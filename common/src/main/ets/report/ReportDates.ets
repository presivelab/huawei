import { dayStateLabel } from './ReportSpeech';

/*
 * Dates of the days of a report period. The period is written "2026-09-04..2026-10-03" (first and last
 * day); day 1 is the first day. Pure text and UTC arithmetic, so the result does not depend on the
 * time zone of the phone.
 */

const DAY_MS: number = 86400000;
const MONTHS_LONG: string[] = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
  'September', 'October', 'November', 'December'];

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

function startMs(periodIso: string): number {
  if (periodIso.length < 10) {
    return -1;
  }
  const year = Number(periodIso.substring(0, 4));
  const month = Number(periodIso.substring(5, 7));
  const day = Number(periodIso.substring(8, 10));
  if (isNaN(year) || isNaN(month) || isNaN(day) || periodIso.charAt(4) !== '-' || periodIso.charAt(7) !== '-' ||
    month < 1 || month > 12 || day < 1 || day > 31) {
    return -1;
  }
  return Date.UTC(year, month - 1, day);
}

/** The date of day `n` of the period as "2026-09-20". Empty when the period is not a date or n < 1. */
export function periodDayIso(periodIso: string, n: number): string {
  const start = startMs(periodIso);
  if (start < 0 || n < 1 || Math.floor(n) !== n) {
    return '';
  }
  const d = new Date(start + (n - 1) * DAY_MS);
  return `${d.getUTCFullYear()}-${pad2(d.getUTCMonth() + 1)}-${pad2(d.getUTCDate())}`;
}

/** What a screen reader says for one day: "20 September, suspicious break". */
export function periodDaySpoken(periodIso: string, n: number, state: string): string {
  const start = startMs(periodIso);
  const label = dayStateLabel(state).toLowerCase();
  if (start < 0 || n < 1 || Math.floor(n) !== n) {
    return `Day ${n}, ${label}`;
  }
  const d = new Date(start + (n - 1) * DAY_MS);
  return `${d.getUTCDate()} ${MONTHS_LONG[d.getUTCMonth()]}, ${label}`;
}
