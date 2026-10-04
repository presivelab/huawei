// Demo feed: a scripted day of heart rate, steps and charging for the watch recorder. Pure logic.
//
// The wearable emulator sends heart rate 0 and a fixed step counter, so a recorded day is all "off wrist".
// The demo feed replaces the sensor readings with a fixed script so the dial and the day packets have a
// real shape: night charging, worn hours, one break, a walk and a workout.
//
// It is demo data and is labelled as such: it only runs while the demo clock runs, the dial says so, and
// every day that received any of it carries the clock label DEMO_X300_FEED in its signed packet.
// The readings go through the same WearStateMachine and SlotRecorder as sensor readings. There is no
// second wear rule here: an "off wrist" stretch is simply a stretch with no valid heart rate.
//
// The script of the day can come from Health Sim, the simulator app that stands in for HUAWEI Health on the
// emulators: its watch module returns it as one JSON text (`fwhsw1`) and `setFeedScript` puts it in use.
// Without it the built-in script below is used. Either way the packet label stays DEMO_X300_FEED.
// This file is copied unchanged into Health Sim (healthsim/watch/src/main/ets/fw/watchlink/).
import { asObject, parseJsonObject, readArray, readInt, readString } from './JsonRead';

/** Appended to the demo-speed clock label of a day that received scripted readings. */
export const CLOCK_FEED_SUFFIX: string = '_FEED';

export class DemoFeedSample {
  hr: number = 0;              // bpm; 0 = no reading (the watch is off the wrist or on the charger)
  charging: boolean = false;
  stepsPerMin: number = 0;
}

export class FeedStretch {
  fromMin: number;             // minute of the local day, inclusive
  toMin: number;               // exclusive
  hrLow: number;               // 0 = no reading
  hrSpan: number;              // heart rate varies in [hrLow, hrLow + hrSpan]
  stepsPerMin: number;
  charging: boolean;

  constructor(fromMin: number, toMin: number, hrLow: number, hrSpan: number, stepsPerMin: number,
    charging: boolean) {
    this.fromMin = fromMin;
    this.toMin = toMin;
    this.hrLow = hrLow;
    this.hrSpan = hrSpan;
    this.stepsPerMin = stepsPerMin;
    this.charging = charging;
  }
}

function at(hour: number, minute: number): number {
  return hour * 60 + minute;
}

// One day, the same every day. Illustrative values, not measurements of anyone.
const SCRIPT: FeedStretch[] = [
  new FeedStretch(at(0, 0), at(5, 30), 0, 0, 0, true),          // on the charger overnight
  new FeedStretch(at(5, 30), at(7, 0), 54, 5, 0, false),        // worn, asleep
  new FeedStretch(at(7, 0), at(8, 30), 66, 9, 12, false),       // morning at home
  new FeedStretch(at(8, 30), at(9, 0), 104, 14, 105, false),    // brisk walk
  new FeedStretch(at(9, 0), at(12, 0), 64, 10, 6, false),       // desk
  new FeedStretch(at(12, 0), at(15, 0), 0, 0, 0, false),        // the one break: watch taken off, 3 h
  new FeedStretch(at(15, 0), at(18, 0), 66, 12, 9, false),      // afternoon
  new FeedStretch(at(18, 0), at(19, 0), 124, 22, 70, false),    // workout
  new FeedStretch(at(19, 0), at(23, 0), 60, 10, 4, false),      // evening
  new FeedStretch(at(23, 0), at(24, 0), 0, 0, 0, true)          // back on the charger
];

export const MINUTES_PER_DAY: number = 1440;

/** The built-in day: night on the charger, worn hours, one break 12:00–15:00, a walk and a workout. */
export const BUILT_IN_SCRIPT: FeedStretch[] = SCRIPT;

/** The Want parameter Health Sim's watch module answers with. */
export const HEALTH_SIM_WATCH_PARAM: string = 'fwhsw1';
export const FEED_SOURCE_BUILT_IN: string = 'built in';
export const FEED_SOURCE_HEALTH_SIM: string = 'Health Sim';
const WATCH_SCRIPT_VERSION: number = 1;
const WATCH_SCRIPT_MAX_CHARS: number = 20000;
const MAX_STRETCHES: number = 96;
const STRETCH_FIELDS: number = 6;
const MAX_HR_LOW: number = 230;
const MAX_HR_SPAN: number = 100;
const MAX_STEPS_PER_MIN: number = 300;

let activeScript: FeedStretch[] = SCRIPT;
let activeSource: string = FEED_SOURCE_BUILT_IN;

/** Puts a script in use; null goes back to the built-in one. */
export function setFeedScript(stretches: FeedStretch[] | null, source: string = FEED_SOURCE_HEALTH_SIM): void {
  if (stretches === null || stretches.length === 0) {
    activeScript = SCRIPT;
    activeSource = FEED_SOURCE_BUILT_IN;
    return;
  }
  activeScript = stretches;
  activeSource = source;
}

/** Where the script in use came from: FEED_SOURCE_HEALTH_SIM or FEED_SOURCE_BUILT_IN. */
export function feedScriptSource(): string {
  return activeSource;
}

/** The script as Health Sim's watch module sends it. */
export function encodeWatchScript(stretches: FeedStretch[]): string {
  const rows: string[] = [];
  for (let i = 0; i < stretches.length; i++) {
    const s = stretches[i];
    rows.push(`[${s.fromMin},${s.toMin},${s.hrLow},${s.hrSpan},${s.stepsPerMin},${s.charging ? 1 : 0}]`);
  }
  return `{"v":${WATCH_SCRIPT_VERSION},"source":${JSON.stringify(FEED_SOURCE_HEALTH_SIM)},` +
    `"stretches":[${rows.join(',')}]}`;
}

function intIn(v: Object, min: number, max: number): number | null {
  if (typeof v !== 'number' || !Number.isInteger(v as number)) {
    return null;
  }
  const n = v as number;
  return n < min || n > max ? null : n;
}

/**
 * The script from Health Sim's text, or null. Strict: the stretches cover the whole day from 00:00 to
 * 24:00 in order, with no gap and no overlap, and every value is in range. Never throws.
 */
export function decodeWatchScript(text: string): FeedStretch[] | null {
  if (text.length === 0 || text.length > WATCH_SCRIPT_MAX_CHARS) {
    return null;
  }
  const o = parseJsonObject(text);
  if (o === null) {
    return null;
  }
  const rows = readArray(o, 'stretches');
  if (readInt(o, 'v') !== WATCH_SCRIPT_VERSION || readString(o, 'source') === null || rows === null ||
    rows.length === 0 || rows.length > MAX_STRETCHES) {
    return null;
  }
  const out: FeedStretch[] = [];
  let expectedFrom = 0;
  for (let i = 0; i < rows.length; i++) {
    const raw: Object = rows[i];
    if (raw === undefined || raw === null || !Array.isArray(raw) || asObject(raw) !== null) {
      return null;
    }
    const r = raw as Object[];
    if (r.length !== STRETCH_FIELDS) {
      return null;
    }
    const fromMin = intIn(r[0], 0, MINUTES_PER_DAY);
    const toMin = intIn(r[1], 0, MINUTES_PER_DAY);
    const hrLow = intIn(r[2], 0, MAX_HR_LOW);
    const hrSpan = intIn(r[3], 0, MAX_HR_SPAN);
    const steps = intIn(r[4], 0, MAX_STEPS_PER_MIN);
    const charging = intIn(r[5], 0, 1);
    if (fromMin === null || toMin === null || hrLow === null || hrSpan === null || steps === null ||
      charging === null || fromMin !== expectedFrom || toMin <= fromMin) {
      return null;
    }
    out.push(new FeedStretch(fromMin, toMin, hrLow, hrSpan, steps, charging === 1));
    expectedFrom = toMin;
  }
  return expectedFrom === MINUTES_PER_DAY ? out : null;
}

/** The scripted reading for one minute of the local day (0..1439). Deterministic: no random numbers. */
export function demoFeedAt(minuteOfDay: number): DemoFeedSample {
  const minute = ((Math.floor(minuteOfDay) % MINUTES_PER_DAY) + MINUTES_PER_DAY) % MINUTES_PER_DAY;
  const out = new DemoFeedSample();
  for (let i = 0; i < activeScript.length; i++) {
    const s = activeScript[i];
    if (minute >= s.fromMin && minute < s.toMin) {
      out.charging = s.charging;
      out.stepsPerMin = s.stepsPerMin;
      if (s.hrLow > 0) {
        // A fixed zig-zag inside the stretch's range, so the line is not flat.
        out.hr = s.hrLow + ((minute * 7) % (s.hrSpan + 1));
      }
      return out;
    }
  }
  return out;
}

/** Steps for a stretch of recorder time ending at `minuteOfDay`, at that minute's rate. Never negative. */
export function demoFeedSteps(minuteOfDay: number, elapsedMinutes: number): number {
  if (elapsedMinutes <= 0) {
    return 0;
  }
  // One tick never stands for more than 30 recorder minutes of walking.
  const minutes = elapsedMinutes > 30 ? 30 : elapsedMinutes;
  return Math.round(demoFeedAt(minuteOfDay).stepsPerMin * minutes);
}

/** "DEMO_X300" becomes "DEMO_X300_FEED". A label that already has the suffix is returned unchanged. */
export function feedClockLabel(speedLabel: string): string {
  return speedLabel.endsWith(CLOCK_FEED_SUFFIX) ? speedLabel : speedLabel + CLOCK_FEED_SUFFIX;
}
