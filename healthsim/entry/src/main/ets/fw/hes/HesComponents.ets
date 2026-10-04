// Component scoring (specification section 6): raw value of each component from the history, then its
// score on the component's curve.
//
// Decisions where the specification is silent or contradicts itself:
//   - MVPA: the specification divides the 28-day sum by 4. With missing days that would count every missing
//     day as zero minutes, against "missing metrics are not treated as zero". Here the weekly value is the
//     mean of the valid days times 7, which is the same number when all 28 days are valid;
//   - HRV: the specification gives an input (a percentile) and a minimum of nights, but no aggregation.
//     The median of the valid nights in the window is used, as for the other nightly values;
//   - heart-rate recovery: no aggregation is given either. The median of the valid sessions is used;
//   - VO2max: the latest valid estimate, as written;
//   - sleep duration is scored in hours (the curve's unit); the history carries minutes;
//   - component scores are kept unrounded. Only the final score is rounded (section 4.2);
//   - a raw value that is not a finite number at or above zero makes the component not available
//     (HES vNext section 16). Each reading is finite, but a mean of very large readings can overflow
//     to Infinity; such a component has no raw value and no score, like any other missing component.
import { HES_DAYS_PER_WEEK, HES_DEFAULT_PROFILE, hesComponentsFor } from './HesCurves';
import { hesMean, hesMedian, hesSampleSd, hesUnwrapClock, sleepRelativeMinutes, sleepTimingSd } from './HesMath';
import { piecewiseScore } from './HesPiecewise';
import { isSufficient, quality, validDays } from './HesSufficiency';
import { HesComponentDefinition, HesComponentId, HesComponentResult, HesDay, HesProfile, HES_MISSING } from './HesTypes';

const MINUTES_PER_HOUR: number = 60;
const PERMILLE: number = 1000;

/** Equivalent MVPA minutes of one day (section 6.3): moderate + 2 x vigorous. */
export function equivalentMvpa(moderateMinutes: number, vigorousMinutes: number): number {
  return moderateMinutes + 2 * vigorousMinutes;
}

function numbersOf(id: HesComponentId, days: HesDay[]): number[] {
  const out: number[] = [];
  for (let i = 0; i < days.length; i++) {
    const day = days[i];
    switch (id) {
      case HesComponentId.CRF:
        out.push(day.vo2maxPercentile);
        break;
      case HesComponentId.RHR:
        out.push(day.restingHeartRate);
        break;
      case HesComponentId.MVPA:
        out.push(equivalentMvpa(day.moderateMinutes, day.vigorousMinutes));
        break;
      case HesComponentId.STEPS:
        out.push(day.steps);
        break;
      case HesComponentId.SLEEP_DURATION:
        out.push(day.sleepMinutes / MINUTES_PER_HOUR);
        break;
      case HesComponentId.HRV:
        out.push(day.hrvPercentile);
        break;
      case HesComponentId.HRR:
        out.push(day.hrr1);
        break;
      default:
        break;
    }
  }
  return out;
}

function timingSdOf(days: HesDay[]): number {
  const bedtimes: number[] = [];
  const wakeTimes: number[] = [];
  for (let i = 0; i < days.length; i++) {
    bedtimes.push(sleepRelativeMinutes(days[i].sleepStartMin));
    wakeTimes.push(sleepRelativeMinutes(days[i].sleepEndMin));
  }
  // Unwrapped first: nights on both sides of 18:00 are close, not a day apart.
  const sdBed = hesSampleSd(hesUnwrapClock(bedtimes));
  const sdWake = hesSampleSd(hesUnwrapClock(wakeTimes));
  if (sdBed < 0 || sdWake < 0) {
    return HES_MISSING;
  }
  return sleepTimingSd(sdBed, sdWake);
}

/** Raw value of a component from its valid days (already inside the window). HES_MISSING when none. */
export function rawValueOf(id: HesComponentId, valid: HesDay[]): number {
  if (valid.length === 0) {
    return HES_MISSING;
  }
  switch (id) {
    case HesComponentId.CRF:
      return valid[valid.length - 1].vo2maxPercentile;
    case HesComponentId.RHR:
    case HesComponentId.SLEEP_DURATION:
    case HesComponentId.HRV:
    case HesComponentId.HRR:
      return hesMedian(numbersOf(id, valid));
    case HesComponentId.MVPA:
      return hesMean(numbersOf(id, valid)) * HES_DAYS_PER_WEEK;
    case HesComponentId.STEPS:
      return hesMean(numbersOf(id, valid));
    case HesComponentId.SLEEP_REGULARITY:
      return timingSdOf(valid);
    default:
      return HES_MISSING;
  }
}

/** A raw value the curves can score: a finite number at or above zero. Never NaN or Infinity. */
function isUsableRaw(rawValue: number): boolean {
  return Number.isFinite(rawValue) && rawValue >= 0;
}

/** Score of a raw value on the component's curve, 0..100, not rounded. */
export function componentScore(def: HesComponentDefinition, rawValue: number): number {
  return piecewiseScore(rawValue, def.curve);
}

/**
 * One component from the history: valid count, availability, quality, raw value and score.
 * The effective weight is filled in by the composite step.
 */
export function evaluateComponent(def: HesComponentDefinition, history: HesDay[]): HesComponentResult {
  const valid = validDays(def, history);
  let available = isSufficient(valid.length, def.minCount);
  let rawValue = HES_MISSING;
  let score = HES_MISSING;
  if (available) {
    const raw = rawValueOf(def.id, valid);
    const points = isUsableRaw(raw) ? componentScore(def, raw) : HES_MISSING;
    if (Number.isFinite(points) && points >= 0) {
      rawValue = raw;
      score = points;
    } else {
      available = false;
    }
  }
  return {
    id: def.id,
    label: def.label,
    unit: def.unit,
    core: def.requiredCore,
    rawValue: rawValue,
    score: score,
    available: available,
    validCount: valid.length,
    minCount: def.minCount,
    targetCount: def.targetCount,
    quality: quality(valid.length, def.targetCount),
    baseWeight: def.weightPermille / PERMILLE,
    effectiveWeight: 0
  };
}

/** All eight components with the base weights of `profile`, in the order of HES_COMPONENTS. */
export function evaluateComponents(history: HesDay[],
  profile: HesProfile = HES_DEFAULT_PROFILE): HesComponentResult[] {
  const defs = hesComponentsFor(profile);
  const out: HesComponentResult[] = [];
  for (let i = 0; i < defs.length; i++) {
    out.push(evaluateComponent(defs[i], history));
  }
  return out;
}
