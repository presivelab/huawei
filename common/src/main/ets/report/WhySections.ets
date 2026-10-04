import { ComponentId, ComponentRow, hasScore, PersonaReport } from './ReportModels';

/*
 * "Why this tier" from the rows of a report. The same rule as `explainHes` (hes/HesExplain), applied to the
 * view model so the screen reads one shape, whichever service filled it:
 *
 *   - strongest: the available components, highest score first, top 3;
 *   - to improve: the available components that are not in strongest, lowest score first, at most 3, so no
 *     component is in both lists (5 available give 3 + 2);
 *   - equal scores: the higher weight first, then the model's fixed order of components;
 *   - a component without data is never a weak factor: it goes to `missing` and nowhere else. `missing`
 *     holds every component without enough data; `missingOptional` only the ones the score does not require;
 *   - without a score there is no tier to explain: both lists are empty.
 */

const LIST_MAX: number = 3;
const TIE: number = 1e-9;

export interface WhySections {
  strongest: ComponentRow[];
  improvement: ComponentRow[];
  missing: ComponentRow[];
  missingOptional: ComponentRow[];
}

// The model's fixed order of components (hes/HesModel), by the report's ids: the last tie-break.
const MODEL_ORDER: string[] = [ComponentId.VO2MAX, ComponentId.RESTING_HR, ComponentId.ACTIVE_MINUTES,
  ComponentId.STEPS, ComponentId.SLEEP_REGULARITY, ComponentId.SLEEP, ComponentId.HRV, ComponentId.HR_RECOVERY];

/** What a report without a score has so far, and what the score still needs. */
export interface ScoreEvidence {
  measured: ComponentRow[];      // enough data already: the component has a value
  needed: ComponentRow[];        // a Core component still short of days or nights
  notMeasured: ComponentRow[];   // an optional component without enough data yet, with or without a few readings
}

function ranked(rows: ComponentRow[], descending: boolean): ComponentRow[] {
  const order: number[] = [];
  for (let i = 0; i < rows.length; i++) {
    order.push(i);
  }
  order.sort((a: number, b: number): number => {
    const diff = descending ? rows[b].scoreExact - rows[a].scoreExact : rows[a].scoreExact - rows[b].scoreExact;
    if (Math.abs(diff) >= TIE) {
      return diff;
    }
    if (rows[a].weightPct !== rows[b].weightPct) {
      return rows[b].weightPct - rows[a].weightPct;
    }
    return MODEL_ORDER.indexOf(rows[a].id) - MODEL_ORDER.indexOf(rows[b].id);
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
  const missingOptional: ComponentRow[] = [];
  for (let i = 0; i < missing.length; i++) {
    if (!missing[i].core) {
      missingOptional.push(missing[i]);
    }
  }
  const out: WhySections = { strongest: [], improvement: [], missing: missing, missingOptional: missingOptional };
  if (!hasScore(report)) {
    return out;
  }
  out.strongest = ranked(available, true).slice(0, LIST_MAX);
  const rest: ComponentRow[] = [];
  for (let i = 0; i < available.length; i++) {
    if (out.strongest.indexOf(available[i]) < 0) {
      rest.push(available[i]);
    }
  }
  out.improvement = ranked(rest, false).slice(0, LIST_MAX);
  return out;
}

/** The evidence behind a missing score: every component is in exactly one of the three lists. */
export function scoreEvidence(report: PersonaReport): ScoreEvidence {
  const out: ScoreEvidence = { measured: [], needed: [], notMeasured: [] };
  for (let i = 0; i < report.components.length; i++) {
    const row = report.components[i];
    if (row.available) {
      out.measured.push(row);
    } else if (row.core) {
      out.needed.push(row);
    } else {
      out.notMeasured.push(row);
    }
  }
  return out;
}

/** "18.8%" or "20.0%": the effective weight with one decimal, as the report carries it. */
export function weightText(row: ComponentRow): string {
  return row.weightText.length > 0 ? row.weightText : `${row.weightPct}%`;
}
