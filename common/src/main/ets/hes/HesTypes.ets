// HES vNext data model (specification section 15), written for ArkTS.
// Pure types: no system-kit imports, so this file runs in the Node logic tests.
//
// A value that is not available is an absent field (undefined). Zero is never written in place of a
// missing value: zero steps is a reading, "no reading" is no field at all.

export enum HesProfile {
  HEALTH_WELLNESS = 'HEALTH_WELLNESS',
  LONGEVITY_WELLNESS = 'LONGEVITY_WELLNESS'
}

export enum ComponentId {
  CRF = 'crf',
  RHR = 'rhr',
  MVPA = 'mvpa',
  STEPS = 'steps',
  SLEEP_REGULARITY = 'sleepRegularity',
  SLEEP_DURATION = 'sleepDuration',
  HRV = 'hrv',
  HRR = 'hrr'
}

export enum HesTier {
  A = 'A',
  B = 'B',
  C = 'C',
  NONE = 'NONE'
}

export enum HesConfidence {
  HIGH = 'HIGH',
  MEDIUM = 'MEDIUM',
  LOW = 'LOW',
  NOT_ENOUGH_DATA = 'NOT_ENOUGH_DATA'
}

export enum HesStatus {
  OK = 'OK',
  INSUFFICIENT_DATA = 'INSUFFICIENT_DATA'
}

/** One night. It belongs to the day the person woke up on. Clock times are local minutes since midnight. */
export interface HesSleep {
  bedMin: number;
  wakeMin: number;
  totalSleepMin: number;
}

/** One night's HRV as a normalized percentile, with the protocol it was measured by. */
export interface HesHrvNight {
  percentile: number;
  protocol: string;
}

/** One completed calendar day. Every reading is optional: an absent field is "no valid reading". */
export interface HesDayRecord {
  date: string;  // local calendar day, YYYY-MM-DD
  steps?: number;
  moderateMin?: number;
  vigorousMin?: number;
  restingHr?: number;  // the day's resting heart rate from the source, never a live reading
  sleep?: HesSleep;
  hrv?: HesHrvNight;
}

/** A VO2max estimate as a percentile for age and sex, as the source supplies it. */
export interface HesCrfEstimate {
  date: string;
  percentile: number;
}

/** One heart-rate recovery session: the peak heart rate and the heart rate 60 seconds later. */
export interface HesHrrSession {
  date: string;
  protocolId: string;
  peakHr: number;
  hr60: number;
}

export interface HesHistory {
  days: HesDayRecord[];  // completed days only, oldest first
  crf: HesCrfEstimate[];
  hrr: HesHrrSession[];
}

export interface ComponentResult {
  id: ComponentId;
  label: string;
  rawValue?: number;         // absent when the component is not available
  score?: number;            // 0..100, not rounded; absent when the component is not available
  available: boolean;        // validCount >= minimumCount
  requiredCore: boolean;
  validCount: number;
  minimumCount: number;
  targetCount: number;
  quality: number;           // min(validCount / targetCount, 1)
  baseWeight: number;        // 0..1, the model's weight in the result's profile
  baseWeightPermille: number;  // the same weight in thousandths, an integer
  effectiveWeight?: number;  // baseWeight / sum of the base weights of the available components
}

export interface HesResult {
  profile: HesProfile;
  score?: number;            // integer 0..100; absent when the Core set is incomplete
  observed?: number;         // the score before rounding: for tests and debugging, not for a screen
  tier: HesTier;
  coverage: number;          // Evidence Coverage, percent (87.5)
  coveragePermille: number;  // the same in thousandths, an integer (875)
  confidence: HesConfidence;
  confidenceIndex?: number;  // 0..1; absent when the Core set is incomplete
  status: HesStatus;
  components: ComponentResult[];  // always all eight, in the order of HES_COMPONENT_ORDER
  modelVersion: string;
}
