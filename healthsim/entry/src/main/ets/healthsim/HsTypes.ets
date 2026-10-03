/**
 * HealthSim shared types.
 *
 * Pure ArkTS, no platform imports. The same folder is copied into FairWear
 * (common module), so both apps decode and read the data the same way.
 *
 * Shapes follow Health Service Kit (healthStore) as documented publicly:
 * a sample point has a data type, a start and end time (equal for instant
 * samples), a data source and value fields. Data type names are
 * PROVISIONAL: replace them with the samplePointHelper names from the
 * installed DevEco SDK if @kit.HealthServiceKit declarations are present.
 */

export const MINUTE_MS: number = 60000;
export const SLOT_MINUTES: number = 5;
export const SLOT_MS: number = SLOT_MINUTES * MINUTE_MS;
export const DAY_MS: number = 24 * 60 * MINUTE_MS;
export const SLOTS_PER_DAY: number = 288;
export const MAX_DAYS: number = 30;

/** Deep link the simulator answers; FairWear opens it with openLink. */
export const HS_BUNDLE_NAME: string = 'com.fairwear.healthsim';
export const HS_AUTH_ABILITY: string = 'AuthAbility';
export const HS_AUTH_LINK: string = 'healthsim://authorize';
export const HS_PAYLOAD_FORMAT: string = 'healthsim.hh.v1';

/** Result codes returned through terminateSelfWithResult. */
export const HS_RESULT_GRANTED: number = 0;
export const HS_RESULT_DENIED: number = 1;
export const HS_RESULT_ERROR: number = 2;

/** Error code thrown by readData when a type was not granted. */
export const HS_ERROR_NOT_AUTHORIZED: number = 201;

// PROVISIONAL: check against samplePointHelper.* in @kit.HealthServiceKit.
export class HsDataType {
  static readonly STEPS: string = 'hh.steps.delta';
  static readonly HEART_RATE: string = 'hh.heart_rate';
  static readonly RESTING_HR: string = 'hh.resting_heart_rate';
  static readonly SLEEP_FRAGMENT: string = 'hh.sleep.fragment';
  static readonly SPO2: string = 'hh.spo2';
  static readonly SKIN_TEMP: string = 'hh.skin_temperature';
  static readonly STRESS: string = 'hh.stress';
  static readonly VO2MAX: string = 'hh.vo2max';

  static all(): string[] {
    return [
      HsDataType.STEPS,
      HsDataType.HEART_RATE,
      HsDataType.RESTING_HR,
      HsDataType.SLEEP_FRAGMENT,
      HsDataType.SPO2,
      HsDataType.SKIN_TEMP,
      HsDataType.STRESS,
      HsDataType.VO2MAX
    ];
  }

  static isKnown(dataType: string): boolean {
    return HsDataType.all().indexOf(dataType) >= 0;
  }
}

/** Sleep stage codes. PROVISIONAL: check against the SDK sleep record type. */
export class HsSleepStage {
  static readonly LIGHT: number = 1;
  static readonly DEEP: number = 2;
  static readonly REM: number = 3;
  static readonly AWAKE: number = 4;
}

/** Event kinds stored in the compact event list (steps and HR are slot arrays). */
export class HsEventKind {
  static readonly RESTING_HR: number = 1;
  static readonly SLEEP: number = 2;
  static readonly SPO2: number = 3;
  static readonly SKIN_TEMP: number = 4;
  static readonly STRESS: number = 5;
  static readonly VO2MAX: number = 6;
}

/**
 * One non-slot sample. value is an integer:
 * resting HR bpm, sleep stage code, SpO2 %, skin temperature in 0.1 °C,
 * stress score 1-99, VO2max in 0.1 ml/kg/min.
 */
export class HsEvent {
  kind: number = 0;
  startMs: number = 0;
  endMs: number = 0;
  value: number = 0;

  constructor(kind: number, startMs: number, endMs: number, value: number) {
    this.kind = kind;
    this.startMs = startMs;
    this.endMs = endMs;
    this.value = value;
  }
}

/** Ground truth for one local day. Never exported to FairWear; shown on the Scenario tab and used in tests. */
export class HsDayTruth {
  dayStartMs: number = 0;
  wornMinutes: number = 0;
  sick: boolean = false;
  removal: boolean = false;
  charged: boolean = false;
  paddedSlots: number = 0;
  stepsTotal: number = 0;
  restingHr: number = 0;
  partial: boolean = false;
}

/** Everything the generator produces for one scenario. */
export class HsDataset {
  personaId: string = '';
  seed: number = 0;
  anchorMs: number = 0;
  startMs: number = 0;
  tzOffsetMin: number = 0;
  slotCount: number = 0;
  /** Steps per 5-minute slot; 0 means no steps interval recorded. */
  steps: Uint16Array = new Uint16Array(0);
  /** Heart rate per slot in bpm; 0 means no sample (watch off). */
  hrBpm: Uint8Array = new Uint8Array(0);
  /** Seconds after slot start at which the HR sample was taken (90-210). */
  hrOffsetSec: Uint8Array = new Uint8Array(0);
  events: HsEvent[] = [];
  truth: HsDayTruth[] = [];
  dataSourceId: string = '';
}

/** Value fields of a sample point. Only the field matching the data type is set. */
export interface HsFields {
  steps?: number;
  bpm?: number;
  stage?: number;
  spo2?: number;
  celsius?: number;
  score?: number;
  value?: number;
}

/** Sample point in the shape of healthStore.SamplePoint. */
export interface HsSamplePoint {
  dataType: string;
  startTime: number;
  endTime: number;
  dataSourceId: string;
  fields: HsFields;
}

/** Read request in the shape of healthStore.SamplePointReadRequest. */
export interface HsReadRequest {
  samplePointDataType: string;
  startTime: number;
  endTime: number;
}

/** Store interface; a RealHealthStore over @kit.HealthServiceKit would implement the same. */
export interface HsHealthStore {
  init(): Promise<void>;
  readData(request: HsReadRequest): Promise<HsSamplePoint[]>;
  lastSyncTime(dataType: string): number;
  grantedTypes(): string[];
}

export class HsError extends Error {
  code: number = 0;

  constructor(code: number, message: string) {
    super(message);
    this.code = code;
  }
}

/** Payload passed back to FairWear in Want parameters (JSON string). Keep under 100 KB. */
export class HsPayload {
  format: string = HS_PAYLOAD_FORMAT;
  simulated: boolean = true;
  personaId: string = '';
  seed: number = 0;
  anchorMs: number = 0;
  startMs: number = 0;
  tzOffsetMin: number = 0;
  slotMinutes: number = SLOT_MINUTES;
  slotCount: number = 0;
  datasetId: string = '';
  dataSourceId: string = '';
  granted: string[] = [];
  syncTypes: string[] = [];
  syncTimes: number[] = [];
  /** base64, uint16 little-endian per slot; empty when steps were not granted. */
  steps: string = '';
  /** base64, 2 bytes per slot (bpm, offsetSec - 90); empty when heart rate was not granted. */
  heartRate: string = '';
  /** base64, 7 bytes per event (kind u8, startMin u16, durMin u16, value+32768 u16). */
  events: string = '';
}
