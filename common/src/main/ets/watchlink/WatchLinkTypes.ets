// Watch Link data contract: what the watch records, and the packets that travel between watch and phone.
// Pure types and constants. No system-kit imports: this file runs in the Node logic tests.
//
// The watch measures, the phone judges. Nothing in these types is a verdict: no "compliant", no "suspicious",
// no tier. Those stay in the rule code on the phone.

// One 5-minute slot of the day as the watch saw it.
//   W  worn
//   C  charging
//   O  off-wrist, observed
//   U  unknown: the app was not observing
// Fairness rule: U is never O. An unobserved slot is never a break and never counts as worn.
export type SlotState = 'W' | 'C' | 'O' | 'U';

export type WearSource = 'SENSOR' | 'HR_SIGNAL';

export const SLOT_MINUTES: number = 5;
export const SLOT_MS: number = 300000;
export const SLOTS_PER_DAY: number = 288;
export const SLOTS_PER_HOUR: number = 12;
export const DAY_MS: number = 86400000;
export const DAY_MINUTES: number = 1440;

// A slot observed for less than this many seconds (half of it) is U.
export const MIN_OBSERVED_SEC: number = 150;

// Night window 00:00-06:00 local: slots 0..71.
export const NIGHT_SLOT_COUNT: number = 72;

// Resting estimate window 07:00-23:00 local: slots 84..275.
export const REST_FIRST_SLOT: number = 84;
export const REST_LAST_SLOT: number = 275;
export const REST_MIN_SLOTS: number = 6;

export const MAX_BREAKS: number = 12;

// A heart-rate reading outside this range is not a reading (0 means "no signal").
export const HR_MIN_BPM: number = 25;
export const HR_MAX_BPM: number = 230;

export const PACKET_VERSION: number = 1;
export const TYPE_DAY: string = 'DAY';
export const TYPE_PAIR: string = 'PAIR';
export const TYPE_ACK: string = 'ACK';
export const GENESIS: string = 'GENESIS';
export const PAIR_ALG: string = 'ECDSA_P256_SHA256';
export const CLOCK_REAL: string = 'REAL';

// A Wear Engine P2P message carries at most 4096 bytes; day packets stay below this.
export const MAX_PACKET_BYTES: number = 3800;

export const NO_VALUE: number = -1;

// Raw sums for one slot. Seconds are recorder seconds (demo clock seconds while the demo clock runs).
export interface SlotRecord {
  idx: number;            // 0..287
  observedSec: number;
  wornSec: number;
  chargingSec: number;
  offSec: number;
  hrSampleCount: number;
  hrSum: number;
  steps: number;
}

// One recorder day on the watch, as stored in days/<date>.json.
export interface DayRecord {
  date: string;           // YYYY-MM-DD, local
  tzOffsetMin: number;    // minutes east of UTC
  clock: string;          // 'REAL', or the demo label once any part of the day ran on the demo clock
  wearSource: WearSource;
  closedCount: number;    // slots 0..closedCount-1 are closed
  sealed: boolean;        // the day is finished; no more time is added
  packed: boolean;        // its day packet is in the outbox
  slots: SlotRecord[];    // always 288
}

// Measured context of one off-wrist break. Inputs for the phone's break rule, not a verdict.
export interface BreakContext {
  startMin: number;           // minutes from the packet day's 00:00; negative when it began the day before
  endMin: number;
  hrSlots24hBefore: number;   // worn slots with at least one heart-rate sample in the 24 h before the start
  rhr24hBefore: number;       // median of per-slot mean heart rate over worn, zero-step slots in those 24 h; -1 if none
  steps24hBefore: number;
}

export interface DayPacket {
  v: number;
  type: string;               // 'DAY'
  kid: string;                // watch key id, 8 hex
  seq: number;                // 1, 2, 3...
  prev: string;               // 'GENESIS' for seq 1, else the hash of the previous packet
  date: string;               // YYYY-MM-DD, local
  tzOffsetMin: number;
  slots: string;              // exactly 288 characters of W / C / O / U
  stepsByHour: number[];      // 24
  hrRestEst: number;          // resting estimate for break context only; never used as the score's resting heart rate
  hrSlotCount: number;
  nightWornMin: number;
  nightChargingMin: number;
  breaks: BreakContext[];     // at most 12
  wearSource: WearSource;
  clock: string;              // 'REAL' | 'DEMO_X300' ...
  iat: number;                // epoch seconds
  sig: string;
}

export interface PairPacket {
  v: number;
  type: string;               // 'PAIR'
  kid: string;
  pub: string;                // public key, X.509 SubjectPublicKeyInfo DER, base64url
  alg: string;                // 'ECDSA_P256_SHA256'
  iat: number;
  sig: string;                // self-signed
}

export type AckStatus = 'ACCEPTED' | 'DUPLICATE' | 'REJECTED';

// ACKs are signed by the phone since version 2. An unsigned version-1 ACK is refused by the watch.
export const ACK_VERSION: number = 2;

// The phone's answer to one packet, signed with the phone's own Watch Link key.
//   phoneKid / phonePub  the phone key; the watch pins it when the pairing is accepted
//   watchKid             the watch the answer is meant for
//   ref                  hash of the signing string of the packet answered (day or pairing request), so an
//                        answer cannot be moved to another packet with the same seq; '' when it did not decode
export interface AckPacket {
  v: number;
  type: string;               // 'ACK'
  seq: number;
  status: AckStatus;
  reason: string;
  watchKid: string;
  ref: string;
  phoneKid: string;
  phonePub: string;
  iat: number;
  sig: string;
}

export function emptySlot(idx: number): SlotRecord {
  const slot: SlotRecord = {
    idx: idx,
    observedSec: 0,
    wornSec: 0,
    chargingSec: 0,
    offSec: 0,
    hrSampleCount: 0,
    hrSum: 0,
    steps: 0
  };
  return slot;
}

export function emptyDay(date: string, tzOffsetMin: number): DayRecord {
  const slots: SlotRecord[] = [];
  for (let i = 0; i < SLOTS_PER_DAY; i++) {
    slots.push(emptySlot(i));
  }
  const day: DayRecord = {
    date: date,
    tzOffsetMin: tzOffsetMin,
    clock: CLOCK_REAL,
    wearSource: 'HR_SIGNAL',
    closedCount: 0,
    sealed: false,
    packed: false,
    slots: slots
  };
  return day;
}

// Classification of a closed slot. Under 150 observed seconds: U. Otherwise the largest of charging, worn
// and off seconds; on a tie charging wins over worn, worn over off.
export function classifySlot(slot: SlotRecord): SlotState {
  if (slot.observedSec < MIN_OBSERVED_SEC) {
    return 'U';
  }
  if (slot.chargingSec >= slot.wornSec && slot.chargingSec >= slot.offSec) {
    return 'C';
  }
  if (slot.wornSec >= slot.offSec) {
    return 'W';
  }
  return 'O';
}

export function isValidHeartRate(bpm: number): boolean {
  return bpm >= HR_MIN_BPM && bpm <= HR_MAX_BPM;
}

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

// Local day number (days since 1970-01-01 in local time) of an epoch instant.
export function localDayNumber(epochMs: number, tzOffsetMin: number): number {
  return Math.floor((epochMs + tzOffsetMin * 60000) / DAY_MS);
}

// Slot index 0..287 of an epoch instant in local time.
export function localSlotIndex(epochMs: number, tzOffsetMin: number): number {
  const localMs = epochMs + tzOffsetMin * 60000;
  const inDay = localMs - Math.floor(localMs / DAY_MS) * DAY_MS;
  return Math.floor(inDay / SLOT_MS);
}

// Epoch ms at which the given slot of the given local day starts.
export function slotStartMs(dayNumber: number, slotIdx: number, tzOffsetMin: number): number {
  return dayNumber * DAY_MS + slotIdx * SLOT_MS - tzOffsetMin * 60000;
}

export function dateOfDayNumber(dayNumber: number): string {
  const d = new Date(dayNumber * DAY_MS);
  return `${d.getUTCFullYear()}-${pad2(d.getUTCMonth() + 1)}-${pad2(d.getUTCDate())}`;
}

// Day number of a YYYY-MM-DD date, or -1 when the text is not a real calendar date.
export function dayNumberOfDate(date: string): number {
  if (date.length !== 10 || date.charAt(4) !== '-' || date.charAt(7) !== '-') {
    return NO_VALUE;
  }
  const digits = date.substring(0, 4) + date.substring(5, 7) + date.substring(8, 10);
  for (let i = 0; i < digits.length; i++) {
    const c = digits.charCodeAt(i);
    if (c < 48 || c > 57) {
      return NO_VALUE;
    }
  }
  const y = Number.parseInt(date.substring(0, 4), 10);
  const m = Number.parseInt(date.substring(5, 7), 10);
  const d = Number.parseInt(date.substring(8, 10), 10);
  const ms = Date.UTC(y, m - 1, d);
  const dayNumber = Math.floor(ms / DAY_MS);
  if (dateOfDayNumber(dayNumber) !== date) {
    return NO_VALUE;
  }
  return dayNumber;
}

export function median(values: number[]): number {
  if (values.length === 0) {
    return NO_VALUE;
  }
  const sorted: number[] = values.slice().sort((a: number, b: number) => a - b);
  const mid = Math.floor(sorted.length / 2);
  if (sorted.length % 2 === 1) {
    return sorted[mid];
  }
  return (sorted[mid - 1] + sorted[mid]) / 2;
}
