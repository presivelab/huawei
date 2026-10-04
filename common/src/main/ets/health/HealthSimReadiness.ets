// "FairWear readiness" of a health history, for the Scenario tool of Health Sim: how many observations each
// component of the score has against its minimum and target, the evidence coverage in both profiles, and a
// preview of the score. Pure logic, no system kits.
//
// The preview is calculated by the same engine FairWear uses (hes/HesEngine), on the same history Health Sim
// exports, so the two apps cannot disagree. It is a check for the person running the simulator: the official
// result is the one FairWear calculates after the data was shared with it.
import { computeHes } from '../hes/HesEngine';
import {
  hesConfidenceLabel,
  hesCountUnit,
  hesCoverageText,
  hesRawText,
  hesSummaryText
} from '../hes/HesFormat';
import { HES_PROFILES, hesProfileLabel } from '../hes/HesModel';
import { ComponentId, HesHistory, HesProfile, HesResult, HesStatus } from '../hes/HesTypes';

export const READINESS_TITLE: string = 'FairWear readiness';
export const READINESS_NOTE: string = 'Simulator check — FairWear computes the official result';
export const READINESS_CORE: string = 'Core';
export const READINESS_OPTIONAL: string = 'Optional';
export const READINESS_NO_SCORE: string = 'No score yet';

/** One component: what the history holds for it against what the score needs. */
export interface ReadinessRow {
  id: ComponentId;
  label: string;         // "Sleep timing regularity"
  kind: string;          // READINESS_CORE or READINESS_OPTIONAL
  core: boolean;
  validCount: number;
  minimumCount: number;
  targetCount: number;
  countText: string;     // "16 of 14 / 21 days": valid of minimum / target
  rawText: string;       // the aggregated value in readable units; empty when the component is not ready
  ready: boolean;        // the minimum is reached: the component enters the score
}

/** The preview of the score in one profile. */
export interface ReadinessPreview {
  profile: HesProfile;
  profileLabel: string;    // "Health & wellness"
  coverageText: string;    // "87.5%"
  scored: boolean;
  scoreText: string;       // "75" or "No score yet"
  tier: string;            // "A", "B", "C" or "NONE"
  confidenceText: string;  // "High", "Medium", "Low" or "Not enough data"
  summary: string;         // "75 · B · 87.5% · High" or "No score · 47.5%"
}

export interface HealthSimReadiness {
  rows: ReadinessRow[];          // the eight components, in the model's order
  previews: ReadinessPreview[];  // Health & wellness first, then Longevity
  coreReady: boolean;            // every Core component reached its minimum
  note: string;                  // READINESS_NOTE
}

function countText(id: ComponentId, valid: number, minimum: number, target: number): string {
  const unit = hesCountUnit(id);
  const text = `${valid} of ${minimum} / ${target}`;
  return unit.length === 0 ? text : `${text} ${unit}`;
}

function previewOf(result: HesResult): ReadinessPreview {
  const score = result.score;
  const scored = result.status === HesStatus.OK && score !== undefined;
  return {
    profile: result.profile,
    profileLabel: hesProfileLabel(result.profile),
    coverageText: hesCoverageText(result.coveragePermille),
    scored: scored,
    scoreText: scored && score !== undefined ? `${score}` : READINESS_NO_SCORE,
    tier: result.tier,
    confidenceText: hesConfidenceLabel(result.confidence),
    summary: hesSummaryText(result)
  };
}

/** The readiness of a history of completed days. The running day is not part of it until it is closed. */
export function healthSimReadiness(history: HesHistory): HealthSimReadiness {
  const results: HesResult[] = [];
  for (let p = 0; p < HES_PROFILES.length; p++) {
    results.push(computeHes(HES_PROFILES[p], history));
  }
  // The counts and the raw values are the same in every profile; only the weights differ.
  const first = results[0];
  const rows: ReadinessRow[] = [];
  let coreReady = true;
  for (let i = 0; i < first.components.length; i++) {
    const c = first.components[i];
    const raw = c.rawValue;
    if (c.requiredCore && !c.available) {
      coreReady = false;
    }
    rows.push({
      id: c.id,
      label: c.label,
      kind: c.requiredCore ? READINESS_CORE : READINESS_OPTIONAL,
      core: c.requiredCore,
      validCount: c.validCount,
      minimumCount: c.minimumCount,
      targetCount: c.targetCount,
      countText: countText(c.id, c.validCount, c.minimumCount, c.targetCount),
      rawText: c.available && raw !== undefined ? hesRawText(c.id, raw) : '',
      ready: c.available
    });
  }
  const previews: ReadinessPreview[] = [];
  for (let p = 0; p < results.length; p++) {
    previews.push(previewOf(results[p]));
  }
  return { rows: rows, previews: previews, coreReady: coreReady, note: READINESS_NOTE };
}
