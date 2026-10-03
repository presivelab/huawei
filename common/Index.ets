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
export { FwTarget, FW_TARGET_PARAM, resolveFwTarget } from './src/main/ets/nav/EntryTarget';
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
