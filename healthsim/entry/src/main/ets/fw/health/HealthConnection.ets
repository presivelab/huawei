import {
  DailyActivity,
  HEALTH_MISSING,
  HealthStatus,
  HrvNight,
  SleepSession,
  Vo2MaxEstimate,
  Workout
} from './HealthRecords';
import { HealthSource } from './HealthSource';

// The data types FairWear asks for: exactly the ones the Health Evidence Score uses.
export enum HealthScope {
  STEPS = 'STEPS',
  RESTING_HEART_RATE = 'RESTING_HEART_RATE',
  SLEEP = 'SLEEP',
  ACTIVITY_MINUTES = 'ACTIVITY_MINUTES',
  VO2MAX = 'VO2MAX',
  HRV = 'HRV',
  WORKOUTS = 'WORKOUTS'
}

export const ALL_HEALTH_SCOPES: HealthScope[] = [
  HealthScope.STEPS,
  HealthScope.RESTING_HEART_RATE,
  HealthScope.SLEEP,
  HealthScope.ACTIVITY_MINUTES,
  HealthScope.VO2MAX,
  HealthScope.HRV,
  HealthScope.WORKOUTS
];

// The connection between FairWear and a health source, with the user's consent in front of it.
//
// Consent has two steps and both are needed:
//   1. the platform's own authorization (HUAWEI Health shows that screen, not FairWear),
//   2. FairWear's consent to process health data (GDPR art. 9), where single data types can be switched off.
//
// Status: NOT_AUTHORIZED until both steps are done, then whatever the inner source reports
// (DEMO for the demo source), and NOT_AUTHORIZED again after disconnect().
//
// While not connected every method returns an empty list. A data type switched off in step 2 comes back
// as an empty list or, for a field of a daily record, as HEALTH_MISSING (-1). Never as zero.
//
// This class keeps no copy of the records; after disconnect() it stops handing out the inner source's
// records. An adapter that caches fetched records has to drop them itself when the app disconnects.
export class HealthConnection implements HealthSource {
  private inner: HealthSource;
  private syncMs: number;
  private platformGranted: boolean = false;
  private connected: boolean = false;
  private refused: boolean = false;
  private enabled: Set<HealthScope> = new Set<HealthScope>();

  // lastSyncMs: when the inner source last received data (epoch ms), HEALTH_MISSING when it does not know.
  constructor(inner: HealthSource, lastSyncMs: number = HEALTH_MISSING) {
    this.inner = inner;
    this.syncMs = lastSyncMs;
  }

  status(): HealthStatus {
    return this.connected ? this.inner.status() : HealthStatus.NOT_AUTHORIZED;
  }

  // Step 1: the result of the platform's authorization screen.
  recordPlatformConsent(granted: boolean): void {
    this.connected = false;
    this.enabled.clear();
    this.platformGranted = granted;
    this.refused = !granted;
  }

  // True between a granted step 1 and step 2.
  awaitingDataConsent(): boolean {
    return this.platformGranted && !this.connected;
  }

  // True when the last answer on the platform's authorization screen was a refusal.
  wasRefused(): boolean {
    return this.refused;
  }

  // Step 2: FairWear's own consent, with the data types the user left switched on.
  // Returns false, and stays NOT_AUTHORIZED, when step 1 was not granted or no data type is left on.
  confirmDataConsent(scopes: HealthScope[]): boolean {
    if (!this.platformGranted || scopes.length === 0) {
      return false;
    }
    this.enabled.clear();
    for (let i = 0; i < scopes.length; i++) {
      this.enabled.add(scopes[i]);
    }
    this.connected = true;
    this.refused = false;
    return true;
  }

  // Withdraws both consents. Connecting again starts from step 1.
  disconnect(): void {
    this.connected = false;
    this.platformGranted = false;
    this.refused = false;
    this.enabled.clear();
  }

  isScopeEnabled(scope: HealthScope): boolean {
    return this.connected && this.enabled.has(scope);
  }

  enabledScopes(): HealthScope[] {
    const out: HealthScope[] = [];
    for (let i = 0; i < ALL_HEALTH_SCOPES.length; i++) {
      if (this.isScopeEnabled(ALL_HEALTH_SCOPES[i])) {
        out.push(ALL_HEALTH_SCOPES[i]);
      }
    }
    return out;
  }

  // Epoch ms of the last sync, HEALTH_MISSING while not connected or when the source does not know.
  lastSyncMs(): number {
    return this.connected ? this.syncMs : HEALTH_MISSING;
  }

  daily(days: number): DailyActivity[] {
    const steps: boolean = this.isScopeEnabled(HealthScope.STEPS);
    const resting: boolean = this.isScopeEnabled(HealthScope.RESTING_HEART_RATE);
    const minutes: boolean = this.isScopeEnabled(HealthScope.ACTIVITY_MINUTES);
    if (!steps && !resting && !minutes) {
      return [];
    }
    const records: DailyActivity[] = this.inner.daily(days);
    const out: DailyActivity[] = [];
    for (let i = 0; i < records.length; i++) {
      const masked: DailyActivity = {
        date: records[i].date,
        steps: steps ? records[i].steps : HEALTH_MISSING,
        restingHeartRate: resting ? records[i].restingHeartRate : HEALTH_MISSING,
        moderateMinutes: minutes ? records[i].moderateMinutes : HEALTH_MISSING,
        vigorousMinutes: minutes ? records[i].vigorousMinutes : HEALTH_MISSING
      };
      out.push(masked);
    }
    return out;
  }

  sleep(days: number): SleepSession[] {
    return this.isScopeEnabled(HealthScope.SLEEP) ? this.inner.sleep(days) : [];
  }

  vo2max(days: number): Vo2MaxEstimate[] {
    return this.isScopeEnabled(HealthScope.VO2MAX) ? this.inner.vo2max(days) : [];
  }

  hrv(days: number): HrvNight[] {
    return this.isScopeEnabled(HealthScope.HRV) ? this.inner.hrv(days) : [];
  }

  workouts(days: number): Workout[] {
    return this.isScopeEnabled(HealthScope.WORKOUTS) ? this.inner.workouts(days) : [];
  }
}
