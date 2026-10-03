/*
 * Daty jako 'YYYY-MM-DD' w UTC, żeby wyniki nie zależały od strefy czasowej emulatora.
 */

const DAY_MS: number = 24 * 60 * 60 * 1000;

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

export function isoDate(d: Date): string {
  return `${d.getUTCFullYear()}-${pad2(d.getUTCMonth() + 1)}-${pad2(d.getUTCDate())}`;
}

export function parseIsoDate(iso: string): number {
  return Date.UTC(Number(iso.substring(0, 4)), Number(iso.substring(5, 7)) - 1, Number(iso.substring(8, 10)));
}

export function addDays(iso: string, n: number): string {
  return isoDate(new Date(parseIsoDate(iso) + n * DAY_MS));
}

export function daysBetween(fromIso: string, toIso: string): number {
  return Math.round((parseIsoDate(toIso) - parseIsoDate(fromIso)) / DAY_MS);
}

/** Wczoraj (UTC) - ostatni pełny dzień danych. */
export function yesterdayIso(nowMs: number): string {
  return isoDate(new Date(nowMs - DAY_MS));
}

/** '2026-09-07' -> '07.09' */
export function shortDate(iso: string): string {
  return `${iso.substring(8, 10)}.${iso.substring(5, 7)}`;
}

/** Znacznik czasu z dokładnością do sekundy, np. 2026-10-03T18:40:12Z (krócej = mniej znaków w QR). */
export function isoSeconds(ms: number): string {
  return new Date(ms).toISOString().substring(0, 19) + 'Z';
}
