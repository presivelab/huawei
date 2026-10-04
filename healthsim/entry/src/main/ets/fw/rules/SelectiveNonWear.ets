import { Thresholds } from '../model/types';

/*
 * Selective non-wear flag: a rule over counted gaps, not a learned model.
 *
 * Flag when there are at least `minSuspicious` suspicious gaps,
 * OR at least `minSuspiciousForShare` suspicious gaps AND they are more than `maxSuspiciousShare` of all gaps.
 * A single suspicious gap never raises the flag: one bad day (a cold, a stressful week) is not a pattern.
 */
export function isSelectiveNonWear(suspiciousGaps: number, totalGaps: number, th: Thresholds): boolean {
  if (suspiciousGaps <= 1) {
    return false;
  }
  if (suspiciousGaps >= th.minSuspicious) {
    return true;
  }
  if (suspiciousGaps >= th.minSuspiciousForShare && totalGaps > 0) {
    return suspiciousGaps / totalGaps > th.maxSuspiciousShare;
  }
  return false;
}
