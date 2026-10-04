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
  HesComponentId,
  HesComponentResult,
  HesConfidence,
  HesDay,
  HesResult,
  HesStatus,
  HES_MISSING
} from '../main/ets/hes/HesTypes';
import { engineSession, engineSessionFrom } from '../main/ets/report/EngineReports';

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

function validCount(result: HesResult, id: HesComponentId): number {
  for (let i = 0; i < result.components.length; i++) {
    const c: HesComponentResult = result.components[i];
    if (c.id === id) {
      return c.validCount;
    }
  }
  return -1;
}

// The fields of one data type in one day; every one of them is HES_MISSING when the type is switched off.
function fieldsOf(day: HesDay, scope: HealthScope): number[] {
  switch (scope) {
    case HealthScope.STEPS:
      return [day.steps];
    case HealthScope.RESTING_HEART_RATE:
      return [day.restingHeartRate];
    case HealthScope.SLEEP:
      return [day.sleepStartMin, day.sleepEndMin, day.sleepMinutes];
    case HealthScope.ACTIVITY_MINUTES:
      return [day.moderateMinutes, day.vigorousMinutes];
    case HealthScope.VO2MAX:
      return [day.vo2maxPercentile];
    case HealthScope.HRV:
      return [day.hrvPercentile];
    default:
      return [day.hrr1];
  }
}

function expectResult(r: HesResult, score: number, tier: string, coverage: number, confidence: HesConfidence): void {
  expect(r.status).assertEqual(HesStatus.OK);
  expect(r.score).assertEqual(score);
  expect(r.tier).assertEqual(tier);
  expect(r.coverage).assertEqual(coverage);
  expect(r.confidence).assertEqual(confidence);
}

export default function consentScopesTest() {
  describe('Consent scopes', () => {
    it('with no scopes given the six personas have the results they had before', 0, () => {
      expectResult(engineSession('ania').result(), 92, 'A', 100, HesConfidence.HIGH);
      expectResult(engineSession('marek').result(), 75, 'B', 85, HesConfidence.HIGH);
      expectResult(engineSession('kasia').result(), 73, 'B', 70, HesConfidence.MEDIUM);
      expectResult(engineSession('tomek').result(), 79, 'B', 90, HesConfidence.HIGH);
      expectResult(engineSession('ewa').result(), 59, 'C', 75, HesConfidence.MEDIUM);
      const ola = engineSession('ola').result();
      expect(ola.status).assertEqual(HesStatus.INSUFFICIENT_DATA);
      expect(ola.coverage).assertEqual(43);
      expect(ola.confidence).assertEqual(HesConfidence.INSUFFICIENT_DATA);
    });

    it('with no scopes given Ewa reaches B / 64 after one closed day, on both paths', 0, () => {
      const builtIn = engineSession('ewa');
      expectResult(builtIn.closeDay(), 64, 'B', builtIn.result().coverage, builtIn.result().confidence);
      const sim = fromHealthSim('ewa', ALL_HEALTH_SCOPES);
      expectResult(sim.result(), 59, 'C', 75, HesConfidence.MEDIUM);
      expect(sim.closeDay().score).assertEqual(64);
      expect(sim.result().tier).assertEqual('B');
    });

    it('Ania without HRV: A / 93, coverage 90%, High, the same on the built-in and the Health Sim path', 0, () => {
      const scopes = without(HealthScope.HRV);
      expectResult(engineSession('ania', scopes).result(), 93, 'A', 90, HesConfidence.HIGH);
      expectResult(fromHealthSim('ania', scopes).result(), 93, 'A', 90, HesConfidence.HIGH);
    });

    it('Ania with the four basic types: A / 96, 70%, Medium, and eight closed days do not bring the rest back',
      0, () => {
        const sessions: HesSession[] = [engineSession('ania', BASICS), fromHealthSim('ania', BASICS)];
        for (let s = 0; s < sessions.length; s++) {
          const session = sessions[s];
          expectResult(session.result(), 96, 'A', 70, HesConfidence.MEDIUM);
          for (let i = 0; i < 8; i++) {
            session.closeDay();
          }
          const after = session.result();
          expect(after.coverage).assertEqual(70);
          expect(validCount(after, HesComponentId.CRF)).assertEqual(0);
          expect(validCount(after, HesComponentId.HRV)).assertEqual(0);
          expect(validCount(after, HesComponentId.HRR)).assertEqual(0);
        }
      });

    it('Ania without sleep has no score, coverage 73%, on both paths', 0, () => {
      const scopes = without(HealthScope.SLEEP);
      const results: HesResult[] = [engineSession('ania', scopes).result(), fromHealthSim('ania', scopes).result()];
      for (let i = 0; i < results.length; i++) {
        expect(results[i].status).assertEqual(HesStatus.INSUFFICIENT_DATA);
        expect(results[i].coverage).assertEqual(73);
      }
    });

    it('each type switched off in turn: the three days closed afterwards have none of its fields', 0, () => {
      for (let t = 0; t < ALL_HEALTH_SCOPES.length; t++) {
        const off = ALL_HEALTH_SCOPES[t];
        const sessions: HesSession[] = [engineSession('ania', without(off)), fromHealthSim('ania', without(off))];
        for (let s = 0; s < sessions.length; s++) {
          const session = sessions[s];
          const before = session.history().length;
          for (let i = 0; i < 3; i++) {
            session.closeDay();
          }
          const history = session.history();
          expect(history.length).assertEqual(before + 3);
          for (let d = history.length - 3; d < history.length; d++) {
            const fields = fieldsOf(history[d], off);
            for (let f = 0; f < fields.length; f++) {
              expect(fields[f]).assertEqual(HES_MISSING);
            }
            // A type that is still on keeps its values in the closed days.
            const kept = off === HealthScope.STEPS ? HealthScope.RESTING_HEART_RATE : HealthScope.STEPS;
            expect(fieldsOf(history[d], kept)[0] !== HES_MISSING).assertTrue();
          }
        }
      }
    });

    it('dayWithScopes leaves the day it was given unchanged and keeps everything when every type is on', 0, () => {
      const day = engineSession('ania').history()[0];
      const steps = day.steps;
      const blank = dayWithScopes(day, []);
      expect(blank.steps).assertEqual(HES_MISSING);
      expect(blank.date).assertEqual(day.date);
      expect(day.steps).assertEqual(steps);
      const same = dayWithScopes(day, ALL_HEALTH_SCOPES);
      expect(same.steps).assertEqual(day.steps);
      expect(same.hrvPercentile).assertEqual(day.hrvPercentile);
      expect(same.sleepMinutes).assertEqual(day.sleepMinutes);
    });

    it('an unknown id gives the default persona with the scopes applied', 0, () => {
      expectResult(engineSession('nobody', without(HealthScope.HRV)).result(), 93, 'A', 90, HesConfidence.HIGH);
    });
  });
}
