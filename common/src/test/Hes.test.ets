import { describe, it, expect } from '@ohos/hypium';
import { TIER_A, TIER_B, TIER_C, TIER_NO_SCORE } from '../main/ets/claim/ClaimValidation';
import {
  componentScore,
  equivalentMvpa,
  evaluateComponent,
  evaluateComponents
} from '../main/ets/hes/HesComponents';
import {
  calculateObservedHes,
  coverage,
  isCoreComplete,
  observedHes
} from '../main/ets/hes/HesComposite';
import {
  calculateConfidence,
  confidenceFromIndex,
  confidenceIndex,
  weightedQuality
} from '../main/ets/hes/HesConfidence';
import {
  hesComponentsFor,
  hesDefinition,
  hesProfileLabel,
  hesWeightPermille,
  HES_COMPONENTS,
  HES_DEFAULT_PROFILE,
  HES_HRR_WINDOW_DAYS,
  HES_HRV_WINDOW_DAYS,
  HES_VO2MAX_WINDOW_DAYS,
  HES_WINDOW_DAYS
} from '../main/ets/hes/HesCurves';
import { composeHes, computeHes } from '../main/ets/hes/HesEngine';
import {
  hesMean,
  hesMedian,
  hesRound,
  hesSampleSd,
  sleepRelativeMinutes,
  sleepTimingSd
} from '../main/ets/hes/HesMath';
import { HesPersonas } from '../main/ets/hes/HesPersonas';
import { piecewiseScore } from '../main/ets/hes/HesPiecewise';
import { HesSession } from '../main/ets/hes/HesSession';
import { isSufficient, quality } from '../main/ets/hes/HesSufficiency';
import { pointsToNextTier, tierFromHes, tierLabel } from '../main/ets/hes/HesTier';
import {
  copyHesDay,
  emptyHesDay,
  HesComponentId,
  HesComponentResult,
  HesConfidence,
  HesDay,
  HesPoint,
  HesProfile,
  HesResult,
  HesStatus,
  HES_MISSING
} from '../main/ets/hes/HesTypes';
import { whyThisTier } from '../main/ets/hes/HesWhy';

const HISTORY_DAYS = 90;
const EPS = 1e-9;

function at(hour: number, minute: number): number {
  return hour * 60 + minute;
}

// A day with every Core value present and no Advanced value.
function coreDay(index: number): HesDay {
  const day = emptyHesDay('day-' + index);
  day.steps = 8000;                 // 95
  day.restingHeartRate = 60;        // 95
  day.moderateMinutes = 20;
  day.vigorousMinutes = 5;          // 30 equivalent minutes a day, 210 a week: 89
  day.sleepStartMin = at(23, 0);
  day.sleepEndMin = at(7, 0);       // the same times every night: timing SD 0, 100
  day.sleepMinutes = 450;           // 7.5 h: 100
  return day;
}

// Core plus all three Advanced values: VO2max every 7th day, HRV every night, a recovery session every 10th day.
function fullDay(index: number): HesDay {
  const day = coreDay(index);
  day.hrvPercentile = 50;           // 75
  if (index % 7 === 0) {
    day.vo2maxPercentile = 50;      // 70
  }
  if (index % 10 === 0) {
    day.hrr1 = 30;                  // 70
  }
  return day;
}

function history(days: number, make: (index: number) => HesDay): HesDay[] {
  const out: HesDay[] = [];
  for (let i = 0; i < days; i++) {
    // Index 0 is the newest day, so patterns such as "every 7th day" always include the last day.
    out.push(make(days - 1 - i));
  }
  return out;
}

function fullHistory(): HesDay[] {
  return history(HISTORY_DAYS, fullDay);
}

function coreHistory(): HesDay[] {
  return history(HISTORY_DAYS, coreDay);
}

function component(result: HesResult, id: HesComponentId): HesComponentResult {
  for (let i = 0; i < result.components.length; i++) {
    if (result.components[i].id === id) {
      return result.components[i];
    }
  }
  throw new Error('component not in the result');
}

function scoreOf(id: HesComponentId, rawValue: number): number {
  return componentScore(hesDefinition(id), rawValue);
}

function ids(list: HesComponentResult[]): string[] {
  const out: string[] = [];
  for (let i = 0; i < list.length; i++) {
    out.push(list[i].id);
  }
  return out;
}

// A hand-made component result, for tests of the composite arithmetic alone.
function made(id: HesComponentId, score: number): HesComponentResult {
  const def = hesDefinition(id);
  return {
    id: id,
    label: def.label,
    unit: def.unit,
    core: def.requiredCore,
    rawValue: 1,
    score: score,
    available: true,
    validCount: def.targetCount,
    minCount: def.minCount,
    targetCount: def.targetCount,
    quality: 1,
    baseWeight: def.weightPermille / 1000,
    effectiveWeight: 0
  };
}

function expectCurve(id: HesComponentId, xs: number[], ys: number[]): void {
  for (let i = 0; i < xs.length; i++) {
    expect(scoreOf(id, xs[i])).assertClose(ys[i], EPS);
  }
}

function isFiniteNumber(value: number): boolean {
  return Number.isFinite(value);
}

// Component scores of the full history: VO2max 70, resting heart rate 95, MVPA 89, sleep regularity 100,
// steps 95, sleep duration 100, HRV 75, recovery 70.
// Health insurance (the default profile):
//   0.125 x 70 + 0.125 x 95 + 0.20 x 89 + 0.15 x 100 + 0.15 x 95 + 0.125 x 100 + 0.075 x 75 + 0.05 x 70 = 89.3
const FULL_OBSERVED = 89.3;
// Life insurance:
//   0.225 x 70 + 0.15 x 95 + 0.15 x 89 + 0.10 x 100 + 0.175 x 95 + 0.075 x 100 + 0.075 x 75 + 0.05 x 70 = 86.6
const FULL_OBSERVED_LIFE = 86.6;

export default function hesTest() {
  // ---------------------------------------------------------------------------------------------
  // Specification section 15, "Minimum Unit Tests": one test per line of the list.
  // ---------------------------------------------------------------------------------------------
  describe('HES-Lite spec 15: boundaries', () => {
    it('Steps 1000 -> 0', 0, () => {
      expect(scoreOf(HesComponentId.STEPS, 1000)).assertEqual(0);
    });

    it('Steps 2000 -> 20', 0, () => {
      expect(scoreOf(HesComponentId.STEPS, 2000)).assertEqual(20);
    });

    it('Steps 10000 -> 100', 0, () => {
      expect(scoreOf(HesComponentId.STEPS, 10000)).assertEqual(100);
    });

    it('MVPA 150 -> 80', 0, () => {
      expect(scoreOf(HesComponentId.MVPA, 150)).assertEqual(80);
    });

    it('RHR 55 -> 100', 0, () => {
      expect(scoreOf(HesComponentId.RHR, 55)).assertEqual(100);
    });

    it('RHR 110 -> 5', 0, () => {
      expect(scoreOf(HesComponentId.RHR, 110)).assertEqual(5);
    });
  });

  describe('HES-Lite spec 15: interpolation', () => {
    it('Steps 3000 -> 35', 0, () => {
      expect(scoreOf(HesComponentId.STEPS, 3000)).assertEqual(35);
    });
  });

  describe('HES-Lite spec 15: midnight', () => {
    it('23:30 -> 330', 0, () => {
      expect(sleepRelativeMinutes(at(23, 30))).assertEqual(330);
    });

    it('00:30 -> 390', 0, () => {
      expect(sleepRelativeMinutes(at(0, 30))).assertEqual(390);
    });

    it('difference -> 60 min', 0, () => {
      expect(sleepRelativeMinutes(at(0, 30)) - sleepRelativeMinutes(at(23, 30))).assertEqual(60);
    });
  });

  describe('HES-Lite spec 15: missing advanced metric (Core valid, HRV missing)', () => {
    const withoutHrv = (): HesDay[] => history(HISTORY_DAYS, (index: number): HesDay => {
      const day = fullDay(index);
      day.hrvPercentile = HES_MISSING;
      return day;
    });

    it('HES is calculated', 0, () => {
      const result = computeHes(withoutHrv());
      expect(result.status).assertEqual(HesStatus.OK);
      expect(result.score).assertEqual(90);
      expect(result.tier).assertEqual(TIER_A);
    });

    it('Coverage is lower by exactly the HRV weight (7.5 points: 100 -> 92.5)', 0, () => {
      expect(computeHes(fullHistory()).coverage).assertEqual(100);
      expect(computeHes(withoutHrv()).coverage).assertEqual(92.5);
    });

    it('HRV is absent from the numerator and the denominator', 0, () => {
      const result = computeHes(withoutHrv());
      // (89.3 - 0.075 x 75) / 0.925 = 90.46. Counting HRV as zero would give 83.675 instead.
      expect(observedHes(result.components)).assertClose((FULL_OBSERVED - 5.625) / 0.925, EPS);
      const hrv = component(result, HesComponentId.HRV);
      expect(hrv.available).assertFalse();
      expect(hrv.score).assertEqual(HES_MISSING);
      expect(hrv.rawValue).assertEqual(HES_MISSING);
      expect(hrv.effectiveWeight).assertEqual(0);
    });

    it('HRV is shown as missing evidence, never as a weak factor', 0, () => {
      const why = whyThisTier(computeHes(withoutHrv()));
      expect(ids(why.missing)).assertDeepEquals(['hrv']);
      expect(ids(why.improvement).indexOf('hrv')).assertEqual(-1);
      expect(ids(why.strongest).indexOf('hrv')).assertEqual(-1);
    });
  });

  describe('HES-Lite spec 15: missing Core (Sleep Duration unavailable)', () => {
    const withoutSleepDuration = (): HesDay[] => history(HISTORY_DAYS, (index: number): HesDay => {
      const day = fullDay(index);
      day.sleepMinutes = HES_MISSING;
      return day;
    });

    it('HES is unavailable', 0, () => {
      const result = computeHes(withoutSleepDuration());
      expect(result.score).assertEqual(HES_MISSING);
    });

    it('Tier is unavailable', 0, () => {
      const result = computeHes(withoutSleepDuration());
      expect(result.tier).assertEqual(TIER_NO_SCORE);
    });

    it('Status = insufficient_data', 0, () => {
      const result = computeHes(withoutSleepDuration());
      expect(result.status).assertEqual(HesStatus.INSUFFICIENT_DATA);
      expect(result.status as string).assertEqual('insufficient_data');
      expect(result.confidence).assertEqual(HesConfidence.INSUFFICIENT_DATA);
      // Coverage is still reported: everything except the 12.5% of sleep duration, exactly.
      expect(result.coverage).assertEqual(87.5);
    });
  });

  describe('HES-Lite spec 15: coverage', () => {
    it('Core only -> 75% (health insurance)', 0, () => {
      expect(computeHes(coreHistory()).coverage).assertEqual(75);
    });

    it('All metrics -> 100%', 0, () => {
      expect(computeHes(fullHistory()).coverage).assertEqual(100);
    });
  });

  describe('HES-Lite spec 15: integer rounding', () => {
    it('84.49 -> 84', 0, () => {
      expect(hesRound(84.49)).assertEqual(84);
      const parts = [made(HesComponentId.RHR, 84.49), made(HesComponentId.MVPA, 84.49)];
      expect(calculateObservedHes(parts)).assertEqual(84);
    });

    it('84.50 -> 85', 0, () => {
      expect(hesRound(84.5)).assertEqual(85);
      // Two components of equal weight (12.5% each) scoring 84 and 85: the observed value is exactly 84.5.
      const parts = [made(HesComponentId.RHR, 84), made(HesComponentId.SLEEP_DURATION, 85)];
      expect(observedHes(parts)).assertEqual(84.5);
      expect(calculateObservedHes(parts)).assertEqual(85);
    });
  });

  describe('HES-Lite spec 15: no division by zero', () => {
    it('no available metrics -> Insufficient data, never NaN or Infinity', 0, () => {
      const result = computeHes([]);
      expect(result.status).assertEqual(HesStatus.INSUFFICIENT_DATA);
      expect(result.confidence).assertEqual(HesConfidence.INSUFFICIENT_DATA);
      expect(result.tier).assertEqual(TIER_NO_SCORE);
      expect(result.score).assertEqual(HES_MISSING);
      expect(result.coverage).assertEqual(0);
      expect(result.components.length).assertEqual(8);
      for (let i = 0; i < result.components.length; i++) {
        const c = result.components[i];
        expect(c.available).assertFalse();
        expect(isFiniteNumber(c.rawValue)).assertTrue();
        expect(isFiniteNumber(c.score)).assertTrue();
        expect(isFiniteNumber(c.quality)).assertTrue();
        expect(isFiniteNumber(c.effectiveWeight)).assertTrue();
        expect(c.quality).assertEqual(0);
        expect(c.effectiveWeight).assertEqual(0);
      }
      expect(observedHes(result.components)).assertEqual(HES_MISSING);
      expect(calculateObservedHes(result.components)).assertEqual(HES_MISSING);
      expect(weightedQuality(result.components)).assertEqual(0);
      expect(confidenceIndex(result.components)).assertEqual(0);
      expect(calculateObservedHes([])).assertEqual(HES_MISSING);
      expect(coverage([])).assertEqual(0);
    });
  });

  describe('HES-Lite spec 15: live heart rate (70 -> 145 bpm)', () => {
    it('the Live card changes', 0, () => {
      const session = new HesSession(fullHistory(), null);
      session.setLiveHeartRate(70);
      expect(session.liveHeartRate()).assertEqual(70);
      session.setLiveHeartRate(145);
      expect(session.liveHeartRate()).assertEqual(145);
    });

    it('HES is unchanged', 0, () => {
      const session = new HesSession(fullHistory(), null);
      session.setLiveHeartRate(70);
      const before = session.result();
      session.setLiveHeartRate(145);
      const after = session.result();
      expect(after.score).assertEqual(before.score);
      expect(after.score).assertEqual(89);
      expect(component(after, HesComponentId.RHR).rawValue).assertEqual(60);
      expect(after).assertDeepEquals(before);
    });
  });

  describe('HES-Lite spec 15: current-day steps (1200 -> 8000)', () => {
    it('the Today card changes', 0, () => {
      const session = new HesSession(fullHistory(), null);
      session.setLiveSteps(1200);
      expect(session.liveSteps()).assertEqual(1200);
      session.setLiveSteps(8000);
      expect(session.liveSteps()).assertEqual(8000);
    });

    it('HES is unchanged until the day is closed', 0, () => {
      const start = history(HISTORY_DAYS, (index: number): HesDay => {
        const day = fullDay(index);
        day.steps = 4000;
        return day;
      });
      const session = new HesSession(start, null);
      session.setLiveSteps(1200);
      const before = session.result();
      session.setLiveSteps(8000);
      expect(session.result()).assertDeepEquals(before);
      expect(component(session.result(), HesComponentId.STEPS).rawValue).assertEqual(4000);
      expect(session.history().length).assertEqual(HISTORY_DAYS);

      // Day close: the completed day enters the history and the rolling mean moves.
      const closed = session.closeDay();
      expect(session.history().length).assertEqual(HISTORY_DAYS + 1);
      expect(session.history()[HISTORY_DAYS].steps).assertEqual(8000);
      const expectedMean = (27 * 4000 + 8000) / 28;
      expect(component(closed, HesComponentId.STEPS).rawValue).assertClose(expectedMean, EPS);
      expect(component(closed, HesComponentId.STEPS).score).assertLarger(component(before,
        HesComponentId.STEPS).score);
    });
  });

  // ---------------------------------------------------------------------------------------------
  // The rest of the specification, section by section.
  // ---------------------------------------------------------------------------------------------
  describe('HES-Lite weights and Core set (spec 2 and 3)', () => {
    it('the default weights are health insurance: 12.5, 12.5, 20, 15, 15, 12.5, 7.5 and 5 percent', 0, () => {
      const expected = [125, 125, 200, 150, 150, 125, 75, 50];
      let sum = 0;
      for (let i = 0; i < HES_COMPONENTS.length; i++) {
        expect(HES_COMPONENTS[i].weightPermille).assertEqual(expected[i]);
        sum += HES_COMPONENTS[i].weightPermille;
      }
      expect(HES_COMPONENTS.length).assertEqual(8);
      expect(sum).assertEqual(1000);
    });

    it('Core is resting heart rate, MVPA, sleep regularity, steps and sleep duration: 75 percent', 0, () => {
      const core: string[] = [];
      let weight = 0;
      for (let i = 0; i < HES_COMPONENTS.length; i++) {
        if (HES_COMPONENTS[i].requiredCore) {
          core.push(HES_COMPONENTS[i].id);
          weight += HES_COMPONENTS[i].weightPermille;
        }
      }
      expect(core).assertDeepEquals(['rhr', 'mvpa', 'sleepRegularity', 'steps', 'sleepDuration']);
      expect(weight).assertEqual(750);
    });

    it('a result always lists all eight components in the order of the weight table', 0, () => {
      const order = ['crf', 'rhr', 'mvpa', 'sleepRegularity', 'steps', 'sleepDuration', 'hrv', 'hrr'];
      expect(ids(computeHes(fullHistory()).components)).assertDeepEquals(order);
      expect(ids(computeHes([]).components)).assertDeepEquals(order);
    });
  });

  describe('HES-Lite composite and coverage (spec 4)', () => {
    it('the full history scores the weighted mean of its component scores', 0, () => {
      const result = computeHes(fullHistory());
      expect(component(result, HesComponentId.CRF).score).assertClose(70, EPS);
      expect(component(result, HesComponentId.RHR).score).assertClose(95, EPS);
      expect(component(result, HesComponentId.MVPA).score).assertClose(89, EPS);
      expect(component(result, HesComponentId.SLEEP_REGULARITY).score).assertClose(100, EPS);
      expect(component(result, HesComponentId.STEPS).score).assertClose(95, EPS);
      expect(component(result, HesComponentId.SLEEP_DURATION).score).assertClose(100, EPS);
      expect(component(result, HesComponentId.HRV).score).assertClose(75, EPS);
      expect(component(result, HesComponentId.HRR).score).assertClose(70, EPS);
      expect(observedHes(result.components)).assertClose(FULL_OBSERVED, EPS);
      expect(result.score).assertEqual(89);
      expect(result.tier).assertEqual(TIER_A);
      expect(result.status as string).assertEqual('ok');
    });

    it('Core + VO2max -> 87.5%, Core + VO2max + HRR -> 92.5%', 0, () => {
      const coreAndVo2 = history(HISTORY_DAYS, (index: number): HesDay => {
        const day = fullDay(index);
        day.hrvPercentile = HES_MISSING;
        day.hrr1 = HES_MISSING;
        return day;
      });
      const coreVo2Hrr = history(HISTORY_DAYS, (index: number): HesDay => {
        const day = fullDay(index);
        day.hrvPercentile = HES_MISSING;
        return day;
      });
      expect(computeHes(coreAndVo2).coverage).assertEqual(87.5);
      expect(computeHes(coreVo2Hrr).coverage).assertEqual(92.5);
    });

    it('a coverage of 42.5 stays 42.5, the same on every run', 0, () => {
      // 12.5 + 15 + 15 = 42.5
      const parts = [made(HesComponentId.RHR, 80), made(HesComponentId.SLEEP_REGULARITY, 80),
        made(HesComponentId.STEPS, 80)];
      expect(coverage(parts)).assertEqual(42.5);
      expect(isCoreComplete(parts)).assertFalse();
    });

    it('a Core-only history is scored over the 75 percent that is there', 0, () => {
      const result = computeHes(coreHistory());
      // (0.125 x 95 + 0.20 x 89 + 0.15 x 100 + 0.15 x 95 + 0.125 x 100) / 0.75 = 95.23
      expect(observedHes(result.components)).assertClose(71.425 / 0.75, EPS);
      expect(result.score).assertEqual(95);
    });

    it('effective weights add up to 1 over the available components and are 0 for missing ones', 0, () => {
      const result = computeHes(coreHistory());
      let sum = 0;
      for (let i = 0; i < result.components.length; i++) {
        sum += result.components[i].effectiveWeight;
      }
      expect(sum).assertClose(1, EPS);
      expect(component(result, HesComponentId.RHR).effectiveWeight).assertClose(0.125 / 0.75, EPS);
      expect(component(result, HesComponentId.STEPS).effectiveWeight).assertClose(0.15 / 0.75, EPS);
      expect(component(result, HesComponentId.CRF).effectiveWeight).assertEqual(0);
      expect(component(result, HesComponentId.RHR).baseWeight).assertEqual(0.125);
    });

    it('scoring does not change the history it is given', 0, () => {
      const days = fullHistory();
      const copy: HesDay[] = [];
      for (let i = 0; i < days.length; i++) {
        copy.push(copyHesDay(days[i]));
      }
      computeHes(days);
      expect(days).assertDeepEquals(copy);
    });
  });

  describe('HES-Lite piecewise scoring (spec 5)', () => {
    const curve: HesPoint[] = [{ x: 10, y: 20 }, { x: 20, y: 60 }, { x: 40, y: 100 }];

    it('below the first point gives the first score, above the last point the last score', 0, () => {
      expect(piecewiseScore(-5, curve)).assertEqual(20);
      expect(piecewiseScore(10, curve)).assertEqual(20);
      expect(piecewiseScore(40, curve)).assertEqual(100);
      expect(piecewiseScore(4000, curve)).assertEqual(100);
    });

    it('between two points the score is on the straight line, boundaries included', 0, () => {
      expect(piecewiseScore(15, curve)).assertEqual(40);
      expect(piecewiseScore(20, curve)).assertEqual(60);
      expect(piecewiseScore(30, curve)).assertEqual(80);
    });

    it('the result is clamped to 0..100', 0, () => {
      const wild: HesPoint[] = [{ x: 0, y: -40 }, { x: 10, y: 160 }];
      expect(piecewiseScore(0, wild)).assertEqual(0);
      expect(piecewiseScore(1, wild)).assertEqual(0);
      expect(piecewiseScore(9, wild)).assertEqual(100);
      expect(piecewiseScore(10, wild)).assertEqual(100);
    });
  });

  describe('HES-Lite component curves (spec 6)', () => {
    it('6.1 VO2max percentile', 0, () => {
      expectCurve(HesComponentId.CRF, [0, 5, 10, 25, 50, 75, 90, 95, 100], [10, 10, 20, 45, 70, 88, 97, 100, 100]);
      expect(scoreOf(HesComponentId.CRF, 60)).assertClose(77.2, EPS);
    });

    it('6.2 resting heart rate', 0, () => {
      expectCurve(HesComponentId.RHR, [35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 90, 100, 110, 130],
        [90, 90, 98, 100, 100, 95, 90, 84, 76, 66, 45, 20, 5, 5]);
      expect(scoreOf(HesComponentId.RHR, 52)).assertEqual(100);
      expect(scoreOf(HesComponentId.RHR, 72)).assertClose(80.8, EPS);
    });

    it('6.3 MVPA minutes per week', 0, () => {
      expectCurve(HesComponentId.MVPA, [0, 30, 60, 100, 150, 250, 300, 500], [0, 20, 40, 60, 80, 95, 100, 100]);
      expect(scoreOf(HesComponentId.MVPA, 200)).assertClose(87.5, EPS);
    });

    it('6.4 sleep timing SD', 0, () => {
      expectCurve(HesComponentId.SLEEP_REGULARITY, [0, 30, 45, 60, 90, 120, 180, 240, 400],
        [100, 100, 90, 80, 60, 40, 15, 0, 0]);
      expect(scoreOf(HesComponentId.SLEEP_REGULARITY, 150)).assertClose(27.5, EPS);
    });

    it('6.5 steps per day', 0, () => {
      expectCurve(HesComponentId.STEPS, [0, 1000, 2000, 4000, 5000, 6000, 7000, 8000, 10000, 25000],
        [0, 0, 20, 50, 65, 80, 90, 95, 100, 100]);
      expect(scoreOf(HesComponentId.STEPS, 9000)).assertClose(97.5, EPS);
    });

    it('6.6 sleep duration, lower for short and for very long nights', 0, () => {
      expectCurve(HesComponentId.SLEEP_DURATION, [3, 4.5, 5, 5.5, 6, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10, 11, 12, 14],
        [0, 0, 25, 45, 65, 82, 95, 100, 100, 100, 100, 95, 90, 80, 65, 65]);
      expect(scoreOf(HesComponentId.SLEEP_DURATION, 6.25)).assertClose(73.5, EPS);
    });

    it('6.7 HRV percentile', 0, () => {
      expectCurve(HesComponentId.HRV, [0, 5, 10, 25, 50, 75, 90, 95, 100], [10, 10, 25, 50, 75, 90, 97, 100, 100]);
      expect(scoreOf(HesComponentId.HRV, 60)).assertClose(81, EPS);
    });

    it('6.8 heart-rate recovery', 0, () => {
      expectCurve(HesComponentId.HRR, [0, 12, 18, 24, 30, 36, 42, 50, 70], [10, 10, 30, 55, 70, 82, 92, 100, 100]);
      expect(scoreOf(HesComponentId.HRR, 27)).assertClose(62.5, EPS);
    });
  });

  describe('HES-Lite raw values (spec 6)', () => {
    it('resting heart rate is the median of the valid days, so one odd day does not move it', 0, () => {
      const days = history(HISTORY_DAYS, (index: number): HesDay => {
        const day = coreDay(index);
        day.restingHeartRate = index === 4 ? 110 : (index % 2 === 0 ? 58 : 62);
        return day;
      });
      expect(component(computeHes(days), HesComponentId.RHR).rawValue).assertEqual(62);
      expect(hesMedian([62, 58, 110])).assertEqual(62);
      expect(hesMedian([58, 62])).assertEqual(60);
    });

    it('MVPA counts vigorous minutes twice and is the 28-day sum divided by 4', 0, () => {
      expect(equivalentMvpa(20, 5)).assertEqual(30);
      const days = history(HISTORY_DAYS, (index: number): HesDay => {
        const day = coreDay(index);
        day.moderateMinutes = index % 2 === 0 ? 30 : 0;
        day.vigorousMinutes = index % 7 === 0 ? 15 : 0;
        return day;
      });
      // 14 days x 30 moderate + 4 days x 15 vigorous x 2 = 540 in 28 days, 135 a week.
      expect(component(computeHes(days), HesComponentId.MVPA).rawValue).assertClose(135, EPS);
    });

    it('steps are the mean of the valid days', 0, () => {
      const days = history(HISTORY_DAYS, (index: number): HesDay => {
        const day = coreDay(index);
        day.steps = index % 2 === 0 ? 5000 : 7000;
        return day;
      });
      expect(component(computeHes(days), HesComponentId.STEPS).rawValue).assertClose(6000, EPS);
      expect(hesMean([5000, 7000])).assertEqual(6000);
    });

    it('sleep duration is the median night, in hours', 0, () => {
      const days = history(HISTORY_DAYS, (index: number): HesDay => {
        const day = coreDay(index);
        day.sleepMinutes = index === 5 ? 120 : 390;
        return day;
      });
      const sleep = component(computeHes(days), HesComponentId.SLEEP_DURATION);
      expect(sleep.rawValue).assertEqual(6.5);
      expect(sleep.score).assertEqual(82);
    });

    it('sleep timing SD joins the bedtime SD and the wake-time SD, across midnight', 0, () => {
      expect(sleepTimingSd(30, 40)).assertClose(Math.sqrt(1250), EPS);
      expect(hesSampleSd([2, 4, 4, 4, 5, 5, 7, 9])).assertClose(Math.sqrt(32 / 7), EPS);
      // Bedtime alternates between 23:00 and 01:00, the wake time never changes.
      const days = history(HISTORY_DAYS, (index: number): HesDay => {
        const day = coreDay(index);
        day.sleepStartMin = index % 2 === 0 ? at(23, 0) : at(1, 0);
        return day;
      });
      const expected = Math.sqrt((60 * 60 * 28 / 27) / 2);
      const regularity = component(computeHes(days), HesComponentId.SLEEP_REGULARITY);
      expect(regularity.rawValue).assertClose(expected, 1e-6);
      expect(regularity.rawValue).assertLess(45);
    });

    it('VO2max is the latest valid estimate', 0, () => {
      const days = history(HISTORY_DAYS, (index: number): HesDay => {
        const day = coreDay(index);
        if (index === 40) {
          day.vo2maxPercentile = 90;
        }
        if (index === 12) {
          day.vo2maxPercentile = 25;
        }
        return day;
      });
      const crf = component(computeHes(days), HesComponentId.CRF);
      expect(crf.validCount).assertEqual(2);
      expect(crf.rawValue).assertEqual(25);
      expect(crf.score).assertEqual(45);
    });

    it('a missing reading is never counted as zero', 0, () => {
      const days = history(HISTORY_DAYS, (index: number): HesDay => {
        // Every fourth day the watch stayed at home: no reading at all.
        return index % 4 === 0 ? emptyHesDay('day-' + index) : coreDay(index);
      });
      const result = computeHes(days);
      expect(component(result, HesComponentId.STEPS).validCount).assertEqual(21);
      expect(component(result, HesComponentId.STEPS).rawValue).assertClose(8000, EPS);
      expect(component(result, HesComponentId.MVPA).rawValue).assertClose(210, EPS);
      expect(component(result, HesComponentId.RHR).rawValue).assertEqual(60);
      expect(result.score).assertEqual(computeHes(coreHistory()).score);
    });

    it('a resting heart rate of 0 bpm is no reading', 0, () => {
      const days = history(HISTORY_DAYS, (index: number): HesDay => {
        const day = coreDay(index);
        if (index % 2 === 0) {
          day.restingHeartRate = 0;
        }
        return day;
      });
      const rhr = component(computeHes(days), HesComponentId.RHR);
      expect(rhr.validCount).assertEqual(14);
      expect(rhr.rawValue).assertEqual(60);
    });
  });

  describe('HES-Lite data sufficiency (spec 7)', () => {
    const lastDays = (count: number, make: (index: number) => HesDay): HesDay[] =>
      history(HISTORY_DAYS, (index: number): HesDay => index < count ? make(index) : emptyHesDay('day-' + index));

    it('available = validCount >= minimum', 0, () => {
      expect(isSufficient(13, 14)).assertFalse();
      expect(isSufficient(14, 14)).assertTrue();
      expect(isSufficient(0, 1)).assertFalse();
    });

    it('minimum and target counts are the ones of the table', 0, () => {
      const mins = [1, 10, 14, 14, 14, 14, 7, 2];
      const targets = [2, 14, 21, 21, 21, 21, 14, 3];
      for (let i = 0; i < HES_COMPONENTS.length; i++) {
        expect(HES_COMPONENTS[i].minCount).assertEqual(mins[i]);
        expect(HES_COMPONENTS[i].targetCount).assertEqual(targets[i]);
      }
    });

    it('steps, MVPA and both sleep components need 14 valid days: 13 give no score', 0, () => {
      const thirteen = computeHes(lastDays(13, coreDay));
      expect(component(thirteen, HesComponentId.STEPS).available).assertFalse();
      expect(component(thirteen, HesComponentId.MVPA).available).assertFalse();
      expect(component(thirteen, HesComponentId.SLEEP_DURATION).available).assertFalse();
      expect(component(thirteen, HesComponentId.SLEEP_REGULARITY).available).assertFalse();
      expect(component(thirteen, HesComponentId.RHR).available).assertTrue();
      expect(thirteen.status).assertEqual(HesStatus.INSUFFICIENT_DATA);
      expect(thirteen.coverage).assertEqual(12.5);

      const fourteen = computeHes(lastDays(14, coreDay));
      expect(fourteen.status).assertEqual(HesStatus.OK);
      expect(fourteen.coverage).assertEqual(75);
    });

    it('resting heart rate needs 10 valid days', 0, () => {
      expect(component(computeHes(lastDays(9, coreDay)), HesComponentId.RHR).available).assertFalse();
      expect(component(computeHes(lastDays(10, coreDay)), HesComponentId.RHR).available).assertTrue();
    });

    it('HRV needs 7 valid nights', 0, () => {
      const hrvNights = (nights: number): HesDay[] => history(HISTORY_DAYS, (index: number): HesDay => {
        const day = coreDay(index);
        if (index < nights) {
          day.hrvPercentile = 50;
        }
        return day;
      });
      expect(component(computeHes(hrvNights(6)), HesComponentId.HRV).available).assertFalse();
      expect(computeHes(hrvNights(6)).coverage).assertEqual(75);
      expect(component(computeHes(hrvNights(7)), HesComponentId.HRV).available).assertTrue();
      expect(computeHes(hrvNights(7)).coverage).assertEqual(82.5);
    });

    it('HRV counts only the recent 14 nights', 0, () => {
      const hrvOn = (indexes: number[]): HesDay[] => history(HISTORY_DAYS, (index: number): HesDay => {
        const day = coreDay(index);
        if (indexes.indexOf(index) >= 0) {
          day.hrvPercentile = 50;
        }
        return day;
      });
      // Seven nights, the oldest of them the 14th night back (index 13): available.
      expect(component(computeHes(hrvOn([0, 1, 2, 3, 4, 5, 13])), HesComponentId.HRV).validCount).assertEqual(7);
      expect(component(computeHes(hrvOn([0, 1, 2, 3, 4, 5, 13])), HesComponentId.HRV).available).assertTrue();
      // The same seven nights with the oldest one a night earlier (index 14): only six count.
      expect(component(computeHes(hrvOn([0, 1, 2, 3, 4, 5, 14])), HesComponentId.HRV).validCount).assertEqual(6);
      expect(component(computeHes(hrvOn([0, 1, 2, 3, 4, 5, 14])), HesComponentId.HRV).available).assertFalse();
      expect(HES_HRV_WINDOW_DAYS).assertEqual(14);
    });

    it('heart-rate recovery needs 2 valid sessions in 60 days', 0, () => {
      const sessionsOn = (indexes: number[]): HesDay[] => history(HISTORY_DAYS, (index: number): HesDay => {
        const day = coreDay(index);
        if (indexes.indexOf(index) >= 0) {
          day.hrr1 = 30;
        }
        return day;
      });
      expect(component(computeHes(sessionsOn([5])), HesComponentId.HRR).available).assertFalse();
      expect(component(computeHes(sessionsOn([5, 59])), HesComponentId.HRR).available).assertTrue();
      // Index 60 is the 61st day back: outside the window.
      expect(component(computeHes(sessionsOn([5, 60])), HesComponentId.HRR).available).assertFalse();
      expect(HES_HRR_WINDOW_DAYS).assertEqual(60);
    });

    it('VO2max needs 1 valid estimate in 90 days', 0, () => {
      const estimateOn = (target: number, length: number): HesDay[] => history(length, (index: number): HesDay => {
        const day = coreDay(index);
        if (index === target) {
          day.vo2maxPercentile = 50;
        }
        return day;
      });
      expect(component(computeHes(coreHistory()), HesComponentId.CRF).available).assertFalse();
      expect(component(computeHes(estimateOn(89, 120)), HesComponentId.CRF).available).assertTrue();
      expect(component(computeHes(estimateOn(90, 120)), HesComponentId.CRF).available).assertFalse();
      expect(HES_VO2MAX_WINDOW_DAYS).assertEqual(90);
    });

    it('only the last 28 completed days count for the daily components', 0, () => {
      const days = history(HISTORY_DAYS, (index: number): HesDay => {
        const day = coreDay(index);
        day.steps = index < HES_WINDOW_DAYS ? 6000 : 20000;
        return day;
      });
      const steps = component(computeHes(days), HesComponentId.STEPS);
      expect(steps.validCount).assertEqual(28);
      expect(steps.rawValue).assertClose(6000, EPS);
      expect(HES_WINDOW_DAYS).assertEqual(28);
    });

    it('a component carries its valid, minimum and target counts', 0, () => {
      const steps = evaluateComponent(hesDefinition(HesComponentId.STEPS), lastDays(9, coreDay));
      expect(steps.validCount).assertEqual(9);
      expect(steps.minCount).assertEqual(14);
      expect(steps.targetCount).assertEqual(21);
      expect(steps.available).assertFalse();
      expect(steps.rawValue).assertEqual(HES_MISSING);
      expect(steps.label).assertEqual('Daily steps');
      expect(steps.unit).assertEqual('steps/day');
      expect(evaluateComponents([]).length).assertEqual(8);
    });
  });

  describe('HES-Lite data confidence (spec 8)', () => {
    it('quality = min(validCount / targetCount, 1)', 0, () => {
      expect(quality(21, 21)).assertEqual(1);
      expect(quality(28, 21)).assertEqual(1);
      expect(quality(14, 21)).assertClose(2 / 3, EPS);
      expect(quality(0, 21)).assertEqual(0);
      expect(quality(5, 0)).assertEqual(0);
    });

    it('High from 0.80, Medium from 0.60, Low below', 0, () => {
      expect(confidenceFromIndex(1)).assertEqual(HesConfidence.HIGH);
      expect(confidenceFromIndex(0.8)).assertEqual(HesConfidence.HIGH);
      expect(confidenceFromIndex(0.7999)).assertEqual(HesConfidence.MEDIUM);
      expect(confidenceFromIndex(0.6)).assertEqual(HesConfidence.MEDIUM);
      expect(confidenceFromIndex(0.5999)).assertEqual(HesConfidence.LOW);
      expect(confidenceFromIndex(0)).assertEqual(HesConfidence.LOW);
      expect(HesConfidence.HIGH as string).assertEqual('High');
      expect(HesConfidence.MEDIUM as string).assertEqual('Medium');
      expect(HesConfidence.LOW as string).assertEqual('Low');
      expect(HesConfidence.INSUFFICIENT_DATA as string).assertEqual('Insufficient data');
    });

    it('full data is High; Core only with full quality is Medium (0.75)', 0, () => {
      const full = computeHes(fullHistory());
      expect(confidenceIndex(full.components)).assertClose(1, EPS);
      expect(full.confidence).assertEqual(HesConfidence.HIGH);
      const core = computeHes(coreHistory());
      expect(confidenceIndex(core.components)).assertClose(0.75, EPS);
      expect(core.confidence).assertEqual(HesConfidence.MEDIUM);
    });

    it('Core only at the bare minimum of 14 days is Low', 0, () => {
      const days = history(HISTORY_DAYS, (index: number): HesDay =>
        index < 14 ? coreDay(index) : emptyHesDay('day-' + index));
      const result = computeHes(days);
      // Quality 14/21 for four components and 14/14 for resting heart rate: (0.125 + 0.625 x 2/3) / 0.75.
      const expected = 0.75 * ((0.125 + 0.625 * 2 / 3) / 0.75);
      expect(confidenceIndex(result.components)).assertClose(expected, EPS);
      expect(result.status).assertEqual(HesStatus.OK);
      expect(result.confidence).assertEqual(HesConfidence.LOW);
    });

    it('with an incomplete Core set the confidence is "Insufficient data"', 0, () => {
      const parts = [made(HesComponentId.RHR, 90), made(HesComponentId.CRF, 90)];
      expect(calculateConfidence(parts)).assertEqual(HesConfidence.INSUFFICIENT_DATA);
      expect(composeHes(parts).confidence).assertEqual(HesConfidence.INSUFFICIENT_DATA);
    });
  });

  describe('HES vNext profiles: health and life insurance', () => {
    it('each profile has its own weights and both add up to 100 percent', 0, () => {
      const health = [125, 125, 200, 150, 150, 125, 75, 50];
      const life = [225, 150, 150, 100, 175, 75, 75, 50];
      const healthDefs = hesComponentsFor(HesProfile.HEALTH_WELLNESS);
      const lifeDefs = hesComponentsFor(HesProfile.LONGEVITY_WELLNESS);
      let healthSum = 0;
      let lifeSum = 0;
      for (let i = 0; i < HES_COMPONENTS.length; i++) {
        expect(healthDefs[i].weightPermille).assertEqual(health[i]);
        expect(lifeDefs[i].weightPermille).assertEqual(life[i]);
        expect(hesWeightPermille(HesProfile.LONGEVITY_WELLNESS, HES_COMPONENTS[i].id)).assertEqual(life[i]);
        healthSum += healthDefs[i].weightPermille;
        lifeSum += lifeDefs[i].weightPermille;
      }
      expect(healthSum).assertEqual(1000);
      expect(lifeSum).assertEqual(1000);
    });

    it('the default profile is health insurance and HES_COMPONENTS carries its weights', 0, () => {
      expect(HES_DEFAULT_PROFILE).assertEqual(HesProfile.HEALTH_WELLNESS);
      for (let i = 0; i < HES_COMPONENTS.length; i++) {
        expect(HES_COMPONENTS[i].weightPermille).assertEqual(
          hesWeightPermille(HES_DEFAULT_PROFILE, HES_COMPONENTS[i].id));
      }
      expect(computeHes(fullHistory()).profile).assertEqual(HesProfile.HEALTH_WELLNESS);
    });

    it('a profile changes only the weights: curves, counts and windows are shared', 0, () => {
      const health = hesComponentsFor(HesProfile.HEALTH_WELLNESS);
      const life = hesComponentsFor(HesProfile.LONGEVITY_WELLNESS);
      for (let i = 0; i < health.length; i++) {
        expect(life[i].id).assertEqual(health[i].id);
        expect(life[i].requiredCore).assertEqual(health[i].requiredCore);
        expect(life[i].minCount).assertEqual(health[i].minCount);
        expect(life[i].targetCount).assertEqual(health[i].targetCount);
        expect(life[i].windowDays).assertEqual(health[i].windowDays);
        expect(life[i].curve).assertDeepEquals(health[i].curve);
      }
      const healthResult = computeHes(fullHistory(), HesProfile.HEALTH_WELLNESS);
      const lifeResult = computeHes(fullHistory(), HesProfile.LONGEVITY_WELLNESS);
      for (let i = 0; i < healthResult.components.length; i++) {
        expect(lifeResult.components[i].score).assertEqual(healthResult.components[i].score);
      }
    });

    it('Ania without HRV: coverage 100 -> 92.5 in both profiles, the score is still calculated', 0, () => {
      const days = HesPersonas.history('ania');
      for (let i = 0; i < days.length; i++) {
        days[i].hrvPercentile = HES_MISSING;
      }
      expect(HesPersonas.result('ania', HesProfile.HEALTH_WELLNESS).coverage).assertEqual(100);
      expect(HesPersonas.result('ania', HesProfile.LONGEVITY_WELLNESS).coverage).assertEqual(100);

      const health = computeHes(days, HesProfile.HEALTH_WELLNESS);
      expect(health.coverage).assertEqual(92.5);
      expect(health.status).assertEqual(HesStatus.OK);
      expect(health.score).assertEqual(93);
      expect(health.tier).assertEqual(TIER_A);
      expect(health.confidence).assertEqual(HesConfidence.HIGH);
      expect(observedHes(health.components)).assertClose(93.2946, 1e-3);
      expect(component(health, HesComponentId.MVPA).effectiveWeight).assertClose(200 / 925, 1e-9);
      expect(component(health, HesComponentId.HRV).available).assertFalse();

      const life = computeHes(days, HesProfile.LONGEVITY_WELLNESS);
      expect(life.coverage).assertEqual(92.5);
      expect(life.status).assertEqual(HesStatus.OK);
      expect(life.score).assertEqual(92);
      expect(life.tier).assertEqual(TIER_A);
      expect(life.confidence).assertEqual(HesConfidence.HIGH);
      expect(observedHes(life.components)).assertClose(92.0082, 1e-3);
      expect(component(life, HesComponentId.MVPA).effectiveWeight).assertClose(150 / 925, 1e-9);
      expect(component(life, HesComponentId.HRV).available).assertFalse();
    });

    it('life insurance scores the full history as 86.6 -> 87', 0, () => {
      const result = computeHes(fullHistory(), HesProfile.LONGEVITY_WELLNESS);
      expect(result.profile).assertEqual(HesProfile.LONGEVITY_WELLNESS);
      expect(observedHes(result.components)).assertClose(FULL_OBSERVED_LIFE, EPS);
      expect(result.score).assertEqual(87);
      expect(result.tier).assertEqual(TIER_A);
      expect(component(result, HesComponentId.CRF).baseWeight).assertEqual(0.225);
    });

    it('life insurance: Core only is 65% coverage and at most Medium confidence', 0, () => {
      const result = computeHes(coreHistory(), HesProfile.LONGEVITY_WELLNESS);
      expect(result.coverage).assertEqual(65);
      expect(confidenceIndex(result.components)).assertClose(0.65, EPS);
      expect(result.confidence).assertEqual(HesConfidence.MEDIUM);
      // (0.15 x 95 + 0.15 x 89 + 0.10 x 100 + 0.175 x 95 + 0.075 x 100) / 0.65
      expect(observedHes(result.components)).assertClose(61.725 / 0.65, EPS);
    });

    it('a missing Core component gives no score in either profile', 0, () => {
      const days = history(HISTORY_DAYS, (index: number): HesDay => {
        const day = fullDay(index);
        day.sleepMinutes = HES_MISSING;
        return day;
      });
      const life = computeHes(days, HesProfile.LONGEVITY_WELLNESS);
      expect(life.score).assertEqual(HES_MISSING);
      expect(life.tier).assertEqual(TIER_NO_SCORE);
      expect(life.status).assertEqual(HesStatus.INSUFFICIENT_DATA);
      // Everything except the 7.5% of sleep duration in the life profile.
      expect(life.coverage).assertEqual(92.5);
    });

    it('a session switches profile on the same completed days and keeps the live values', 0, () => {
      const session = new HesSession(fullHistory(), null);
      session.setLive(120, 5000);
      expect(session.profile()).assertEqual(HesProfile.HEALTH_WELLNESS);
      expect(session.result().score).assertEqual(89);
      const life = session.setProfile(HesProfile.LONGEVITY_WELLNESS);
      expect(life.score).assertEqual(87);
      expect(session.result()).assertDeepEquals(computeHes(fullHistory(), HesProfile.LONGEVITY_WELLNESS));
      expect(session.liveHeartRate()).assertEqual(120);
      expect(session.liveSteps()).assertEqual(5000);
      expect(session.history().length).assertEqual(HISTORY_DAYS);
      session.closeDay();
      expect(session.result().profile).assertEqual(HesProfile.LONGEVITY_WELLNESS);
      session.reset();
      expect(session.profile()).assertEqual(HesProfile.LONGEVITY_WELLNESS);
      expect(session.result().score).assertEqual(87);
    });

    it('labels', 0, () => {
      expect(hesProfileLabel(HesProfile.HEALTH_WELLNESS)).assertEqual('Health insurance');
      expect(hesProfileLabel(HesProfile.LONGEVITY_WELLNESS)).assertEqual('Life insurance');
    });
  });

  describe('HES-Lite tiering (spec 9)', () => {
    it('A from 80, B from 60 to 79, C below 60', 0, () => {
      expect(tierFromHes(100)).assertEqual(TIER_A);
      expect(tierFromHes(80)).assertEqual(TIER_A);
      expect(tierFromHes(79)).assertEqual(TIER_B);
      expect(tierFromHes(60)).assertEqual(TIER_B);
      expect(tierFromHes(59)).assertEqual(TIER_C);
      expect(tierFromHes(0)).assertEqual(TIER_C);
    });

    it('no score gives no tier, with the claim value NONE', 0, () => {
      expect(tierFromHes(HES_MISSING)).assertEqual(TIER_NO_SCORE);
      expect(TIER_NO_SCORE).assertEqual('NONE');
      expect(TIER_A).assertEqual('A');
      expect(TIER_B).assertEqual('B');
      expect(TIER_C).assertEqual('C');
    });

    it('a tier is assigned only with all five Core components', 0, () => {
      const parts = [
        made(HesComponentId.CRF, 100),
        made(HesComponentId.RHR, 100),
        made(HesComponentId.MVPA, 100),
        made(HesComponentId.SLEEP_REGULARITY, 100),
        made(HesComponentId.STEPS, 100),
        made(HesComponentId.HRV, 100),
        made(HesComponentId.HRR, 100)
      ];
      const result = composeHes(parts);
      expect(result.tier).assertEqual(TIER_NO_SCORE);
      expect(result.score).assertEqual(HES_MISSING);
      expect(result.coverage).assertEqual(87.5);
    });

    it('labels and the distance to the next tier', 0, () => {
      expect(tierLabel(TIER_A)).assertEqual('Strong overall profile');
      expect(tierLabel(TIER_B)).assertEqual('Moderate overall profile');
      expect(tierLabel(TIER_C)).assertEqual('Improvement opportunity');
      expect(tierLabel(TIER_NO_SCORE)).assertEqual('Insufficient data');
      expect(pointsToNextTier(79)).assertEqual(1);
      expect(pointsToNextTier(59)).assertEqual(1);
      expect(pointsToNextTier(92)).assertEqual(0);
      expect(pointsToNextTier(HES_MISSING)).assertEqual(0);
    });
  });

  describe('HES-Lite "Why this tier" (spec 11)', () => {
    it('strongest are the highest scores, improvement the lowest, with no component in both', 0, () => {
      const why = whyThisTier(computeHes(fullHistory()));
      // Scores: sleep regularity 100, sleep duration 100, resting HR 95, steps 95, MVPA 89, HRV 75,
      // VO2max 70, recovery 70. Equal scores keep the order of the weight table.
      expect(ids(why.strongest)).assertDeepEquals(['sleepRegularity', 'sleepDuration', 'rhr']);
      expect(ids(why.improvement)).assertDeepEquals(['crf', 'hrr', 'hrv']);
      expect(why.missing.length).assertEqual(0);
    });

    it('with five available components the lists are 3 and 2', 0, () => {
      const why = whyThisTier(computeHes(coreHistory()));
      expect(ids(why.strongest)).assertDeepEquals(['sleepRegularity', 'sleepDuration', 'rhr']);
      expect(ids(why.improvement)).assertDeepEquals(['mvpa', 'steps']);
      expect(ids(why.missing)).assertDeepEquals(['crf', 'hrv', 'hrr']);
    });

    it('without a score nothing is ranked and the missing list says what is needed', 0, () => {
      const days = history(HISTORY_DAYS, (index: number): HesDay => {
        const day = coreDay(index);
        if (index >= 9) {
          day.sleepStartMin = HES_MISSING;
          day.sleepEndMin = HES_MISSING;
          day.sleepMinutes = HES_MISSING;
        }
        return day;
      });
      const why = whyThisTier(computeHes(days));
      expect(why.strongest.length).assertEqual(0);
      expect(why.improvement.length).assertEqual(0);
      expect(ids(why.missing)).assertDeepEquals(['crf', 'sleepRegularity', 'sleepDuration', 'hrv', 'hrr']);
      expect(why.missing[1].validCount).assertEqual(9);
      expect(why.missing[1].minCount).assertEqual(14);
      expect(why.missing[1].core).assertTrue();
      expect(why.missing[0].core).assertFalse();
    });
  });
}
