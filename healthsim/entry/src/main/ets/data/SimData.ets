import { HealthScope } from '../fw/health/HealthConnection';
import { HES_MISSING, HesDay } from '../fw/hes/HesTypes';
import { HesPersonas } from '../fw/hes/HesPersonas';
import { WearDayRecord } from '../fw/wear/WearMonth';
import { WearPersonas } from '../fw/wear/WearPersonas';

/*
 * What the Health Sim screens show: the people of the simulation and their days, read from the same
 * persona generator FairWear uses (the files under ../fw are copies of FairWear's `common`).
 * Nothing is calculated here beyond picking days and writing numbers as text.
 */

export const HISTORY_DAYS: number = 30;
/** A value that was not measured. Shown instead of a number, never as zero. */
export const NO_VALUE: string = '—';

const MINUTES_PER_HOUR: number = 60;
const WEEKDAYS: string[] = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MONTHS: string[] = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/** One person of the simulation, as the picker lists them. */
export interface SimPerson {
  id: string;
  name: string;
}

/** One day as a row of the history list: every value already written as text. */
export interface SimDayRow {
  date: string;        // "2026-10-03"
  title: string;       // "Sat 3 Oct"
  steps: string;
  restingHr: string;
  sleep: string;
  active: string;
  worn: string;
  stepsShare: number;  // 0..100, the day's steps against the highest day of the list; 0 when not measured
}

export function simPeople(): SimPerson[] {
  const out: SimPerson[] = [];
  for (let i = 0; i < HesPersonas.IDS.length; i++) {
    out.push({ id: HesPersonas.IDS[i], name: HesPersonas.displayName(HesPersonas.IDS[i]) });
  }
  return out;
}

export function simPersonName(id: string): string {
  return HesPersonas.displayName(id);
}

function missing(value: number): boolean {
  return value === HES_MISSING || value < 0;
}

/** 5843 -> "5,843". */
export function grouped(n: number): string {
  let text = `${Math.floor(n)}`;
  let out = '';
  while (text.length > 3) {
    out = `,${text.substring(text.length - 3)}${out}`;
    text = text.substring(0, text.length - 3);
  }
  return text + out;
}

/** 448 -> "7 h 28 min". */
export function hoursMinutes(minutes: number): string {
  const total = Math.max(0, Math.round(minutes));
  const h = Math.floor(total / MINUTES_PER_HOUR);
  const m = total % MINUTES_PER_HOUR;
  if (h === 0) {
    return `${m} min`;
  }
  return m === 0 ? `${h} h` : `${h} h ${m} min`;
}

/** "2026-10-03" -> "Sat 3 Oct". Text that is not a date is returned as it is. */
export function dayTitle(date: string): string {
  if (date.length < 10) {
    return date;
  }
  const ms = Date.UTC(Number(date.substring(0, 4)), Number(date.substring(5, 7)) - 1,
    Number(date.substring(8, 10)));
  if (isNaN(ms)) {
    return date;
  }
  const d = new Date(ms);
  return `${WEEKDAYS[d.getUTCDay()]} ${d.getUTCDate()} ${MONTHS[d.getUTCMonth()]}`;
}

export function stepsText(day: HesDay): string {
  return missing(day.steps) ? NO_VALUE : grouped(day.steps);
}

export function restingHrText(day: HesDay): string {
  return missing(day.restingHeartRate) ? NO_VALUE : `${Math.round(day.restingHeartRate)}`;
}

export function sleepText(day: HesDay): string {
  return missing(day.sleepMinutes) ? NO_VALUE : hoursMinutes(day.sleepMinutes);
}

/** Moderate plus vigorous minutes; missing only when both are missing. */
export function activeText(day: HesDay): string {
  if (missing(day.moderateMinutes) && missing(day.vigorousMinutes)) {
    return NO_VALUE;
  }
  return `${Math.max(0, day.moderateMinutes) + Math.max(0, day.vigorousMinutes)}`;
}

export function wornText(record: WearDayRecord | null): string {
  if (record === null || !record.observed) {
    return NO_VALUE;
  }
  return hoursMinutes(record.wornMin);
}

function wearOf(records: WearDayRecord[], date: string): WearDayRecord | null {
  for (let i = 0; i < records.length; i++) {
    if (records[i].date === date) {
      return records[i];
    }
  }
  return null;
}

/** The last `HISTORY_DAYS` days of a person, newest first. An unknown id gives an empty list. */
export function simHistory(id: string): SimDayRow[] {
  const days: HesDay[] = HesPersonas.history(id);
  const wear: WearDayRecord[] = WearPersonas.month(id);
  const first = Math.max(0, days.length - HISTORY_DAYS);
  let top = 0;
  for (let i = first; i < days.length; i++) {
    if (!missing(days[i].steps) && days[i].steps > top) {
      top = days[i].steps;
    }
  }
  const out: SimDayRow[] = [];
  for (let i = days.length - 1; i >= first; i--) {
    const day = days[i];
    out.push({
      date: day.date,
      title: dayTitle(day.date),
      steps: stepsText(day),
      restingHr: restingHrText(day),
      sleep: sleepText(day),
      active: activeText(day),
      worn: wornText(wearOf(wear, day.date)),
      stepsShare: missing(day.steps) || top === 0 ? 0 : Math.round(day.steps * 100 / top)
    });
  }
  return out;
}

/** The newest day of a person; null for an unknown id. */
export function simToday(id: string): SimDayRow | null {
  const rows = simHistory(id);
  return rows.length > 0 ? rows[0] : null;
}

/** The readable name of a data type FairWear can ask for. Empty for a name Health Sim does not know. */
export function scopeLabel(scope: string): string {
  if (scope === HealthScope.STEPS) {
    return 'Steps';
  }
  if (scope === HealthScope.RESTING_HEART_RATE) {
    return 'Resting heart rate';
  }
  if (scope === HealthScope.SLEEP) {
    return 'Sleep';
  }
  if (scope === HealthScope.ACTIVITY_MINUTES) {
    return 'Activity minutes';
  }
  if (scope === HealthScope.VO2MAX) {
    return 'VO₂max';
  }
  if (scope === HealthScope.HRV) {
    return 'Heart rate variability';
  }
  if (scope === HealthScope.WORKOUTS) {
    return 'Workouts (heart-rate recovery)';
  }
  return '';
}

/** The scope behind a name from a request; null for a name Health Sim does not know. */
export function scopeOf(name: string): HealthScope | null {
  const all: HealthScope[] = [HealthScope.STEPS, HealthScope.RESTING_HEART_RATE, HealthScope.SLEEP,
    HealthScope.ACTIVITY_MINUTES, HealthScope.VO2MAX, HealthScope.HRV, HealthScope.WORKOUTS];
  for (let i = 0; i < all.length; i++) {
    if (all[i] === name) {
      return all[i];
    }
  }
  return null;
}
