// Six demo personas for HES vNext: a deterministic recipe for completed days, with no random numbers.
// Illustrative values, not measurements of anyone. The same persona gives the same history on every run.
//
// The recipe:
//   - pattern(A, d, n): n odd gives [A, A-d, A+d, A-d, ...]; n even gives [A-d, A+d, A-d, ...]. So the mean
//     and the median are A for every n, and the population SD of an even pattern is d;
//   - a value series of n values goes to the n newest days of the history, oldest first; the older days do
//     not have that field at all (absent, not zero);
//   - the last day of the history is the day before `today`. There is no clock here: `today` is a parameter;
//   - the night's clock times are moved by pattern(0, shift, n) and wrapped into 0..1439; the time in bed
//     stays fixed and the sleep total is never longer than it.
//
// Only the numbers in this file describe the personas. The weights, curves and thresholds are in
// HesModel.ets and were not touched to make a persona fit.
import { dateOfDayNumber, dayNumberOfDate } from '../watchlink/WatchLinkTypes';
import { computeHes } from './HesEngine';
import { HRV_PROTOCOL } from './HesModel';
import { HesSession, HesSnapshot } from './HesSession';
import {
  HesCrfEstimate,
  HesDayRecord,
  HesHistory,
  HesHrrSession,
  HesProfile,
  HesResult
} from './HesTypes';

/** The last completed day of every persona's starting history in the demo. */
export const HES_PERSONA_END_DATE: string = '2026-10-03';
/** The running day of the demo: the day after HES_PERSONA_END_DATE. */
export const HES_PERSONA_TODAY: string = '2026-10-04';

const MINUTES_PER_DAY: number = 1440;
const NONE: number = -1;

// How far the values of a series swing around the persona's base value.
const STEPS_SWING: number = 600;
const MVPA_SWING: number = 6;       // equivalent minutes a day
const RHR_SWING: number = 2;        // bpm
const SLEEP_TOTAL_SWING: number = 18;  // minutes
const HRV_SWING: number = 5;        // percentile points
const VIGOROUS_SHARE: number = 5;   // vigorous minutes = floor(daily equivalent / 5)

const WALK: string = 'walk-3min';
const INTERVAL_RUN: string = 'interval-run';

/** A VO2max estimate of a persona, `daysAgo` days before the last completed day. */
export interface PersonaCrf {
  daysAgo: number;
  percentile: number;
}

/** A heart-rate recovery session of a persona, `daysAgo` days before the last completed day. */
export interface PersonaHrr {
  daysAgo: number;
  protocolId: string;
  peakHr: number;
  hr60: number;
}

/** What a persona's days look like. A count is how many of the newest days carry the value. */
export interface HesPersonaSpec {
  id: string;
  name: string;
  days: number;            // length of the starting history, completed days
  stepsBase: number;       // steps a day
  stepsCount: number;
  mvpaBase: number;        // equivalent minutes a day (moderate + 2 x vigorous)
  mvpaCount: number;
  rhrBase: number;         // bpm
  rhrCount: number;
  sleepCount: number;      // nights with a sleep record
  bedMin: number;          // usual bedtime, minutes since midnight
  wakeMin: number;         // usual wake-up time, minutes since midnight
  sleepShift: number;      // how far the night moves earlier and later, minutes
  sleepTotalMin: number;   // usual total sleep, minutes
  hrvBase: number;         // percentile; NONE when the persona's watch has no HRV
  hrvCount: number;
  crf: PersonaCrf[];
  hrr: PersonaHrr[];
}

function at(hour: number, minute: number): number {
  return hour * 60 + minute;
}

const ANIA: HesPersonaSpec = {
  id: 'ania',
  name: 'Ania',
  days: 28,
  stepsBase: 8800,
  stepsCount: 28,
  mvpaBase: 34,
  mvpaCount: 28,
  rhrBase: 58,
  rhrCount: 28,
  sleepCount: 28,
  bedMin: at(22, 45),
  wakeMin: at(6, 45),
  sleepShift: 45,
  sleepTotalMin: 444,
  hrvBase: 60,
  hrvCount: 28,
  crf: [
    { daysAgo: 120, percentile: 60 },  // older than the 90-day window
    { daysAgo: 70, percentile: 74 },
    { daysAgo: 12, percentile: 77 }
  ],
  hrr: [
    { daysAgo: 75, protocolId: WALK, peakHr: 150, hr60: 130 },  // older than the 60-day window
    { daysAgo: 45, protocolId: WALK, peakHr: 152, hr60: 122 },
    { daysAgo: 25, protocolId: WALK, peakHr: 154, hr60: 120 },
    { daysAgo: 4, protocolId: WALK, peakHr: 150, hr60: 118 }
  ]
};

const MAREK: HesPersonaSpec = {
  id: 'marek',
  name: 'Marek',
  days: 28,
  stepsBase: 6200,
  stepsCount: 28,
  mvpaBase: 17,
  mvpaCount: 28,
  rhrBase: 68,
  rhrCount: 28,
  sleepCount: 28,
  bedMin: at(23, 30),
  wakeMin: at(6, 50),
  sleepShift: 70,
  sleepTotalMin: 396,
  hrvBase: 40,
  hrvCount: 28,
  crf: [],
  hrr: [
    { daysAgo: 50, protocolId: WALK, peakHr: 140, hr60: 118 },
    { daysAgo: 30, protocolId: WALK, peakHr: 142, hr60: 116 },
    { daysAgo: 9, protocolId: WALK, peakHr: 141, hr60: 117 }
  ]
};

const KASIA: HesPersonaSpec = {
  id: 'kasia',
  name: 'Kasia',
  days: 28,
  stepsBase: 6000,
  stepsCount: 20,
  mvpaBase: 14,
  mvpaCount: 20,
  rhrBase: 72,
  rhrCount: 18,
  sleepCount: 16,
  bedMin: at(23, 0),
  wakeMin: at(6, 30),
  sleepShift: 70,
  sleepTotalMin: 384,
  hrvBase: 52,
  hrvCount: 4,
  crf: [],
  hrr: []
};

// Tomek's watch has no HRV. One of his recovery sessions used another protocol.
const TOMEK: HesPersonaSpec = {
  id: 'tomek',
  name: 'Tomek',
  days: 28,
  stepsBase: 7000,
  stepsCount: 28,
  mvpaBase: 21,
  mvpaCount: 28,
  rhrBase: 62,
  rhrCount: 28,
  sleepCount: 28,
  bedMin: at(0, 0),
  wakeMin: at(7, 0),
  sleepShift: 80,
  sleepTotalMin: 390,
  hrvBase: NONE,
  hrvCount: 0,
  crf: [
    { daysAgo: 40, percentile: 48 },
    { daysAgo: 5, percentile: 50 }
  ],
  hrr: [
    { daysAgo: 55, protocolId: WALK, peakHr: 150, hr60: 125 },
    { daysAgo: 50, protocolId: INTERVAL_RUN, peakHr: 178, hr60: 137 },
    { daysAgo: 33, protocolId: WALK, peakHr: 152, hr60: 123 },
    { daysAgo: 8, protocolId: WALK, peakHr: 151, hr60: 124 }
  ]
};

const EWA: HesPersonaSpec = {
  id: 'ewa',
  name: 'Ewa',
  days: 28,
  stepsBase: 4400,
  stepsCount: 20,
  mvpaBase: 10,
  mvpaCount: 20,
  rhrBase: 76,
  rhrCount: 20,
  sleepCount: 16,
  bedMin: at(23, 45),
  wakeMin: at(7, 15),
  sleepShift: 85,
  sleepTotalMin: 372,
  hrvBase: 35,
  hrvCount: 3,
  crf: [],
  hrr: [
    { daysAgo: 38, protocolId: WALK, peakHr: 135, hr60: 117 },
    { daysAgo: 6, protocolId: WALK, peakHr: 136, hr60: 114 }
  ]
};

// A new user: 16 days of history and only six nights with the watch on.
const OLA: HesPersonaSpec = {
  id: 'ola',
  name: 'Ola',
  days: 16,
  stepsBase: 6800,
  stepsCount: 16,
  mvpaBase: 16,
  mvpaCount: 16,
  rhrBase: 68,
  rhrCount: 16,
  sleepCount: 6,
  bedMin: at(23, 15),
  wakeMin: at(7, 0),
  sleepShift: 40,
  sleepTotalMin: 420,
  hrvBase: 50,
  hrvCount: 6,
  crf: [],
  hrr: []
};

const SPECS: HesPersonaSpec[] = [ANIA, MAREK, KASIA, TOMEK, EWA, OLA];

/**
 * n values around `base`: n odd gives [base, base-d, base+d, base-d, ...], n even gives
 * [base-d, base+d, ...]. The mean and the median are `base` for every n.
 */
export function personaPattern(base: number, d: number, n: number): number[] {
  const out: number[] = [];
  const odd = n % 2 === 1;
  for (let i = 0; i < n; i++) {
    if (odd && i === 0) {
      out.push(base);
    } else if (odd) {
      out.push(i % 2 === 1 ? base - d : base + d);
    } else {
      out.push(i % 2 === 0 ? base - d : base + d);
    }
  }
  return out;
}

// Into 0..1439. A plain % leaves a negative number for a night moved before midnight.
function wrapMinute(value: number): number {
  return ((value % MINUTES_PER_DAY) + MINUTES_PER_DAY) % MINUTES_PER_DAY;
}

function setMvpa(day: HesDayRecord, equivalent: number): void {
  const vigorous = Math.floor(equivalent / VIGOROUS_SHARE);
  day.vigorousMin = vigorous;
  day.moderateMin = equivalent - 2 * vigorous;
}

// Day number of the last completed day for a running day `today`; NONE when `today` is not a real date.
function lastCompletedDay(today: string): number {
  const n = dayNumberOfDate(today);
  return n < 0 ? NONE : n - 1;
}

/** The starting history of a persona: `spec.days` completed days, oldest first, ending the day before `today`. */
export function generatePersonaHistory(spec: HesPersonaSpec, today: string = HES_PERSONA_TODAY): HesHistory {
  const history: HesHistory = { days: [], crf: [], hrr: [] };
  const last = lastCompletedDay(today);
  if (last < 0) {
    return history;
  }
  const steps = personaPattern(spec.stepsBase, STEPS_SWING, spec.stepsCount);
  const mvpa = personaPattern(spec.mvpaBase, MVPA_SWING, spec.mvpaCount);
  const rhr = personaPattern(spec.rhrBase, RHR_SWING, spec.rhrCount);
  const shift = personaPattern(0, spec.sleepShift, spec.sleepCount);
  const sleepTotal = personaPattern(spec.sleepTotalMin, SLEEP_TOTAL_SWING, spec.sleepCount);
  const hrv = personaPattern(spec.hrvBase, HRV_SWING, spec.hrvBase < 0 ? 0 : spec.hrvCount);
  for (let k = 0; k < spec.days; k++) {
    const day: HesDayRecord = { date: dateOfDayNumber(last - (spec.days - 1 - k)) };
    const stepsAt = k - (spec.days - steps.length);
    if (stepsAt >= 0) {
      day.steps = steps[stepsAt];
    }
    const mvpaAt = k - (spec.days - mvpa.length);
    if (mvpaAt >= 0) {
      setMvpa(day, mvpa[mvpaAt]);
    }
    const rhrAt = k - (spec.days - rhr.length);
    if (rhrAt >= 0) {
      day.restingHr = rhr[rhrAt];
    }
    const sleepAt = k - (spec.days - shift.length);
    if (sleepAt >= 0) {
      day.sleep = {
        bedMin: wrapMinute(spec.bedMin + shift[sleepAt]),
        wakeMin: wrapMinute(spec.wakeMin + shift[sleepAt]),
        totalSleepMin: sleepTotal[sleepAt]
      };
    }
    const hrvAt = k - (spec.days - hrv.length);
    if (hrvAt >= 0) {
      day.hrv = { percentile: hrv[hrvAt], protocol: HRV_PROTOCOL };
    }
    history.days.push(day);
  }
  for (let i = 0; i < spec.crf.length; i++) {
    const estimate: HesCrfEstimate = {
      date: dateOfDayNumber(last - spec.crf[i].daysAgo),
      percentile: spec.crf[i].percentile
    };
    history.crf.push(estimate);
  }
  for (let i = 0; i < spec.hrr.length; i++) {
    const session: HesHrrSession = {
      date: dateOfDayNumber(last - spec.hrr[i].daysAgo),
      protocolId: spec.hrr[i].protocolId,
      peakHr: spec.hrr[i].peakHr,
      hr60: spec.hrr[i].hr60
    };
    history.hrr.push(session);
  }
  return history;
}

/**
 * The record of the running day as the source has it: the persona's base values, last night's sleep at the
 * usual times, and HRV for a persona whose watch measures it. It is not scored until the day is closed.
 */
export function generatePersonaToday(spec: HesPersonaSpec, today: string = HES_PERSONA_TODAY): HesDayRecord {
  const day: HesDayRecord = { date: today };
  day.steps = spec.stepsBase;
  setMvpa(day, spec.mvpaBase);
  day.restingHr = spec.rhrBase;
  day.sleep = {
    bedMin: wrapMinute(spec.bedMin),
    wakeMin: wrapMinute(spec.wakeMin),
    totalSleepMin: spec.sleepTotalMin
  };
  if (spec.hrvBase >= 0) {
    day.hrv = { percentile: spec.hrvBase, protocol: HRV_PROTOCOL };
  }
  return day;
}

/** The six demo personas. An unknown id gives an empty history, which has no score. */
export class HesPersonas {
  static readonly IDS: string[] = ['ania', 'marek', 'kasia', 'tomek', 'ewa', 'ola'];

  static has(id: string): boolean {
    return HesPersonas.IDS.indexOf(id) >= 0;
  }

  /** The persona's parameters, or null for an unknown id. */
  static spec(id: string): HesPersonaSpec | null {
    for (let i = 0; i < SPECS.length; i++) {
      if (SPECS[i].id === id) {
        return SPECS[i];
      }
    }
    return null;
  }

  /** The display name, e.g. "Ania"; the id itself for an unknown id. */
  static displayName(id: string): string {
    const spec = HesPersonas.spec(id);
    return spec === null ? id : spec.name;
  }

  /** The starting history: completed days, oldest first, ending the day before `today`. */
  static history(id: string, today: string = HES_PERSONA_TODAY): HesHistory {
    const spec = HesPersonas.spec(id);
    return spec === null ? { days: [], crf: [], hrr: [] } : generatePersonaHistory(spec, today);
  }

  /** The record of the running day; only a date for an unknown id. */
  static today(id: string, today: string = HES_PERSONA_TODAY): HesDayRecord {
    const spec = HesPersonas.spec(id);
    return spec === null ? { date: today } : generatePersonaToday(spec, today);
  }

  /** The starting history together with the running day: what a source hands over for the persona. */
  static snapshot(id: string, today: string = HES_PERSONA_TODAY): HesSnapshot {
    return { history: HesPersonas.history(id, today), today: HesPersonas.today(id, today) };
  }

  /** HES for the starting history in a profile. */
  static result(id: string, profile: HesProfile, today: string = HES_PERSONA_TODAY): HesResult {
    return computeHes(profile, HesPersonas.history(id, today));
  }

  /** A demo session that starts from the persona's snapshot (live values, close the day, reset). */
  static session(id: string, today: string = HES_PERSONA_TODAY): HesSession {
    return new HesSession(HesPersonas.snapshot(id, today));
  }
}
