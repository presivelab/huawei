import { Thresholds } from '../model/types';
import { DayCell, DayState, PersonaReport } from './ReportModels';
import { periodDayIso } from './ReportDates';

/*
 * The month of a report as a calendar, and the appeals a person has sent from it. Pure logic for the
 * Evidence tab: where each day sits in a Monday-first grid, how minutes read, which days can be appealed.
 *
 * An appeal is a note kept on this phone. It never changes a day, the score or the benefit.
 */

const WEEK: number = 7;
const MINUTES_PER_HOUR: number = 60;
const PERCENT: number = 100;

/** The column headers of the calendar, Monday first. */
export const CALENDAR_WEEKDAYS: string[] = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

/** One cell of the calendar grid. `n` is 0 for an empty cell before the first or after the last day. */
export interface CalendarCell {
  n: number;             // day of the period, 1 is the first; 0 for an empty cell
  date: string;          // "2026-09-17"; empty for an empty cell
  label: string;         // day of the month as shown, "17"; empty for an empty cell
  state: string;         // DayState; empty for an empty cell
}

function emptyCell(): CalendarCell {
  return { n: 0, date: '', label: '', state: '' };
}

// Monday = 0 ... Sunday = 6. -1 when the text is not a date.
function mondayIndex(date: string): number {
  if (date.length < 10) {
    return -1;
  }
  const ms = Date.UTC(Number(date.substring(0, 4)), Number(date.substring(5, 7)) - 1,
    Number(date.substring(8, 10)));
  if (isNaN(ms)) {
    return -1;
  }
  return (new Date(ms).getUTCDay() + WEEK - 1) % WEEK;
}

/**
 * The days of the period laid out in whole weeks, Monday first: empty cells before the first day and
 * after the last one. When the period is not a date the days start in the first column.
 */
export function calendarCells(report: PersonaReport): CalendarCell[] {
  const days: DayCell[] = report.wear.days;
  const out: CalendarCell[] = [];
  if (days.length === 0) {
    return out;
  }
  const lead = Math.max(0, mondayIndex(periodDayIso(report.periodIso, days[0].n)));
  for (let i = 0; i < lead; i++) {
    out.push(emptyCell());
  }
  for (let i = 0; i < days.length; i++) {
    const date = periodDayIso(report.periodIso, days[i].n);
    out.push({
      n: days[i].n,
      date: date,
      label: date.length >= 10 ? `${Number(date.substring(8, 10))}` : `${days[i].n}`,
      state: days[i].state
    });
  }
  while (out.length % WEEK !== 0) {
    out.push(emptyCell());
  }
  return out;
}

/** How many days of the period are in one state. */
export function daysInState(report: PersonaReport, state: string): number {
  let n = 0;
  for (let i = 0; i < report.wear.days.length; i++) {
    if (report.wear.days[i].state === state) {
      n++;
    }
  }
  return n;
}

/** Observed days that fail the wear rule: short days and days with a suspicious break. */
export function redDays(report: PersonaReport): number {
  return daysInState(report, DayState.SHORT) + daysInState(report, DayState.SUSPICIOUS);
}

/** A person can appeal a day that counts against them, and no other. */
export function canAppeal(state: string): boolean {
  return state === DayState.SHORT || state === DayState.SUSPICIOUS;
}

/** The key of one appeal: the persona and the calendar day, so it stays on its day when days move. */
export function appealKey(personaId: string, date: string): string {
  return `${personaId}|${date}`;
}

export function isAppealed(appeals: string[], personaId: string, date: string): boolean {
  return date.length > 0 && appeals.indexOf(appealKey(personaId, date)) >= 0;
}

/** The list with one more appeal. A day is appealed once; the given list is not changed. */
export function withAppeal(appeals: string[], personaId: string, date: string): string[] {
  const out: string[] = appeals.slice();
  if (date.length > 0 && !isAppealed(appeals, personaId, date)) {
    out.push(appealKey(personaId, date));
  }
  return out;
}

/** The list without the appeals of one persona (demo reset). The given list is not changed. */
export function withoutAppealsOf(appeals: string[], personaId: string): string[] {
  const prefix = `${personaId}|`;
  const out: string[] = [];
  for (let i = 0; i < appeals.length; i++) {
    if (appeals[i].indexOf(prefix) !== 0) {
      out.push(appeals[i]);
    }
  }
  return out;
}

/** How many days of this report carry an appeal. */
export function appealsIn(report: PersonaReport, appeals: string[]): number {
  let n = 0;
  for (let i = 0; i < report.wear.days.length; i++) {
    if (isAppealed(appeals, report.id, periodDayIso(report.periodIso, report.wear.days[i].n))) {
      n++;
    }
  }
  return n;
}

/** 860 -> "14 h 20 min", 40 -> "40 min", 120 -> "2 h". Never negative. */
export function minutesText(minutes: number): string {
  const total = Math.max(0, Math.round(minutes));
  const h = Math.floor(total / MINUTES_PER_HOUR);
  const m = total % MINUTES_PER_HOUR;
  if (h === 0) {
    return `${m} min`;
  }
  return m === 0 ? `${h} h` : `${h} h ${m} min`;
}

/** Minute of the day as a clock time: 785 -> "13:05". */
export function clockText(minuteOfDay: number): string {
  const total = Math.min(Math.max(0, Math.round(minuteOfDay)), 24 * MINUTES_PER_HOUR - 1);
  const h = Math.floor(total / MINUTES_PER_HOUR);
  const m = total % MINUTES_PER_HOUR;
  return `${h < 10 ? '0' : ''}${h}:${m < 10 ? '0' : ''}${m}`;
}

/** The flag rule in one sentence, with the numbers of the thresholds in force. */
export function flagRuleText(th: Thresholds): string {
  return `One break never flags. A flag needs ${th.minSuspicious} suspicious breaks, or ` +
    `${th.minSuspiciousForShare} that are more than ${Math.round(th.maxSuspiciousShare * PERCENT)}% ` +
    'of all breaks.';
}

/** What a screen reader says for a calendar day: the date, the state and the appeal, if one was sent. */
export function calendarDaySpoken(dateAndState: string, appealed: boolean): string {
  return appealed ? `${dateAndState}, appeal sent` : dateAndState;
}
