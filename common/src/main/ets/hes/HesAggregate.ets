// From a history of completed days to one raw value per component (specification sections 3 and 4).
//
// Which data counts:
//   - a value is valid when it is present, finite and not negative. What is physiologically plausible is
//     decided by the source (the device or its API), not here;
//   - nothing is interpolated, filled in or extrapolated: a missing day is left out, never counted as zero;
//   - windows are calendar days back from the last completed day (0 = that day): steps, MVPA, resting heart
//     rate and sleep 0..27, HRV 0..13, heart-rate recovery 0..59, VO2max 0..89;
//   - with no completed day there is no reference day, so nothing is inside any window.
import { dayNumberOfDate } from '../watchlink/WatchLinkTypes';
import {
  HES_CRF_WINDOW_DAYS,
  HES_DAYS_PER_WEEK,
  HES_HRR_WINDOW_DAYS,
  HES_HRV_WINDOW_DAYS,
  HES_MINUTES_PER_DAY,
  HES_MINUTES_PER_HOUR,
  HES_SLEEP_ANCHOR_MIN,
  HES_VIGOROUS_FACTOR,
  HES_WINDOW_DAYS,
  HRV_PROTOCOL
} from './HesModel';
import { ComponentId, HesDayRecord, HesHistory, HesHrvNight, HesSleep } from './HesTypes';

/** The aggregated raw value of one component and how many valid observations stand behind it. */
export interface HesAggregateValue {
  raw?: number;        // absent when there is no valid observation in the window
  validCount: number;
}

export interface HesAggregates {
  crf: HesAggregateValue;              // newest valid VO2max percentile
  rhr: HesAggregateValue;              // median daily resting heart rate, bpm
  mvpa: HesAggregateValue;             // equivalent minutes per week
  steps: HesAggregateValue;            // mean steps per day
  sleepRegularity: HesAggregateValue;  // timing SD, minutes
  sleepDuration: HesAggregateValue;    // median total sleep, hours
  hrv: HesAggregateValue;              // median nightly percentile
  hrr: HesAggregateValue;              // median drop in the first 60 seconds, bpm
}

const NOT_VALID: number = -1;

/** The value when it is present, finite and not negative; NOT_VALID otherwise. */
function validNumber(value: number | undefined | null): number {
  if (value === undefined || value === null || !Number.isFinite(value) || value < 0) {
    return NOT_VALID;
  }
  return value;
}

export function hesIsValidValue(value: number | undefined | null): boolean {
  return validNumber(value) >= 0;
}

/** Mean of a list; undefined for an empty list (never NaN). */
export function hesMean(values: number[]): number | undefined {
  if (values.length === 0) {
    return undefined;
  }
  let sum = 0;
  for (let i = 0; i < values.length; i++) {
    sum += values[i];
  }
  return sum / values.length;
}

/** Median of a list, the mean of the two middle values for an even count; undefined for an empty list. */
export function hesMedian(values: number[]): number | undefined {
  if (values.length === 0) {
    return undefined;
  }
  const sorted = values.slice().sort((a: number, b: number): number => a - b);
  const mid = Math.floor(sorted.length / 2);
  if (sorted.length % 2 === 1) {
    return sorted[mid];
  }
  return (sorted[mid - 1] + sorted[mid]) / 2;
}

/** Population standard deviation (divisor n); undefined for an empty list. */
export function hesPopulationSd(values: number[]): number | undefined {
  const mean = hesMean(values);
  if (mean === undefined) {
    return undefined;
  }
  let squares = 0;
  for (let i = 0; i < values.length; i++) {
    const d = values[i] - mean;
    squares += d * d;
  }
  return Math.sqrt(squares / values.length);
}

/**
 * Midnight-safe clock time: minutes since 18:00. 23:30 gives 330 and 00:30 gives 390, so the two are
 * 60 minutes apart instead of 23 hours.
 */
export function sleepRelativeMinutes(minutesSinceMidnight: number): number {
  return (minutesSinceMidnight - HES_SLEEP_ANCHOR_MIN + HES_MINUTES_PER_DAY) % HES_MINUTES_PER_DAY;
}

/** Timing SD: the root mean square of the bedtime SD and the wake-time SD, in minutes. */
export function sleepTimingSd(bedtimeSd: number, wakeTimeSd: number): number {
  return Math.sqrt((bedtimeSd * bedtimeSd + wakeTimeSd * wakeTimeSd) / 2);
}

/** A day's MVPA equivalent: a vigorous minute counts twice. */
export function equivalentMvpa(moderateMin: number, vigorousMin: number): number {
  return moderateMin + HES_VIGOROUS_FACTOR * vigorousMin;
}

/**
 * The day number of the last completed day, or NOT_VALID when the history has no day with a real date.
 * Every window is counted back from this day.
 */
function referenceDay(days: HesDayRecord[]): number {
  let last = NOT_VALID;
  for (let i = 0; i < days.length; i++) {
    const n = dayNumberOfDate(days[i].date);
    if (n > last) {
      last = n;
    }
  }
  return last;
}

/**
 * The completed days inside a window, one record per calendar day: when the same date is listed twice,
 * the later record stands.
 */
function daysInWindow(days: HesDayRecord[], reference: number, windowDays: number): HesDayRecord[] {
  const byDay: Map<number, HesDayRecord> = new Map<number, HesDayRecord>();
  for (let i = 0; i < days.length; i++) {
    const n = dayNumberOfDate(days[i].date);
    if (n < 0) {
      continue;
    }
    const daysAgo = reference - n;
    if (daysAgo >= 0 && daysAgo < windowDays) {
      byDay.set(n, days[i]);
    }
  }
  const out: HesDayRecord[] = [];
  byDay.forEach((day: HesDayRecord): void => {
    out.push(day);
  });
  return out;
}

/** A night counts when the bedtime, the wake time and the total are all valid values. */
export function hesIsValidNight(sleep: HesSleep | undefined | null): boolean {
  if (sleep === undefined || sleep === null) {
    return false;
  }
  return validNumber(sleep.bedMin) >= 0 && validNumber(sleep.wakeMin) >= 0 &&
    validNumber(sleep.totalSleepMin) >= 0;
}

function stepsAggregate(window: HesDayRecord[]): HesAggregateValue {
  const values: number[] = [];
  for (let i = 0; i < window.length; i++) {
    const steps = validNumber(window[i].steps);
    if (steps >= 0) {
      values.push(steps);
    }
  }
  return { raw: hesMean(values), validCount: values.length };
}

// Weekly MVPA is the mean daily equivalent of the valid days times 7. With 28 valid days this is exactly
// the specification's SUM / 4; with fewer it does not count a missing day as zero minutes.
function mvpaAggregate(window: HesDayRecord[]): HesAggregateValue {
  const values: number[] = [];
  for (let i = 0; i < window.length; i++) {
    const moderate = validNumber(window[i].moderateMin);
    const vigorous = validNumber(window[i].vigorousMin);
    if (moderate >= 0 && vigorous >= 0) {
      values.push(equivalentMvpa(moderate, vigorous));
    }
  }
  const mean = hesMean(values);
  return { raw: mean === undefined ? undefined : mean * HES_DAYS_PER_WEEK, validCount: values.length };
}

function rhrAggregate(window: HesDayRecord[]): HesAggregateValue {
  const values: number[] = [];
  for (let i = 0; i < window.length; i++) {
    const rhr = validNumber(window[i].restingHr);
    if (rhr >= 0) {
      values.push(rhr);
    }
  }
  return { raw: hesMedian(values), validCount: values.length };
}

function sleepDurationAggregate(window: HesDayRecord[]): HesAggregateValue {
  const values: number[] = [];
  for (let i = 0; i < window.length; i++) {
    const sleep = window[i].sleep;
    if (sleep !== undefined && hesIsValidNight(sleep)) {
      values.push(sleep.totalSleepMin);
    }
  }
  const median = hesMedian(values);
  return { raw: median === undefined ? undefined : median / HES_MINUTES_PER_HOUR, validCount: values.length };
}

function sleepRegularityAggregate(window: HesDayRecord[]): HesAggregateValue {
  const bedtimes: number[] = [];
  const wakeTimes: number[] = [];
  for (let i = 0; i < window.length; i++) {
    const sleep = window[i].sleep;
    if (sleep !== undefined && hesIsValidNight(sleep)) {
      bedtimes.push(sleepRelativeMinutes(sleep.bedMin));
      wakeTimes.push(sleepRelativeMinutes(sleep.wakeMin));
    }
  }
  const bedtimeSd = hesPopulationSd(bedtimes);
  const wakeTimeSd = hesPopulationSd(wakeTimes);
  if (bedtimeSd === undefined || wakeTimeSd === undefined) {
    return { validCount: 0 };
  }
  return { raw: sleepTimingSd(bedtimeSd, wakeTimeSd), validCount: bedtimes.length };
}

/** An HRV night counts when it was measured by the scored protocol and its percentile is a valid value. */
export function hesIsScoredHrv(hrv: HesHrvNight | undefined | null): boolean {
  if (hrv === undefined || hrv === null) {
    return false;
  }
  return hrv.protocol === HRV_PROTOCOL && validNumber(hrv.percentile) >= 0;
}

// The percentile is supplied by the source. HRV is never derived from a heart rate.
function hrvAggregate(window: HesDayRecord[]): HesAggregateValue {
  const values: number[] = [];
  for (let i = 0; i < window.length; i++) {
    const hrv = window[i].hrv;
    if (hrv !== undefined && hesIsScoredHrv(hrv)) {
      values.push(hrv.percentile);
    }
  }
  return { raw: hesMedian(values), validCount: values.length };
}

// The newest valid estimate in the window. VO2max is never derived from steps or MVPA.
function crfAggregate(history: HesHistory, reference: number): HesAggregateValue {
  let count = 0;
  let newestAgo = NOT_VALID;
  let newest = NOT_VALID;
  for (let i = 0; i < history.crf.length; i++) {
    const estimate = history.crf[i];
    const n = dayNumberOfDate(estimate.date);
    const percentile = validNumber(estimate.percentile);
    if (n < 0 || percentile < 0) {
      continue;
    }
    const daysAgo = reference - n;
    if (daysAgo < 0 || daysAgo >= HES_CRF_WINDOW_DAYS) {
      continue;
    }
    count++;
    if (newestAgo < 0 || daysAgo < newestAgo) {
      newestAgo = daysAgo;
      newest = percentile;
    }
  }
  if (count === 0) {
    return { validCount: 0 };
  }
  return { raw: newest, validCount: count };
}

class RecoverySession {
  daysAgo: number;
  protocolId: string;
  hrr1: number;

  constructor(daysAgo: number, protocolId: string, hrr1: number) {
    this.daysAgo = daysAgo;
    this.protocolId = protocolId;
    this.hrr1 = hrr1;
  }
}

// HRR1 = peak heart rate minus the heart rate 60 seconds later. Only comparable sessions count: those of
// the protocol with the most sessions in the window; on equal counts, the protocol of the newest session.
// So one new session of another protocol does not switch the component off.
function hrrAggregate(history: HesHistory, reference: number): HesAggregateValue {
  const sessions: RecoverySession[] = [];
  for (let i = 0; i < history.hrr.length; i++) {
    const session = history.hrr[i];
    const n = dayNumberOfDate(session.date);
    const peak = validNumber(session.peakHr);
    const after = validNumber(session.hr60);
    if (n < 0 || peak < 0 || after < 0 || peak <= after) {
      continue;
    }
    const daysAgo = reference - n;
    if (daysAgo < 0 || daysAgo >= HES_HRR_WINDOW_DAYS) {
      continue;
    }
    sessions.push(new RecoverySession(daysAgo, session.protocolId, peak - after));
  }
  if (sessions.length === 0) {
    return { validCount: 0 };
  }
  const counts: Map<string, number> = new Map<string, number>();
  for (let i = 0; i < sessions.length; i++) {
    const before = counts.get(sessions[i].protocolId);
    counts.set(sessions[i].protocolId, (before === undefined ? 0 : before) + 1);
  }
  let protocol = sessions[0].protocolId;
  let protocolCount = 0;
  let protocolNewest = NOT_VALID;
  for (let i = 0; i < sessions.length; i++) {
    const id = sessions[i].protocolId;
    const found = counts.get(id);
    const count = found === undefined ? 0 : found;
    let newest = sessions[i].daysAgo;
    for (let j = 0; j < sessions.length; j++) {
      if (sessions[j].protocolId === id && sessions[j].daysAgo < newest) {
        newest = sessions[j].daysAgo;
      }
    }
    if (count > protocolCount || (count === protocolCount && newest < protocolNewest)) {
      protocol = id;
      protocolCount = count;
      protocolNewest = newest;
    }
  }
  const values: number[] = [];
  for (let i = 0; i < sessions.length; i++) {
    if (sessions[i].protocolId === protocol) {
      values.push(sessions[i].hrr1);
    }
  }
  return { raw: hesMedian(values), validCount: values.length };
}

/** The raw value and the valid count of every component for a history of completed days. */
export function aggregate(history: HesHistory): HesAggregates {
  const reference = referenceDay(history.days);
  if (reference < 0) {
    return {
      crf: { validCount: 0 },
      rhr: { validCount: 0 },
      mvpa: { validCount: 0 },
      steps: { validCount: 0 },
      sleepRegularity: { validCount: 0 },
      sleepDuration: { validCount: 0 },
      hrv: { validCount: 0 },
      hrr: { validCount: 0 }
    };
  }
  const window = daysInWindow(history.days, reference, HES_WINDOW_DAYS);
  const hrvWindow = daysInWindow(history.days, reference, HES_HRV_WINDOW_DAYS);
  return {
    crf: crfAggregate(history, reference),
    rhr: rhrAggregate(window),
    mvpa: mvpaAggregate(window),
    steps: stepsAggregate(window),
    sleepRegularity: sleepRegularityAggregate(window),
    sleepDuration: sleepDurationAggregate(window),
    hrv: hrvAggregate(hrvWindow),
    hrr: hrrAggregate(history, reference)
  };
}

/** One component's aggregate. */
export function aggregateOf(aggregates: HesAggregates, id: ComponentId): HesAggregateValue {
  switch (id) {
    case ComponentId.CRF:
      return aggregates.crf;
    case ComponentId.RHR:
      return aggregates.rhr;
    case ComponentId.MVPA:
      return aggregates.mvpa;
    case ComponentId.STEPS:
      return aggregates.steps;
    case ComponentId.SLEEP_REGULARITY:
      return aggregates.sleepRegularity;
    case ComponentId.SLEEP_DURATION:
      return aggregates.sleepDuration;
    case ComponentId.HRV:
      return aggregates.hrv;
    default:
      return aggregates.hrr;
  }
}
