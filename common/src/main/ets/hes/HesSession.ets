// A demo session around the engine (specification section 10).
//
// HES is longitudinal, not minute by minute:
//   - the live heart rate and today's steps are shown and never change the score;
//   - a live heart rate is never used as a resting heart rate;
//   - closing the day appends one completed day to the history and the score is calculated again;
//   - reset goes back to the starting history;
//   - the profile (health or life insurance) only changes the weights; switching it recalculates the score
//     for the same completed days and keeps the live values. Reset keeps the profile.
import { HES_DEFAULT_PROFILE } from './HesCurves';
import { computeHes } from './HesEngine';
import { copyHesDay, emptyHesDay, HesDay, HesProfile, HesResult, HES_MISSING } from './HesTypes';

/** Where the values of a newly completed day come from (everything except today's live steps). */
export interface HesDaySource {
  /** The n-th completed day after the starting history, n = 1, 2, ... */
  dayAfter(closedDays: number): HesDay;
}

export class HesSession {
  private start: HesDay[];
  private days: HesDay[];
  private source: HesDaySource | null;
  private closed: number = 0;
  private liveHr: number = HES_MISSING;
  private stepsToday: number = HES_MISSING;
  private scoreProfile: HesProfile;
  private current: HesResult;

  /**
   * `start` is the history of completed days, oldest first. `source` supplies the days that get closed;
   * with null a closed day carries only today's steps.
   */
  constructor(start: HesDay[], source: HesDaySource | null, profile: HesProfile = HES_DEFAULT_PROFILE) {
    this.start = HesSession.copyOf(start);
    this.days = HesSession.copyOf(start);
    this.source = source;
    this.scoreProfile = profile;
    this.current = computeHes(this.days, this.scoreProfile);
  }

  /** The profile the score is calculated with. */
  profile(): HesProfile {
    return this.scoreProfile;
  }

  /** Recalculates the score for the same completed days with the weights of another profile. */
  setProfile(profile: HesProfile): HesResult {
    this.scoreProfile = profile;
    this.current = computeHes(this.days, this.scoreProfile);
    return this.current;
  }

  private static copyOf(days: HesDay[]): HesDay[] {
    const out: HesDay[] = [];
    for (let i = 0; i < days.length; i++) {
      out.push(copyHesDay(days[i]));
    }
    return out;
  }

  /** The score for the completed days. Live values are not part of it. */
  result(): HesResult {
    return this.current;
  }

  /** A copy of the completed days, oldest first. */
  history(): HesDay[] {
    return HesSession.copyOf(this.days);
  }

  /** How many days were closed since the start or the last reset. */
  closedDays(): number {
    return this.closed;
  }

  /** Display only. A reading of 0 bpm or less is no reading. */
  setLiveHeartRate(bpm: number): void {
    this.liveHr = bpm > 0 ? bpm : HES_MISSING;
  }

  /** Display only until the day is closed. A negative count is no reading. */
  setLiveSteps(steps: number): void {
    this.stepsToday = steps >= 0 ? steps : HES_MISSING;
  }

  setLive(heartRate: number, steps: number): void {
    this.setLiveHeartRate(heartRate);
    this.setLiveSteps(steps);
  }

  /** The live heart rate for the Live card; HES_MISSING when there is none. */
  liveHeartRate(): number {
    return this.liveHr;
  }

  /** Today's steps for the Today card; HES_MISSING when there is no reading yet. */
  liveSteps(): number {
    return this.stepsToday;
  }

  /**
   * Closes the day: today becomes a completed day and enters the history, then the score is recalculated.
   * Today's steps are the live count when there is one. The live heart rate is not stored anywhere.
   */
  closeDay(): HesResult {
    this.closed++;
    const day = this.source === null ? emptyHesDay('') : copyHesDay(this.source.dayAfter(this.closed));
    if (this.stepsToday >= 0) {
      day.steps = this.stepsToday;
    }
    this.days.push(day);
    this.stepsToday = HES_MISSING;
    this.current = computeHes(this.days, this.scoreProfile);
    return this.current;
  }

  /** Back to the starting history, with no live values. */
  reset(): HesResult {
    this.days = HesSession.copyOf(this.start);
    this.closed = 0;
    this.liveHr = HES_MISSING;
    this.stepsToday = HES_MISSING;
    this.current = computeHes(this.days, this.scoreProfile);
    return this.current;
  }
}
