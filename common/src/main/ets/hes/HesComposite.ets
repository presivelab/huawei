// Composite score (specification section 4): Evidence Coverage, effective weights and the observed HES.
// A component that is not available is left out of the numerator and of the denominator. It is never zero.
//
// Decision: the arithmetic runs on weights in thousandths (150, 125, 100, 50), which are whole numbers.
// With fractions, 0.15 + 0.15 + 0.125 is not exactly 0.425 in floating point and a coverage of 42.5%
// could round either way; with whole numbers 42.5 rounds up to 43 and 84.50 rounds up to 85 every time.
import { HES_COMPONENTS } from './HesCurves';
import { hesRound } from './HesMath';
import { HesComponentResult, HES_MISSING } from './HesTypes';

const PERMILLE: number = 1000;
const PERMILLE_PER_PERCENT: number = 10;

function permilleOf(component: HesComponentResult): number {
  return Math.round(component.baseWeight * PERMILLE);
}

function scored(component: HesComponentResult): boolean {
  return component.available && component.score >= 0;
}

/** Sum of the base weights of the available components, in thousandths. */
export function availableWeightPermille(components: HesComponentResult[]): number {
  let sum = 0;
  for (let i = 0; i < components.length; i++) {
    if (components[i].available) {
      sum += permilleOf(components[i]);
    }
  }
  return sum;
}

/** Evidence Coverage (section 4.1): 100 x the sum of the base weights of the available components. */
export function coverage(components: HesComponentResult[]): number {
  return hesRound(availableWeightPermille(components) / PERMILLE_PER_PERCENT);
}

/**
 * Observed HES before rounding (section 4.2): the weighted mean of the available component scores.
 * HES_MISSING when nothing is available, so there is never a division by zero.
 */
export function observedHes(components: HesComponentResult[]): number {
  let numerator = 0;
  let denominator = 0;
  for (let i = 0; i < components.length; i++) {
    if (scored(components[i])) {
      const weight = permilleOf(components[i]);
      numerator += weight * components[i].score;
      denominator += weight;
    }
  }
  if (denominator <= 0) {
    return HES_MISSING;
  }
  return numerator / denominator;
}

/** HES = round(ObservedHES), an integer; HES_MISSING when nothing is available. */
export function calculateObservedHes(components: HesComponentResult[]): number {
  const observed = observedHes(components);
  if (observed < 0) {
    return HES_MISSING;
  }
  return hesRound(observed);
}

/** True when every Core component of the model is in the list and available (sections 3.1 and 9). */
export function isCoreComplete(components: HesComponentResult[]): boolean {
  let needed = 0;
  for (let i = 0; i < HES_COMPONENTS.length; i++) {
    if (HES_COMPONENTS[i].requiredCore) {
      needed++;
    }
  }
  let present = 0;
  for (let i = 0; i < components.length; i++) {
    if (components[i].core && components[i].available) {
      present++;
    }
  }
  return present === needed;
}

/**
 * Fills in the effective weights (section 11): base weight / sum of the base weights of the available
 * components. They add up to 1 over the available components; a missing component gets 0.
 */
export function applyEffectiveWeights(components: HesComponentResult[]): void {
  const total = availableWeightPermille(components);
  for (let i = 0; i < components.length; i++) {
    if (components[i].available && total > 0) {
      components[i].effectiveWeight = permilleOf(components[i]) / total;
    } else {
      components[i].effectiveWeight = 0;
    }
  }
}
