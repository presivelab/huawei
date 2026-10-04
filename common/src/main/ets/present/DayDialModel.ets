// The 24-hour dial of the Report screen, as pure geometry and text.
//
// Input: the newest completed day of the report (sleep start and end, sleep minutes, steps), the wear
// segments of a day the watch sent (when the phone has one) and the current local minute.
// Output: arcs in degrees, the angle of the "now" marker and the text in the middle.
//
// The dial is a picture of facts the app already holds. Nothing here is scored and nothing is invented:
// there is no hourly distribution of steps, only the day's total, and a missing value is said, not drawn.
import { hesIsValidNight, hesIsValidValue } from '../hes/HesAggregate';
import { HesDayRecord } from '../hes/HesTypes';
import { SlotRun } from './TourContent';
import { WEAR_CHARGING, WEAR_OFF, WEAR_WORN } from './WatchDayPresent';

export const DIAL_DAY_MINUTES: number = 1440;
export const DIAL_FULL_DEG: number = 360;
const DEG_PER_MINUTE: number = DIAL_FULL_DEG / DIAL_DAY_MINUTES;
const SLOT_MINUTES: number = 5;

export const DIAL_SLEEP: string = 'SLEEP';
export const DIAL_WORN: string = 'WORN';
export const DIAL_CHARGING: string = 'CHARGING';
export const DIAL_OFF: string = 'OFF';

export const DIAL_LABEL_SLEEP: string = 'Sleep';
export const DIAL_LABEL_WORN: string = 'Worn';
export const DIAL_LABEL_CHARGING: string = 'Charging';
export const DIAL_LABEL_OFF: string = 'Off wrist';

export const DIAL_SLEEP_NOT_MEASURED: string = 'Sleep not measured';
export const DIAL_NO_WEAR_SEGMENTS: string = 'Wear segments appear when the watch sends a day';
export const DIAL_STEPS_NOT_MEASURED: string = 'Steps not measured';
export const DIAL_STEPS_UNIT: string = 'steps';
export const DIAL_NO_VALUE: string = '—';
export const DIAL_TITLE: string = '24-hour day';
export const DIAL_DEMO_NOTE: string = 'Before launch: demo data';
export const DIAL_NOW_NOTE: string = 'The marker is the time now. Shown, never scored.';
/** The four labelled ticks of the dial: midnight at the top, then clockwise. */
export const DIAL_TICK_LABELS: string[] = ['00', '06', '12', '18'];

/** One arc of the dial. 0° is 00:00 at the top; angles grow clockwise; 15° is one hour. */
export class DialArc {
  startDeg: number;     // 0 <= startDeg < 360
  sweepDeg: number;     // 0 < sweepDeg <= 360; an arc that passes midnight runs past 360 in one piece
  kind: string;         // DIAL_SLEEP, DIAL_WORN, DIAL_CHARGING or DIAL_OFF

  constructor(startDeg: number, sweepDeg: number, kind: string) {
    this.startDeg = startDeg;
    this.sweepDeg = sweepDeg;
    this.kind = kind;
  }
}

/** A stretch of one wear state inside a day, in minutes since local midnight. */
export class DialSegment {
  startMin: number;
  minutes: number;
  kind: string;         // DIAL_WORN, DIAL_CHARGING or DIAL_OFF

  constructor(startMin: number, minutes: number, kind: string) {
    this.startMin = startMin;
    this.minutes = minutes;
    this.kind = kind;
  }
}

export class DayDial {
  sleepArcs: DialArc[] = [];
  wearArcs: DialArc[] = [];
  nowDeg: number = 0;
  centerValue: string = DIAL_NO_VALUE;      // "7,954", or "—" when the day has no step count
  centerUnit: string = DIAL_STEPS_UNIT;
  centerText: string = DIAL_STEPS_NOT_MEASURED;   // "7,954 steps", or "Steps not measured"
  sleepNote: string = DIAL_SLEEP_NOT_MEASURED;    // "Sleep 23:30–07:10", or "Sleep not measured"
  wearNote: string = DIAL_NO_WEAR_SEGMENTS;       // empty when wear arcs are drawn
  legend: string[] = [];                    // the kinds that are drawn, in drawing order
  spoken: string = '';                      // one sentence for a screen reader
}

function wrapMinute(minute: number): number {
  const whole = Math.floor(minute);
  return ((whole % DIAL_DAY_MINUTES) + DIAL_DAY_MINUTES) % DIAL_DAY_MINUTES;
}

function two(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

function clock(minute: number): string {
  const m = wrapMinute(minute);
  return `${two(Math.floor(m / 60))}:${two(m % 60)}`;
}

/** Minutes since local midnight as an angle: 00:00 is 0°, 06:00 is 90°, 23:59 is 359.75°. */
export function minuteToDeg(minute: number): number {
  return wrapMinute(minute) * DEG_PER_MINUTE;
}

/** 7954 as "7,954". A negative value (no reading) gives "—". */
export function groupedNumber(value: number): string {
  if (value < 0 || isNaN(value)) {
    return DIAL_NO_VALUE;
  }
  const digits = `${Math.round(value)}`;
  let out = '';
  for (let i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 === 0) {
      out += ',';
    }
    out += digits.charAt(i);
  }
  return out;
}

/**
 * The sleep arc of a day, or nothing when the night was not measured. A night that starts before
 * midnight (23:30 to 07:10) is one arc that begins at 352.5° and runs 115° through 0°.
 */
export function sleepArcs(day: HesDayRecord | null): DialArc[] {
  if (day === null) {
    return [];
  }
  const sleep = day.sleep;
  if (sleep === undefined || !hesIsValidNight(sleep) || sleep.totalSleepMin <= 0) {
    return [];
  }
  const start = wrapMinute(sleep.bedMin);
  const end = wrapMinute(sleep.wakeMin);
  let span = end - start;
  if (span <= 0) {
    span += DIAL_DAY_MINUTES;
  }
  return [new DialArc(start * DEG_PER_MINUTE, span * DEG_PER_MINUTE, DIAL_SLEEP)];
}

function dialKind(wearState: string): string {
  if (wearState === WEAR_WORN) {
    return DIAL_WORN;
  }
  if (wearState === WEAR_CHARGING) {
    return DIAL_CHARGING;
  }
  return wearState === WEAR_OFF ? DIAL_OFF : '';
}

/** The runs of a received watch day (five-minute slots) as segments; not-observed time is left out. */
export function dialSegmentsOfRuns(runs: SlotRun[]): DialSegment[] {
  const out: DialSegment[] = [];
  let minute = 0;
  for (let i = 0; i < runs.length; i++) {
    const minutes = runs[i].count * SLOT_MINUTES;
    const kind = dialKind(runs[i].state);
    if (kind.length > 0 && minutes > 0) {
      out.push(new DialSegment(minute, minutes, kind));
    }
    minute += minutes;
  }
  return out;
}

/** One arc per segment, in the order given. Segments of an unknown kind or without length are skipped. */
export function wearArcs(segments: DialSegment[]): DialArc[] {
  const out: DialArc[] = [];
  for (let i = 0; i < segments.length; i++) {
    const s = segments[i];
    if (s.minutes <= 0 || (s.kind !== DIAL_WORN && s.kind !== DIAL_CHARGING && s.kind !== DIAL_OFF)) {
      continue;
    }
    const minutes = Math.min(s.minutes, DIAL_DAY_MINUTES);
    out.push(new DialArc(minuteToDeg(s.startMin), minutes * DEG_PER_MINUTE, s.kind));
  }
  return out;
}

export function dialKindLabel(kind: string): string {
  if (kind === DIAL_SLEEP) {
    return DIAL_LABEL_SLEEP;
  }
  if (kind === DIAL_WORN) {
    return DIAL_LABEL_WORN;
  }
  return kind === DIAL_CHARGING ? DIAL_LABEL_CHARGING : DIAL_LABEL_OFF;
}

/**
 * The dial of one day. `day` is the newest completed day of the report (null: no day yet), `segments`
 * the wear segments of a day the watch sent (empty: the phone has none), `nowMin` the current local
 * minute of the day.
 */
export function dayDial(day: HesDayRecord | null, segments: DialSegment[], nowMin: number): DayDial {
  const dial = new DayDial();
  dial.nowDeg = minuteToDeg(nowMin);

  dial.sleepArcs = sleepArcs(day);
  const sleep = day === null ? undefined : day.sleep;
  if (sleep !== undefined && dial.sleepArcs.length > 0) {
    dial.sleepNote = `${DIAL_LABEL_SLEEP} ${clock(sleep.bedMin)}–${clock(sleep.wakeMin)}`;
    dial.legend.push(DIAL_SLEEP);
  }

  const steps = day === null ? undefined : day.steps;
  if (steps !== undefined && hesIsValidValue(steps)) {
    dial.centerValue = groupedNumber(steps);
    dial.centerText = `${dial.centerValue} ${DIAL_STEPS_UNIT}`;
  }

  dial.wearArcs = wearArcs(segments);
  if (dial.wearArcs.length > 0) {
    dial.wearNote = '';
    const order: string[] = [DIAL_WORN, DIAL_CHARGING, DIAL_OFF];
    for (let k = 0; k < order.length; k++) {
      for (let i = 0; i < dial.wearArcs.length; i++) {
        if (dial.wearArcs[i].kind === order[k]) {
          dial.legend.push(order[k]);
          break;
        }
      }
    }
  }

  const parts: string[] = [dial.centerText, dial.sleepNote];
  if (dial.wearNote.length > 0) {
    parts.push(dial.wearNote);
  }
  dial.spoken = `Day dial. ${parts.join('. ')}. Now ${clock(nowMin)}`;
  return dial;
}
