import { HealthScope } from '../fw/health/HealthConnection';
import { HES_MISSING, HesDay } from '../fw/hes/HesTypes';
import { HesPersonas } from '../fw/hes/HesPersonas';

/*
 * What the Health Sim screens show: the people of the simulation and their days, read from the same
 * persona generator FairWear uses (the files under ../fw are copies of FairWear's `common`).
 * Nothing is calculated here beyond picking days and writing numbers as text.
 */

export const HISTORY_DAYS: number = 30;
/** A value that was not measured. Shown instead of a number, never as zero. */
export const NO_VALUE: string = '—';
/** The daily goals the two rings of "Activity records" are drawn against. Display only. */
export const STEPS_GOAL: number = 10000;
export const EXERCISE_GOAL_MIN: number = 30;
/** How many days the small bars of a metric card show. */
export const RECENT_DAYS: number = 7;

/** The metrics Health Sim shows. One id per card and per detail page. */
export const METRIC_STEPS: string = 'steps';
export const METRIC_EXERCISE: string = 'exercise';
export const METRIC_HEART: string = 'heart';
export const METRIC_SLEEP: string = 'sleep';
export const METRIC_VO2MAX: string = 'vo2max';
export const METRIC_HRV: string = 'hrv';

const MINUTES_PER_HOUR: number = 60;
const WEEKDAYS: string[] = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MONTHS: string[] = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/** One person of the simulation, as the picker lists them. */
export interface SimPerson {
  id: string;
  name: string;
}

/** One day of one metric as a row of the detail page: the value already written as text. */
export interface SimMetricRow {
  date: string;    // "2026-10-03"
  title: string;   // "Sat 3 Oct"
  value: string;   // NO_VALUE when not measured
  share: number;   // 0..100, the day against the highest day of the list; 0 when not measured
}

/** The newest day as the "Activity records" card shows it. */
export interface SimActivity {
  title: string;          // "Sat 3 Oct"
  steps: string;
  exercise: string;
  stepsShare: number;     // 0..100 of STEPS_GOAL; 0 when not measured
  exerciseShare: number;  // 0..100 of EXERCISE_GOAL_MIN; 0 when not measured
}

export function simPeople(): SimPerson[] {
  const out: SimPerson[] = [];
  for (let i = 0; i < HesPersonas.IDS.length; i++) {
    out.push({ id: HesPersonas.IDS[i], name: HesPersonas.displayName(HesPersonas.IDS[i]) });
  }
  return out;
}

export function simPersonName(id: string): string {
  return HesPersonas.displayName(id);
}

function missing(value: number): boolean {
  return value === HES_MISSING || value < 0;
}

/** 5843 -> "5,843". */
export function grouped(n: number): string {
  let text = `${Math.floor(n)}`;
  let out = '';
  while (text.length > 3) {
    out = `,${text.substring(text.length - 3)}${out}`;
    text = text.substring(0, text.length - 3);
  }
  return text + out;
}

/** 448 -> "7 h 28 min". */
export function hoursMinutes(minutes: number): string {
  const total = Math.max(0, Math.round(minutes));
  const h = Math.floor(total / MINUTES_PER_HOUR);
  const m = total % MINUTES_PER_HOUR;
  if (h === 0) {
    return `${m} min`;
  }
  return m === 0 ? `${h} h` : `${h} h ${m} min`;
}

/** "2026-10-03" -> "Sat 3 Oct". Text that is not a date is returned as it is. */
export function dayTitle(date: string): string {
  if (date.length < 10) {
    return date;
  }
  const ms = Date.UTC(Number(date.substring(0, 4)), Number(date.substring(5, 7)) - 1,
    Number(date.substring(8, 10)));
  if (isNaN(ms)) {
    return date;
  }
  const d = new Date(ms);
  return `${WEEKDAYS[d.getUTCDay()]} ${d.getUTCDate()} ${MONTHS[d.getUTCMonth()]}`;
}

/**
 * The number a metric has on a day; HES_MISSING when it was not measured. Exercise is moderate plus
 * vigorous minutes and is missing only when both are missing.
 */
function metricNumber(day: HesDay, metric: string): number {
  if (metric === METRIC_STEPS) {
    return missing(day.steps) ? HES_MISSING : day.steps;
  }
  if (metric === METRIC_EXERCISE) {
    if (missing(day.moderateMinutes) && missing(day.vigorousMinutes)) {
      return HES_MISSING;
    }
    return Math.max(0, day.moderateMinutes) + Math.max(0, day.vigorousMinutes);
  }
  if (metric === METRIC_HEART) {
    return missing(day.restingHeartRate) ? HES_MISSING : day.restingHeartRate;
  }
  if (metric === METRIC_SLEEP) {
    return missing(day.sleepMinutes) ? HES_MISSING : day.sleepMinutes;
  }
  if (metric === METRIC_VO2MAX) {
    return missing(day.vo2maxPercentile) ? HES_MISSING : day.vo2maxPercentile;
  }
  if (metric === METRIC_HRV) {
    return missing(day.hrvPercentile) ? HES_MISSING : day.hrvPercentile;
  }
  return HES_MISSING;
}

/** The number as a screen writes it, without its unit. A missing value is NO_VALUE, never zero. */
function metricText(metric: string, n: number): string {
  if (missing(n)) {
    return NO_VALUE;
  }
  if (metric === METRIC_STEPS) {
    return grouped(n);
  }
  if (metric === METRIC_SLEEP) {
    return hoursMinutes(n);
  }
  return `${Math.round(n)}`;
}

/** The unit written after a value; sleep carries its units in the value ("7 h 28 min"). */
export function metricUnit(metric: string): string {
  if (metric === METRIC_STEPS) {
    return 'steps';
  }
  if (metric === METRIC_EXERCISE) {
    return 'min';
  }
  if (metric === METRIC_HEART) {
    return 'bpm';
  }
  if (metric === METRIC_VO2MAX || metric === METRIC_HRV) {
    return 'percentile';
  }
  return '';
}

function lastDays(id: string): HesDay[] {
  const days: HesDay[] = HesPersonas.history(id);
  return days.slice(Math.max(0, days.length - HISTORY_DAYS));
}

function shareOf(n: number, top: number): number {
  return missing(n) || top <= 0 ? 0 : Math.min(100, Math.round(n * 100 / top));
}

/** The newest day's value of a metric as text; NO_VALUE for an unknown id or a day without it. */
export function simMetricToday(id: string, metric: string): string {
  const days = lastDays(id);
  return days.length === 0 ? NO_VALUE : metricText(metric, metricNumber(days[days.length - 1], metric));
}

/** One metric over the last `HISTORY_DAYS` days, newest first. An unknown id gives an empty list. */
export function simMetricRows(id: string, metric: string): SimMetricRow[] {
  const days = lastDays(id);
  let top = 0;
  for (let i = 0; i < days.length; i++) {
    top = Math.max(top, metricNumber(days[i], metric));
  }
  const out: SimMetricRow[] = [];
  for (let i = days.length - 1; i >= 0; i--) {
    const n = metricNumber(days[i], metric);
    out.push({
      date: days[i].date,
      title: dayTitle(days[i].date),
      value: metricText(metric, n),
      share: shareOf(n, top)
    });
  }
  return out;
}

/**
 * The last `RECENT_DAYS` days of a metric as bar heights 0..100 against the highest of them, oldest
 * first. A day that was not measured is -1, so the card leaves its bar out instead of drawing zero.
 */
export function simRecentBars(id: string, metric: string): number[] {
  const days = lastDays(id);
  const first = Math.max(0, days.length - RECENT_DAYS);
  let top = 0;
  for (let i = first; i < days.length; i++) {
    top = Math.max(top, metricNumber(days[i], metric));
  }
  const out: number[] = [];
  for (let i = first; i < days.length; i++) {
    const n = metricNumber(days[i], metric);
    out.push(missing(n) ? -1 : shareOf(n, top));
  }
  return out;
}

/** The newest day for the "Activity records" card; null for an unknown id. */
export function simActivity(id: string): SimActivity | null {
  const days = lastDays(id);
  if (days.length === 0) {
    return null;
  }
  const day = days[days.length - 1];
  const steps = metricNumber(day, METRIC_STEPS);
  const exercise = metricNumber(day, METRIC_EXERCISE);
  return {
    title: dayTitle(day.date),
    steps: metricText(METRIC_STEPS, steps),
    exercise: metricText(METRIC_EXERCISE, exercise),
    stepsShare: shareOf(steps, STEPS_GOAL),
    exerciseShare: shareOf(exercise, EXERCISE_GOAL_MIN)
  };
}

/** The readable name of a data type FairWear can ask for. Empty for a name Health Sim does not know. */
export function scopeLabel(scope: string): string {
  if (scope === HealthScope.STEPS) {
    return 'Steps';
  }
  if (scope === HealthScope.RESTING_HEART_RATE) {
    return 'Resting heart rate';
  }
  if (scope === HealthScope.SLEEP) {
    return 'Sleep';
  }
  if (scope === HealthScope.ACTIVITY_MINUTES) {
    return 'Exercise';
  }
  if (scope === HealthScope.VO2MAX) {
    return 'VO₂max';
  }
  if (scope === HealthScope.HRV) {
    return 'Heart rate variability';
  }
  if (scope === HealthScope.WORKOUTS) {
    return 'Workouts (heart-rate recovery)';
  }
  return '';
}

/** The scope behind a name from a request; null for a name Health Sim does not know. */
export function scopeOf(name: string): HealthScope | null {
  const all: HealthScope[] = [HealthScope.STEPS, HealthScope.RESTING_HEART_RATE, HealthScope.SLEEP,
    HealthScope.ACTIVITY_MINUTES, HealthScope.VO2MAX, HealthScope.HRV, HealthScope.WORKOUTS];
  for (let i = 0; i < all.length; i++) {
    if (all[i] === name) {
      return all[i];
    }
  }
  return null;
}
