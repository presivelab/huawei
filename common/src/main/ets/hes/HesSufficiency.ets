// Data sufficiency (specification section 7) and data quality (section 8): which readings are valid,
// how many there are in the component's window, and whether that is enough.
//
// Decisions where the specification is silent:
//   - a resting heart rate of 0 bpm or less is no reading (the rule the watch already uses);
//   - an MVPA day is valid only when both the moderate and the vigorous minutes are present;
//   - a night is valid for sleep duration when its total sleep time is above zero, and valid for sleep
//     timing when both clock times are present;
//   - percentiles are valid from 0 to 100; a heart-rate recovery is valid when it is above zero;
//   - HRV counts nights in its own window, the recent 14 nights (HES vNext).
import { HesComponentDefinition, HesComponentId, HesDay } from './HesTypes';

const MAX_CLOCK_MIN: number = 1439;
const MAX_PERCENTILE: number = 100;

/** The completed days a component looks at: the newest `windowDays` entries of the history. */
export function windowOf(history: HesDay[], windowDays: number): HesDay[] {
  if (history.length <= windowDays) {
    return history.slice();
  }
  return history.slice(history.length - windowDays);
}

function isClockTime(value: number): boolean {
  return value >= 0 && value <= MAX_CLOCK_MIN;
}

function isPercentile(value: number): boolean {
  return value >= 0 && value <= MAX_PERCENTILE;
}

/** True when this day carries a valid reading for the component. */
export function isValidFor(id: HesComponentId, day: HesDay): boolean {
  switch (id) {
    case HesComponentId.CRF:
      return isPercentile(day.vo2maxPercentile);
    case HesComponentId.RHR:
      return day.restingHeartRate > 0;
    case HesComponentId.MVPA:
      return day.moderateMinutes >= 0 && day.vigorousMinutes >= 0;
    case HesComponentId.SLEEP_REGULARITY:
      return isClockTime(day.sleepStartMin) && isClockTime(day.sleepEndMin);
    case HesComponentId.STEPS:
      return day.steps >= 0;
    case HesComponentId.SLEEP_DURATION:
      return day.sleepMinutes > 0;
    case HesComponentId.HRV:
      return isPercentile(day.hrvPercentile);
    case HesComponentId.HRR:
      return day.hrr1 > 0;
    default:
      return false;
  }
}

/** The valid days of a component inside its window, oldest first. */
export function validDays(def: HesComponentDefinition, history: HesDay[]): HesDay[] {
  const days = windowOf(history, def.windowDays);
  const valid: HesDay[] = [];
  for (let i = 0; i < days.length; i++) {
    if (isValidFor(def.id, days[i])) {
      valid.push(days[i]);
    }
  }
  return valid;
}

/** Availability (section 7): available = validCount >= minimum. */
export function isSufficient(validCount: number, minCount: number): boolean {
  return validCount >= minCount;
}

/** Data quality (section 8): min(validCount / targetCount, 1). Never NaN: a target of 0 gives 0. */
export function quality(validCount: number, targetCount: number): number {
  if (targetCount <= 0 || validCount <= 0) {
    return 0;
  }
  return Math.min(validCount / targetCount, 1);
}
