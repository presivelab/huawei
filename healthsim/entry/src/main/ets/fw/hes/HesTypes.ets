// HES-Lite v1.0 data model (specification section 12), written for ArkTS.
// Pure types and constants: no system-kit imports, so this file runs in the Node logic tests.
//
// Differences from the skeleton in the specification, all on purpose:
//   - the specification marks absent numbers as optional fields (rawValue?, score?); here a number that is
//     not available is HES_MISSING (-1), the convention of HealthRecords. Zero is never written in place of
//     a missing value: zero steps is a reading, "no reading" is -1;
//   - string unions are enums with the specification's strings as values;
//   - the tier is a string with the values the claim already uses ('A', 'B', 'C', 'NONE').
import { HEALTH_MISSING } from '../health/HealthRecords';

/** A value that is not available. Never zero. */
export const HES_MISSING: number = HEALTH_MISSING;

export enum HesComponentId {
  CRF = 'crf',
  RHR = 'rhr',
  MVPA = 'mvpa',
  SLEEP_REGULARITY = 'sleepRegularity',
  STEPS = 'steps',
  SLEEP_DURATION = 'sleepDuration',
  HRV = 'hrv',
  HRR = 'hrr'
}

/**
 * The product a score is calculated for (HES vNext). Each profile has its own base weights; the curves,
 * minimum and target counts, windows and tier boundaries are the same for both.
 *   HEALTH_WELLNESS    monthly health insurance
 *   LONGEVITY_WELLNESS life insurance (polisa na życie)
 */
export enum HesProfile {
  HEALTH_WELLNESS = 'HEALTH_WELLNESS',
  LONGEVITY_WELLNESS = 'LONGEVITY_WELLNESS'
}

export enum HesStatus {
  OK = 'ok',
  INSUFFICIENT_DATA = 'insufficient_data'
}

export enum HesConfidence {
  HIGH = 'High',
  MEDIUM = 'Medium',
  LOW = 'Low',
  INSUFFICIENT_DATA = 'Insufficient data'
}

/** One point of a piecewise-linear scoring curve: raw value x gives score y. */
export interface HesPoint {
  x: number;
  y: number;
}

export interface HesComponentDefinition {
  id: HesComponentId;
  label: string;           // the name a screen shows
  unit: string;            // unit of the raw value
  weightPermille: number;  // base weight of the profile, in thousandths (150 = 15%); integers keep rounding exact
  requiredCore: boolean;   // Core components are all required for a score
  minCount: number;        // valid observations needed for the component to be available
  targetCount: number;     // valid observations at which data quality is 1.0
  windowDays: number;      // how many completed days back the component looks
  curve: HesPoint[];
}

/**
 * One completed calendar day of history. The engine takes a list of these, oldest first, one entry per
 * calendar day with no days skipped: a day with no data is an entry whose values are all HES_MISSING.
 * The night belongs to the day the person woke up on.
 */
export interface HesDay {
  date: string;              // local calendar day, YYYY-MM-DD
  steps: number;
  restingHeartRate: number;  // bpm
  moderateMinutes: number;
  vigorousMinutes: number;
  sleepStartMin: number;     // local clock time of falling asleep, minutes since midnight (0..1439)
  sleepEndMin: number;       // local clock time of waking up, minutes since midnight (0..1439)
  sleepMinutes: number;      // total sleep time, minutes
  vo2maxPercentile: number;  // 0..100, only on days with an estimate
  hrvPercentile: number;     // 0..100, one value per night
  hrr1: number;              // bpm dropped in the first 60 s after exercise, only on days with a session
}

export interface HesComponentResult {
  id: HesComponentId;
  label: string;
  unit: string;
  core: boolean;
  rawValue: number;         // HES_MISSING when the component is not available
  score: number;            // 0..100, not rounded; HES_MISSING when the component is not available
  available: boolean;       // validCount >= minCount
  validCount: number;
  minCount: number;
  targetCount: number;
  quality: number;          // min(validCount / targetCount, 1)
  baseWeight: number;       // 0..1
  effectiveWeight: number;  // baseWeight / sum of the base weights of the available components; 0 when missing
}

export interface HesResult {
  profile: HesProfile;       // the weights the score was calculated with
  status: HesStatus;
  score: number;             // integer 0..100; HES_MISSING when the Core set is incomplete
  tier: string;              // 'A' | 'B' | 'C', or 'NONE' when there is no score
  coverage: number;          // Evidence Coverage, percent in steps of 0.5 (never rounded)
  confidence: HesConfidence;
  components: HesComponentResult[];  // always all eight, in the order of HES_COMPONENTS
}

/** "Why this tier" (specification section 11). A missing component is never listed as a weak factor. */
export interface HesWhy {
  strongest: HesComponentResult[];    // highest scores first
  improvement: HesComponentResult[];  // lowest scores first
  missing: HesComponentResult[];      // components that are not available, Core and Advanced
}

/** A day with no data at all. */
export function emptyHesDay(date: string): HesDay {
  return {
    date: date,
    steps: HES_MISSING,
    restingHeartRate: HES_MISSING,
    moderateMinutes: HES_MISSING,
    vigorousMinutes: HES_MISSING,
    sleepStartMin: HES_MISSING,
    sleepEndMin: HES_MISSING,
    sleepMinutes: HES_MISSING,
    vo2maxPercentile: HES_MISSING,
    hrvPercentile: HES_MISSING,
    hrr1: HES_MISSING
  };
}

export function copyHesDay(day: HesDay): HesDay {
  return {
    date: day.date,
    steps: day.steps,
    restingHeartRate: day.restingHeartRate,
    moderateMinutes: day.moderateMinutes,
    vigorousMinutes: day.vigorousMinutes,
    sleepStartMin: day.sleepStartMin,
    sleepEndMin: day.sleepEndMin,
    sleepMinutes: day.sleepMinutes,
    vo2maxPercentile: day.vo2maxPercentile,
    hrvPercentile: day.hrvPercentile,
    hrr1: day.hrr1
  };
}
