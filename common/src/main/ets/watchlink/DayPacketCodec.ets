// JSON for the three Watch Link packets, with full validation on the way in.
// fromJson never throws and never returns a half-valid packet: a typed result or a reason.
import { EARLIEST_BREAK_START_MIN } from './DayBuilder';
import { asObject, parseJsonObject, readArray, readInt, readIntArray, readString } from './JsonRead';
import {
  AckPacket,
  AckStatus,
  BreakContext,
  dayNumberOfDate,
  DayPacket,
  DAY_MINUTES,
  MAX_BREAKS,
  NO_VALUE,
  PACKET_VERSION,
  PAIR_ALG,
  PairPacket,
  SLOTS_PER_DAY,
  TYPE_ACK,
  TYPE_DAY,
  TYPE_PAIR,
  WearSource
} from './WatchLinkTypes';

export type DecodeCode = 'OK' | 'FORMAT' | 'VERSION';

const MAX_INT: number = 2147483647;
const MAX_TZ_MIN: number = 14 * 60;
const KID_LENGTH: number = 8;
const MAX_TEXT: number = 512;

// An ACK with this seq answers the pairing request, not a day packet.
export const PAIR_ACK_SEQ: number = 0;

export class DayDecodeResult {
  code: DecodeCode = 'FORMAT';
  reason: string = '';
  packet: DayPacket | null = null;
}

export class PairDecodeResult {
  code: DecodeCode = 'FORMAT';
  reason: string = '';
  packet: PairPacket | null = null;
}

export class AckDecodeResult {
  code: DecodeCode = 'FORMAT';
  reason: string = '';
  packet: AckPacket | null = null;
}

function isKid(text: string): boolean {
  if (text.length !== KID_LENGTH) {
    return false;
  }
  for (let i = 0; i < text.length; i++) {
    const c = text.charCodeAt(i);
    const digit = c >= 48 && c <= 57;
    const lowerHex = c >= 97 && c <= 102;
    if (!digit && !lowerHex) {
      return false;
    }
  }
  return true;
}

function isSlots(text: string): boolean {
  if (text.length !== SLOTS_PER_DAY) {
    return false;
  }
  for (let i = 0; i < text.length; i++) {
    const ch = text.charAt(i);
    if (ch !== 'W' && ch !== 'C' && ch !== 'O' && ch !== 'U') {
      return false;
    }
  }
  return true;
}

// Printable ASCII without line breaks: these fields go into the signing string one per line.
function isPlainToken(text: string): boolean {
  if (text.length === 0 || text.length > MAX_TEXT) {
    return false;
  }
  for (let i = 0; i < text.length; i++) {
    const c = text.charCodeAt(i);
    if (c < 33 || c > 126) {
      return false;
    }
  }
  return true;
}

function readBreak(raw: Object): BreakContext | null {
  const o = asObject(raw);
  if (o === null) {
    return null;
  }
  const startMin = readInt(o, 'startMin');
  const endMin = readInt(o, 'endMin');
  const hrSlots = readInt(o, 'hrSlots24hBefore');
  const rhr = readInt(o, 'rhr24hBefore');
  const steps = readInt(o, 'steps24hBefore');
  if (startMin === null || endMin === null || hrSlots === null || rhr === null || steps === null) {
    return null;
  }
  if (startMin < EARLIEST_BREAK_START_MIN || endMin < 0 || endMin >= DAY_MINUTES || endMin <= startMin) {
    return null;
  }
  if (hrSlots < 0 || hrSlots > SLOTS_PER_DAY || rhr < NO_VALUE || rhr > 255 || steps < 0 || steps > MAX_INT) {
    return null;
  }
  const b: BreakContext = {
    startMin: startMin,
    endMin: endMin,
    hrSlots24hBefore: hrSlots,
    rhr24hBefore: rhr,
    steps24hBefore: steps
  };
  return b;
}

export class DayPacketCodec {
  static toJson(p: DayPacket): string {
    return JSON.stringify(p);
  }

  static fromJson(text: string): DayDecodeResult {
    const out = new DayDecodeResult();
    const o = parseJsonObject(text);
    if (o === null) {
      out.reason = 'not a JSON object';
      return out;
    }
    const v = readInt(o, 'v');
    const type = readString(o, 'type');
    if (v === null || type === null) {
      out.reason = 'v or type missing';
      return out;
    }
    if (v !== PACKET_VERSION || type !== TYPE_DAY) {
      out.code = 'VERSION';
      out.reason = `v ${v}, type ${type}`;
      return out;
    }
    const kid = readString(o, 'kid');
    const seq = readInt(o, 'seq');
    const prev = readString(o, 'prev');
    const date = readString(o, 'date');
    const tzOffsetMin = readInt(o, 'tzOffsetMin');
    const slots = readString(o, 'slots');
    const stepsByHour = readIntArray(o, 'stepsByHour', 0, MAX_INT);
    const hrRestEst = readInt(o, 'hrRestEst');
    const hrSlotCount = readInt(o, 'hrSlotCount');
    const nightWornMin = readInt(o, 'nightWornMin');
    const nightChargingMin = readInt(o, 'nightChargingMin');
    const rawBreaks = readArray(o, 'breaks');
    const wearSource = readString(o, 'wearSource');
    const clock = readString(o, 'clock');
    const iat = readInt(o, 'iat');
    const sig = readString(o, 'sig');
    if (kid === null || seq === null || prev === null || date === null || tzOffsetMin === null || slots === null ||
      stepsByHour === null || hrRestEst === null || hrSlotCount === null || nightWornMin === null ||
      nightChargingMin === null || rawBreaks === null || wearSource === null || clock === null || iat === null ||
      sig === null) {
      out.reason = 'a field is missing or has the wrong type';
      return out;
    }
    if (!isKid(kid)) {
      out.reason = 'kid is not 8 hex characters';
      return out;
    }
    if (seq < 1 || seq > MAX_INT) {
      out.reason = 'seq out of range';
      return out;
    }
    if (!isPlainToken(prev) || !isPlainToken(clock) || !isPlainToken(sig)) {
      out.reason = 'prev, clock or sig is not a plain token';
      return out;
    }
    if (dayNumberOfDate(date) < 0) {
      out.reason = 'date is not YYYY-MM-DD';
      return out;
    }
    if (tzOffsetMin < -MAX_TZ_MIN || tzOffsetMin > MAX_TZ_MIN) {
      out.reason = 'tzOffsetMin out of range';
      return out;
    }
    if (!isSlots(slots)) {
      out.reason = 'slots is not 288 characters of W/C/O/U';
      return out;
    }
    if (stepsByHour.length !== 24) {
      out.reason = 'stepsByHour is not 24 non-negative integers';
      return out;
    }
    if (hrRestEst < NO_VALUE || hrRestEst > 255 || hrSlotCount < 0 || hrSlotCount > SLOTS_PER_DAY) {
      out.reason = 'hrRestEst or hrSlotCount out of range';
      return out;
    }
    if (nightWornMin < 0 || nightChargingMin < 0 || nightWornMin + nightChargingMin > 360) {
      out.reason = 'night minutes out of range';
      return out;
    }
    if (rawBreaks.length > MAX_BREAKS) {
      out.reason = 'more than 12 breaks';
      return out;
    }
    const breaks: BreakContext[] = [];
    for (let i = 0; i < rawBreaks.length; i++) {
      const b = readBreak(rawBreaks[i]);
      if (b === null) {
        out.reason = `break ${i} is malformed`;
        return out;
      }
      breaks.push(b);
    }
    if (wearSource !== 'SENSOR' && wearSource !== 'HR_SIGNAL') {
      out.reason = 'wearSource is not SENSOR or HR_SIGNAL';
      return out;
    }
    if (iat < 0) {
      out.reason = 'iat is negative';
      return out;
    }
    const packet: DayPacket = {
      v: v,
      type: type,
      kid: kid,
      seq: seq,
      prev: prev,
      date: date,
      tzOffsetMin: tzOffsetMin,
      slots: slots,
      stepsByHour: stepsByHour,
      hrRestEst: hrRestEst,
      hrSlotCount: hrSlotCount,
      nightWornMin: nightWornMin,
      nightChargingMin: nightChargingMin,
      breaks: breaks,
      wearSource: wearSource as WearSource,
      clock: clock,
      iat: iat,
      sig: sig
    };
    out.code = 'OK';
    out.packet = packet;
    return out;
  }
}

export class PairPacketCodec {
  static toJson(p: PairPacket): string {
    return JSON.stringify(p);
  }

  static fromJson(text: string): PairDecodeResult {
    const out = new PairDecodeResult();
    const o = parseJsonObject(text);
    if (o === null) {
      out.reason = 'not a JSON object';
      return out;
    }
    const v = readInt(o, 'v');
    const type = readString(o, 'type');
    if (v === null || type === null) {
      out.reason = 'v or type missing';
      return out;
    }
    if (v !== PACKET_VERSION || type !== TYPE_PAIR) {
      out.code = 'VERSION';
      out.reason = `v ${v}, type ${type}`;
      return out;
    }
    const kid = readString(o, 'kid');
    const pub = readString(o, 'pub');
    const alg = readString(o, 'alg');
    const iat = readInt(o, 'iat');
    const sig = readString(o, 'sig');
    if (kid === null || pub === null || alg === null || iat === null || sig === null) {
      out.reason = 'a field is missing or has the wrong type';
      return out;
    }
    if (!isKid(kid) || !isPlainToken(pub) || !isPlainToken(sig) || iat < 0) {
      out.reason = 'kid, pub, sig or iat is malformed';
      return out;
    }
    if (alg !== PAIR_ALG) {
      out.code = 'VERSION';
      out.reason = `alg ${alg}`;
      return out;
    }
    const packet: PairPacket = { v: v, type: type, kid: kid, pub: pub, alg: alg, iat: iat, sig: sig };
    out.code = 'OK';
    out.packet = packet;
    return out;
  }
}

export class AckPacketCodec {
  static make(seq: number, status: AckStatus, reason: string): AckPacket {
    const ack: AckPacket = { v: PACKET_VERSION, type: TYPE_ACK, seq: seq, status: status, reason: reason };
    return ack;
  }

  static toJson(p: AckPacket): string {
    return JSON.stringify(p);
  }

  static fromJson(text: string): AckDecodeResult {
    const out = new AckDecodeResult();
    const o = parseJsonObject(text);
    if (o === null) {
      out.reason = 'not a JSON object';
      return out;
    }
    const v = readInt(o, 'v');
    const type = readString(o, 'type');
    if (v === null || type === null) {
      out.reason = 'v or type missing';
      return out;
    }
    if (v !== PACKET_VERSION || type !== TYPE_ACK) {
      out.code = 'VERSION';
      out.reason = `v ${v}, type ${type}`;
      return out;
    }
    const seq = readInt(o, 'seq');
    const status = readString(o, 'status');
    const reason = readString(o, 'reason');
    if (seq === null || status === null || reason === null || seq < PAIR_ACK_SEQ || reason.length > MAX_TEXT) {
      out.reason = 'a field is missing or has the wrong type';
      return out;
    }
    if (status !== 'ACCEPTED' && status !== 'DUPLICATE' && status !== 'REJECTED') {
      out.reason = 'unknown status';
      return out;
    }
    out.code = 'OK';
    out.packet = AckPacketCodec.make(seq, status as AckStatus, reason);
    return out;
  }
}
