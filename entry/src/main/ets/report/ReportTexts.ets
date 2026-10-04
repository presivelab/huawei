import {
  benefitLabel,
  ComponentId,
  hasScore,
  healthSourceLabel,
  PersonaReport,
  ReportTier
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
export const SHARE_PLACEHOLDER: string = 'The share screen arrives in the next step.';
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
  if (report.tier === ReportTier.B) {
    if (report.pointsToNext === 1) {
      return '1 point to A';
    }
    return report.pointsToNext > 1 ? `${report.pointsToNext} points to A` : 'Solid overall profile';
  }
  return 'Tier C this month';
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
