import { describe, it, expect } from '@ohos/hypium';
import {
  DailyActivity,
  HEALTH_MISSING,
  HealthStatus,
  HrvNight,
  SleepSession,
  Vo2MaxEstimate,
  Workout
} from '../main/ets/health/HealthRecords';
import { EmptyHealthSource, HealthSource } from '../main/ets/health/HealthSource';
import { ALL_HEALTH_SCOPES, HealthConnection, HealthScope } from '../main/ets/health/HealthConnection';

// Test fixture only: a source with two days of made-up records. Not used by the app.
class FixtureSource implements HealthSource {
  status(): HealthStatus {
    return HealthStatus.DEMO;
  }

  daily(days: number): DailyActivity[] {
    const a: DailyActivity = {
      date: '2026-10-01', steps: 8200, restingHeartRate: 58, moderateMinutes: 35, vigorousMinutes: 10
    };
    const b: DailyActivity = {
      date: '2026-10-02', steps: 0, restingHeartRate: 60, moderateMinutes: 0, vigorousMinutes: 0
    };
    return [a, b];
  }

  sleep(days: number): SleepSession[] {
    const s: SleepSession = { start: 1790892000000, end: 1790917200000, asleepMinutes: 395 };
    return [s];
  }

  vo2max(days: number): Vo2MaxEstimate[] {
    const v: Vo2MaxEstimate = { date: '2026-10-01', mlPerKgMin: 41 };
    return [v];
  }

  hrv(days: number): HrvNight[] {
    const h: HrvNight = { date: '2026-10-01', rmssdMs: 46 };
    return [h];
  }

  workouts(days: number): Workout[] {
    const w: Workout = { date: '2026-10-01', peakHeartRate: 162, heartRate60s: 131 };
    return [w];
  }
}

const FIXTURE_SYNC_MS: number = 1790920800000;

function connected(scopes: HealthScope[]): HealthConnection {
  const c: HealthConnection = new HealthConnection(new FixtureSource(), FIXTURE_SYNC_MS);
  c.recordPlatformConsent(true);
  c.confirmDataConsent(scopes);
  return c;
}

function without(scope: HealthScope): HealthScope[] {
  const out: HealthScope[] = [];
  for (let i = 0; i < ALL_HEALTH_SCOPES.length; i++) {
    if (ALL_HEALTH_SCOPES[i] !== scope) {
      out.push(ALL_HEALTH_SCOPES[i]);
    }
  }
  return out;
}

function totalRecords(c: HealthSource): number {
  return c.daily(90).length + c.sleep(90).length + c.vo2max(90).length + c.hrv(90).length + c.workouts(90).length;
}

export default function healthTest() {
  describe('HealthStatus transitions', () => {
    it('starts NOT_AUTHORIZED and hands out nothing', 0, () => {
      const c: HealthConnection = new HealthConnection(new FixtureSource(), FIXTURE_SYNC_MS);
      expect(c.status()).assertEqual(HealthStatus.NOT_AUTHORIZED);
      expect(totalRecords(c)).assertEqual(0);
      expect(c.lastSyncMs()).assertEqual(HEALTH_MISSING);
    });

    it('NOT_AUTHORIZED, consent, DEMO, disconnect, NOT_AUTHORIZED', 0, () => {
      const c: HealthConnection = new HealthConnection(new FixtureSource(), FIXTURE_SYNC_MS);
      expect(c.status()).assertEqual(HealthStatus.NOT_AUTHORIZED);
      c.recordPlatformConsent(true);
      expect(c.status()).assertEqual(HealthStatus.NOT_AUTHORIZED);
      expect(c.awaitingDataConsent()).assertTrue();
      expect(c.confirmDataConsent(ALL_HEALTH_SCOPES)).assertTrue();
      expect(c.status()).assertEqual(HealthStatus.DEMO);
      expect(c.daily(90).length).assertEqual(2);
      expect(c.lastSyncMs()).assertEqual(FIXTURE_SYNC_MS);
      c.disconnect();
      expect(c.status()).assertEqual(HealthStatus.NOT_AUTHORIZED);
    });

    it('refusal keeps NOT_AUTHORIZED and the second consent step cannot connect', 0, () => {
      const c: HealthConnection = new HealthConnection(new FixtureSource(), FIXTURE_SYNC_MS);
      c.recordPlatformConsent(false);
      expect(c.status()).assertEqual(HealthStatus.NOT_AUTHORIZED);
      expect(c.wasRefused()).assertTrue();
      expect(c.awaitingDataConsent()).assertFalse();
      expect(c.confirmDataConsent(ALL_HEALTH_SCOPES)).assertFalse();
      expect(c.status()).assertEqual(HealthStatus.NOT_AUTHORIZED);
      expect(totalRecords(c)).assertEqual(0);
    });

    it('after disconnect every method returns an empty list', 0, () => {
      const c: HealthConnection = connected(ALL_HEALTH_SCOPES);
      expect(totalRecords(c)).assertEqual(6);
      c.disconnect();
      expect(c.daily(90).length).assertEqual(0);
      expect(c.sleep(90).length).assertEqual(0);
      expect(c.vo2max(90).length).assertEqual(0);
      expect(c.hrv(90).length).assertEqual(0);
      expect(c.workouts(90).length).assertEqual(0);
      expect(c.enabledScopes().length).assertEqual(0);
      expect(c.lastSyncMs()).assertEqual(HEALTH_MISSING);
    });

    it('reconnecting needs both consent steps again', 0, () => {
      const c: HealthConnection = connected(ALL_HEALTH_SCOPES);
      c.disconnect();
      expect(c.confirmDataConsent(ALL_HEALTH_SCOPES)).assertFalse();
      expect(c.status()).assertEqual(HealthStatus.NOT_AUTHORIZED);
      c.recordPlatformConsent(true);
      expect(c.confirmDataConsent(ALL_HEALTH_SCOPES)).assertTrue();
      expect(c.status()).assertEqual(HealthStatus.DEMO);
      expect(totalRecords(c)).assertEqual(6);
    });

    it('consent with every data type switched off does not connect', 0, () => {
      const c: HealthConnection = new HealthConnection(new FixtureSource(), FIXTURE_SYNC_MS);
      c.recordPlatformConsent(true);
      const none: HealthScope[] = [];
      expect(c.confirmDataConsent(none)).assertFalse();
      expect(c.status()).assertEqual(HealthStatus.NOT_AUTHORIZED);
    });

    it('a connected source with no records stays empty, with its own status', 0, () => {
      const c: HealthConnection = new HealthConnection(new EmptyHealthSource(HealthStatus.DEMO));
      c.recordPlatformConsent(true);
      c.confirmDataConsent(ALL_HEALTH_SCOPES);
      expect(c.status()).assertEqual(HealthStatus.DEMO);
      expect(totalRecords(c)).assertEqual(0);
      expect(c.lastSyncMs()).assertEqual(HEALTH_MISSING);
      const u: HealthConnection = new HealthConnection(new EmptyHealthSource(HealthStatus.UNAVAILABLE));
      u.recordPlatformConsent(true);
      u.confirmDataConsent(ALL_HEALTH_SCOPES);
      expect(u.status()).assertEqual(HealthStatus.UNAVAILABLE);
    });
  });

  describe('Health scope switched off', () => {
    it('steps off: steps are -1, never zero; the other daily fields stay', 0, () => {
      const days: DailyActivity[] = connected(without(HealthScope.STEPS)).daily(90);
      expect(days.length).assertEqual(2);
      for (let i = 0; i < days.length; i++) {
        expect(days[i].steps).assertEqual(HEALTH_MISSING);
      }
      expect(days[0].restingHeartRate).assertEqual(58);
      expect(days[0].moderateMinutes).assertEqual(35);
    });

    it('resting heart rate off: -1, never zero', 0, () => {
      const days: DailyActivity[] = connected(without(HealthScope.RESTING_HEART_RATE)).daily(90);
      for (let i = 0; i < days.length; i++) {
        expect(days[i].restingHeartRate).assertEqual(HEALTH_MISSING);
      }
      expect(days[0].steps).assertEqual(8200);
    });

    it('activity minutes off: both minute fields are -1, never zero', 0, () => {
      const days: DailyActivity[] = connected(without(HealthScope.ACTIVITY_MINUTES)).daily(90);
      for (let i = 0; i < days.length; i++) {
        expect(days[i].moderateMinutes).assertEqual(HEALTH_MISSING);
        expect(days[i].vigorousMinutes).assertEqual(HEALTH_MISSING);
      }
    });

    it('a real zero from the source is kept as zero when the scope is on', 0, () => {
      const days: DailyActivity[] = connected(ALL_HEALTH_SCOPES).daily(90);
      expect(days[1].steps).assertEqual(0);
      expect(days[1].moderateMinutes).assertEqual(0);
    });

    it('all three daily scopes off: daily() is an empty list', 0, () => {
      const c: HealthConnection = connected([HealthScope.SLEEP, HealthScope.VO2MAX, HealthScope.HRV,
        HealthScope.WORKOUTS]);
      expect(c.daily(90).length).assertEqual(0);
    });

    it('sleep, VO2max, HRV, workouts off: each returns an empty list and leaves the rest alone', 0, () => {
      const noSleep: HealthConnection = connected(without(HealthScope.SLEEP));
      expect(noSleep.sleep(90).length).assertEqual(0);
      expect(noSleep.workouts(90).length).assertEqual(1);
      const noVo2: HealthConnection = connected(without(HealthScope.VO2MAX));
      expect(noVo2.vo2max(90).length).assertEqual(0);
      expect(noVo2.hrv(90).length).assertEqual(1);
      const noHrv: HealthConnection = connected(without(HealthScope.HRV));
      expect(noHrv.hrv(90).length).assertEqual(0);
      expect(noHrv.vo2max(90).length).assertEqual(1);
      const noWorkouts: HealthConnection = connected(without(HealthScope.WORKOUTS));
      expect(noWorkouts.workouts(90).length).assertEqual(0);
      expect(noWorkouts.sleep(90).length).assertEqual(1);
    });

    it('no field of any record handed out with a scope off is zero in place of missing', 0, () => {
      for (let s = 0; s < ALL_HEALTH_SCOPES.length; s++) {
        const off: HealthScope = ALL_HEALTH_SCOPES[s];
        const c: HealthConnection = connected(without(off));
        expect(c.isScopeEnabled(off)).assertFalse();
        expect(c.enabledScopes().length).assertEqual(ALL_HEALTH_SCOPES.length - 1);
        const first: DailyActivity = c.daily(90)[0];
        if (off === HealthScope.STEPS) {
          expect(first.steps).assertEqual(HEALTH_MISSING);
        } else {
          expect(first.steps).assertEqual(8200);
        }
        if (off === HealthScope.RESTING_HEART_RATE) {
          expect(first.restingHeartRate).assertEqual(HEALTH_MISSING);
        } else {
          expect(first.restingHeartRate).assertEqual(58);
        }
        if (off === HealthScope.ACTIVITY_MINUTES) {
          expect(first.moderateMinutes).assertEqual(HEALTH_MISSING);
          expect(first.vigorousMinutes).assertEqual(HEALTH_MISSING);
        } else {
          expect(first.moderateMinutes).assertEqual(35);
          expect(first.vigorousMinutes).assertEqual(10);
        }
      }
    });
  });
}
