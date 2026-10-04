import { describe, it, expect } from '@ohos/hypium';
import {
  aggregate,
  hesMedian,
  hesPopulationSd,
  sleepRelativeMinutes,
  sleepTimingSd
} from '../main/ets/hes/HesAggregate';
import { piecewise } from '../main/ets/hes/HesCurves';
import { computeHes, confidenceFromIndex, hesRound, tierFromHes } from '../main/ets/hes/HesEngine';
import {
  hesCountText,
  hesCoverageText,
  hesOneDecimal,
  hesRawText,
  hesWeightText
} from '../main/ets/hes/HesFormat';
import {
  HES_COMPONENTS,
  HES_MODEL_VERSION,
  HES_PROFILES,
  hesComponentDefinition,
  hesWeightPermille,
  HesPoint
} from '../main/ets/hes/HesModel';
import { HesPrng } from '../main/ets/hes/HesPrng';
import {
  ComponentId,
  ComponentResult,
  HesConfidence,
  HesDayRecord,
  HesHistory,
  HesProfile,
  HesResult,
  HesStatus,
  HesTier
} from '../main/ets/hes/HesTypes';
import { dateOfDayNumber, dayNumberOfDate } from '../main/ets/watchlink/WatchLinkTypes';

const EPS = 1e-9;
const LAST_DAY = '2026-10-03';

function curveOf(id: ComponentId): HesPoint[] {
  return hesComponentDefinition(id).curve;
}

function score(id: ComponentId, x: number): number {
  const s = piecewise(curveOf(id), x);
  if (s === undefined) {
    throw new Error('no score');
  }
  return s;
}

function byId(result: HesResult, id: ComponentId): ComponentResult {
  for (let i = 0; i < result.components.length; i++) {
    if (result.components[i].id === id) {
      return result.components[i];
    }
  }
  throw new Error('component not in the result');
}

function dateAgo(daysAgo: number): string {
  return dateOfDayNumber(dayNumberOfDate(LAST_DAY) - daysAgo);
}

// A completed day with every Core value: steps 8000 (95), MVPA 30 a day = 210 a week (89),
// resting HR 60 (95), the same night every day (timing SD 0: 100), 7.5 h of sleep (100).
function coreDay(daysAgo: number): HesDayRecord {
  return {
    date: dateAgo(daysAgo),
    steps: 8000,
    moderateMin: 20,
    vigorousMin: 5,
    restingHr: 60,
    sleep: { bedMin: 1380, wakeMin: 420, totalSleepMin: 450 }
  };
}

// `count` completed days ending on LAST_DAY, oldest first.
function coreHistory(count: number): HesHistory {
  const days: HesDayRecord[] = [];
  for (let i = count - 1; i >= 0; i--) {
    days.push(coreDay(i));
  }
  return { days: days, crf: [], hrr: [] };
}

export default function hesTest() {
  describe('HES piecewise curves', () => {
    it('every point of every curve gives its exact score', 0, () => {
      for (let i = 0; i < HES_COMPONENTS.length; i++) {
        const curve = HES_COMPONENTS[i].curve;
        for (let j = 0; j < curve.length; j++) {
          expect(piecewise(curve, curve[j].x)).assertEqual(curve[j].y);
        }
      }
    });

    it('below the first point and above the last point the end scores stand', 0, () => {
      for (let i = 0; i < HES_COMPONENTS.length; i++) {
        const curve = HES_COMPONENTS[i].curve;
        expect(piecewise(curve, curve[0].x - 1000)).assertEqual(curve[0].y);
        expect(piecewise(curve, curve[curve.length - 1].x + 1000)).assertEqual(curve[curve.length - 1].y);
      }
    });

    it('between two points the score is on the straight line, on every curve', 0, () => {
      expect(score(ComponentId.CRF, 77)).assertClose(89.2, EPS);
      expect(score(ComponentId.RHR, 58)).assertClose(97, EPS);
      expect(score(ComponentId.RHR, 68)).assertClose(86.4, EPS);
      expect(score(ComponentId.MVPA, 238)).assertClose(93.2, EPS);
      expect(score(ComponentId.STEPS, 8800)).assertClose(97, EPS);
      expect(score(ComponentId.SLEEP_REGULARITY, 70)).assertClose(80 - 20 / 3, EPS);
      expect(score(ComponentId.SLEEP_DURATION, 7.4)).assertClose(99, EPS);
      expect(score(ComponentId.SLEEP_DURATION, 6.6)).assertClose(84.6, EPS);
      expect(score(ComponentId.HRV, 60)).assertClose(81, EPS);
      expect(score(ComponentId.HRR, 27)).assertClose(62.5, EPS);
    });

    it('steps: 1000 gives 0, 2000 gives 20, 3000 gives 35, 10000 gives 100', 0, () => {
      expect(score(ComponentId.STEPS, 1000)).assertEqual(0);
      expect(score(ComponentId.STEPS, 2000)).assertEqual(20);
      expect(score(ComponentId.STEPS, 3000)).assertClose(35, EPS);
      expect(score(ComponentId.STEPS, 10000)).assertEqual(100);
      expect(score(ComponentId.STEPS, 0)).assertEqual(0);
      expect(score(ComponentId.STEPS, 25000)).assertEqual(100);
    });

    it('MVPA: 150 minutes a week gives 80', 0, () => {
      expect(score(ComponentId.MVPA, 150)).assertEqual(80);
    });

    it('resting heart rate: 55 gives 100, 110 gives 5, and 35 gives 90: lower is not always better', 0, () => {
      expect(score(ComponentId.RHR, 55)).assertEqual(100);
      expect(score(ComponentId.RHR, 110)).assertEqual(5);
      expect(score(ComponentId.RHR, 35)).assertEqual(90);
      expect(score(ComponentId.RHR, 50)).assertEqual(100);
      expect(score(ComponentId.RHR, 42.5)).assertClose(94, EPS);
    });

    it('a value that is not a finite number has no score, never NaN', 0, () => {
      expect(piecewise(curveOf(ComponentId.STEPS), NaN)).assertUndefined();
      expect(piecewise(curveOf(ComponentId.STEPS), Infinity)).assertUndefined();
      expect(piecewise(curveOf(ComponentId.STEPS), -Infinity)).assertUndefined();
      expect(piecewise([], 5)).assertUndefined();
    });
  });

  describe('HES model', () => {
    it('the weights of both profiles sum to 1000 thousandths', 0, () => {
      for (let p = 0; p < HES_PROFILES.length; p++) {
        let sum = 0;
        for (let i = 0; i < HES_COMPONENTS.length; i++) {
          sum += hesWeightPermille(HES_PROFILES[p], HES_COMPONENTS[i].id);
        }
        expect(sum).assertEqual(1000);
      }
    });

    it('the weights are the ones of the specification', 0, () => {
      const hw = HesProfile.HEALTH_WELLNESS;
      const lw = HesProfile.LONGEVITY_WELLNESS;
      expect(hesWeightPermille(hw, ComponentId.CRF)).assertEqual(125);
      expect(hesWeightPermille(hw, ComponentId.RHR)).assertEqual(125);
      expect(hesWeightPermille(hw, ComponentId.MVPA)).assertEqual(200);
      expect(hesWeightPermille(hw, ComponentId.STEPS)).assertEqual(150);
      expect(hesWeightPermille(hw, ComponentId.SLEEP_REGULARITY)).assertEqual(150);
      expect(hesWeightPermille(hw, ComponentId.SLEEP_DURATION)).assertEqual(125);
      expect(hesWeightPermille(hw, ComponentId.HRV)).assertEqual(75);
      expect(hesWeightPermille(hw, ComponentId.HRR)).assertEqual(50);
      expect(hesWeightPermille(lw, ComponentId.CRF)).assertEqual(225);
      expect(hesWeightPermille(lw, ComponentId.RHR)).assertEqual(150);
      expect(hesWeightPermille(lw, ComponentId.MVPA)).assertEqual(150);
      expect(hesWeightPermille(lw, ComponentId.STEPS)).assertEqual(175);
      expect(hesWeightPermille(lw, ComponentId.SLEEP_REGULARITY)).assertEqual(100);
      expect(hesWeightPermille(lw, ComponentId.SLEEP_DURATION)).assertEqual(75);
      expect(hesWeightPermille(lw, ComponentId.HRV)).assertEqual(75);
      expect(hesWeightPermille(lw, ComponentId.HRR)).assertEqual(50);
    });

    it('five Core and three optional components, with the minimum and target counts', 0, () => {
      const core: string[] = [];
      for (let i = 0; i < HES_COMPONENTS.length; i++) {
        if (HES_COMPONENTS[i].requiredCore) {
          core.push(HES_COMPONENTS[i].id);
        }
      }
      expect(core).assertDeepEquals(['rhr', 'mvpa', 'steps', 'sleepRegularity', 'sleepDuration']);
      const counts: number[][] = [];
      for (let i = 0; i < HES_COMPONENTS.length; i++) {
        counts.push([HES_COMPONENTS[i].minimumCount, HES_COMPONENTS[i].targetCount, HES_COMPONENTS[i].windowDays]);
      }
      expect(counts).assertDeepEquals([[1, 2, 90], [10, 14, 28], [14, 21, 28], [14, 21, 28], [14, 21, 28],
        [14, 21, 28], [7, 14, 14], [2, 3, 60]]);
    });
  });

  describe('HES sleep timing', () => {
    it('23:30 gives 330 and 00:30 gives 390: 60 minutes apart', 0, () => {
      expect(sleepRelativeMinutes(23 * 60 + 30)).assertEqual(330);
      expect(sleepRelativeMinutes(30)).assertEqual(390);
      expect(sleepRelativeMinutes(30) - sleepRelativeMinutes(23 * 60 + 30)).assertEqual(60);
    });

    it('the standard deviation is the population one and the median of an even count is the mean of two', 0, () => {
      expect(hesPopulationSd([2, 4, 4, 4, 5, 5, 7, 9])).assertClose(2, EPS);
      expect(hesMedian([1, 9, 3, 5])).assertEqual(4);
      expect(hesMedian([])).assertUndefined();
      expect(hesPopulationSd([])).assertUndefined();
      expect(sleepTimingSd(30, 40)).assertClose(Math.sqrt(1250), EPS);
    });
  });

  describe('HES score', () => {
    it('rounding: 84.49 gives 84 and 84.50 gives 85', 0, () => {
      expect(hesRound(84.49)).assertEqual(84);
      expect(hesRound(84.5)).assertEqual(85);
      expect(hesRound(84.49999999999999)).assertEqual(85);
      expect(hesRound(59.4)).assertEqual(59);
    });

    it('tiers: A from 80, B from 60, C below', 0, () => {
      expect(tierFromHes(80)).assertEqual(HesTier.A);
      expect(tierFromHes(79)).assertEqual(HesTier.B);
      expect(tierFromHes(60)).assertEqual(HesTier.B);
      expect(tierFromHes(59)).assertEqual(HesTier.C);
    });

    it('confidence: High from 0.80, Medium from 0.60, Low below', 0, () => {
      expect(confidenceFromIndex(0.8)).assertEqual(HesConfidence.HIGH);
      expect(confidenceFromIndex(0.7999)).assertEqual(HesConfidence.MEDIUM);
      expect(confidenceFromIndex(0.6)).assertEqual(HesConfidence.MEDIUM);
      expect(confidenceFromIndex(0.5999)).assertEqual(HesConfidence.LOW);
      expect(confidenceFromIndex(0.7 + 0.1)).assertEqual(HesConfidence.HIGH);
    });

    it('a Core-only history is scored on the Core weights alone', 0, () => {
      const result = computeHes(HesProfile.HEALTH_WELLNESS, coreHistory(28));
      expect(result.status).assertEqual(HesStatus.OK);
      expect(result.coveragePermille).assertEqual(750);
      expect(result.coverage).assertEqual(75);
      // (125*95 + 200*89 + 150*95 + 150*100 + 125*100) / 750
      expect(result.observed).assertClose(95.23333333333333, EPS);
      expect(result.score).assertEqual(95);
      expect(result.tier).assertEqual(HesTier.A);
      expect(result.confidenceIndex).assertClose(0.75, EPS);
      expect(result.confidence).assertEqual(HesConfidence.MEDIUM);
      expect(result.modelVersion).assertEqual(HES_MODEL_VERSION);
      expect(byId(result, ComponentId.MVPA).effectiveWeight).assertClose(200 / 750, EPS);
      expect(byId(result, ComponentId.MVPA).baseWeight).assertClose(0.2, EPS);
    });

    it('without one Core component there is no score, no tier and no confidence; coverage is still counted', 0,
      () => {
        const history = coreHistory(28);
        for (let i = 0; i < history.days.length; i++) {
          history.days[i].sleep = undefined;
        }
        for (let p = 0; p < HES_PROFILES.length; p++) {
          const result = computeHes(HES_PROFILES[p], history);
          expect(result.score).assertUndefined();
          expect(result.observed).assertUndefined();
          expect(result.tier).assertEqual(HesTier.NONE);
          expect(result.status).assertEqual(HesStatus.INSUFFICIENT_DATA);
          expect(result.confidence).assertEqual(HesConfidence.NOT_ENOUGH_DATA);
          expect(result.confidenceIndex).assertUndefined();
          expect(byId(result, ComponentId.SLEEP_DURATION).score).assertUndefined();
          expect(byId(result, ComponentId.SLEEP_DURATION).available).assertFalse();
          expect(byId(result, ComponentId.STEPS).effectiveWeight).assertUndefined();
        }
        expect(computeHes(HesProfile.HEALTH_WELLNESS, history).coverage).assertEqual(47.5);
        expect(computeHes(HesProfile.LONGEVITY_WELLNESS, history).coverage).assertEqual(47.5);
      });

    it('thirteen valid days are below the minimum of fourteen: the component is not available', 0, () => {
      const result = computeHes(HesProfile.HEALTH_WELLNESS, coreHistory(13));
      expect(byId(result, ComponentId.STEPS).available).assertFalse();
      expect(byId(result, ComponentId.STEPS).validCount).assertEqual(13);
      expect(byId(result, ComponentId.RHR).available).assertTrue();
      expect(result.status).assertEqual(HesStatus.INSUFFICIENT_DATA);
      expect(computeHes(HesProfile.HEALTH_WELLNESS, coreHistory(14)).status).assertEqual(HesStatus.OK);
    });

    it('MVPA is the mean daily equivalent of the valid days times 7; a missing day is not zero minutes', 0, () => {
      const history = coreHistory(28);
      for (let i = 0; i < 8; i++) {
        history.days[i].moderateMin = undefined;
      }
      const mvpa = aggregate(history).mvpa;
      expect(mvpa.validCount).assertEqual(20);
      expect(mvpa.raw).assertClose(210, EPS);
      // A day with only one of the two fields is not a valid MVPA day.
      history.days[10].vigorousMin = undefined;
      expect(aggregate(history).mvpa.validCount).assertEqual(19);
    });

    it('only completed days inside the 28-day window count, by calendar date', 0, () => {
      const history = coreHistory(40);
      const steps = aggregate(history).steps;
      expect(steps.validCount).assertEqual(28);
      // A gap in the calendar is not filled: the window is days, not entries.
      const gapped: HesHistory = { days: [], crf: [], hrr: [] };
      for (let i = 59; i >= 0; i -= 2) {
        gapped.days.push(coreDay(i - 1));
      }
      expect(aggregate(gapped).steps.validCount).assertEqual(14);
    });

    it('an empty history has no score and zero coverage', 0, () => {
      const result = computeHes(HesProfile.HEALTH_WELLNESS, { days: [], crf: [], hrr: [] });
      expect(result.status).assertEqual(HesStatus.INSUFFICIENT_DATA);
      expect(result.coveragePermille).assertEqual(0);
      expect(result.tier).assertEqual(HesTier.NONE);
      expect(result.components.length).assertEqual(8);
    });
  });

  describe('HES filters', () => {
    it('HRV of another protocol is skipped and does not count', 0, () => {
      const history = coreHistory(28);
      for (let i = 0; i < history.days.length; i++) {
        history.days[i].hrv = { percentile: 60, protocol: i % 2 === 0 ? 'nocturnal' : 'spot-check' };
      }
      const hrv = aggregate(history).hrv;
      expect(hrv.validCount).assertEqual(7);
      expect(hrv.raw).assertEqual(60);
      for (let i = 0; i < history.days.length; i++) {
        history.days[i].hrv = { percentile: 60, protocol: 'spot-check' };
      }
      expect(aggregate(history).hrv.validCount).assertEqual(0);
      expect(byId(computeHes(HesProfile.HEALTH_WELLNESS, history), ComponentId.HRV).available).assertFalse();
    });

    it('HRV looks at the last 14 nights only', 0, () => {
      const history = coreHistory(28);
      for (let i = 0; i < 14; i++) {
        history.days[i].hrv = { percentile: 90, protocol: 'nocturnal' };
      }
      expect(aggregate(history).hrv.validCount).assertEqual(0);
    });

    it('VO2max: the newest estimate inside 90 days; an older one is not there', 0, () => {
      const history = coreHistory(28);
      history.crf = [
        { date: dateAgo(90), percentile: 20 },
        { date: dateAgo(89), percentile: 40 },
        { date: dateAgo(3), percentile: 55 },
        { date: dateAgo(30), percentile: 45 }
      ];
      const crf = aggregate(history).crf;
      expect(crf.validCount).assertEqual(3);
      expect(crf.raw).assertEqual(55);
    });

    it('VO2max is never worked out from steps or MVPA, and HRV never from a heart rate', 0, () => {
      const result = computeHes(HesProfile.HEALTH_WELLNESS, coreHistory(28));
      expect(byId(result, ComponentId.CRF).available).assertFalse();
      expect(byId(result, ComponentId.CRF).validCount).assertEqual(0);
      expect(byId(result, ComponentId.HRV).available).assertFalse();
      expect(byId(result, ComponentId.HRR).available).assertFalse();
    });

    it('recovery: HRR1 is peak minus the rate 60 s later; a session without a drop is not valid', 0, () => {
      const history = coreHistory(28);
      history.hrr = [
        { date: dateAgo(60), protocolId: 'walk-3min', peakHr: 150, hr60: 100 },
        { date: dateAgo(59), protocolId: 'walk-3min', peakHr: 150, hr60: 120 },
        { date: dateAgo(20), protocolId: 'walk-3min', peakHr: 150, hr60: 126 },
        { date: dateAgo(10), protocolId: 'walk-3min', peakHr: 120, hr60: 120 },
        { date: dateAgo(5), protocolId: 'walk-3min', peakHr: 110, hr60: 130 }
      ];
      const hrr = aggregate(history).hrr;
      expect(hrr.validCount).assertEqual(2);
      expect(hrr.raw).assertEqual(27);
    });

    it('recovery: the protocol with the most sessions is the comparable one; on a tie, the newest session\'s',
      0, () => {
        const history = coreHistory(28);
        history.hrr = [
          { date: dateAgo(40), protocolId: 'walk-3min', peakHr: 150, hr60: 120 },
          { date: dateAgo(30), protocolId: 'interval-run', peakHr: 180, hr60: 140 },
          { date: dateAgo(20), protocolId: 'walk-3min', peakHr: 150, hr60: 126 },
          { date: dateAgo(2), protocolId: 'interval-run', peakHr: 180, hr60: 130 }
        ];
        const tie = aggregate(history).hrr;
        expect(tie.validCount).assertEqual(2);
        expect(tie.raw).assertEqual(45);
        history.hrr.push({ date: dateAgo(50), protocolId: 'walk-3min', peakHr: 150, hr60: 110 });
        const most = aggregate(history).hrr;
        expect(most.validCount).assertEqual(3);
        expect(most.raw).assertEqual(30);
      });
  });

  describe('HES safeguards', () => {
    it('1000 seeded histories with NaN, Infinity, negative and missing values never break the result', 0, () => {
      const prng = new HesPrng(20261004);
      const pool: (number | undefined)[] = [undefined, NaN, Infinity, -Infinity, -1, -500, 0, 1, 7, 55, 480, 1439,
        5000, 12000, 1e12, 0.5];
      const pick = (): number | undefined => pool[Math.floor(prng.next() * pool.length)];
      const num = (): number => {
        const v = pick();
        return v === undefined ? NaN : v;
      };
      const dates: string[] = ['', 'not-a-date', '2026-02-30', '2026-13-01', LAST_DAY];
      const date = (): string => prng.next() < 0.15 ? dates[Math.floor(prng.next() * dates.length)] :
        dateAgo(Math.floor(prng.next() * 130) - 5);
      const protocols: string[] = ['nocturnal', 'spot-check', '', 'walk-3min', 'interval-run'];
      const protocol = (): string => protocols[Math.floor(prng.next() * protocols.length)];
      let scored = 0;
      for (let run = 0; run < 1000; run++) {
        const history: HesHistory = { days: [], crf: [], hrr: [] };
        const dayCount = Math.floor(prng.next() * 45);
        for (let i = 0; i < dayCount; i++) {
          const day: HesDayRecord = { date: prng.next() < 0.8 ? dateAgo(dayCount - 1 - i) : date() };
          // Mostly plausible days with one broken field now and then, so that many runs do get a score.
          const broken = prng.next() < 0.2;
          day.steps = broken ? pick() : 3000 + Math.floor(prng.next() * 9000);
          day.moderateMin = broken ? pick() : Math.floor(prng.next() * 60);
          day.vigorousMin = broken ? pick() : Math.floor(prng.next() * 20);
          day.restingHr = broken ? pick() : 45 + Math.floor(prng.next() * 50);
          if (prng.next() < 0.85) {
            day.sleep = broken ? { bedMin: num(), wakeMin: num(), totalSleepMin: num() } :
              { bedMin: Math.floor(prng.next() * 1440), wakeMin: Math.floor(prng.next() * 1440),
                totalSleepMin: 200 + Math.floor(prng.next() * 400) };
          }
          if (prng.next() < 0.6) {
            day.hrv = { percentile: broken ? num() : Math.floor(prng.next() * 100), protocol: protocol() };
          }
          history.days.push(day);
        }
        const crfCount = Math.floor(prng.next() * 4);
        for (let i = 0; i < crfCount; i++) {
          history.crf.push({ date: date(), percentile: prng.next() < 0.3 ? num() : Math.floor(prng.next() * 100) });
        }
        const hrrCount = Math.floor(prng.next() * 6);
        for (let i = 0; i < hrrCount; i++) {
          history.hrr.push({
            date: date(),
            protocolId: protocol(),
            peakHr: prng.next() < 0.3 ? num() : 120 + Math.floor(prng.next() * 60),
            hr60: prng.next() < 0.3 ? num() : 90 + Math.floor(prng.next() * 60)
          });
        }
        for (let p = 0; p < HES_PROFILES.length; p++) {
          const result = computeHes(HES_PROFILES[p], history);
          expect(Number.isFinite(result.coverage)).assertTrue();
          expect(result.coveragePermille >= 0 && result.coveragePermille <= 1000).assertTrue();
          expect(result.components.length).assertEqual(8);
          if (result.status === HesStatus.OK) {
            scored++;
            const s = result.score;
            const index = result.confidenceIndex;
            expect(s !== undefined && Number.isInteger(s) && s >= 0 && s <= 100).assertTrue();
            expect(Number.isFinite(result.observed)).assertTrue();
            expect(index !== undefined && Number.isFinite(index) && index >= 0 && index <= 1 + EPS).assertTrue();
            expect(result.tier !== HesTier.NONE).assertTrue();
            expect(result.confidence !== HesConfidence.NOT_ENOUGH_DATA).assertTrue();
            expect(result.tier === HesTier.C).assertEqual(s !== undefined && s < 60);
          } else {
            // No score is never a low score and never tier C.
            expect(result.score).assertUndefined();
            expect(result.tier).assertEqual(HesTier.NONE);
            expect(result.confidence).assertEqual(HesConfidence.NOT_ENOUGH_DATA);
          }
          for (let i = 0; i < result.components.length; i++) {
            const c = result.components[i];
            expect(Number.isFinite(c.quality) && c.quality >= 0 && c.quality <= 1).assertTrue();
            expect(Number.isInteger(c.validCount) && c.validCount >= 0).assertTrue();
            if (c.available) {
              const cs = c.score;
              expect(cs !== undefined && Number.isFinite(cs) && cs >= 0 && cs <= 100).assertTrue();
              expect(Number.isFinite(c.rawValue)).assertTrue();
              expect(c.validCount >= c.minimumCount).assertTrue();
            } else {
              // A missing component never has a score, least of all zero.
              expect(c.score).assertUndefined();
              expect(c.rawValue).assertUndefined();
              expect(c.effectiveWeight).assertUndefined();
            }
          }
        }
      }
      // The fuzz reaches both branches.
      expect(scored).assertLarger(50);
      expect(scored).assertLess(2000);
    });

    it('a negative, NaN or infinite reading is not a reading; it is never counted as zero', 0, () => {
      const history = coreHistory(28);
      history.days[27].steps = -1;
      history.days[26].steps = NaN;
      history.days[25].steps = Infinity;
      const steps = aggregate(history).steps;
      expect(steps.validCount).assertEqual(25);
      expect(steps.raw).assertEqual(8000);
      // Zero steps is a reading: it stays in the count and pulls the mean down.
      history.days[24].steps = 0;
      expect(aggregate(history).steps.validCount).assertEqual(25);
      expect(aggregate(history).steps.raw).assertClose(8000 * 24 / 25, EPS);
    });
  });

  describe('HES numbers as text', () => {
    it('coverage: 47.5%, 75%, 87.5%, 100%', 0, () => {
      expect(hesCoverageText(475)).assertEqual('47.5%');
      expect(hesCoverageText(750)).assertEqual('75%');
      expect(hesCoverageText(875)).assertEqual('87.5%');
      expect(hesCoverageText(1000)).assertEqual('100%');
    });

    it('an effective weight has one decimal, halves up: 150/800 reads 18.8%', 0, () => {
      expect(hesWeightText(150 / 800)).assertEqual('18.8%');
      expect(hesWeightText(150 / 750)).assertEqual('20.0%');
      expect(hesOneDecimal(84.25)).assertEqual('84.3');
    });

    it('raw values in readable units', 0, () => {
      expect(hesRawText(ComponentId.CRF, 77)).assertEqual('77th percentile (age & sex)');
      expect(hesRawText(ComponentId.RHR, 58)).assertEqual('58 bpm');
      expect(hesRawText(ComponentId.MVPA, 238)).assertEqual('238 min/week (vigorous counts ×2)');
      expect(hesRawText(ComponentId.STEPS, 8800)).assertEqual('8,800/day');
      expect(hesRawText(ComponentId.SLEEP_REGULARITY, 45)).assertEqual('±45 min');
      expect(hesRawText(ComponentId.SLEEP_DURATION, 7.4)).assertEqual('7 h 24 min');
      expect(hesRawText(ComponentId.HRV, 60)).assertEqual('60th percentile');
      expect(hesRawText(ComponentId.HRR, 32)).assertEqual('32 bpm drop in 60 s');
    });

    it('how far a component is from its minimum', 0, () => {
      const result = computeHes(HesProfile.HEALTH_WELLNESS, coreHistory(6));
      expect(hesCountText(byId(result, ComponentId.SLEEP_REGULARITY))).assertEqual('6 of 14 nights');
      expect(hesCountText(byId(result, ComponentId.CRF))).assertEqual('0 of 1');
      expect(hesCountText(byId(result, ComponentId.HRR))).assertEqual('0 of 2 sessions');
      expect(hesCountText(byId(result, ComponentId.HRV))).assertEqual('0 of 7 nights');
    });
  });
}
