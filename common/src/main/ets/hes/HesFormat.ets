// Numbers of the score as text, one place for both apps so that FairWear and Health Sim write them alike.
// No formulas of the model here: only rounding for display and units.
import { hesRound } from './HesEngine';
import { HES_EPSILON, HES_MINUTES_PER_HOUR, hesProfileLabel } from './HesModel';
import { ComponentId, ComponentResult, HesConfidence, HesProfile, HesResult, HesStatus, HesTier } from './HesTypes';

const TENTHS: number = 10;
const PERCENT: number = 100;
const HALF: number = 0.5;

/** One decimal, halves up, always written: 18.75 gives "18.8", 20 gives "20.0". */
export function hesOneDecimal(value: number): string {
  const tenths = Math.floor(value * TENTHS + HALF + HES_EPSILON);
  return `${Math.floor(tenths / TENTHS)}.${tenths % TENTHS}`;
}

/** Evidence coverage from thousandths: 875 gives "87.5%", 750 gives "75%", 1000 gives "100%". */
export function hesCoverageText(coveragePermille: number): string {
  const whole = Math.floor(coveragePermille / TENTHS);
  const tenth = coveragePermille % TENTHS;
  return tenth === 0 ? `${whole}%` : `${whole}.${tenth}%`;
}

/** An effective weight (0..1) as a percentage with one decimal: 0.1875 gives "18.8%". */
export function hesWeightText(weight: number): string {
  return `${hesOneDecimal(weight * PERCENT)}%`;
}

/** The effective weight of a component in percent with one decimal as a number (18.8); 0 when there is none. */
export function hesWeightPct(component: ComponentResult): number {
  const weight = component.effectiveWeight;
  if (weight === undefined) {
    return 0;
  }
  return Math.floor(weight * PERCENT * TENTHS + HALF + HES_EPSILON) / TENTHS;
}

export function hesConfidenceLabel(confidence: HesConfidence): string {
  switch (confidence) {
    case HesConfidence.HIGH:
      return 'High';
    case HesConfidence.MEDIUM:
      return 'Medium';
    case HesConfidence.LOW:
      return 'Low';
    default:
      return 'Not enough data';
  }
}

// 9412.4 -> "9,412".
export function hesThousands(value: number): string {
  const digits = `${hesRound(value)}`;
  let out = '';
  for (let i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 === 0) {
      out += ',';
    }
    out += digits.charAt(i);
  }
  return out;
}

// 82 -> "82nd", 11 -> "11th".
export function hesOrdinal(value: number): string {
  const n = hesRound(value);
  const lastTwo = n % 100;
  const last = n % 10;
  if (lastTwo >= 11 && lastTwo <= 13) {
    return `${n}th`;
  }
  if (last === 1) {
    return `${n}st`;
  }
  if (last === 2) {
    return `${n}nd`;
  }
  if (last === 3) {
    return `${n}rd`;
  }
  return `${n}th`;
}

// 7.4 -> "7 h 24 min", 7 -> "7 h".
export function hesHoursText(hours: number): string {
  const total = hesRound(hours * HES_MINUTES_PER_HOUR);
  const h = Math.floor(total / HES_MINUTES_PER_HOUR);
  const m = total % HES_MINUTES_PER_HOUR;
  return m === 0 ? `${h} h` : `${h} h ${m} min`;
}

/**
 * The raw value of a component in readable units: "8,800/day", "238 min/week (vigorous counts ×2)",
 * "58 bpm", "7 h 24 min", "±45 min", "77th percentile (age & sex)", "60th percentile",
 * "32 bpm drop in 60 s".
 */
export function hesRawText(id: ComponentId, value: number): string {
  switch (id) {
    case ComponentId.STEPS:
      return `${hesThousands(value)}/day`;
    case ComponentId.MVPA:
      return `${hesRound(value)} min/week (vigorous counts ×2)`;
    case ComponentId.RHR:
      return `${hesRound(value)} bpm`;
    case ComponentId.SLEEP_DURATION:
      return hesHoursText(value);
    case ComponentId.SLEEP_REGULARITY:
      return `±${hesRound(value)} min`;
    case ComponentId.CRF:
      return `${hesOrdinal(value)} percentile (age & sex)`;
    case ComponentId.HRV:
      return `${hesOrdinal(value)} percentile`;
    default:
      return `${hesRound(value)} bpm drop in 60 s`;
  }
}

/** What one observation of a component is: "days", "nights", "sessions"; empty for VO2max estimates. */
export function hesCountUnit(id: ComponentId): string {
  switch (id) {
    case ComponentId.STEPS:
    case ComponentId.MVPA:
    case ComponentId.RHR:
      return 'days';
    case ComponentId.SLEEP_DURATION:
    case ComponentId.SLEEP_REGULARITY:
    case ComponentId.HRV:
      return 'nights';
    case ComponentId.HRR:
      return 'sessions';
    default:
      return '';
  }
}

/** How far a component is from its minimum: "6 of 14 nights", "0 of 2 sessions", "0 of 1". */
export function hesCountText(component: ComponentResult): string {
  const unit = hesCountUnit(component.id);
  const text = `${component.validCount} of ${component.minimumCount}`;
  return unit.length === 0 ? text : `${text} ${unit}`;
}

/** "Health & wellness (set by partner)" for the profile a partner fixed. */
export function hesPartnerProfileText(profile: HesProfile): string {
  return `${hesProfileLabel(profile)} (set by partner)`;
}

/** One line for a check or a preview: "92 · A · 100% · High"; without a score "No score · 47.5%". */
export function hesSummaryText(result: HesResult): string {
  const coverage = hesCoverageText(result.coveragePermille);
  const score = result.score;
  if (result.status !== HesStatus.OK || score === undefined || result.tier === HesTier.NONE) {
    return `No score · ${coverage}`;
  }
  return `${score} · ${result.tier} · ${coverage} · ${hesConfidenceLabel(result.confidence)}`;
}
