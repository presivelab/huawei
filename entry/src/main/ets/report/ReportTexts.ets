import {
  benefitLabel,
  ComponentId,
  ComponentRow,
  DayState,
  hasScore,
  healthSourceLabel,
  HES_TIER_A_MIN,
  HES_TIER_B_MIN,
  HesProfile,
  hesProfileLabel,
  nextTierOf,
  PARTNER_HES_PROFILE,
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
export const DISCLAIMER: string =
  'HES is deterministic rules, not a medical device and not AI / ML. Weights and curves are ' +
    'research-informed product assumptions, not clinically or actuarially validated.';

// The profile switch of the Report tab and the Why page: the two weight profiles, named by the engine.
export const PROFILE_SWITCH_SPOKEN: string = 'Weight profile';
export const PROFILE_OPTIONS: HesProfile[] = [HesProfile.HEALTH_WELLNESS, HesProfile.LONGEVITY_WELLNESS];
export const COVERAGE_CHIP_PREFIX: string = 'Evidence coverage ';
export const CONFIDENCE_CHIP_PREFIX: string = 'Data confidence: ';

// "Health & wellness" or "Longevity".
export function profileOptionLabel(profile: HesProfile): string {
  return hesProfileLabel(profile);
}

// Under the switch while the profile on screen is not the partner's: it explains, it changes nothing.
export function profileExplainLine(): string {
  return `Shown for explanation. Sharing and benefits use ${hesProfileLabel(PARTNER_HES_PROFILE)} (set by partner).`;
}

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

// Evidence for sleep is counted in nights, recovery in workouts (one reading per workout), VO₂max in
// estimates (one per estimate the watch made), everything else in days.
export function countUnit(id: string): string {
  if (id === ComponentId.SLEEP || id === ComponentId.SLEEP_REGULARITY) {
    return 'nights';
  }
  if (id === ComponentId.HR_RECOVERY) {
    return 'sessions';
  }
  return id === ComponentId.VO2MAX ? 'estimates' : 'days';
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
    return `No score yet · evidence coverage ${report.coverageText}`;
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

export const WHY_NO_SCORE_LABEL: string = 'Why no score yet';
export const WHY_STRONGEST: string = 'Strongest';
export const WHY_IMPROVE: string = 'To improve';
export const WHY_MISSING: string = 'Missing data (optional)';
export const WHY_MISSING_NOTE: string =
  'Missing optional data lowers Evidence coverage. It is never scored as zero.';
export const WHY_OPTIONAL_NOT_YET: string = 'Optional, not yet';
export const WHY_MEASURED: string = 'Measured so far';
export const WHY_NEEDED: string = 'Needed for a score';
export const WHY_NOT_MEASURED: string = 'Not measured';
export const WHY_ENOUGH: string = 'Enough for a score';
export const WHY_HOW_TITLE: string = 'How it\'s calculated';
export const WHY_HOW_LINES: string[] = [
  'There are two weight profiles, Health & wellness and Longevity. Each measure is scored from 0 to 100 on a ' +
    'fixed curve.',
  'Five measures are Core: resting HR, MVPA, steps, sleep timing regularity and sleep duration. Three are ' +
    'optional: VO₂max, HRV and HRR.',
  'Your score is the weighted average of the measures that have enough data. Missing optional data lowers ' +
    'Evidence coverage and is never scored as zero.',
  'Without all Core measures there is no score at all, never a low one.',
  'Windows: 28 days; HRV 14 nights, HRR 60 days, VO₂max 90 days. The current day is not scored until it ' +
    'is closed.',
  `Tier A starts at ${HES_TIER_A_MIN}, tier B at ${HES_TIER_B_MIN}.`
];
export const WHY_ASSUMPTIONS: string =
  'Weights, curves, thresholds, windows and minimum counts are research-informed product assumptions, ' +
    'not clinically or actuarially validated.';

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

// "Evidence coverage 90% · Data confidence High · Partial benefit".
export function whySubline(report: PersonaReport): string {
  return `Evidence coverage ${report.coverageText} · Data confidence ${report.confidence} · ` +
    benefitLabel(report.benefit);
}

// "No score yet" header line: the coverage and why there is no benefit.
export function noScoreSubline(report: PersonaReport): string {
  return `Evidence coverage ${report.coverageText} · ${report.benefitReason}`;
}

// "±24 min" or "±24 min · weight 17.0%"; the weight only when the coverage is below 100%.
export function whyRowDetail(row: ComponentRow, showWeights: boolean): string {
  return showWeights && row.weightText.length > 0 ? `${row.rawText} · weight ${weightText(row)}` : row.rawText;
}

// "Daily steps — 6,800/day (16 days)": a measure that has data, with its value and count.
export function measuredLine(row: ComponentRow): string {
  return row.rawText.length > 0 ? `${row.label} — ${row.rawText} (${countLine(row)})` :
    `${row.label} — ${countLine(row)}`;
}

// "14 days" or "1 night" under a measure that already has data.
export function countLine(row: ComponentRow): string {
  const unit = countUnit(row.id);
  return `${row.validCount} ${row.validCount === 1 ? unit.substring(0, unit.length - 1) : unit}`;
}

// --- Report tab: the live card and the demo controls ---

export const LIVE_TITLE: string = 'Live · not scored';
export const LIVE_CHIP: string = 'Demo values';
export const LIVE_NOTE: string =
  'Not scored: changing these never changes the score. Close the day turns today\'s steps into a completed ' +
    'day; the heart rate is never stored.';
export const NO_READING: string = '—';
export const DEMO_TITLE: string = 'Demo controls';
export const DEMO_HR_LABEL: string = 'Heart rate';
export const DEMO_STEPS_LABEL: string = 'Steps today';
export const DEMO_CLOSE_DAY: string = 'Close the day';
export const DEMO_RESET: string = 'Reset demo';
export const DEMO_NOTE: string =
  'Close the day adds today as a completed day and recalculates the score. Reset returns this persona ' +
    'to its starting month.';
export const DEMO_DAY_CLOSED: string = 'Day closed';
export const DEMO_RESET_DONE: string = 'Demo reset';
export const PERSONA_SHEET_NOTE_ENGINE: string = 'Scripted demo personas, scored by the same rules';

// The note under the persona sheet title: fixed preview values, or scripted days scored by the rules.
export function personaSheetNote(preview: boolean): string {
  return preview ? PERSONA_SHEET_NOTE : PERSONA_SHEET_NOTE_ENGINE;
}

// A live reading as text; a reading below zero is "no reading", never a number.
export function liveText(value: number): string {
  return value < 0 ? NO_READING : grouped(value);
}
