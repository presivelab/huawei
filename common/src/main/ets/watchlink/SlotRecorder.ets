// Records what the watch saw into 288 five-minute slots per local day. Pure logic: time, storage and
// sensor values are passed in.
//
// The recorder never extrapolates. Time it was not fed is "not observed" (U): the app was suspended,
// killed, or had no sensor signal. U is never off-wrist.
import { dayFilePath, dayRecordFromJson, dayRecordToJson } from './DayRecordCodec';
import { TextStore } from './WatchLinkPorts';
import {
  classifySlot,
  CLOCK_REAL,
  dateOfDayNumber,
  dayNumberOfDate,
  DayRecord,
  DAY_MS,
  emptyDay,
  isValidHeartRate,
  localDayNumber,
  localSlotIndex,
  SlotRecord,
  SlotState,
  SLOT_MS,
  SLOTS_PER_DAY,
  WearSource
} from './WatchLinkTypes';

// Two ticks more than this many real seconds apart: the time between them was not observed.
export const GAP_REAL_MS: number = 5000;
// Slot files kept on the watch: the current day and the two before it.
export const KEEP_DAYS: number = 3;

const DAYS_DIR: string = 'days';
const JSON_SUFFIX: string = '.json';

export class SlotRecorder {
  private store: TextStore;
  private tzOffsetMin: number;
  private speed: number = 1;
  private clockLabel: string = CLOCK_REAL;
  private wearSource: WearSource = 'HR_SIGNAL';
  private day: DayRecord | null = null;
  private dayNumber: number = -1;
  private lastRealMs: number = -1;
  private lastRecorderMs: number = -1;
  private finished: DayRecord[] = [];
  private dirty: boolean = false;

  constructor(store: TextStore, tzOffsetMin: number) {
    this.store = store;
    this.tzOffsetMin = tzOffsetMin;
  }

  // Recorder seconds per real second (1, or the demo speed) and the label that goes into the packet.
  // Changing the clock is a discontinuity: nothing is added across it.
  setClock(speed: number, label: string): void {
    this.speed = speed > 0 ? speed : 1;
    this.clockLabel = label;
    this.pause();
  }

  setWearSource(source: WearSource): void {
    this.wearSource = source;
    if (this.day !== null && !this.day.sealed) {
      this.day.wearSource = source;
    }
  }

  // Call when observation stops (app to background, sensors off). The next tick starts a new stretch;
  // the time in between stays not observed.
  pause(): void {
    this.lastRealMs = -1;
    this.lastRecorderMs = -1;
    this.persist();
  }

  // One observation, about once per real second.
  //   state        what the wear state machine says now; pass 'U' when there is no sensor signal
  //   hrBpmOrNull  a heart-rate reading taken since the last tick, or null
  //   stepsDelta   steps counted since the last tick
  tick(realMs: number, recorderMs: number, state: SlotState, hrBpmOrNull: number | null, stepsDelta: number): void {
    if (state === 'U') {
      this.lastRealMs = -1;
      this.lastRecorderMs = -1;
      return;
    }
    if (!this.moveTo(recorderMs)) {
      // The clock points into a finished day or went backwards: not observed.
      this.lastRealMs = -1;
      this.lastRecorderMs = -1;
      return;
    }
    const realDt = realMs - this.lastRealMs;
    const recorderDt = recorderMs - this.lastRecorderMs;
    const continuous = this.lastRealMs >= 0 && realDt >= 0 && realDt <= GAP_REAL_MS &&
      recorderDt >= 0 && recorderDt <= GAP_REAL_MS * this.speed;
    if (continuous) {
      this.addTime(this.lastRecorderMs, recorderMs, state);
    }
    const slot = this.slotAt(recorderMs);
    if (slot !== null) {
      if (hrBpmOrNull !== null && isValidHeartRate(hrBpmOrNull)) {
        slot.hrSampleCount += 1;
        slot.hrSum += hrBpmOrNull;
      }
      if (stepsDelta > 0) {
        slot.steps += Math.round(stepsDelta);
      }
    }
    this.lastRealMs = realMs;
    this.lastRecorderMs = recorderMs;
    // The file is rewritten when a slot closed or a day opened, not on every tick.
    if (this.dirty) {
      this.persist();
    }
  }

  // Finishes the current recorder day now; the slots not reached stay U. The caller then moves the
  // recorder clock to the next local midnight. Returns the finished day, or null when nothing was recorded.
  closeDayNow(): DayRecord | null {
    const day = this.day;
    if (day === null || day.sealed) {
      return null;
    }
    this.sealCurrent(false);
    this.lastRealMs = -1;
    this.lastRecorderMs = -1;
    return day;
  }

  // Finished days whose packet has not been built yet, oldest first. Call markPacked() once the packet
  // is safely in the outbox; until then the day is offered again after a restart.
  takeFinishedDays(): DayRecord[] {
    const out = this.finished;
    this.finished = [];
    return out;
  }

  markPacked(date: string): void {
    const day = this.loadDay(date);
    if (day === null) {
      return;
    }
    day.packed = true;
    this.store.writeAtomic(dayFilePath(date), dayRecordToJson(day));
    if (this.day !== null && this.day.date === date) {
      this.day.packed = true;
    }
  }

  currentDay(): DayRecord | null {
    return this.day;
  }

  // The stored record of a date, or null. Used for "yesterday" when a packet is built.
  loadDay(date: string): DayRecord | null {
    if (this.day !== null && this.day.date === date) {
      return this.day;
    }
    const text = this.store.read(dayFilePath(date));
    if (text === null) {
      return null;
    }
    return dayRecordFromJson(text);
  }

  // The day so far as 288 characters, for the dial. Slots not reached yet are U, and so is the open
  // slot until half of it has been observed.
  slotString(): string {
    const day = this.day;
    if (day === null) {
      return 'U'.repeat(SLOTS_PER_DAY);
    }
    return slotsToString(day);
  }

  // Index of the slot being filled, or -1.
  openSlotIndex(): number {
    if (this.day === null || this.day.sealed || this.lastRecorderMs < 0) {
      return -1;
    }
    return localSlotIndex(this.lastRecorderMs, this.tzOffsetMin);
  }

  // Makes the day and slot of `recorderMs` the current position, closing every slot before it.
  // False when that instant cannot be recorded.
  private moveTo(recorderMs: number): boolean {
    const dayNumber = localDayNumber(recorderMs, this.tzOffsetMin);
    const idx = localSlotIndex(recorderMs, this.tzOffsetMin);
    if (this.day === null) {
      this.recoverOlderDays(dayNumber);
      this.openDay(dayNumber);
    } else if (dayNumber < this.dayNumber) {
      return false;
    } else if (dayNumber > this.dayNumber) {
      this.sealCurrent(true);
      this.openDay(dayNumber);
    }
    const day = this.day;
    if (day === null || day.sealed || idx < day.closedCount) {
      return false;
    }
    if (idx > day.closedCount) {
      day.closedCount = idx;
      this.dirty = true;
    }
    return true;
  }

  private slotAt(recorderMs: number): SlotRecord | null {
    const day = this.day;
    if (day === null || day.sealed || localDayNumber(recorderMs, this.tzOffsetMin) !== this.dayNumber) {
      return null;
    }
    return day.slots[localSlotIndex(recorderMs, this.tzOffsetMin)];
  }

  // Adds the recorder time between two instants to the slots it falls into. moveTo(toMs) has already
  // run, so every slot before the last one is closed; only seconds are added here.
  private addTime(fromMs: number, toMs: number, state: SlotState): void {
    const day = this.day;
    if (day === null) {
      return;
    }
    const dayStartMs = this.dayNumber * DAY_MS - this.tzOffsetMin * 60000;
    let t = fromMs < dayStartMs ? dayStartMs : fromMs;
    // Time before this day's midnight belonged to the day that was sealed in moveTo(); add it there
    // only through the record still in memory.
    if (fromMs < dayStartMs) {
      this.addToPrevious(fromMs, dayStartMs, state);
    }
    while (t < toMs) {
      const idx = Math.floor((t - dayStartMs) / SLOT_MS);
      if (idx < 0 || idx >= SLOTS_PER_DAY) {
        break;
      }
      const slotEnd = dayStartMs + (idx + 1) * SLOT_MS;
      const segEnd = slotEnd < toMs ? slotEnd : toMs;
      addSeconds(day.slots[idx], (segEnd - t) / 1000, state);
      t = segEnd;
    }
  }

  // A continuous tick that crossed midnight: the seconds before midnight go to the day just sealed.
  private addToPrevious(fromMs: number, midnightMs: number, state: SlotState): void {
    if (this.finished.length === 0) {
      return;
    }
    const previous = this.finished[this.finished.length - 1];
    if (previous.date !== dateOfDayNumber(this.dayNumber - 1)) {
      return;
    }
    const prevStartMs = midnightMs - DAY_MS;
    let t = fromMs < prevStartMs ? prevStartMs : fromMs;
    while (t < midnightMs) {
      const idx = Math.floor((t - prevStartMs) / SLOT_MS);
      if (idx < 0 || idx >= SLOTS_PER_DAY) {
        break;
      }
      const slotEnd = prevStartMs + (idx + 1) * SLOT_MS;
      const segEnd = slotEnd < midnightMs ? slotEnd : midnightMs;
      addSeconds(previous.slots[idx], (segEnd - t) / 1000, state);
      t = segEnd;
    }
    this.store.writeAtomic(dayFilePath(previous.date), dayRecordToJson(previous));
  }

  private openDay(dayNumber: number): void {
    const date = dateOfDayNumber(dayNumber);
    const text = this.store.read(dayFilePath(date));
    let day: DayRecord | null = text === null ? null : dayRecordFromJson(text);
    if (day === null) {
      day = emptyDay(date, this.tzOffsetMin);
    }
    if (!day.sealed) {
      day.wearSource = this.wearSource;
      if (this.clockLabel !== CLOCK_REAL) {
        day.clock = this.clockLabel;
      }
    }
    this.day = day;
    this.dayNumber = dayNumber;
    this.prune(dayNumber);
    this.dirty = true;
  }

  // Marks the current day finished and queues it for packing.
  private sealCurrent(natural: boolean): void {
    const day = this.day;
    if (day === null || day.sealed) {
      return;
    }
    if (this.clockLabel !== CLOCK_REAL) {
      day.clock = this.clockLabel;
    }
    if (natural) {
      day.closedCount = SLOTS_PER_DAY;
    }
    day.sealed = true;
    this.store.writeAtomic(dayFilePath(day.date), dayRecordToJson(day));
    this.finished.push(day);
  }

  // At startup: days left on disk from an earlier run. An unfinished older day is finished as it is;
  // a finished day whose packet never reached the outbox is offered again.
  private recoverOlderDays(currentDayNumber: number): void {
    const names: string[] = this.store.list(DAYS_DIR).slice().sort();
    for (let i = 0; i < names.length; i++) {
      const name = names[i];
      if (!name.endsWith(JSON_SUFFIX)) {
        continue;
      }
      const date = name.substring(0, name.length - JSON_SUFFIX.length);
      const dayNumber = dayNumberOfDate(date);
      if (dayNumber < 0 || dayNumber >= currentDayNumber) {
        continue;
      }
      const text = this.store.read(dayFilePath(date));
      const day: DayRecord | null = text === null ? null : dayRecordFromJson(text);
      if (day === null || day.packed) {
        continue;
      }
      if (!day.sealed) {
        day.sealed = true;
        this.store.writeAtomic(dayFilePath(date), dayRecordToJson(day));
      }
      this.finished.push(day);
    }
  }

  private prune(currentDayNumber: number): void {
    const names: string[] = this.store.list(DAYS_DIR);
    for (let i = 0; i < names.length; i++) {
      const name = names[i];
      if (!name.endsWith(JSON_SUFFIX)) {
        continue;
      }
      const dayNumber = dayNumberOfDate(name.substring(0, name.length - JSON_SUFFIX.length));
      if (dayNumber >= 0 && dayNumber <= currentDayNumber - KEEP_DAYS) {
        const text = this.store.read(`${DAYS_DIR}/${name}`);
        const day: DayRecord | null = text === null ? null : dayRecordFromJson(text);
        // A day whose packet is not in the outbox yet is never deleted.
        if (day === null || day.packed) {
          this.store.remove(`${DAYS_DIR}/${name}`);
        }
      }
    }
  }

  private persist(): void {
    const day = this.day;
    if (day === null || day.sealed) {
      return;
    }
    this.store.writeAtomic(dayFilePath(day.date), dayRecordToJson(day));
    this.dirty = false;
  }
}

function addSeconds(slot: SlotRecord, seconds: number, state: SlotState): void {
  if (seconds <= 0) {
    return;
  }
  slot.observedSec += seconds;
  if (state === 'W') {
    slot.wornSec += seconds;
  } else if (state === 'C') {
    slot.chargingSec += seconds;
  } else if (state === 'O') {
    slot.offSec += seconds;
  }
}

// 288 characters for a day. A slot that was never reached has no observed time, so it comes out as U.
export function slotsToString(day: DayRecord): string {
  let out = '';
  for (let i = 0; i < SLOTS_PER_DAY; i++) {
    out += classifySlot(day.slots[i]);
  }
  return out;
}
