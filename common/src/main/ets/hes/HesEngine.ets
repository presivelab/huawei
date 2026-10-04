// HES vNext: from a history of completed days to the score (specification sections 6 to 11).
// Deterministic rules and curves over completed days. No learned model, no network, no clock, no I/O.
// All weights, curves, thresholds, windows and minimum counts are product assumptions (HesModel.ets).
import { aggregate, aggregateOf, HesAggregates } from './HesAggregate';
import { piecewise } from './HesCurves';
import {
  HES_COMPONENTS,
  HES_CONFIDENCE_HIGH_MIN,
  HES_CONFIDENCE_MEDIUM_MIN,
  HES_EPSILON,
  HES_MODEL_VERSION,
  HES_PERMILLE,
  HES_TIER_A_MIN,
  HES_TIER_B_MIN,
  hesWeightPermille
} from './HesModel';
import {
  ComponentResult,
  HesConfidence,
  HesHistory,
  HesProfile,
  HesResult,
  HesStatus,
  HesTier
} from './HesTypes';

const HALF: number = 0.5;
const PERCENT_PER_PERMILLE: number = 10;

/**
 * Integer rounding of the score, halves up: 84.49 gives 84, 84.50 gives 85. The small tolerance keeps a
 * half that a float calculation left a hair below .5 on the upper side.
 */
export function hesRound(observed: number): number {
  return Math.floor(observed + HALF + HES_EPSILON);
}

/** Tier of a rounded score: A from 80, B from 60, C below. */
export function tierFromHes(score: number): HesTier {
  if (score >= HES_TIER_A_MIN) {
    return HesTier.A;
  }
  if (score >= HES_TIER_B_MIN) {
    return HesTier.B;
  }
  return HesTier.C;
}

/** Data Confidence label of a confidence index: High from 0.80, Medium from 0.60, Low below. */
export function confidenceFromIndex(index: number): HesConfidence {
  if (index >= HES_CONFIDENCE_HIGH_MIN - HES_EPSILON) {
    return HesConfidence.HIGH;
  }
  if (index >= HES_CONFIDENCE_MEDIUM_MIN - HES_EPSILON) {
    return HesConfidence.MEDIUM;
  }
  return HesConfidence.LOW;
}

/**
 * The eight component results for a profile. A component with fewer valid observations than its minimum
 * is not available: it has no raw value and no score. It never gets a score of zero.
 */
export function evaluateComponents(profile: HesProfile, aggregates: HesAggregates): ComponentResult[] {
  const out: ComponentResult[] = [];
  for (let i = 0; i < HES_COMPONENTS.length; i++) {
    const def = HES_COMPONENTS[i];
    const value = aggregateOf(aggregates, def.id);
    const validCount = value.validCount > 0 ? value.validCount : 0;
    const permille = hesWeightPermille(profile, def.id);
    const component: ComponentResult = {
      id: def.id,
      label: def.label,
      available: false,
      requiredCore: def.requiredCore,
      validCount: validCount,
      minimumCount: def.minimumCount,
      targetCount: def.targetCount,
      quality: def.targetCount > 0 ? Math.min(validCount / def.targetCount, 1) : 0,
      baseWeight: permille / HES_PERMILLE,
      baseWeightPermille: permille
    };
    const raw = value.raw;
    if (validCount >= def.minimumCount && raw !== undefined) {
      const score = piecewise(def.curve, raw);
      if (score !== undefined) {
        component.available = true;
        component.rawValue = raw;
        component.score = score;
      }
    }
    out.push(component);
  }
  return out;
}

function insufficient(profile: HesProfile, components: ComponentResult[], coveragePermille: number): HesResult {
  return {
    profile: profile,
    tier: HesTier.NONE,
    coverage: coveragePermille / PERCENT_PER_PERMILLE,
    coveragePermille: coveragePermille,
    confidence: HesConfidence.NOT_ENOUGH_DATA,
    status: HesStatus.INSUFFICIENT_DATA,
    components: components,
    modelVersion: HES_MODEL_VERSION
  };
}

/**
 * The result for a list of component results: coverage, score, confidence and tier.
 * With an incomplete Core set there is no score and no tier; the coverage is still reported.
 * A missing optional component is left out of both the numerator and the denominator (renormalization).
 */
export function composeComponents(profile: HesProfile, components: ComponentResult[]): HesResult {
  let coreComplete = true;
  let denominator = 0;  // thousandths: the base weights of the available components
  let numerator = 0;
  let qualitySum = 0;
  for (let i = 0; i < components.length; i++) {
    const c = components[i];
    const score = c.score;
    if (!c.available || score === undefined) {
      if (c.requiredCore) {
        coreComplete = false;
      }
      continue;
    }
    denominator += c.baseWeightPermille;
    numerator += c.baseWeightPermille * score;
    qualitySum += c.baseWeightPermille * c.quality;
  }
  if (!coreComplete || denominator <= 0) {
    return insufficient(profile, components, denominator);
  }
  const observed = numerator / denominator;
  // Coverage fraction times weighted quality: the denominators cancel.
  const confidenceIndex = qualitySum / HES_PERMILLE;
  if (!Number.isFinite(observed) || !Number.isFinite(confidenceIndex)) {
    return insufficient(profile, components, denominator);
  }
  for (let i = 0; i < components.length; i++) {
    if (components[i].available) {
      components[i].effectiveWeight = components[i].baseWeightPermille / denominator;
    }
  }
  const score = hesRound(observed);
  return {
    profile: profile,
    score: score,
    observed: observed,
    tier: tierFromHes(score),
    coverage: denominator / PERCENT_PER_PERMILLE,
    coveragePermille: denominator,
    confidence: confidenceFromIndex(confidenceIndex),
    confidenceIndex: confidenceIndex,
    status: HesStatus.OK,
    components: components,
    modelVersion: HES_MODEL_VERSION
  };
}

/** The result for a set of aggregates. */
export function composeHes(profile: HesProfile, aggregates: HesAggregates): HesResult {
  return composeComponents(profile, evaluateComponents(profile, aggregates));
}

/**
 * HES for a history of completed days in a profile.
 * Today's unfinished day is not part of the history: it enters only after the day is closed.
 */
export function computeHes(profile: HesProfile, history: HesHistory): HesResult {
  return composeHes(profile, aggregate(history));
}
