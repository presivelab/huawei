import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import {
  DayTransport,
  decodeWatchScript,
  DeviceHasher,
  deviceTzOffsetMin,
  feedScriptSource,
  FileTextStore,
  KeySigner,
  ProofSigner,
  setFeedScript,
  SystemClock,
  WatchLinkEngine,
  WatchLinkView
} from 'common';
import { LiveSensors } from '../sensors/LiveSensors';
import { WearEngineTransport } from './WearEngineTransport';

const DOMAIN = 0x0000;
const TAG = 'FairWear';
const CHARGING_POLL_TICKS = 5;
// Health Sim on the watch: the simulator app that stands in for HUAWEI Health on the emulators. It hands
// over the script of the demo day; the script is kept in the sandbox and read again at the next start.
const HEALTH_SIM_BUNDLE = 'com.fairwear.healthsim';
const HEALTH_SIM_MODULE = 'watch';
const HEALTH_SIM_ABILITY = 'WatchExportAbility';
const HEALTH_SIM_PARAM = 'fwhsw1';
const HEALTH_SIM_OK = 0;
const SCRIPT_PATH = 'healthsim/fwhsw1.json';

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
  private store: FileTextStore | null = null;
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

  // Scripted heart rate, steps and charging instead of the sensors; only while the demo clock runs.
  // Returns whether the feed is on after the call.
  setDemoFeed(on: boolean): boolean {
    const engine = this.engine;
    if (engine === null) {
      return false;
    }
    try {
      return engine.setDemoFeed(on);
    } catch (e) {
      this.fail('demo feed', e as BusinessError);
      return false;
    }
  }

  // Where the script of the demo feed comes from: 'Health Sim' or 'built in'.
  feedSource(): string {
    return feedScriptSource();
  }

  // Asks Health Sim on this watch for the script of the demo day and puts it in use. Health Sim answers
  // at once, without a question: consent was given on the phone. False when Health Sim is not installed,
  // does not answer, or answers with something that is not a whole day; the built-in script then stays.
  async fetchDayScript(): Promise<boolean> {
    const context = this.context;
    if (context === null) {
      return false;
    }
    try {
      const result = await context.startAbilityForResult({
        bundleName: HEALTH_SIM_BUNDLE,
        moduleName: HEALTH_SIM_MODULE,
        abilityName: HEALTH_SIM_ABILITY
      });
      const parameters = result.want === undefined ? undefined : result.want.parameters;
      if (result.resultCode !== HEALTH_SIM_OK || parameters === undefined) {
        return false;
      }
      const raw = parameters[HEALTH_SIM_PARAM];
      if (typeof raw !== 'string') {
        return false;
      }
      const script = decodeWatchScript(raw);
      if (script === null) {
        return false;
      }
      setFeedScript(script);
      const store = this.store;
      if (store !== null) {
        store.writeAtomic(SCRIPT_PATH, raw);
      }
      return true;
    } catch (e) {
      const err = e as BusinessError;
      hilog.info(DOMAIN, TAG, 'health sim script not taken: %{public}d', err.code === undefined ? 0 : err.code);
      return false;
    }
  }

  // The script Health Sim handed over earlier, if any. A stored text that no longer decodes is ignored.
  private restoreDayScript(store: FileTextStore): void {
    const text = store.read(SCRIPT_PATH);
    if (text === null) {
      return;
    }
    const script = decodeWatchScript(text);
    if (script !== null) {
      setFeedScript(script);
    }
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
      const store = new FileTextStore(filesDir);
      this.store = store;
      this.restoreDayScript(store);
      const engine = new WatchLinkEngine(store, signer, new DeviceHasher(), new SystemClock(),
        deviceTzOffsetMin());
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
