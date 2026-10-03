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
export { FwTarget, FW_TARGET_PARAM, resolveFwTarget } from './src/main/ets/nav/EntryTarget';
