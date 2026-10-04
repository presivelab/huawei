import { HES_DEFAULT_PROFILE } from '../hes/HesCurves';
import { benefitLevel, benefitReason, discountPct } from './Benefit';
import {
  BAR_NO_DATA,
  ComponentId,
  ComponentRow,
  DayCell,
  DayState,
  HES_NONE,
  LiveNow,
  PersonaReport,
  PersonaRef,
  POINTS_UNKNOWN,
  ReportConfidence,
  ReportTier,
  WearSummary
} from './ReportModels';

/*
 * Fixed preview reports of the six demo personas.
 *
 * Score, tier, coverage, confidence, eligibility and benefit are the expected results of the personas
 * for the default profile (health insurance, HES vNext weights) and must not be tuned. Component values,
 * days and seven-day bars are illustrative; the weights are the health-insurance weights of the components
 * shown. The screens label all of it as preview data. When the scoring engine is part of the build, the tests
 * of this file check the engine against the same expected results.
 */

export const PREVIEW_PERIOD: string = '4 Sep – 3 Oct';
export const PREVIEW_PERIOD_ISO: string = '2026-09-04..2026-10-03';
export const PREVIEW_DEFAULT_ID: string = 'ania';
export const PREVIEW_SOURCE: string = 'HUAWEI Health · demo';

const TOTAL_DAYS: number = 30;
const NO_BARS: number[] = [BAR_NO_DATA, BAR_NO_DATA, BAR_NO_DATA, BAR_NO_DATA, BAR_NO_DATA, BAR_NO_DATA,
  BAR_NO_DATA];

const LABEL_STEPS: string = 'Daily steps';
const LABEL_ACTIVE: string = 'Active minutes';
const LABEL_RHR: string = 'Resting heart rate';
const LABEL_SLEEP: string = 'Sleep duration';
const LABEL_SLEEP_REG: string = 'Sleep timing regularity';
const LABEL_VO2MAX: string = 'VO₂max';
const LABEL_HRV: string = 'Heart rate variability';
const LABEL_HRR: string = 'Heart-rate recovery';

// Days or nights with data the score needs. The three optional components have no minimum.
const MIN_DAYS: number = 14;
const MIN_RHR_DAYS: number = 10;
const MIN_OPTIONAL: number = 0;

class Measured {
  score: number = HES_NONE;
  raw: string = '';
  unit: string = '';
  weightPct: number = 0;
  validCount: number = 0;
  bars7: number[] = NO_BARS;
}

function measured(score: number, raw: string, unit: string, weightPct: number, validCount: number,
  bars7: number[]): Measured {
  const m = new Measured();
  m.score = score;
  m.raw = raw;
  m.unit = unit;
  m.weightPct = weightPct;
  m.validCount = validCount;
  m.bars7 = bars7;
  return m;
}

function row(id: string, label: string, minCount: number, m: Measured): ComponentRow {
  return {
    id: id,
    label: label,
    score: m.score,
    raw: m.raw,
    unit: m.unit,
    weightPct: m.weightPct,
    available: true,
    validCount: m.validCount,
    minCount: minCount,
    bars7: m.bars7,
    source: PREVIEW_SOURCE
  };
}

// A component without enough data: no value, no score, no weight. Never a zero.
function missing(id: string, label: string, minCount: number, validCount: number): ComponentRow {
  return {
    id: id,
    label: label,
    score: HES_NONE,
    raw: '',
    unit: '',
    weightPct: 0,
    available: false,
    validCount: validCount,
    minCount: minCount,
    bars7: NO_BARS,
    source: ''
  };
}

function steps(m: Measured): ComponentRow {
  return row(ComponentId.STEPS, LABEL_STEPS, MIN_DAYS, m);
}

function active(m: Measured): ComponentRow {
  return row(ComponentId.ACTIVE_MINUTES, LABEL_ACTIVE, MIN_DAYS, m);
}

function restingHr(m: Measured): ComponentRow {
  return row(ComponentId.RESTING_HR, LABEL_RHR, MIN_RHR_DAYS, m);
}

function sleep(m: Measured): ComponentRow {
  return row(ComponentId.SLEEP, LABEL_SLEEP, MIN_DAYS, m);
}

function sleepRegularity(m: Measured): ComponentRow {
  return row(ComponentId.SLEEP_REGULARITY, LABEL_SLEEP_REG, MIN_DAYS, m);
}

function vo2max(m: Measured): ComponentRow {
  return row(ComponentId.VO2MAX, LABEL_VO2MAX, MIN_OPTIONAL, m);
}

function hrv(m: Measured): ComponentRow {
  return row(ComponentId.HRV, LABEL_HRV, MIN_OPTIONAL, m);
}

function hrRecovery(m: Measured): ComponentRow {
  return row(ComponentId.HR_RECOVERY, LABEL_HRR, MIN_OPTIONAL, m);
}

function noVo2max(): ComponentRow {
  return missing(ComponentId.VO2MAX, LABEL_VO2MAX, MIN_OPTIONAL, 0);
}

function noHrv(): ComponentRow {
  return missing(ComponentId.HRV, LABEL_HRV, MIN_OPTIONAL, 0);
}

function noHrRecovery(): ComponentRow {
  return missing(ComponentId.HR_RECOVERY, LABEL_HRR, MIN_OPTIONAL, 0);
}

function wornPctOf(state: string, n: number): number {
  if (state === DayState.COMPLIANT) {
    return 92 + (n * 7) % 9;
  }
  if (state === DayState.SHORT) {
    return 68;
  }
  if (state === DayState.SUSPICIOUS) {
    return 60;
  }
  return 0;
}

/*
 * The days of the period. Every day is compliant unless its number is in one of the lists; days up to
 * `unknownUntil` have no data. `lastWeek`, when given, holds the worn share of the last seven days.
 */
function periodDays(shortDays: number[], suspiciousDays: number[], sickDays: number[], unknownUntil: number,
  lastWeek: number[]): DayCell[] {
  const out: DayCell[] = [];
  for (let n = 1; n <= TOTAL_DAYS; n++) {
    let state: string = DayState.COMPLIANT;
    if (n <= unknownUntil) {
      state = DayState.UNKNOWN;
    } else if (suspiciousDays.indexOf(n) >= 0) {
      state = DayState.SUSPICIOUS;
    } else if (shortDays.indexOf(n) >= 0) {
      state = DayState.SHORT;
    } else if (sickDays.indexOf(n) >= 0) {
      state = DayState.SICK;
    }
    let wornPct: number = wornPctOf(state, n);
    const weekIndex: number = n - (TOTAL_DAYS - lastWeek.length) - 1;
    if (state === DayState.COMPLIANT && weekIndex >= 0 && weekIndex < lastWeek.length) {
      wornPct = lastWeek[weekIndex];
    }
    out.push({ n: n, state: state, wornPct: wornPct });
  }
  return out;
}

function wear(compliantDays: number, nightsWorn: number, suspicious: number, flagged: boolean,
  days: DayCell[]): WearSummary {
  return {
    compliantDays: compliantDays,
    totalDays: TOTAL_DAYS,
    nightsWorn: nightsWorn,
    suspicious: suspicious,
    flagged: flagged,
    days: days
  };
}

class Expected {
  id: string = '';
  name: string = '';
  hes: number = HES_NONE;
  tier: string = ReportTier.NONE;
  coveragePct: number = 0;
  confidence: string = ReportConfidence.INSUFFICIENT;
  eligible: boolean = false;
  pointsToNext: number = POINTS_UNKNOWN;
}

function expected(id: string, name: string, hes: number, tier: string, coveragePct: number, confidence: string,
  eligible: boolean, pointsToNext: number): Expected {
  const e = new Expected();
  e.id = id;
  e.name = name;
  e.hes = hes;
  e.tier = tier;
  e.coveragePct = coveragePct;
  e.confidence = confidence;
  e.eligible = eligible;
  e.pointsToNext = pointsToNext;
  return e;
}

function report(e: Expected, components: ComponentRow[], wearSummary: WearSummary, live: LiveNow,
  whatIf: string): PersonaReport {
  const scored: boolean = e.hes >= 0 && e.tier !== ReportTier.NONE;
  const benefit: string = benefitLevel(e.eligible, e.tier, scored);
  return {
    id: e.id,
    name: e.name,
    profile: HES_DEFAULT_PROFILE,
    period: PREVIEW_PERIOD,
    periodIso: PREVIEW_PERIOD_ISO,
    hes: e.hes,
    tier: e.tier,
    coveragePct: e.coveragePct,
    confidence: e.confidence,
    eligible: e.eligible,
    benefit: benefit,
    benefitReason: benefitReason(e.eligible, e.tier, scored, wearSummary.flagged, wearSummary.suspicious),
    discountPct: discountPct(HES_DEFAULT_PROFILE, benefit),
    pointsToNext: e.pointsToNext,
    components: components,
    wear: wearSummary,
    live: live,
    whatIf: whatIf
  };
}

// A/92, coverage 100%, High: full benefit. Values as on the Report mock-up.
function ania(): PersonaReport {
  return report(
    expected('ania', 'Ania', 92, ReportTier.A, 100, ReportConfidence.HIGH, true, 0),
    [
      steps(measured(95, '9,412', '/day', 15, 28, [62, 80, 71, 90, 68, 95, 84])),
      active(measured(93, '212', 'min/week', 20, 28, [55, 70, 40, 88, 76, 92, 64])),
      restingHr(measured(92, '56', 'bpm', 13, 28, [60, 58, 62, 57, 59, 56, 58])),
      sleep(measured(90, '7 h 24', 'min', 13, 28, [78, 82, 74, 86, 80, 88, 84])),
      sleepRegularity(measured(96, '±22', 'min', 15, 28, [90, 86, 92, 88, 94, 90, 92])),
      vo2max(measured(90, '47', 'ml/kg/min', 12, 4, [70, 72, 72, 74, 74, 76, 76])),
      hrv(measured(88, '58', 'ms', 7, 27, [64, 70, 58, 72, 66, 74, 68])),
      hrRecovery(measured(88, '34', 'bpm in 60 s', 5, 9,
        [BAR_NO_DATA, 70, BAR_NO_DATA, BAR_NO_DATA, 76, BAR_NO_DATA, 80]))
    ],
    wear(28, 29, 0, false, periodDays([10, 22], [], [], 0, [100, 100, 92, 100, 100, 96, 100])),
    { hr: 72, steps: 5843 },
    '');
}

// B/75, coverage 87.5%, High: flagged after three suspicious breaks, so no benefit. Days as on the
// Evidence mock-up: suspicious on 3, 17 and 24, short on 10, sick on 11, 12 and 25.
function marek(): PersonaReport {
  return report(
    expected('marek', 'Marek', 75, ReportTier.B, 87.5, ReportConfidence.HIGH, false, 5),
    [
      steps(measured(78, '7,820', '/day', 17, 26, [58, 72, 64, 80, 52, 76, 70])),
      active(measured(72, '142', 'min/week', 23, 26, [48, 66, 30, 74, 58, 80, 62])),
      restingHr(measured(70, '68', 'bpm', 14, 25, [66, 70, 68, 72, 67, 69, 68])),
      sleep(measured(76, '6 h 48', 'min', 14, 24, [70, 76, 62, 80, 72, 78, 74])),
      sleepRegularity(measured(80, '±38', 'min', 17, 24, [74, 80, 68, 82, 78, 84, 76])),
      noVo2max(),
      hrv(measured(74, '41', 'ms', 9, 22, [52, 60, 46, 62, 56, 64, 58])),
      hrRecovery(measured(70, '25', 'bpm in 60 s', 6, 5,
        [BAR_NO_DATA, BAR_NO_DATA, 62, BAR_NO_DATA, BAR_NO_DATA, 68, BAR_NO_DATA]))
    ],
    wear(26, 25, 3, true, periodDays([10], [3, 17, 24], [11, 12, 25], 0, [])),
    { hr: 75, steps: 3120 },
    '');
}

// B/71, coverage 75%, Medium: one suspicious break, which never flags, so partial benefit.
function kasia(): PersonaReport {
  return report(
    expected('kasia', 'Kasia', 71, ReportTier.B, 75, ReportConfidence.MEDIUM, true, 9),
    [
      steps(measured(70, '6,950', '/day', 20, 24, [50, 64, 58, 72, 46, 70, 62])),
      active(measured(63, '124', 'min/week', 27, 24, [42, 60, 34, 70, 52, 74, 56])),
      restingHr(measured(76, '64', 'bpm', 17, 22, [62, 66, 63, 65, 64, 66, 64])),
      sleep(measured(78, '6 h 55', 'min', 16, 21, [72, 78, 66, 80, 74, 82, 76])),
      sleepRegularity(measured(74, '±44', 'min', 20, 21, [68, 74, 62, 78, 70, 80, 72])),
      noVo2max(),
      noHrv(),
      noHrRecovery()
    ],
    wear(27, 26, 1, false, periodDays([6, 21], [14], [], 0, [])),
    { hr: 70, steps: 3890 },
    '');
}

// B/79, coverage 92.5%, High: one point to A. Components as on the "Why this tier" mock-up.
function tomek(): PersonaReport {
  return report(
    expected('tomek', 'Tomek', 79, ReportTier.B, 92.5, ReportConfidence.HIGH, true, 1),
    [
      steps(measured(86, '8,640', '/day', 16, 28, [66, 82, 74, 88, 70, 90, 80])),
      active(measured(67, '118', 'min/week', 22, 28, [40, 58, 32, 66, 50, 72, 54])),
      restingHr(measured(74, '66', 'bpm', 14, 27, [64, 68, 66, 67, 65, 68, 66])),
      sleep(measured(67, '6 h 15', 'min', 14, 27, [60, 68, 54, 70, 62, 72, 64])),
      sleepRegularity(measured(96, '±24', 'min', 16, 27, [90, 88, 94, 90, 92, 94, 92])),
      vo2max(measured(89, '82nd', 'percentile', 13, 4, [80, 80, 82, 82, 82, 82, 82])),
      noHrv(),
      hrRecovery(measured(58, '22', 'bpm in 60 s', 5, 6,
        [BAR_NO_DATA, 52, BAR_NO_DATA, 58, BAR_NO_DATA, BAR_NO_DATA, 56]))
    ],
    wear(29, 29, 0, false, periodDays([19], [], [], 0, [])),
    { hr: 68, steps: 4210 },
    'Sleeping 7 h a night would be enough for Tier A.');
}

// C/58, coverage 80%, High: wear is fine, the score is C, so no benefit.
function ewa(): PersonaReport {
  return report(
    expected('ewa', 'Ewa', 58, ReportTier.C, 80, ReportConfidence.HIGH, true, POINTS_UNKNOWN),
    [
      steps(measured(52, '4,870', '/day', 19, 25, [36, 48, 30, 54, 40, 58, 44])),
      active(measured(50, '74', 'min/week', 25, 25, [24, 40, 18, 46, 30, 52, 34])),
      restingHr(measured(64, '72', 'bpm', 16, 23, [70, 74, 72, 73, 71, 74, 72])),
      sleep(measured(66, '6 h 20', 'min', 15, 22, [58, 66, 52, 68, 60, 70, 62])),
      sleepRegularity(measured(62, '±58', 'min', 19, 22, [54, 62, 48, 66, 58, 68, 60])),
      noVo2max(),
      noHrv(),
      hrRecovery(measured(62, '20', 'bpm in 60 s', 6, 4,
        [BAR_NO_DATA, BAR_NO_DATA, BAR_NO_DATA, 50, BAR_NO_DATA, BAR_NO_DATA, 54]))
    ],
    wear(26, 25, 0, false, periodDays([5, 9, 16, 27], [], [], 0, [])),
    { hr: 78, steps: 2140 },
    '');
}

// No score, coverage 47.5%: fourteen days of history and too few nights. Counters as on the mock-up.
function ola(): PersonaReport {
  return report(
    expected('ola', 'Ola', HES_NONE, ReportTier.NONE, 47.5, ReportConfidence.INSUFFICIENT, false, POINTS_UNKNOWN),
    [
      steps(measured(HES_NONE, '6,120', '/day', 0, 14, [44, 60, 52, 66, 48, 70, 58])),
      active(measured(HES_NONE, '96', 'min/week', 0, 14, [30, 48, 26, 56, 40, 60, 44])),
      missing(ComponentId.RESTING_HR, LABEL_RHR, MIN_RHR_DAYS, 6),
      missing(ComponentId.SLEEP, LABEL_SLEEP, MIN_DAYS, 9),
      missing(ComponentId.SLEEP_REGULARITY, LABEL_SLEEP_REG, MIN_DAYS, 9),
      noVo2max(),
      noHrv(),
      noHrRecovery()
    ],
    wear(9, 9, 0, false, periodDays([18, 20, 23, 26, 29], [], [], 16, [])),
    { hr: 74, steps: 2960 },
    '');
}

let cache: PersonaReport[] = [];

/** The six preview reports, in the order the demo lists them. */
export function previewReports(): PersonaReport[] {
  if (cache.length === 0) {
    cache = [ania(), marek(), kasia(), tomek(), ewa(), ola()];
  }
  return cache;
}

export function previewPersonas(): PersonaRef[] {
  const all = previewReports();
  const out: PersonaRef[] = [];
  for (let i = 0; i < all.length; i++) {
    out.push({ id: all[i].id, name: all[i].name });
  }
  return out;
}

/** The report of one persona. An unknown id gives the default persona; it never throws. */
export function previewReport(id: string): PersonaReport {
  const all = previewReports();
  for (let i = 0; i < all.length; i++) {
    if (all[i].id === id) {
      return all[i];
    }
  }
  return all[0];
}
