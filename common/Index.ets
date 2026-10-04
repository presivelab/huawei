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
// Watch Link tour: read-only checks on a copy of the chain, and the tour's content (steps, code, criteria).
export {
  flippedSlot,
  NOTE_COUNTED_ONCE,
  NOTE_FILLS_GAP,
  NOTE_NOT_TAKEN,
  PROBE_LEDGER_UNREADABLE,
  PROBE_NEEDS_DAY,
  PROBE_NEEDS_TWO,
  ProbeAction,
  ProbeKind,
  ProbeResult,
  ProbeStep,
  probeTitle,
  ReceivedPacketInfo,
  STORED_UNCHANGED,
  utf8Length
} from './src/main/ets/watchlink/LinkProbe';
export {
  CODE_ELLIPSIS,
  demoClockText,
  displayCode,
  elapsedText,
  LEAVES_PHONE,
  notObservedMinutes,
  packetLine,
  probeLine,
  probeStepLabel,
  REAL_ROWS,
  ReviewRow,
  SlotRun,
  slotRuns,
  slotState,
  slotStateLabel,
  TOUR_INTRO,
  TOUR_STEPS,
  TOUR_TITLE,
  TourStep,
  VERIFY_ORDER,
  wearSourceText
} from './src/main/ets/present/TourContent';
// How watch days are worded on the phone. Pure functions; no verdict.
export {
  breakText,
  DAY_NOT_RECEIVED,
  demoDayLabel,
  durationParts,
  DurationParts,
  durationText,
  dayOfMonth,
  dayTitle,
  isDemoDay,
  isVerifiedDay,
  lastSyncText,
  listedWearParts,
  logLineText,
  logTimeText,
  minuteClock,
  missingSummary,
  NOT_SYNCED,
  observedMinutes,
  STRIP_DAYS,
  stripDays,
  transportLabel,
  verifiedDayCount,
  verifiedSummary,
  WEAR_CHARGING,
  WEAR_LABEL_CHARGING,
  WEAR_LABEL_OFF,
  WEAR_LABEL_UNOBSERVED,
  WEAR_LABEL_WORN,
  WEAR_OFF,
  WEAR_UNOBSERVED,
  WEAR_WORN,
  WearPart,
  wearParts,
  weekdayShort
} from './src/main/ets/present/WatchDayPresent';
export {
  BUILT_IN_SCRIPT,
  CLOCK_FEED_SUFFIX,
  decodeWatchScript,
  demoFeedAt,
  DemoFeedSample,
  demoFeedSteps,
  encodeWatchScript,
  feedClockLabel,
  FEED_SOURCE_BUILT_IN,
  FEED_SOURCE_HEALTH_SIM,
  feedScriptSource,
  FeedStretch,
  HEALTH_SIM_WATCH_PARAM,
  setFeedScript
} from './src/main/ets/watchlink/DemoFeed';

export {
  isValidKeySource,
  isValidKidText,
  isValidNonceText,
  isValidSignatureText,
  validateSignedClaim,
  validateTierClaimJson,
  CLAIM_TIERS,
  KEY_SOURCE_HUKS,
  KEY_SOURCE_SOFTWARE,
  MAX_CLAIM_JSON_CHARS,
  MAX_DER_SIGNATURE_BYTES,
  MAX_FUTURE_SKEW_MS,
  MAX_TOKEN_CHARS,
  TIER_NO_SCORE
} from './src/main/ets/claim/ClaimValidation';
export {
  decodeSignedClaimToken,
  encodeSignedClaimToken,
  TOKEN_MARKER
} from './src/main/ets/claim/SignedClaimToken';
export {
  NONCE_BYTES,
  NONCE_TTL_MS,
  PartnerKey,
  PartnerVerifier,
  RandomSource,
  STATUS_ALREADY_USED,
  STATUS_INVALID_FORMAT,
  STATUS_INVALID_SIGNATURE,
  STATUS_NONCE_MISMATCH,
  STATUS_UNKNOWN_KEY,
  STATUS_VALID,
  VERIFY_STEPS,
  VerifyResult
} from './src/main/ets/claim/PartnerVerifier';
export { DeviceRandom } from './src/main/ets/platform/DeviceRandom';
// HES-Lite v1.0: the scoring engine, rebuilt from the specification. Pure logic. See docs/HES.md.
export {
  copyHesDay,
  emptyHesDay,
  HesComponentDefinition,
  HesComponentId,
  HesComponentResult,
  HesConfidence,
  HesDay,
  HesPoint,
  HesResult,
  HesStatus,
  HesWhy,
  HES_MISSING
} from './src/main/ets/hes/HesTypes';
export { piecewiseScore } from './src/main/ets/hes/HesPiecewise';
export {
  hesDefinition,
  HES_COMPONENTS,
  HES_CONFIDENCE_HIGH_MIN,
  HES_CONFIDENCE_MEDIUM_MIN,
  HES_HRR_WINDOW_DAYS,
  HES_TIER_A_MIN,
  HES_TIER_B_MIN,
  HES_VO2MAX_WINDOW_DAYS,
  HES_WINDOW_DAYS
} from './src/main/ets/hes/HesCurves';
export {
  hesMean,
  hesMedian,
  hesRound,
  hesSampleSd,
  sleepRelativeMinutes,
  sleepTimingSd
} from './src/main/ets/hes/HesMath';
export {
  isSufficient as hesIsSufficient,
  isValidFor as hesIsValidFor,
  quality as hesQuality,
  validDays as hesValidDays
} from './src/main/ets/hes/HesSufficiency';
export {
  componentScore as hesComponentScore,
  equivalentMvpa,
  evaluateComponent as hesEvaluateComponent,
  evaluateComponents as hesEvaluateComponents
} from './src/main/ets/hes/HesComponents';
export {
  calculateObservedHes,
  coverage as hesCoverage,
  isCoreComplete as hesIsCoreComplete,
  observedHes
} from './src/main/ets/hes/HesComposite';
export {
  calculateConfidence as hesCalculateConfidence,
  confidenceFromIndex as hesConfidenceFromIndex,
  confidenceIndex as hesConfidenceIndex,
  weightedQuality as hesWeightedQuality
} from './src/main/ets/hes/HesConfidence';
export {
  pointsToNextTier as hesPointsToNextTier,
  tierFromHes,
  tierLabel as hesTierLabel
} from './src/main/ets/hes/HesTier';
export { whyThisTier } from './src/main/ets/hes/HesWhy';
export { composeHes, computeHes } from './src/main/ets/hes/HesEngine';
export { HesPrng } from './src/main/ets/hes/HesPrng';
export { HesDaySource, HesSession } from './src/main/ets/hes/HesSession';
export {
  generatePersonaDay,
  generatePersonaHistory,
  HesPersonas,
  HesPersonaSpec,
  HES_PERSONA_END_DATE
} from './src/main/ets/hes/HesPersonas';
// Wear month of the demo personas: compliance, breaks and the selective non-wear flag. Pure logic.
export {
  buildWearMonth,
  countedWearMinutes,
  isDayCompliant,
  isNightWorn,
  judgeBreak,
  WearBreak,
  WearBreakResult,
  WearDayRecord,
  WearDayResult,
  WearDayState,
  WearMonthResult
} from './src/main/ets/wear/WearMonth';
export {
  generateWearDay,
  generateWearMonth,
  WearEvent,
  WearPersonas,
  WEAR_MONTH_DAYS
} from './src/main/ets/wear/WearPersonas';
// The monthly report on the phone: view models, the benefit rule and the fixed preview of the six personas.
export {
  BAR_NO_DATA,
  BenefitLevel,
  ComponentId,
  ComponentRow,
  DayCell,
  DayState,
  hasScore,
  HES_NONE,
  LiveNow,
  PersonaRef,
  PersonaReport,
  POINTS_UNKNOWN,
  ReportConfidence,
  ReportTier,
  WearSummary
} from './src/main/ets/report/ReportModels';
export {
  BENEFIT_FULL_LABEL,
  BENEFIT_NONE_LABEL,
  BENEFIT_PARTIAL_LABEL,
  benefitLabel,
  benefitLevel,
  benefitReason
} from './src/main/ets/report/Benefit';
export {
  PREVIEW_DEFAULT_ID,
  PREVIEW_PERIOD,
  PREVIEW_PERIOD_ISO,
  PREVIEW_SOURCE,
  previewPersonas,
  previewReport,
  previewReports
} from './src/main/ets/report/PreviewReports';
export {
  FW_TAB_EVIDENCE,
  FW_TAB_REPORT,
  FW_TAB_SHARE,
  fwTargetOpensSettings,
  fwTargetTab
} from './src/main/ets/nav/EntryTarget';
export { dayStateLabel, metricSpoken, scoreSpoken, wearSpoken } from './src/main/ets/report/ReportSpeech';
export { periodDayIso, periodDaySpoken } from './src/main/ets/report/ReportDates';
// The same report built from the scoring engine, the persona history and the wear month.
export {
  ENGINE_DEFAULT_ID,
  ENGINE_SOURCE,
  enginePersonas,
  engineReport,
  engineReportOf,
  engineReports,
  engineSession,
  engineWhatIf,
  EngineWhatIf,
  nextTierOf,
  reportComponentId,
  SCORE_TO,
  engineDayDetailsFrom,
  engineReportFromPerson,
  engineSessionFrom,
  HEALTH_SIM_LABEL,
  wearMonthFrom
} from './src/main/ets/report/EngineReports';
// Health Sim: the simulator app that stands in for HUAWEI Health hands its data over in this format.
export { dayWithScopes } from './src/main/ets/health/HealthSimPayload';
export {
  decodeHealthSimPayload,
  encodeHealthSimPayload,
  HEALTH_SIM_MAX_CHARS,
  HEALTH_SIM_PARAM,
  HEALTH_SIM_SOURCE,
  HEALTH_SIM_VERSION,
  healthSimPayloadFromPersonas,
  healthSimPerson,
  HealthSimPayload,
  HealthSimPerson,
  withScopes
} from './src/main/ets/health/HealthSimPayload';
// The Evidence calendar and the "Why this tier" sections, from the rows of a report.
export {
  appealKey,
  appealsIn,
  CALENDAR_WEEKDAYS,
  calendarCells,
  CalendarCell,
  calendarDaySpoken,
  canAppeal,
  clockText,
  daysInState,
  flagRuleText,
  isAppealed,
  minutesText,
  redDays,
  withAppeal,
  withoutAppealsOf
} from './src/main/ets/report/EvidenceCalendar';
export { scoreEvidence, ScoreEvidence, weightText, whySections, WhySections } from './src/main/ets/report/WhySections';
// Share and the partner view of the demo: the offer of a report, the signed token, the partner's reading.
export {
  CHECK_LABELS,
  CheckRow,
  checkRows,
  CheckState,
  claimBenefitLabel,
  claimLedgerEntry,
  claimLine,
  claimPeriodText,
  claimTierLine,
  keySourceLabel,
  LEDGER_DESTINATION_PARTNER,
  LEDGER_KIND_CLAIM,
  mintClaimToken,
  ShareOffer,
  shareOffer,
  SHARE_NO_SCORE_REASON,
  SHARE_NO_SCORE_TIER,
  SHARE_REASON_STAYS,
  stoppedAt,
  tamperedTierToken,
  tamperTargetTier,
  tokenClaim,
  tokenLengthLine,
  verdictLine,
  LEDGER_KIND_VISIT,
  LEDGER_DESTINATION_VISIT,
  visitLedgerEntry
} from './src/main/ets/claim/ShareFlow';
// The days of the wear month in detail: worn time, breaks and the reason of each day as text.
export { DayBreak, DayDetail, dayDetailOf, engineDayDetails } from './src/main/ets/report/EngineReports';
// Visits and day dial
export {
  DayDial,
  dayDial,
  DIAL_CHARGING,
  DIAL_DEMO_NOTE,
  DIAL_NOW_NOTE,
  DIAL_OFF,
  DIAL_SLEEP,
  DIAL_TICK_LABELS,
  DIAL_TITLE,
  DIAL_WORN,
  DialArc,
  dialKindLabel,
  DialSegment,
  dialSegmentsOfRuns,
  groupedNumber,
  minuteToDeg,
  sleepArcs,
  wearArcs
} from './src/main/ets/present/DayDialModel';
export {
  ADHERENCE_NONE,
  ADHERENCE_ON_TIME,
  ADHERENCE_VALUES,
  addDays,
  Adherence,
  daysBetween,
  isIsoDate,
  isoDateMs,
  isServiceType,
  isShareableServiceType,
  MedicalReceipt,
  NoteItem,
  NoteKind,
  ReceiptStatus,
  SERVICE_TYPES,
  ServiceType,
  serviceTypeLabel,
  SHAREABLE_SERVICE_TYPES,
  Speaker,
  TranscriptSegment,
  Visit,
  visitDateText
} from './src/main/ets/visits/VisitTypes';
export { parseReceipt, RECEIPT_QR_PREFIX, serializeReceipt } from './src/main/ets/visits/ReceiptCodec';
export {
  checkReceiptText,
  MockReceiptVerifier,
  RECEIPT_MAX_AGE_DAYS,
  ReceiptCheck,
  receiptStatusMessage,
  ReceiptVerifier
} from './src/main/ets/visits/ReceiptVerifier';
export {
  DEMO_FOLLOW_UP_DAYS,
  DEMO_ISSUER_ID,
  DEMO_ISSUER_NAME,
  DEMO_R1,
  DEMO_R2,
  DEMO_R3,
  DEMO_R4,
  DEMO_R5,
  DEMO_RECEIPT_IDS,
  demoReceiptHint,
  demoReceiptLabel,
  demoTranscriptT1,
  DemoVisits,
  emptyVisit,
  VISITS_PERSONA_ID
} from './src/main/ets/visits/DemoVisits';
export {
  followUpDays,
  followUpDueDateOf,
  NotesExtractor,
  notesOfKind,
  RuleBasedNotesExtractor,
  segmentById,
  sentencesOf,
  sourceQuote,
  transcriptTimeText
} from './src/main/ets/visits/NotesExtractor';
export {
  adherence,
  followUpDoneOnTime,
  followUpVisitOf,
  visitAdherence,
  visitById,
  visitDateOf
} from './src/main/ets/visits/FollowUp';
export {
  adherenceLabel,
  buildVisitClaim,
  ClaimLine,
  decodeVisitClaim,
  decodeVisitToken,
  encodeVisitClaim,
  encodeVisitToken,
  mintVisitToken,
  receiptRef,
  tamperedVisitDateToken,
  validateVisitClaimJson,
  VISIT_CLAIM_KEYS,
  VISIT_CLAIM_TYPE,
  VISIT_CLAIM_VERSION,
  VISIT_NEVER_SHARED,
  VISIT_NOT_VERIFIED,
  VISIT_TOKEN_MARKER,
  VISIT_TYPE_NEVER_SHARED,
  VisitClaim,
  visitClaimLine,
  visitClaimLines,
  visitShareBlock,
  visitTokenClaim
} from './src/main/ets/visits/VisitClaim';
export {
  VISIT_CHECK_LABELS,
  VISIT_STATUS_ALREADY_USED,
  VISIT_STATUS_INVALID_FORMAT,
  VISIT_STATUS_INVALID_SIGNATURE,
  VISIT_STATUS_NONCE_MISMATCH,
  VISIT_STATUS_RECEIPT_CLAIMED,
  VISIT_STATUS_UNKNOWN_KEY,
  VISIT_STATUS_VALID,
  VISIT_STATUS_WRONG_TYPE,
  VISIT_VERIFY_STEPS,
  visitCheckRows,
  visitVerdictLine,
  VisitVerifier,
  VisitVerifyResult
} from './src/main/ets/visits/VisitVerifier';
export { AddReceiptResult, VisitBook } from './src/main/ets/visits/VisitBook';
