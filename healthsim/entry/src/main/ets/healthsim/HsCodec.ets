/**
 * Compact codec for handing a dataset to FairWear through Want parameters.
 * WantParams are limited to 100 KB, so slots are packed as bytes and base64-encoded.
 * 30 days with every type granted is about 65 KB of JSON.
 */
import {
  HS_PAYLOAD_FORMAT,
  HsDataset,
  HsDataType,
  HsEvent,
  HsEventKind,
  HsPayload,
  MINUTE_MS,
  SLOT_MINUTES,
  SLOT_MS
} from './HsTypes';
import { hashBytes, toHex8 } from './HsRandom';

const B64: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

/** Want parameter keys. */
export class HsWantKeys {
  static readonly TYPES: string = 'types';
  static readonly DAYS: string = 'days';
  static readonly REQUESTER: string = 'requester';
  static readonly PAYLOAD: string = 'payload';
  static readonly STATUS: string = 'status';
}

/** Sync delay per type when "simulate sync delay" is on (minutes behind the anchor). */
export class HsSyncDelay {
  static minutesFor(dataType: string): number {
    if (dataType === HsDataType.SLEEP_FRAGMENT || dataType === HsDataType.SPO2 ||
      dataType === HsDataType.SKIN_TEMP) {
      return 60;
    }
    return 15;
  }
}

export function base64Encode(bytes: Uint8Array): string {
  const parts: string[] = [];
  let i: number = 0;
  for (; i + 2 < bytes.length; i += 3) {
    const n: number = (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2];
    parts.push(B64.charAt((n >> 18) & 63) + B64.charAt((n >> 12) & 63) + B64.charAt((n >> 6) & 63) +
      B64.charAt(n & 63));
  }
  const rest: number = bytes.length - i;
  if (rest === 1) {
    const n: number = bytes[i] << 16;
    parts.push(B64.charAt((n >> 18) & 63) + B64.charAt((n >> 12) & 63) + '==');
  } else if (rest === 2) {
    const n: number = (bytes[i] << 16) | (bytes[i + 1] << 8);
    parts.push(B64.charAt((n >> 18) & 63) + B64.charAt((n >> 12) & 63) + B64.charAt((n >> 6) & 63) + '=');
  }
  return parts.join('');
}

export function base64Decode(text: string): Uint8Array {
  let clean: string = text;
  while (clean.length > 0 && clean.charAt(clean.length - 1) === '=') {
    clean = clean.substring(0, clean.length - 1);
  }
  const outLen: number = Math.floor(clean.length * 3 / 4);
  const out: Uint8Array = new Uint8Array(outLen);
  let buffer: number = 0;
  let bits: number = 0;
  let o: number = 0;
  for (let i = 0; i < clean.length; i++) {
    const v: number = B64.indexOf(clean.charAt(i));
    if (v < 0) {
      continue;
    }
    buffer = ((buffer << 6) | v) & 0xffffff;
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      if (o < outLen) {
        out[o] = (buffer >> bits) & 0xff;
      }
      o++;
    }
  }
  return out;
}

function kindToType(kind: number): string {
  if (kind === HsEventKind.RESTING_HR) {
    return HsDataType.RESTING_HR;
  }
  if (kind === HsEventKind.SLEEP) {
    return HsDataType.SLEEP_FRAGMENT;
  }
  if (kind === HsEventKind.SPO2) {
    return HsDataType.SPO2;
  }
  if (kind === HsEventKind.SKIN_TEMP) {
    return HsDataType.SKIN_TEMP;
  }
  if (kind === HsEventKind.STRESS) {
    return HsDataType.STRESS;
  }
  return HsDataType.VO2MAX;
}

function packSteps(ds: HsDataset): Uint8Array {
  const b: Uint8Array = new Uint8Array(ds.slotCount * 2);
  for (let i = 0; i < ds.slotCount; i++) {
    b[2 * i] = ds.steps[i] & 0xff;
    b[2 * i + 1] = (ds.steps[i] >> 8) & 0xff;
  }
  return b;
}

function packHeartRate(ds: HsDataset): Uint8Array {
  const b: Uint8Array = new Uint8Array(ds.slotCount * 2);
  for (let i = 0; i < ds.slotCount; i++) {
    b[2 * i] = ds.hrBpm[i];
    b[2 * i + 1] = ds.hrBpm[i] > 0 ? ds.hrOffsetSec[i] - 90 : 0;
  }
  return b;
}

function packEvents(ds: HsDataset, granted: string[]): Uint8Array {
  const list: HsEvent[] = [];
  for (let i = 0; i < ds.events.length; i++) {
    if (granted.indexOf(kindToType(ds.events[i].kind)) >= 0) {
      list.push(ds.events[i]);
    }
  }
  const b: Uint8Array = new Uint8Array(list.length * 7);
  for (let i = 0; i < list.length; i++) {
    const e: HsEvent = list[i];
    const startMin: number = Math.round((e.startMs - ds.startMs) / MINUTE_MS);
    const durMin: number = Math.round((e.endMs - e.startMs) / MINUTE_MS);
    const v: number = e.value + 32768;
    const o: number = 7 * i;
    b[o] = e.kind;
    b[o + 1] = startMin & 0xff;
    b[o + 2] = (startMin >> 8) & 0xff;
    b[o + 3] = durMin & 0xff;
    b[o + 4] = (durMin >> 8) & 0xff;
    b[o + 5] = v & 0xff;
    b[o + 6] = (v >> 8) & 0xff;
  }
  return b;
}

export class HsCodec {
  /** Short fingerprint of the whole dataset; both apps show it so the jury can see the input is the same. */
  static datasetId(ds: HsDataset): string {
    const a: Uint8Array = packSteps(ds);
    const b: Uint8Array = packHeartRate(ds);
    const c: Uint8Array = packEvents(ds, HsDataType.all());
    const all: Uint8Array = new Uint8Array(a.length + b.length + c.length);
    all.set(a, 0);
    all.set(b, a.length);
    all.set(c, a.length + b.length);
    return toHex8(hashBytes(all));
  }

  static encode(ds: HsDataset, granted: string[], simulateSyncDelay: boolean): HsPayload {
    const p: HsPayload = new HsPayload();
    p.format = HS_PAYLOAD_FORMAT;
    p.simulated = true;
    p.personaId = ds.personaId;
    p.seed = ds.seed;
    p.anchorMs = ds.anchorMs;
    p.startMs = ds.startMs;
    p.tzOffsetMin = ds.tzOffsetMin;
    p.slotMinutes = SLOT_MINUTES;
    p.slotCount = ds.slotCount;
    p.datasetId = HsCodec.datasetId(ds);
    p.dataSourceId = ds.dataSourceId;
    const known: string[] = [];
    for (let i = 0; i < granted.length; i++) {
      if (HsDataType.isKnown(granted[i]) && known.indexOf(granted[i]) < 0) {
        known.push(granted[i]);
      }
    }
    p.granted = known;
    for (let i = 0; i < known.length; i++) {
      p.syncTypes.push(known[i]);
      const delay: number = simulateSyncDelay ? HsSyncDelay.minutesFor(known[i]) : 0;
      p.syncTimes.push(ds.anchorMs - delay * MINUTE_MS);
    }
    p.steps = known.indexOf(HsDataType.STEPS) >= 0 ? base64Encode(packSteps(ds)) : '';
    p.heartRate = known.indexOf(HsDataType.HEART_RATE) >= 0 ? base64Encode(packHeartRate(ds)) : '';
    p.events = base64Encode(packEvents(ds, known));
    return p;
  }

  static toJson(p: HsPayload): string {
    return JSON.stringify(p);
  }

  /** Parses and validates a payload string. Throws Error on anything unexpected. */
  static fromJson(text: string): HsPayload {
    const p: HsPayload = JSON.parse(text) as HsPayload;
    if (p === null || p === undefined || p.format !== HS_PAYLOAD_FORMAT) {
      throw new Error('Unknown payload format');
    }
    if (p.slotMinutes !== SLOT_MINUTES || p.slotCount <= 0) {
      throw new Error('Unsupported slot layout');
    }
    if (p.syncTypes.length !== p.syncTimes.length) {
      throw new Error('Corrupt sync table');
    }
    return p;
  }

  static decode(p: HsPayload): HsDataset {
    const ds: HsDataset = new HsDataset();
    ds.personaId = p.personaId;
    ds.seed = p.seed;
    ds.anchorMs = p.anchorMs;
    ds.startMs = p.startMs;
    ds.tzOffsetMin = p.tzOffsetMin;
    ds.slotCount = p.slotCount;
    ds.dataSourceId = p.dataSourceId;
    ds.steps = new Uint16Array(p.slotCount);
    ds.hrBpm = new Uint8Array(p.slotCount);
    ds.hrOffsetSec = new Uint8Array(p.slotCount);
    if (p.steps.length > 0) {
      const b: Uint8Array = base64Decode(p.steps);
      if (b.length !== p.slotCount * 2) {
        throw new Error('Steps length mismatch');
      }
      for (let i = 0; i < p.slotCount; i++) {
        ds.steps[i] = b[2 * i] | (b[2 * i + 1] << 8);
      }
    }
    if (p.heartRate.length > 0) {
      const b: Uint8Array = base64Decode(p.heartRate);
      if (b.length !== p.slotCount * 2) {
        throw new Error('Heart rate length mismatch');
      }
      for (let i = 0; i < p.slotCount; i++) {
        ds.hrBpm[i] = b[2 * i];
        ds.hrOffsetSec[i] = b[2 * i] > 0 ? b[2 * i + 1] + 90 : 0;
      }
    }
    const e: Uint8Array = base64Decode(p.events);
    if (e.length % 7 !== 0) {
      throw new Error('Events length mismatch');
    }
    const events: HsEvent[] = [];
    for (let o = 0; o < e.length; o += 7) {
      const startMin: number = e[o + 1] | (e[o + 2] << 8);
      const durMin: number = e[o + 3] | (e[o + 4] << 8);
      const v: number = (e[o + 5] | (e[o + 6] << 8)) - 32768;
      const start: number = p.startMs + startMin * MINUTE_MS;
      events.push(new HsEvent(e[o], start, start + durMin * MINUTE_MS, v));
    }
    ds.events = events;
    return ds;
  }

  static slotStart(ds: HsDataset, slot: number): number {
    return ds.startMs + slot * SLOT_MS;
  }
}
