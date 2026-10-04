// HES-Lite v1.0: every number of the model in one place (specification sections 2, 3, 6, 7, 8 and 9).
// All weights, curves, thresholds and minimum counts are prototype product assumptions.
// They are copied from the specification and are not tuned to make any persona fit.
import { HesComponentDefinition, HesComponentId, HesPoint } from './HesTypes';

/** Rolling window of completed days for steps, MVPA, resting heart rate, sleep and HRV. */
export const HES_WINDOW_DAYS: number = 28;
/** MVPA is reported per week. */
export const HES_DAYS_PER_WEEK: number = 7;
/** Heart-rate recovery sessions count when they are at most this many days old (section 7). */
export const HES_HRR_WINDOW_DAYS: number = 60;
/** A VO2max estimate counts when it is at most this many days old (sections 6.1 and 7). */
export const HES_VO2MAX_WINDOW_DAYS: number = 90;

/** Tiering (section 9): A from 80, B from 60, C below. */
export const HES_TIER_A_MIN: number = 80;
export const HES_TIER_B_MIN: number = 60;

/** Data Confidence labels (section 8). */
export const HES_CONFIDENCE_HIGH_MIN: number = 0.80;
export const HES_CONFIDENCE_MEDIUM_MIN: number = 0.60;

/** Sleep clock times are measured from 18:00 so that a night never wraps at midnight (section 6.4). */
export const HES_SLEEP_ANCHOR_MIN: number = 1080;
export const HES_MINUTES_PER_DAY: number = 1440;

// 6.1 CRF / VO2max percentile
const CRF_CURVE: HesPoint[] = [
  { x: 5, y: 10 },
  { x: 10, y: 20 },
  { x: 25, y: 45 },
  { x: 50, y: 70 },
  { x: 75, y: 88 },
  { x: 90, y: 97 },
  { x: 95, y: 100 }
];

// 6.2 Resting heart rate, bpm
const RHR_CURVE: HesPoint[] = [
  { x: 40, y: 90 },
  { x: 45, y: 98 },
  { x: 50, y: 100 },
  { x: 55, y: 100 },
  { x: 60, y: 95 },
  { x: 65, y: 90 },
  { x: 70, y: 84 },
  { x: 75, y: 76 },
  { x: 80, y: 66 },
  { x: 90, y: 45 },
  { x: 100, y: 20 },
  { x: 110, y: 5 }
];

// 6.3 MVPA, equivalent minutes per week
const MVPA_CURVE: HesPoint[] = [
  { x: 0, y: 0 },
  { x: 30, y: 20 },
  { x: 60, y: 40 },
  { x: 100, y: 60 },
  { x: 150, y: 80 },
  { x: 250, y: 95 },
  { x: 300, y: 100 }
];

// 6.4 Sleep timing regularity, timing SD in minutes
const SLEEP_REGULARITY_CURVE: HesPoint[] = [
  { x: 30, y: 100 },
  { x: 45, y: 90 },
  { x: 60, y: 80 },
  { x: 90, y: 60 },
  { x: 120, y: 40 },
  { x: 180, y: 15 },
  { x: 240, y: 0 }
];

// 6.5 Steps per day
const STEPS_CURVE: HesPoint[] = [
  { x: 1000, y: 0 },
  { x: 2000, y: 20 },
  { x: 4000, y: 50 },
  { x: 5000, y: 65 },
  { x: 6000, y: 80 },
  { x: 7000, y: 90 },
  { x: 8000, y: 95 },
  { x: 10000, y: 100 }
];

// 6.6 Sleep duration, hours
const SLEEP_DURATION_CURVE: HesPoint[] = [
  { x: 4.5, y: 0 },
  { x: 5.0, y: 25 },
  { x: 5.5, y: 45 },
  { x: 6.0, y: 65 },
  { x: 6.5, y: 82 },
  { x: 7.0, y: 95 },
  { x: 7.5, y: 100 },
  { x: 8.0, y: 100 },
  { x: 8.5, y: 100 },
  { x: 9.0, y: 100 },
  { x: 9.5, y: 95 },
  { x: 10.0, y: 90 },
  { x: 11.0, y: 80 },
  { x: 12.0, y: 65 }
];

// 6.7 HRV percentile
const HRV_CURVE: HesPoint[] = [
  { x: 5, y: 10 },
  { x: 10, y: 25 },
  { x: 25, y: 50 },
  { x: 50, y: 75 },
  { x: 75, y: 90 },
  { x: 90, y: 97 },
  { x: 95, y: 100 }
];

// 6.8 Heart-rate recovery, HRR1 in bpm
const HRR_CURVE: HesPoint[] = [
  { x: 12, y: 10 },
  { x: 18, y: 30 },
  { x: 24, y: 55 },
  { x: 30, y: 70 },
  { x: 36, y: 82 },
  { x: 42, y: 92 },
  { x: 50, y: 100 }
];

/**
 * The eight components in the order of the weight table (section 2.1), with the minimum and target counts
 * of section 7. The labels are the ones the phone screens use; the specification names are in the comments.
 */
export const HES_COMPONENTS: HesComponentDefinition[] = [
  {
    // CRF / VO2max, 15%, Advanced. 1 valid estimate in 90 days, target 2.
    id: HesComponentId.CRF,
    label: 'VO₂max',
    unit: 'percentile',
    weightPermille: 150,
    requiredCore: false,
    minCount: 1,
    targetCount: 2,
    windowDays: HES_VO2MAX_WINDOW_DAYS,
    curve: CRF_CURVE
  },
  {
    // Resting Heart Rate, 15%, Core. 10 valid days, target 14.
    id: HesComponentId.RHR,
    label: 'Resting heart rate',
    unit: 'bpm',
    weightPermille: 150,
    requiredCore: true,
    minCount: 10,
    targetCount: 14,
    windowDays: HES_WINDOW_DAYS,
    curve: RHR_CURVE
  },
  {
    // MVPA, 15%, Core. 14 valid days, target 21.
    id: HesComponentId.MVPA,
    label: 'Active minutes',
    unit: 'min/week',
    weightPermille: 150,
    requiredCore: true,
    minCount: 14,
    targetCount: 21,
    windowDays: HES_WINDOW_DAYS,
    curve: MVPA_CURVE
  },
  {
    // Sleep Timing Regularity, 15%, Core. 14 valid nights, target 21.
    id: HesComponentId.SLEEP_REGULARITY,
    label: 'Sleep timing regularity',
    unit: 'min',
    weightPermille: 150,
    requiredCore: true,
    minCount: 14,
    targetCount: 21,
    windowDays: HES_WINDOW_DAYS,
    curve: SLEEP_REGULARITY_CURVE
  },
  {
    // Steps, 12.5%, Core. 14 valid days, target 21.
    id: HesComponentId.STEPS,
    label: 'Daily steps',
    unit: 'steps/day',
    weightPermille: 125,
    requiredCore: true,
    minCount: 14,
    targetCount: 21,
    windowDays: HES_WINDOW_DAYS,
    curve: STEPS_CURVE
  },
  {
    // Sleep Duration, 12.5%, Core. 14 valid nights, target 21.
    id: HesComponentId.SLEEP_DURATION,
    label: 'Sleep duration',
    unit: 'h',
    weightPermille: 125,
    requiredCore: true,
    minCount: 14,
    targetCount: 21,
    windowDays: HES_WINDOW_DAYS,
    curve: SLEEP_DURATION_CURVE
  },
  {
    // HRV, 10%, Advanced. 7 valid nights, target 14.
    id: HesComponentId.HRV,
    label: 'HRV',
    unit: 'percentile',
    weightPermille: 100,
    requiredCore: false,
    minCount: 7,
    targetCount: 14,
    windowDays: HES_WINDOW_DAYS,
    curve: HRV_CURVE
  },
  {
    // HRR, 5%, Advanced. 2 valid sessions in 60 days, target 3.
    id: HesComponentId.HRR,
    label: 'Heart-rate recovery',
    unit: 'bpm',
    weightPermille: 50,
    requiredCore: false,
    minCount: 2,
    targetCount: 3,
    windowDays: HES_HRR_WINDOW_DAYS,
    curve: HRR_CURVE
  }
];

/** The definition of one component. */
export function hesDefinition(id: HesComponentId): HesComponentDefinition {
  for (let i = 0; i < HES_COMPONENTS.length; i++) {
    if (HES_COMPONENTS[i].id === id) {
      return HES_COMPONENTS[i];
    }
  }
  throw new Error('Unknown HES component');
}
