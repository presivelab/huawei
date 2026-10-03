// Storage format of one recorder day on the watch (days/<date>.json). Slots are stored as rows of seven
// numbers so the file stays small: it is rewritten after every slot close.
import { parseJsonObject, readArray, readBoolean, readInt, readString } from './JsonRead';
import {
  dayNumberOfDate,
  DayRecord,
  emptySlot,
  SlotRecord,
  SLOTS_PER_DAY,
  WearSource
} from './WatchLinkTypes';

const DAY_FILE_VERSION: number = 1;
const ROW_LENGTH: number = 7;

class DayFile {
  v: number = DAY_FILE_VERSION;
  date: string = '';
  tzOffsetMin: number = 0;
  clock: string = '';
  wearSource: string = '';
  closedCount: number = 0;
  sealed: boolean = false;
  packed: boolean = false;
  rows: number[][] = [];
}

function round3(n: number): number {
  return Math.round(n * 1000) / 1000;
}

export function dayFilePath(date: string): string {
  return `days/${date}.json`;
}

export function dayRecordToJson(day: DayRecord): string {
  const file = new DayFile();
  file.date = day.date;
  file.tzOffsetMin = day.tzOffsetMin;
  file.clock = day.clock;
  file.wearSource = day.wearSource;
  file.closedCount = day.closedCount;
  file.sealed = day.sealed;
  file.packed = day.packed;
  for (let i = 0; i < day.slots.length; i++) {
    const s = day.slots[i];
    const row: number[] = [round3(s.observedSec), round3(s.wornSec), round3(s.chargingSec), round3(s.offSec),
      s.hrSampleCount, round3(s.hrSum), s.steps];
    file.rows.push(row);
  }
  return JSON.stringify(file);
}

// Returns null for anything that is not a complete day file. A broken file is never half-used.
export function dayRecordFromJson(text: string): DayRecord | null {
  const o = parseJsonObject(text);
  if (o === null) {
    return null;
  }
  const v = readInt(o, 'v');
  const date = readString(o, 'date');
  const tzOffsetMin = readInt(o, 'tzOffsetMin');
  const clock = readString(o, 'clock');
  const wearSource = readString(o, 'wearSource');
  const closedCount = readInt(o, 'closedCount');
  const sealed = readBoolean(o, 'sealed');
  const packed = readBoolean(o, 'packed');
  const rows = readArray(o, 'rows');
  if (v !== DAY_FILE_VERSION || date === null || tzOffsetMin === null || clock === null || wearSource === null ||
    closedCount === null || sealed === null || packed === null || rows === null) {
    return null;
  }
  if (dayNumberOfDate(date) < 0 || rows.length !== SLOTS_PER_DAY || closedCount < 0 ||
    closedCount > SLOTS_PER_DAY) {
    return null;
  }
  if (wearSource !== 'SENSOR' && wearSource !== 'HR_SIGNAL') {
    return null;
  }
  const slots: SlotRecord[] = [];
  for (let i = 0; i < rows.length; i++) {
    const raw: Object = rows[i];
    if (!Array.isArray(raw)) {
      return null;
    }
    const row = raw as Object[];
    if (row.length !== ROW_LENGTH) {
      return null;
    }
    const nums: number[] = [];
    for (let k = 0; k < row.length; k++) {
      const cell: Object = row[k];
      if (typeof cell !== 'number' || !Number.isFinite(cell as number) || (cell as number) < 0) {
        return null;
      }
      nums.push(cell as number);
    }
    const slot = emptySlot(i);
    slot.observedSec = nums[0];
    slot.wornSec = nums[1];
    slot.chargingSec = nums[2];
    slot.offSec = nums[3];
    slot.hrSampleCount = nums[4];
    slot.hrSum = nums[5];
    slot.steps = nums[6];
    slots.push(slot);
  }
  const day: DayRecord = {
    date: date,
    tzOffsetMin: tzOffsetMin,
    clock: clock,
    wearSource: wearSource as WearSource,
    closedCount: closedCount,
    sealed: sealed,
    packed: packed,
    slots: slots
  };
  return day;
}
