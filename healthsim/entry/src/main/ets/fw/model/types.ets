// common/src/main/ets/model/types.ets
// The data contract shared by the phone, the watch and the partner. The first plan's report types (Epoch,
// DaySummary, Gap, ScoreResult, MonthlyReport and the rest) were replaced by HES-Lite (hes/HesTypes.ets), the
// wear month (wear/WearMonth.ets) and the report view models (report/ReportModels.ets) and are no longer here.
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
export interface LedgerEntry {      // K14 — everything that left the device
  t: number;
  kind: string;                     // 'CLAIM' | 'VISIT' | 'NOTE'
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
