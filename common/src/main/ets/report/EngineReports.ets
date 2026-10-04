/*
 * The monthly report built from the scoring engine: the same `PersonaReport` the fixed preview fills, with
 * every value taken from HES vNext (`hes/`), the person's history and the wear month (`wear/`).
 * Pure logic: no UI and no platform imports.
 *
 * What comes from where:
 *   - score, tier, coverage, confidence, component scores and weights: the engine result in the profile the
 *     report is asked for;
 *   - eligible, benefit and its reason: always the engine result in the partner's profile
 *     (`PARTNER_HES_PROFILE`), whichever profile the report shows. The profile switch on a screen explains;
 *     it never changes what is shared or what the benefit is;
 *   - raw values with units and the seven-day bars: the completed days of the history;
 *   - compliant days, nights, suspicious breaks, the flag and the 30 day cells: the wear month;
 *   - eligible = the wear month is eligible and there is a score; benefit and its reason: `Benefit.ets`;
 *   - live heart rate and today's steps: the session. They are shown and never scored;
 *   - the details of each day (worn time, charging, the night, breaks, the reason of the day): the wear
 *     month again, as `DayDetail`.
 *
 * Decisions:
 *   - a value that does not exist stays missing: HES_NONE, POINTS_UNKNOWN, BAR_NO_DATA, an empty text.
 *     Zero is written only for a reading of zero;
 *   - `weightPct` is the effective weight with one decimal (16.7). It is 0 for every component when there is
 *     no score, because there is nothing to weigh;
 *   - `minCount` is the engine's minimum for a Core component and 0 for the three components the score
 *     does not require, as `ReportModels` defines it; `needCount` is the engine's minimum for all eight;
 *   - VO2max and HRV are percentiles the source supplies, so they are shown as percentiles;
 *   - a bar is the reading of that one day on the component's curve. Sleep timing regularity has no value
 *     for a single night; its bar is how far that night's bedtime and wake time were from the person's
 *     own average, on the same curve. VO2max and recovery have a bar on a day with an estimate or a session;
 *   - the wear month is the persona's fixed month. Closing a day in a session changes the score, the
 *     components and the bars; the period and the day cells stay as they are;
 *   - the points to the next tier are to B for tier C and to A for tier B (`nextTierOf`);
 *   - a day's `reason` states the numbers the wear rule compared. It never guesses why the watch was off;
 *   - `DayDetail.breaks` lists the off-wrist stretches the rule counts as breaks (at least `gapMinMinutes`);
 *     shorter moments off the wrist are not listed.
 */
import { TIER_A, TIER_B, TIER_C } from '../claim/ClaimValidation';
import { ALL_HEALTH_SCOPES, HealthScope } from '../health/HealthConnection';
import { HealthStatus } from '../health/HealthRecords';
import { healthSimSnapshot, HealthSimPerson, snapshotWithScopes } from '../health/HealthSimPayload';
import { healthSourceLabel } from '../health/HealthStatusLabel';
import {
  equivalentMvpa,
  hesIsScoredHrv,
  hesIsValidNight,
  hesIsValidValue,
  hesMean,
  sleepRelativeMinutes,
  sleepTimingSd
} from '../hes/HesAggregate';
import { piecewise } from '../hes/HesCurves';
import { composeComponents, hesRound } from '../hes/HesEngine';
import { pointsToNextTier } from '../hes/HesExplain';
import {
  hesConfidenceLabel,
  hesCountText,
  hesCoverageText,
  hesHoursText,
  hesOrdinal,
  hesRawText,
  hesThousands,
  hesWeightPct,
  hesWeightText
} from '../hes/HesFormat';
import {
  HES_DAYS_PER_WEEK,
  HES_MINUTES_PER_DAY,
  HES_MINUTES_PER_HOUR,
  HES_TIER_A_MIN,
  HES_TIER_B_MIN,
  HES_WINDOW_DAYS,
  hesComponentDefinition,
  HesComponentDefinition,
  hesProfileLabel,
  HesPoint
} from '../hes/HesModel';
import { HesPersonas } from '../hes/HesPersonas';
import { HesSession } from '../hes/HesSession';
import {
  ComponentId as HesComponentId,
  ComponentResult,
  HesConfidence,
  HesDayRecord,
  HesHistory,
  HesProfile,
  HesResult,
  HesStatus
} from '../hes/HesTypes';
import { DEFAULT_THRESHOLDS } from '../model/defaults';
import { Thresholds } from '../model/types';
import { buildWearMonth, WearBreakResult, WearDayResult, WearDayState, WearMonthResult } from '../wear/WearMonth';
import { WearPersonas } from '../wear/WearPersonas';
import { benefitLevel, benefitReason } from './Benefit';
import { PARTNER_HES_PROFILE } from './PartnerProgram';
import {
  BAR_NO_DATA,
  ComponentId,
  ComponentRow,
  DayCell,
  HES_NONE,
  LIVE_NONE,
  LiveNow,
  PersonaRef,
  PersonaReport,
  POINTS_UNKNOWN,
  ReportConfidence,
  WearSummary
} from './ReportModels';

/** The persona an unknown id falls back to. */
export const ENGINE_DEFAULT_ID: string = 'ania';
/** Where the values come from, as the screens write it: "HUAWEI Health · Demo data". */
export const ENGINE_SOURCE: string = healthSourceLabel(HealthStatus.DEMO);
/** Where the values come from when Health Sim sent them: "Health Sim · Simulated data". */
export const HEALTH_SIM_LABEL: string = 'Health Sim · Simulated data';

const BAR_DAYS: number = 7;
const MINUTES_PER_HOUR: number = HES_MINUTES_PER_HOUR;
const MINUTES_PER_DAY: number = HES_MINUTES_PER_DAY;
const PERCENT: number = 100;
const FULL_COVERAGE_PERMILLE: number = 1000;
const MONTHS: string[] = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

// The order the report lists the components in (ComponentId).
const ROW_ORDER: HesComponentId[] = [
  HesComponentId.STEPS,
  HesComponentId.MVPA,
  HesComponentId.RHR,
  HesComponentId.SLEEP_DURATION,
  HesComponentId.SLEEP_REGULARITY,
  HesComponentId.CRF,
  HesComponentId.HRV,
  HesComponentId.HRR
];

/** The report's id of an engine component. */
export function reportComponentId(id: HesComponentId): string {
  switch (id) {
    case HesComponentId.STEPS:
      return ComponentId.STEPS;
    case HesComponentId.MVPA:
      return ComponentId.ACTIVE_MINUTES;
    case HesComponentId.RHR:
      return ComponentId.RESTING_HR;
    case HesComponentId.SLEEP_DURATION:
      return ComponentId.SLEEP;
    case HesComponentId.SLEEP_REGULARITY:
      return ComponentId.SLEEP_REGULARITY;
    case HesComponentId.CRF:
      return ComponentId.VO2MAX;
    case HesComponentId.HRV:
      return ComponentId.HRV;
    default:
      return ComponentId.HR_RECOVERY;
  }
}

/** The tier above: 'A' for B, 'B' for C. Empty for tier A and for no score. */
export function nextTierOf(tier: string): string {
  if (tier === TIER_B) {
    return TIER_A;
  }
  if (tier === TIER_C) {
    return TIER_B;
  }
  return '';
}

// ---------------------------------------------------------------------------------------------------------
// Numbers as text
// ---------------------------------------------------------------------------------------------------------

// "2026-09-04" -> "4 Sep". Text that is not a date is returned as it is.
function shortDate(date: string): string {
  if (date.length !== 10) {
    return date;
  }
  const month = Number.parseInt(date.substring(5, 7), 10);
  const day = Number.parseInt(date.substring(8, 10), 10);
  if (Number.isNaN(month) || Number.isNaN(day) || month < 1 || month > MONTHS.length) {
    return date;
  }
  return `${day} ${MONTHS[month - 1]}`;
}

// "2026-09-04..2026-10-03" -> "4 Sep – 3 Oct".
function periodText(periodIso: string): string {
  const cut = periodIso.indexOf('..');
  if (cut < 0) {
    return periodIso;
  }
  return `${shortDate(periodIso.substring(0, cut))} – ${shortDate(periodIso.substring(cut + 2))}`;
}

// The wear month as read on screen. When "Close the day" has scored days after the month, the last scored
// day is added: "4 Sep – 3 Oct · score to 5 Oct". The claim keeps the wear month (periodIso).
export const SCORE_TO: string = ' · score to ';

function periodLine(periodIso: string, days: HesDayRecord[]): string {
  const text = periodText(periodIso);
  const cut = periodIso.indexOf('..');
  if (cut < 0 || days.length === 0) {
    return text;
  }
  const last: string = days[days.length - 1].date;
  return last > periodIso.substring(cut + 2) ? `${text}${SCORE_TO}${shortDate(last)}` : text;
}

class RawText {
  raw: string = '';
  unit: string = '';

  constructor(raw: string, unit: string) {
    this.raw = raw;
    this.unit = unit;
  }
}

// The measured value of an available component as the tile shows it: a number and its unit.
function rawText(id: HesComponentId, value: number): RawText {
  switch (id) {
    case HesComponentId.STEPS:
      return new RawText(hesThousands(value), '/day');
    case HesComponentId.MVPA:
      return new RawText(`${hesRound(value)}`, 'min/week');
    case HesComponentId.RHR:
      return new RawText(`${hesRound(value)}`, 'bpm');
    case HesComponentId.SLEEP_DURATION: {
      const total = hesRound(value * MINUTES_PER_HOUR);
      const h = Math.floor(total / MINUTES_PER_HOUR);
      const m = total % MINUTES_PER_HOUR;
      return m === 0 ? new RawText(`${h}`, 'h') : new RawText(`${h} h ${m}`, 'min');
    }
    case HesComponentId.SLEEP_REGULARITY:
      return new RawText(`±${hesRound(value)}`, 'min');
    case HesComponentId.CRF:
    case HesComponentId.HRV:
      return new RawText(hesOrdinal(value), 'percentile');
    default:
      return new RawText(`${hesRound(value)}`, 'bpm in 60 s');
  }
}

// ---------------------------------------------------------------------------------------------------------
// Seven-day bars
// ---------------------------------------------------------------------------------------------------------

const NO_READING: number = -1;

// The mean bedtime or wake time, in minutes since 18:00, of the valid nights among the last 28 days; 0 when
// there is none.
function meanClock(days: HesDayRecord[], bedtime: boolean): number {
  const values: number[] = [];
  for (let i = Math.max(0, days.length - HES_WINDOW_DAYS); i < days.length; i++) {
    const sleep = days[i].sleep;
    if (sleep !== undefined && hesIsValidNight(sleep)) {
      values.push(sleepRelativeMinutes(bedtime ? sleep.bedMin : sleep.wakeMin));
    }
  }
  const mean = hesMean(values);
  return mean === undefined ? 0 : mean;
}

// The reading of one day in the unit of the component's curve; NO_READING when the day has none.
function dayValue(id: HesComponentId, history: HesHistory, day: HesDayRecord, meanBedtime: number,
  meanWake: number): number {
  switch (id) {
    case HesComponentId.STEPS: {
      const steps = day.steps;
      return steps !== undefined && hesIsValidValue(steps) ? steps : NO_READING;
    }
    case HesComponentId.MVPA: {
      const moderate = day.moderateMin;
      const vigorous = day.vigorousMin;
      if (moderate === undefined || vigorous === undefined || !hesIsValidValue(moderate) ||
        !hesIsValidValue(vigorous)) {
        return NO_READING;
      }
      return equivalentMvpa(moderate, vigorous) * HES_DAYS_PER_WEEK;
    }
    case HesComponentId.RHR: {
      const rhr = day.restingHr;
      return rhr !== undefined && hesIsValidValue(rhr) ? rhr : NO_READING;
    }
    case HesComponentId.SLEEP_DURATION: {
      const sleep = day.sleep;
      return sleep !== undefined && hesIsValidNight(sleep) ? sleep.totalSleepMin / MINUTES_PER_HOUR : NO_READING;
    }
    case HesComponentId.SLEEP_REGULARITY: {
      const sleep = day.sleep;
      if (sleep === undefined || !hesIsValidNight(sleep)) {
        return NO_READING;
      }
      return sleepTimingSd(Math.abs(sleepRelativeMinutes(sleep.bedMin) - meanBedtime),
        Math.abs(sleepRelativeMinutes(sleep.wakeMin) - meanWake));
    }
    case HesComponentId.CRF: {
      for (let i = history.crf.length - 1; i >= 0; i--) {
        if (history.crf[i].date === day.date && hesIsValidValue(history.crf[i].percentile)) {
          return history.crf[i].percentile;
        }
      }
      return NO_READING;
    }
    case HesComponentId.HRV: {
      const hrv = day.hrv;
      return hrv !== undefined && hesIsScoredHrv(hrv) ? hrv.percentile : NO_READING;
    }
    default: {
      for (let i = history.hrr.length - 1; i >= 0; i--) {
        const s = history.hrr[i];
        if (s.date === day.date && hesIsValidValue(s.peakHr) && hesIsValidValue(s.hr60) && s.peakHr > s.hr60) {
          return s.peakHr - s.hr60;
        }
      }
      return NO_READING;
    }
  }
}

function noBars(): number[] {
  const out: number[] = [];
  for (let i = 0; i < BAR_DAYS; i++) {
    out.push(BAR_NO_DATA);
  }
  return out;
}

// The last seven completed days, oldest first: each day's reading on the component's curve, 0..100.
function barsOf(def: HesComponentDefinition, history: HesHistory): number[] {
  const days = history.days;
  const regularity = def.id === HesComponentId.SLEEP_REGULARITY;
  const meanBedtime = regularity ? meanClock(days, true) : 0;
  const meanWake = regularity ? meanClock(days, false) : 0;
  const out: number[] = [];
  for (let i = days.length - BAR_DAYS; i < days.length; i++) {
    if (i < 0) {
      out.push(BAR_NO_DATA);
      continue;
    }
    const value = dayValue(def.id, history, days[i], meanBedtime, meanWake);
    const score = value < 0 ? undefined : piecewise(def.curve, value);
    out.push(score === undefined ? BAR_NO_DATA : hesRound(score));
  }
  return out;
}

// ---------------------------------------------------------------------------------------------------------
// Components, wear and the report
// ---------------------------------------------------------------------------------------------------------

function findComponent(result: HesResult, id: HesComponentId): ComponentResult | null {
  for (let i = 0; i < result.components.length; i++) {
    if (result.components[i].id === id) {
      return result.components[i];
    }
  }
  return null;
}

function rowOf(c: ComponentResult, history: HesHistory, scored: boolean, source: string): ComponentRow {
  const minCount = c.requiredCore ? c.minimumCount : 0;
  const rawValue = c.rawValue;
  const score = c.score;
  if (!c.available || rawValue === undefined || score === undefined) {
    // Not enough data: no value, no score, no weight and no bar. The counts say how far it is.
    return {
      id: reportComponentId(c.id),
      label: c.label,
      score: HES_NONE,
      scoreExact: HES_NONE,
      raw: '',
      unit: '',
      rawText: '',
      weightPct: 0,
      weightText: '',
      available: false,
      core: c.requiredCore,
      validCount: c.validCount,
      minCount: minCount,
      needCount: c.minimumCount,
      targetCount: c.targetCount,
      countText: hesCountText(c),
      bars7: noBars(),
      source: ''
    };
  }
  const text = rawText(c.id, rawValue);
  const weight = c.effectiveWeight;
  return {
    id: reportComponentId(c.id),
    label: c.label,
    score: hesRound(score),
    scoreExact: score,
    raw: text.raw,
    unit: text.unit,
    rawText: hesRawText(c.id, rawValue),
    weightPct: scored ? hesWeightPct(c) : 0,
    weightText: scored && weight !== undefined ? hesWeightText(weight) : '',
    available: true,
    core: c.requiredCore,
    validCount: c.validCount,
    minCount: minCount,
    needCount: c.minimumCount,
    targetCount: c.targetCount,
    countText: hesCountText(c),
    bars7: barsOf(hesComponentDefinition(c.id), history),
    source: source
  };
}

function rowsOf(result: HesResult, history: HesHistory, scored: boolean, source: string): ComponentRow[] {
  const out: ComponentRow[] = [];
  for (let i = 0; i < ROW_ORDER.length; i++) {
    const c = findComponent(result, ROW_ORDER[i]);
    if (c !== null) {
      out.push(rowOf(c, history, scored, source));
    }
  }
  return out;
}

function confidenceOf(confidence: HesConfidence): string {
  if (confidence === HesConfidence.HIGH) {
    return ReportConfidence.HIGH;
  }
  if (confidence === HesConfidence.MEDIUM) {
    return ReportConfidence.MEDIUM;
  }
  if (confidence === HesConfidence.LOW) {
    return ReportConfidence.LOW;
  }
  return ReportConfidence.INSUFFICIENT;
}

// A day the watch did not observe has the state UNKNOWN; its worn share is not a reading.
function wearOf(month: WearMonthResult): WearSummary {
  const days: DayCell[] = [];
  for (let i = 0; i < month.days.length; i++) {
    const worn = hesRound(month.days[i].wornMin * PERCENT / MINUTES_PER_DAY);
    days.push({
      n: i + 1,
      state: month.days[i].state,
      wornPct: Math.max(0, Math.min(PERCENT, worn))
    });
  }
  return {
    compliantDays: month.compliantDays,
    totalDays: month.totalDays,
    nightsWorn: month.nightsWorn,
    suspicious: month.suspiciousBreaks,
    flagged: month.flagged,
    days: days
  };
}

function knownId(id: string): string {
  return HesPersonas.has(id) ? id : ENGINE_DEFAULT_ID;
}

let wearIds: string[] = [];
let wearMonths: WearMonthResult[] = [];

// The wear month of a persona never changes, so it is built once.
function wearMonthOf(id: string): WearMonthResult {
  const at = wearIds.indexOf(id);
  if (at >= 0) {
    return wearMonths[at];
  }
  const month = WearPersonas.result(id);
  wearIds.push(id);
  wearMonths.push(month);
  return month;
}

function isScored(result: HesResult): boolean {
  return result.status === HesStatus.OK && result.score !== undefined;
}

// `result` is the score in the profile the report shows. `partner` is the score in the partner's profile:
// eligibility and the benefit are always taken from it.
function build(id: string, result: HesResult, partner: HesResult, history: HesHistory, month: WearMonthResult,
  liveHr: number | undefined, liveSteps: number | undefined, source: string = ENGINE_SOURCE): PersonaReport {
  const scored: boolean = isScored(result);
  const partnerScored: boolean = isScored(partner);
  const eligible: boolean = partnerScored && month.eligible;
  const live: LiveNow = {
    hr: liveHr !== undefined && liveHr > 0 ? liveHr : LIVE_NONE,
    steps: liveSteps !== undefined && liveSteps >= 0 ? liveSteps : LIVE_NONE
  };
  const counterfactual = engineWhatIf(result);
  const score = result.score;
  const points = pointsToNextTier(result);
  return {
    id: id,
    name: HesPersonas.displayName(id),
    period: periodLine(month.period, history.days),
    periodIso: month.period,
    profile: result.profile,
    profileLabel: hesProfileLabel(result.profile),
    partnerProfile: result.profile === PARTNER_HES_PROFILE,
    hes: scored && score !== undefined ? score : HES_NONE,
    tier: result.tier,
    coveragePct: result.coverage,
    coverageText: hesCoverageText(result.coveragePermille),
    confidence: confidenceOf(result.confidence),
    showWeights: scored && result.coveragePermille < FULL_COVERAGE_PERMILLE,
    eligible: eligible,
    benefit: benefitLevel(eligible, partner.tier, partnerScored),
    benefitReason: benefitReason(eligible, partner.tier, partnerScored, month.flagged, month.suspiciousBreaks),
    pointsToNext: scored ? (points === undefined ? 0 : points) : POINTS_UNKNOWN,
    components: rowsOf(result, history, scored, source),
    wear: wearOf(month),
    live: live,
    whatIf: counterfactual === null ? '' : counterfactual.sentence
  };
}

// ---------------------------------------------------------------------------------------------------------
// The counterfactual
// ---------------------------------------------------------------------------------------------------------

/** One change in one Core component that reaches the next tier, with everything else as it is. */
export interface EngineWhatIf {
  componentId: string;       // ComponentId of the report
  hesId: HesComponentId;     // the engine's id of the same component
  fromRaw: number;           // the value today, in the unit of the component's curve
  toRaw: number;             // the value that is enough: a point of the component's curve
  score: number;             // the score with this one change
  tier: string;              // the tier that score gives
  sentence: string;          // one sentence for the screen
}

function copyComponent(c: ComponentResult): ComponentResult {
  const out: ComponentResult = {
    id: c.id,
    label: c.label,
    available: c.available,
    requiredCore: c.requiredCore,
    validCount: c.validCount,
    minimumCount: c.minimumCount,
    targetCount: c.targetCount,
    quality: c.quality,
    baseWeight: c.baseWeight,
    baseWeightPermille: c.baseWeightPermille
  };
  if (c.rawValue !== undefined) {
    out.rawValue = c.rawValue;
  }
  if (c.score !== undefined) {
    out.score = c.score;
  }
  return out;
}

// The score when one component has the value `toRaw` and nothing else changes.
function resultWith(result: HesResult, id: HesComponentId, toRaw: number): HesResult {
  const components: ComponentResult[] = [];
  for (let i = 0; i < result.components.length; i++) {
    const c = copyComponent(result.components[i]);
    if (c.id === id) {
      const score = piecewise(hesComponentDefinition(id).curve, toRaw);
      if (score !== undefined) {
        c.rawValue = toRaw;
        c.score = score;
      }
    }
    components.push(c);
  }
  return composeComponents(result.profile, components);
}

// The points of a curve between the value today and the top of the curve, the nearest first. For steps
// they go up; for the resting heart rate and the sleep timing they go down; none when the value is
// already on the top.
function pointsTowardsTop(curve: HesPoint[], raw: number): HesPoint[] {
  let top = -1;
  for (let i = 0; i < curve.length; i++) {
    top = Math.max(top, curve[i].y);
  }
  let firstTop = 0;
  let lastTop = 0;
  for (let i = 0; i < curve.length; i++) {
    if (curve[i].y === top) {
      lastTop = i;
    }
  }
  for (let i = curve.length - 1; i >= 0; i--) {
    if (curve[i].y === top) {
      firstTop = i;
    }
  }
  const out: HesPoint[] = [];
  if (raw < curve[firstTop].x) {
    for (let i = 0; i <= firstTop; i++) {
      if (curve[i].x > raw) {
        out.push(curve[i]);
      }
    }
  } else if (raw > curve[lastTop].x) {
    for (let i = curve.length - 1; i >= lastTop; i--) {
      if (curve[i].x < raw) {
        out.push(curve[i]);
      }
    }
  }
  return out;
}

function sentenceOf(id: HesComponentId, fromRaw: number, toRaw: number, tier: string): string {
  let target = '';
  let today = '';
  switch (id) {
    case HesComponentId.STEPS:
      target = `${hesThousands(toRaw)} steps a day`;
      today = hesThousands(fromRaw);
      break;
    case HesComponentId.MVPA:
      target = `${hesRound(toRaw)} active minutes a week`;
      today = `${hesRound(fromRaw)}`;
      break;
    case HesComponentId.SLEEP_DURATION:
      target = `${hesHoursText(toRaw)} of sleep a night`;
      today = hesHoursText(fromRaw);
      break;
    case HesComponentId.SLEEP_REGULARITY:
      target = `Bed and wake times within ±${hesRound(toRaw)} min`;
      today = `±${hesRound(fromRaw)} min`;
      break;
    default:
      target = `A resting heart rate of ${hesRound(toRaw)} bpm`;
      today = `${hesRound(fromRaw)} bpm`;
      break;
  }
  return `${target} instead of ${today} would be enough for Tier ${tier}, with everything else unchanged.`;
}

// The first point of the component's curve, going towards the top, that reaches `threshold`; null when
// even the top of the curve is not enough.
function firstCrossing(result: HesResult, c: ComponentResult, rawValue: number, score: number,
  threshold: number): EngineWhatIf | null {
  const points = pointsTowardsTop(hesComponentDefinition(c.id).curve, rawValue);
  for (let i = 0; i < points.length; i++) {
    if (points[i].y <= score) {
      continue;
    }
    const changed = resultWith(result, c.id, points[i].x);
    const changedScore = changed.score;
    if (changed.status === HesStatus.OK && changedScore !== undefined && changedScore >= threshold) {
      return {
        componentId: reportComponentId(c.id),
        hesId: c.id,
        fromRaw: rawValue,
        toRaw: points[i].x,
        score: changedScore,
        tier: changed.tier,
        sentence: sentenceOf(c.id, rawValue, points[i].x, changed.tier)
      };
    }
  }
  return null;
}

function relativeChange(change: EngineWhatIf): number {
  return change.fromRaw > 0 ? Math.abs(change.toRaw - change.fromRaw) / change.fromRaw : Number.MAX_VALUE;
}

/*
 * The counterfactual of a result below tier A: the smallest change in ONE Core component that reaches the
 * next tier. Each Core component is moved along its own curve, point by point towards the top, the score
 * is calculated again, and the first point that reaches the threshold is kept. Of the components that can
 * do it, the one with the smallest change relative to today's value is taken; equal changes keep the
 * report's order. The resting heart rate is not something a person sets directly, so it is taken only when
 * none of steps, active minutes, sleep duration and sleep timing is enough.
 *
 * null when there is no score, in tier A, and when no single Core change is enough.
 */
export function engineWhatIf(result: HesResult): EngineWhatIf | null {
  if (!isScored(result) || nextTierOf(result.tier).length === 0) {
    return null;
  }
  const threshold = result.tier === TIER_B ? HES_TIER_A_MIN : HES_TIER_B_MIN;
  let best: EngineWhatIf | null = null;
  let restingHeartRate: EngineWhatIf | null = null;
  for (let i = 0; i < ROW_ORDER.length; i++) {
    const c = findComponent(result, ROW_ORDER[i]);
    if (c === null || !c.requiredCore || !c.available) {
      continue;
    }
    const rawValue = c.rawValue;
    const score = c.score;
    if (rawValue === undefined || score === undefined) {
      continue;
    }
    const change = firstCrossing(result, c, rawValue, score, threshold);
    if (change === null) {
      continue;
    }
    if (c.id === HesComponentId.RHR) {
      restingHeartRate = change;
    } else if (best === null || relativeChange(change) < relativeChange(best)) {
      best = change;
    }
  }
  return best !== null ? best : restingHeartRate;
}

// ---------------------------------------------------------------------------------------------------------
// Public entry points
// ---------------------------------------------------------------------------------------------------------

/** The six personas, in the order the demo lists them. */
export function enginePersonas(): PersonaRef[] {
  const out: PersonaRef[] = [];
  for (let i = 0; i < HesPersonas.IDS.length; i++) {
    out.push({ id: HesPersonas.IDS[i], name: HesPersonas.displayName(HesPersonas.IDS[i]) });
  }
  return out;
}

/**
 * A demo session of a persona: live values, close the day, reset. An unknown id gives the default one.
 * `scopes` are the data types the person agreed to: the readings of every other type are absent in the
 * starting history, in the running day, and so in each day that is closed later. With no argument every
 * type is used.
 */
export function engineSession(id: string, scopes: HealthScope[] = ALL_HEALTH_SCOPES): HesSession {
  return new HesSession(snapshotWithScopes(HesPersonas.snapshot(knownId(id)), scopes));
}

/**
 * The report of a persona as its session stands now, in a profile. The live heart rate and today's steps
 * are in `live` and nowhere else; after `closeDay()` the score, the components and the bars are those of
 * the session. Without a profile the report is in the partner's profile: the one that is shared.
 */
export function engineReportOf(id: string, session: HesSession,
  profile: HesProfile = PARTNER_HES_PROFILE): PersonaReport {
  const known = knownId(id);
  return build(known, session.current(profile), session.current(PARTNER_HES_PROFILE), session.history(),
    wearMonthOf(known), session.liveHeartRate(), session.liveSteps());
}

let cacheProfiles: HesProfile[] = [];
let caches: PersonaReport[][] = [];

/** The six reports for the personas' starting histories in a profile, with today's steps as the source has them. Built once. */
export function engineReports(profile: HesProfile = PARTNER_HES_PROFILE): PersonaReport[] {
  const at = cacheProfiles.indexOf(profile);
  if (at >= 0) {
    return caches[at];
  }
  const out: PersonaReport[] = [];
  for (let i = 0; i < HesPersonas.IDS.length; i++) {
    const id = HesPersonas.IDS[i];
    out.push(engineReportOf(id, HesPersonas.session(id), profile));
  }
  cacheProfiles.push(profile);
  caches.push(out);
  return out;
}

// ---------------------------------------------------------------------------------------------------------
// Reports from a history that came from Health Sim
// ---------------------------------------------------------------------------------------------------------

/**
 * A demo session that starts from what Health Sim sent for this person: the completed days, the estimates,
 * the sessions and the running day. Closing a day closes that running day. `scopes` are applied as in
 * `engineSession`.
 */
export function engineSessionFrom(person: HealthSimPerson, scopes: HealthScope[] = ALL_HEALTH_SCOPES): HesSession {
  return new HesSession(snapshotWithScopes(healthSimSnapshot(person), scopes));
}

/** The wear month of the days Health Sim sent, under the default thresholds, with no sick days. */
export function wearMonthFrom(person: HealthSimPerson): WearMonthResult {
  return buildWearMonth(person.wear, DEFAULT_THRESHOLDS, []);
}

/** The report of a person whose data came from Health Sim, as the session stands now, in a profile. */
export function engineReportFromPerson(person: HealthSimPerson, session: HesSession,
  profile: HesProfile = PARTNER_HES_PROFILE): PersonaReport {
  return build(knownId(person.id), session.current(profile), session.current(PARTNER_HES_PROFILE),
    session.history(), wearMonthFrom(person), session.liveHeartRate(), session.liveSteps(), HEALTH_SIM_LABEL);
}

/** The report of one persona in a profile. An unknown id gives the default persona; it never throws. */
export function engineReport(id: string, profile: HesProfile = PARTNER_HES_PROFILE): PersonaReport {
  const all = engineReports(profile);
  const known = knownId(id);
  for (let i = 0; i < all.length; i++) {
    if (all[i].id === known) {
      return all[i];
    }
  }
  return all[0];
}

// ---------------------------------------------------------------------------------------------------------
// Day details
// ---------------------------------------------------------------------------------------------------------

/** One break of a day: an off-wrist stretch, not on the charger, of at least `gapMinMinutes`. */
export interface DayBreak {
  startMin: number;             // local minute of the day the break started, 0..1439
  minutes: number;              // length of the break
  judged: boolean;              // enough heart-rate readings in the 24 h before it
  suspicious: boolean;
  restDeltaBpm: number;         // resting heart rate in the 24 h before, minus the person's baseline
  stepsRatio: number;           // steps in the 24 h before / the person's usual steps (1.0 = as usual)
  hrReadings24hBefore: number;  // heart-rate readings in the 24 h before the break
}

/** One day of the wear month, with the reason it counts the way it does as ready text. */
export interface DayDetail {
  n: number;                    // 1 is the first day of the period
  date: string;                 // local calendar day, YYYY-MM-DD
  state: string;                // DayState
  wornMin: number;              // minutes on the wrist; 0 on a day the watch did not observe
  chargingMin: number;          // minutes on the charger
  nightWorn: boolean;           // the night counts
  breaks: DayBreak[];
  reason: string;               // one line for the screen; the screens do not work reasons out themselves
}

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

// 785 -> "13:05".
function clockText(minuteOfDay: number): string {
  const total = Math.max(0, Math.min(MINUTES_PER_DAY, hesRound(minuteOfDay)));
  return `${pad2(Math.floor(total / MINUTES_PER_HOUR))}:${pad2(total % MINUTES_PER_HOUR)}`;
}

// 335 -> "5 h 35 min", 300 -> "5 h", 40 -> "40 min".
function minutesText(minutes: number): string {
  const total = Math.max(0, hesRound(minutes));
  const h = Math.floor(total / MINUTES_PER_HOUR);
  const m = total % MINUTES_PER_HOUR;
  if (h === 0) {
    return `${m} min`;
  }
  return m === 0 ? `${h} h` : `${h} h ${m} min`;
}

// 9 -> "+9", -1 -> "−1", 0 -> "+0".
function signedBpm(delta: number): string {
  return delta < 0 ? `−${-delta}` : `+${delta}`;
}

// "Off the wrist 13:05 for 5 h 35 min after resting HR +9 bpm and 46% fewer steps in the 24 h before".
function suspiciousText(gap: WearBreakResult): string {
  const when = gap.startMin <= 0 && gap.minutes >= MINUTES_PER_DAY ? 'all day' :
    `${clockText(gap.startMin)} for ${minutesText(gap.minutes)}`;
  const fewer = hesRound((1 - gap.stepsRatio) * PERCENT);
  return `Off the wrist ${when} after resting HR ${signedBpm(gap.restDeltaBpm)} bpm and ${fewer}% fewer ` +
    'steps in the 24 h before';
}

function capitalised(text: string): string {
  return text.length === 0 ? text : text.charAt(0).toUpperCase() + text.substring(1);
}

// Why an observed day without a suspicious break is not compliant: the hours, the night, or both; then the
// breaks that could not be judged.
function shortText(day: WearDayResult, th: Thresholds): string {
  const parts: string[] = [];
  if (day.wornMin <= 0) {
    parts.push('not worn this day');
  } else {
    if (day.countedMin < th.minDailyHours * MINUTES_PER_HOUR) {
      const credit = day.countedMin - day.wornMin;
      parts.push(`worn ${minutesText(day.wornMin)} of ${th.minDailyHours} h` +
        (credit > 0 ? ` (plus ${minutesText(credit)} of charging counted)` : ''));
    }
    if (th.nightRequired && !day.nightWorn) {
      parts.push(`night not worn (${minutesText(day.nightWornMin)} of ${minutesText(th.nightMinWornMin)} ` +
        'between 00:00 and 06:00)');
    }
  }
  for (let i = 0; i < day.breaks.length; i++) {
    const gap = day.breaks[i];
    if (gap.counted && !gap.judged) {
      parts.push(`break not judged (${gap.hrReadings24hBefore} heart-rate readings before it, ` +
        `${th.minHrReadingsBeforeGap} needed)`);
    }
  }
  return capitalised(parts.join('; '));
}

function reasonOf(day: WearDayResult, th: Thresholds): string {
  if (day.state === WearDayState.UNKNOWN) {
    return 'No record from the watch for this day';
  }
  if (day.state === WearDayState.SICK) {
    return 'Sick day, left out of the month';
  }
  if (day.state === WearDayState.SUSPICIOUS) {
    const parts: string[] = [];
    for (let i = 0; i < day.breaks.length; i++) {
      if (day.breaks[i].suspicious) {
        parts.push(suspiciousText(day.breaks[i]));
      }
    }
    return parts.join('; ');
  }
  if (day.state === WearDayState.COMPLIANT) {
    return `Worn ${minutesText(day.wornMin)}, the night counts`;
  }
  return shortText(day, th);
}

/** The details of one day of a wear month. `n` is the day's place in the period, 1 for the first day. */
export function dayDetailOf(day: WearDayResult, n: number, th: Thresholds): DayDetail {
  const breaks: DayBreak[] = [];
  for (let i = 0; i < day.breaks.length; i++) {
    const gap = day.breaks[i];
    if (gap.counted) {
      breaks.push({
        startMin: gap.startMin,
        minutes: gap.minutes,
        judged: gap.judged,
        suspicious: gap.suspicious,
        restDeltaBpm: gap.restDeltaBpm,
        stepsRatio: gap.stepsRatio,
        hrReadings24hBefore: gap.hrReadings24hBefore
      });
    }
  }
  return {
    n: n,
    date: day.date,
    state: day.state,
    wornMin: day.wornMin,
    chargingMin: day.chargingMin,
    nightWorn: day.nightWorn,
    breaks: breaks,
    reason: reasonOf(day, th)
  };
}

/**
 * The 30 days of a persona's wear month, oldest first: `engineDayDetails(id)[n - 1]` is day `n` of
 * `PersonaReport.wear.days`. An unknown id gives the default persona; it never throws.
 */
export function engineDayDetails(id: string): DayDetail[] {
  const month = wearMonthOf(knownId(id));
  const out: DayDetail[] = [];
  for (let i = 0; i < month.days.length; i++) {
    out.push(dayDetailOf(month.days[i], i + 1, DEFAULT_THRESHOLDS));
  }
  return out;
}

/** The 30 days of the wear month Health Sim sent for this person, oldest first. */
export function engineDayDetailsFrom(person: HealthSimPerson): DayDetail[] {
  const month = wearMonthFrom(person);
  const out: DayDetail[] = [];
  for (let i = 0; i < month.days.length; i++) {
    out.push(dayDetailOf(month.days[i], i + 1, DEFAULT_THRESHOLDS));
  }
  return out;
}
