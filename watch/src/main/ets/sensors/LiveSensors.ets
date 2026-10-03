import { sensor } from '@kit.SensorServiceKit';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { LiveWearState, WearState, NO_HEART_RATE, DEFAULT_REMOVED_AFTER_MS } from 'common';
import { DaySteps, NO_STEPS } from '../model/DaySteps';

const DOMAIN = 0x0000;
const TAG = 'FairWear';
const SENSOR_INTERVAL_NS = 1000000000;
const STORE_NAME = 'fairwear_watch';
const STORE_KEY = 'day_steps_v1';
const PERMISSION_DENIED = 201;
const PERSIST_EVERY_TICKS = 10;
const SUMMARY_EVERY_TICKS = 10;

export enum SensorLink {
  WAITING,
  LIVE,
  ABSENT,
  NO_PERMISSION,
  ERROR
}

// What the watch screen shows. Live values only: nothing here enters the score.
export class LiveSnapshot {
  heartRate: number = NO_HEART_RATE;
  steps: number = NO_STEPS;
  wear: WearState = WearState.NO_DATA;
  heartSensor: SensorLink = SensorLink.WAITING;
  stepSensor: SensorLink = SensorLink.WAITING;
}

function dayKey(now: Date): string {
  return `${now.getFullYear()}-${now.getMonth() + 1}-${now.getDate()}`;
}

// Owns the sensor subscriptions of the watch module. The wear-state rules live in common
// (LiveWearState); this class only feeds it raw readings and timestamps.
export class LiveSensors {
  private wear: LiveWearState = new LiveWearState(DEFAULT_REMOVED_AFTER_MS);
  private steps: DaySteps = new DaySteps();
  private store: preferences.Preferences | null = null;
  private heartLink: SensorLink = SensorLink.WAITING;
  private stepLink: SensorLink = SensorLink.WAITING;
  private running: boolean = false;
  private stepsDirty: boolean = false;
  private ticks: number = 0;
  private heartEvents: number = 0;
  private heartValidEvents: number = 0;
  private stepEvents: number = 0;
  private lastHeartRaw: number = NO_HEART_RATE;

  init(context: common.Context): void {
    if (this.store !== null) {
      return;
    }
    try {
      this.store = preferences.getPreferencesSync(context, { name: STORE_NAME });
      this.steps.restore(this.store.getSync(STORE_KEY, '') as string);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'step state load failed: %{public}s', JSON.stringify(err));
    }
  }

  start(): void {
    if (this.running) {
      return;
    }
    this.running = true;
    // Nothing was read while the sensors were off, so the wear state starts again from "no data".
    this.wear = new LiveWearState(DEFAULT_REMOVED_AFTER_MS);
    this.heartEvents = 0;
    this.heartValidEvents = 0;
    this.stepEvents = 0;
    const ids = this.sensorIds();
    hilog.info(DOMAIN, TAG, 'sensor ids: %{public}s', ids.join(','));

    if (ids.includes(sensor.SensorId.HEART_RATE)) {
      this.heartLink = this.subscribe('heart rate', () => {
        sensor.on(sensor.SensorId.HEART_RATE, (data: sensor.HeartRateResponse) => {
          this.onHeartRate(data.heartRate);
        }, { interval: SENSOR_INTERVAL_NS });
      });
    } else {
      this.heartLink = SensorLink.ABSENT;
    }

    if (ids.includes(sensor.SensorId.PEDOMETER)) {
      this.stepLink = this.subscribe('step counter', () => {
        sensor.on(sensor.SensorId.PEDOMETER, (data: sensor.PedometerResponse) => {
          this.onSteps(data.steps);
        }, { interval: SENSOR_INTERVAL_NS });
      });
    } else {
      this.stepLink = SensorLink.ABSENT;
    }
  }

  stop(): void {
    if (!this.running) {
      return;
    }
    this.running = false;
    this.heartLink = this.unsubscribe(this.heartLink, () => sensor.off(sensor.SensorId.HEART_RATE));
    this.stepLink = this.unsubscribe(this.stepLink, () => sensor.off(sensor.SensorId.PEDOMETER));
    this.persist();
    hilog.info(DOMAIN, TAG, 'sensors off');
  }

  // Call about once a second: ages the last valid heart rate even when the sensor is silent.
  tick(nowMs: number): LiveSnapshot {
    this.wear.advance(nowMs);
    this.ticks++;
    if (this.ticks % PERSIST_EVERY_TICKS === 0) {
      this.persist();
    }
    if (this.ticks % SUMMARY_EVERY_TICKS === 0) {
      this.logSummary();
    }
    return this.snapshot();
  }

  snapshot(): LiveSnapshot {
    const view = new LiveSnapshot();
    view.heartSensor = this.heartLink;
    view.stepSensor = this.stepLink;
    view.heartRate = this.heartLink === SensorLink.LIVE ? this.wear.heartRate() : NO_HEART_RATE;
    view.wear = this.heartLink === SensorLink.LIVE ? this.wear.state() : WearState.NO_DATA;
    view.steps = this.stepLink === SensorLink.LIVE ? this.steps.today(dayKey(new Date())) : NO_STEPS;
    return view;
  }

  private sensorIds(): number[] {
    const ids: number[] = [];
    try {
      sensor.getSensorListSync().forEach((item) => {
        ids.push(item.sensorId);
      });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'sensor list failed: %{public}s', JSON.stringify(err));
    }
    ids.sort((a, b) => a - b);
    return ids;
  }

  private subscribe(name: string, attach: () => void): SensorLink {
    try {
      attach();
      hilog.info(DOMAIN, TAG, '%{public}s subscribed', name);
      return SensorLink.LIVE;
    } catch (err) {
      const code = (err as BusinessError).code;
      hilog.error(DOMAIN, TAG, '%{public}s subscribe failed: %{public}s', name, JSON.stringify(err));
      return code === PERMISSION_DENIED ? SensorLink.NO_PERMISSION : SensorLink.ERROR;
    }
  }

  private unsubscribe(link: SensorLink, detach: () => void): SensorLink {
    if (link !== SensorLink.LIVE) {
      return link;
    }
    try {
      detach();
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'sensor unsubscribe failed: %{public}s', JSON.stringify(err));
    }
    return SensorLink.WAITING;
  }

  private onHeartRate(value: number): void {
    this.heartEvents++;
    this.lastHeartRaw = value;
    if (value > 0) {
      this.heartValidEvents++;
    }
    // LiveWearState treats every reading <= 0 as "no reading".
    this.wear.onReading(Date.now(), value);
  }

  private onSteps(raw: number): void {
    this.stepEvents++;
    if (this.steps.onRaw(dayKey(new Date()), raw)) {
      this.stepsDirty = true;
    }
  }

  private persist(): void {
    if (this.store === null || !this.stepsDirty) {
      return;
    }
    try {
      this.store.putSync(STORE_KEY, this.steps.save());
      this.store.flush();
      this.stepsDirty = false;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'step state save failed: %{public}s', JSON.stringify(err));
    }
  }

  private logSummary(): void {
    const view = this.snapshot();
    const line = `live hrLink=${this.heartLink} hrEvents=${this.heartEvents} hrValid=${this.heartValidEvents}` +
      ` hrRaw=${this.lastHeartRaw} hrShown=${view.heartRate} wear=${view.wear}` +
      ` stepLink=${this.stepLink} stepEvents=${this.stepEvents} stepsRaw=${this.steps.lastRaw()}` +
      ` stepsToday=${view.steps}`;
    hilog.info(DOMAIN, TAG, '%{public}s', line);
  }
}
