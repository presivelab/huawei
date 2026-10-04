import {
  benefitLabel,
  ComponentId,
  ComponentRow,
  DayState,
  hasScore,
  healthSourceLabel,
  HES_TIER_A_MIN,
  HES_TIER_B_MIN,
  nextTierOf,
  PersonaReport,
  ReportTier,
  weightText
} from 'common';
import { str } from '../ui/Strings';

// UI copy of the report screens, kept in string resources (base = English).
// A constant is the resource; a function returns the text.

export const PREVIEW_LINE: Resource = $r('app.string.report_preview_line');
export const SCORE_UNIT: Resource = $r('app.string.report_score_unit');

export const WHY_LABEL: Resource = $r('app.string.report_why_label');
export const EVIDENCE_LABEL: Resource = $r('app.string.report_evidence_label');
export const WEAR_TITLE: Resource = $r('app.string.report_wear_title');
export const EVIDENCE_TITLE: Resource = $r('app.string.report_evidence_title');
export const EVIDENCE_NOTE: Resource = $r('app.string.report_evidence_note');
export const TODAY_TITLE: Resource = $r('app.string.report_today_title');
export const TODAY_CHIP_LIVE: Resource = $r('app.string.report_today_chip_live');
export const TODAY_CHIP_PREVIEW: Resource = $r('app.string.report_today_chip_preview');
export const TODAY_NOTE: Resource = $r('app.string.report_today_note');
export const DISCLAIMER: Resource = $r('app.string.report_disclaimer');

export const NO_SCORE_HEADLINE: Resource = $r('app.string.report_no_score_headline');
export const NO_SCORE_BODY: Resource = $r('app.string.report_no_score_body');
export const UNLOCK_TITLE: Resource = $r('app.string.report_unlock_title');

// The three steps under "What unlocks your score".
export function unlockSteps(): string[] {
  return [
    str($r('app.string.report_unlock_step_night')),
    str($r('app.string.report_unlock_step_heart_rate')),
    str($r('app.string.report_unlock_step_trusleep'))
  ];
}

export const SHARE_NEEDS_SCORE: Resource = $r('app.string.report_share_needs_score');

export const NOT_MEASURED: Resource = $r('app.string.report_not_measured');
export const NOT_MEASURED_NOTE: Resource = $r('app.string.report_not_measured_note');

export const PERSONA_SHEET_TITLE: Resource = $r('app.string.persona_sheet_title');
export const PERSONA_SHEET_NOTE: Resource = $r('app.string.persona_sheet_note');

export const SHARE_TAB_TITLE: Resource = $r('app.string.tab_share_title');
export const EVIDENCE_TAB_TITLE: Resource = $r('app.string.tab_evidence_title');
export const REPORT_TAB_TITLE: Resource = $r('app.string.tab_report_title');
export const NEXT_STEP_SENTENCE: Resource = $r('app.string.report_next_step_sentence');

// The source line of the report: the brand and the readable status, marked as preview while the values
// are fixed preview values ("HUAWEI Health · Demo data · preview").
export function reportSourceLine(status: string, preview: boolean): string {
  const label: string = healthSourceLabel(status);
  return preview ? str($r('app.string.report_source_preview'), label) : label;
}

// The short name of a score component on a tile.
export function tileName(id: string): string {
  if (id === ComponentId.STEPS) {
    return str($r('app.string.report_tile_steps'));
  }
  if (id === ComponentId.ACTIVE_MINUTES) {
    return str($r('app.string.report_tile_active_minutes'));
  }
  if (id === ComponentId.RESTING_HR) {
    return str($r('app.string.report_tile_resting_hr'));
  }
  if (id === ComponentId.SLEEP) {
    return str($r('app.string.report_tile_sleep'));
  }
  if (id === ComponentId.SLEEP_REGULARITY) {
    return str($r('app.string.report_tile_sleep_regularity'));
  }
  if (id === ComponentId.VO2MAX) {
    return str($r('app.string.report_tile_vo2max'));
  }
  if (id === ComponentId.HRV) {
    return str($r('app.string.report_tile_hrv'));
  }
  return str($r('app.string.report_tile_recovery'));
}

// Evidence for sleep is counted in nights, everything else in days.
function countedInNights(id: string): boolean {
  return id === ComponentId.SLEEP || id === ComponentId.SLEEP_REGULARITY;
}

export function countUnit(id: string): string {
  return countedInNights(id) ? str($r('app.string.report_count_unit_nights')) :
  str($r('app.string.report_count_unit_days'));
}

// The line next to the tier letter: what the tier means, or how far the next one is.
export function tierHeadline(report: PersonaReport): string {
  if (report.tier === ReportTier.A) {
    return str($r('app.string.report_tier_headline_a'));
  }
  const next = nextTierOf(report.tier);
  if (report.pointsToNext > 0 && next.length > 0) {
    return pointsLine(report.pointsToNext, next);
  }
  return report.tier === ReportTier.B ? str($r('app.string.report_tier_headline_b')) :
  str($r('app.string.report_tier_headline_c'));
}

// One line per persona in the demo switcher.
export function personaSummary(report: PersonaReport): string {
  if (!hasScore(report)) {
    return str($r('app.string.persona_summary_no_score'), report.coveragePct);
  }
  return str($r('app.string.persona_summary_score'), report.tier, report.hes, benefitLabel(report.benefit));
}

// 5843 -> "5,843".
export function grouped(n: number): string {
  let text = `${Math.floor(n)}`;
  let out = '';
  while (text.length > 3) {
    out = `,${text.substring(text.length - 3)}${out}`;
    text = text.substring(0, text.length - 3);
  }
  return text + out;
}

// --- Evidence tab: the calendar of the month and the day sheet ---

export const EVIDENCE_SEGMENT_CALENDAR: Resource = $r('app.string.evidence_segment_calendar');
export const EVIDENCE_SEGMENT_WATCH: Resource = $r('app.string.evidence_segment_watch');
export const CALENDAR_TITLE: Resource = $r('app.string.evidence_calendar_title');
export const DAYS_LABEL: Resource = $r('app.string.evidence_days_label');
export const NIGHTS_LABEL: Resource = $r('app.string.evidence_nights_label');
export const BREAKS_LABEL: Resource = $r('app.string.evidence_breaks_label');
export const FLAG_CHIP: Resource = $r('app.string.evidence_flag_chip');
export const FLAG_LINE: Resource = $r('app.string.evidence_flag_line');
export const CALENDAR_HINT: Resource = $r('app.string.evidence_calendar_hint');
export const APPEAL_LABEL: Resource = $r('app.string.evidence_appeal_label');
export const APPEAL_SENT: Resource = $r('app.string.evidence_appeal_sent');
export const APPEAL_NOTE: Resource = $r('app.string.evidence_appeal_note');
export const DAY_WORN: Resource = $r('app.string.evidence_day_worn');
export const DAY_CHARGING: Resource = $r('app.string.evidence_day_charging');
export const DAY_NIGHT: Resource = $r('app.string.evidence_day_night');
export const DAY_NIGHT_YES: Resource = $r('app.string.evidence_day_night_yes');
export const DAY_NIGHT_NO: Resource = $r('app.string.evidence_day_night_no');
export const DAY_NOT_OBSERVED: Resource = $r('app.string.evidence_day_not_observed');

// What a day state means when the day has no recorded details to show.
export function dayStateNote(state: string): string {
  if (state === DayState.COMPLIANT) {
    return str($r('app.string.evidence_day_note_compliant'));
  }
  if (state === DayState.SHORT) {
    return str($r('app.string.evidence_day_note_short'));
  }
  if (state === DayState.SUSPICIOUS) {
    return str($r('app.string.evidence_day_note_suspicious'));
  }
  if (state === DayState.SICK) {
    return str($r('app.string.evidence_day_note_sick'));
  }
  return str($r('app.string.evidence_day_note_no_watch'));
}

// --- "Why this tier" ---

export const WHY_NO_SCORE_LABEL: Resource = $r('app.string.why_no_score_label');
export const WHY_STRONGEST: Resource = $r('app.string.why_strongest');
export const WHY_IMPROVE: Resource = $r('app.string.why_improve');
export const WHY_MISSING: Resource = $r('app.string.why_missing');
export const WHY_MISSING_NOTE: Resource = $r('app.string.why_missing_note');
export const WHY_MEASURED: Resource = $r('app.string.why_measured');
export const WHY_NEEDED: Resource = $r('app.string.why_needed');
export const WHY_NOT_MEASURED: Resource = $r('app.string.why_not_measured');
export const WHY_HOW_TITLE: Resource = $r('app.string.why_how_title');

// The five lines of "How it's calculated"; the third names the tier thresholds.
export function whyHowLines(): string[] {
  return [
    str($r('app.string.why_how_line_curve')),
    str($r('app.string.why_how_line_average')),
    str($r('app.string.why_how_line_tiers'), HES_TIER_A_MIN, HES_TIER_B_MIN),
    str($r('app.string.why_how_line_coverage')),
    str($r('app.string.why_how_line_core'))
  ];
}

export const WHY_ASSUMPTIONS: Resource = $r('app.string.why_assumptions');

// "HES 79 · 1 point to A"; at the top tier only the score.
export function whyHeadline(report: PersonaReport): string {
  const next = nextTierOf(report.tier);
  if (report.pointsToNext > 0 && next.length > 0) {
    return str($r('app.string.why_headline_points'), report.hes, pointsLine(report.pointsToNext, next));
  }
  return str($r('app.string.why_headline'), report.hes);
}

// "1 point to A", "5 points to A".
export function pointsLine(points: number, tier: string): string {
  return points === 1 ? str($r('app.string.report_points_one'), tier) :
  str($r('app.string.report_points_many'), points, tier);
}

// "Coverage 90% · Confidence High · Partial benefit".
export function whySubline(report: PersonaReport): string {
  return str($r('app.string.why_subline'), report.coveragePct, report.confidence, benefitLabel(report.benefit));
}

// "±24 min · weight 17%".
export function whyRowDetail(row: ComponentRow): string {
  return str($r('app.string.why_row_detail'), row.raw, row.unit, weightText(row));
}

// "14 days" or "1 night" under a measure that already has data.
export function countLine(row: ComponentRow): string {
  if (countedInNights(row.id)) {
    return row.validCount === 1 ? str($r('app.string.report_count_night_one'), row.validCount) :
    str($r('app.string.report_count_nights_many'), row.validCount);
  }
  return row.validCount === 1 ? str($r('app.string.report_count_day_one'), row.validCount) :
  str($r('app.string.report_count_days_many'), row.validCount);
}

// --- Report tab: the live card and the demo controls ---

export const LIVE_TITLE: Resource = $r('app.string.live_title');
export const LIVE_CHIP: Resource = $r('app.string.live_chip');
export const LIVE_NOTE: Resource = $r('app.string.live_note');
export const NO_READING: Resource = $r('app.string.live_no_reading');
export const DEMO_TITLE: Resource = $r('app.string.demo_controls_title');
export const DEMO_HR_LABEL: Resource = $r('app.string.demo_controls_hr_label');
export const DEMO_STEPS_LABEL: Resource = $r('app.string.demo_controls_steps_label');
export const DEMO_CLOSE_DAY: Resource = $r('app.string.demo_controls_close_day');
export const DEMO_RESET: Resource = $r('app.string.demo_controls_reset');
export const DEMO_NOTE: Resource = $r('app.string.demo_controls_note');
export const DEMO_DAY_CLOSED: Resource = $r('app.string.demo_controls_day_closed');
export const DEMO_RESET_DONE: Resource = $r('app.string.demo_controls_reset_done');
export const PERSONA_SHEET_NOTE_ENGINE: Resource = $r('app.string.persona_sheet_note_engine');

// The note under the persona sheet title: fixed preview values, or scripted days scored by the rules.
export function personaSheetNote(preview: boolean): string {
  return str(preview ? PERSONA_SHEET_NOTE : PERSONA_SHEET_NOTE_ENGINE);
}

// A live reading as text; a reading below zero is "no reading", never a number.
export function liveText(value: number): string {
  return value < 0 ? str(NO_READING) : grouped(value);
}
