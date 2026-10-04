/**
 * HsSimStore: healthStore-shaped reader over a dataset received from the simulator.
 * FairWear wraps it in its own data-source interface. A real adapter over
 * @kit.HealthServiceKit would implement the same HsHealthStore interface.
 */
import {
  HS_ERROR_NOT_AUTHORIZED,
  HsDataset,
  HsDataType,
  HsError,
  HsEvent,
  HsEventKind,
  HsFields,
  HsHealthStore,
  HsPayload,
  HsReadRequest,
  HsSamplePoint,
  SLOT_MS
} from './HsTypes';
import { HsCodec } from './HsCodec';

function typeToKind(dataType: string): number {
  if (dataType === HsDataType.RESTING_HR) {
    return HsEventKind.RESTING_HR;
  }
  if (dataType === HsDataType.SLEEP_FRAGMENT) {
    return HsEventKind.SLEEP;
  }
  if (dataType === HsDataType.SPO2) {
    return HsEventKind.SPO2;
  }
  if (dataType === HsDataType.SKIN_TEMP) {
    return HsEventKind.SKIN_TEMP;
  }
  if (dataType === HsDataType.STRESS) {
    return HsEventKind.STRESS;
  }
  if (dataType === HsDataType.VO2MAX) {
    return HsEventKind.VO2MAX;
  }
  return 0;
}

function fieldsFor(kind: number, value: number): HsFields {
  if (kind === HsEventKind.RESTING_HR) {
    const f: HsFields = { bpm: value };
    return f;
  }
  if (kind === HsEventKind.SLEEP) {
    const f: HsFields = { stage: value };
    return f;
  }
  if (kind === HsEventKind.SPO2) {
    const f: HsFields = { spo2: value };
    return f;
  }
  if (kind === HsEventKind.SKIN_TEMP) {
    const f: HsFields = { celsius: value / 10 };
    return f;
  }
  if (kind === HsEventKind.STRESS) {
    const f: HsFields = { score: value };
    return f;
  }
  const f: HsFields = { value: value / 10 };
  return f;
}

export class HsSimStore implements HsHealthStore {
  private dataset: HsDataset;
  private granted: string[];
  private syncTypes: string[];
  private syncTimes: number[];
  private datasetIdValue: string;

  constructor(dataset: HsDataset, granted: string[], syncTypes: string[], syncTimes: number[], datasetId: string) {
    this.dataset = dataset;
    this.granted = granted;
    this.syncTypes = syncTypes;
    this.syncTimes = syncTimes;
    this.datasetIdValue = datasetId;
  }

  /** Builds a store from the JSON string the simulator returned in Want parameters. */
  static fromPayloadJson(text: string): HsSimStore {
    const p: HsPayload = HsCodec.fromJson(text);
    return new HsSimStore(HsCodec.decode(p), p.granted, p.syncTypes, p.syncTimes, p.datasetId);
  }

  init(): Promise<void> {
    return Promise.resolve();
  }

  grantedTypes(): string[] {
    return this.granted.slice(0);
  }

  datasetId(): string {
    return this.datasetIdValue;
  }

  personaId(): string {
    return this.dataset.personaId;
  }

  anchorTime(): number {
    return this.dataset.anchorMs;
  }

  windowStart(): number {
    return this.dataset.startMs;
  }

  tzOffsetMin(): number {
    return this.dataset.tzOffsetMin;
  }

  lastSyncTime(dataType: string): number {
    const i: number = this.syncTypes.indexOf(dataType);
    return i >= 0 ? this.syncTimes[i] : 0;
  }

  readData(request: HsReadRequest): Promise<HsSamplePoint[]> {
    const type: string = request.samplePointDataType;
    if (this.granted.indexOf(type) < 0) {
      return Promise.reject(new HsError(HS_ERROR_NOT_AUTHORIZED, 'Not authorized: ' + type));
    }
    return Promise.resolve(this.readSync(type, request.startTime, request.endTime));
  }

  /** Synchronous variant for tests and batch use. Samples are sorted by start time. */
  readSync(type: string, startTime: number, endTime: number): HsSamplePoint[] {
    const out: HsSamplePoint[] = [];
    const sync: number = this.lastSyncTime(type);
    const ds: HsDataset = this.dataset;
    const src: string = ds.dataSourceId;
    if (type === HsDataType.STEPS) {
      for (let i = 0; i < ds.slotCount; i++) {
        const t: number = ds.startMs + i * SLOT_MS;
        if (ds.steps[i] === 0 || t < startTime || t >= endTime || t + SLOT_MS > sync) {
          continue;
        }
        const f: HsFields = { steps: ds.steps[i] };
        const sp: HsSamplePoint = { dataType: type, startTime: t, endTime: t + SLOT_MS, dataSourceId: src, fields: f };
        out.push(sp);
      }
      return out;
    }
    if (type === HsDataType.HEART_RATE) {
      for (let i = 0; i < ds.slotCount; i++) {
        const t: number = ds.startMs + i * SLOT_MS + ds.hrOffsetSec[i] * 1000;
        if (ds.hrBpm[i] === 0 || t < startTime || t >= endTime || t > sync) {
          continue;
        }
        const f: HsFields = { bpm: ds.hrBpm[i] };
        const sp: HsSamplePoint = { dataType: type, startTime: t, endTime: t, dataSourceId: src, fields: f };
        out.push(sp);
      }
      return out;
    }
    const kind: number = typeToKind(type);
    for (let i = 0; i < ds.events.length; i++) {
      const e: HsEvent = ds.events[i];
      if (e.kind !== kind || e.startMs < startTime || e.startMs >= endTime || e.endMs > sync) {
        continue;
      }
      const sp: HsSamplePoint = {
        dataType: type,
        startTime: e.startMs,
        endTime: e.endMs,
        dataSourceId: src,
        fields: fieldsFor(kind, e.value)
      };
      out.push(sp);
    }
    return out;
  }
}
