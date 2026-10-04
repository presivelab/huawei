// What Health Sim hands to FairWear. Health Sim is the team's simulator app that stands in for HUAWEI Health
// on the emulators (bundle com.fairwear.healthsim). After the user allows it, Health Sim returns the health
// export of the six demo people as one JSON text in the result of startAbilityForResult, under the
// parameter `fwhs1`. Pure logic, no system kits.
//
// The same file is copied unchanged into the Health Sim app (healthsim/entry/src/main/ets/fw/health/), so
// both apps write and read the very same format; common/src/test/HealthSimCopies.test.ets keeps the copies
// identical.
//
// The contract is versioned. Version 2:
//   {"schema":"fairwear.health-export","version":2,"source":"Health Sim","exportedAt":"2026-10-04",
//    "people":[{"personaId":"ania","name":"Ania",
//      "today":{day},                       the running day as the source has it; not scored until closed
//      "days":[{day}, ...],                 completed days, oldest first
//      "crf":[{"date":"2026-09-21","percentile":77}, ...],                     VO2max estimates
//      "hrr":[{"date":"...","protocolId":"walk-3min","peakHr":150,"hr60":118}, ...],  recovery sessions
//      "wear":[[date, observed 0|1, wornMin, nightWornMin, chargingMin,
//               [[startMin, minutes, hrReadings24hBefore, restDeltaBpm, stepsRatio], ...]], ...]}, ...]}
//   {day} = {"date":"2026-10-03","steps":8200,"moderateMin":16,"vigorousMin":6,"restingHr":56,
//            "sleep":{"bedMin":1320,"wakeMin":360,"totalSleepMin":426},
//            "hrv":{"percentile":55,"protocol":"nocturnal"}}
// Every reading of a day is optional: a reading that does not exist is a key that is not there. It is never
// written as 0 or -1, and the reader never turns a missing key into a number.
//
// A text of another version is refused as outdated (HEALTH_SIM_OUTDATED_TEXT) and nothing is calculated
// from it. "wear" is the wear month. Wear is not a HUAWEI Health data type: Health Sim derives it from the
// gaps in the heart-rate samples, as the real data would allow.
import { HES_PERSONA_TODAY, HesPersonas } from '../hes/HesPersonas';
import { copyHesDayRecord, HesSnapshot } from '../hes/HesSession';
import { HesCrfEstimate, HesDayRecord, HesHistory, HesHrrSession, HesHrvNight, HesSleep } from '../hes/HesTypes';
import { asObject, parseJsonObject, readArray, readNumber, readString } from '../watchlink/JsonRead';
import { WearBreak, WearDayRecord } from '../wear/WearMonth';
import { WearPersonas } from '../wear/WearPersonas';
import { HealthScope } from './HealthConnection';

/** The Want parameter that carries the text. */
export const HEALTH_SIM_PARAM: string = 'fwhs1';
export const HEALTH_SIM_SCHEMA: string = 'fairwear.health-export';
export const HEALTH_SIM_VERSION: number = 2;
export const HEALTH_SIM_SOURCE: string = 'Health Sim';
/** A longer text is refused without being parsed. Six people are about 36 000 characters. */
export const HEALTH_SIM_MAX_CHARS: number = 90000;
/** What FairWear says when Health Sim answers in another version of the contract. */
export const HEALTH_SIM_OUTDATED_TEXT: string = 'Health Sim data format is outdated — update Health Sim';

const WEAR_FIELDS: number = 6;
const BREAK_FIELDS: number = 5;
const MAX_DAYS: number = 400;
const MAX_ESTIMATES: number = 200;
const MAX_WEAR_DAYS: number = 62;
const MAX_BREAKS: number = 48;
const MAX_TEXT: number = 64;
const DATE_PATTERN: RegExp = new RegExp('^[0-9]{4}-[0-9]{2}-[0-9]{2}$');

/** One person's export as Health Sim holds it. */
export class HealthSimPerson {
  id: string = '';
  name: string = '';
  today: HesDayRecord = { date: '' };
  history: HesHistory = { days: [], crf: [], hrr: [] };
  wear: WearDayRecord[] = [];
}

/** Everything Health Sim sends in one answer. */
export class HealthSimPayload {
  schema: string = HEALTH_SIM_SCHEMA;
  version: number = HEALTH_SIM_VERSION;
  source: string = HEALTH_SIM_SOURCE;
  exportedAt: string = '';
  people: HealthSimPerson[] = [];
}

/** How a text from Health Sim read. */
export enum HealthSimReadStatus {
  OK = 'OK',
  OUTDATED = 'OUTDATED',  // readable JSON of another schema or version
  INVALID = 'INVALID'     // not the contract at all
}

export class HealthSimRead {
  status: HealthSimReadStatus = HealthSimReadStatus.INVALID;
  payload: HealthSimPayload | null = null;
}

// ---------------------------------------------------------------------------------------------------------
// Writing
// ---------------------------------------------------------------------------------------------------------

function isNumber(n: number | undefined): boolean {
  return n !== undefined && n !== null && Number.isFinite(n);
}

// Wear rows keep their fixed positions, so a number that is not finite is written as -1 there.
function wearNum(n: number): string {
  return Number.isFinite(n) ? `${n}` : '-1';
}

function dayText(d: HesDayRecord): string {
  const parts: string[] = [`"date":${JSON.stringify(d.date)}`];
  if (isNumber(d.steps)) {
    parts.push(`"steps":${d.steps}`);
  }
  if (isNumber(d.moderateMin)) {
    parts.push(`"moderateMin":${d.moderateMin}`);
  }
  if (isNumber(d.vigorousMin)) {
    parts.push(`"vigorousMin":${d.vigorousMin}`);
  }
  if (isNumber(d.restingHr)) {
    parts.push(`"restingHr":${d.restingHr}`);
  }
  const sleep = d.sleep;
  if (sleep !== undefined && isNumber(sleep.bedMin) && isNumber(sleep.wakeMin) && isNumber(sleep.totalSleepMin)) {
    parts.push(`"sleep":{"bedMin":${sleep.bedMin},"wakeMin":${sleep.wakeMin},` +
      `"totalSleepMin":${sleep.totalSleepMin}}`);
  }
  const hrv = d.hrv;
  if (hrv !== undefined && isNumber(hrv.percentile)) {
    parts.push(`"hrv":{"percentile":${hrv.percentile},"protocol":${JSON.stringify(hrv.protocol)}}`);
  }
  return `{${parts.join(',')}}`;
}

function crfText(e: HesCrfEstimate): string {
  return `{"date":${JSON.stringify(e.date)},"percentile":${e.percentile}}`;
}

function hrrText(s: HesHrrSession): string {
  return `{"date":${JSON.stringify(s.date)},"protocolId":${JSON.stringify(s.protocolId)},` +
    `"peakHr":${s.peakHr},"hr60":${s.hr60}}`;
}

function breakText(b: WearBreak): string {
  return `[${wearNum(b.startMin)},${wearNum(b.minutes)},${wearNum(b.hrReadings24hBefore)},` +
    `${wearNum(b.restDeltaBpm)},${wearNum(b.stepsRatio)}]`;
}

function wearText(w: WearDayRecord): string {
  const breaks: string[] = [];
  for (let i = 0; i < w.breaks.length; i++) {
    breaks.push(breakText(w.breaks[i]));
  }
  return `[${JSON.stringify(w.date)},${w.observed ? 1 : 0},${wearNum(w.wornMin)},${wearNum(w.nightWornMin)},` +
    `${wearNum(w.chargingMin)},[${breaks.join(',')}]]`;
}

function personText(p: HealthSimPerson): string {
  const days: string[] = [];
  for (let i = 0; i < p.history.days.length; i++) {
    days.push(dayText(p.history.days[i]));
  }
  const crf: string[] = [];
  for (let i = 0; i < p.history.crf.length; i++) {
    if (isNumber(p.history.crf[i].percentile)) {
      crf.push(crfText(p.history.crf[i]));
    }
  }
  const hrr: string[] = [];
  for (let i = 0; i < p.history.hrr.length; i++) {
    if (isNumber(p.history.hrr[i].peakHr) && isNumber(p.history.hrr[i].hr60)) {
      hrr.push(hrrText(p.history.hrr[i]));
    }
  }
  const wear: string[] = [];
  for (let i = 0; i < p.wear.length; i++) {
    wear.push(wearText(p.wear[i]));
  }
  return `{"personaId":${JSON.stringify(p.id)},"name":${JSON.stringify(p.name)},"today":${dayText(p.today)},` +
    `"days":[${days.join(',')}],"crf":[${crf.join(',')}],"hrr":[${hrr.join(',')}],"wear":[${wear.join(',')}]}`;
}

/** The text Health Sim returns under HEALTH_SIM_PARAM. */
export function encodeHealthSimPayload(p: HealthSimPayload): string {
  const people: string[] = [];
  for (let i = 0; i < p.people.length; i++) {
    people.push(personText(p.people[i]));
  }
  return `{"schema":${JSON.stringify(p.schema)},"version":${wearNum(p.version)},` +
    `"source":${JSON.stringify(p.source)},"exportedAt":${JSON.stringify(p.exportedAt)},` +
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

// How an optional key read.
const ABSENT: number = 0;
const PRESENT: number = 1;
const WRONG: number = 2;

class OptionalNumber {
  state: number = ABSENT;
  value: number = 0;
}

// A key that is not there (or is null) is an absent reading. A key that holds anything but a finite number
// makes the whole text invalid.
function optionalNumber(o: Record<string, Object>, key: string): OptionalNumber {
  const out = new OptionalNumber();
  const v: Object | undefined = o[key];
  if (v === undefined || v === null) {
    return out;
  }
  const n = finite(v);
  if (n === null) {
    out.state = WRONG;
    return out;
  }
  out.state = PRESENT;
  out.value = n;
  return out;
}

function requiredNumber(o: Record<string, Object>, key: string): number | null {
  const v: Object | undefined = o[key];
  return v === undefined || v === null ? null : finite(v);
}

function shortText(o: Record<string, Object>, key: string): string | null {
  const text = readString(o, key);
  return text === null || text.length > MAX_TEXT ? null : text;
}

function readDay(v: Object): HesDayRecord | null {
  const o = asObject(v);
  if (o === null) {
    return null;
  }
  const date: Object | undefined = o['date'];
  if (date === undefined || !isDate(date)) {
    return null;
  }
  const day: HesDayRecord = { date: date as string };
  const steps = optionalNumber(o, 'steps');
  const moderate = optionalNumber(o, 'moderateMin');
  const vigorous = optionalNumber(o, 'vigorousMin');
  const resting = optionalNumber(o, 'restingHr');
  if (steps.state === WRONG || moderate.state === WRONG || vigorous.state === WRONG || resting.state === WRONG) {
    return null;
  }
  if (steps.state === PRESENT) {
    day.steps = steps.value;
  }
  if (moderate.state === PRESENT) {
    day.moderateMin = moderate.value;
  }
  if (vigorous.state === PRESENT) {
    day.vigorousMin = vigorous.value;
  }
  if (resting.state === PRESENT) {
    day.restingHr = resting.value;
  }
  const rawSleep: Object | undefined = o['sleep'];
  if (rawSleep !== undefined && rawSleep !== null) {
    const s = asObject(rawSleep);
    if (s === null) {
      return null;
    }
    const bed = requiredNumber(s, 'bedMin');
    const wake = requiredNumber(s, 'wakeMin');
    const total = requiredNumber(s, 'totalSleepMin');
    if (bed === null || wake === null || total === null) {
      return null;
    }
    const sleep: HesSleep = { bedMin: bed, wakeMin: wake, totalSleepMin: total };
    day.sleep = sleep;
  }
  const rawHrv: Object | undefined = o['hrv'];
  if (rawHrv !== undefined && rawHrv !== null) {
    const h = asObject(rawHrv);
    if (h === null) {
      return null;
    }
    const percentile = requiredNumber(h, 'percentile');
    const protocol = shortText(h, 'protocol');
    if (percentile === null || protocol === null) {
      return null;
    }
    const hrv: HesHrvNight = { percentile: percentile, protocol: protocol };
    day.hrv = hrv;
  }
  return day;
}

function readCrf(v: Object): HesCrfEstimate | null {
  const o = asObject(v);
  if (o === null) {
    return null;
  }
  const date: Object | undefined = o['date'];
  const percentile = requiredNumber(o, 'percentile');
  if (date === undefined || !isDate(date) || percentile === null) {
    return null;
  }
  return { date: date as string, percentile: percentile };
}

function readHrr(v: Object): HesHrrSession | null {
  const o = asObject(v);
  if (o === null) {
    return null;
  }
  const date: Object | undefined = o['date'];
  const protocolId = shortText(o, 'protocolId');
  const peak = requiredNumber(o, 'peakHr');
  const after = requiredNumber(o, 'hr60');
  if (date === undefined || !isDate(date) || protocolId === null || peak === null || after === null) {
    return null;
  }
  return { date: date as string, protocolId: protocolId, peakHr: peak, hr60: after };
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

function readPerson(v: Object): HealthSimPerson | null {
  const o = asObject(v);
  if (o === null) {
    return null;
  }
  const id = readString(o, 'personaId');
  const name = shortText(o, 'name');
  const rawToday: Object | undefined = o['today'];
  const days = readArray(o, 'days');
  const crf = readArray(o, 'crf');
  const hrr = readArray(o, 'hrr');
  const wear = readArray(o, 'wear');
  if (id === null || !HesPersonas.has(id) || name === null || rawToday === undefined || days === null ||
    crf === null || hrr === null || wear === null || days.length > MAX_DAYS ||
    crf.length > MAX_ESTIMATES || hrr.length > MAX_ESTIMATES || wear.length > MAX_WEAR_DAYS) {
    return null;
  }
  const today = readDay(rawToday);
  if (today === null) {
    return null;
  }
  const p = new HealthSimPerson();
  p.id = id;
  p.name = name;
  p.today = today;
  for (let i = 0; i < days.length; i++) {
    const d = readDay(days[i]);
    if (d === null) {
      return null;
    }
    p.history.days.push(d);
  }
  for (let i = 0; i < crf.length; i++) {
    const e = readCrf(crf[i]);
    if (e === null) {
      return null;
    }
    p.history.crf.push(e);
  }
  for (let i = 0; i < hrr.length; i++) {
    const s = readHrr(hrr[i]);
    if (s === null) {
      return null;
    }
    p.history.hrr.push(s);
  }
  for (let i = 0; i < wear.length; i++) {
    const w = readWearDay(wear[i]);
    if (w === null) {
      return null;
    }
    p.wear.push(w);
  }
  return p;
}

function readPeople(o: Record<string, Object>): HealthSimPayload | null {
  const source = shortText(o, 'source');
  const exportedAt = shortText(o, 'exportedAt');
  const people = readArray(o, 'people');
  if (source === null || exportedAt === null || people === null || people.length === 0 ||
    people.length > HesPersonas.IDS.length) {
    return null;
  }
  const out = new HealthSimPayload();
  out.source = source;
  out.exportedAt = exportedAt;
  for (let i = 0; i < people.length; i++) {
    const p = readPerson(people[i]);
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

/**
 * Reads a text from Health Sim. OUTDATED for readable JSON of another schema or version: FairWear then says
 * HEALTH_SIM_OUTDATED_TEXT and calculates nothing. INVALID for anything else that is not the contract.
 * Never throws.
 */
export function readHealthSimPayload(text: string): HealthSimRead {
  const out = new HealthSimRead();
  if (text.length === 0 || text.length > HEALTH_SIM_MAX_CHARS) {
    return out;
  }
  const o = parseJsonObject(text);
  if (o === null) {
    return out;
  }
  const schema = readString(o, 'schema');
  const version = readNumber(o, 'version');
  if (schema === null || schema !== HEALTH_SIM_SCHEMA || version === null || version !== HEALTH_SIM_VERSION) {
    out.status = HealthSimReadStatus.OUTDATED;
    return out;
  }
  const payload = readPeople(o);
  if (payload !== null) {
    out.status = HealthSimReadStatus.OK;
    out.payload = payload;
  }
  return out;
}

/** The payload, or null for anything that is not a valid version-2 text. Never throws. */
export function decodeHealthSimPayload(text: string): HealthSimPayload | null {
  return readHealthSimPayload(text).payload;
}

// ---------------------------------------------------------------------------------------------------------
// The six demo people, and consent
// ---------------------------------------------------------------------------------------------------------

/**
 * What Health Sim holds: the six demo people from the persona generator, for the running day `today`.
 * `exportedAt` is written as given; there is no clock here.
 */
export function healthSimPayloadFromPersonas(today: string = HES_PERSONA_TODAY,
  exportedAt: string = HES_PERSONA_TODAY): HealthSimPayload {
  const out = new HealthSimPayload();
  out.exportedAt = exportedAt;
  for (let i = 0; i < HesPersonas.IDS.length; i++) {
    const id = HesPersonas.IDS[i];
    const p = new HealthSimPerson();
    p.id = id;
    p.name = HesPersonas.displayName(id);
    p.today = HesPersonas.today(id, today);
    p.history = HesPersonas.history(id, today);
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

/** What the score session starts from for this person. */
export function healthSimSnapshot(person: HealthSimPerson): HesSnapshot {
  return { history: person.history, today: person.today };
}

/**
 * One day as the consent allows it: every reading of a data type that is not in `scopes` is removed (absent,
 * never zero). The day passed in is not changed.
 */
export function dayWithScopes(day: HesDayRecord, scopes: HealthScope[]): HesDayRecord {
  const d = copyHesDayRecord(day);
  if (scopes.indexOf(HealthScope.STEPS) < 0) {
    d.steps = undefined;
  }
  if (scopes.indexOf(HealthScope.RESTING_HEART_RATE) < 0) {
    d.restingHr = undefined;
  }
  if (scopes.indexOf(HealthScope.SLEEP) < 0) {
    d.sleep = undefined;
  }
  if (scopes.indexOf(HealthScope.ACTIVITY_MINUTES) < 0) {
    d.moderateMin = undefined;
    d.vigorousMin = undefined;
  }
  if (scopes.indexOf(HealthScope.HRV) < 0) {
    d.hrv = undefined;
  }
  return d;
}

/**
 * A snapshot as the consent allows it: the days and the running day lose the readings of every data type
 * that is not in `scopes`; without VO2MAX there are no estimates and without WORKOUTS no recovery sessions.
 * Every day closed later starts from the same running day, so the consent holds for those days too.
 */
export function snapshotWithScopes(snapshot: HesSnapshot, scopes: HealthScope[]): HesSnapshot {
  const days: HesDayRecord[] = [];
  for (let i = 0; i < snapshot.history.days.length; i++) {
    days.push(dayWithScopes(snapshot.history.days[i], scopes));
  }
  const crf: HesCrfEstimate[] = [];
  if (scopes.indexOf(HealthScope.VO2MAX) >= 0) {
    for (let i = 0; i < snapshot.history.crf.length; i++) {
      crf.push({ date: snapshot.history.crf[i].date, percentile: snapshot.history.crf[i].percentile });
    }
  }
  const hrr: HesHrrSession[] = [];
  if (scopes.indexOf(HealthScope.WORKOUTS) >= 0) {
    for (let i = 0; i < snapshot.history.hrr.length; i++) {
      const s = snapshot.history.hrr[i];
      hrr.push({ date: s.date, protocolId: s.protocolId, peakHr: s.peakHr, hr60: s.hr60 });
    }
  }
  return {
    history: { days: days, crf: crf, hrr: hrr },
    today: dayWithScopes(snapshot.today, scopes)
  };
}

/**
 * The same payload without the readings of every data type the user did not allow. The wear month stays: it
 * is not a HUAWEI Health data type.
 */
export function withScopes(p: HealthSimPayload, scopes: HealthScope[]): HealthSimPayload {
  const out = new HealthSimPayload();
  out.schema = p.schema;
  out.version = p.version;
  out.source = p.source;
  out.exportedAt = p.exportedAt;
  for (let i = 0; i < p.people.length; i++) {
    const src = p.people[i];
    const scoped = snapshotWithScopes(healthSimSnapshot(src), scopes);
    const person = new HealthSimPerson();
    person.id = src.id;
    person.name = src.name;
    person.today = scoped.today;
    person.history = scoped.history;
    person.wear = src.wear;
    out.people.push(person);
  }
  return out;
}
