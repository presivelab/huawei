// A deterministic 30-day wear record for each demo persona, built on the same days as the persona's
// HES history: a day with no health data is a day the watch stayed off the wrist, a night with no sleep
// record is a night the watch was not worn, and days before the history starts are not observed.
// Illustrative values, not measurements of anyone. No Math.random.
import { dateOfDayNumber, dayNumberOfDate } from '../watchlink/WatchLinkTypes';
import { DEFAULT_THRESHOLDS } from '../model/defaults';
import { generatePersonaDay, HesPersonas, HesPersonaSpec, HES_PERSONA_END_DATE } from '../hes/HesPersonas';
import { HesPrng } from '../hes/HesPrng';
import { HES_MISSING } from '../hes/HesTypes';
import { buildWearMonth, WearBreak, WearDayRecord, WearMonthResult } from './WearMonth';

export const WEAR_MONTH_DAYS: number = 30;

const MINUTES_PER_DAY: number = 1440;
const NIGHT_END_MIN: number = 360;         // 06:00
const STREAM_WEAR: number = 20;
const CHARGING_MIN: number = 35;
const CHARGING_SPAN: number = 41;          // charging takes 35..75 minutes a day
const MINOR_OFF_SPAN: number = 31;         // 0..30 minutes of short moments off the wrist, not breaks
const NIGHT_OFF_MIN: number = 380;
const NIGHT_OFF_SPAN: number = 61;         // a night off the wrist ends between 06:20 and 07:20
const USUAL_READINGS: number = 180;
const USUAL_READINGS_SPAN: number = 80;
const USUAL_DELTA_LIMIT: number = 3;
const USUAL_RATIO_MIN: number = 88;        // steps before an ordinary break: 0.88..1.12 of the usual
const USUAL_RATIO_SPAN: number = 25;

/** A scripted break of a persona: when it happened and what the 24 h before it looked like. */
export interface WearEvent {
  offset: number;               // 0 = HES_PERSONA_END_DATE, negative = earlier days
  startMin: number;             // ignored on a day the watch was off the wrist all day
  minutes: number;              // ignored on a day the watch was off the wrist all day
  hrReadings24hBefore: number;
  restDeltaBpm: number;
  stepsRatio: number;
}

function at(hour: number, minute: number): number {
  return hour * 60 + minute;
}

// Marek: three breaks after a day with a raised resting heart rate and far fewer steps, one long ordinary
// break and one short ordinary break.
const MAREK_EVENTS: WearEvent[] = [
  { offset: -25, startMin: at(8, 0), minutes: 300, hrReadings24hBefore: 240, restDeltaBpm: 1, stepsRatio: 0.92 },
  { offset: -20, startMin: at(12, 30), minutes: 320, hrReadings24hBefore: 260, restDeltaBpm: 8, stepsRatio: 0.55 },
  { offset: -16, startMin: at(13, 5), minutes: 335, hrReadings24hBefore: 251, restDeltaBpm: 9, stepsRatio: 0.54 },
  { offset: -9, startMin: at(9, 40), minutes: 330, hrReadings24hBefore: 244, restDeltaBpm: 10, stepsRatio: 0.48 },
  { offset: -5, startMin: at(17, 0), minutes: 125, hrReadings24hBefore: 230, restDeltaBpm: 0, stepsRatio: 1.02 }
];

// Kasia: what the 24 h before each of her four days without the watch looked like. One is suspicious; one
// would be, but the watch had only 8 heart-rate readings before it, so it is not judged.
const KASIA_EVENTS: WearEvent[] = [
  { offset: -27, startMin: 0, minutes: 0, hrReadings24hBefore: 236, restDeltaBpm: -1, stepsRatio: 1.04 },
  { offset: -19, startMin: 0, minutes: 0, hrReadings24hBefore: 228, restDeltaBpm: 8, stepsRatio: 0.52 },
  { offset: -11, startMin: 0, minutes: 0, hrReadings24hBefore: 8, restDeltaBpm: 9, stepsRatio: 0.5 },
  { offset: -3, startMin: 0, minutes: 0, hrReadings24hBefore: 240, restDeltaBpm: 2, stepsRatio: 0.88 }
];

const TOMEK_EVENTS: WearEvent[] = [
  { offset: -13, startMin: at(10, 0), minutes: 290, hrReadings24hBefore: 250, restDeltaBpm: 1, stepsRatio: 0.97 }
];

const NO_EVENTS: WearEvent[] = [];

function eventAt(events: WearEvent[], offset: number): WearEvent | null {
  for (let i = 0; i < events.length; i++) {
    if (events[i].offset === offset) {
      return events[i];
    }
  }
  return null;
}

function pick(prng: HesPrng, span: number): number {
  return Math.floor(prng.next() * span);
}

// The 24 h before an ordinary break: the usual resting heart rate and the usual steps.
function ordinaryBreak(prng: HesPrng, startMin: number, minutes: number): WearBreak {
  return {
    startMin: startMin,
    minutes: minutes,
    hrReadings24hBefore: USUAL_READINGS + pick(prng, USUAL_READINGS_SPAN),
    restDeltaBpm: pick(prng, 2 * USUAL_DELTA_LIMIT + 1) - USUAL_DELTA_LIMIT,
    stepsRatio: (USUAL_RATIO_MIN + pick(prng, USUAL_RATIO_SPAN)) / 100
  };
}

function scriptedBreak(event: WearEvent, startMin: number, minutes: number): WearBreak {
  return {
    startMin: startMin,
    minutes: minutes,
    hrReadings24hBefore: event.hrReadings24hBefore,
    restDeltaBpm: event.restDeltaBpm,
    stepsRatio: event.stepsRatio
  };
}

/** One day of the wear record. `offset` 0 is HES_PERSONA_END_DATE. */
export function generateWearDay(spec: HesPersonaSpec, offset: number, events: WearEvent[]): WearDayRecord {
  const record: WearDayRecord = {
    date: dateOfDayNumber(dayNumberOfDate(HES_PERSONA_END_DATE) + offset),
    observed: false,
    wornMin: 0,
    nightWornMin: 0,
    chargingMin: 0,
    breaks: []
  };
  if (offset < 1 - spec.days) {
    return record;                           // before the persona's history: the watch has no record
  }
  record.observed = true;
  const hesDay = generatePersonaDay(spec, offset);
  const prng = HesPrng.forStream(spec.seed, offset, STREAM_WEAR);
  const event = eventAt(events, offset);

  if (hesDay.steps === HES_MISSING) {
    // The watch stayed off the wrist all day: one break as long as the day.
    record.breaks.push(event === null ? ordinaryBreak(prng, 0, MINUTES_PER_DAY) :
      scriptedBreak(event, 0, MINUTES_PER_DAY));
    return record;
  }

  record.chargingMin = CHARGING_MIN + pick(prng, CHARGING_SPAN);
  let offMin = pick(prng, MINOR_OFF_SPAN);
  let nightWornMin = NIGHT_END_MIN;
  if (hesDay.sleepMinutes === HES_MISSING) {
    // No sleep record: the watch was not worn that night.
    const nightOff = NIGHT_OFF_MIN + pick(prng, NIGHT_OFF_SPAN);
    record.breaks.push(ordinaryBreak(prng, 0, nightOff));
    offMin += nightOff;
    nightWornMin = 0;
  }
  if (event !== null) {
    record.breaks.push(scriptedBreak(event, event.startMin, event.minutes));
    offMin += event.minutes;
    if (event.startMin < NIGHT_END_MIN) {
      const overlap = Math.min(NIGHT_END_MIN, event.startMin + event.minutes) - event.startMin;
      nightWornMin = Math.max(0, nightWornMin - overlap);
    }
  }
  record.nightWornMin = nightWornMin;
  record.wornMin = Math.max(0, MINUTES_PER_DAY - record.chargingMin - offMin);
  return record;
}

/** The last WEAR_MONTH_DAYS days of a persona, oldest first, ending on HES_PERSONA_END_DATE. */
export function generateWearMonth(spec: HesPersonaSpec, events: WearEvent[]): WearDayRecord[] {
  const out: WearDayRecord[] = [];
  for (let offset = 1 - WEAR_MONTH_DAYS; offset <= 0; offset++) {
    out.push(generateWearDay(spec, offset, events));
  }
  return out;
}

/** The wear month of the six demo personas. An unknown id gives an empty month. */
export class WearPersonas {
  /** The scripted breaks of a persona. */
  static events(id: string): WearEvent[] {
    if (id === 'marek') {
      return MAREK_EVENTS;
    }
    if (id === 'kasia') {
      return KASIA_EVENTS;
    }
    if (id === 'tomek') {
      return TOMEK_EVENTS;
    }
    return NO_EVENTS;
  }

  /** 30 day records, oldest first. */
  static month(id: string): WearDayRecord[] {
    const spec = HesPersonas.spec(id);
    return spec === null ? [] : generateWearMonth(spec, WearPersonas.events(id));
  }

  /** The month under the default thresholds, with no sick days. */
  static result(id: string): WearMonthResult {
    return buildWearMonth(WearPersonas.month(id), DEFAULT_THRESHOLDS, []);
  }
}
