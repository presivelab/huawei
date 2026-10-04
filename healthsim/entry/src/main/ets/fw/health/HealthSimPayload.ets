// What Health Sim hands to FairWear. Health Sim is the team's simulator app that stands in for HUAWEI Health
// on the emulators (bundle com.fairwear.healthsim). After the user allows it, Health Sim returns the health
// history of the six demo people as one JSON text in the result of startAbilityForResult, under the
// parameter `fwhs1`. Pure logic, no system kits.
//
// The same file is copied unchanged into the Health Sim app (healthsim/entry/src/main/ets/fw/health/), so
// both apps write and read the very same format; common/src/test/HealthSimCopies.test.ets keeps the copies
// identical.
//
// Format, version 1 (-1 = no value, as everywhere in the score):
//   {"v":1,"source":"Health Sim","end":"2026-10-03","people":[{"id":"ania","name":"Ania",
//     "days":[[date, steps, restingHeartRate, moderateMinutes, vigorousMinutes, sleepStartMin, sleepEndMin,
//              sleepMinutes, vo2maxPercentile, hrvPercentile, hrr1], ...],           oldest first
//     "wear":[[date, observed 0|1, wornMin, nightWornMin, chargingMin,
//              [[startMin, minutes, hrReadings24hBefore, restDeltaBpm, stepsRatio], ...]], ...]}, ...]}
// "days" are the completed days the score uses; "wear" is the wear month. Wear is not a HUAWEI Health data
// type: Health Sim derives it from the gaps in the heart-rate samples, as the real data would allow.
import { HES_PERSONA_END_DATE, HesPersonas } from '../hes/HesPersonas';
import { copyHesDay, HesDay, HES_MISSING } from '../hes/HesTypes';
import { asObject, parseJsonObject, readArray, readInt, readString } from '../watchlink/JsonRead';
import { dayNumberOfDate } from '../watchlink/WatchLinkTypes';
import { WearBreak, WearDayRecord } from '../wear/WearMonth';
import { WearPersonas } from '../wear/WearPersonas';
import { HealthScope } from './HealthConnection';

/** The Want parameter that carries the text. */
export const HEALTH_SIM_PARAM: string = 'fwhs1';
export const HEALTH_SIM_VERSION: number = 1;
export const HEALTH_SIM_SOURCE: string = 'Health Sim';
/** A longer text is refused without being parsed. Six people are about 30 000 characters. */
export const HEALTH_SIM_MAX_CHARS: number = 90000;

const DAY_FIELDS: number = 11;
const WEAR_FIELDS: number = 6;
const BREAK_FIELDS: number = 5;
const MAX_DAYS: number = 400;
const MAX_WEAR_DAYS: number = 62;
const MAX_BREAKS: number = 48;
const DATE_PATTERN: RegExp = new RegExp('^[0-9]{4}-[0-9]{2}-[0-9]{2}$');

/** One person's data as Health Sim holds it. */
export class HealthSimPerson {
  id: string = '';
  name: string = '';
  days: HesDay[] = [];
  wear: WearDayRecord[] = [];
}

/** Everything Health Sim sends in one answer. */
export class HealthSimPayload {
  v: number = HEALTH_SIM_VERSION;
  source: string = HEALTH_SIM_SOURCE;
  end: string = '';
  people: HealthSimPerson[] = [];
}

// ---------------------------------------------------------------------------------------------------------
// Writing
// ---------------------------------------------------------------------------------------------------------

function numText(n: number): string {
  return Number.isFinite(n) ? `${n}` : `${HES_MISSING}`;
}

function dayText(d: HesDay): string {
  return `[${JSON.stringify(d.date)},${numText(d.steps)},${numText(d.restingHeartRate)},` +
    `${numText(d.moderateMinutes)},${numText(d.vigorousMinutes)},${numText(d.sleepStartMin)},` +
    `${numText(d.sleepEndMin)},${numText(d.sleepMinutes)},${numText(d.vo2maxPercentile)},` +
    `${numText(d.hrvPercentile)},${numText(d.hrr1)}]`;
}

function breakText(b: WearBreak): string {
  return `[${numText(b.startMin)},${numText(b.minutes)},${numText(b.hrReadings24hBefore)},` +
    `${numText(b.restDeltaBpm)},${numText(b.stepsRatio)}]`;
}

function wearText(w: WearDayRecord): string {
  const breaks: string[] = [];
  for (let i = 0; i < w.breaks.length; i++) {
    breaks.push(breakText(w.breaks[i]));
  }
  return `[${JSON.stringify(w.date)},${w.observed ? 1 : 0},${numText(w.wornMin)},${numText(w.nightWornMin)},` +
    `${numText(w.chargingMin)},[${breaks.join(',')}]]`;
}

function personText(p: HealthSimPerson): string {
  const days: string[] = [];
  for (let i = 0; i < p.days.length; i++) {
    days.push(dayText(p.days[i]));
  }
  const wear: string[] = [];
  for (let i = 0; i < p.wear.length; i++) {
    wear.push(wearText(p.wear[i]));
  }
  return `{"id":${JSON.stringify(p.id)},"name":${JSON.stringify(p.name)},"days":[${days.join(',')}],` +
    `"wear":[${wear.join(',')}]}`;
}

/** The text Health Sim returns under HEALTH_SIM_PARAM. */
export function encodeHealthSimPayload(p: HealthSimPayload): string {
  const people: string[] = [];
  for (let i = 0; i < p.people.length; i++) {
    people.push(personText(p.people[i]));
  }
  return `{"v":${numText(p.v)},"source":${JSON.stringify(p.source)},"end":${JSON.stringify(p.end)},` +
    `"people":[${people.join(',')}]}`;
}

// ---------------------------------------------------------------------------------------------------------
// Reading: nothing that arrives from another app is trusted to have the right shape
// ---------------------------------------------------------------------------------------------------------

function isDate(v: Object): boolean {
  return typeof v === 'string' && DATE_PATTERN.test(v as string);
}

function finite(v: Object): number | null {
  if (typeof v !== 'number' || !Number.isFinite(v as number)) {
    return null;
  }
  return v as number;
}

function row(v: Object, length: number): Object[] | null {
  if (v === undefined || v === null || !Array.isArray(v)) {
    return null;
  }
  const a = v as Object[];
  return a.length === length ? a : null;
}

function readDay(v: Object): HesDay | null {
  const a = row(v, DAY_FIELDS);
  if (a === null || !isDate(a[0])) {
    return null;
  }
  const n: number[] = [];
  for (let i = 1; i < DAY_FIELDS; i++) {
    const x = finite(a[i]);
    if (x === null) {
      return null;
    }
    n.push(x);
  }
  return {
    date: a[0] as string,
    steps: n[0],
    restingHeartRate: n[1],
    moderateMinutes: n[2],
    vigorousMinutes: n[3],
    sleepStartMin: n[4],
    sleepEndMin: n[5],
    sleepMinutes: n[6],
    vo2maxPercentile: n[7],
    hrvPercentile: n[8],
    hrr1: n[9]
  };
}

function readBreak(v: Object): WearBreak | null {
  const a = row(v, BREAK_FIELDS);
  if (a === null) {
    return null;
  }
  const n: number[] = [];
  for (let i = 0; i < BREAK_FIELDS; i++) {
    const x = finite(a[i]);
    if (x === null) {
      return null;
    }
    n.push(x);
  }
  return { startMin: n[0], minutes: n[1], hrReadings24hBefore: n[2], restDeltaBpm: n[3], stepsRatio: n[4] };
}

function readWearDay(v: Object): WearDayRecord | null {
  const a = row(v, WEAR_FIELDS);
  if (a === null || !isDate(a[0])) {
    return null;
  }
  const observed = finite(a[1]);
  const worn = finite(a[2]);
  const night = finite(a[3]);
  const charging = finite(a[4]);
  if (observed === null || (observed !== 0 && observed !== 1) || worn === null || night === null ||
    charging === null) {
    return null;
  }
  const rawBreaks: Object = a[5];
  if (rawBreaks === undefined || rawBreaks === null || !Array.isArray(rawBreaks)) {
    return null;
  }
  const list = rawBreaks as Object[];
  if (list.length > MAX_BREAKS) {
    return null;
  }
  const breaks: WearBreak[] = [];
  for (let i = 0; i < list.length; i++) {
    const b = readBreak(list[i]);
    if (b === null) {
      return null;
    }
    breaks.push(b);
  }
  return {
    date: a[0] as string,
    observed: observed === 1,
    wornMin: worn,
    nightWornMin: night,
    chargingMin: charging,
    breaks: breaks
  };
}

// The score's windows count list entries, not dates (HES.md decision 10), so a history has to be one entry
// per calendar day: real dates, oldest first, no day skipped or repeated, the last one on the end date.
// Otherwise a history with every other day missing would put 56 days into a "28-day" window.
function isDailyRun(dates: string[], end: string): boolean {
  if (dates.length === 0) {
    return true;
  }
  const endDay = dayNumberOfDate(end);
  if (endDay < 0) {
    return false;
  }
  const first = endDay - dates.length + 1;
  for (let i = 0; i < dates.length; i++) {
    if (dayNumberOfDate(dates[i]) !== first + i) {
      return false;
    }
  }
  return true;
}

function readPerson(v: Object, end: string): HealthSimPerson | null {
  const o = asObject(v);
  if (o === null) {
    return null;
  }
  const id = readString(o, 'id');
  const name = readString(o, 'name');
  const days = readArray(o, 'days');
  const wear = readArray(o, 'wear');
  if (id === null || !HesPersonas.has(id) || name === null || days === null || wear === null ||
    days.length > MAX_DAYS || wear.length > MAX_WEAR_DAYS) {
    return null;
  }
  const p = new HealthSimPerson();
  p.id = id;
  p.name = name;
  for (let i = 0; i < days.length; i++) {
    const d = readDay(days[i]);
    if (d === null) {
      return null;
    }
    p.days.push(d);
  }
  for (let i = 0; i < wear.length; i++) {
    const w = readWearDay(wear[i]);
    if (w === null) {
      return null;
    }
    p.wear.push(w);
  }
  const dayDates: string[] = [];
  for (let i = 0; i < p.days.length; i++) {
    dayDates.push(p.days[i].date);
  }
  const wearDates: string[] = [];
  for (let i = 0; i < p.wear.length; i++) {
    wearDates.push(p.wear[i].date);
  }
  if (!isDailyRun(dayDates, end) || !isDailyRun(wearDates, end)) {
    return null;
  }
  return p;
}

/** The payload, or null for anything that is not a valid version-1 text. Never throws. */
export function decodeHealthSimPayload(text: string): HealthSimPayload | null {
  if (text.length === 0 || text.length > HEALTH_SIM_MAX_CHARS) {
    return null;
  }
  const o = parseJsonObject(text);
  if (o === null) {
    return null;
  }
  const v = readInt(o, 'v');
  const source = readString(o, 'source');
  const end = readString(o, 'end');
  const people = readArray(o, 'people');
  if (v !== HEALTH_SIM_VERSION || source === null || end === null || !DATE_PATTERN.test(end) ||
    people === null || people.length === 0 || people.length > HesPersonas.IDS.length) {
    return null;
  }
  const out = new HealthSimPayload();
  out.source = source;
  out.end = end;
  for (let i = 0; i < people.length; i++) {
    const p = readPerson(people[i], end);
    if (p === null) {
      return null;
    }
    for (let j = 0; j < out.people.length; j++) {
      if (out.people[j].id === p.id) {
        return null;    // one person twice
      }
    }
    out.people.push(p);
  }
  return out;
}

// ---------------------------------------------------------------------------------------------------------
// The six demo people, and consent
// ---------------------------------------------------------------------------------------------------------

/** What Health Sim holds: the six demo people with the same seeded histories the score was tuned on. */
export function healthSimPayloadFromPersonas(): HealthSimPayload {
  const out = new HealthSimPayload();
  out.end = HES_PERSONA_END_DATE;
  for (let i = 0; i < HesPersonas.IDS.length; i++) {
    const id = HesPersonas.IDS[i];
    const p = new HealthSimPerson();
    p.id = id;
    p.name = HesPersonas.displayName(id);
    p.days = HesPersonas.history(id);
    p.wear = WearPersonas.month(id);
    out.people.push(p);
  }
  return out;
}

/** The person with this id, or null. */
export function healthSimPerson(p: HealthSimPayload, id: string): HealthSimPerson | null {
  for (let i = 0; i < p.people.length; i++) {
    if (p.people[i].id === id) {
      return p.people[i];
    }
  }
  return null;
}

/**
 * One day as the consent allows it: every field of a data type that is not in `scopes` becomes HES_MISSING.
 * The day passed in is not changed.
 */
export function dayWithScopes(day: HesDay, scopes: HealthScope[]): HesDay {
  const d = copyHesDay(day);
  if (scopes.indexOf(HealthScope.STEPS) < 0) {
    d.steps = HES_MISSING;
  }
  if (scopes.indexOf(HealthScope.RESTING_HEART_RATE) < 0) {
    d.restingHeartRate = HES_MISSING;
  }
  if (scopes.indexOf(HealthScope.SLEEP) < 0) {
    d.sleepStartMin = HES_MISSING;
    d.sleepEndMin = HES_MISSING;
    d.sleepMinutes = HES_MISSING;
  }
  if (scopes.indexOf(HealthScope.ACTIVITY_MINUTES) < 0) {
    d.moderateMinutes = HES_MISSING;
    d.vigorousMinutes = HES_MISSING;
  }
  if (scopes.indexOf(HealthScope.VO2MAX) < 0) {
    d.vo2maxPercentile = HES_MISSING;
  }
  if (scopes.indexOf(HealthScope.HRV) < 0) {
    d.hrvPercentile = HES_MISSING;
  }
  if (scopes.indexOf(HealthScope.WORKOUTS) < 0) {
    d.hrr1 = HES_MISSING;
  }
  return d;
}

/**
 * The same payload with the values of every data type the user did not allow set to -1 (no value). The
 * wear month stays: it is not a HUAWEI Health data type.
 */
export function withScopes(p: HealthSimPayload, scopes: HealthScope[]): HealthSimPayload {
  const out = new HealthSimPayload();
  out.v = p.v;
  out.source = p.source;
  out.end = p.end;
  for (let i = 0; i < p.people.length; i++) {
    const src = p.people[i];
    const person = new HealthSimPerson();
    person.id = src.id;
    person.name = src.name;
    for (let j = 0; j < src.days.length; j++) {
      person.days.push(dayWithScopes(src.days[j], scopes));
    }
    person.wear = src.wear;
    out.people.push(person);
  }
  return out;
}
