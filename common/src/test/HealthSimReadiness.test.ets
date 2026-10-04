import { describe, it, expect } from '@ohos/hypium';
import {
  decodeHealthSimPayload,
  encodeHealthSimPayload,
  healthSimPayloadFromPersonas,
  healthSimPerson,
  HealthSimPerson
} from '../main/ets/health/HealthSimPayload';
import {
  healthSimReadiness,
  HealthSimReadiness,
  READINESS_NOTE,
  ReadinessRow
} from '../main/ets/health/HealthSimReadiness';
import { computeHes } from '../main/ets/hes/HesEngine';
import { hesSummaryText } from '../main/ets/hes/HesFormat';
import { HES_PROFILES } from '../main/ets/hes/HesModel';
import { HesPersonas } from '../main/ets/hes/HesPersonas';
import { ComponentId, HesProfile } from '../main/ets/hes/HesTypes';
import { engineReportFromPerson, engineSessionFrom } from '../main/ets/report/EngineReports';
import { hasScore } from '../main/ets/report/ReportModels';

// Health Sim has no logic of its own to test: its Scenario tool renders this model. These are its tests.

function received(id: string): HealthSimPerson {
  const payload = decodeHealthSimPayload(encodeHealthSimPayload(healthSimPayloadFromPersonas()));
  if (payload === null) {
    throw new Error('the payload did not read');
  }
  const person = healthSimPerson(payload, id);
  if (person === null) {
    throw new Error('person not in the payload');
  }
  return person;
}

function row(readiness: HealthSimReadiness, id: ComponentId): ReadinessRow {
  for (let i = 0; i < readiness.rows.length; i++) {
    if (readiness.rows[i].id === id) {
      return readiness.rows[i];
    }
  }
  throw new Error('row not in the readiness');
}

export default function healthSimReadinessTest() {
  describe('Health Sim readiness', () => {
    it('the preview of every persona in both profiles', 0, () => {
      const lines: string[] = [];
      for (let i = 0; i < HesPersonas.IDS.length; i++) {
        const readiness = healthSimReadiness(HesPersonas.history(HesPersonas.IDS[i]));
        expect(readiness.previews.length).assertEqual(2);
        expect(readiness.previews[0].profile).assertEqual(HesProfile.HEALTH_WELLNESS);
        expect(readiness.previews[1].profile).assertEqual(HesProfile.LONGEVITY_WELLNESS);
        lines.push(`${HesPersonas.IDS[i]}: ${readiness.previews[0].summary} | ${readiness.previews[1].summary}`);
      }
      expect(lines).assertDeepEquals([
        'ania: 92 · A · 100% · High | 92 · A · 100% · High',
        'marek: 75 · B · 87.5% · High | 76 · B · 77.5% · Medium',
        'kasia: 73 · B · 75% · Medium | 74 · B · 65% · Low',
        'tomek: 79 · B · 92.5% · High | 79 · B · 92.5% · High',
        'ewa: 59 · C · 80% · Medium | 59 · C · 70% · Medium',
        'ola: No score · 47.5% | No score · 47.5%'
      ]);
    });

    it('the preview in Health Sim is what FairWear calculates from the exported data, for everyone', 0, () => {
      for (let i = 0; i < HesPersonas.IDS.length; i++) {
        const id = HesPersonas.IDS[i];
        // Health Sim: its own history. FairWear: the history after it travelled through the contract.
        const readiness = healthSimReadiness(HesPersonas.history(id));
        const person = received(id);
        const session = engineSessionFrom(person);
        for (let p = 0; p < HES_PROFILES.length; p++) {
          const inFairWear = session.current(HES_PROFILES[p]);
          const preview = readiness.previews[p];
          expect(preview.summary).assertEqual(hesSummaryText(inFairWear));
          expect(preview.tier).assertEqual(inFairWear.tier);
          const report = engineReportFromPerson(person, session, HES_PROFILES[p]);
          expect(preview.coverageText).assertEqual(report.coverageText);
          expect(preview.confidenceText).assertEqual(report.confidence);
          expect(preview.scored).assertEqual(hasScore(report));
          if (preview.scored) {
            expect(preview.scoreText).assertEqual(`${report.hes}`);
          }
          expect(inFairWear).assertDeepEquals(computeHes(HES_PROFILES[p], HesPersonas.history(id)));
        }
      }
    });

    it('eight rows: the count against the minimum and the target, Core or Optional, ready or not', 0, () => {
      const kasia = healthSimReadiness(HesPersonas.history('kasia'));
      expect(kasia.rows.length).assertEqual(8);
      expect(row(kasia, ComponentId.RHR).countText).assertEqual('18 of 10 / 14 days');
      expect(row(kasia, ComponentId.RHR).ready).assertTrue();
      expect(row(kasia, ComponentId.RHR).kind).assertEqual('Core');
      expect(row(kasia, ComponentId.RHR).rawText).assertEqual('72 bpm');
      expect(row(kasia, ComponentId.SLEEP_DURATION).countText).assertEqual('16 of 14 / 21 nights');
      expect(row(kasia, ComponentId.HRV).countText).assertEqual('4 of 7 / 14 nights');
      expect(row(kasia, ComponentId.HRV).ready).assertFalse();
      expect(row(kasia, ComponentId.HRV).kind).assertEqual('Optional');
      expect(row(kasia, ComponentId.HRV).rawText).assertEqual('');
      expect(row(kasia, ComponentId.CRF).countText).assertEqual('0 of 1 / 2');
      expect(row(kasia, ComponentId.HRR).countText).assertEqual('0 of 2 / 3 sessions');
      expect(kasia.coreReady).assertTrue();
      expect(kasia.note).assertEqual(READINESS_NOTE);
    });

    it('Ola: two Core rows are not ready, so there is no score in either profile', 0, () => {
      const ola = healthSimReadiness(HesPersonas.history('ola'));
      expect(ola.coreReady).assertFalse();
      expect(row(ola, ComponentId.SLEEP_REGULARITY).countText).assertEqual('6 of 14 / 21 nights');
      expect(row(ola, ComponentId.SLEEP_REGULARITY).ready).assertFalse();
      expect(row(ola, ComponentId.STEPS).countText).assertEqual('16 of 14 / 21 days');
      expect(row(ola, ComponentId.STEPS).ready).assertTrue();
      for (let p = 0; p < ola.previews.length; p++) {
        expect(ola.previews[p].scored).assertFalse();
        expect(ola.previews[p].scoreText).assertEqual('No score yet');
        expect(ola.previews[p].tier).assertEqual('NONE');
        expect(ola.previews[p].coverageText).assertEqual('47.5%');
        expect(ola.previews[p].confidenceText).assertEqual('Not enough data');
      }
    });

    it('Ania: everything is ready and the raw values read in their units', 0, () => {
      const ania = healthSimReadiness(HesPersonas.history('ania'));
      const texts: string[] = [];
      for (let i = 0; i < ania.rows.length; i++) {
        expect(ania.rows[i].ready).assertTrue();
        texts.push(ania.rows[i].rawText);
      }
      expect(texts).assertDeepEquals(['77th percentile (age & sex)', '58 bpm', '238 min/week (vigorous counts ×2)',
        '8,800/day', '±45 min', '7 h 24 min', '60th percentile', '32 bpm drop in 60 s']);
      expect(row(ania, ComponentId.CRF).countText).assertEqual('2 of 1 / 2');
      expect(row(ania, ComponentId.HRR).countText).assertEqual('3 of 2 / 3 sessions');
    });

    it('an empty history is all "0 of", with no score and zero coverage', 0, () => {
      const empty = healthSimReadiness({ days: [], crf: [], hrr: [] });
      expect(empty.coreReady).assertFalse();
      expect(empty.previews[0].coverageText).assertEqual('0%');
      expect(empty.previews[0].summary).assertEqual('No score · 0%');
      expect(row(empty, ComponentId.STEPS).countText).assertEqual('0 of 14 / 21 days');
    });
  });
}
