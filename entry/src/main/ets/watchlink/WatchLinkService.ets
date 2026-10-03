import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  DeviceHasher,
  DeviceSigVerifier,
  FileTextStore,
  PhoneLinkEngine,
  PhoneLinkView,
  SystemClock,
  TRANSPORT_WEAR_ENGINE,
  WatchDayFacts
} from 'common';
import { WearEngineReceiver } from './WearEngineReceiver';

const DOMAIN = 0x0000;
const TAG = 'FairWear';
const INBOX_POLL_MS = 2000;

// AppStorage key: a counter that changes whenever the Watch Link state changed. Views re-read on it.
export const KEY_LINK_REVISION: string = 'fwWatchLinkRevision';

/*
 * Phone side of Watch Link: takes pairing requests and signed day packets from the watch, checks them
 * and keeps the chain. All checks live in common (PhoneLinkEngine, DayPacketVerifier, ChainLedger).
 *
 * Packets arrive in two ways, both ending in the same engine:
 *  - inbox/ files, put there by tools/watch-phone-relay.mjs over hdc (emulators cannot pair over Wear Engine);
 *  - Wear Engine P2P messages on real paired devices (WearEngineReceiver).
 *
 * This service checks origin and integrity. It does not judge a day: compliance, breaks, the flag and the
 * tier are decided by the rule code from the facts in timeline().
 */
export class WatchLinkService {
  private static instance: WatchLinkService | null = null;

  private engine: PhoneLinkEngine | null = null;
  private receiver: WearEngineReceiver | null = null;
  private revision: number = 0;
  private syncing: boolean = false;
  private pollTimer: number = -1;
  lastError: string = '';

  static shared(): WatchLinkService {
    if (WatchLinkService.instance === null) {
      WatchLinkService.instance = new WatchLinkService();
    }
    return WatchLinkService.instance;
  }

  // Call once at app launch.
  init(context: common.UIAbilityContext): void {
    if (this.engine !== null) {
      return;
    }
    try {
      const filesDir = context.getApplicationContext().filesDir;
      hilog.info(DOMAIN, TAG, 'watchlink filesDir=%{public}s', filesDir);
      const engine = new PhoneLinkEngine(new FileTextStore(filesDir), new DeviceSigVerifier(), new DeviceHasher(),
        new SystemClock());
      engine.load();
      this.engine = engine;
      const receiver = new WearEngineReceiver(context);
      this.receiver = receiver;
      receiver.start((text: string) => {
        this.onWearEngineMessage(text);
      });
    } catch (e) {
      this.fail('start', e as BusinessError);
    }
    this.publish();
  }

  // The app is in the foreground: read the inbox now and keep checking it, so a relay run shows up
  // without a tap.
  onForeground(): void {
    this.syncNow();
    if (this.pollTimer < 0) {
      this.pollTimer = setInterval(() => {
        const engine = this.engine;
        if (engine !== null && engine.hasInbox()) {
          this.syncNow();
        }
      }, INBOX_POLL_MS);
    }
  }

  onBackground(): void {
    if (this.pollTimer >= 0) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
  }

  // Reads inbox/. Runs when the app comes to the foreground, while it stays there, and on "Sync now".
  async syncNow(): Promise<void> {
    const engine = this.engine;
    if (engine === null || this.syncing) {
      return;
    }
    this.syncing = true;
    try {
      const report = await engine.scanInbox();
      hilog.info(DOMAIN, TAG, 'watchlink sync: processed=%{public}d accepted=%{public}d rejected=%{public}d',
        report.processed, report.accepted, report.rejected);
      this.lastError = '';
    } catch (e) {
      this.fail('sync', e as BusinessError);
    } finally {
      this.syncing = false;
    }
    this.publish();
  }

  confirmPair(): void {
    const engine = this.engine;
    if (engine === null) {
      return;
    }
    try {
      engine.confirmPair();
      this.sendAcks();
    } catch (e) {
      this.fail('pair', e as BusinessError);
    }
    this.publish();
  }

  declinePair(): void {
    const engine = this.engine;
    if (engine !== null) {
      engine.declinePair();
    }
    this.publish();
  }

  forget(): void {
    const engine = this.engine;
    if (engine === null) {
      return;
    }
    try {
      engine.forget();
    } catch (e) {
      this.fail('forget', e as BusinessError);
    }
    this.publish();
  }

  view(): PhoneLinkView {
    const engine = this.engine;
    return engine === null ? new PhoneLinkView() : engine.view();
  }

  // Days received from the watch, newest first, with a placeholder for each day the chain shows as missing.
  days(): WatchDayFacts[] {
    const engine = this.engine;
    if (engine === null) {
      return [];
    }
    try {
      return engine.timeline().reverse();
    } catch (e) {
      this.fail('days', e as BusinessError);
      return [];
    }
  }

  wearEngineStatus(): string {
    return this.receiver === null ? '' : this.receiver.status();
  }

  private onWearEngineMessage(text: string): void {
    const engine = this.engine;
    if (engine === null) {
      return;
    }
    engine.receive(text, TRANSPORT_WEAR_ENGINE).then(() => {
      this.sendAcks();
      this.publish();
    }).catch((e: BusinessError) => {
      this.fail('receive', e);
    });
  }

  // Over Wear Engine the ACKs go back as messages; with the relay the acks/ files are fetched by the script.
  private sendAcks(): void {
    const receiver = this.receiver;
    const context = this.receiver === null ? null : this.receiver.filesDir();
    if (receiver === null || context === null || !receiver.isConnected()) {
      return;
    }
    const store = new FileTextStore(context);
    const names = store.list('acks');
    for (let i = 0; i < names.length; i++) {
      const text = store.read(`acks/${names[i]}`);
      if (text !== null) {
        receiver.send(text);
      }
    }
  }

  private publish(): void {
    this.revision++;
    AppStorage.setOrCreate<number>(KEY_LINK_REVISION, this.revision);
  }

  private fail(what: string, err: BusinessError): void {
    const text = err === undefined || err === null ? 'unknown error' :
      (err.code !== undefined ? `${err.code}: ${err.message}` : `${err.message}`);
    this.lastError = `${what}: ${text}`;
    hilog.error(DOMAIN, TAG, 'watchlink %{public}s failed: %{public}s', what, text);
  }
}
