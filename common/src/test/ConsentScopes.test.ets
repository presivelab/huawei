// The consent switches: a data type that is switched off is missing in the starting history and in every
// day "Close the day" adds, on the built-in path and on the Health Sim path.
import { describe, it, expect } from '@ohos/hypium';
import { ALL_HEALTH_SCOPES, HealthScope } from '../main/ets/health/HealthConnection';
import {
  dayWithScopes,
  healthSimPayloadFromPersonas,
  healthSimPerson,
  HealthSimPerson,
  withScopes
} from '../main/ets/health/HealthSimPayload';
import { HesSession } from '../main/ets/hes/HesSession';
import {
  ComponentId,
  ComponentResult,
  HesConfidence,
  HesDayRecord,
  HesProfile,
  HesResult,
  HesStatus,
  HesTier
} from '../main/ets/hes/HesTypes';
import { engineSession, engineSessionFrom } from '../main/ets/report/EngineReports';

const HW = HesProfile.HEALTH_WELLNESS;
const LW = HesProfile.LONGEVITY_WELLNESS;

const BASICS: HealthScope[] = [
  HealthScope.STEPS,
  HealthScope.RESTING_HEART_RATE,
  HealthScope.SLEEP,
  HealthScope.ACTIVITY_MINUTES
];

function without(scope: HealthScope): HealthScope[] {
  const out: HealthScope[] = [];
  for (let i = 0; i < ALL_HEALTH_SCOPES.length; i++) {
    if (ALL_HEALTH_SCOPES[i] !== scope) {
      out.push(ALL_HEALTH_SCOPES[i]);
    }
  }
  return out;
}

// The session of a person whose days came from Health Sim with the same consent.
function fromHealthSim(id: string, scopes: HealthScope[]): HesSession {
  const person: HealthSimPerson | null = healthSimPerson(withScopes(healthSimPayloadFromPersonas(), scopes), id);
  expect(person !== null).assertTrue();
  return engineSessionFrom(person as HealthSimPerson, scopes);
}

function validCount(result: HesResult, id: ComponentId): number {
  for (let i = 0; i < result.components.length; i++) {
    const c: ComponentResult = result.components[i];
    if (c.id === id) {
      return c.validCount;
    }
  }
  return -1;
}

// The fields of one data type in one day; every one of them is undefined when the type is switched off.
// VO2max estimates and recovery sessions are not part of a day: they are checked on the history.
function fieldsOf(day: HesDayRecord, scope: HealthScope): (number | undefined)[] {
  switch (scope) {
    case HealthScope.STEPS:
      return [day.steps];
    case HealthScope.RESTING_HEART_RATE:
      return [day.restingHr];
    case HealthScope.SLEEP: {
      const sleep = day.sleep;
      return sleep === undefined ? [undefined] : [sleep.bedMin, sleep.wakeMin, sleep.totalSleepMin];
    }
    case HealthScope.ACTIVITY_MINUTES:
      return [day.moderateMin, day.vigorousMin];
    case HealthScope.HRV: {
      const hrv = day.hrv;
      return hrv === undefined ? [undefined] : [hrv.percentile];
    }
    default:
      return [];
  }
}

function expectResult(r: HesResult, score: number, tier: HesTier, coverage: number,
  confidence: HesConfidence): void {
  expect(r.status).assertEqual(HesStatus.OK);
  expect(r.score).assertEqual(score);
  expect(r.tier).assertEqual(tier);
  expect(r.coverage).assertEqual(coverage);
  expect(r.confidence).assertEqual(confidence);
}

export default function consentScopesTest() {
  describe('Consent scopes', () => {
    it('with no scopes given the six personas have the golden results in both profiles', 0, () => {
      expectResult(engineSession('ania').current(HW), 92, HesTier.A, 100, HesConfidence.HIGH);
      expectResult(engineSession('marek').current(HW), 75, HesTier.B, 87.5, HesConfidence.HIGH);
      expectResult(engineSession('kasia').current(HW), 73, HesTier.B, 75, HesConfidence.MEDIUM);
      expectResult(engineSession('tomek').current(HW), 79, HesTier.B, 92.5, HesConfidence.HIGH);
      expectResult(engineSession('ewa').current(HW), 59, HesTier.C, 80, HesConfidence.MEDIUM);
      expectResult(engineSession('marek').current(LW), 76, HesTier.B, 77.5, HesConfidence.MEDIUM);
      expectResult(engineSession('kasia').current(LW), 74, HesTier.B, 65, HesConfidence.LOW);
      const profiles: HesProfile[] = [HW, LW];
      for (let p = 0; p < profiles.length; p++) {
        const ola = engineSession('ola').current(profiles[p]);
        expect(ola.status).assertEqual(HesStatus.INSUFFICIENT_DATA);
        expect(ola.score).assertUndefined();
        expect(ola.coverage).assertEqual(47.5);
        expect(ola.confidence).assertEqual(HesConfidence.NOT_ENOUGH_DATA);
      }
    });

    it('with no scopes the built-in path and the Health Sim path give the same result, also after a closed day',
      0, () => {
        const ids: string[] = ['ania', 'marek', 'kasia', 'tomek', 'ewa', 'ola'];
        for (let i = 0; i < ids.length; i++) {
          const builtIn = engineSession(ids[i]);
          const sim = fromHealthSim(ids[i], ALL_HEALTH_SCOPES);
          expect(sim.current(HW)).assertDeepEquals(builtIn.current(HW));
          expect(sim.current(LW)).assertDeepEquals(builtIn.current(LW));
          builtIn.closeDay();
          sim.closeDay();
          expect(sim.current(HW)).assertDeepEquals(builtIn.current(HW));
          expect(sim.current(LW)).assertDeepEquals(builtIn.current(LW));
        }
      });

    it('Ania without HRV: 93 · A · 92.5% · High in Health & wellness, on both paths', 0, () => {
      const scopes = without(HealthScope.HRV);
      expectResult(engineSession('ania', scopes).current(HW), 93, HesTier.A, 92.5, HesConfidence.HIGH);
      expectResult(fromHealthSim('ania', scopes).current(HW), 93, HesTier.A, 92.5, HesConfidence.HIGH);
      // Longevity: HRV weighs 7.5% there too, so the coverage is the same. The score is
      // (225 x 89.2 + 150 x 97 + 150 x 93.2 + 175 x 97 + 100 x 90 + 75 x 99 + 50 x 74) / 925 = 92.65, which is 93.
      expectResult(engineSession('ania', scopes).current(LW), 93, HesTier.A, 92.5, HesConfidence.HIGH);
    });

    it('Ania with the four basic types: 95 · A · 75% · Medium, and eight closed days do not bring the rest back',
      0, () => {
        // Without VO2max, HRV and recovery the coverage is 100 - 12.5 - 7.5 - 5 = 75%. The score is
        // (125 x 97 + 200 x 93.2 + 150 x 97 + 150 x 90 + 125 x 99) / 750 = 94.92, which is 95. The confidence
        // index is the coverage (0.75) times the quality (1.0): Medium.
        const sessions: HesSession[] = [engineSession('ania', BASICS), fromHealthSim('ania', BASICS)];
        for (let s = 0; s < sessions.length; s++) {
          const session = sessions[s];
          expectResult(session.current(HW), 95, HesTier.A, 75, HesConfidence.MEDIUM);
          for (let i = 0; i < 8; i++) {
            session.closeDay();
          }
          const after = session.current(HW);
          expect(after.coverage).assertEqual(75);
          expect(validCount(after, ComponentId.CRF)).assertEqual(0);
          expect(validCount(after, ComponentId.HRV)).assertEqual(0);
          expect(validCount(after, ComponentId.HRR)).assertEqual(0);
        }
      });

    it('Ania without sleep has no score, coverage 72.5%, on both paths and in both profiles', 0, () => {
      const scopes = without(HealthScope.SLEEP);
      const sessions: HesSession[] = [engineSession('ania', scopes), fromHealthSim('ania', scopes)];
      for (let s = 0; s < sessions.length; s++) {
        // Sleep regularity (15%) and sleep duration (12.5%) are Core: a score needs both.
        const hw = sessions[s].current(HW);
        expect(hw.status).assertEqual(HesStatus.INSUFFICIENT_DATA);
        expect(hw.score).assertUndefined();
        expect(hw.tier).assertEqual(HesTier.NONE);
        expect(hw.coverage).assertEqual(72.5);
        expect(hw.confidence).assertEqual(HesConfidence.NOT_ENOUGH_DATA);
        // Longevity: 100 - 10 - 7.5 = 82.5.
        const lw = sessions[s].current(LW);
        expect(lw.status).assertEqual(HesStatus.INSUFFICIENT_DATA);
        expect(lw.coverage).assertEqual(82.5);
      }
    });

    it('each type switched off in turn: the three days closed afterwards have none of its fields', 0, () => {
      for (let t = 0; t < ALL_HEALTH_SCOPES.length; t++) {
        const off = ALL_HEALTH_SCOPES[t];
        const sessions: HesSession[] = [engineSession('ania', without(off)), fromHealthSim('ania', without(off))];
        for (let s = 0; s < sessions.length; s++) {
          const session = sessions[s];
          const before = session.historyLength();
          for (let i = 0; i < 3; i++) {
            session.closeDay();
          }
          const history = session.history();
          expect(history.days.length).assertEqual(before + 3);
          for (let d = history.days.length - 3; d < history.days.length; d++) {
            const fields = fieldsOf(history.days[d], off);
            for (let f = 0; f < fields.length; f++) {
              expect(fields[f]).assertUndefined();
            }
            // A type that is still on keeps its values in the closed days.
            const kept = off === HealthScope.STEPS ? HealthScope.RESTING_HEART_RATE : HealthScope.STEPS;
            expect(fieldsOf(history.days[d], kept)[0] !== undefined).assertTrue();
          }
          // VO2max estimates and recovery sessions are not part of a day.
          expect(history.crf.length === 0).assertEqual(off === HealthScope.VO2MAX);
          expect(history.hrr.length === 0).assertEqual(off === HealthScope.WORKOUTS);
        }
      }
    });

    it('without VO2MAX there are no estimates, without WORKOUTS no recovery sessions', 0, () => {
      const noCrf = engineSession('tomek', without(HealthScope.VO2MAX));
      expect(noCrf.history().crf.length).assertEqual(0);
      expect(noCrf.history().hrr.length > 0).assertTrue();
      expect(validCount(noCrf.current(HW), ComponentId.CRF)).assertEqual(0);
      const noHrr = engineSession('tomek', without(HealthScope.WORKOUTS));
      expect(noHrr.history().hrr.length).assertEqual(0);
      expect(noHrr.history().crf.length > 0).assertTrue();
      expect(validCount(noHrr.current(HW), ComponentId.HRR)).assertEqual(0);
      // Tomek lacks nothing Core without them: the score stays, only the coverage falls. Tomek has no HRV, so
      // his full coverage is 92.5; without VO2max (12.5) it is 80, without recovery (5) it is 87.5.
      expect(noCrf.current(HW).status).assertEqual(HesStatus.OK);
      expect(noCrf.current(HW).coverage).assertEqual(80);
      expect(noHrr.current(HW).coverage).assertEqual(87.5);
    });

    it('dayWithScopes leaves the day it was given unchanged and keeps everything when every type is on', 0, () => {
      const day = engineSession('ania').history().days[0];
      const steps = day.steps;
      const blank = dayWithScopes(day, []);
      expect(blank.steps).assertUndefined();
      expect(blank.restingHr).assertUndefined();
      expect(blank.sleep).assertUndefined();
      expect(blank.moderateMin).assertUndefined();
      expect(blank.vigorousMin).assertUndefined();
      expect(blank.hrv).assertUndefined();
      expect(blank.date).assertEqual(day.date);
      expect(day.steps).assertEqual(steps);
      expect(day.steps !== undefined).assertTrue();
      const same = dayWithScopes(day, ALL_HEALTH_SCOPES);
      expect(same.steps).assertEqual(day.steps);
      expect(same.hrv).assertDeepEquals(day.hrv);
      expect(same.sleep).assertDeepEquals(day.sleep);
    });

    it('an unknown id gives the default persona with the scopes applied', 0, () => {
      expectResult(engineSession('nobody', without(HealthScope.HRV)).current(HW), 93, HesTier.A, 92.5,
        HesConfidence.HIGH);
    });
  });
}
