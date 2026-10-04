/*
 * View models of the monthly report on the phone. Plain data, no logic and no platform imports.
 *
 * The screens read these and nothing else. Today they are filled by the fixed preview (PreviewReports);
 * when the scoring engine is part of the build, its results are mapped onto the same shapes, so the
 * screens do not change.
 */

/** `PersonaReport.hes` and `ComponentRow.score` when there is no value. Never shown as a number. */
export const HES_NONE: number = -1;
/** `PersonaReport.pointsToNext` when the distance to the next tier is not known. */
export const POINTS_UNKNOWN: number = -1;
/** A day without data inside `ComponentRow.bars7`. */
export const BAR_NO_DATA: number = -1;
/** `LiveNow.hr` and `LiveNow.steps` when there is no reading. Never shown as a number. */
export const LIVE_NONE: number = -1;

export class ReportTier {
  static readonly A: string = 'A';
  static readonly B: string = 'B';
  static readonly C: string = 'C';
  static readonly NONE: string = 'NONE';
}

export class ReportConfidence {
  static readonly HIGH: string = 'High';
  static readonly MEDIUM: string = 'Medium';
  static readonly LOW: string = 'Low';
  static readonly INSUFFICIENT: string = 'Not enough data';
}

export class BenefitLevel {
  static readonly FULL: string = 'FULL';
  static readonly PARTIAL: string = 'PARTIAL';
  static readonly NONE: string = 'NONE';
}

/** How one day of the period counts for the wear rule. */
export class DayState {
  static readonly COMPLIANT: string = 'COMPLIANT';
  static readonly SHORT: string = 'SHORT';
  static readonly SUSPICIOUS: string = 'SUSPICIOUS';
  static readonly SICK: string = 'SICK';
  static readonly UNKNOWN: string = 'UNKNOWN';
}

/** Ids of the eight score components, in the order the report lists them. */
export class ComponentId {
  static readonly STEPS: string = 'steps';
  static readonly ACTIVE_MINUTES: string = 'activeMinutes';
  static readonly RESTING_HR: string = 'restingHr';
  static readonly SLEEP: string = 'sleep';
  static readonly SLEEP_REGULARITY: string = 'sleepRegularity';
  static readonly VO2MAX: string = 'vo2max';
  static readonly HRV: string = 'hrv';
  static readonly HR_RECOVERY: string = 'hrRecovery';
}

/** One score component: what was measured, how it scored and how much evidence stands behind it. */
export interface ComponentRow {
  id: string;            // ComponentId
  label: string;         // name, "Resting HR"
  score: number;         // 0..100, HES_NONE when the component is not available
  scoreExact: number;    // the same score before rounding, for ranking; HES_NONE when not available
  raw: string;           // the measured value as text, "9,412"; empty when not available
  unit: string;          // "/day"
  rawText: string;       // the measured value in readable units, "8,800/day"; empty when not available
  weightPct: number;     // effective weight in the score with one decimal (18.8), 0 when not available
  weightText: string;    // the same as text, "18.8%"; empty when there is no score or no value
  available: boolean;
  core: boolean;         // a Core component: the score needs it
  validCount: number;    // days, nights, estimates or sessions with data
  minCount: number;      // days or nights the score needs; 0 for a component the score does not require
  needCount: number;     // observations the component needs to be available, for all eight components
  targetCount: number;   // observations at which the evidence is complete
  countText: string;     // how far it is from the minimum, "6 of 14 nights"
  bars7: number[];       // last seven days, oldest first, 0..100; BAR_NO_DATA for a day without data
  source: string;        // where the value comes from, as text
}

export interface DayCell {
  n: number;             // 1 is the first day of the period
  state: string;         // DayState
  wornPct: number;       // share of the day the watch was worn, 0..100
}

export interface WearSummary {
  compliantDays: number;
  totalDays: number;
  nightsWorn: number;
  suspicious: number;    // suspicious breaks in the period
  flagged: boolean;
  days: DayCell[];       // one per day of the period, oldest first
}

/** Readings of the running day. Shown, never scored. */
export interface LiveNow {
  hr: number;            // bpm
  steps: number;         // steps since midnight
}

export interface PersonaReport {
  id: string;
  name: string;
  period: string;        // as read on screen, "4 Sep – 3 Oct"
  periodIso: string;     // first and last day as the claim writes them, "2026-09-04..2026-10-03"
  profile: string;       // the weight profile the score is shown in, HesProfile
  profileLabel: string;  // "Health & wellness" or "Longevity"
  partnerProfile: boolean;  // the profile is the partner's: the one eligibility and sharing use
  hes: number;           // 0..100, HES_NONE when there is no score
  tier: string;          // ReportTier
  coveragePct: number;   // Evidence coverage in percent, 87.5
  coverageText: string;  // "87.5%"
  confidence: string;    // ReportConfidence
  showWeights: boolean;  // coverage is below 100%: the effective weights differ from the model's
  eligible: boolean;     // always by the partner's profile
  benefit: string;       // BenefitLevel, always by the partner's profile
  benefitReason: string;
  pointsToNext: number;  // points to the next tier; 0 at the top tier; POINTS_UNKNOWN when not known
  components: ComponentRow[];
  wear: WearSummary;
  live: LiveNow;
  whatIf: string;        // one sentence, empty when there is none
}

/** A persona as the demo switcher lists it. */
export interface PersonaRef {
  id: string;
  name: string;
}

export function hasScore(report: PersonaReport): boolean {
  return report.hes >= 0 && report.tier !== ReportTier.NONE;
}
