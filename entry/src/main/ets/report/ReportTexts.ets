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

// UI copy of the report screens. English only.

export const PREVIEW_SUFFIX: string = ' · preview';
export const PREVIEW_LINE: string = 'Score engine not connected — preview values';
export const PERIOD_SUFFIX: string = ' · last 30 days';
export const SCORE_UNIT: string = 'HES';

export const WHY_LABEL: string = 'Why this tier';
export const EVIDENCE_LABEL: string = 'Evidence';
export const WEAR_TITLE: string = 'Wear this month';
export const EVIDENCE_TITLE: string = 'Your evidence';
export const EVIDENCE_NOTE: string = 'completed days · last 28';
export const TODAY_TITLE: string = 'Today';
export const TODAY_CHIP_LIVE: string = 'Live · not scored';
export const TODAY_CHIP_PREVIEW: string = 'Preview · not scored';
export const TODAY_NOTE: string = 'Enters your score when the day closes. Your score uses completed days only.';
export const DISCLAIMER: string =
  'HES is deterministic rules, not a medical device. Weights and curves are prototype assumptions, ' +
    'not clinically tested.';

export const NO_SCORE_HEADLINE: string = 'No score yet';
export const NO_SCORE_BODY: string =
  'We need more completed days before we can score fairly. A low score is never shown instead.';
export const UNLOCK_TITLE: string = 'What unlocks your score';
export const UNLOCK_STEPS: string[] = [
  'Wear the watch at night',
  'Turn on continuous heart rate monitoring in HUAWEI Health',
  'Turn on TruSleep in HUAWEI Health'
];
export const SHARE_NEEDS_SCORE: string = 'Share is available once you have a score.';

export const NOT_MEASURED: string = 'Not measured';
export const NOT_MEASURED_NOTE: string = 'Doesn\'t lower your score';

export const PERSONA_SHEET_TITLE: string = 'Demo persona';
export const PERSONA_SHEET_NOTE: string = 'Fixed preview data, for the demo only';
export const PERSONA_CHIP_SUFFIX: string = ' · Demo';

export const SHARE_TAB_TITLE: string = 'Share';
export const EVIDENCE_TAB_TITLE: string = 'Evidence';
export const REPORT_TAB_TITLE: string = 'Report';
export const NEXT_STEP_SENTENCE: string = 'This screen arrives in the next step.';

// The source line of the report: the brand and the readable status, marked as preview while the values
// are fixed preview values ("HUAWEI Health · Demo data · preview").
export function reportSourceLine(status: string, preview: boolean): string {
  return healthSourceLabel(status) + (preview ? PREVIEW_SUFFIX : '');
}

// The short name of a score component on a tile.
export function tileName(id: string): string {
  if (id === ComponentId.STEPS) {
    return 'Steps';
  }
  if (id === ComponentId.ACTIVE_MINUTES) {
    return 'Active minutes';
  }
  if (id === ComponentId.RESTING_HR) {
    return 'Resting HR';
  }
  if (id === ComponentId.SLEEP) {
    return 'Sleep';
  }
  if (id === ComponentId.SLEEP_REGULARITY) {
    return 'Sleep regularity';
  }
  if (id === ComponentId.VO2MAX) {
    return 'VO₂max';
  }
  if (id === ComponentId.HRV) {
    return 'HRV';
  }
  return 'Recovery (HRR1)';
}

// Evidence for sleep is counted in nights, everything else in days.
export function countUnit(id: string): string {
  return id === ComponentId.SLEEP || id === ComponentId.SLEEP_REGULARITY ? 'nights' : 'days';
}

// The line next to the tier letter: what the tier means, or how far the next one is.
export function tierHeadline(report: PersonaReport): string {
  if (report.tier === ReportTier.A) {
    return 'Strong overall profile';
  }
  const next = nextTierOf(report.tier);
  if (report.pointsToNext > 0 && next.length > 0) {
    return pointsLine(report.pointsToNext, next);
  }
  return report.tier === ReportTier.B ? 'Solid overall profile' : 'Tier C this month';
}

// One line per persona in the demo switcher.
export function personaSummary(report: PersonaReport): string {
  if (!hasScore(report)) {
    return `No score yet · coverage ${report.coveragePct}%`;
  }
  return `Tier ${report.tier} · HES ${report.hes} · ${benefitLabel(report.benefit)}`;
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

export const EVIDENCE_SEGMENT_CALENDAR: string = 'Calendar';
export const EVIDENCE_SEGMENT_WATCH: string = 'Watch days';
export const CALENDAR_TITLE: string = 'This month';
export const DAYS_LABEL: string = 'Days compliant';
export const NIGHTS_LABEL: string = 'Nights worn';
export const BREAKS_LABEL: string = 'Suspicious breaks';
export const FLAG_CHIP: string = 'Flagged';
export const FLAG_LINE: string = 'Selective non-wear: flagged → no benefit this month';
export const CALENDAR_HINT: string = 'Tap a day to see what the watch recorded.';
export const APPEAL_LABEL: string = 'Appeal this day';
export const APPEAL_SENT: string = 'Appeal sent';
export const APPEAL_NOTE: string =
  'An appeal does not change this day or your score. In this demo it stays on this phone.';
export const APPEAL_MARK_SPOKEN: string = 'appeal sent';
export const DAY_WORN: string = 'worn';
export const DAY_CHARGING: string = 'charging';
export const DAY_NIGHT: string = 'night';
export const DAY_NIGHT_YES: string = 'Worn';
export const DAY_NIGHT_NO: string = 'Not worn';
export const DAY_NOT_OBSERVED: string = '—';

// What a day state means when the day has no recorded details to show.
export function dayStateNote(state: string): string {
  if (state === DayState.COMPLIANT) {
    return 'This day counts towards your month.';
  }
  if (state === DayState.SHORT) {
    return 'The watch was worn too little for this day to count.';
  }
  if (state === DayState.SUSPICIOUS) {
    return 'A break on this day counts as suspicious.';
  }
  if (state === DayState.SICK) {
    return 'A sick day. It is left out of the month and never sent to your partner.';
  }
  return 'No watch yet: there is no record from the watch for this day.';
}

// --- "Why this tier" ---

export const WHY_STRONGEST: string = 'Strongest';
export const WHY_IMPROVE: string = 'To improve';
export const WHY_MISSING: string = 'Missing data';
export const WHY_MISSING_NOTE: string = 'Missing data never lowers your score. It only lowers coverage.';
export const WHY_MEASURED: string = 'Measured so far';
export const WHY_NEEDED: string = 'Needed for a score';
export const WHY_NOT_MEASURED: string = 'Not measured';
export const WHY_ENOUGH: string = 'Enough for a score';
export const WHY_HOW_TITLE: string = 'How it\'s calculated';
export const WHY_HOW_LINES: string[] = [
  'Each measure is scored from 0 to 100 on a fixed curve, from completed days only.',
  'Your score is the weighted average of the measures that have enough data. A missing measure is left ' +
    'out; it is never counted as zero.',
  `Tier A starts at ${HES_TIER_A_MIN}, tier B at ${HES_TIER_B_MIN}.`,
  'Coverage is the share of the full set of measures that has enough data.',
  'Without one of the core measures there is no score at all, never a low one.'
];
export const WHY_ASSUMPTIONS: string =
  'Weights, curves and minimum counts are prototype product assumptions, not clinically tested.';

// "HES 79 · 1 point to A"; at the top tier only the score.
export function whyHeadline(report: PersonaReport): string {
  const next = nextTierOf(report.tier);
  if (report.pointsToNext > 0 && next.length > 0) {
    return `HES ${report.hes} · ${pointsLine(report.pointsToNext, next)}`;
  }
  return `HES ${report.hes}`;
}

// "1 point to A", "5 points to A".
export function pointsLine(points: number, tier: string): string {
  return points === 1 ? `1 point to ${tier}` : `${points} points to ${tier}`;
}

// "Coverage 90% · Confidence High · Partial benefit".
export function whySubline(report: PersonaReport): string {
  return `Coverage ${report.coveragePct}% · Confidence ${report.confidence} · ${benefitLabel(report.benefit)}`;
}

// "±24 min · weight 17%".
export function whyRowDetail(row: ComponentRow): string {
  return `${row.raw} ${row.unit} · weight ${weightText(row)}`;
}

// "14 days" under a measure that already has enough data.
export function countLine(row: ComponentRow): string {
  return `${row.validCount} ${countUnit(row.id)}`;
}

// --- Report tab: the live card and the demo controls ---

export const LIVE_TITLE: string = 'Live';
export const LIVE_CHIP: string = 'Demo values';
export const LIVE_NOTE: string =
  'Live readings are shown, never scored. Your score uses completed days only.';
export const NO_READING: string = '—';
export const DEMO_TITLE: string = 'Demo controls';
export const DEMO_HR_LABEL: string = 'Heart rate';
export const DEMO_STEPS_LABEL: string = 'Steps today';
export const DEMO_CLOSE_DAY: string = 'Close the day';
export const DEMO_RESET: string = 'Reset demo';
export const DEMO_NOTE: string =
  'Close the day adds today as a completed day and recalculates the score. Reset returns this persona ' +
    'to its starting month.';
export const PERSONA_SHEET_NOTE_ENGINE: string = 'Scripted demo personas, scored by the same rules';

// The note under the persona sheet title: fixed preview values, or scripted days scored by the rules.
export function personaSheetNote(preview: boolean): string {
  return preview ? PERSONA_SHEET_NOTE : PERSONA_SHEET_NOTE_ENGINE;
}

// A live reading as text; a reading below zero is "no reading", never a number.
export function liveText(value: number): string {
  return value < 0 ? NO_READING : grouped(value);
}
