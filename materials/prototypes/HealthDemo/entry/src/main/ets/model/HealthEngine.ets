import { sensor } from '@kit.SensorServiceKit';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0002;
const TAG = 'HealthDemo';
const STORE_NAME = 'health_day';
const STORE_KEY = 'day_v2';
const SENSOR_INTERVAL_NS = 1000000000;
const TICK_MS = 1000;
const PERSIST_EVERY_TICKS = 10;
const SUMMARY_EVERY_TICKS = 10;
const RATE_WINDOW_TICKS = 10;
const HR_STALE_MS = 5000;
const WORN_HR_WINDOW_MS = 60000;
const MINUTES_PER_DAY = 1440;

// Daily goals. Exercise 30 min and stand 12 h are the usual defaults; the move goal is a chosen value.
export const MOVE_GOAL_KCAL = 300;
export const EXERCISE_GOAL_MIN = 30;
export const STAND_GOAL_HOURS = 12;
export const CHART_MINUTES = 60;

// Estimates, not measurements: the only inputs are heart rate and a step counter.
const KCAL_PER_STEP = 0.04;
const METERS_PER_STEP = 0.7;
const EXERCISE_HR_BPM = 100;
const EXERCISE_STEPS_PER_MIN = 80;
// A larger jump between two readings was walked while nobody was listening (app suspended, counter
// restarted). It counts towards today's total, but is not credited to the current minute or hour.
const MAX_LIVE_STEP_DELTA = 250;

export const WEAR_SOURCE_SENSOR = 'WEAR_SENSOR';
export const WEAR_SOURCE_HR = 'HR_SIGNAL';
export const PROBE_WAITING = 'not subscribed';
export const PROBE_SUBSCRIBED = 'subscribed';
export const PROBE_ABSENT = 'absent';
export const UNKNOWN = -1;

export class MinuteBucket {
  minute: number = 0;
  min: number = 0;
  max: number = 0;
  sum: number = 0;
  count: number = 0;
  steps: number = 0;
}

export class SensorInfo {
  id: number = 0;
  name: string = '';
}

export class ProbeSnapshot {
  present: boolean = false;
  status: string = PROBE_WAITING;
  hasValue: boolean = false;
  value: number = 0;
  events: number = 0;
  eventsPerSecond: number = 0;
  secondsSinceEvent: number = UNKNOWN;
}

export class BackgroundSnapshot {
  foreground: boolean = true;
  visits: number = 0;
  seconds: number = 0;
  ticks: number = 0;
  heartRateEvents: number = 0;
  stepEvents: number = 0;
  wearEvents: number = 0;
  gapForegroundMs: number = UNKNOWN;
  gapBackgroundMs: number = UNKNOWN;
}

export class StepSnapshot {
  raw: number = UNKNOWN;
  baseline: number = UNKNOWN;
  carried: number = 0;
}

class DayState {
  date: string = '';
  // Raw counter value that counts as zero for today; UNKNOWN until the first reading of the day.
  baselineSteps: number = UNKNOWN;
  // Steps counted today before the counter last restarted.
  carriedSteps: number = 0;
  lastRawSteps: number = UNKNOWN;
  standHours: number[] = [];
  buckets: MinuteBucket[] = [];
}

class SensorProbe {
  present: boolean = false;
  status: string = PROBE_WAITING;
  hasValue: boolean = false;
  value: number = 0;
  events: number = 0;
  backgroundEvents: number = 0;
  lastEventAt: number = 0;
  private tickEvents: number = 0;
  private recentTicks: number[] = [];

  record(value: number, now: number, foreground: boolean): void {
    this.hasValue = true;
    this.value = value;
    this.lastEventAt = now;
    this.events++;
    this.tickEvents++;
    if (!foreground) {
      this.backgroundEvents++;
    }
  }

  closeTick(): void {
    this.recentTicks.push(this.tickEvents);
    this.tickEvents = 0;
    if (this.recentTicks.length > RATE_WINDOW_TICKS) {
      this.recentTicks.shift();
    }
  }

  eventsPerSecond(): number {
    if (this.recentTicks.length === 0) {
      return 0;
    }
    let total = 0;
    this.recentTicks.forEach((count) => {
      total += count;
    });
    return total / this.recentTicks.length;
  }

  snapshot(now: number): ProbeSnapshot {
    const view = new ProbeSnapshot();
    view.present = this.present;
    view.status = this.status;
    view.hasValue = this.hasValue;
    view.value = this.value;
    view.events = this.events;
    view.eventsPerSecond = this.eventsPerSecond();
    view.secondsSinceEvent = this.lastEventAt > 0 ? Math.floor((now - this.lastEventAt) / 1000) : UNKNOWN;
    return view;
  }
}

function todayKey(now: Date): string {
  return `${now.getFullYear()}-${now.getMonth() + 1}-${now.getDate()}`;
}

function minuteOfDay(now: Date): number {
  return now.getHours() * 60 + now.getMinutes();
}

export class HealthEngine {
  private static instance: HealthEngine | null = null;
  private state: DayState = new DayState();
  private store: preferences.Preferences | null = null;
  private timer: number = -1;
  private ticks: number = 0;
  private liveHeartRate: number = 0;
  private lastHeartRateAt: number = 0;
  private sensorsOn: boolean = false;
  private heartProbe: SensorProbe = new SensorProbe();
  private stepProbe: SensorProbe = new SensorProbe();
  private wearProbe: SensorProbe = new SensorProbe();
  private foreground: boolean = true;
  private backgroundSince: number = 0;
  private backgroundMs: number = 0;
  private backgroundVisits: number = 0;
  private backgroundTicks: number = 0;
  // True while the gap since the last heart-rate event includes time spent in the background.
  private gapInBackground: boolean = false;
  private gapForegroundMs: number = UNKNOWN;
  private gapBackgroundMs: number = UNKNOWN;

  static get(): HealthEngine {
    if (HealthEngine.instance === null) {
      HealthEngine.instance = new HealthEngine();
    }
    return HealthEngine.instance;
  }

  init(context: common.Context): void {
    try {
      this.store = preferences.getPreferencesSync(context, { name: STORE_NAME });
      const raw = this.store.getSync(STORE_KEY, '') as string;
      if (raw.length > 0) {
        this.state = JSON.parse(raw) as DayState;
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'load failed: %{public}s', JSON.stringify(err));
      this.state = new DayState();
    }
    this.rollDay(new Date());
    this.readSensorList();
    this.publish();
    if (this.timer < 0) {
      this.timer = setInterval(() => this.tick(), TICK_MS);
    }
  }

  startSensors(): void {
    if (this.sensorsOn) {
      return;
    }
    this.sensorsOn = true;
    this.subscribe('heart rate', this.heartProbe, () => {
      sensor.on(sensor.SensorId.HEART_RATE, (data: sensor.HeartRateResponse) => {
        this.onHeartRate(data.heartRate);
      }, { interval: SENSOR_INTERVAL_NS });
    });
    this.subscribe('step counter', this.stepProbe, () => {
      sensor.on(sensor.SensorId.PEDOMETER, (data: sensor.PedometerResponse) => {
        this.onSteps(data.steps);
      }, { interval: SENSOR_INTERVAL_NS });
    });
    if (this.wearProbe.present) {
      this.subscribe('wear detection', this.wearProbe, () => {
        sensor.on(sensor.SensorId.WEAR_DETECTION, (data: sensor.WearDetectionResponse) => {
          this.wearProbe.record(data.value, Date.now(), this.foreground);
        }, { interval: SENSOR_INTERVAL_NS });
      });
    } else {
      this.wearProbe.status = PROBE_ABSENT;
    }
  }

  stopSensors(): void {
    if (!this.sensorsOn) {
      return;
    }
    this.unsubscribe(this.heartProbe, () => sensor.off(sensor.SensorId.HEART_RATE));
    this.unsubscribe(this.stepProbe, () => sensor.off(sensor.SensorId.PEDOMETER));
    this.unsubscribe(this.wearProbe, () => sensor.off(sensor.SensorId.WEAR_DETECTION));
    this.sensorsOn = false;
    this.persist();
  }

  setForeground(foreground: boolean): void {
    if (foreground === this.foreground) {
      return;
    }
    const now = Date.now();
    this.foreground = foreground;
    if (foreground) {
      this.backgroundMs += now - this.backgroundSince;
    } else {
      this.backgroundSince = now;
      this.backgroundVisits++;
      this.gapInBackground = true;
    }
    hilog.info(DOMAIN, TAG, 'ability %{public}s', foreground ? 'foreground' : 'background');
    this.publish();
  }

  // One slot per minute for the last CHART_MINUTES minutes, oldest first; null where nothing was read.
  lastHour(): (MinuteBucket | null)[] {
    const now = minuteOfDay(new Date());
    const slots: (MinuteBucket | null)[] = [];
    for (let i = 0; i < CHART_MINUTES; i++) {
      slots.push(null);
    }
    const buckets = this.state.buckets;
    for (let i = buckets.length - 1; i >= 0; i--) {
      const age = now - buckets[i].minute;
      if (age >= CHART_MINUTES) {
        break;
      }
      if (age >= 0 && buckets[i].count > 0) {
        slots[CHART_MINUTES - 1 - age] = buckets[i];
      }
    }
    return slots;
  }

  private readSensorList(): void {
    const infos: SensorInfo[] = [];
    try {
      sensor.getSensorListSync().forEach((item) => {
        const info = new SensorInfo();
        info.id = item.sensorId;
        info.name = item.sensorName;
        infos.push(info);
      });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'sensor list failed: %{public}s', JSON.stringify(err));
    }
    infos.sort((a, b) => a.id - b.id);
    this.heartProbe.present = infos.some((item) => item.id === sensor.SensorId.HEART_RATE);
    this.stepProbe.present = infos.some((item) => item.id === sensor.SensorId.PEDOMETER);
    this.wearProbe.present = infos.some((item) => item.id === sensor.SensorId.WEAR_DETECTION);
    AppStorage.setOrCreate('hd_sensors', infos);
    hilog.info(DOMAIN, TAG, 'sensor ids: %{public}s', infos.map((item) => item.id).join(','));
  }

  private subscribe(name: string, probe: SensorProbe, attach: () => void): void {
    try {
      attach();
      probe.status = PROBE_SUBSCRIBED;
      hilog.info(DOMAIN, TAG, '%{public}s subscribed', name);
    } catch (err) {
      probe.status = `error ${(err as BusinessError).code}`;
      hilog.error(DOMAIN, TAG, '%{public}s subscribe failed: %{public}s', name, JSON.stringify(err));
    }
  }

  private unsubscribe(probe: SensorProbe, detach: () => void): void {
    if (probe.status !== PROBE_SUBSCRIBED) {
      return;
    }
    try {
      detach();
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'sensor unsubscribe failed: %{public}s', JSON.stringify(err));
    }
    probe.status = PROBE_WAITING;
  }

  private onHeartRate(value: number): void {
    const now = Date.now();
    if (this.heartProbe.lastEventAt > 0) {
      this.noteHeartGap(now - this.heartProbe.lastEventAt);
    }
    this.gapInBackground = !this.foreground;
    this.heartProbe.record(value, now, this.foreground);
    if (value <= 0) {
      this.liveHeartRate = 0;
      return;
    }
    if (value !== this.liveHeartRate) {
      hilog.info(DOMAIN, TAG, 'heartRate=%{public}d', value);
    }
    this.liveHeartRate = value;
    this.lastHeartRateAt = now;
    const bucket = this.currentBucket();
    bucket.min = bucket.count === 0 ? value : Math.min(bucket.min, value);
    bucket.max = Math.max(bucket.max, value);
    bucket.sum += value;
    bucket.count++;
  }

  private noteHeartGap(gap: number): void {
    if (this.gapInBackground) {
      this.gapBackgroundMs = Math.max(this.gapBackgroundMs, gap);
    } else {
      this.gapForegroundMs = Math.max(this.gapForegroundMs, gap);
    }
  }

  // The sensor is a running counter, not a daily one: today = carried + raw - baseline.
  private onSteps(raw: number): void {
    const state = this.state;
    const last = state.lastRawSteps;
    this.stepProbe.record(raw, Date.now(), this.foreground);
    if (raw === last && state.baselineSteps !== UNKNOWN) {
      return;
    }
    hilog.info(DOMAIN, TAG, 'steps raw=%{public}d', raw);
    if (state.baselineSteps === UNKNOWN) {
      state.baselineSteps = raw;
    } else if (raw < last) {
      // The counter restarted (reboot): keep what was counted and go on from zero.
      state.carriedSteps += last - state.baselineSteps;
      state.baselineSteps = 0;
    } else if (raw - last <= MAX_LIVE_STEP_DELTA) {
      this.currentBucket().steps += raw - last;
      const hour = new Date().getHours();
      if (!state.standHours.includes(hour)) {
        state.standHours.push(hour);
      }
    }
    state.lastRawSteps = raw;
  }

  private currentBucket(): MinuteBucket {
    const minute = minuteOfDay(new Date());
    const buckets = this.state.buckets;
    if (buckets.length > 0 && buckets[buckets.length - 1].minute === minute) {
      return buckets[buckets.length - 1];
    }
    const bucket = new MinuteBucket();
    bucket.minute = minute;
    buckets.push(bucket);
    if (buckets.length > MINUTES_PER_DAY) {
      buckets.shift();
    }
    return bucket;
  }

  private rollDay(now: Date): void {
    const key = todayKey(now);
    if (this.state.date === key) {
      return;
    }
    const fresh = new DayState();
    fresh.date = key;
    fresh.lastRawSteps = this.state.lastRawSteps;
    this.state = fresh;
  }

  private tick(): void {
    const now = Date.now();
    this.rollDay(new Date());
    if (this.liveHeartRate > 0 && now - this.lastHeartRateAt > HR_STALE_MS) {
      this.liveHeartRate = 0;
    }
    if (this.heartProbe.lastEventAt > 0) {
      this.noteHeartGap(now - this.heartProbe.lastEventAt);
    }
    if (!this.foreground) {
      this.backgroundTicks++;
    }
    this.heartProbe.closeTick();
    this.stepProbe.closeTick();
    this.wearProbe.closeTick();
    this.publish();
    this.ticks++;
    if (this.ticks % PERSIST_EVERY_TICKS === 0) {
      this.persist();
    }
    if (this.ticks % SUMMARY_EVERY_TICKS === 0) {
      this.logSummary();
    }
  }

  private todaySteps(): number {
    const state = this.state;
    if (state.baselineSteps === UNKNOWN) {
      return UNKNOWN;
    }
    return state.carriedSteps + Math.max(0, state.lastRawSteps - state.baselineSteps);
  }

  // The wear sensor decides once it has reported; until then, and on devices without one,
  // the watch counts as worn while a heart rate above zero arrived in the last minute.
  private wearFromSensor(): boolean {
    return this.wearProbe.status === PROBE_SUBSCRIBED && this.wearProbe.hasValue;
  }

  private worn(now: number): boolean {
    if (this.wearFromSensor()) {
      return this.wearProbe.value === 1;
    }
    return this.lastHeartRateAt > 0 && now - this.lastHeartRateAt <= WORN_HR_WINDOW_MS;
  }

  private backgroundSnapshot(now: number): BackgroundSnapshot {
    const view = new BackgroundSnapshot();
    view.foreground = this.foreground;
    view.visits = this.backgroundVisits;
    view.seconds = Math.round((this.backgroundMs + (this.foreground ? 0 : now - this.backgroundSince)) / 1000);
    view.ticks = this.backgroundTicks;
    view.heartRateEvents = this.heartProbe.backgroundEvents;
    view.stepEvents = this.stepProbe.backgroundEvents;
    view.wearEvents = this.wearProbe.backgroundEvents;
    view.gapForegroundMs = this.gapForegroundMs;
    view.gapBackgroundMs = this.gapBackgroundMs;
    return view;
  }

  private publish(): void {
    const now = Date.now();
    const state = this.state;
    const steps = this.todaySteps();
    const stepsKnown = steps !== UNKNOWN;
    const currentMinute = minuteOfDay(new Date());
    let exerciseMinutes = 0;
    let measuredMinutes = 0;
    let dayMin = 0;
    let dayMax = 0;
    let hourMin = 0;
    let hourMax = 0;
    let resting = 0;
    state.buckets.forEach((bucket) => {
      const average = bucket.count > 0 ? bucket.sum / bucket.count : 0;
      if (bucket.minute !== currentMinute &&
        (average >= EXERCISE_HR_BPM || bucket.steps >= EXERCISE_STEPS_PER_MIN)) {
        exerciseMinutes++;
      }
      if (bucket.count === 0) {
        return;
      }
      measuredMinutes++;
      dayMin = dayMin === 0 ? bucket.min : Math.min(dayMin, bucket.min);
      dayMax = Math.max(dayMax, bucket.max);
      const age = currentMinute - bucket.minute;
      if (age >= 0 && age < CHART_MINUTES) {
        hourMin = hourMin === 0 ? bucket.min : Math.min(hourMin, bucket.min);
        hourMax = Math.max(hourMax, bucket.max);
      }
      // Resting estimate: the lowest one-minute average among finished minutes without a step.
      if (bucket.steps === 0 && bucket.minute !== currentMinute) {
        resting = resting === 0 ? average : Math.min(resting, average);
      }
    });
    const stepView = new StepSnapshot();
    stepView.raw = state.lastRawSteps;
    stepView.baseline = state.baselineSteps;
    stepView.carried = state.carriedSteps;
    AppStorage.setOrCreate('hd_hr', this.liveHeartRate);
    AppStorage.setOrCreate('hd_steps', steps);
    AppStorage.setOrCreate('hd_kcal', stepsKnown ? Math.round(steps * KCAL_PER_STEP) : UNKNOWN);
    AppStorage.setOrCreate('hd_meters', stepsKnown ? Math.round(steps * METERS_PER_STEP) : UNKNOWN);
    AppStorage.setOrCreate('hd_exercise', stepsKnown || state.buckets.length > 0 ? exerciseMinutes : UNKNOWN);
    AppStorage.setOrCreate('hd_stand', stepsKnown ? state.standHours.length : UNKNOWN);
    AppStorage.setOrCreate('hd_hr_min', dayMin);
    AppStorage.setOrCreate('hd_hr_max', dayMax);
    AppStorage.setOrCreate('hd_hour_min', hourMin);
    AppStorage.setOrCreate('hd_hour_max', hourMax);
    AppStorage.setOrCreate('hd_hr_minutes', measuredMinutes);
    AppStorage.setOrCreate('hd_resting', Math.round(resting));
    AppStorage.setOrCreate('hd_worn', this.worn(now));
    AppStorage.setOrCreate('hd_wear_source', this.wearFromSensor() ? WEAR_SOURCE_SENSOR : WEAR_SOURCE_HR);
    AppStorage.setOrCreate('hd_probe_hr', this.heartProbe.snapshot(now));
    AppStorage.setOrCreate('hd_probe_steps', this.stepProbe.snapshot(now));
    AppStorage.setOrCreate('hd_probe_wear', this.wearProbe.snapshot(now));
    AppStorage.setOrCreate('hd_step_counter', stepView);
    AppStorage.setOrCreate('hd_background', this.backgroundSnapshot(now));
    AppStorage.setOrCreate('hd_tick', this.ticks);
  }

  private logSummary(): void {
    const now = Date.now();
    const background = this.backgroundSnapshot(now);
    const line = `summary ${this.foreground ? 'fg' : 'bg'}` +
      ` hr=${this.liveHeartRate} hrEv=${this.heartProbe.events} hrRate=${this.heartProbe.eventsPerSecond().toFixed(1)}/s` +
      ` stepsRaw=${this.state.lastRawSteps} today=${this.todaySteps()} stepEv=${this.stepProbe.events}` +
      ` wear=${this.wearProbe.status} worn=${this.worn(now) ? 1 : 0}` +
      `/${this.wearFromSensor() ? WEAR_SOURCE_SENSOR : WEAR_SOURCE_HR}` +
      ` | bg ${background.seconds}s visits=${background.visits} ticks=${background.ticks}` +
      ` hrEv=${background.heartRateEvents} stepEv=${background.stepEvents}` +
      ` | hrGapMaxMs fg=${background.gapForegroundMs} bg=${background.gapBackgroundMs}`;
    hilog.info(DOMAIN, TAG, '%{public}s', line);
  }

  private persist(): void {
    if (this.store === null) {
      return;
    }
    try {
      this.store.putSync(STORE_KEY, JSON.stringify(this.state));
      this.store.flush();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'persist failed: %{public}s', JSON.stringify(err));
    }
  }
}
