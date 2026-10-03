// Public surface of the common HAR. Pure logic only: no UI imports.
export {
  Epoch,
  SleepRecord,
  DaySummary,
  Gap,
  Thresholds,
  ComplianceResult,
  Factor,
  ScoreResult,
  MonthlyReport,
  WhatIfSuggestion,
  UserSettings,
  LedgerEntry,
  TierClaim,
  SignedClaim,
  LiveSample
} from './src/main/ets/model/types';
export { DEFAULT_THRESHOLDS } from './src/main/ets/model/defaults';
export {
  buildTierClaim,
  decodeTierClaim,
  encodeTierClaim,
  TIER_CLAIM_KEYS,
  TIER_CLAIM_VERSION
} from './src/main/ets/claim/TierClaimCodec';
export { isSelectiveNonWear } from './src/main/ets/rules/SelectiveNonWear';
export { LiveWearState, WearState, NO_HEART_RATE } from './src/main/ets/live/LiveWearState';
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
export { HEALTH_BRAND, healthSourceLabel, healthStatusLabel } from './src/main/ets/health/HealthStatusLabel';
export { ALL_HEALTH_SCOPES, HealthConnection, HealthScope } from './src/main/ets/health/HealthConnection';
export {
  CARD_PARAMS_KEY,
  FwTarget,
  FW_TARGET_PARAM,
  resolveFwTarget,
  resolveFwTargetFromWant
} from './src/main/ets/nav/EntryTarget';
export {
  buildCardDigest,
  cardCoverageText,
  CardDigest,
  cardResultText,
  cardSourceLabel,
  CARD_COVERAGE_NONE,
  CARD_NO_VALUE,
  decodeCardDigest,
  emptyCardDigest,
  encodeCardDigest
} from './src/main/ets/card/CardDigest';
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
// Platform helpers shared by the phone and the watch (these import system kits; the logic tests do not load them).
export { b64urlDecode, b64urlEncode, toHex, utf8Decode, utf8Encode } from './src/main/ets/platform/Bytes';
export { CryptoUtil } from './src/main/ets/platform/CryptoUtil';
export { DeviceKey, KeySource, ProofSigner } from './src/main/ets/platform/ProofSigner';
export { FileTextStore } from './src/main/ets/platform/FileTextStore';
export {
  DeviceHasher,
  DeviceSigVerifier,
  deviceTzOffsetMin,
  KeySigner,
  SystemClock
} from './src/main/ets/platform/DeviceCrypto';
// Watch Link engines: the watch side and the phone side, platform passed in.
export { DayTransport } from './src/main/ets/watchlink/DayTransport';
export { DEMO_SPEED, RecorderClock } from './src/main/ets/watchlink/RecorderClock';
export {
  ACKS_DIR,
  OUTBOX_DIR,
  PAIR_FILE,
  STATUS_NOT_PAIRED,
  STATUS_SYNCED,
  syncStatusLine,
  WatchLinkEngine,
  WatchLinkView
} from './src/main/ets/watchlink/WatchLinkEngine';
export {
  factsOfMissing,
  factsOfPacket,
  INBOX_DIR,
  missingDayReason,
  PhoneLinkEngine,
  PhoneLinkView,
  PHONE_ACKS_DIR,
  sourceLine,
  SyncLogEntry,
  SyncReport,
  TRANSPORT_RELAY,
  TRANSPORT_WEAR_ENGINE,
  WatchDayFacts
} from './src/main/ets/watchlink/PhoneLinkEngine';
export { PAIR_ACK_SEQ } from './src/main/ets/watchlink/DayPacketCodec';
export {
  CLOCK_FEED_SUFFIX,
  demoFeedAt,
  DemoFeedSample,
  demoFeedSteps,
  feedClockLabel
} from './src/main/ets/watchlink/DemoFeed';
