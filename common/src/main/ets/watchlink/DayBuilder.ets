// Turns a finished recorder day into an unsigned day packet. Measurements only: there is no
// "suspicious", no "compliant" and no tier here. Those are decided on the phone.
import { DEFAULT_THRESHOLDS } from '../model/defaults';
import { slotsToString } from './SlotRecorder';
import {
  BreakContext,
  dateOfDayNumber,
  dayNumberOfDate,
  DayPacket,
  DayRecord,
  DAY_MINUTES,
  MAX_BREAKS,
  median,
  NIGHT_SLOT_COUNT,
  NO_VALUE,
  PACKET_VERSION,
  REST_FIRST_SLOT,
  REST_LAST_SLOT,
  REST_MIN_SLOTS,
  SlotRecord,
  SLOT_MINUTES,
  SLOTS_PER_DAY,
  SLOTS_PER_HOUR,
  TYPE_DAY
} from './WatchLinkTypes';

// Yesterday's 288 slots followed by today's. Index 288 is today's 00:00.
class TwoDays {
  states: string = '';
  slots: SlotRecord[] = [];
}

function joinDays(today: DayRecord, yesterday: DayRecord | null): TwoDays {
  const out = new TwoDays();
  if (yesterday === null) {
    out.states = 'U'.repeat(SLOTS_PER_DAY);
    for (let i = 0; i < SLOTS_PER_DAY; i++) {
      out.slots.push(today.slots[0]);   // placeholders, never read: their state is U
    }
  } else {
    out.states = slotsToString(yesterday);
    for (let i = 0; i < SLOTS_PER_DAY; i++) {
      out.slots.push(yesterday.slots[i]);
    }
  }
  out.states += slotsToString(today);
  for (let i = 0; i < SLOTS_PER_DAY; i++) {
    out.slots.push(today.slots[i]);
  }
  return out;
}

function hasHr(slot: SlotRecord): boolean {
  return slot.hrSampleCount >= 1;
}

function meanHr(slot: SlotRecord): number {
  return slot.hrSum / slot.hrSampleCount;
}

// Context of a break from the 288 slots before its start (fewer when the record does not reach that far).
function contextBefore(two: TwoDays, start: number, end: number): BreakContext {
  let hrSlots = 0;
  let steps = 0;
  const restMeans: number[] = [];
  const from = start - SLOTS_PER_DAY < 0 ? 0 : start - SLOTS_PER_DAY;
  for (let i = from; i < start; i++) {
    const slot = two.slots[i];
    const state = two.states.charAt(i);
    if (state === 'U') {
      continue;
    }
    steps += slot.steps;
    if (state === 'W' && hasHr(slot)) {
      hrSlots++;
      if (slot.steps === 0) {
        restMeans.push(meanHr(slot));
      }
    }
  }
  const context: BreakContext = {
    startMin: (start - SLOTS_PER_DAY) * SLOT_MINUTES,
    endMin: (end - SLOTS_PER_DAY) * SLOT_MINUTES,
    hrSlots24hBefore: hrSlots,
    rhr24hBefore: restMeans.length === 0 ? NO_VALUE : Math.round(median(restMeans)),
    steps24hBefore: steps
  };
  return context;
}

// Breaks that END on the packet day: maximal runs of O (never C, never U) of at least the break minimum,
// the same limit the phone's rule counts with (WearMonth judgeBreak: minutes >= gapMinMinutes).
// A run still going at the end of the day is not reported here; it is carried into the next day's packet.
// A run that began the day before has a negative startMin.
function findBreaks(two: TwoDays, breakMinMinutes: number): BreakContext[] {
  const out: BreakContext[] = [];
  const total = SLOTS_PER_DAY * 2;
  let i = 0;
  while (i < total) {
    if (two.states.charAt(i) !== 'O') {
      i++;
      continue;
    }
    const start = i;
    while (i < total && two.states.charAt(i) === 'O') {
      i++;
    }
    const end = i;   // exclusive
    const endsToday = end >= SLOTS_PER_DAY && end < total;
    if (endsToday && (end - start) * SLOT_MINUTES >= breakMinMinutes && out.length < MAX_BREAKS) {
      out.push(contextBefore(two, start, end));
    }
  }
  return out;
}

export class DayBuilder {
  // `yesterday` is the record of the day right before `today`, or null. A record of any other date is ignored.
  // The break minimum comes from the shared thresholds (defaults.ets), in minutes.
  static build(today: DayRecord, yesterday: DayRecord | null,
    breakMinMinutes: number = DEFAULT_THRESHOLDS.gapMinMinutes): DayPacket {
    let before: DayRecord | null = yesterday;
    if (before !== null && before.date !== dateOfDayNumber(dayNumberOfDate(today.date) - 1)) {
      before = null;
    }
    const two = joinDays(today, before);
    const slots = slotsToString(today);

    const stepsByHour: number[] = [];
    for (let h = 0; h < 24; h++) {
      let sum = 0;
      for (let k = 0; k < SLOTS_PER_HOUR; k++) {
        sum += today.slots[h * SLOTS_PER_HOUR + k].steps;
      }
      stepsByHour.push(sum);
    }

    let nightWorn = 0;
    let nightCharging = 0;
    for (let i = 0; i < NIGHT_SLOT_COUNT; i++) {
      const state = slots.charAt(i);
      if (state === 'W') {
        nightWorn++;
      } else if (state === 'C') {
        nightCharging++;
      }
    }

    let hrSlotCount = 0;
    const restMeans: number[] = [];
    for (let i = 0; i < SLOTS_PER_DAY; i++) {
      const slot = today.slots[i];
      if (slots.charAt(i) !== 'W' || !hasHr(slot)) {
        continue;
      }
      hrSlotCount++;
      if (i >= REST_FIRST_SLOT && i <= REST_LAST_SLOT && slot.steps === 0) {
        restMeans.push(meanHr(slot));
      }
    }

    const packet: DayPacket = {
      v: PACKET_VERSION,
      type: TYPE_DAY,
      kid: '',
      seq: 0,
      prev: '',
      date: today.date,
      tzOffsetMin: today.tzOffsetMin,
      slots: slots,
      stepsByHour: stepsByHour,
      hrRestEst: restMeans.length < REST_MIN_SLOTS ? NO_VALUE : Math.round(median(restMeans)),
      hrSlotCount: hrSlotCount,
      nightWornMin: nightWorn * SLOT_MINUTES,
      nightChargingMin: nightCharging * SLOT_MINUTES,
      breaks: findBreaks(two, breakMinMinutes),
      wearSource: today.wearSource,
      clock: today.clock,
      iat: 0,
      sig: ''
    };
    return packet;
  }
}

export const EARLIEST_BREAK_START_MIN: number = -DAY_MINUTES;
