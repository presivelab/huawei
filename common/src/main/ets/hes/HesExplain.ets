// "Why this tier" (specification sections 13 and 14): the strongest components, what to improve, and the
// missing components in lists of their own. Missing data never appears as a weak factor or with a score.
//
// Rules:
//   - strongest: the available components, highest score first, top 3;
//   - to improve: the available components that are not in strongest, lowest score first, at most 3,
//     so no component is in both lists (5 available give 3 + 2);
//   - scores closer than 1e-9 are a tie: the higher base weight goes first, then the model's fixed order;
//   - without a score there is no tier to explain: both lists are empty, and what was measured and what a
//     score still needs are listed instead.
import { HES_EPSILON, HES_TIER_A_MIN, HES_TIER_B_MIN, hesComponentIndex } from './HesModel';
import { ComponentResult, HesResult, HesStatus, HesTier } from './HesTypes';

const LIST_MAX: number = 3;

export interface HesExplanation {
  strongest: ComponentResult[];
  toImprove: ComponentResult[];
  missingOptional: ComponentResult[];  // optional components that are not available
  missingCore: ComponentResult[];      // Core components a score still needs
  measured: ComponentResult[];         // the available components, in the model's order
  pointsToNextTier?: number;           // absent in tier A and without a score
  nextTier?: HesTier;
}

function scoreOf(component: ComponentResult): number {
  const score = component.score;
  return score === undefined ? 0 : score;
}

function available(result: HesResult): ComponentResult[] {
  const out: ComponentResult[] = [];
  for (let i = 0; i < result.components.length; i++) {
    const c = result.components[i];
    if (c.available && c.score !== undefined) {
      out.push(c);
    }
  }
  return out;
}

function ranked(components: ComponentResult[], descending: boolean): ComponentResult[] {
  const out = components.slice();
  out.sort((a: ComponentResult, b: ComponentResult): number => {
    const diff = descending ? scoreOf(b) - scoreOf(a) : scoreOf(a) - scoreOf(b);
    if (Math.abs(diff) >= HES_EPSILON) {
      return diff;
    }
    if (a.baseWeightPermille !== b.baseWeightPermille) {
      return b.baseWeightPermille - a.baseWeightPermille;
    }
    return hesComponentIndex(a.id) - hesComponentIndex(b.id);
  });
  return out;
}

/** The available components with the highest scores, at most three. Empty without a score. */
export function strongest(result: HesResult): ComponentResult[] {
  if (result.status !== HesStatus.OK) {
    return [];
  }
  return ranked(available(result), true).slice(0, LIST_MAX);
}

/** The lowest-scoring available components that are not in `strongest`, at most three. */
export function toImprove(result: HesResult): ComponentResult[] {
  if (result.status !== HesStatus.OK) {
    return [];
  }
  const top = strongest(result);
  const rest: ComponentResult[] = [];
  const all = available(result);
  for (let i = 0; i < all.length; i++) {
    let inTop = false;
    for (let j = 0; j < top.length; j++) {
      if (top[j].id === all[i].id) {
        inTop = true;
      }
    }
    if (!inTop) {
      rest.push(all[i]);
    }
  }
  return ranked(rest, false).slice(0, LIST_MAX);
}

function missing(result: HesResult, core: boolean): ComponentResult[] {
  const out: ComponentResult[] = [];
  for (let i = 0; i < result.components.length; i++) {
    const c = result.components[i];
    if (!c.available && c.requiredCore === core) {
      out.push(c);
    }
  }
  return out;
}

/** Optional components that are not available, in the model's order. */
export function missingOptional(result: HesResult): ComponentResult[] {
  return missing(result, false);
}

/** Core components that are not available: what a score still needs. */
export function missingCore(result: HesResult): ComponentResult[] {
  return missing(result, true);
}

/** Points to the next tier: to A from B, to B from C. Undefined in tier A and without a score. */
export function pointsToNextTier(result: HesResult): number | undefined {
  const score = result.score;
  if (result.status !== HesStatus.OK || score === undefined) {
    return undefined;
  }
  if (result.tier === HesTier.B) {
    return HES_TIER_A_MIN - score;
  }
  if (result.tier === HesTier.C) {
    return HES_TIER_B_MIN - score;
  }
  return undefined;
}

/** The tier above the result's tier, or undefined in tier A and without a score. */
export function nextTier(result: HesResult): HesTier | undefined {
  if (result.status !== HesStatus.OK) {
    return undefined;
  }
  if (result.tier === HesTier.B) {
    return HesTier.A;
  }
  if (result.tier === HesTier.C) {
    return HesTier.B;
  }
  return undefined;
}

export function explainHes(result: HesResult): HesExplanation {
  const out: HesExplanation = {
    strongest: strongest(result),
    toImprove: toImprove(result),
    missingOptional: missingOptional(result),
    missingCore: missingCore(result),
    measured: available(result)
  };
  const points = pointsToNextTier(result);
  const next = nextTier(result);
  if (points !== undefined && next !== undefined) {
    out.pointsToNextTier = points;
    out.nextTier = next;
  }
  return out;
}
