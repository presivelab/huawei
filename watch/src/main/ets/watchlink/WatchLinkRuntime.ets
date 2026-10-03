import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import {
  DayTransport,
  DeviceHasher,
  deviceTzOffsetMin,
  FileTextStore,
  KeySigner,
  ProofSigner,
  SystemClock,
  WatchLinkEngine,
  WatchLinkView
} from 'common';
import { LiveSensors } from '../sensors/LiveSensors';
import { WearEngineTransport } from './WearEngineTransport';

const DOMAIN = 0x0000;
const TAG = 'FairWear';
const CHARGING_POLL_TICKS = 5;

// Platform side of Watch Link on the watch: the day-signing key, the files directory, the transports,
// and the feed from the sensors into the engine. Every rule of the recorder lives in common (WatchLinkEngine).
//
// Records while the watch app is open. No continuous task is requested: none of the continuous-task
// types matches health logging, so time in the background is "not observed".
export class WatchLinkRuntime {
  private static instance: WatchLinkRuntime | null = null;

  private engine: WatchLinkEngine | null = null;
  private pending: Promise<void> | null = null;
  private context: common.UIAbilityContext | null = null;
  private wearEngine: WearEngineTransport | null = null;
  private ticking: boolean = false;
  private ticks: number = 0;
  private keptScreenOn: boolean = false;
  keyNote: string = '';
  error: string = '';

  static shared(): WatchLinkRuntime {
    if (WatchLinkRuntime.instance === null) {
      WatchLinkRuntime.instance = new WatchLinkRuntime();
    }
    return WatchLinkRuntime.instance;
  }

  // Creates the key and the engine once. Safe to call repeatedly.
  init(context: common.UIAbilityContext): Promise<void> {
    if (this.pending === null) {
      this.context = context;
      this.pending = this.setUp(context);
    }
    return this.pending;
  }

  // Routes raw sensor readings into the engine. Readings that arrive before the engine exists are dropped.
  attach(sensors: LiveSensors): void {
    sensors.setTaps((bpm: number) => {
      const engine = this.engine;
      if (engine !== null) {
        engine.onHr(bpm);
      }
    }, (value: number) => {
      const engine = this.engine;
      if (engine !== null) {
        engine.onWear(value);
      }
    });
  }

  // About once a second while the dial is visible.
  async tick(sensors: LiveSensors): Promise<void> {
    const engine = this.engine;
    if (engine === null || this.ticking) {
      return;
    }
    this.ticking = true;
    try {
      if (this.ticks % CHARGING_POLL_TICKS === 0) {
        engine.onCharging(sensors.isCharging());
      }
      this.ticks++;
      await engine.tick(sensors.takeStepsDelta());
      this.error = '';
    } catch (e) {
      this.fail('tick', e as BusinessError);
    } finally {
      this.ticking = false;
    }
  }

  // The dial is hidden: observation stops, the open slot is flushed.
  pause(): void {
    const engine = this.engine;
    if (engine === null) {
      return;
    }
    try {
      engine.pause();
    } catch (e) {
      this.fail('pause', e as BusinessError);
    }
  }

  view(): WatchLinkView {
    const engine = this.engine;
    if (engine === null) {
      return new WatchLinkView();
    }
    try {
      return engine.view();
    } catch (e) {
      this.fail('view', e as BusinessError);
      return new WatchLinkView();
    }
  }

  isReady(): boolean {
    return this.engine !== null;
  }

  wearEngineStatus(): string {
    return this.wearEngine === null ? '' : this.wearEngine.status();
  }

  setDemoClock(on: boolean): void {
    const engine = this.engine;
    if (engine === null) {
      return;
    }
    try {
      engine.setDemoClock(on);
    } catch (e) {
      this.fail('demo clock', e as BusinessError);
    }
    this.keepScreenOn(on);
  }

  // Returns the seq of the packet now in the outbox, 0 when nothing had been recorded, -1 on failure.
  async closeDay(): Promise<number> {
    const engine = this.engine;
    if (engine === null) {
      return -1;
    }
    try {
      return await engine.closeDayNow();
    } catch (e) {
      this.fail('close day', e as BusinessError);
      return -1;
    }
  }

  // Returns the 8-hex code to show, or '' on failure.
  async pair(): Promise<string> {
    const engine = this.engine;
    if (engine === null) {
      return '';
    }
    try {
      return await engine.pair();
    } catch (e) {
      this.fail('pair', e as BusinessError);
      return '';
    }
  }

  reset(): void {
    const engine = this.engine;
    if (engine === null) {
      return;
    }
    try {
      engine.reset();
    } catch (e) {
      this.fail('reset', e as BusinessError);
    }
    this.keepScreenOn(false);
  }

  private async setUp(context: common.UIAbilityContext): Promise<void> {
    try {
      const filesDir = context.getApplicationContext().filesDir;
      hilog.info(DOMAIN, TAG, 'watchlink filesDir=%{public}s', filesDir);
      // The watch's own key, separate from the phone's claim key.
      const signer = await KeySigner.create(ProofSigner.WATCH_DAY_ALIAS);
      this.keyNote = signer.note();
      hilog.info(DOMAIN, TAG, 'watchlink key kid=%{public}s source=%{public}s', signer.kid(), signer.keySource());
      const engine = new WatchLinkEngine(new FileTextStore(filesDir), signer, new DeviceHasher(),
        new SystemClock(), deviceTzOffsetMin());
      const wearEngine = new WearEngineTransport(context);
      this.wearEngine = wearEngine;
      const transports: DayTransport[] = [wearEngine];
      engine.setTransports(transports);
      await engine.start();
      this.engine = engine;
    } catch (e) {
      this.fail('start', e as BusinessError);
    }
  }

  // The screen stays on only while the demo clock runs.
  private keepScreenOn(on: boolean): void {
    const context = this.context;
    if (context === null || this.keptScreenOn === on) {
      return;
    }
    this.keptScreenOn = on;
    window.getLastWindow(context).then((win: window.Window) => {
      return win.setWindowKeepScreenOn(on);
    }).catch((err: BusinessError) => {
      hilog.warn(DOMAIN, TAG, 'keep screen on failed: %{public}s', JSON.stringify(err));
    });
  }

  private fail(what: string, err: BusinessError): void {
    const text = err === undefined || err === null ? 'unknown error' :
      (err.code !== undefined ? `${err.code}: ${err.message}` : `${err.message}`);
    this.error = `${what}: ${text}`;
    hilog.error(DOMAIN, TAG, 'watchlink %{public}s failed: %{public}s', what, text);
  }
}
