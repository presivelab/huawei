// Tiering (specification section 9). The tier strings are the ones the signed claim already uses.
import { TIER_A, TIER_B, TIER_C, TIER_NO_SCORE } from '../claim/ClaimValidation';
import { HES_TIER_A_MIN, HES_TIER_B_MIN } from './HesCurves';

/** A from 80, B from 60 to 79, C below 60. 'NONE' for a score that does not exist. */
export function tierFromHes(score: number): string {
  if (score < 0) {
    return TIER_NO_SCORE;
  }
  if (score >= HES_TIER_A_MIN) {
    return TIER_A;
  }
  if (score >= HES_TIER_B_MIN) {
    return TIER_B;
  }
  return TIER_C;
}

/** The recommended wording of section 9. No medical or insurance wording. */
export function tierLabel(tier: string): string {
  if (tier === TIER_A) {
    return 'Strong overall profile';
  }
  if (tier === TIER_B) {
    return 'Moderate overall profile';
  }
  if (tier === TIER_C) {
    return 'Improvement opportunity';
  }
  return 'Insufficient data';
}

/** Points still needed for the next tier up; 0 for tier A and for no score. */
export function pointsToNextTier(score: number): number {
  if (score < 0 || score >= HES_TIER_A_MIN) {
    return 0;
  }
  if (score >= HES_TIER_B_MIN) {
    return HES_TIER_A_MIN - score;
  }
  return HES_TIER_B_MIN - score;
}
