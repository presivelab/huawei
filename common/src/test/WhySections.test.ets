import { describe, it, expect } from '@ohos/hypium';
import { ComponentId, ComponentRow, PersonaReport } from '../main/ets/report/ReportModels';
import { previewReport, previewReports } from './fixtures/PreviewReports';
import { engineReports } from '../main/ets/report/EngineReports';
import { scoreEvidence, weightText, whySections } from '../main/ets/report/WhySections';

function ids(rows: ComponentRow[]): string {
  const out: string[] = [];
  for (let i = 0; i < rows.length; i++) {
    out.push(rows[i].id);
  }
  return out.join(',');
}

function checkSections(report: PersonaReport): void {
  const why = whySections(report);
  for (let i = 0; i < why.strongest.length; i++) {
    expect(why.strongest[i].available).assertTrue();
    expect(why.improvement.indexOf(why.strongest[i])).assertEqual(-1);
  }
  for (let i = 0; i < why.improvement.length; i++) {
    // Missing data is never a weak factor.
    expect(why.improvement[i].available).assertTrue();
  }
  for (let i = 0; i < why.missing.length; i++) {
    expect(why.missing[i].available).assertFalse();
  }
  expect(why.strongest.length <= 3).assertTrue();
  expect(why.improvement.length <= 3).assertTrue();
}

export default function whySectionsTest() {
  describe('Why this tier: sections', () => {
    it('Tomek: the three strongest, the three to improve, HRV missing', 0, () => {
      const why = whySections(previewReport('tomek'));
      expect(ids(why.strongest))
        .assertEqual([ComponentId.SLEEP_REGULARITY, ComponentId.VO2MAX, ComponentId.STEPS].join(','));
      // Lowest first; equal scores (active minutes and sleep, both 67) keep the order of the report.
      expect(ids(why.improvement))
        .assertEqual([ComponentId.HR_RECOVERY, ComponentId.ACTIVE_MINUTES, ComponentId.SLEEP].join(','));
      expect(ids(why.missing)).assertEqual(ComponentId.HRV);
    });

    it('five available components give three strongest and two to improve', 0, () => {
      const why = whySections(previewReport('kasia'));
      expect(why.strongest.length).assertEqual(3);
      expect(why.improvement.length).assertEqual(2);
      expect(why.missing.length).assertEqual(3);
    });

    it('no component is in two lists and a missing one is never "to improve"', 0, () => {
      const preview = previewReports();
      for (let i = 0; i < preview.length; i++) {
        checkSections(preview[i]);
      }
      const engine = engineReports();
      for (let i = 0; i < engine.length; i++) {
        checkSections(engine[i]);
      }
    });

    it('without a score there is no tier to explain', 0, () => {
      const why = whySections(previewReport('ola'));
      expect(why.strongest.length).assertEqual(0);
      expect(why.improvement.length).assertEqual(0);
      // Steps and active minutes have enough days; the other six components are still without a value.
      expect(why.missing.length).assertEqual(6);
    });

    it('Ola: what is measured so far and what the score still needs', 0, () => {
      const ola: PersonaReport = previewReport('ola');
      const e = scoreEvidence(ola);
      expect(ids(e.measured)).assertEqual([ComponentId.STEPS, ComponentId.ACTIVE_MINUTES].join(','));
      expect(ids(e.needed))
        .assertEqual([ComponentId.RESTING_HR, ComponentId.SLEEP, ComponentId.SLEEP_REGULARITY].join(','));
      expect(ids(e.notMeasured))
        .assertEqual([ComponentId.VO2MAX, ComponentId.HRV, ComponentId.HR_RECOVERY].join(','));
      expect(e.measured.length + e.needed.length + e.notMeasured.length).assertEqual(ola.components.length);
      for (let i = 0; i < e.needed.length; i++) {
        expect(e.needed[i].validCount < e.needed[i].minCount).assertTrue();
      }
    });

    it('every component of every report is in exactly one evidence list', 0, () => {
      const all = previewReports().concat(engineReports());
      for (let i = 0; i < all.length; i++) {
        const e = scoreEvidence(all[i]);
        expect(e.measured.length + e.needed.length + e.notMeasured.length)
          .assertEqual(all[i].components.length);
      }
    });

    it('the weight is written as the report carries it', 0, () => {
      const tomek: PersonaReport = previewReport('tomek');
      expect(weightText(tomek.components[0])).assertEqual('16%');
    });
  });
}
