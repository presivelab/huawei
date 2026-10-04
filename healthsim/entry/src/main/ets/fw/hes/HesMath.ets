// Small numeric helpers of HES-Lite. Only +, -, *, / and Math.sqrt: the same bits on every engine.
import { HES_MINUTES_PER_DAY, HES_SLEEP_ANCHOR_MIN } from './HesCurves';
import { HES_MISSING } from './HesTypes';

/** Mean of a list; HES_MISSING for an empty list (never NaN). */
export function hesMean(values: number[]): number {
  if (values.length === 0) {
    return HES_MISSING;
  }
  let sum = 0;
  for (let i = 0; i < values.length; i++) {
    sum += values[i];
  }
  return sum / values.length;
}

/** Median of a list (mean of the two middle values for an even count); HES_MISSING for an empty list. */
export function hesMedian(values: number[]): number {
  if (values.length === 0) {
    return HES_MISSING;
  }
  const sorted = values.slice().sort((a: number, b: number): number => a - b);
  const mid = Math.floor(sorted.length / 2);
  if (sorted.length % 2 === 1) {
    return sorted[mid];
  }
  return (sorted[mid - 1] + sorted[mid]) / 2;
}

/**
 * Sample standard deviation (divisor n - 1); HES_MISSING for fewer than two values.
 * Decision: the specification says "SD" without the divisor. The sample form is used because the nights
 * in the window are a sample of the person's sleep timing.
 */
export function hesSampleSd(values: number[]): number {
  if (values.length < 2) {
    return HES_MISSING;
  }
  const mean = hesMean(values);
  let squares = 0;
  for (let i = 0; i < values.length; i++) {
    const d = values[i] - mean;
    squares += d * d;
  }
  return Math.sqrt(squares / (values.length - 1));
}

/**
 * Integer rounding of the score, halves up: 84.49 gives 84, 84.50 gives 85 (specification section 15).
 */
export function hesRound(value: number): number {
  return Math.floor(value + 0.5);
}

/**
 * Midnight-safe clock time (section 6.4): minutes since 18:00. 23:30 gives 330, 00:30 gives 390, so the
 * two are 60 minutes apart instead of 23 hours.
 */
export function sleepRelativeMinutes(minutesSinceMidnight: number): number {
  return (minutesSinceMidnight - HES_SLEEP_ANCHOR_MIN + HES_MINUTES_PER_DAY) % HES_MINUTES_PER_DAY;
}

/** Timing SD (section 6.4): the root mean square of the bedtime SD and the wake-time SD, in minutes. */
export function sleepTimingSd(sdBedtime: number, sdWakeTime: number): number {
  return Math.sqrt((sdBedtime * sdBedtime + sdWakeTime * sdWakeTime) / 2);
}
