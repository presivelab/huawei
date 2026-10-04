import { describe, it, expect } from '@ohos/hypium';
import { aggregate, aggregateOf, hesPopulationSd, sleepTimingSd } from '../main/ets/hes/HesAggregate';
import { computeHes } from '../main/ets/hes/HesEngine';
import { explainHes, pointsToNextTier } from '../main/ets/hes/HesExplain';
import { hesCountText, hesCoverageText, hesOneDecimal, hesSummaryText } from '../main/ets/hes/HesFormat';
import { HES_COMPONENTS, HES_PROFILES, HRV_PROTOCOL } from '../main/ets/hes/HesModel';
import {
  generatePersonaHistory,
  generatePersonaToday,
  HesPersonas,
  HesPersonaSpec,
  HES_PERSONA_END_DATE,
  HES_PERSONA_TODAY,
  personaPattern
} from '../main/ets/hes/HesPersonas';
import { copyHesDayRecord, copyHesHistory } from '../main/ets/hes/HesSession';
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

// The golden values were calculated by a reference implementation and checked by a second, independent one.
// When a number here disagrees with the engine, the engine is wrong: the numbers are not to be adjusted.
const TODAY = '2026-10-04';
const EPS = 1e-9;
const TWO_PLACES = 5e-3;
const THREE_PLACES = 5e-4;
const HW = HesProfile.HEALTH_WELLNESS;
const LW = HesProfile.LONGEVITY_WELLNESS;
const NA = -1;  // "no value" in the tables below

const ORDER: ComponentId[] = [ComponentId.CRF, ComponentId.RHR, ComponentId.MVPA, ComponentId.STEPS,
  ComponentId.SLEEP_REGULARITY, ComponentId.SLEEP_DURATION, ComponentId.HRV, ComponentId.HRR];

class Golden {
  id: string = '';
  raw: number[] = [];          // in ORDER; NA when the component is not available
  valid: number[] = [];        // valid counts, in ORDER
  scores: number[] = [];       // component scores, in ORDER; NA when not available
  hwScore: number = NA;
  hwTier: HesTier = HesTier.NONE;
  hwCoverage: number = 0;
  hwConfidence: HesConfidence = HesConfidence.NOT_ENOUGH_DATA;
  hwObserved: number = NA;
  hwIndex: number = NA;
  lwScore: number = NA;
  lwTier: HesTier = HesTier.NONE;
  lwCoverage: number = 0;
  lwConfidence: HesConfidence = HesConfidence.NOT_ENOUGH_DATA;
  lwObserved: number = NA;
  lwIndex: number = NA;
  strongest: string[] = [];
  toImprove: string[] = [];
  missingOptional: string[] = [];
}

function golden(id: string, raw: number[], valid: number[], scores: number[]): Golden {
  const g = new Golden();
  g.id = id;
  g.raw = raw;
  g.valid = valid;
  g.scores = scores;
  return g;
}

function hw(g: Golden, score: number, tier: HesTier, coverage: number, confidence: HesConfidence,
  observed: number, index: number): Golden {
  g.hwScore = score;
  g.hwTier = tier;
  g.hwCoverage = coverage;
  g.hwConfidence = confidence;
  g.hwObserved = observed;
  g.hwIndex = index;
  return g;
}

function lw(g: Golden, score: number, tier: HesTier, coverage: number, confidence: HesConfidence,
  observed: number, index: number): Golden {
  g.lwScore = score;
  g.lwTier = tier;
  g.lwCoverage = coverage;
  g.lwConfidence = confidence;
  g.lwObserved = observed;
  g.lwIndex = index;
  return g;
}

function why(g: Golden, strongest: string[], toImprove: string[], missingOptional: string[]): Golden {
  g.strongest = strongest;
  g.toImprove = toImprove;
  g.missingOptional = missingOptional;
  return g;
}

//                      crf  rhr  mvpa  steps  sleepReg  sleepDur  hrv  hrr
const ANIA = why(lw(hw(golden('ania',
  [77, 58, 238, 8800, 45, 7.4, 60, 32],
  [2, 28, 28, 28, 28, 28, 14, 3],
  [89.2, 97, 93.2, 97, 90, 99, 81, 74]),
  92, HesTier.A, 100, HesConfidence.HIGH, 92.115, 1.000),
  92, HesTier.A, 100, HesConfidence.HIGH, 91.775, 1.000),
  ['sleepDuration', 'steps', 'rhr'], ['hrr', 'hrv', 'crf'], []);

const MAREK = why(lw(hw(golden('marek',
  [NA, 68, 119, 6200, 70, 6.6, 40, 24],
  [0, 28, 28, 28, 28, 28, 14, 3],
  [NA, 86.4, 67.6, 82, 73.33, 84.6, 65, 55]),
  75, HesTier.B, 87.5, HesConfidence.HIGH, 75.223, 0.875),
  76, HesTier.B, 77.5, HesConfidence.MEDIUM, 75.811, 0.775),
  ['rhr', 'sleepDuration', 'steps'], ['hrr', 'hrv', 'mvpa'], ['crf']);

const KASIA = why(lw(hw(golden('kasia',
  [NA, 72, 98, 6000, 70, 6.4, NA, NA],
  [0, 18, 20, 20, 16, 16, 4, 0],
  [NA, 80.8, 59, 80, 73.33, 78.6, NA, NA]),
  73, HesTier.B, 75, HesConfidence.MEDIUM, 72.967, 0.668),
  74, HesTier.B, 65, HesConfidence.LOW, 74.151, 0.593),
  ['rhr', 'steps', 'sleepDuration'], ['mvpa', 'sleepRegularity'], ['crf', 'hrv', 'hrr']);

const TOMEK = why(lw(hw(golden('tomek',
  [50, 62, 147, 7000, 80, 6.5, NA, 27],
  [2, 28, 28, 28, 28, 28, 0, 3],
  [70, 93, 78.8, 90, 66.67, 82, NA, 62.5]),
  79, HesTier.B, 92.5, HesConfidence.HIGH, 78.930, 0.925),
  79, HesTier.B, 92.5, HesConfidence.HIGH, 79.148, 0.925),
  ['rhr', 'steps', 'sleepDuration'], ['hrr', 'sleepRegularity', 'crf'], ['hrv']);

const EWA = why(lw(hw(golden('ewa',
  [NA, 76, 70, 4400, 85, 6.2, NA, 20],
  [0, 20, 20, 20, 16, 16, 3, 2],
  [NA, 74, 45, 56, 63.33, 71.8, NA, 38.33]),
  59, HesTier.C, 80, HesConfidence.MEDIUM, 58.802, 0.701),
  59, HesTier.C, 70, HesConfidence.MEDIUM, 58.979, 0.626),
  ['rhr', 'sleepDuration', 'sleepRegularity'], ['hrr', 'mvpa', 'steps'], ['crf', 'hrv']);

const OLA = why(lw(hw(golden('ola',
  [NA, 68, 112, 6800, NA, NA, NA, NA],
  [0, 16, 16, 16, 6, 6, 6, 0],
  // Her three measured components do have scores on their curves; there is no overall score yet.
  [NA, 86.4, 64.8, 88, NA, NA, NA, NA]),
  NA, HesTier.NONE, 47.5, HesConfidence.NOT_ENOUGH_DATA, NA, NA),
  NA, HesTier.NONE, 47.5, HesConfidence.NOT_ENOUGH_DATA, NA, NA),
  [], [], ['crf', 'hrv', 'hrr']);

const ALL: Golden[] = [ANIA, MAREK, KASIA, TOMEK, EWA, OLA];

function byId(result: HesResult, id: ComponentId): ComponentResult {
  for (let i = 0; i < result.components.length; i++) {
    if (result.components[i].id === id) {
      return result.components[i];
    }
  }
  throw new Error('component not in the result');
}

function ids(components: ComponentResult[]): string[] {
  const out: string[] = [];
  for (let i = 0; i < components.length; i++) {
    out.push(components[i].id);
  }
  return out;
}

function specOf(id: string): HesPersonaSpec {
  const spec = HesPersonas.spec(id);
  if (spec === null) {
    throw new Error('unknown persona');
  }
  return spec;
}

function dateAgo(daysAgo: number): string {
  return dateOfDayNumber(dayNumberOfDate(HES_PERSONA_END_DATE) - daysAgo);
}

function nextDate(history: HesHistory): string {
  return dateOfDayNumber(dayNumberOfDate(history.days[history.days.length - 1].date) + 1);
}

// The same history with `count` more completed days, each a copy of `day` on the next calendar date.
function withClosedDays(history: HesHistory, day: HesDayRecord, count: number): HesHistory {
  const out = copyHesHistory(history);
  for (let i = 0; i < count; i++) {
    const next = copyHesDayRecord(day);
    next.date = nextDate(out);
    out.days.push(next);
  }
  return out;
}

function effectiveWeights(result: HesResult): string[] {
  const out: string[] = [];
  for (let i = 0; i < result.components.length; i++) {
    const weight = result.components[i].effectiveWeight;
    if (weight !== undefined) {
      out.push(`${result.components[i].id} ${hesOneDecimal(weight * 100)}`);
    }
  }
  return out;
}

function checkResult(result: HesResult, score: number, tier: HesTier, coverage: number,
  confidence: HesConfidence, observed: number, index: number): void {
  expect(result.tier).assertEqual(tier);
  expect(result.coverage).assertEqual(coverage);
  expect(result.coveragePermille).assertEqual(coverage * 10);
  expect(result.confidence).assertEqual(confidence);
  if (score === NA) {
    expect(result.score).assertUndefined();
    expect(result.observed).assertUndefined();
    expect(result.confidenceIndex).assertUndefined();
    expect(result.status).assertEqual(HesStatus.INSUFFICIENT_DATA);
  } else {
    expect(result.score).assertEqual(score);
    expect(result.observed).assertClose(observed, THREE_PLACES);
    expect(result.confidenceIndex).assertClose(index, THREE_PLACES);
    expect(result.status).assertEqual(HesStatus.OK);
  }
}

export default function hesPersonasTest() {
  describe('HES personas: the golden values', () => {
    it('aggregates: raw values and valid counts of every persona', 0, () => {
      for (let g = 0; g < ALL.length; g++) {
        const aggregates = aggregate(HesPersonas.history(ALL[g].id, TODAY));
        const result = HesPersonas.result(ALL[g].id, HW, TODAY);
        for (let i = 0; i < ORDER.length; i++) {
          const value = aggregateOf(aggregates, ORDER[i]);
          const component = byId(result, ORDER[i]);
          expect(value.validCount).assertEqual(ALL[g].valid[i]);
          expect(component.validCount).assertEqual(ALL[g].valid[i]);
          if (ALL[g].raw[i] === NA) {
            // Not available: no raw value in the result, whether or not a few readings exist.
            expect(component.available).assertFalse();
            expect(component.rawValue).assertUndefined();
          } else {
            expect(component.available).assertTrue();
            expect(component.rawValue).assertClose(ALL[g].raw[i], EPS);
            expect(value.raw).assertClose(ALL[g].raw[i], EPS);
          }
        }
      }
    });

    it('component scores, the same in both profiles', 0, () => {
      for (let g = 0; g < ALL.length; g++) {
        for (let p = 0; p < HES_PROFILES.length; p++) {
          const result = HesPersonas.result(ALL[g].id, HES_PROFILES[p], TODAY);
          for (let i = 0; i < ORDER.length; i++) {
            const expected = ALL[g].scores[i];
            const component = byId(result, ORDER[i]);
            if (expected === NA) {
              expect(component.score).assertUndefined();
            } else {
              // 73.33 and 66.67 are written to two places; the others are exact.
              const exact = Math.abs(expected * 10 - Math.round(expected * 10)) < EPS;
              expect(component.score).assertClose(expected, exact ? EPS : TWO_PLACES);
            }
          }
        }
      }
    });

    it('Health & wellness: score, tier, coverage, confidence, observed score and confidence index', 0, () => {
      for (let g = 0; g < ALL.length; g++) {
        const x = ALL[g];
        checkResult(HesPersonas.result(x.id, HW, TODAY), x.hwScore, x.hwTier, x.hwCoverage, x.hwConfidence,
          x.hwObserved, x.hwIndex);
      }
    });

    it('Longevity: score, tier, coverage, confidence, observed score and confidence index', 0, () => {
      for (let g = 0; g < ALL.length; g++) {
        const x = ALL[g];
        checkResult(HesPersonas.result(x.id, LW, TODAY), x.lwScore, x.lwTier, x.lwCoverage, x.lwConfidence,
          x.lwObserved, x.lwIndex);
      }
    });

    it('one line per persona, as a screen writes it', 0, () => {
      const lines: string[] = [];
      for (let g = 0; g < ALL.length; g++) {
        lines.push(hesSummaryText(HesPersonas.result(ALL[g].id, HW, TODAY)));
        lines.push(hesSummaryText(HesPersonas.result(ALL[g].id, LW, TODAY)));
      }
      expect(lines).assertDeepEquals([
        '92 · A · 100% · High', '92 · A · 100% · High',
        '75 · B · 87.5% · High', '76 · B · 77.5% · Medium',
        '73 · B · 75% · Medium', '74 · B · 65% · Low',
        '79 · B · 92.5% · High', '79 · B · 92.5% · High',
        '59 · C · 80% · Medium', '59 · C · 70% · Medium',
        'No score · 47.5%', 'No score · 47.5%'
      ]);
    });

    it('points to the next tier: Tomek is 1 point from A', 0, () => {
      expect(pointsToNextTier(HesPersonas.result('ania', HW, TODAY))).assertUndefined();
      expect(pointsToNextTier(HesPersonas.result('marek', HW, TODAY))).assertEqual(5);
      expect(pointsToNextTier(HesPersonas.result('kasia', HW, TODAY))).assertEqual(7);
      expect(pointsToNextTier(HesPersonas.result('tomek', HW, TODAY))).assertEqual(1);
      expect(pointsToNextTier(HesPersonas.result('ewa', HW, TODAY))).assertEqual(1);
      expect(pointsToNextTier(HesPersonas.result('ola', HW, TODAY))).assertUndefined();
      const tomek = explainHes(HesPersonas.result('tomek', HW, TODAY));
      expect(tomek.pointsToNextTier).assertEqual(1);
      expect(tomek.nextTier).assertEqual(HesTier.A);
      expect(explainHes(HesPersonas.result('ewa', LW, TODAY)).nextTier).assertEqual(HesTier.B);
    });
  });

  describe('HES personas: why this tier', () => {
    it('strongest, to improve and missing optional, the same in both profiles', 0, () => {
      for (let g = 0; g < ALL.length; g++) {
        for (let p = 0; p < HES_PROFILES.length; p++) {
          const why = explainHes(HesPersonas.result(ALL[g].id, HES_PROFILES[p], TODAY));
          expect(ids(why.strongest)).assertDeepEquals(ALL[g].strongest);
          expect(ids(why.toImprove)).assertDeepEquals(ALL[g].toImprove);
          expect(ids(why.missingOptional)).assertDeepEquals(ALL[g].missingOptional);
        }
      }
    });

    it('no component is in both lists, and a missing one is in neither', 0, () => {
      for (let g = 0; g < ALL.length; g++) {
        const result = HesPersonas.result(ALL[g].id, HW, TODAY);
        const why = explainHes(result);
        const strongest = ids(why.strongest);
        const toImprove = ids(why.toImprove);
        for (let i = 0; i < toImprove.length; i++) {
          expect(strongest.indexOf(toImprove[i])).assertEqual(-1);
        }
        const missing = ids(why.missingOptional).concat(ids(why.missingCore));
        for (let i = 0; i < missing.length; i++) {
          expect(strongest.indexOf(missing[i])).assertEqual(-1);
          expect(toImprove.indexOf(missing[i])).assertEqual(-1);
          expect(byId(result, missing[i] as ComponentId).score).assertUndefined();
        }
      }
    });

    it('Ania: equal scores go by the higher base weight, steps before resting HR', 0, () => {
      const why = explainHes(HesPersonas.result('ania', HW, TODAY));
      const scores: number[] = [];
      for (let i = 0; i < why.strongest.length; i++) {
        scores.push(why.strongest[i].score as number);
      }
      expect(ids(why.strongest)).assertDeepEquals(['sleepDuration', 'steps', 'rhr']);
      expect(scores[0]).assertClose(99, EPS);
      expect(scores[1]).assertClose(97, EPS);
      expect(scores[2]).assertClose(97, EPS);
      expect(why.toImprove[0].score).assertClose(74, EPS);
      expect(why.toImprove[1].score).assertClose(81, EPS);
      expect(why.toImprove[2].score).assertClose(89.2, EPS);
    });

    it('missing optional data is listed with its count against the minimum', 0, () => {
      const kasia = explainHes(HesPersonas.result('kasia', HW, TODAY));
      const lines: string[] = [];
      for (let i = 0; i < kasia.missingOptional.length; i++) {
        lines.push(`${kasia.missingOptional[i].label} ${hesCountText(kasia.missingOptional[i])}`);
      }
      expect(lines).assertDeepEquals(['VO₂max 0 of 1', 'HRV 4 of 7 nights', 'HRR 0 of 2 sessions']);
      const tomek = explainHes(HesPersonas.result('tomek', HW, TODAY));
      expect(hesCountText(tomek.missingOptional[0])).assertEqual('0 of 7 nights');
      const ewa = explainHes(HesPersonas.result('ewa', HW, TODAY));
      expect(hesCountText(ewa.missingOptional[1])).assertEqual('3 of 7 nights');
    });

    it('Ola has no score: what is measured, what the score needs, and the optional data apart', 0, () => {
      const result = HesPersonas.result('ola', HW, TODAY);
      const why = explainHes(result);
      expect(why.strongest.length).assertEqual(0);
      expect(why.toImprove.length).assertEqual(0);
      expect(ids(why.measured)).assertDeepEquals(['rhr', 'mvpa', 'steps']);
      expect(ids(why.missingCore)).assertDeepEquals(['sleepRegularity', 'sleepDuration']);
      expect(hesCountText(why.missingCore[0])).assertEqual('6 of 14 nights');
      expect(hesCountText(why.missingCore[1])).assertEqual('6 of 14 nights');
      expect(ids(why.missingOptional)).assertDeepEquals(['crf', 'hrv', 'hrr']);
      expect(hesCountText(why.missingOptional[1])).assertEqual('6 of 7 nights');
      expect(hesCoverageText(result.coveragePermille)).assertEqual('47.5%');
      expect(why.pointsToNextTier).assertUndefined();
    });

    it('effective weights in Health & wellness when coverage is below 100%', 0, () => {
      expect(effectiveWeights(HesPersonas.result('marek', HW, TODAY))).assertDeepEquals([
        'rhr 14.3', 'mvpa 22.9', 'steps 17.1', 'sleepRegularity 17.1', 'sleepDuration 14.3', 'hrv 8.6',
        'hrr 5.7']);
      expect(effectiveWeights(HesPersonas.result('kasia', HW, TODAY))).assertDeepEquals([
        'rhr 16.7', 'mvpa 26.7', 'steps 20.0', 'sleepRegularity 20.0', 'sleepDuration 16.7']);
      expect(effectiveWeights(HesPersonas.result('tomek', HW, TODAY))).assertDeepEquals([
        'crf 13.5', 'rhr 13.5', 'mvpa 21.6', 'steps 16.2', 'sleepRegularity 16.2', 'sleepDuration 13.5',
        'hrr 5.4']);
      expect(effectiveWeights(HesPersonas.result('ewa', HW, TODAY))).assertDeepEquals([
        'rhr 15.6', 'mvpa 25.0', 'steps 18.8', 'sleepRegularity 18.8', 'sleepDuration 15.6', 'hrr 6.3']);
      expect(effectiveWeights(HesPersonas.result('ola', HW, TODAY)).length).assertEqual(0);
    });

    it('the base weights are never overwritten by the effective ones', 0, () => {
      const result = HesPersonas.result('kasia', HW, TODAY);
      expect(byId(result, ComponentId.MVPA).baseWeight).assertClose(0.2, EPS);
      expect(byId(result, ComponentId.MVPA).effectiveWeight).assertClose(200 / 750, EPS);
      expect(byId(result, ComponentId.CRF).baseWeight).assertClose(0.125, EPS);
    });
  });

  describe('HES personas: sleep across midnight', () => {
    it('Ewa goes to bed at 22:20 or 01:10 and her timing SD is 85', 0, () => {
      const history = HesPersonas.history('ewa', TODAY);
      const bedtimes: number[] = [];
      const wakeTimes: number[] = [];
      for (let i = 0; i < history.days.length; i++) {
        const sleep = history.days[i].sleep;
        if (sleep !== undefined) {
          bedtimes.push(sleep.bedMin);
          wakeTimes.push(sleep.wakeMin);
        }
      }
      expect(bedtimes.length).assertEqual(16);
      expect(bedtimes.indexOf(22 * 60 + 20) >= 0).assertTrue();
      expect(bedtimes.indexOf(60 + 10) >= 0).assertTrue();
      expect(aggregate(history).sleepRegularity.raw).assertClose(85, EPS);
      // Plain minutes since midnight would put 22:20 and 01:10 almost a day apart.
      const naiveBed = hesPopulationSd(bedtimes) as number;
      const naiveWake = hesPopulationSd(wakeTimes) as number;
      expect(naiveBed).assertClose(635, 0.5);
      expect(sleepTimingSd(naiveBed, naiveWake)).assertClose(453, 0.5);
    });

    it('every clock time of every persona is inside 0..1439 and sleep is never longer than the time in bed', 0,
      () => {
        for (let g = 0; g < ALL.length; g++) {
          const days = HesPersonas.history(ALL[g].id, TODAY).days;
          for (let i = 0; i < days.length; i++) {
            const sleep = days[i].sleep;
            if (sleep === undefined) {
              continue;
            }
            expect(sleep.bedMin >= 0 && sleep.bedMin < 1440).assertTrue();
            expect(sleep.wakeMin >= 0 && sleep.wakeMin < 1440).assertTrue();
            const inBed = (sleep.wakeMin - sleep.bedMin + 1440) % 1440;
            expect(sleep.totalSleepMin <= inBed).assertTrue();
          }
        }
      });
  });

  describe('HES personas: missing optional data', () => {
    it('Ania without HRV: coverage drops by exactly 7.5 and the score is still calculated', 0, () => {
      const history = HesPersonas.history('ania', TODAY);
      for (let i = 0; i < history.days.length; i++) {
        history.days[i].hrv = undefined;
      }
      const inHw = computeHes(HW, history);
      expect(inHw.coverage).assertEqual(92.5);
      expect(100 - inHw.coverage).assertEqual(7.5);
      expect(inHw.score).assertEqual(93);
      expect(inHw.observed).assertClose(93.016, THREE_PLACES);
      expect(byId(inHw, ComponentId.MVPA).effectiveWeight).assertClose(200 / 925, EPS);
      expect(byId(inHw, ComponentId.MVPA).effectiveWeight).assertClose(0.2162, 5e-5);
      expect(byId(inHw, ComponentId.HRV).score).assertUndefined();
      expect(byId(inHw, ComponentId.HRV).effectiveWeight).assertUndefined();
      const inLw = computeHes(LW, history);
      expect(inLw.coverage).assertEqual(92.5);
      expect(inLw.score).assertEqual(93);
      expect(inLw.observed).assertClose(92.649, THREE_PLACES);
      expect(byId(inLw, ComponentId.MVPA).effectiveWeight).assertClose(150 / 925, EPS);
      expect(byId(inLw, ComponentId.MVPA).effectiveWeight).assertClose(0.1622, 5e-5);
    });

    it('Tomek has heart-rate data and no HRV: HRV is not available', 0, () => {
      const result = HesPersonas.result('tomek', HW, TODAY);
      expect(byId(result, ComponentId.RHR).available).assertTrue();
      expect(byId(result, ComponentId.HRV).available).assertFalse();
      expect(byId(result, ComponentId.HRV).validCount).assertEqual(0);
    });

    it('Kasia has steps and MVPA and no VO2max estimate: VO2max is not available', 0, () => {
      const result = HesPersonas.result('kasia', HW, TODAY);
      expect(byId(result, ComponentId.STEPS).available).assertTrue();
      expect(byId(result, ComponentId.MVPA).available).assertTrue();
      expect(byId(result, ComponentId.CRF).available).assertFalse();
    });
  });

  describe('HES personas: closing days at the engine', () => {
    it('Ania plus one completed day without a night: the windows move and the score is 92 · A · High', 0, () => {
      const day: HesDayRecord = { date: '', steps: 8000, moderateMin: 20, vigorousMin: 7, restingHr: 58 };
      const history = withClosedDays(HesPersonas.history('ania', TODAY), day, 1);
      expect(history.days.length).assertEqual(29);
      const aggregates = aggregate(history);
      expect(aggregates.steps.raw).assertClose(8792.857142857, 1e-6);
      expect(aggregates.steps.validCount).assertEqual(28);
      expect(aggregates.mvpa.raw).assertClose(239.5, EPS);
      expect(aggregates.rhr.raw).assertClose(59, EPS);
      expect(aggregates.sleepDuration.validCount).assertEqual(27);
      const result = computeHes(HW, history);
      expect(result.score).assertEqual(92);
      expect(result.tier).assertEqual(HesTier.A);
      expect(result.confidence).assertEqual(HesConfidence.HIGH);
      expect(result.observed).assertClose(92.385, THREE_PLACES);
    });

    it('Ola: seven more complete days are not enough, the eighth gives the first score', 0, () => {
      const day = HesPersonas.today('ola', TODAY);
      expect(day.steps).assertEqual(6800);
      expect(day.moderateMin).assertEqual(10);
      expect(day.vigorousMin).assertEqual(3);
      expect(day.restingHr).assertEqual(68);
      expect(day.sleep).assertDeepEquals({ bedMin: 23 * 60 + 15, wakeMin: 7 * 60, totalSleepMin: 420 });
      expect(day.hrv).assertDeepEquals({ percentile: 50, protocol: HRV_PROTOCOL });
      const start = HesPersonas.history('ola', TODAY);
      const seven = computeHes(HW, withClosedDays(start, day, 7));
      expect(seven.status).assertEqual(HesStatus.INSUFFICIENT_DATA);
      expect(seven.coverage).assertEqual(55);
      expect(seven.tier).assertEqual(HesTier.NONE);
      const eight = withClosedDays(start, day, 8);
      checkResult(computeHes(HW, eight), 84, HesTier.A, 82.5, HesConfidence.MEDIUM, 84.194, 0.733);
      checkResult(computeHes(LW, eight), 84, HesTier.A, 72.5, HesConfidence.MEDIUM, 83.903, 0.667);
    });
  });

  describe('HES personas: windows and protocols', () => {
    it('Ania: the estimate from 120 days ago and the session from 75 days ago are outside the windows', 0, () => {
      const history = HesPersonas.history('ania', TODAY);
      expect(history.crf.length).assertEqual(3);
      expect(history.hrr.length).assertEqual(4);
      expect(history.crf[0].date).assertEqual(dateAgo(120));
      expect(history.hrr[0].date).assertEqual(dateAgo(75));
      const aggregates = aggregate(history);
      expect(aggregates.crf.validCount).assertEqual(2);
      expect(aggregates.crf.raw).assertEqual(77);
      expect(aggregates.hrr.validCount).assertEqual(3);
      expect(aggregates.hrr.raw).assertEqual(32);
    });

    it('Tomek: the interval-run session is not comparable with the walk sessions', 0, () => {
      const history = HesPersonas.history('tomek', TODAY);
      expect(history.hrr.length).assertEqual(4);
      const hrr = aggregate(history).hrr;
      expect(hrr.validCount).assertEqual(3);
      expect(hrr.raw).assertEqual(27);
    });

    it('Tomek plus a new interval-run session yesterday: recovery is still 27 from 3 sessions', 0, () => {
      const history = HesPersonas.history('tomek', TODAY);
      history.hrr.push({ date: dateAgo(1), protocolId: 'interval-run', peakHr: 180, hr60: 135 });
      const hrr = aggregate(history).hrr;
      expect(hrr.validCount).assertEqual(3);
      expect(hrr.raw).assertEqual(27);
      expect(byId(computeHes(HW, history), ComponentId.HRR).score).assertClose(62.5, EPS);
    });
  });

  describe('HES personas: the generator', () => {
    it('pattern: the mean and the median are the base for every count', 0, () => {
      expect(personaPattern(10, 2, 5)).assertDeepEquals([10, 8, 12, 8, 12]);
      expect(personaPattern(10, 2, 4)).assertDeepEquals([8, 12, 8, 12]);
      expect(personaPattern(10, 2, 1)).assertDeepEquals([10]);
      expect(personaPattern(10, 2, 0).length).assertEqual(0);
    });

    it('the same persona gives the same history on every call', 0, () => {
      for (let g = 0; g < ALL.length; g++) {
        expect(HesPersonas.history(ALL[g].id, TODAY)).assertDeepEquals(HesPersonas.history(ALL[g].id, TODAY));
      }
    });

    it('the history ends the day before today and has one record per calendar day', 0, () => {
      expect(HES_PERSONA_TODAY).assertEqual(TODAY);
      for (let g = 0; g < ALL.length; g++) {
        const spec = specOf(ALL[g].id);
        const days = generatePersonaHistory(spec, TODAY).days;
        expect(days.length).assertEqual(spec.days);
        expect(days[days.length - 1].date).assertEqual(HES_PERSONA_END_DATE);
        for (let i = 1; i < days.length; i++) {
          expect(dayNumberOfDate(days[i].date) - dayNumberOfDate(days[i - 1].date)).assertEqual(1);
        }
      }
      expect(specOf('ola').days).assertEqual(16);
    });

    it('today is a parameter: another day moves the whole history and keeps the score', 0, () => {
      const moved = HesPersonas.history('tomek', '2027-01-15');
      expect(moved.days[moved.days.length - 1].date).assertEqual('2027-01-14');
      expect(computeHes(HW, moved).score).assertEqual(79);
      expect(HesPersonas.history('tomek', 'not a date').days.length).assertEqual(0);
    });

    it('a value series fills the newest days; the older days do not have the field at all', 0, () => {
      const days = HesPersonas.history('kasia', TODAY).days;
      for (let i = 0; i < days.length; i++) {
        expect(days[i].steps === undefined).assertEqual(i < 8);
        expect(days[i].restingHr === undefined).assertEqual(i < 10);
        expect(days[i].sleep === undefined).assertEqual(i < 12);
        expect(days[i].hrv === undefined).assertEqual(i < 24);
        expect(days[i].moderateMin === undefined).assertEqual(days[i].vigorousMin === undefined);
      }
    });

    it('vigorous minutes are a fifth of the daily equivalent, rounded down', 0, () => {
      const day = generatePersonaToday(specOf('ania'), TODAY);
      expect(day.vigorousMin).assertEqual(6);
      expect(day.moderateMin).assertEqual(22);
      expect(generatePersonaToday(specOf('tomek'), TODAY).hrv).assertUndefined();
    });

    it('an unknown persona has an empty history and no score', 0, () => {
      expect(HesPersonas.has('nobody')).assertFalse();
      expect(HesPersonas.history('nobody', TODAY).days.length).assertEqual(0);
      expect(HesPersonas.result('nobody', HW, TODAY).status).assertEqual(HesStatus.INSUFFICIENT_DATA);
      expect(HesPersonas.displayName('nobody')).assertEqual('nobody');
      expect(HES_COMPONENTS.length).assertEqual(8);
    });
  });
}
