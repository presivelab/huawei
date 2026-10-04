// common/src/main/ets/model/types.ets
export interface Epoch {            // 5-minute slot
  t: number;                        // epoch ms (slot start)
  worn: boolean;
  charging: boolean;                // on the charger (then worn = false)
  hr: number;                       // bpm; 0 when not worn
  steps: number;
}
export interface SleepRecord { dayIndex: number; minutes: number; }

export interface DaySummary {
  dayIndex: number;
  wornMin: number;
  chargingMin: number;
  nightWorn: boolean;               // worn ≥ Thresholds.nightMinWornMin between 00:00 and 06:00, persona time zone
  restingHr: number;                // mean of the lowest 10% of HR values in worn slots
  steps: number;
  sleepMin: number;
  activeMin: number;                // worn slots with HR ≥ restingHr + 30, ×5 (K16)
}
export interface Gap {
  start: number; end: number;       // epoch ms
  minutes: number;
  preRestDelta: number;             // bpm vs baseline
  stepsRatio: number;               // steps in the 24 h before / baseline median
  suspicious: boolean;
}
export interface Thresholds {
  minDailyHours: number;            // 20
  maxChargingCountedMin: number;    // 120
  nightRequired: boolean;           // true
  minMonthlyPct: number;            // 85
  gapMinMinutes: number;            // 120
  restDeltaBpm: number;             // 7
  stepsDropRatio: number;           // 0.6  (a 40% drop)
  minSuspicious: number;            // 3  (this many suspicious gaps always raise the flag)
  minSuspiciousForShare: number;    // 2  (from this many, the share rule below applies; one gap never flags)
  maxSuspiciousShare: number;       // 0.3
  maxPauseDaysPer30: number;        // 5  (sick-day pause, K11)
  nightMinWornMin: number;          // 240  (a night counts when worn ≥ 4 h between 00:00 and 06:00, persona time zone)
  minHrReadingsBeforeGap: number;   // 12  (fewer HR readings in the 24 h before a gap: the gap is not judged)
}
export interface ComplianceResult { compliantDays: number; totalDays: number; pct: number; passes: boolean; }
export interface Factor { name: string; value: string; points: number; maxPoints: number; }
export interface ScoreResult { points: number; tier: string; factors: Factor[]; }  // tier: 'A'|'B'|'C'
export interface MonthlyReport {
  personaId: string;
  periodLabel: string;              // e.g. "2026-09-03..2026-10-02"
  compliance: ComplianceResult;
  gaps: Gap[];
  selectiveNonWear: boolean;
  eligible: boolean;                // compliance.passes && !selectiveNonWear
  score: ScoreResult;
  discountPct: number;
  pausedDays: number;               // K11 — NEVER sent to the partner
  whatIf: WhatIfSuggestion[];       // K12
}
export interface WhatIfSuggestion { factor: string; change: string; newTier: string; newDiscountPct: number; }
export interface UserSettings {
  thresholds: Thresholds;
  pausedDayIndexes: number[];       // days marked as a sick-day pause (K11)
  limitedMobility: boolean;         // accessibility profile (K16)
}
export interface LedgerEntry {      // K14 — everything that left the device
  t: number;
  kind: string;                     // 'CLAIM'
  destination: string;
  payload: string;                  // exact content sent
  bytes: number;
}
export interface TierClaim {        // the ONLY thing the partner sees; exactly these seven keys
  v: number; period: string;
  tier: string; eligible: boolean;
  nonce: string; issuedAt: number;
  kid: string;                      // 8 hex chars: first 4 bytes of SHA-256 over the public key
}
// The public key is NOT in the token: the partner looks it up by kid in its own key registry.
export interface SignedClaim { claimJson: string; sigB64: string; kid: string; keySource: string; } // keySource: 'HUKS'|'SOFTWARE'
export interface LiveSample {       // watch, about once per second
  t: number;
  hr: number;                       // 0 = no signal
  steps: number;                    // counter since start
  wornSource: string;               // 'WEAR_SENSOR' | 'HR_SIGNAL' (emulator) — see docs/WATCH_LINK.md, wear state
  worn: boolean;
}
