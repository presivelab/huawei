// "Why this tier" (specification section 11): strongest factors, improvement opportunities, and the
// missing components in a list of their own. Missing data never appears as a weak factor.
//
// Decisions where the specification says "2-3":
//   - strongest takes up to 3, but at most half of the available components rounded up;
//   - improvement takes up to 3 of the rest, so no component is in both lists
//     (5 available give 3 + 2, 6 or more give 3 + 3);
//   - equal scores keep the order of the weight table;
//   - without a score there is no tier to explain: both lists are empty and only `missing` is filled.
import { HesComponentResult, HesResult, HesStatus, HesWhy } from './HesTypes';

const LIST_MAX: number = 3;

function ranked(components: HesComponentResult[], descending: boolean): HesComponentResult[] {
  const order: number[] = [];
  for (let i = 0; i < components.length; i++) {
    order.push(i);
  }
  order.sort((a: number, b: number): number => {
    const diff = descending ? components[b].score - components[a].score :
      components[a].score - components[b].score;
    return diff !== 0 ? diff : a - b;
  });
  const out: HesComponentResult[] = [];
  for (let i = 0; i < order.length; i++) {
    out.push(components[order[i]]);
  }
  return out;
}

export function whyThisTier(result: HesResult): HesWhy {
  const available: HesComponentResult[] = [];
  const missing: HesComponentResult[] = [];
  for (let i = 0; i < result.components.length; i++) {
    if (result.components[i].available) {
      available.push(result.components[i]);
    } else {
      missing.push(result.components[i]);
    }
  }
  const why: HesWhy = { strongest: [], improvement: [], missing: missing };
  if (result.status !== HesStatus.OK) {
    return why;
  }
  const strongestCount = Math.min(LIST_MAX, Math.ceil(available.length / 2));
  const improvementCount = Math.min(LIST_MAX, available.length - strongestCount);
  why.strongest = ranked(available, true).slice(0, strongestCount);
  const rest: HesComponentResult[] = [];
  for (let i = 0; i < available.length; i++) {
    if (why.strongest.indexOf(available[i]) < 0) {
      rest.push(available[i]);
    }
  }
  why.improvement = ranked(rest, false).slice(0, improvementCount);
  return why;
}
