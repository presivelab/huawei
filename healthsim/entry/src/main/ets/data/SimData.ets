import {
  HealthScope,
  healthSimReadiness,
  HealthSimReadiness,
  HesCrfEstimate,
  HesDayRecord,
  HesHistory,
  HesHrrSession,
  hesHoursText,
  hesOrdinal,
  hesThousands,
  HesPersonas
} from 'common';

/*
 * What the Health Sim screens show: the people of the simulation and their days, read from FairWear's own
 * persona generator in the common package (healthsim/libs/common.har). Nothing is calculated here beyond
 * picking days and writing numbers as text. A reading that does not exist is an absent field in the data
 * and "—" on screen, never zero.
 */

/** A value that was not measured. Shown instead of a number, never as zero. */
export const NO_VALUE: string = '—';
/** The daily goals the two rings of "Activity records" are drawn against. Display only. */
export const STEPS_GOAL: number = 10000;
export const EXERCISE_GOAL_MIN: number = 30;
/** How many days the small bars of a metric card show. */
export const RECENT_DAYS: number = 7;
/**
 * The demo heart rate shown as "Live": the resting value of the running day plus this fixed offset. It is
 * a static value, not a measurement.
 */
const LIVE_HR_OFFSET: number = 6;
const MINUTES_PER_HOUR: number = 60;
const MINUTES_PER_DAY: number = 1440;

/** The metrics Health Sim shows. One id per card and per detail page. */
export const METRIC_STEPS: string = 'steps';
export const METRIC_EXERCISE: string = 'exercise';
export const METRIC_HEART: string = 'heart';
export const METRIC_RESTING: string = 'resting';
export const METRIC_SLEEP: string = 'sleep';
export const METRIC_VO2MAX: string = 'vo2max';
export const METRIC_HRV: string = 'hrv';

const WEEKDAYS: string[] = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MONTHS: string[] = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct',
  'Nov', 'Dec'];

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
  share: number;   // 0..100, the row against the highest row of the list; 0 when not measured
}

/** The running day as the "Activity records" card shows it. */
export interface SimActivity {
  title: string;          // "Today · Sun 4 Oct"
  steps: string;
  exercise: string;       // moderate + vigorous minutes, for the ring
  intensity: string;      // "moderate / vigorous", e.g. "26 / 4 min"
  stepsShare: number;     // 0..100 of STEPS_GOAL; 0 when not measured
  exerciseShare: number;  // 0..100 of EXERCISE_GOAL_MIN; 0 when not measured
}

/** One card of the Health tab. */
export interface SimCard {
  metric: string;
  value: string;   // NO_VALUE when not measured
  sub: string;     // the line under the value
  bars: number[];  // 0..100 per day, oldest first; -1 = not measured that day; empty = no bars
}

/** One completed day of the History list, every field already written as text ("—" = not measured). */
export interface SimHistoryDay {
  date: string;
  title: string;
  steps: string;
  moderate: string;
  vigorous: string;
  resting: string;
  sleepClock: string;   // "22:45–06:45"
  sleepTotal: string;   // "8 h"
  hrv: string;          // "60th percentile"
}

export interface SimCrfRow {
  date: string;
  title: string;
  text: string;         // "77th percentile"
}

export interface SimHrrRow {
  date: string;
  title: string;
  protocol: string;
  detail: string;       // "peak 150 → 118 after 60 s"
  drop: string;         // "HRR1 32 bpm"
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

/** 448 -> "7 h 28 min". */
export function hoursMinutes(minutes: number): string {
  return hesHoursText(minutes / MINUTES_PER_HOUR);
}

/** 405 -> "06:45". */
export function clockText(minuteOfDay: number): string {
  const total = ((Math.round(minuteOfDay) % MINUTES_PER_DAY) + MINUTES_PER_DAY) % MINUTES_PER_DAY;
  const h = Math.floor(total / MINUTES_PER_HOUR);
  const m = total % MINUTES_PER_HOUR;
  return `${h < 10 ? '0' : ''}${h}:${m < 10 ? '0' : ''}${m}`;
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

function completedDays(id: string): HesDayRecord[] {
  return HesPersonas.history(id).days;
}

/** Moderate plus vigorous minutes; absent only when both are absent. */
function exerciseMinutes(day: HesDayRecord): number | undefined {
  const moderate = day.moderateMin;
  const vigorous = day.vigorousMin;
  if (moderate === undefined && vigorous === undefined) {
    return undefined;
  }
  return (moderate === undefined ? 0 : moderate) + (vigorous === undefined ? 0 : vigorous);
}

/** The number a metric has on a day; undefined when it was not measured. */
function dayNumber(day: HesDayRecord, metric: string): number | undefined {
  if (metric === METRIC_STEPS) {
    return day.steps;
  }
  if (metric === METRIC_EXERCISE) {
    return exerciseMinutes(day);
  }
  if (metric === METRIC_HEART || metric === METRIC_RESTING) {
    return day.restingHr;
  }
  if (metric === METRIC_SLEEP) {
    const sleep = day.sleep;
    return sleep === undefined ? undefined : sleep.totalSleepMin;
  }
  if (metric === METRIC_HRV) {
    const hrv = day.hrv;
    return hrv === undefined ? undefined : hrv.percentile;
  }
  return undefined;
}

/** The number as a screen writes it, without its unit. A missing value is NO_VALUE, never zero. */
function metricText(metric: string, n: number | undefined): string {
  if (n === undefined) {
    return NO_VALUE;
  }
  if (metric === METRIC_STEPS) {
    return hesThousands(n);
  }
  if (metric === METRIC_SLEEP) {
    return hoursMinutes(n);
  }
  if (metric === METRIC_VO2MAX || metric === METRIC_HRV) {
    return hesOrdinal(n);
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
  if (metric === METRIC_HEART || metric === METRIC_RESTING) {
    return 'bpm';
  }
  if (metric === METRIC_VO2MAX || metric === METRIC_HRV) {
    return 'percentile';
  }
  return '';
}

function shareOf(n: number | undefined, top: number): number {
  return n === undefined || top <= 0 ? 0 : Math.min(100, Math.round(n * 100 / top));
}

function newestFirst(a: string, b: string): number {
  return a < b ? 1 : (a > b ? -1 : 0);
}

/** The VO2max estimates, newest first. */
function crfNewestFirst(history: HesHistory): HesCrfEstimate[] {
  return history.crf.slice().sort((a: HesCrfEstimate, b: HesCrfEstimate) => newestFirst(a.date, b.date));
}

/** A metric over time: dates and values, oldest first. VO2max comes from the estimates, the rest from the days. */
class Series {
  dates: string[] = [];
  values: (number | undefined)[] = [];
}

function seriesOf(id: string, metric: string): Series {
  const out = new Series();
  if (metric === METRIC_VO2MAX) {
    const crf = crfNewestFirst(HesPersonas.history(id));
    for (let i = crf.length - 1; i >= 0; i--) {
      out.dates.push(crf[i].date);
      out.values.push(crf[i].percentile);
    }
    return out;
  }
  const days = completedDays(id);
  for (let i = 0; i < days.length; i++) {
    out.dates.push(days[i].date);
    out.values.push(dayNumber(days[i], metric));
  }
  return out;
}

function topOf(values: (number | undefined)[], from: number): number {
  let top = 0;
  for (let i = from; i < values.length; i++) {
    const v = values[i];
    if (v !== undefined) {
      top = Math.max(top, v);
    }
  }
  return top;
}

/** One metric over the completed days (VO2max: over the estimates), newest first. */
export function simMetricRows(id: string, metric: string): SimMetricRow[] {
  const series = seriesOf(id, metric);
  const top = topOf(series.values, 0);
  const out: SimMetricRow[] = [];
  for (let i = series.values.length - 1; i >= 0; i--) {
    out.push({
      date: series.dates[i],
      title: dayTitle(series.dates[i]),
      value: metricText(metric, series.values[i]),
      share: shareOf(series.values[i], top)
    });
  }
  return out;
}

/**
 * The last `RECENT_DAYS` completed days of a metric as bar heights 0..100 against the highest of them,
 * oldest first. A day that was not measured is -1, so the card leaves its bar out instead of drawing zero.
 */
export function simRecentBars(id: string, metric: string): number[] {
  const values = seriesOf(id, metric).values;
  const first = Math.max(0, values.length - RECENT_DAYS);
  const top = topOf(values, first);
  const out: number[] = [];
  for (let i = first; i < values.length; i++) {
    out.push(values[i] === undefined ? -1 : shareOf(values[i], top));
  }
  return out;
}

/** The running day for the "Activity records" card. */
export function simActivity(id: string): SimActivity {
  const day = HesPersonas.today(id);
  const steps = day.steps;
  const exercise = exerciseMinutes(day);
  const moderate = day.moderateMin;
  const vigorous = day.vigorousMin;
  return {
    title: `Today · ${dayTitle(day.date)}`,
    steps: metricText(METRIC_STEPS, steps),
    exercise: metricText(METRIC_EXERCISE, exercise),
    intensity: `${moderate === undefined ? NO_VALUE : Math.round(moderate)} / ` +
      `${vigorous === undefined ? NO_VALUE : Math.round(vigorous)}`,
    stepsShare: shareOf(steps, STEPS_GOAL),
    exerciseShare: shareOf(exercise, EXERCISE_GOAL_MIN)
  };
}

function sleepClock(day: HesDayRecord): string {
  const sleep = day.sleep;
  return sleep === undefined ? NO_VALUE : `${clockText(sleep.bedMin)}–${clockText(sleep.wakeMin)}`;
}

/** The static demo value shown as "Live": today's resting heart rate plus a fixed offset. */
function liveHeartRate(id: string): number | undefined {
  const resting = HesPersonas.today(id).restingHr;
  return resting === undefined ? undefined : resting + LIVE_HR_OFFSET;
}

/** One card of the Health tab for the running day (the bars come from the completed days). */
export function simCard(id: string, metric: string): SimCard {
  const day = HesPersonas.today(id);
  if (metric === METRIC_HEART) {
    return { metric: metric, value: metricText(metric, liveHeartRate(id)), sub: 'Live', bars: [] };
  }
  if (metric === METRIC_SLEEP) {
    const sleep = day.sleep;
    return {
      metric: metric,
      value: metricText(metric, sleep === undefined ? undefined : sleep.totalSleepMin),
      sub: sleep === undefined ? 'Last night' : `Last night · ${sleepClock(day)}`,
      bars: simRecentBars(id, metric)
    };
  }
  if (metric === METRIC_EXERCISE) {
    const intensity = simActivity(id).intensity;
    return {
      metric: metric,
      value: intensity,
      sub: 'Moderate / vigorous · today',
      bars: simRecentBars(id, metric)
    };
  }
  if (metric === METRIC_VO2MAX) {
    const crf = crfNewestFirst(HesPersonas.history(id));
    return {
      metric: metric,
      value: crf.length === 0 ? NO_VALUE : metricText(metric, crf[0].percentile),
      sub: crf.length === 0 ? 'Not measured' : `Newest estimate · ${dayTitle(crf[0].date)}`,
      bars: []
    };
  }
  if (metric === METRIC_HRV) {
    const value = metricText(metric, dayNumber(day, metric));
    return { metric: metric, value: value, sub: value === NO_VALUE ? 'Not measured' : 'Last night', bars: [] };
  }
  return {
    metric: metric,
    value: metricText(metric, dayNumber(day, metric)),
    sub: metric === METRIC_STEPS ? 'Today so far' : 'Resting · today',
    bars: simRecentBars(id, metric)
  };
}

/** The value written with its unit; "—" stays "—". */
function withUnit(text: string, unit: string): string {
  return text === NO_VALUE ? text : `${text} ${unit}`;
}

/** The completed days, newest first, as text. */
export function simHistoryDays(id: string): SimHistoryDay[] {
  const days = completedDays(id);
  const out: SimHistoryDay[] = [];
  for (let i = days.length - 1; i >= 0; i--) {
    const day = days[i];
    const sleep = day.sleep;
    const moderate = day.moderateMin;
    const vigorous = day.vigorousMin;
    const hrv = metricText(METRIC_HRV, dayNumber(day, METRIC_HRV));
    out.push({
      date: day.date,
      title: dayTitle(day.date),
      steps: withUnit(metricText(METRIC_STEPS, day.steps), 'steps'),
      moderate: moderate === undefined ? NO_VALUE : `${Math.round(moderate)}`,
      vigorous: vigorous === undefined ? NO_VALUE : `${Math.round(vigorous)}`,
      resting: withUnit(metricText(METRIC_RESTING, day.restingHr), 'bpm'),
      sleepClock: sleepClock(day),
      sleepTotal: sleep === undefined ? NO_VALUE : hoursMinutes(sleep.totalSleepMin),
      hrv: withUnit(hrv, 'percentile')
    });
  }
  return out;
}

export function simCrfRows(id: string): SimCrfRow[] {
  const crf = crfNewestFirst(HesPersonas.history(id));
  const out: SimCrfRow[] = [];
  for (let i = 0; i < crf.length; i++) {
    out.push({
      date: crf[i].date,
      title: dayTitle(crf[i].date),
      text: `${hesOrdinal(crf[i].percentile)} percentile`
    });
  }
  return out;
}

export function simHrrRows(id: string): SimHrrRow[] {
  const sessions: HesHrrSession[] =
    HesPersonas.history(id).hrr.slice().sort((a: HesHrrSession, b: HesHrrSession) => newestFirst(a.date, b.date));
  const out: SimHrrRow[] = [];
  for (let i = 0; i < sessions.length; i++) {
    const s = sessions[i];
    out.push({
      date: s.date,
      title: dayTitle(s.date),
      protocol: s.protocolId,
      detail: `peak ${s.peakHr} → ${s.hr60} after 60 s`,
      drop: `HRR1 ${s.peakHr - s.hr60} bpm`
    });
  }
  return out;
}

/** The Scenario tool's model for a person, from the same engine FairWear uses. */
export function simReadiness(id: string): HealthSimReadiness {
  return healthSimReadiness(HesPersonas.history(id));
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
