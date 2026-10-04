// Wear month: compliance, breaks and the selective non-wear flag over a month of wear records.
// Deterministic rules over counted days and breaks; the thresholds come from DEFAULT_THRESHOLDS and are
// prototype product assumptions. Pure logic: no system-kit imports.
//
// Rules (the team's plan, appendix B, and the thresholds in model/defaults.ets):
//   - a day is compliant when the watch was worn at least `minDailyHours`, with charging time counted up to
//     `maxChargingCountedMin`, and (when `nightRequired`) the night counts;
//   - the night counts when the watch was worn at least `nightMinWornMin` between 00:00 and 06:00;
//   - a break is an off-wrist stretch of at least `gapMinMinutes`;
//   - a break is judged only with at least `minHrReadingsBeforeGap` heart-rate readings in the 24 h before
//     it; a break that is not judged is never suspicious;
//   - a judged break is suspicious when the resting heart rate in the 24 h before it was at least
//     `restDeltaBpm` above the baseline AND the steps in the 24 h before it were below `stepsDropRatio` of
//     the usual;
//   - the flag is isSelectiveNonWear(suspicious breaks, all breaks): one suspicious break never flags;
//   - charging time never hides a break: the charging credit only counts towards the worn hours.
//
// Decisions where the plan is silent:
//   - a day the watch did not observe is UNKNOWN: it has no breaks and it is not compliant, and it stays in
//     the total (an unobserved day is never evidence of wear);
//   - a sick day is left out of the total, and its breaks are neither counted nor judged; at most
//     `maxPauseDaysPer30` sick days are honoured, the earliest ones;
//   - a day with a suspicious break is shown as SUSPICIOUS even if its hours would make it compliant;
//   - "red days" are the days that fail compliance: SHORT and SUSPICIOUS that are not compliant.
import { Thresholds } from '../model/types';
import { isSelectiveNonWear } from '../rules/SelectiveNonWear';

const MINUTES_PER_HOUR: number = 60;
const PERCENT: number = 100;

export enum WearDayState {
  COMPLIANT = 'COMPLIANT',
  SHORT = 'SHORT',
  SUSPICIOUS = 'SUSPICIOUS',
  SICK = 'SICK',
  UNKNOWN = 'UNKNOWN'
}

/** One off-wrist stretch (not on the charger) with what the watch saw in the 24 h before it. */
export interface WearBreak {
  startMin: number;             // local minute of the day the break started, 0..1439
  minutes: number;              // length of the break
  hrReadings24hBefore: number;  // heart-rate readings in the 24 h before the break
  restDeltaBpm: number;         // resting heart rate in the 24 h before, minus the person's baseline
  stepsRatio: number;           // steps in the 24 h before / the person's usual steps (1.0 = as usual)
}

/** One day as the watch recorded it. */
export interface WearDayRecord {
  date: string;                 // local calendar day, YYYY-MM-DD
  observed: boolean;            // false: the watch has no record of this day
  wornMin: number;              // minutes on the wrist
  nightWornMin: number;         // minutes on the wrist between 00:00 and 06:00
  chargingMin: number;          // minutes on the charger
  breaks: WearBreak[];
}

export interface WearBreakResult {
  startMin: number;
  minutes: number;
  hrReadings24hBefore: number;
  restDeltaBpm: number;
  stepsRatio: number;
  counted: boolean;             // long enough to be a break at all
  judged: boolean;              // counted and enough heart-rate readings before it
  suspicious: boolean;
}

export interface WearDayResult {
  date: string;
  state: WearDayState;
  compliant: boolean;
  wornMin: number;
  chargingMin: number;
  countedMin: number;           // worn minutes plus the charging credit
  nightWornMin: number;
  nightWorn: boolean;
  breaks: WearBreakResult[];
}

export interface WearMonthResult {
  period: string;               // first and last day, e.g. 2026-09-04..2026-10-03
  compliantDays: number;
  totalDays: number;            // days of the month without the sick days
  pct: number;                  // compliantDays / totalDays, percent with one decimal
  passes: boolean;              // pct >= minMonthlyPct
  nightsWorn: number;
  totalBreaks: number;          // breaks of at least gapMinMinutes
  judgedBreaks: number;
  suspiciousBreaks: number;
  flagged: boolean;             // selective non-wear
  eligible: boolean;            // passes and not flagged
  redDays: number;              // observed days that fail compliance
  sickDays: number;
  unknownDays: number;
  days: WearDayResult[];
}

/** The night counts when worn at least `nightMinWornMin` (4 h) between 00:00 and 06:00. */
export function isNightWorn(nightWornMin: number, th: Thresholds): boolean {
  return nightWornMin >= th.nightMinWornMin;
}

/** Worn minutes plus the charging credit. Charging beyond the limit does not count. */
export function countedWearMinutes(wornMin: number, chargingMin: number, th: Thresholds): number {
  return Math.max(0, wornMin) + Math.min(Math.max(0, chargingMin), th.maxChargingCountedMin);
}

export function isDayCompliant(record: WearDayRecord, th: Thresholds): boolean {
  if (!record.observed) {
    return false;
  }
  // A minute count that is not a number never makes a day compliant (NaN < limit would be false).
  if (!Number.isFinite(record.wornMin) || !Number.isFinite(record.chargingMin) ||
    !Number.isFinite(record.nightWornMin)) {
    return false;
  }
  if (countedWearMinutes(record.wornMin, record.chargingMin, th) < th.minDailyHours * MINUTES_PER_HOUR) {
    return false;
  }
  return !th.nightRequired || isNightWorn(record.nightWornMin, th);
}

/** Judges one break. Charging time is not an input: it can never hide a break. */
export function judgeBreak(gap: WearBreak, th: Thresholds): WearBreakResult {
  const counted = gap.minutes >= th.gapMinMinutes;
  const judged = counted && gap.hrReadings24hBefore >= th.minHrReadingsBeforeGap;
  const suspicious = judged && gap.restDeltaBpm >= th.restDeltaBpm && gap.stepsRatio < th.stepsDropRatio;
  return {
    startMin: gap.startMin,
    minutes: gap.minutes,
    hrReadings24hBefore: gap.hrReadings24hBefore,
    restDeltaBpm: gap.restDeltaBpm,
    stepsRatio: gap.stepsRatio,
    counted: counted,
    judged: judged,
    suspicious: suspicious
  };
}

function honouredSickDays(sickDayIndexes: number[], dayCount: number, th: Thresholds): number[] {
  const sorted = sickDayIndexes.slice().sort((a: number, b: number): number => a - b);
  const out: number[] = [];
  for (let i = 0; i < sorted.length && out.length < th.maxPauseDaysPer30; i++) {
    if (sorted[i] >= 0 && sorted[i] < dayCount && out.indexOf(sorted[i]) < 0) {
      out.push(sorted[i]);
    }
  }
  return out;
}

function roundToTenth(value: number): number {
  return Math.round(value * 10) / 10;
}

/**
 * The month for a list of day records, oldest first. `sickDayIndexes` are positions in `records` the user
 * marked as sick days (they never leave the phone).
 */
export function buildWearMonth(records: WearDayRecord[], th: Thresholds, sickDayIndexes: number[]): WearMonthResult {
  const sick = honouredSickDays(sickDayIndexes, records.length, th);
  const days: WearDayResult[] = [];
  let compliantDays = 0;
  let nightsWorn = 0;
  let totalBreaks = 0;
  let judgedBreaks = 0;
  let suspiciousBreaks = 0;
  let redDays = 0;
  let unknownDays = 0;

  for (let i = 0; i < records.length; i++) {
    const record = records[i];
    const isSick = sick.indexOf(i) >= 0;
    const nightWorn = record.observed && isNightWorn(record.nightWornMin, th);
    const compliant = isDayCompliant(record, th);
    const breaks: WearBreakResult[] = [];
    let daySuspicious = false;
    if (record.observed && !isSick) {
      for (let b = 0; b < record.breaks.length; b++) {
        const verdict = judgeBreak(record.breaks[b], th);
        breaks.push(verdict);
        if (verdict.counted) {
          totalBreaks++;
        }
        if (verdict.judged) {
          judgedBreaks++;
        }
        if (verdict.suspicious) {
          suspiciousBreaks++;
          daySuspicious = true;
        }
      }
    }

    let state: WearDayState = WearDayState.SHORT;
    if (isSick) {
      state = WearDayState.SICK;
    } else if (!record.observed) {
      state = WearDayState.UNKNOWN;
      unknownDays++;
    } else if (daySuspicious) {
      state = WearDayState.SUSPICIOUS;
    } else if (compliant) {
      state = WearDayState.COMPLIANT;
    }

    if (!isSick) {
      if (compliant) {
        compliantDays++;
      } else if (record.observed) {
        redDays++;
      }
      if (nightWorn) {
        nightsWorn++;
      }
    }
    days.push({
      date: record.date,
      state: state,
      compliant: compliant && !isSick,
      wornMin: record.observed ? record.wornMin : 0,
      chargingMin: record.observed ? record.chargingMin : 0,
      countedMin: record.observed ? countedWearMinutes(record.wornMin, record.chargingMin, th) : 0,
      nightWornMin: record.observed ? record.nightWornMin : 0,
      nightWorn: nightWorn,
      breaks: breaks
    });
  }

  const totalDays = records.length - sick.length;
  const pct = totalDays > 0 ? roundToTenth(compliantDays * PERCENT / totalDays) : 0;
  const passes = totalDays > 0 && compliantDays * PERCENT >= th.minMonthlyPct * totalDays;
  const flagged = isSelectiveNonWear(suspiciousBreaks, totalBreaks, th);
  return {
    period: records.length > 0 ? records[0].date + '..' + records[records.length - 1].date : '',
    compliantDays: compliantDays,
    totalDays: totalDays,
    pct: pct,
    passes: passes,
    nightsWorn: nightsWorn,
    totalBreaks: totalBreaks,
    judgedBreaks: judgedBreaks,
    suspiciousBreaks: suspiciousBreaks,
    flagged: flagged,
    eligible: passes && !flagged,
    redDays: redDays,
    sickDays: sick.length,
    unknownDays: unknownDays,
    days: days
  };
}
