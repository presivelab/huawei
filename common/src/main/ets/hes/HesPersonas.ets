// Six demo personas for HES-Lite (specification section 16): a seeded generator of completed days.
// Illustrative values, not measurements of anyone. No Math.random: the same persona gives the same
// history on every run and on every engine.
//
// The personas are tuned so that the engine returns the team's fixed results. Only the numbers in this
// file were tuned; the weights, curves and thresholds in HesCurves.ets were not touched.
import { dateOfDayNumber, dayNumberOfDate } from '../watchlink/WatchLinkTypes';
import { HES_DEFAULT_PROFILE } from './HesCurves';
import { computeHes } from './HesEngine';
import { HesPrng } from './HesPrng';
import { HesDaySource, HesSession } from './HesSession';
import { emptyHesDay, HesDay, HesProfile, HesResult, HES_MISSING } from './HesTypes';

/** The last completed day of every persona's starting history. */
export const HES_PERSONA_END_DATE: string = '2026-10-03';

const MINUTES_PER_DAY: number = 1440;
const DAYS_PER_WEEK: number = 7;
const MIN_SLEEP_MINUTES: number = 60;
const MIN_PERCENTILE: number = 1;
const MAX_PERCENTILE: number = 99;
const NONE: number = HES_MISSING;

// Independent random streams of one day.
const STREAM_STEPS: number = 0;
const STREAM_RHR: number = 1;
const STREAM_MODERATE: number = 2;
const STREAM_BEDTIME: number = 3;
const STREAM_WAKE: number = 4;
const STREAM_AWAKE: number = 5;
const STREAM_HRV: number = 6;
const STREAM_HRR: number = 7;

// Phases of the repeating patterns, so that they do not all fall on the same day.
const PHASE_NIGHT: number = 0;
const PHASE_VIGOROUS: number = 1;
const PHASE_VO2MAX: number = 2;
const PHASE_OFF_WRIST: number = 3;
const PHASE_HRR: number = 4;

/** What a persona's days look like. "Every N" patterns use 0 for "never". */
export interface HesPersonaSpec {
  id: string;
  name: string;
  seed: number;
  days: number;              // length of the starting history, completed days
  stepsMean: number;
  stepsSd: number;
  rhrMean: number;           // bpm
  rhrSd: number;
  moderateMean: number;      // moderate minutes per day
  moderateSd: number;
  vigorousEvery: number;     // a vigorous session every N days
  vigorousMinutes: number;
  bedtimeMin: number;        // usual time of falling asleep, minutes after the previous midnight (1410 = 23:30)
  bedtimeSd: number;
  wakeMin: number;           // usual wake-up time, minutes since midnight
  wakeSd: number;
  weekendShiftMin: number;   // later to bed and later up on Saturday and Sunday mornings
  awakeMin: number;          // time awake during the night, taken off the time in bed
  awakeSd: number;
  nightEvery: number;        // the watch is worn every N-th night (1 = every night)
  offWristEvery: number;     // a whole day without the watch every N days
  vo2maxPercentile: number;  // NONE when the persona has no estimate
  vo2maxEvery: number;
  hrvPercentile: number;     // NONE when the persona has no HRV
  hrvSd: number;
  hrr1Mean: number;          // NONE when the persona has no recovery sessions
  hrr1Sd: number;
  hrrEvery: number;
}

const ANIA: HesPersonaSpec = {
  id: 'ania',
  name: 'Ania',
  seed: 1101,
  days: 90,
  stepsMean: 7510,
  stepsSd: 1300,
  rhrMean: 58,
  rhrSd: 2,
  moderateMean: 21,
  moderateSd: 9,
  vigorousEvery: 3,
  vigorousMinutes: 20,
  bedtimeMin: 1375,
  bedtimeSd: 28,
  wakeMin: 410,
  wakeSd: 26,
  weekendShiftMin: 40,
  awakeMin: 28,
  awakeSd: 8,
  nightEvery: 1,
  offWristEvery: 0,
  vo2maxPercentile: 72,
  vo2maxEvery: 7,
  hrvPercentile: 58,
  hrvSd: 6,
  hrr1Mean: 33,
  hrr1Sd: 3,
  hrrEvery: 5
};

const MAREK: HesPersonaSpec = {
  id: 'marek',
  name: 'Marek',
  seed: 2202,
  days: 90,
  stepsMean: 6120,
  stepsSd: 1500,
  rhrMean: 71,
  rhrSd: 3,
  moderateMean: 13,
  moderateSd: 7,
  vigorousEvery: 7,
  vigorousMinutes: 12,
  bedtimeMin: 1425,
  bedtimeSd: 70,
  wakeMin: 420,
  wakeSd: 58,
  weekendShiftMin: 75,
  awakeMin: 35,
  awakeSd: 10,
  nightEvery: 1,
  offWristEvery: 0,
  vo2maxPercentile: 46,
  vo2maxEvery: 14,
  hrvPercentile: NONE,
  hrvSd: 0,
  hrr1Mean: NONE,
  hrr1Sd: 0,
  hrrEvery: 0
};

const KASIA: HesPersonaSpec = {
  id: 'kasia',
  name: 'Kasia',
  seed: 3303,
  days: 90,
  stepsMean: 4380,
  stepsSd: 1200,
  rhrMean: 66,
  rhrSd: 3,
  moderateMean: 10,
  moderateSd: 6,
  vigorousEvery: 7,
  vigorousMinutes: 10,
  bedtimeMin: 1425,
  bedtimeSd: 65,
  wakeMin: 395,
  wakeSd: 55,
  weekendShiftMin: 90,
  awakeMin: 30,
  awakeSd: 10,
  nightEvery: 1,
  offWristEvery: 8,
  vo2maxPercentile: NONE,
  vo2maxEvery: 0,
  hrvPercentile: NONE,
  hrvSd: 0,
  hrr1Mean: NONE,
  hrr1Sd: 0,
  hrrEvery: 0
};

const TOMEK: HesPersonaSpec = {
  id: 'tomek',
  name: 'Tomek',
  seed: 4404,
  days: 90,
  stepsMean: 6600,
  stepsSd: 1400,
  rhrMean: 76,
  rhrSd: 3,
  moderateMean: 15,
  moderateSd: 7,
  vigorousEvery: 7,
  vigorousMinutes: 8,
  bedtimeMin: 1420,
  bedtimeSd: 34,
  wakeMin: 415,
  wakeSd: 32,
  weekendShiftMin: 35,
  awakeMin: 70,
  awakeSd: 10,
  nightEvery: 1,
  offWristEvery: 0,
  vo2maxPercentile: 76,
  vo2maxEvery: 7,
  hrvPercentile: NONE,
  hrvSd: 0,
  hrr1Mean: 25,
  hrr1Sd: 3,
  hrrEvery: 6
};

const EWA: HesPersonaSpec = {
  id: 'ewa',
  name: 'Ewa',
  seed: 5505,
  days: 90,
  stepsMean: 4980,
  stepsSd: 1300,
  rhrMean: 76,
  rhrSd: 3,
  moderateMean: 10,
  moderateSd: 6,
  vigorousEvery: 0,
  vigorousMinutes: 0,
  bedtimeMin: 1450,
  bedtimeSd: 88,
  wakeMin: 465,
  wakeSd: 72,
  weekendShiftMin: 100,
  awakeMin: 44,
  awakeSd: 12,
  nightEvery: 1,
  offWristEvery: 9,
  vo2maxPercentile: NONE,
  vo2maxEvery: 0,
  hrvPercentile: NONE,
  hrvSd: 0,
  hrr1Mean: 20,
  hrr1Sd: 2,
  hrrEvery: 21
};

// A new user: 24 days of history, the watch on the wrist only every third night, one recovery session.
const OLA: HesPersonaSpec = {
  id: 'ola',
  name: 'Ola',
  seed: 6606,
  days: 24,
  stepsMean: 5200,
  stepsSd: 1400,
  rhrMean: 70,
  rhrSd: 3,
  moderateMean: 12,
  moderateSd: 6,
  vigorousEvery: 0,
  vigorousMinutes: 0,
  bedtimeMin: 1430,
  bedtimeSd: 50,
  wakeMin: 430,
  wakeSd: 40,
  weekendShiftMin: 60,
  awakeMin: 30,
  awakeSd: 10,
  nightEvery: 3,
  offWristEvery: 0,
  vo2maxPercentile: NONE,
  vo2maxEvery: 0,
  hrvPercentile: NONE,
  hrvSd: 0,
  hrr1Mean: 24,
  hrr1Sd: 2,
  hrrEvery: 30
};

const SPECS: HesPersonaSpec[] = [ANIA, MAREK, KASIA, TOMEK, EWA, OLA];

function mod(value: number, divisor: number): number {
  return ((value % divisor) + divisor) % divisor;
}

function hits(every: number, offset: number, phase: number): boolean {
  return every > 0 && mod(offset + phase, every) === 0;
}

function around(spec: HesPersonaSpec, offset: number, stream: number, mean: number, sd: number): number {
  return Math.round(mean + HesPrng.forStream(spec.seed, offset, stream).gauss() * sd);
}

function clamp(value: number, low: number, high: number): number {
  return Math.max(low, Math.min(high, value));
}

/**
 * One completed day of a persona. `offset` 0 is HES_PERSONA_END_DATE, negative offsets are earlier days,
 * positive offsets are the days that follow (used when the demo closes a day).
 * A day depends only on the persona and its offset, never on the days around it.
 */
export function generatePersonaDay(spec: HesPersonaSpec, offset: number): HesDay {
  const day = emptyHesDay(dateOfDayNumber(dayNumberOfDate(HES_PERSONA_END_DATE) + offset));
  if (hits(spec.offWristEvery, offset, PHASE_OFF_WRIST)) {
    return day;
  }
  day.steps = Math.max(0, around(spec, offset, STREAM_STEPS, spec.stepsMean, spec.stepsSd));
  day.restingHeartRate = Math.max(1, around(spec, offset, STREAM_RHR, spec.rhrMean, spec.rhrSd));
  day.moderateMinutes = Math.max(0, around(spec, offset, STREAM_MODERATE, spec.moderateMean, spec.moderateSd));
  day.vigorousMinutes = hits(spec.vigorousEvery, offset, PHASE_VIGOROUS) ? spec.vigorousMinutes : 0;

  if (hits(spec.nightEvery, offset, PHASE_NIGHT)) {
    // The end date is a Saturday: offsets 0 and 1 (modulo 7) are Saturday and Sunday mornings.
    const weekday = mod(offset, DAYS_PER_WEEK);
    const shift = weekday === 0 || weekday === 1 ? spec.weekendShiftMin : 0;
    const bedtime = around(spec, offset, STREAM_BEDTIME, spec.bedtimeMin + shift, spec.bedtimeSd);
    const wake = around(spec, offset, STREAM_WAKE, spec.wakeMin + shift, spec.wakeSd);
    const awake = Math.max(0, around(spec, offset, STREAM_AWAKE, spec.awakeMin, spec.awakeSd));
    const inBed = wake + MINUTES_PER_DAY - bedtime;
    day.sleepStartMin = mod(bedtime, MINUTES_PER_DAY);
    day.sleepEndMin = mod(wake, MINUTES_PER_DAY);
    day.sleepMinutes = Math.max(MIN_SLEEP_MINUTES, inBed - awake);
    if (spec.hrvPercentile >= 0) {
      day.hrvPercentile = clamp(around(spec, offset, STREAM_HRV, spec.hrvPercentile, spec.hrvSd),
        MIN_PERCENTILE, MAX_PERCENTILE);
    }
  }
  if (spec.vo2maxPercentile >= 0 && hits(spec.vo2maxEvery, offset, PHASE_VO2MAX)) {
    day.vo2maxPercentile = spec.vo2maxPercentile;
  }
  if (spec.hrr1Mean >= 0 && hits(spec.hrrEvery, offset, PHASE_HRR)) {
    day.hrr1 = Math.max(1, around(spec, offset, STREAM_HRR, spec.hrr1Mean, spec.hrr1Sd));
  }
  return day;
}

/** The starting history of a persona: `spec.days` completed days, oldest first, ending on the end date. */
export function generatePersonaHistory(spec: HesPersonaSpec): HesDay[] {
  const out: HesDay[] = [];
  for (let offset = 1 - spec.days; offset <= 0; offset++) {
    out.push(generatePersonaDay(spec, offset));
  }
  return out;
}

class PersonaDaySource implements HesDaySource {
  private spec: HesPersonaSpec;

  constructor(spec: HesPersonaSpec) {
    this.spec = spec;
  }

  dayAfter(closedDays: number): HesDay {
    return generatePersonaDay(this.spec, closedDays);
  }
}

/** The six demo personas. An unknown id gives an empty history, which scores as "Insufficient data". */
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

  /** The starting history: completed days, oldest first. */
  static history(id: string): HesDay[] {
    const spec = HesPersonas.spec(id);
    return spec === null ? [] : generatePersonaHistory(spec);
  }

  /** HES for the starting history, with the weights of `profile`. */
  static result(id: string, profile: HesProfile = HES_DEFAULT_PROFILE): HesResult {
    return computeHes(HesPersonas.history(id), profile);
  }

  /** A demo session that starts from the persona's history (live values, close the day, reset). */
  static session(id: string, profile: HesProfile = HES_DEFAULT_PROFILE): HesSession {
    const spec = HesPersonas.spec(id);
    if (spec === null) {
      return new HesSession([], null, profile);
    }
    return new HesSession(generatePersonaHistory(spec), new PersonaDaySource(spec), profile);
  }
}
