import { describe, it, expect } from '@ohos/hypium';
import { TIER_NO_SCORE } from '../main/ets/claim/ClaimValidation';
import { computeHes } from '../main/ets/hes/HesEngine';
import { HesPersonas } from '../main/ets/hes/HesPersonas';
import { HesPrng } from '../main/ets/hes/HesPrng';
import { validDays } from '../main/ets/hes/HesSufficiency';
import { hesComponentsFor } from '../main/ets/hes/HesCurves';
import {
  HesComponentId,
  HesComponentResult,
  HesDay,
  HesProfile,
  HesResult,
  HES_MISSING
} from '../main/ets/hes/HesTypes';

// HES vNext section 16: whatever the readings are, the engine never throws and never returns NaN or
// Infinity. A reading that is not a finite number is not evidence; a missing component is never zero.

const FUZZ_SEED = 20261004;
const FUZZ_HISTORIES = 1000;
const FUZZ_MAX_DAYS = 100;      // lengths 0..99
const BAD_SHARE = 0.25;
const MISSING_SHARE = 0.15;
const BAD_VALUES: number[] = [NaN, Infinity, -Infinity, -1, -5, 0, 1e308, Number.MAX_VALUE];
const PROFILES: HesProfile[] = [HesProfile.HEALTH_WELLNESS, HesProfile.LONGEVITY_WELLNESS];

// One reading: 25% a hostile value, 15% missing, otherwise the usual value times 0.5..1.5.
function reading(prng: HesPrng, usual: number): number {
  const roll = prng.next();
  if (roll < BAD_SHARE) {
    return BAD_VALUES[Math.floor(prng.next() * BAD_VALUES.length)];
  }
  if (roll < BAD_SHARE + MISSING_SHARE) {
    return HES_MISSING;
  }
  return usual * (0.5 + prng.next());
}

function fuzzDay(prng: HesPrng, index: number): HesDay {
  return {
    date: 'day-' + index,
    steps: reading(prng, 8000),
    restingHeartRate: reading(prng, 60),
    moderateMinutes: reading(prng, 20),
    vigorousMinutes: reading(prng, 5),
    sleepStartMin: reading(prng, 900),
    sleepEndMin: reading(prng, 420),
    sleepMinutes: reading(prng, 450),
    vo2maxPercentile: reading(prng, 50),
    hrvPercentile: reading(prng, 50),
    hrr1: reading(prng, 30)
  };
}

function fuzzHistory(prng: HesPrng): HesDay[] {
  const length = Math.floor(prng.next() * FUZZ_MAX_DAYS);
  const days: HesDay[] = [];
  for (let i = 0; i < length; i++) {
    days.push(fuzzDay(prng, i));
  }
  return days;
}

function componentViolations(c: HesComponentResult): number {
  let count = 0;
  if (!Number.isFinite(c.rawValue)) {
    count++;
  }
  if (!Number.isFinite(c.score)) {
    count++;
  }
  if (!Number.isFinite(c.quality) || c.quality < 0 || c.quality > 1) {
    count++;
  }
  if (!Number.isFinite(c.effectiveWeight) || c.effectiveWeight < 0 || c.effectiveWeight > 1) {
    count++;
  }
  if (c.available && (c.score < 0 || c.score > 100)) {
    count++;
  }
  // A component that is not available has no score and no raw value. It is never zero.
  if (!c.available && (c.score !== HES_MISSING || c.rawValue !== HES_MISSING)) {
    count++;
  }
  return count;
}

function resultViolations(result: HesResult): number {
  let count = 0;
  const hasScore = result.score !== HES_MISSING;
  if (!Number.isFinite(result.score)) {
    count++;
  } else if (hasScore && (!Number.isInteger(result.score) || result.score < 0 || result.score > 100)) {
    count++;
  }
  if (!Number.isFinite(result.coverage) || result.coverage < 0 || result.coverage > 100) {
    count++;
  }
  // Without a score there is no tier: never C.
  if (!hasScore && result.tier !== TIER_NO_SCORE) {
    count++;
  }
  if (hasScore && result.tier === TIER_NO_SCORE) {
    count++;
  }
  for (let i = 0; i < result.components.length; i++) {
    count += componentViolations(result.components[i]);
  }
  return count;
}

function stepsOf(result: HesResult): HesComponentResult {
  for (let i = 0; i < result.components.length; i++) {
    if (result.components[i].id === HesComponentId.STEPS) {
      return result.components[i];
    }
  }
  throw new Error('steps not in the result');
}

export default function hesFuzzTest() {
  describe('HES vNext section 16: never NaN, never Infinity', () => {
    it('1000 seeded histories with hostile readings, both profiles: no exception, every number finite', 0, () => {
      const prng = new HesPrng(FUZZ_SEED);
      let violations = 0;
      let exceptions = 0;
      let scored = 0;
      for (let h = 0; h < FUZZ_HISTORIES; h++) {
        const days = fuzzHistory(prng);
        for (let p = 0; p < PROFILES.length; p++) {
          try {
            const result = computeHes(days, PROFILES[p]);
            violations += resultViolations(result);
            if (result.score !== HES_MISSING) {
              scored++;
            }
          } catch (e) {
            exceptions++;
          }
        }
      }
      expect(exceptions).assertEqual(0);
      expect(violations).assertEqual(0);
      // The run is not all "no score": some histories do reach a score with hostile readings left out.
      expect(scored > 0).assertTrue();
    });

    it('one day with Infinity steps is one valid day less; the score does not change', 0, () => {
      const days = HesPersonas.history('ania');
      const before = computeHes(days);
      days[days.length - 1].steps = Infinity;
      const after = computeHes(days);
      expect(stepsOf(after).validCount).assertEqual(stepsOf(before).validCount - 1);
      expect(stepsOf(after).available).assertTrue();
      expect(Number.isFinite(stepsOf(after).rawValue)).assertTrue();
      expect(after.score).assertEqual(before.score);
      expect(after.tier).assertEqual(before.tier);
      expect(after.coverage).assertEqual(before.coverage);
    });

    it('readings that are not finite numbers are not valid days, in every component', 0, () => {
      const defs = hesComponentsFor(HesProfile.HEALTH_WELLNESS);
      const hostile: number[] = [NaN, Infinity, -Infinity];
      for (let v = 0; v < hostile.length; v++) {
        const day: HesDay = {
          date: 'day-0',
          steps: hostile[v],
          restingHeartRate: hostile[v],
          moderateMinutes: hostile[v],
          vigorousMinutes: hostile[v],
          sleepStartMin: hostile[v],
          sleepEndMin: hostile[v],
          sleepMinutes: hostile[v],
          vo2maxPercentile: hostile[v],
          hrvPercentile: hostile[v],
          hrr1: hostile[v]
        };
        for (let i = 0; i < defs.length; i++) {
          expect(validDays(defs[i], [day]).length).assertEqual(0);
        }
      }
    });

    it('finite but huge readings overflow the mean: the component is not available, never Infinity', 0, () => {
      const days = HesPersonas.history('ania');
      for (let i = days.length - 5; i < days.length; i++) {
        days[i].steps = 1e308;
      }
      const result = computeHes(days);
      const steps = stepsOf(result);
      expect(steps.available).assertFalse();
      expect(steps.rawValue).assertEqual(HES_MISSING);
      expect(steps.score).assertEqual(HES_MISSING);
      // Steps are Core, so there is no score and no tier.
      expect(result.score).assertEqual(HES_MISSING);
      expect(result.tier).assertEqual(TIER_NO_SCORE);
      expect(Number.isFinite(result.coverage)).assertTrue();
    });
  });
}
