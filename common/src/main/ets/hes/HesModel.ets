// HES vNext: every number of the model in one place (specification sections 1, 2, 3, 5, 10 and 11).
// All weights, curves, thresholds, windows and minimum counts are research-informed product assumptions,
// not clinically or actuarially validated coefficients. They are copied from the specification and are
// not tuned to make any persona fit.
import { ComponentId, HesProfile } from './HesTypes';

export const HES_MODEL_VERSION: string = 'vnext-1';

/** The only HRV protocol the score takes; nights measured by another protocol are skipped. */
export const HRV_PROTOCOL: string = 'nocturnal';

/** Rolling window of completed days for steps, MVPA, resting heart rate and sleep. */
export const HES_WINDOW_DAYS: number = 28;
/** HRV looks at the most recent nights only. */
export const HES_HRV_WINDOW_DAYS: number = 14;
/** Heart-rate recovery sessions count when they are at most this many days old. */
export const HES_HRR_WINDOW_DAYS: number = 60;
/** A VO2max estimate counts when it is at most this many days old. */
export const HES_CRF_WINDOW_DAYS: number = 90;

export const HES_DAYS_PER_WEEK: number = 7;
/** A vigorous minute counts as this many moderate minutes. */
export const HES_VIGOROUS_FACTOR: number = 2;
export const HES_MINUTES_PER_HOUR: number = 60;

/** Sleep clock times are measured from 18:00 so that a night never wraps at midnight. */
export const HES_SLEEP_ANCHOR_MIN: number = 1080;
export const HES_MINUTES_PER_DAY: number = 1440;

/** Tiering: A from 80, B from 60, C below. */
export const HES_TIER_A_MIN: number = 80;
export const HES_TIER_B_MIN: number = 60;

/** Data Confidence labels, on the confidence index. */
export const HES_CONFIDENCE_HIGH_MIN: number = 0.80;
export const HES_CONFIDENCE_MEDIUM_MIN: number = 0.60;

/** Tolerance for comparisons of calculated numbers, so that a float error never moves a threshold. */
export const HES_EPSILON: number = 1e-9;

export const HES_PERMILLE: number = 1000;

/** One point of a piecewise-linear scoring curve: raw value x gives score y. */
export interface HesPoint {
  x: number;
  y: number;
}

export interface HesComponentDefinition {
  id: ComponentId;
  label: string;          // the name a screen shows
  requiredCore: boolean;  // Core components are all required for a score
  minimumCount: number;   // valid observations needed for the component to be available
  targetCount: number;    // valid observations at which data quality is 1.0
  windowDays: number;     // how many completed days back the component looks
  curve: HesPoint[];
}

// VO2max percentile for age and sex
const CRF_CURVE: HesPoint[] = [
  { x: 5, y: 10 },
  { x: 10, y: 20 },
  { x: 25, y: 45 },
  { x: 50, y: 70 },
  { x: 75, y: 88 },
  { x: 90, y: 97 },
  { x: 95, y: 100 }
];

// Resting heart rate, bpm. The plateau at the low end is on purpose: lower is not always better.
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

// MVPA, equivalent minutes per week
const MVPA_CURVE: HesPoint[] = [
  { x: 0, y: 0 },
  { x: 30, y: 20 },
  { x: 60, y: 40 },
  { x: 100, y: 60 },
  { x: 150, y: 80 },
  { x: 250, y: 95 },
  { x: 300, y: 100 }
];

// Steps per day
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

// Sleep timing regularity: timing SD, minutes
const SLEEP_REGULARITY_CURVE: HesPoint[] = [
  { x: 30, y: 100 },
  { x: 45, y: 90 },
  { x: 60, y: 80 },
  { x: 90, y: 60 },
  { x: 120, y: 40 },
  { x: 180, y: 15 },
  { x: 240, y: 0 }
];

// Sleep duration, hours
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

// HRV percentile
const HRV_CURVE: HesPoint[] = [
  { x: 5, y: 10 },
  { x: 10, y: 25 },
  { x: 25, y: 50 },
  { x: 50, y: 75 },
  { x: 75, y: 90 },
  { x: 90, y: 97 },
  { x: 95, y: 100 }
];

// Heart-rate recovery in the first 60 seconds, bpm
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
 * The eight components in the model's fixed order. The order is also the last tie-break of the
 * "Why this tier" lists.
 */
export const HES_COMPONENTS: HesComponentDefinition[] = [
  {
    id: ComponentId.CRF,
    label: 'VO₂max',
    requiredCore: false,
    minimumCount: 1,
    targetCount: 2,
    windowDays: HES_CRF_WINDOW_DAYS,
    curve: CRF_CURVE
  },
  {
    id: ComponentId.RHR,
    label: 'Resting HR',
    requiredCore: true,
    minimumCount: 10,
    targetCount: 14,
    windowDays: HES_WINDOW_DAYS,
    curve: RHR_CURVE
  },
  {
    id: ComponentId.MVPA,
    label: 'MVPA',
    requiredCore: true,
    minimumCount: 14,
    targetCount: 21,
    windowDays: HES_WINDOW_DAYS,
    curve: MVPA_CURVE
  },
  {
    id: ComponentId.STEPS,
    label: 'Daily steps',
    requiredCore: true,
    minimumCount: 14,
    targetCount: 21,
    windowDays: HES_WINDOW_DAYS,
    curve: STEPS_CURVE
  },
  {
    id: ComponentId.SLEEP_REGULARITY,
    label: 'Sleep timing regularity',
    requiredCore: true,
    minimumCount: 14,
    targetCount: 21,
    windowDays: HES_WINDOW_DAYS,
    curve: SLEEP_REGULARITY_CURVE
  },
  {
    id: ComponentId.SLEEP_DURATION,
    label: 'Sleep duration',
    requiredCore: true,
    minimumCount: 14,
    targetCount: 21,
    windowDays: HES_WINDOW_DAYS,
    curve: SLEEP_DURATION_CURVE
  },
  {
    id: ComponentId.HRV,
    label: 'HRV',
    requiredCore: false,
    minimumCount: 7,
    targetCount: 14,
    windowDays: HES_HRV_WINDOW_DAYS,
    curve: HRV_CURVE
  },
  {
    id: ComponentId.HRR,
    label: 'HRR',
    requiredCore: false,
    minimumCount: 2,
    targetCount: 3,
    windowDays: HES_HRR_WINDOW_DAYS,
    curve: HRR_CURVE
  }
];

// Weights in thousandths, in the order of HES_COMPONENTS. Integers keep the coverage exact: as floats the
// Longevity weights sum to 0.9999999999999999.
const WEIGHTS_HEALTH_WELLNESS: number[] = [125, 125, 200, 150, 150, 125, 75, 50];
const WEIGHTS_LONGEVITY_WELLNESS: number[] = [225, 150, 150, 175, 100, 75, 75, 50];

export const HES_PROFILES: HesProfile[] = [HesProfile.HEALTH_WELLNESS, HesProfile.LONGEVITY_WELLNESS];

/** Position of a component in HES_COMPONENTS. */
export function hesComponentIndex(id: ComponentId): number {
  for (let i = 0; i < HES_COMPONENTS.length; i++) {
    if (HES_COMPONENTS[i].id === id) {
      return i;
    }
  }
  return -1;
}

export function hesComponentDefinition(id: ComponentId): HesComponentDefinition {
  return HES_COMPONENTS[hesComponentIndex(id)];
}

/** The base weight of a component in a profile, in thousandths (150 = 15%). */
export function hesWeightPermille(profile: HesProfile, id: ComponentId): number {
  const index = hesComponentIndex(id);
  if (index < 0) {
    return 0;
  }
  return profile === HesProfile.LONGEVITY_WELLNESS ? WEIGHTS_LONGEVITY_WELLNESS[index] :
    WEIGHTS_HEALTH_WELLNESS[index];
}

/** The name of a profile on a screen. */
export function hesProfileLabel(profile: HesProfile): string {
  return profile === HesProfile.LONGEVITY_WELLNESS ? 'Longevity' : 'Health & wellness';
}
