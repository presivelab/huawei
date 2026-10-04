// A demo session around the engine (specification section 12).
//
// HES is longitudinal, not minute by minute:
//   - the live heart rate and today's steps are shown and never change the score;
//   - a live heart rate is never used as a resting heart rate: the resting heart rate of the day that is
//     closed comes from the source's daily record;
//   - closing the day appends today's record to the history and everything is calculated again;
//   - a value that was not set stays absent. Zero is never written because a live value was cleared;
//   - reset goes back to the snapshot the session started from.
//
// In production the day closes at midnight. In the demo the "Close the day" button does it.
import { dateOfDayNumber, dayNumberOfDate } from '../watchlink/WatchLinkTypes';
import { hesIsValidValue } from './HesAggregate';
import { computeHes } from './HesEngine';
import {
  HesCrfEstimate,
  HesDayRecord,
  HesHistory,
  HesHrrSession,
  HesProfile,
  HesResult
} from './HesTypes';

/** What a source hands over for one person: the completed days and the record of the running day. */
export interface HesSnapshot {
  history: HesHistory;
  today: HesDayRecord;  // the running day as the source has it; not scored until the day is closed
}

export function copyHesDayRecord(day: HesDayRecord): HesDayRecord {
  const out: HesDayRecord = { date: day.date };
  if (day.steps !== undefined) {
    out.steps = day.steps;
  }
  if (day.moderateMin !== undefined) {
    out.moderateMin = day.moderateMin;
  }
  if (day.vigorousMin !== undefined) {
    out.vigorousMin = day.vigorousMin;
  }
  if (day.restingHr !== undefined) {
    out.restingHr = day.restingHr;
  }
  const sleep = day.sleep;
  if (sleep !== undefined) {
    out.sleep = { bedMin: sleep.bedMin, wakeMin: sleep.wakeMin, totalSleepMin: sleep.totalSleepMin };
  }
  const hrv = day.hrv;
  if (hrv !== undefined) {
    out.hrv = { percentile: hrv.percentile, protocol: hrv.protocol };
  }
  return out;
}

export function copyHesHistory(history: HesHistory): HesHistory {
  const days: HesDayRecord[] = [];
  for (let i = 0; i < history.days.length; i++) {
    days.push(copyHesDayRecord(history.days[i]));
  }
  const crf: HesCrfEstimate[] = [];
  for (let i = 0; i < history.crf.length; i++) {
    crf.push({ date: history.crf[i].date, percentile: history.crf[i].percentile });
  }
  const hrr: HesHrrSession[] = [];
  for (let i = 0; i < history.hrr.length; i++) {
    const s = history.hrr[i];
    hrr.push({ date: s.date, protocolId: s.protocolId, peakHr: s.peakHr, hr60: s.hr60 });
  }
  return { days: days, crf: crf, hrr: hrr };
}

export function copyHesSnapshot(snapshot: HesSnapshot): HesSnapshot {
  return { history: copyHesHistory(snapshot.history), today: copyHesDayRecord(snapshot.today) };
}

export function emptyHesSnapshot(): HesSnapshot {
  return { history: { days: [], crf: [], hrr: [] }, today: { date: '' } };
}

// The calendar day after `date`; the same text when it is not a real date.
function nextDate(date: string): string {
  const n = dayNumberOfDate(date);
  return n < 0 ? date : dateOfDayNumber(n + 1);
}

export class HesSession {
  private start: HesSnapshot;
  private past: HesHistory;
  private running: HesDayRecord;
  private closed: number = 0;
  private liveHr: number | undefined = undefined;
  private stepsNow: number | undefined = undefined;

  /** `snapshot` is what the source handed over. The session works on its own copy. */
  constructor(snapshot: HesSnapshot) {
    this.start = copyHesSnapshot(snapshot);
    this.past = copyHesHistory(snapshot.history);
    this.running = copyHesDayRecord(snapshot.today);
  }

  /** The score for the completed days in a profile. Live values and the running day are not part of it. */
  current(profile: HesProfile): HesResult {
    return computeHes(profile, this.past);
  }

  /** A copy of the completed days and of the estimates and sessions. */
  history(): HesHistory {
    return copyHesHistory(this.past);
  }

  /** How many completed days the history holds. */
  historyLength(): number {
    return this.past.days.length;
  }

  /** A copy of the running day's record, with the steps as they stand now. Display only. */
  today(): HesDayRecord {
    const out = copyHesDayRecord(this.running);
    const steps = this.liveSteps();
    if (steps !== undefined) {
      out.steps = steps;
    }
    return out;
  }

  /** How many days were closed since the start or the last reset. */
  closedDays(): number {
    return this.closed;
  }

  /** Display only. A reading that is not a positive number is no reading. */
  setLiveHeartRate(bpm: number | undefined): void {
    this.liveHr = bpm !== undefined && hesIsValidValue(bpm) && bpm > 0 ? bpm : undefined;
  }

  /** Display only until the day is closed. A count that is not valid is no reading. */
  setLiveSteps(steps: number | undefined): void {
    this.stepsNow = steps !== undefined && hesIsValidValue(steps) ? steps : undefined;
  }

  setLive(heartRate: number | undefined, steps: number | undefined): void {
    this.setLiveHeartRate(heartRate);
    this.setLiveSteps(steps);
  }

  /** The live heart rate for the Live card; undefined when there is none. It is never stored. */
  liveHeartRate(): number | undefined {
    return this.liveHr;
  }

  /** Today's steps for the Live card: the live count when one was set, else the source's count for today. */
  liveSteps(): number | undefined {
    if (this.stepsNow !== undefined) {
      return this.stepsNow;
    }
    return this.running.steps;
  }

  /**
   * Closes the day: today's record becomes a completed day, with the steps as they stand now, and enters
   * the history. The next running day is the source's record for today again, one calendar day later.
   */
  closeDay(): void {
    this.past.days.push(this.today());
    this.closed++;
    const next = copyHesDayRecord(this.start.today);
    next.date = nextDate(this.running.date);
    this.running = next;
    this.stepsNow = undefined;
  }

  /** Back to the snapshot the session started from, with no live values. */
  resetDemo(): void {
    this.past = copyHesHistory(this.start.history);
    this.running = copyHesDayRecord(this.start.today);
    this.closed = 0;
    this.liveHr = undefined;
    this.stepsNow = undefined;
  }
}
