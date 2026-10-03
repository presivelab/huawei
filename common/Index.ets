// Public surface of the common HAR. Pure logic only: no UI imports.
export * from './src/main/ets/model/types';
export { DEFAULT_THRESHOLDS } from './src/main/ets/model/defaults';
export {
  buildTierClaim,
  decodeTierClaim,
  encodeTierClaim,
  TIER_CLAIM_KEYS,
  TIER_CLAIM_VERSION
} from './src/main/ets/claim/TierClaimCodec';
export { isSelectiveNonWear } from './src/main/ets/rules/SelectiveNonWear';
export { LiveWearState, WearState, NO_HEART_RATE, DEFAULT_REMOVED_AFTER_MS } from './src/main/ets/live/LiveWearState';
export {
  DailyActivity,
  HEALTH_MISSING,
  HealthStatus,
  HrvNight,
  SleepSession,
  Vo2MaxEstimate,
  Workout
} from './src/main/ets/health/HealthRecords';
export { EmptyHealthSource, HealthSource } from './src/main/ets/health/HealthSource';
export { ALL_HEALTH_SCOPES, HealthConnection, HealthScope } from './src/main/ets/health/HealthConnection';
// Watch Link: on-wrist recorder, signed day packets, chain verification. Pure logic; platform through ports.
export {
  AckPacket,
  AckStatus,
  BreakContext,
  classifySlot,
  CLOCK_REAL,
  dateOfDayNumber,
  dayNumberOfDate,
  DayPacket,
  DayRecord,
  GENESIS,
  isValidHeartRate,
  localDayNumber,
  localSlotIndex,
  MAX_PACKET_BYTES,
  PairPacket,
  SlotRecord,
  SlotState,
  slotStartMs,
  SLOTS_PER_DAY,
  WearSource
} from './src/main/ets/watchlink/WatchLinkTypes';
export { Clock, Hasher, Signer, SigVerifier, TextStore } from './src/main/ets/watchlink/WatchLinkPorts';
export { daySigningString, dayPacketHash, pairSigningString } from './src/main/ets/watchlink/WatchLinkSigning';
export {
  FRESHNESS_DEMO_CLOCK_MS,
  FRESHNESS_REAL_CLOCK_MS,
  WearStateMachine
} from './src/main/ets/watchlink/WearStateMachine';
export { GAP_REAL_MS, KEEP_DAYS, SlotRecorder, slotsToString } from './src/main/ets/watchlink/SlotRecorder';
export { DayBuilder } from './src/main/ets/watchlink/DayBuilder';
export {
  AckDecodeResult,
  AckPacketCodec,
  DayDecodeResult,
  DayPacketCodec,
  DecodeCode,
  PairDecodeResult,
  PairPacketCodec
} from './src/main/ets/watchlink/DayPacketCodec';
export { ChainCheck, ChainEntry, ChainKind, ChainLedger } from './src/main/ets/watchlink/ChainLedger';
export {
  DayPacketVerifier,
  missingDaysNote,
  MSG_ACCEPTED,
  MSG_CHAIN_CONFLICT,
  MSG_DATE_FUTURE,
  MSG_DATE_ORDER,
  MSG_DEMO_CLOCK,
  MSG_DUPLICATE,
  MSG_INVALID_FORMAT,
  MSG_INVALID_SIGNATURE,
  MSG_KEY_ID_MISMATCH,
  MSG_PAIR_VALID,
  MSG_UNKNOWN_KEY,
  MSG_UNSUPPORTED_VERSION,
  PairOutcome,
  PairVerifier,
  VerifyOutcome
} from './src/main/ets/watchlink/DayPacketVerifier';
export {
  chainStateFromJson,
  chainStateToJson,
  newChainState,
  PacketSealer,
  SealedDay,
  WatchChainState
} from './src/main/ets/watchlink/PacketSealer';
