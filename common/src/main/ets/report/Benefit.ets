import { BenefitLevel, ReportTier } from './ReportModels';

/*
 * The benefit level of a month. Deterministic rules:
 *
 *   eligible and tier A   -> FULL
 *   eligible and tier B   -> PARTIAL
 *   anything else         -> NONE   (tier C, not eligible, or no score)
 *
 * The level is always shown with its reason.
 */

export const BENEFIT_FULL_LABEL: string = 'Full benefit';
export const BENEFIT_PARTIAL_LABEL: string = 'Partial benefit';
export const BENEFIT_NONE_LABEL: string = 'No benefit this month';

export const REASON_ELIGIBLE: string = 'Eligible';
export const REASON_NO_DATA: string = 'Not enough data yet';
export const REASON_WEAR: string = 'Wear below the required days';

export function benefitLevel(eligible: boolean, tier: string, hasScore: boolean): string {
  if (!hasScore || !eligible) {
    return BenefitLevel.NONE;
  }
  if (tier === ReportTier.A) {
    return BenefitLevel.FULL;
  }
  if (tier === ReportTier.B) {
    return BenefitLevel.PARTIAL;
  }
  return BenefitLevel.NONE;
}

export function benefitLabel(level: string): string {
  if (level === BenefitLevel.FULL) {
    return BENEFIT_FULL_LABEL;
  }
  if (level === BenefitLevel.PARTIAL) {
    return BENEFIT_PARTIAL_LABEL;
  }
  return BENEFIT_NONE_LABEL;
}

/*
 * Why the level is what it is, in the order a person needs it: no score, then the flag, then the tier,
 * then wear. `suspicious` is the number of suspicious breaks of the period.
 */
export function benefitReason(eligible: boolean, tier: string, hasScore: boolean, flagged: boolean,
  suspicious: number): string {
  if (!hasScore) {
    return REASON_NO_DATA;
  }
  if (flagged) {
    return suspicious === 1 ? '1 suspicious break' : `${suspicious} suspicious breaks`;
  }
  if (tier === ReportTier.C) {
    return 'Score C';
  }
  if (!eligible) {
    return REASON_WEAR;
  }
  return tier === ReportTier.A ? REASON_ELIGIBLE : 'Score B';
}
