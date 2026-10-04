import { describe, it, expect } from '@ohos/hypium';
import { TIER_A, TIER_B, TIER_C, TIER_NO_SCORE } from '../main/ets/claim/ClaimValidation';
import { observedHes } from '../main/ets/hes/HesComposite';
import { computeHes } from '../main/ets/hes/HesEngine';
import {
  generatePersonaDay,
  generatePersonaHistory,
  HesPersonas,
  HesPersonaSpec,
  HES_PERSONA_END_DATE
} from '../main/ets/hes/HesPersonas';
import { HesPrng } from '../main/ets/hes/HesPrng';
import { pointsToNextTier } from '../main/ets/hes/HesTier';
import {
  HesComponentResult,
  HesConfidence,
  HesDay,
  HesProfile,
  HesResult,
  HesStatus,
  HES_MISSING
} from '../main/ets/hes/HesTypes';
import { whyThisTier } from '../main/ets/hes/HesWhy';
import { dateOfDayNumber, dayNumberOfDate } from '../main/ets/watchlink/WatchLinkTypes';

function availableIds(result: HesResult): string[] {
  const out: string[] = [];
  for (let i = 0; i < result.components.length; i++) {
    if (result.components[i].available) {
      out.push(result.components[i].id);
    }
  }
  return out;
}

function byId(result: HesResult, id: string): HesComponentResult {
  for (let i = 0; i < result.components.length; i++) {
    if ((result.components[i].id as string) === id) {
      return result.components[i];
    }
  }
  throw new Error('component not in the result');
}

function specOf(id: string): HesPersonaSpec {
  const spec = HesPersonas.spec(id);
  if (spec === null) {
    throw new Error('unknown persona');
  }
  return spec;
}

// The fixed table: tier, score, coverage, confidence, for one profile (health insurance when not named).
function expectResult(id: string, tier: string, score: number, coveragePct: number,
  confidence: HesConfidence, profile: HesProfile = HesProfile.HEALTH_WELLNESS): void {
  const result = HesPersonas.result(id, profile);
  expect(result.profile).assertEqual(profile);
  expect(result.tier).assertEqual(tier);
  expect(result.score).assertEqual(score);
  expect(result.coverage).assertEqual(coveragePct);
  expect(result.confidence).assertEqual(confidence);
}

const CORE: string[] = ['rhr', 'mvpa', 'sleepRegularity', 'steps', 'sleepDuration'];

export default function hesPersonasTest() {
  describe('HES personas: the fixed results, health insurance', () => {
    it('Ania: A / 92, coverage 100%, confidence High (full data)', 0, () => {
      expectResult('ania', TIER_A, 92, 100, HesConfidence.HIGH);
      expect(availableIds(HesPersonas.result('ania')).length).assertEqual(8);
    });

    it('Marek: B / 75, coverage 87.5%, confidence High (Core + VO2max)', 0, () => {
      expectResult('marek', TIER_B, 75, 87.5, HesConfidence.HIGH);
      expect(availableIds(HesPersonas.result('marek'))).assertDeepEquals(['crf'].concat(CORE));
    });

    it('Kasia: B / 71, coverage 75%, confidence Medium (Core only)', 0, () => {
      expectResult('kasia', TIER_B, 71, 75, HesConfidence.MEDIUM);
      expect(availableIds(HesPersonas.result('kasia'))).assertDeepEquals(CORE);
    });

    it('Tomek: B / 79, coverage 92.5%, confidence High, one point from A', 0, () => {
      expectResult('tomek', TIER_B, 79, 92.5, HesConfidence.HIGH);
      expect(availableIds(HesPersonas.result('tomek'))).assertDeepEquals(['crf'].concat(CORE).concat(['hrr']));
      expect(pointsToNextTier(HesPersonas.result('tomek').score)).assertEqual(1);
    });

    it('Ewa: C / 58, coverage 80%, confidence High (Core + heart-rate recovery)', 0, () => {
      expectResult('ewa', TIER_C, 58, 80, HesConfidence.HIGH);
      expect(availableIds(HesPersonas.result('ewa'))).assertDeepEquals(CORE.concat(['hrr']));
    });

    it('Ola: no score, coverage 47.5%, not enough data', 0, () => {
      const result = HesPersonas.result('ola');
      expect(result.status).assertEqual(HesStatus.INSUFFICIENT_DATA);
      expect(result.tier).assertEqual(TIER_NO_SCORE);
      expect(result.score).assertEqual(HES_MISSING);
      expect(result.coverage).assertEqual(47.5);
      expect(result.confidence).assertEqual(HesConfidence.INSUFFICIENT_DATA);
      expect(availableIds(result)).assertDeepEquals(['rhr', 'mvpa', 'steps']);
    });
  });

  describe('HES personas: the fixed results, life insurance', () => {
    it('Ania: A / 91, Marek: B / 75, Kasia: B / 71', 0, () => {
      expectResult('ania', TIER_A, 91, 100, HesConfidence.HIGH, HesProfile.LONGEVITY_WELLNESS);
      expectResult('marek', TIER_B, 75, 87.5, HesConfidence.HIGH, HesProfile.LONGEVITY_WELLNESS);
      expectResult('kasia', TIER_B, 71, 65, HesConfidence.MEDIUM, HesProfile.LONGEVITY_WELLNESS);
    });

    it('Tomek reaches A / 80: VO2max weighs 22.5% for life insurance', 0, () => {
      expectResult('tomek', TIER_A, 80, 92.5, HesConfidence.HIGH, HesProfile.LONGEVITY_WELLNESS);
    });

    it('Ewa: C / 59, coverage 70%, Medium; Ola: no score, coverage 47.5%', 0, () => {
      expectResult('ewa', TIER_C, 59, 70, HesConfidence.MEDIUM, HesProfile.LONGEVITY_WELLNESS);
      const ola = HesPersonas.result('ola', HesProfile.LONGEVITY_WELLNESS);
      expect(ola.tier).assertEqual(TIER_NO_SCORE);
      expect(ola.coverage).assertEqual(47.5);
    });
  });

  describe('HES personas: the unrounded values', () => {
    // The scores are pinned to three decimals, so any change in the generator or the engine shows here
    // before it moves a rounded score. Tomek's health score (78.501) and Marek's life score (74.511) sit
    // close to a rounding edge: a persona change can move them by one point.
    it('health insurance', 0, () => {
      const ids = ['ania', 'marek', 'kasia', 'tomek', 'ewa'];
      const values = [92.373, 74.890, 71.367, 78.501, 57.559];
      for (let i = 0; i < ids.length; i++) {
        const result = HesPersonas.result(ids[i], HesProfile.HEALTH_WELLNESS);
        expect(observedHes(result.components)).assertClose(values[i], 0.0005);
      }
    });

    it('life insurance', 0, () => {
      const ids = ['ania', 'marek', 'kasia', 'tomek', 'ewa'];
      const values = [91.183, 74.511, 71.452, 79.682, 59.385];
      for (let i = 0; i < ids.length; i++) {
        const result = HesPersonas.result(ids[i], HesProfile.LONGEVITY_WELLNESS);
        expect(observedHes(result.components)).assertClose(values[i], 0.0005);
      }
    });
  });

  describe('HES-Lite personas: the generator', () => {
    it('the ids are ania, marek, kasia, tomek, ewa, ola', 0, () => {
      expect(HesPersonas.IDS).assertDeepEquals(['ania', 'marek', 'kasia', 'tomek', 'ewa', 'ola']);
      expect(HesPersonas.displayName('ania')).assertEqual('Ania');
      expect(HesPersonas.has('ola')).assertTrue();
      expect(HesPersonas.has('nobody')).assertFalse();
    });

    it('the same persona gives the same history every time', 0, () => {
      for (let i = 0; i < HesPersonas.IDS.length; i++) {
        const id = HesPersonas.IDS[i];
        expect(HesPersonas.history(id)).assertDeepEquals(HesPersonas.history(id));
        expect(HesPersonas.result(id)).assertDeepEquals(HesPersonas.result(id));
      }
    });

    it('the seeded generator repeats its sequence and stays in [0, 1)', 0, () => {
      const a = new HesPrng(12345);
      const b = new HesPrng(12345);
      const c = new HesPrng(12346);
      let differs = false;
      for (let i = 0; i < 200; i++) {
        const value = a.next();
        expect(value).assertEqual(b.next());
        expect(value >= 0 && value < 1).assertTrue();
        if (value !== c.next()) {
          differs = true;
        }
      }
      expect(differs).assertTrue();
      expect(HesPrng.forStream(7, 3, 1).gauss()).assertEqual(HesPrng.forStream(7, 3, 1).gauss());
    });

    it('a history is one entry per calendar day, oldest first, ending on the end date', 0, () => {
      const end = dayNumberOfDate(HES_PERSONA_END_DATE);
      for (let i = 0; i < HesPersonas.IDS.length; i++) {
        const id = HesPersonas.IDS[i];
        const days = HesPersonas.history(id);
        expect(days.length).assertEqual(specOf(id).days);
        for (let d = 0; d < days.length; d++) {
          expect(days[d].date).assertEqual(dateOfDayNumber(end - (days.length - 1) + d));
        }
      }
      expect(HesPersonas.history('ania').length).assertEqual(90);
      expect(HesPersonas.history('ola').length).assertEqual(24);
    });

    it('a day depends only on the persona and its position, so closing a day continues the same series', 0, () => {
      const spec = specOf('tomek');
      const days = generatePersonaHistory(spec);
      expect(days[days.length - 1]).assertDeepEquals(generatePersonaDay(spec, 0));
      expect(days[0]).assertDeepEquals(generatePersonaDay(spec, 1 - spec.days));
      expect(generatePersonaDay(spec, 1).date).assertEqual('2026-10-04');
    });

    it('a day without the watch carries no values, never zeros', 0, () => {
      const days = HesPersonas.history('kasia');
      let offWrist = 0;
      for (let i = 0; i < days.length; i++) {
        const day: HesDay = days[i];
        if (day.steps === HES_MISSING) {
          offWrist++;
          expect(day.restingHeartRate).assertEqual(HES_MISSING);
          expect(day.moderateMinutes).assertEqual(HES_MISSING);
          expect(day.vigorousMinutes).assertEqual(HES_MISSING);
          expect(day.sleepStartMin).assertEqual(HES_MISSING);
          expect(day.sleepEndMin).assertEqual(HES_MISSING);
          expect(day.sleepMinutes).assertEqual(HES_MISSING);
        } else {
          expect(day.restingHeartRate).assertLarger(0);
        }
        expect(day.vo2maxPercentile).assertEqual(HES_MISSING);
        expect(day.hrvPercentile).assertEqual(HES_MISSING);
        expect(day.hrr1).assertEqual(HES_MISSING);
      }
      expect(offWrist).assertEqual(11);
    });

    it('Ola is short of sleep nights and recovery sessions, and the result says by how many', 0, () => {
      const result = HesPersonas.result('ola');
      expect(byId(result, 'sleepDuration').validCount).assertEqual(8);
      expect(byId(result, 'sleepDuration').minCount).assertEqual(14);
      expect(byId(result, 'sleepRegularity').validCount).assertEqual(8);
      expect(byId(result, 'hrr').validCount).assertEqual(1);
      expect(byId(result, 'hrr').minCount).assertEqual(2);
      const why = whyThisTier(result);
      expect(why.strongest.length).assertEqual(0);
      expect(why.improvement.length).assertEqual(0);
      expect(why.missing.length).assertEqual(5);
    });

    it('an unknown persona gives an empty history and no score', 0, () => {
      expect(HesPersonas.spec('nobody')).assertNull();
      expect(HesPersonas.history('nobody').length).assertEqual(0);
      const result = HesPersonas.result('nobody');
      expect(result.status).assertEqual(HesStatus.INSUFFICIENT_DATA);
      expect(result.coverage).assertEqual(0);
      expect(computeHes(HesPersonas.history('nobody')).tier).assertEqual(TIER_NO_SCORE);
    });

    it('Ewa is tier C, two points below B for health insurance and one for life insurance', 0, () => {
      expect(HesPersonas.result('ewa').tier).assertEqual(TIER_C);
      expect(pointsToNextTier(HesPersonas.result('ewa').score)).assertEqual(2);
      expect(pointsToNextTier(HesPersonas.result('ewa', HesProfile.LONGEVITY_WELLNESS).score)).assertEqual(1);
    });
  });
}
