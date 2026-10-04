// HES vNext, the calculation flow of specification section 14, for one score profile.
// Deterministic rules over a history of completed days. No learned model, no network, no clock.
// All weights, curves, thresholds and minimum counts are prototype product assumptions (HesCurves.ets).
import { TIER_NO_SCORE } from '../claim/ClaimValidation';
import { evaluateComponents } from './HesComponents';
import { HES_DEFAULT_PROFILE } from './HesCurves';
import { applyEffectiveWeights, calculateObservedHes, coverage, isCoreComplete } from './HesComposite';
import { calculateConfidence } from './HesConfidence';
import { tierFromHes } from './HesTier';
import { HesComponentResult, HesConfidence, HesDay, HesProfile, HesResult, HesStatus, HES_MISSING } from './HesTypes';

/**
 * The result for a list of component results: coverage, score, confidence and tier.
 * With an incomplete Core set there is no score and no tier; the coverage is still reported.
 */
export function composeHes(components: HesComponentResult[],
  profile: HesProfile = HES_DEFAULT_PROFILE): HesResult {
  applyEffectiveWeights(components);
  const coveragePct = coverage(components);
  if (!isCoreComplete(components)) {
    return {
      profile: profile,
      status: HesStatus.INSUFFICIENT_DATA,
      score: HES_MISSING,
      tier: TIER_NO_SCORE,
      coverage: coveragePct,
      confidence: HesConfidence.INSUFFICIENT_DATA,
      components: components
    };
  }
  const score = calculateObservedHes(components);
  return {
    profile: profile,
    status: HesStatus.OK,
    score: score,
    tier: tierFromHes(score),
    coverage: coveragePct,
    confidence: calculateConfidence(components),
    components: components
  };
}

/**
 * HES for a history of completed days, oldest first, one entry per calendar day, with the base weights of
 * `profile`. Today's unfinished day is not part of the history: it enters only after the day is closed.
 */
export function computeHes(history: HesDay[], profile: HesProfile = HES_DEFAULT_PROFILE): HesResult {
  return composeHes(evaluateComponents(history, profile), profile);
}
