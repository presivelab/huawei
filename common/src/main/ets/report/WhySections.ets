import { ComponentRow, hasScore, PersonaReport } from './ReportModels';

/*
 * "Why this tier" from the rows of a report. The same rule as `whyThisTier` (hes/HesWhy), applied to the
 * view model so the screen reads one shape, whichever service filled it:
 *
 *   - strongest: up to 3 available components by score, at most half of them rounded up;
 *   - to improve: up to 3 of the rest, lowest score first, so no component is in both lists;
 *   - equal scores keep the order of the report;
 *   - a component without data is never a weak factor: it goes to `missing` and nowhere else;
 *   - without a score there is no tier to explain: both lists are empty.
 */

const LIST_MAX: number = 3;

export interface WhySections {
  strongest: ComponentRow[];
  improvement: ComponentRow[];
  missing: ComponentRow[];
}

/** What a report without a score has so far, and what the score still needs. */
export interface ScoreEvidence {
  measured: ComponentRow[];      // enough data already, or data the score does not require
  needed: ComponentRow[];        // required by the score and still short of days or nights
  notMeasured: ComponentRow[];   // no data and not required
}

function ranked(rows: ComponentRow[], descending: boolean): ComponentRow[] {
  const order: number[] = [];
  for (let i = 0; i < rows.length; i++) {
    order.push(i);
  }
  order.sort((a: number, b: number): number => {
    const diff = descending ? rows[b].score - rows[a].score : rows[a].score - rows[b].score;
    return diff !== 0 ? diff : a - b;
  });
  const out: ComponentRow[] = [];
  for (let i = 0; i < order.length; i++) {
    out.push(rows[order[i]]);
  }
  return out;
}

export function whySections(report: PersonaReport): WhySections {
  const available: ComponentRow[] = [];
  const missing: ComponentRow[] = [];
  for (let i = 0; i < report.components.length; i++) {
    if (report.components[i].available) {
      available.push(report.components[i]);
    } else {
      missing.push(report.components[i]);
    }
  }
  const out: WhySections = { strongest: [], improvement: [], missing: missing };
  if (!hasScore(report)) {
    return out;
  }
  const strongestCount = Math.min(LIST_MAX, Math.ceil(available.length / 2));
  const improvementCount = Math.min(LIST_MAX, available.length - strongestCount);
  out.strongest = ranked(available, true).slice(0, strongestCount);
  const rest: ComponentRow[] = [];
  for (let i = 0; i < available.length; i++) {
    if (out.strongest.indexOf(available[i]) < 0) {
      rest.push(available[i]);
    }
  }
  out.improvement = ranked(rest, false).slice(0, improvementCount);
  return out;
}

/** The evidence behind a missing score: every component is in exactly one of the three lists. */
export function scoreEvidence(report: PersonaReport): ScoreEvidence {
  const out: ScoreEvidence = { measured: [], needed: [], notMeasured: [] };
  for (let i = 0; i < report.components.length; i++) {
    const row = report.components[i];
    if (row.minCount > 0 && row.validCount < row.minCount) {
      out.needed.push(row);
    } else if (row.validCount > 0) {
      out.measured.push(row);
    } else {
      out.notMeasured.push(row);
    }
  }
  return out;
}

/** "17%" or "16.7%": the effective weight as the report carries it. */
export function weightText(row: ComponentRow): string {
  return `${row.weightPct}%`;
}
