// Data Confidence (specification section 8).
//   quality_i        = min(validCount / targetCount, 1)
//   WeightedQuality  = sum(w_i * quality_i) / sum(w_i)      over the available components
//   ConfidenceIndex  = (Coverage / 100) * WeightedQuality
//   High from 0.80, Medium from 0.60, Low below. When the Core set is incomplete: "Insufficient data".
import { HES_CONFIDENCE_HIGH_MIN, HES_CONFIDENCE_MEDIUM_MIN } from './HesCurves';
import { coverage, isCoreComplete } from './HesComposite';
import { HesComponentResult, HesConfidence } from './HesTypes';

// Decision: the boundaries are inclusive (section 5 says so for the curves; section 8 writes ">= 0.80").
// The index is a product of fractions, so a value meant to be exactly 0.80 can arrive as 0.7999999999.
// This tolerance keeps such a value on its boundary; it is far below any step the index can take.
const BOUNDARY_TOLERANCE: number = 1e-9;

/** Quality of the available components weighted by base weight; 0 when nothing is available. */
export function weightedQuality(components: HesComponentResult[]): number {
  let numerator = 0;
  let denominator = 0;
  for (let i = 0; i < components.length; i++) {
    if (components[i].available) {
      numerator += components[i].baseWeight * components[i].quality;
      denominator += components[i].baseWeight;
    }
  }
  if (denominator <= 0) {
    return 0;
  }
  return numerator / denominator;
}

/** ConfidenceIndex = CoverageFraction x WeightedQuality, 0..1. */
export function confidenceIndex(components: HesComponentResult[]): number {
  return (coverage(components) / 100) * weightedQuality(components);
}

export function confidenceFromIndex(index: number): HesConfidence {
  if (index + BOUNDARY_TOLERANCE >= HES_CONFIDENCE_HIGH_MIN) {
    return HesConfidence.HIGH;
  }
  if (index + BOUNDARY_TOLERANCE >= HES_CONFIDENCE_MEDIUM_MIN) {
    return HesConfidence.MEDIUM;
  }
  return HesConfidence.LOW;
}

export function calculateConfidence(components: HesComponentResult[]): HesConfidence {
  if (!isCoreComplete(components)) {
    return HesConfidence.INSUFFICIENT_DATA;
  }
  return confidenceFromIndex(confidenceIndex(components));
}
