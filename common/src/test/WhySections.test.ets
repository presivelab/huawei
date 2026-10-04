import { describe, it, expect } from '@ohos/hypium';
import { ComponentId, ComponentRow, PersonaReport } from '../main/ets/report/ReportModels';
import { previewReport, previewReports } from '../main/ets/report/PreviewReports';
import { engineReport, engineReports } from '../main/ets/report/EngineReports';
import { HES_PROFILES } from '../main/ets/hes/HesModel';
import { HesProfile } from '../main/ets/hes/HesTypes';
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
      for (let p = 0; p < HES_PROFILES.length; p++) {
        const engine = engineReports(HES_PROFILES[p]);
        for (let i = 0; i < engine.length; i++) {
          checkSections(engine[i]);
        }
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
      const all = previewReports().concat(engineReports(), engineReports(HesProfile.LONGEVITY_WELLNESS));
      for (let i = 0; i < all.length; i++) {
        const e = scoreEvidence(all[i]);
        expect(e.measured.length + e.needed.length + e.notMeasured.length)
          .assertEqual(all[i].components.length);
      }
    });

    // The golden lists of the specification. The component scores are the same in both profiles and so are
    // the lists.
    it('golden lists: the strongest, the ones to improve and the optional ones that are missing, in both profiles',
      0, () => {
        for (let p = 0; p < HES_PROFILES.length; p++) {
          const profile = HES_PROFILES[p];
          const ania = whySections(engineReport('ania', profile));
          expect(ids(ania.strongest))
            .assertEqual([ComponentId.SLEEP, ComponentId.STEPS, ComponentId.RESTING_HR].join(','));
          expect(ids(ania.improvement))
            .assertEqual([ComponentId.HR_RECOVERY, ComponentId.HRV, ComponentId.VO2MAX].join(','));
          expect(ania.missing.length).assertEqual(0);
          expect(ania.missingOptional.length).assertEqual(0);

          const marek = whySections(engineReport('marek', profile));
          expect(ids(marek.strongest))
            .assertEqual([ComponentId.RESTING_HR, ComponentId.SLEEP, ComponentId.STEPS].join(','));
          expect(ids(marek.improvement))
            .assertEqual([ComponentId.HR_RECOVERY, ComponentId.HRV, ComponentId.ACTIVE_MINUTES].join(','));
          expect(ids(marek.missingOptional)).assertEqual(ComponentId.VO2MAX);

          const kasia = whySections(engineReport('kasia', profile));
          expect(ids(kasia.strongest))
            .assertEqual([ComponentId.RESTING_HR, ComponentId.STEPS, ComponentId.SLEEP].join(','));
          // Five available components give 3 + 2.
          expect(ids(kasia.improvement))
            .assertEqual([ComponentId.ACTIVE_MINUTES, ComponentId.SLEEP_REGULARITY].join(','));
          expect(ids(kasia.missingOptional))
            .assertEqual([ComponentId.VO2MAX, ComponentId.HRV, ComponentId.HR_RECOVERY].join(','));

          const tomek = whySections(engineReport('tomek', profile));
          expect(ids(tomek.strongest))
            .assertEqual([ComponentId.RESTING_HR, ComponentId.STEPS, ComponentId.SLEEP].join(','));
          expect(ids(tomek.improvement))
            .assertEqual([ComponentId.HR_RECOVERY, ComponentId.SLEEP_REGULARITY, ComponentId.VO2MAX].join(','));
          expect(ids(tomek.missingOptional)).assertEqual(ComponentId.HRV);

          const ewa = whySections(engineReport('ewa', profile));
          expect(ids(ewa.strongest))
            .assertEqual([ComponentId.RESTING_HR, ComponentId.SLEEP, ComponentId.SLEEP_REGULARITY].join(','));
          expect(ids(ewa.improvement))
            .assertEqual([ComponentId.HR_RECOVERY, ComponentId.ACTIVE_MINUTES, ComponentId.STEPS].join(','));
          expect(ids(ewa.missingOptional)).assertEqual([ComponentId.VO2MAX, ComponentId.HRV].join(','));

          const ola = whySections(engineReport('ola', profile));
          expect(ola.strongest.length).assertEqual(0);
          expect(ola.improvement.length).assertEqual(0);
        }
      });

    it('Ola: the Core components that are short and the optional ones that are not there yet, with their counts',
      0, () => {
        const ola = engineReport('ola');
        const why = whySections(ola);
        // Five components have no value: two Core ones (sleep) and three optional ones.
        expect(why.missing.length).assertEqual(5);
        expect(ids(why.missingOptional))
          .assertEqual([ComponentId.VO2MAX, ComponentId.HRV, ComponentId.HR_RECOVERY].join(','));
        const needed: ComponentRow[] = [];
        const measured: ComponentRow[] = [];
        for (let i = 0; i < ola.components.length; i++) {
          const row = ola.components[i];
          if (row.available) {
            measured.push(row);
          } else if (row.core) {
            needed.push(row);
          }
        }
        expect(ids(measured))
          .assertEqual([ComponentId.STEPS, ComponentId.ACTIVE_MINUTES, ComponentId.RESTING_HR].join(','));
        expect(ids(needed)).assertEqual([ComponentId.SLEEP, ComponentId.SLEEP_REGULARITY].join(','));
        expect(needed[0].countText).assertEqual('6 of 14 nights');
        expect(needed[1].countText).assertEqual('6 of 14 nights');
        expect(why.missingOptional[0].countText).assertEqual('0 of 1');
        expect(why.missingOptional[1].countText).assertEqual('6 of 7 nights');
        expect(why.missingOptional[2].countText).assertEqual('0 of 2 sessions');
      });

    it('Ola: scoreEvidence lists the same three groups as the Why screen: measured, needed, optional not yet',
      0, () => {
        // The Why screen shows measured rhr, mvpa, steps; needed sleep regularity and sleep duration; and the
        // optional ones that are not there yet: VO2max 0 of 1, HRV 6 of 7 nights, recovery 0 of 2 sessions.
        const e = scoreEvidence(engineReport('ola'));
        expect(ids(e.measured))
          .assertEqual([ComponentId.STEPS, ComponentId.ACTIVE_MINUTES, ComponentId.RESTING_HR].join(','));
        expect(ids(e.needed)).assertEqual([ComponentId.SLEEP, ComponentId.SLEEP_REGULARITY].join(','));
        expect(ids(e.notMeasured))
          .assertEqual([ComponentId.VO2MAX, ComponentId.HRV, ComponentId.HR_RECOVERY].join(','));
      });

    it('equal scores: the higher weight goes first, then the model order', 0, () => {
      const copy: PersonaReport = JSON.parse(JSON.stringify(engineReport('marek'))) as PersonaReport;
      for (let i = 0; i < copy.components.length; i++) {
        copy.components[i].scoreExact = 70;
      }
      const why = whySections(copy);
      // Weights: activity 22.9, steps and timing 17.1, resting HR and sleep 14.3, HRV 8.6, recovery 5.7.
      expect(ids(why.strongest))
        .assertEqual([ComponentId.ACTIVE_MINUTES, ComponentId.STEPS, ComponentId.SLEEP_REGULARITY].join(','));
      // Lowest first; all equal, so again the higher weight first and, between 14.3 and 14.3, the model order.
      expect(ids(why.improvement))
        .assertEqual([ComponentId.RESTING_HR, ComponentId.SLEEP, ComponentId.HRV].join(','));
    });

    it('the weight text of a row is the one-decimal text of the report', 0, () => {
      expect(weightText(engineReport('ewa').components[0])).assertEqual('18.8%');
      expect(weightText(engineReport('ania').components[0])).assertEqual('15.0%');
      expect(weightText(engineReport('kasia').components[1])).assertEqual('26.7%');
    });

    it('the weight is written as the report carries it', 0, () => {
      const tomek: PersonaReport = previewReport('tomek');
      expect(weightText(tomek.components[0])).assertEqual('14%');
    });
  });
}
