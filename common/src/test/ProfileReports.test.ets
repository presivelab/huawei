import { describe, it, expect } from '@ohos/hypium';
import { computeHes } from '../main/ets/hes/HesEngine';
import { HesPersonas } from '../main/ets/hes/HesPersonas';
import { HesProfile } from '../main/ets/hes/HesTypes';
import { DISCOUNT_NONE_LINE, discountLine } from '../main/ets/report/Benefit';
import {
  engineReportFor,
  engineReportOf,
  engineSession,
  profileChoice,
  profileFromChoice,
  profileNote,
  SHARE_PROFILE,
  shareProfileLine
} from '../main/ets/report/EngineReports';
import {
  BenefitLevel,
  hasScore,
  HES_NONE,
  ReportConfidence,
  ReportTier
} from '../main/ets/report/ReportModels';

const HEALTH = HesProfile.HEALTH_WELLNESS;
const LIFE = HesProfile.LONGEVITY_WELLNESS;

// The profile switch of the Report tab: the same completed days with the weights of another product.
// Share, the partner and the benefit behind the code stay on health insurance.
export default function profileReportsTest() {
  describe('Engine reports: the profile chosen on the Report tab', () => {
    it('Tomek: 80 / A / 92.5% for life insurance, while the report Share uses stays 79 / B', 0, () => {
      const session = engineSession('tomek');
      const life = engineReportFor('tomek', session, LIFE);
      expect(life.profile).assertEqual(LIFE);
      expect(life.hes).assertEqual(80);
      expect(life.tier).assertEqual(ReportTier.A);
      expect(life.coveragePct).assertEqual(92.5);
      expect(life.confidence).assertEqual(ReportConfidence.HIGH);
      expect(life.benefit).assertEqual(BenefitLevel.FULL);
      expect(life.discountPct).assertEqual(10);

      const shared = engineReportOf('tomek', session);
      expect(shared.profile).assertEqual(HEALTH);
      expect(shared.hes).assertEqual(79);
      expect(shared.tier).assertEqual(ReportTier.B);
      expect(shared.coveragePct).assertEqual(92.5);
      expect(shared.pointsToNext).assertEqual(1);
      expect(shared.discountPct).assertEqual(8);
    });

    it('asking for another profile does not change the session Share reads', 0, () => {
      const session = engineSession('tomek');
      const before = engineReportOf('tomek', session);
      engineReportFor('tomek', session, LIFE);
      expect(session.profile()).assertEqual(SHARE_PROFILE);
      expect(engineReportOf('tomek', session)).assertDeepEquals(before);
    });

    it('for health insurance the report is the one every other screen gets, for all six personas', 0, () => {
      for (let i = 0; i < HesPersonas.IDS.length; i++) {
        const id = HesPersonas.IDS[i];
        const session = engineSession(id);
        session.setLive(72, 1234);
        expect(engineReportFor(id, session, HEALTH)).assertDeepEquals(engineReportOf(id, session));
      }
    });

    it('after Close the day the other profile is calculated on the history with the added day', 0, () => {
      const session = engineSession('tomek');
      const days = session.history().length;
      session.closeDay();
      expect(session.history().length).assertEqual(days + 1);

      const health = engineReportFor('tomek', session, HEALTH);
      const life = engineReportFor('tomek', session, LIFE);
      expect(health.hes).assertEqual(78);
      expect(health.tier).assertEqual(ReportTier.B);
      expect(life.hes).assertEqual(80);
      expect(life.tier).assertEqual(ReportTier.A);
      expect(health.coveragePct).assertEqual(92.5);
      expect(life.coveragePct).assertEqual(92.5);
      expect(life.hes).assertEqual(computeHes(session.history(), LIFE).score);
      // Not the starting history: there the health score is 79.
      expect(health.hes).assertEqual(computeHes(session.history(), HEALTH).score);
      expect(computeHes(HesPersonas.history('tomek'), HEALTH).score).assertEqual(79);
    });

    it('the live values are the same in both profiles and are never scored', 0, () => {
      const session = engineSession('ania');
      const before = engineReportFor('ania', session, LIFE);
      session.setLive(88, 4321);
      const life = engineReportFor('ania', session, LIFE);
      const health = engineReportFor('ania', session, HEALTH);
      expect(life.live.hr).assertEqual(88);
      expect(life.live.steps).assertEqual(4321);
      expect(health.live.hr).assertEqual(88);
      expect(health.live.steps).assertEqual(4321);
      expect(life.hes).assertEqual(before.hes);
      expect(life.wear).assertDeepEquals(health.wear);
    });

    it('Ola has no score in either profile: coverage 47.5%', 0, () => {
      const session = engineSession('ola');
      const profiles = [HEALTH, LIFE];
      for (let i = 0; i < profiles.length; i++) {
        const report = engineReportFor('ola', session, profiles[i]);
        expect(hasScore(report)).assertFalse();
        expect(report.hes).assertEqual(HES_NONE);
        expect(report.tier).assertEqual(ReportTier.NONE);
        expect(report.coveragePct).assertEqual(47.5);
        expect(report.confidence).assertEqual(ReportConfidence.INSUFFICIENT);
        expect(report.discountPct).assertEqual(0);
      }
    });

    it('the choice is kept with its persona: another persona starts on health insurance', 0, () => {
      const choice = profileChoice('tomek', LIFE);
      expect(profileFromChoice(choice, 'tomek')).assertEqual(LIFE);
      expect(profileFromChoice(choice, 'ania')).assertEqual(HEALTH);
      expect(profileFromChoice(profileChoice('tomek', HEALTH), 'tomek')).assertEqual(HEALTH);
      expect(profileFromChoice('', 'tomek')).assertEqual(HEALTH);
      expect(profileFromChoice('tomek|SOMETHING_ELSE', 'tomek')).assertEqual(HEALTH);
    });

    it('the texts: the discount per profile and the product the code is for', 0, () => {
      expect(shareProfileLine()).assertEqual('For: Health insurance');
      expect(discountLine(HEALTH, 8)).assertEqual('Illustrative discount: 8% of the monthly premium');
      expect(discountLine(LIFE, 10)).assertEqual('Illustrative discount: 10% of the yearly premium');
      expect(discountLine(HEALTH, 0)).assertEqual(DISCOUNT_NONE_LINE);

      const session = engineSession('tomek');
      expect(profileNote(engineReportFor('tomek', session, HEALTH)))
        .assertEqual('Illustrative discount: 8% of the monthly premium');
      expect(profileNote(engineReportFor('tomek', session, LIFE)))
        .assertEqual('Illustrative discount: 10% of the yearly premium · The code on Share is for health insurance');
      // Ola has no score, so there is no code to speak of.
      expect(profileNote(engineReportFor('ola', engineSession('ola'), LIFE))).assertEqual(DISCOUNT_NONE_LINE);
      // Marek is flagged: no benefit and no discount in either profile.
      expect(profileNote(engineReportFor('marek', engineSession('marek'), HEALTH))).assertEqual(DISCOUNT_NONE_LINE);
    });
  });
}
