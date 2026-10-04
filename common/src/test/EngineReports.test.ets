import { describe, it, expect } from '@ohos/hypium';
import { validateTierClaimJson } from '../main/ets/claim/ClaimValidation';
import { buildTierClaim, encodeTierClaim } from '../main/ets/claim/TierClaimCodec';
import { piecewise } from '../main/ets/hes/HesCurves';
import { composeComponents, computeHes, hesRound } from '../main/ets/hes/HesEngine';
import { pointsToNextTier } from '../main/ets/hes/HesExplain';
import { HES_COMPONENTS, HES_PROFILES, hesComponentDefinition, HesPoint } from '../main/ets/hes/HesModel';
import { HesPersonas } from '../main/ets/hes/HesPersonas';
import { HesSession } from '../main/ets/hes/HesSession';
import {
  ComponentId as HesComponentId,
  ComponentResult,
  HesDayRecord,
  HesHistory,
  HesProfile,
  HesResult,
  HesStatus,
  HesTier
} from '../main/ets/hes/HesTypes';
import { dateOfDayNumber, dayNumberOfDate } from '../main/ets/watchlink/WatchLinkTypes';
import { WearPersonas } from '../main/ets/wear/WearPersonas';
import { benefitLevel, benefitReason } from '../main/ets/report/Benefit';
import {
  DayDetail,
  ENGINE_DEFAULT_ID,
  ENGINE_SOURCE,
  engineDayDetails,
  enginePersonas,
  engineReport,
  engineReportOf,
  engineReports,
  engineSession,
  engineWhatIf,
  EngineWhatIf,
  nextTierOf,
  reportComponentId
} from '../main/ets/report/EngineReports';
import { PARTNER_HES_PROFILE } from '../main/ets/report/PartnerProgram';
import { previewPersonas, previewReport } from '../main/ets/report/PreviewReports';
import {
  BAR_NO_DATA,
  BenefitLevel,
  ComponentId,
  ComponentRow,
  DayState,
  hasScore,
  HES_NONE,
  LIVE_NONE,
  PersonaReport,
  POINTS_UNKNOWN,
  ReportConfidence,
  ReportTier
} from '../main/ets/report/ReportModels';

const IDS: string[] = ['ania', 'marek', 'kasia', 'tomek', 'ewa', 'ola'];
const HW = HesProfile.HEALTH_WELLNESS;
const LW = HesProfile.LONGEVITY_WELLNESS;
const EPS = 1e-9;
const ONE_DECIMAL = 0.05;
const TODAY = '2026-10-04';
const LAST_DAY = '2026-10-03';
const NA = -1;  // "no value" in the golden tables below
// The report lists the components in this order.
const REPORT_ORDER: string[] = [
  ComponentId.STEPS,
  ComponentId.ACTIVE_MINUTES,
  ComponentId.RESTING_HR,
  ComponentId.SLEEP,
  ComponentId.SLEEP_REGULARITY,
  ComponentId.VO2MAX,
  ComponentId.HRV,
  ComponentId.HR_RECOVERY
];
// The golden tables list the components in the model's order.
const MODEL_ORDER: string[] = [
  ComponentId.VO2MAX,
  ComponentId.RESTING_HR,
  ComponentId.ACTIVE_MINUTES,
  ComponentId.STEPS,
  ComponentId.SLEEP_REGULARITY,
  ComponentId.SLEEP,
  ComponentId.HRV,
  ComponentId.HR_RECOVERY
];
const DAY_STATES: string[] = [DayState.COMPLIANT, DayState.SHORT, DayState.SUSPICIOUS, DayState.SICK,
  DayState.UNKNOWN];
// Wording that is not allowed in user text, and promise wording.
const FORBIDDEN: string[] = ['risk', 'validated', 'healthy', ' ai ', 'predict', 'guarantee', ' will ', 'disease'];

// The expected result of one persona in a profile (the specification's table). The partner's profile is the
// default one.
function expectPersona(id: string, profile: HesProfile, hes: number, tier: string, coverage: number,
  confidence: string): void {
  const r: PersonaReport = engineReport(id, profile);
  expect(r.id).assertEqual(id);
  expect(r.profile).assertEqual(profile);
  expect(r.hes).assertEqual(hes);
  expect(r.tier).assertEqual(tier);
  expect(r.coveragePct).assertEqual(coverage);
  expect(r.confidence).assertEqual(confidence);
}

function component(r: PersonaReport, id: string): ComponentRow {
  for (let i = 0; i < r.components.length; i++) {
    if (r.components[i].id === id) {
      return r.components[i];
    }
  }
  throw new Error('component not in the report');
}

function engineComponent(result: HesResult, id: HesComponentId): ComponentResult {
  for (let i = 0; i < result.components.length; i++) {
    if (result.components[i].id === id) {
      return result.components[i];
    }
  }
  throw new Error('component not in the result');
}

function engineComponentOfRow(result: HesResult, rowId: string): ComponentResult {
  for (let i = 0; i < result.components.length; i++) {
    if (reportComponentId(result.components[i].id) === rowId) {
      return result.components[i];
    }
  }
  throw new Error('component not in the result');
}

function countDays(r: PersonaReport, state: string): number {
  let n = 0;
  for (let i = 0; i < r.wear.days.length; i++) {
    if (r.wear.days[i].state === state) {
      n++;
    }
  }
  return n;
}

function countBars(row: ComponentRow): number {
  let n = 0;
  for (let i = 0; i < row.bars7.length; i++) {
    if (row.bars7[i] >= 0) {
      n++;
    }
  }
  return n;
}

function score(id: HesComponentId, x: number): number {
  const s = piecewise(hesComponentDefinition(id).curve, x);
  if (s === undefined) {
    throw new Error('no score');
  }
  return s;
}

function session(id: string): HesSession {
  return HesPersonas.session(id, TODAY);
}

// Everything of a report except the live readings, as one text.
function withoutLive(r: PersonaReport): string {
  const copy: PersonaReport = {
    id: r.id,
    name: r.name,
    period: r.period,
    periodIso: r.periodIso,
    profile: r.profile,
    profileLabel: r.profileLabel,
    partnerProfile: r.partnerProfile,
    hes: r.hes,
    tier: r.tier,
    coveragePct: r.coveragePct,
    coverageText: r.coverageText,
    confidence: r.confidence,
    showWeights: r.showWeights,
    eligible: r.eligible,
    benefit: r.benefit,
    benefitReason: r.benefitReason,
    pointsToNext: r.pointsToNext,
    components: r.components,
    wear: r.wear,
    live: { hr: LIVE_NONE, steps: LIVE_NONE },
    whatIf: r.whatIf
  };
  return JSON.stringify(copy);
}

function copyComponent(c: ComponentResult): ComponentResult {
  const out: ComponentResult = {
    id: c.id,
    label: c.label,
    available: c.available,
    requiredCore: c.requiredCore,
    validCount: c.validCount,
    minimumCount: c.minimumCount,
    targetCount: c.targetCount,
    quality: c.quality,
    baseWeight: c.baseWeight,
    baseWeightPermille: c.baseWeightPermille
  };
  if (c.rawValue !== undefined) {
    out.rawValue = c.rawValue;
  }
  if (c.score !== undefined) {
    out.score = c.score;
  }
  return out;
}

// The engine result when one component has another value: calculated here from the engine's own pieces,
// not taken from the report.
function resultWithChange(result: HesResult, id: HesComponentId, toRaw: number): HesResult {
  const components: ComponentResult[] = [];
  for (let i = 0; i < result.components.length; i++) {
    const c = copyComponent(result.components[i]);
    if (c.id === id) {
      c.rawValue = toRaw;
      c.score = score(id, toRaw);
    }
    components.push(c);
  }
  return composeComponents(result.profile, components);
}

function whatIfOf(id: string, profile: HesProfile): EngineWhatIf {
  const change = engineWhatIf(HesPersonas.result(id, profile, TODAY));
  if (change === null) {
    throw new Error('no counterfactual');
  }
  return change;
}

function dateAgo(daysAgo: number): string {
  return dateOfDayNumber(dayNumberOfDate(LAST_DAY) - daysAgo);
}

// 28 identical completed days: the same steps, resting heart rate, activity and night every day. The
// night's clock times never move, so the timing SD is 0.
function steadyHistory(steps: number, rhr: number, moderate: number, bedMin: number, wakeMin: number,
  sleepMinutes: number): HesHistory {
  const days: HesDayRecord[] = [];
  for (let i = 27; i >= 0; i--) {
    days.push({
      date: dateAgo(i),
      steps: steps,
      moderateMin: moderate,
      vigorousMin: 0,
      restingHr: rhr,
      sleep: { bedMin: bedMin, wakeMin: wakeMin, totalSleepMin: sleepMinutes }
    });
  }
  return { days: days, crf: [], hrr: [] };
}

// The golden component scores, in the model's order (crf, rhr, mvpa, steps, sleep regularity, sleep duration,
// hrv, hrr). NA when the component is not available. The scores are the same in both profiles.
function expectScores(id: string, profile: HesProfile, scores: number[]): void {
  const r = engineReport(id, profile);
  for (let i = 0; i < MODEL_ORDER.length; i++) {
    const row = component(r, MODEL_ORDER[i]);
    if (scores[i] === NA) {
      expect(row.available).assertFalse();
      expect(row.scoreExact).assertEqual(HES_NONE);
    } else {
      expect(row.available).assertTrue();
      expect(row.scoreExact).assertClose(scores[i], ONE_DECIMAL);
      expect(row.score).assertEqual(hesRound(row.scoreExact));
    }
  }
}

// The golden effective weights of the available components in percent, in the model's order. NA = not available.
function expectWeights(id: string, weights: number[]): void {
  const r = engineReport(id, HW);
  for (let i = 0; i < MODEL_ORDER.length; i++) {
    const row = component(r, MODEL_ORDER[i]);
    if (weights[i] === NA) {
      expect(row.weightPct).assertEqual(0);
      expect(row.weightText).assertEqual('');
    } else {
      expect(row.weightPct).assertClose(weights[i], EPS);
    }
  }
}

export default function engineReportsTest() {
  describe('Engine reports: the fixed results', () => {
    it('the six personas equal the golden table in the partner profile (Health & wellness)', 0, () => {
      expect(PARTNER_HES_PROFILE).assertEqual(HW);
      expect(engineReports().length).assertEqual(6);
      expectPersona('ania', HW, 92, ReportTier.A, 100, ReportConfidence.HIGH);
      expectPersona('marek', HW, 75, ReportTier.B, 87.5, ReportConfidence.HIGH);
      expectPersona('kasia', HW, 73, ReportTier.B, 75, ReportConfidence.MEDIUM);
      expectPersona('tomek', HW, 79, ReportTier.B, 92.5, ReportConfidence.HIGH);
      expectPersona('ewa', HW, 59, ReportTier.C, 80, ReportConfidence.MEDIUM);
      expectPersona('ola', HW, HES_NONE, ReportTier.NONE, 47.5, ReportConfidence.INSUFFICIENT);
      expect(ReportConfidence.INSUFFICIENT).assertEqual('Not enough data');
      expect(hasScore(engineReport('ola'))).assertFalse();
      expect(hasScore(engineReport('ewa'))).assertTrue();
      // Without a profile the report is in the partner's profile.
      for (let i = 0; i < IDS.length; i++) {
        expect(engineReport(IDS[i])).assertDeepEquals(engineReport(IDS[i], HW));
      }
    });

    it('the six personas equal the golden table in the Longevity profile', 0, () => {
      expect(engineReports(LW).length).assertEqual(6);
      expectPersona('ania', LW, 92, ReportTier.A, 100, ReportConfidence.HIGH);
      expectPersona('marek', LW, 76, ReportTier.B, 77.5, ReportConfidence.MEDIUM);
      expectPersona('kasia', LW, 74, ReportTier.B, 65, ReportConfidence.LOW);
      expectPersona('tomek', LW, 79, ReportTier.B, 92.5, ReportConfidence.HIGH);
      expectPersona('ewa', LW, 59, ReportTier.C, 70, ReportConfidence.MEDIUM);
      expectPersona('ola', LW, HES_NONE, ReportTier.NONE, 47.5, ReportConfidence.INSUFFICIENT);
    });

    it('eligibility and benefit are always the partner profile\'s, whichever profile the report shows', 0, () => {
      const expected: string[] = [BenefitLevel.FULL, BenefitLevel.NONE, BenefitLevel.PARTIAL, BenefitLevel.PARTIAL,
        BenefitLevel.NONE, BenefitLevel.NONE];
      const eligible: boolean[] = [true, false, true, true, true, false];
      for (let i = 0; i < IDS.length; i++) {
        const hw = engineReport(IDS[i], HW);
        const lw = engineReport(IDS[i], LW);
        expect(hw.benefit).assertEqual(expected[i]);
        expect(lw.benefit).assertEqual(expected[i]);
        expect(hw.eligible).assertEqual(eligible[i]);
        expect(lw.eligible).assertEqual(eligible[i]);
        expect(lw.benefitReason).assertEqual(hw.benefitReason);
        // The wear month does not depend on the profile either.
        expect(lw.wear).assertDeepEquals(hw.wear);
      }
    });

    it('profile fields: label, partner flag and whether the weights differ from the model', 0, () => {
      const hw = engineReport('marek', HW);
      const lw = engineReport('marek', LW);
      expect(hw.profileLabel).assertEqual('Health & wellness');
      expect(hw.partnerProfile).assertTrue();
      expect(lw.profileLabel).assertEqual('Longevity');
      expect(lw.partnerProfile).assertFalse();
      expect(hw.coverageText).assertEqual('87.5%');
      expect(lw.coverageText).assertEqual('77.5%');
      expect(engineReport('kasia', HW).coverageText).assertEqual('75%');
      expect(engineReport('ania', HW).coverageText).assertEqual('100%');
      // Full coverage: the effective weights are the model's weights, so there is nothing to explain.
      expect(engineReport('ania', HW).showWeights).assertFalse();
      expect(engineReport('ania', LW).showWeights).assertFalse();
      expect(hw.showWeights).assertTrue();
      expect(lw.showWeights).assertTrue();
      // No score: no weights.
      expect(engineReport('ola', HW).showWeights).assertFalse();
    });

    it('engine and preview agree on score, tier, coverage, confidence, benefit and eligible', 0, () => {
      for (let i = 0; i < IDS.length; i++) {
        const engine = engineReport(IDS[i]);
        const preview = previewReport(IDS[i]);
        expect(engine.id).assertEqual(preview.id);
        expect(engine.hes).assertEqual(preview.hes);
        expect(engine.tier).assertEqual(preview.tier);
        expect(engine.coveragePct).assertEqual(preview.coveragePct);
        expect(engine.coverageText).assertEqual(preview.coverageText);
        expect(engine.confidence).assertEqual(preview.confidence);
        expect(engine.benefit).assertEqual(preview.benefit);
        expect(engine.eligible).assertEqual(preview.eligible);
      }
    });

    it('the persona list has the ids, names and order of the preview', 0, () => {
      const engine = enginePersonas();
      const preview = previewPersonas();
      expect(engine.length).assertEqual(6);
      expect(engine.length).assertEqual(preview.length);
      for (let i = 0; i < engine.length; i++) {
        expect(engine[i].id).assertEqual(preview[i].id);
        expect(engine[i].name).assertEqual(preview[i].name);
        expect(engineReports()[i].id).assertEqual(engine[i].id);
        expect(engineReports()[i].name).assertEqual(engine[i].name);
      }
      expect(engine[0].id).assertEqual(ENGINE_DEFAULT_ID);
    });

    it('an unknown id gives the default persona and never throws', 0, () => {
      expect(engineReport('nobody').id).assertEqual(ENGINE_DEFAULT_ID);
      expect(engineReport('').id).assertEqual(ENGINE_DEFAULT_ID);
      expect(engineReport('nobody', LW)).assertDeepEquals(engineReport(ENGINE_DEFAULT_ID, LW));
      const s = engineSession('nobody');
      expect(engineReportOf('nobody', s)).assertDeepEquals(engineReport(ENGINE_DEFAULT_ID));
    });

    it('benefit and its reason are the ones the benefit rule gives', 0, () => {
      const all = engineReports();
      for (let i = 0; i < all.length; i++) {
        const r = all[i];
        expect(r.benefit).assertEqual(benefitLevel(r.eligible, r.tier, hasScore(r)));
        expect(r.benefitReason).assertEqual(benefitReason(r.eligible, r.tier, hasScore(r), r.wear.flagged,
          r.wear.suspicious));
      }
      expect(engineReport('ania').benefitReason).assertEqual('Eligible');
      expect(engineReport('marek').benefitReason).assertEqual('3 suspicious breaks');
      expect(engineReport('kasia').benefitReason).assertEqual('Score B');
      expect(engineReport('ewa').benefitReason).assertEqual('Score C');
      expect(engineReport('ola').benefitReason).assertEqual('Not enough data yet');
    });

    it('points to the next tier: 0 in tier A, the engine\'s distance below it, unknown without a score', 0, () => {
      expect(engineReport('ania').pointsToNext).assertEqual(0);
      expect(engineReport('marek').pointsToNext).assertEqual(5);
      expect(engineReport('kasia').pointsToNext).assertEqual(7);
      expect(engineReport('tomek').pointsToNext).assertEqual(1);
      expect(engineReport('ewa').pointsToNext).assertEqual(1);       // to B
      expect(engineReport('ola').pointsToNext).assertEqual(POINTS_UNKNOWN);
      // Longevity: 80 - 76, 80 - 74, 80 - 79, 60 - 59.
      expect(engineReport('marek', LW).pointsToNext).assertEqual(4);
      expect(engineReport('kasia', LW).pointsToNext).assertEqual(6);
      expect(engineReport('tomek', LW).pointsToNext).assertEqual(1);
      expect(engineReport('ewa', LW).pointsToNext).assertEqual(1);
      expect(engineReport('ola', LW).pointsToNext).assertEqual(POINTS_UNKNOWN);
      for (let p = 0; p < HES_PROFILES.length; p++) {
        for (let i = 0; i < IDS.length; i++) {
          const r = engineReport(IDS[i], HES_PROFILES[p]);
          const points = pointsToNextTier(HesPersonas.result(IDS[i], HES_PROFILES[p], TODAY));
          if (hasScore(r)) {
            // Tier A has no next tier in the engine: the report says 0 there, never "unknown".
            expect(r.pointsToNext).assertEqual(points === undefined ? 0 : points);
          }
        }
      }
      expect(pointsToNextTier(HesPersonas.result('ania', HW, TODAY))).assertUndefined();
      expect(nextTierOf(ReportTier.B)).assertEqual(ReportTier.A);
      expect(nextTierOf(ReportTier.C)).assertEqual(ReportTier.B);
      expect(nextTierOf(ReportTier.A)).assertEqual('');
      expect(nextTierOf(ReportTier.NONE)).assertEqual('');
    });
  });

  describe('Engine reports: components', () => {
    it('eight components in the report order, with the engine scores, counts and weights', 0, () => {
      for (let p = 0; p < HES_PROFILES.length; p++) {
        for (let i = 0; i < IDS.length; i++) {
          const r = engineReport(IDS[i], HES_PROFILES[p]);
          const result = HesPersonas.result(IDS[i], HES_PROFILES[p], TODAY);
          expect(r.components.length).assertEqual(8);
          for (let c = 0; c < r.components.length; c++) {
            const row = r.components[c];
            const source = engineComponentOfRow(result, row.id);
            expect(row.id).assertEqual(REPORT_ORDER[c]);
            expect(row.label).assertEqual(source.label);
            expect(row.available).assertEqual(source.available);
            expect(row.core).assertEqual(source.requiredCore);
            expect(row.validCount).assertEqual(source.validCount);
            expect(row.needCount).assertEqual(source.minimumCount);
            expect(row.targetCount).assertEqual(source.targetCount);
            expect(row.bars7.length).assertEqual(7);
            if (row.available && source.score !== undefined) {
              expect(row.scoreExact).assertEqual(source.score);
              expect(row.score).assertEqual(hesRound(source.score));
              expect(row.score >= 0 && row.score <= 100).assertTrue();
              expect(row.source).assertEqual(ENGINE_SOURCE);
            }
            const weight = source.effectiveWeight;
            if (row.available && hasScore(r) && weight !== undefined) {
              expect(Math.abs(row.weightPct - weight * 100) <= 0.05 + EPS).assertTrue();
            }
          }
        }
      }
      expect(ENGINE_SOURCE).assertEqual('HUAWEI Health · Demo data');
    });

    it('component scores equal the golden table (both profiles; "not available" where the table has a dash)', 0, () => {
      for (let p = 0; p < HES_PROFILES.length; p++) {
        const profile = HES_PROFILES[p];
        expectScores('ania', profile, [89.2, 97, 93.2, 97, 90, 99, 81, 74]);
        expectScores('marek', profile, [NA, 86.4, 67.6, 82, 73.33, 84.6, 65, 55]);
        expectScores('kasia', profile, [NA, 80.8, 59, 80, 73.33, 78.6, NA, NA]);
        expectScores('tomek', profile, [70, 93, 78.8, 90, 66.67, 82, NA, 62.5]);
        expectScores('ewa', profile, [NA, 74, 45, 56, 63.33, 71.8, NA, 38.33]);
        expectScores('ola', profile, [NA, 86.4, 64.8, 88, NA, NA, NA, NA]);
      }
    });

    it('effective weights equal the golden table; Ania carries the model\'s base weights', 0, () => {
      // crf, rhr, mvpa, steps, sleep regularity, sleep duration, hrv, hrr
      expectWeights('ania', [12.5, 12.5, 20, 15, 15, 12.5, 7.5, 5]);
      expectWeights('marek', [NA, 14.3, 22.9, 17.1, 17.1, 14.3, 8.6, 5.7]);
      expectWeights('kasia', [NA, 16.7, 26.7, 20, 20, 16.7, NA, NA]);
      expectWeights('tomek', [13.5, 13.5, 21.6, 16.2, 16.2, 13.5, NA, 5.4]);
      expectWeights('ewa', [NA, 15.6, 25, 18.8, 18.8, 15.6, NA, 6.3]);
      expect(component(engineReport('ewa'), ComponentId.STEPS).weightText).assertEqual('18.8%');
      expect(component(engineReport('ania'), ComponentId.STEPS).weightText).assertEqual('15.0%');
      expect(component(engineReport('marek'), ComponentId.SLEEP).weightText).assertEqual('14.3%');
    });

    it('weights of the available components add up to 100 (±0.5); without a score nothing is weighed', 0, () => {
      for (let p = 0; p < HES_PROFILES.length; p++) {
        const all = engineReports(HES_PROFILES[p]);
        for (let i = 0; i < all.length; i++) {
          let sum = 0;
          for (let c = 0; c < all[i].components.length; c++) {
            const row = all[i].components[c];
            if (hasScore(all[i]) && row.available) {
              sum += row.weightPct;
            } else {
              expect(row.weightPct).assertEqual(0);
              expect(row.weightText).assertEqual('');
            }
          }
          if (hasScore(all[i])) {
            expect(Math.abs(sum - 100) <= 0.5).assertTrue();
          } else {
            expect(sum).assertEqual(0);
          }
        }
      }
    });

    it('component scores weighted by their weights give the score (±0.5 plus the rounding of the weights)', 0, () => {
      const all = engineReports();
      for (let i = 0; i < all.length; i++) {
        if (!hasScore(all[i])) {
          continue;
        }
        let weighted = 0;
        for (let c = 0; c < all[i].components.length; c++) {
          const row = all[i].components[c];
          if (row.available) {
            weighted += row.scoreExact * row.weightPct / 100;
          }
        }
        expect(Math.abs(weighted - all[i].hes) <= 0.6).assertTrue();
      }
    });

    it('a component that is not available has no value, score, weight or bar, and carries its counts', 0, () => {
      let unavailable = 0;
      for (let i = 0; i < IDS.length; i++) {
        const r = engineReport(IDS[i]);
        const result = HesPersonas.result(IDS[i], HW, TODAY);
        for (let c = 0; c < r.components.length; c++) {
          const row = r.components[c];
          const source = engineComponentOfRow(result, row.id);
          if (row.available) {
            expect(row.raw.length > 0).assertTrue();
            expect(row.unit.length > 0).assertTrue();
            expect(row.rawText.length > 0).assertTrue();
            expect(row.countText.length > 0).assertTrue();
            expect(row.validCount >= row.needCount).assertTrue();
            continue;
          }
          unavailable++;
          expect(row.score).assertEqual(HES_NONE);
          expect(row.scoreExact).assertEqual(HES_NONE);
          expect(row.raw).assertEqual('');
          expect(row.unit).assertEqual('');
          expect(row.rawText).assertEqual('');
          expect(row.weightPct).assertEqual(0);
          expect(row.weightText).assertEqual('');
          expect(row.source).assertEqual('');
          expect(countBars(row)).assertEqual(0);
          expect(row.validCount).assertEqual(source.validCount);
          expect(row.validCount < row.needCount).assertTrue();
          if (source.requiredCore) {
            // A Core component: "X of Y", with X below Y.
            expect(row.minCount).assertEqual(source.minimumCount);
            expect(row.minCount > 0).assertTrue();
          } else {
            // The score does not require it.
            expect(row.minCount).assertEqual(0);
          }
        }
      }
      // crf 0 (Marek, Kasia, Ewa, Ola), hrv (Kasia, Tomek, Ewa, Ola), hrr (Kasia, Ola), Ola's two sleep
      // components: 1 + 3 + 1 + 2 + 5 = 12 over the six personas.
      expect(unavailable).assertEqual(12);
    });

    it('Ola: what she measured, what the score still needs, and how far each component is', 0, () => {
      const ola = engineReport('ola');
      expect(component(ola, ComponentId.SLEEP).validCount).assertEqual(6);
      expect(component(ola, ComponentId.SLEEP).minCount).assertEqual(14);
      expect(component(ola, ComponentId.SLEEP).countText).assertEqual('6 of 14 nights');
      expect(component(ola, ComponentId.SLEEP_REGULARITY).validCount).assertEqual(6);
      expect(component(ola, ComponentId.SLEEP_REGULARITY).minCount).assertEqual(14);
      expect(component(ola, ComponentId.SLEEP_REGULARITY).countText).assertEqual('6 of 14 nights');
      expect(component(ola, ComponentId.HRV).countText).assertEqual('6 of 7 nights');
      expect(component(ola, ComponentId.HRV).minCount).assertEqual(0);
      expect(component(ola, ComponentId.HRV).needCount).assertEqual(7);
      expect(component(ola, ComponentId.HR_RECOVERY).countText).assertEqual('0 of 2 sessions');
      expect(component(ola, ComponentId.VO2MAX).countText).assertEqual('0 of 1');
      expect(component(ola, ComponentId.STEPS).available).assertTrue();
      expect(component(ola, ComponentId.STEPS).validCount).assertEqual(16);
      expect(component(ola, ComponentId.STEPS).minCount).assertEqual(14);
      expect(component(ola, ComponentId.RESTING_HR).validCount).assertEqual(16);
      expect(component(ola, ComponentId.RESTING_HR).minCount).assertEqual(10);
      expect(component(ola, ComponentId.ACTIVE_MINUTES).validCount).assertEqual(16);
      expect(component(engineReport('tomek'), ComponentId.HRV).available).assertFalse();
      expect(component(engineReport('ania'), ComponentId.HRV).available).assertTrue();
    });

    it('raw values are the engine values, written with their units', 0, () => {
      const tomek = engineReport('tomek');
      expect(component(tomek, ComponentId.STEPS).raw).assertEqual('7,000');
      expect(component(tomek, ComponentId.STEPS).unit).assertEqual('/day');
      expect(component(tomek, ComponentId.STEPS).rawText).assertEqual('7,000/day');
      expect(component(tomek, ComponentId.ACTIVE_MINUTES).raw).assertEqual('147');
      expect(component(tomek, ComponentId.ACTIVE_MINUTES).unit).assertEqual('min/week');
      expect(component(tomek, ComponentId.RESTING_HR).raw).assertEqual('62');
      expect(component(tomek, ComponentId.RESTING_HR).unit).assertEqual('bpm');
      expect(component(tomek, ComponentId.SLEEP).raw).assertEqual('6 h 30');
      expect(component(tomek, ComponentId.SLEEP).unit).assertEqual('min');
      expect(component(tomek, ComponentId.SLEEP).rawText).assertEqual('6 h 30 min');
      expect(component(tomek, ComponentId.SLEEP_REGULARITY).raw).assertEqual('±80');
      expect(component(tomek, ComponentId.SLEEP_REGULARITY).unit).assertEqual('min');
      expect(component(tomek, ComponentId.VO2MAX).raw).assertEqual('50th');
      expect(component(tomek, ComponentId.VO2MAX).unit).assertEqual('percentile');
      expect(component(tomek, ComponentId.VO2MAX).rawText).assertEqual('50th percentile (age & sex)');
      expect(component(tomek, ComponentId.HR_RECOVERY).raw).assertEqual('27');
      expect(component(tomek, ComponentId.HR_RECOVERY).unit).assertEqual('bpm in 60 s');
      const ania = engineReport('ania');
      expect(component(ania, ComponentId.STEPS).rawText).assertEqual('8,800/day');
      expect(component(ania, ComponentId.ACTIVE_MINUTES).rawText).assertEqual('238 min/week (vigorous counts ×2)');
      expect(component(ania, ComponentId.RESTING_HR).rawText).assertEqual('58 bpm');
      expect(component(ania, ComponentId.SLEEP).rawText).assertEqual('7 h 24 min');
      expect(component(ania, ComponentId.SLEEP_REGULARITY).rawText).assertEqual('±45 min');
      expect(component(ania, ComponentId.VO2MAX).rawText).assertEqual('77th percentile (age & sex)');
      expect(component(ania, ComponentId.HRV).raw).assertEqual('60th');
      expect(component(ania, ComponentId.HRV).unit).assertEqual('percentile');
      expect(component(ania, ComponentId.HR_RECOVERY).rawText).assertEqual('32 bpm drop in 60 s');
      // The numbers behind the text are the engine's.
      const result = HesPersonas.result('tomek', HW, TODAY);
      expect(engineComponent(result, HesComponentId.STEPS).rawValue).assertEqual(7000);
      const sleepHours = engineComponent(result, HesComponentId.SLEEP_DURATION).rawValue;
      expect(sleepHours).assertClose(6.5, EPS);
      expect(engineComponent(result, HesComponentId.CRF).rawValue).assertEqual(50);
    });

    it('seven-day bars: each of the last seven days on the component curve; no data is not a zero', 0, () => {
      for (let i = 0; i < IDS.length; i++) {
        const r = engineReport(IDS[i]);
        const history = HesPersonas.history(IDS[i], TODAY);
        const steps = component(r, ComponentId.STEPS);
        const rhr = component(r, ComponentId.RESTING_HR);
        for (let b = 0; b < 7; b++) {
          const day = history.days[history.days.length - 7 + b];
          const dayRhr = day.restingHr;
          const daySteps = day.steps;
          if (daySteps === undefined) {
            expect(steps.bars7[b]).assertEqual(BAR_NO_DATA);
          } else {
            expect(steps.bars7[b]).assertEqual(hesRound(score(HesComponentId.STEPS, daySteps)));
          }
          if (dayRhr === undefined) {
            expect(rhr.bars7[b]).assertEqual(BAR_NO_DATA);
          } else {
            expect(rhr.bars7[b]).assertEqual(hesRound(score(HesComponentId.RHR, dayRhr)));
          }
        }
        for (let c = 0; c < r.components.length; c++) {
          for (let b = 0; b < 7; b++) {
            const bar = r.components[c].bars7[b];
            expect(bar === BAR_NO_DATA || (bar >= 0 && bar <= 100)).assertTrue();
          }
        }
      }
      // Ania: steps swing 8200 / 9400 (99 and 96), the last day has the higher value.
      const ania = engineReport('ania');
      expect(component(ania, ComponentId.STEPS).bars7[6]).assertEqual(99);
      expect(component(ania, ComponentId.STEPS).bars7[5]).assertEqual(96);
      // Her heart-rate recovery session was four days before the last completed day: one bar, on the curve.
      expect(countBars(component(ania, ComponentId.HR_RECOVERY))).assertEqual(1);
      expect(component(ania, ComponentId.HR_RECOVERY).bars7[2]).assertEqual(74);
      // Her VO2max estimate is twelve days old: the component is available, but no bar lies in the last seven days.
      expect(component(ania, ComponentId.VO2MAX).available).assertTrue();
      expect(countBars(component(ania, ComponentId.VO2MAX))).assertEqual(0);
      expect(countBars(component(ania, ComponentId.SLEEP_REGULARITY))).assertEqual(7);
      // Tomek's estimate five days before the last day is the third bar of the last seven (day index 24 of 28).
      expect(component(engineReport('tomek'), ComponentId.VO2MAX).bars7[1]).assertEqual(70);
      expect(countBars(component(engineReport('tomek'), ComponentId.VO2MAX))).assertEqual(1);
    });

    it('a day without a reading inside the last seven has no bar, and the other days keep theirs', 0, () => {
      const snapshot = HesPersonas.snapshot('tomek', TODAY);
      const days = snapshot.history.days;
      days[24].steps = undefined;       // the fourth of the last seven days
      days[24].restingHr = undefined;
      const s = new HesSession(snapshot);
      const r = engineReportOf('tomek', s);
      const steps = component(r, ComponentId.STEPS);
      const rhr = component(r, ComponentId.RESTING_HR);
      expect(steps.bars7[3]).assertEqual(BAR_NO_DATA);
      expect(rhr.bars7[3]).assertEqual(BAR_NO_DATA);
      expect(countBars(steps)).assertEqual(6);
      expect(countBars(rhr)).assertEqual(6);
      expect(steps.validCount).assertEqual(27);
      // The component itself is still available and the day was not counted as a zero.
      expect(steps.available).assertTrue();
      // Mean of the 27 remaining days: (28 x 7000 - 7600) / 27 = 7022.2 (day 24 of the pattern is 7000 + 600).
      expect(steps.raw).assertEqual('7,022');
    });
  });

  describe('Engine reports: wear month', () => {
    it('Marek: flagged, 3 suspicious breaks, 4 red days; Kasia: 1 suspicious break and no flag', 0, () => {
      const marek = engineReport('marek');
      expect(marek.wear.flagged).assertTrue();
      expect(marek.wear.suspicious).assertEqual(3);
      expect(marek.wear.totalDays - marek.wear.compliantDays).assertEqual(4);
      expect(countDays(marek, DayState.SUSPICIOUS) + countDays(marek, DayState.SHORT)).assertEqual(4);
      expect(countDays(marek, DayState.SUSPICIOUS)).assertEqual(3);
      expect(marek.eligible).assertFalse();
      const kasia = engineReport('kasia');
      expect(kasia.wear.suspicious).assertEqual(1);
      expect(kasia.wear.flagged).assertFalse();
      expect(countDays(kasia, DayState.SUSPICIOUS)).assertEqual(1);
      expect(kasia.eligible).assertTrue();
      // The same wear compliance: only the flag separates them.
      expect(kasia.wear.compliantDays).assertEqual(marek.wear.compliantDays);
      expect(marek.wear.compliantDays).assertEqual(26);
      // 17 September is the 14th day of the period.
      expect(marek.wear.days[13].state).assertEqual(DayState.SUSPICIOUS);
    });

    it('thirty day cells, each with a known state, and the summary of the wear month', 0, () => {
      for (let i = 0; i < IDS.length; i++) {
        const r = engineReport(IDS[i]);
        const month = WearPersonas.result(IDS[i]);
        expect(r.wear.days.length).assertEqual(30);
        expect(r.wear.totalDays).assertEqual(30);
        expect(r.wear.compliantDays).assertEqual(month.compliantDays);
        expect(r.wear.nightsWorn).assertEqual(month.nightsWorn);
        expect(r.wear.suspicious).assertEqual(month.suspiciousBreaks);
        expect(r.wear.flagged).assertEqual(month.flagged);
        for (let d = 0; d < r.wear.days.length; d++) {
          const cell = r.wear.days[d];
          expect(cell.n).assertEqual(d + 1);
          expect(DAY_STATES.indexOf(cell.state) >= 0).assertTrue();
          expect(cell.state).assertEqual(month.days[d].state as string);
          expect(cell.wornPct >= 0 && cell.wornPct <= 100).assertTrue();
          expect(cell.wornPct).assertEqual(hesRound(month.days[d].wornMin * 100 / 1440));
        }
        const notCompliant = countDays(r, DayState.SHORT) + countDays(r, DayState.SUSPICIOUS) +
          countDays(r, DayState.UNKNOWN);
        expect(r.wear.compliantDays).assertEqual(30 - notCompliant);
        expect(r.wear.suspicious).assertEqual(countDays(r, DayState.SUSPICIOUS));
        // Eligible needs the wear month and a score in the partner's profile.
        expect(r.eligible).assertEqual(month.eligible && hasScore(r));
      }
      expect(engineReport('ania').wear.compliantDays).assertEqual(30);
      expect(engineReport('tomek').wear.compliantDays).assertEqual(29);
      expect(engineReport('ewa').wear.compliantDays).assertEqual(27);
      const ola = engineReport('ola');
      expect(ola.wear.compliantDays).assertEqual(8);
      expect(ola.wear.nightsWorn).assertEqual(8);
      expect(countDays(ola, DayState.UNKNOWN)).assertEqual(6);
      expect(ola.wear.days[0].state).assertEqual(DayState.UNKNOWN);
    });

    it('the period is the wear month, as read on screen and as the claim accepts it', 0, () => {
      for (let i = 0; i < IDS.length; i++) {
        const r = engineReport(IDS[i]);
        expect(r.period).assertEqual('4 Sep – 3 Oct');
        expect(r.periodIso).assertEqual('2026-09-04..2026-10-03');
        expect(r.periodIso).assertEqual(previewReport(IDS[i]).periodIso);
      }
      const r = engineReport('tomek');
      const issuedAt = 1791000000000;
      const json = encodeTierClaim(buildTierClaim(r.periodIso, r.tier, r.eligible, 'AAAAAAAAAAAAAAAAAAAAAA',
        issuedAt, '0a1b2c3d'));
      expect(validateTierClaimJson(json, issuedAt) !== null).assertTrue();
    });
  });

  describe('Engine reports: live values and the session', () => {
    it('a new session gives the persona report: today\'s steps from the source, no live heart rate', 0, () => {
      const steps: number[] = [8800, 6200, 6000, 7000, 4400, 6800];
      for (let i = 0; i < IDS.length; i++) {
        const s = engineSession(IDS[i]);
        const r = engineReportOf(IDS[i], s);
        expect(r).assertDeepEquals(engineReport(IDS[i]));
        expect(r.live.hr).assertEqual(LIVE_NONE);
        expect(r.live.steps).assertEqual(steps[i]);
      }
    });

    it('live heart rate 200 and 99999 steps change `live` and nothing else, in both profiles', 0, () => {
      for (let p = 0; p < HES_PROFILES.length; p++) {
        for (let i = 0; i < IDS.length; i++) {
          const s = engineSession(IDS[i]);
          const before = engineReportOf(IDS[i], s, HES_PROFILES[p]);
          s.setLive(200, 99999);
          const after = engineReportOf(IDS[i], s, HES_PROFILES[p]);
          expect(after.live.hr).assertEqual(200);
          expect(after.live.steps).assertEqual(99999);
          expect(withoutLive(after)).assertEqual(withoutLive(before));
          expect(after.hes).assertEqual(before.hes);
          expect(after.tier).assertEqual(before.tier);
          expect(after.components).assertDeepEquals(before.components);
          expect(after.wear).assertDeepEquals(before.wear);
          expect(after.whatIf).assertEqual(before.whatIf);
        }
      }
    });

    it('no live reading is LIVE_NONE, never zero; zero steps is a reading; an invalid count falls back to the source', 0, () => {
      const s = engineSession('tomek');
      s.setLive(0, -5);
      expect(engineReportOf('tomek', s).live.hr).assertEqual(LIVE_NONE);
      expect(engineReportOf('tomek', s).live.steps).assertEqual(7000);   // the source's steps for today
      s.setLive(72, 0);
      expect(engineReportOf('tomek', s).live.hr).assertEqual(72);
      expect(engineReportOf('tomek', s).live.steps).assertEqual(0);
      s.setLive(undefined, undefined);
      expect(engineReportOf('tomek', s).live.hr).assertEqual(LIVE_NONE);
      expect(engineReportOf('tomek', s).live.steps).assertEqual(7000);
      // A day in which the source has no steps at all: no reading, not zero.
      const snapshot = HesPersonas.snapshot('tomek', TODAY);
      snapshot.today.steps = undefined;
      expect(engineReportOf('tomek', new HesSession(snapshot)).live.steps).assertEqual(LIVE_NONE);
    });

    it('closing the day: the report follows the session, the live steps enter the history', 0, () => {
      const s = engineSession('tomek');
      s.setLive(70, 12000);
      s.closeDay();
      const closed = computeHes(HW, s.history());
      const r = engineReportOf('tomek', s);
      expect(s.historyLength()).assertEqual(29);
      expect(r.hes).assertEqual(closed.score === undefined ? HES_NONE : closed.score);
      expect(r.tier).assertEqual(closed.tier);
      expect(r.coveragePct).assertEqual(closed.coverage);
      const points = pointsToNextTier(closed);
      expect(r.pointsToNext).assertEqual(points === undefined ? 0 : points);
      expect(r.benefit).assertEqual(benefitLevel(r.eligible, r.tier, hasScore(r)));
      // Today's steps are a completed day now: the newest bar is 12,000 steps on the curve.
      const bars = component(r, ComponentId.STEPS).bars7;
      expect(bars[6]).assertEqual(100);
      expect(bars[5]).assertEqual(component(engineReport('tomek'), ComponentId.STEPS).bars7[6]);
      // The live heart rate is never stored; the new running day starts from the source's steps again.
      expect(r.live.hr).assertEqual(70);
      expect(r.live.steps).assertEqual(7000);
      // The wear month and the period stay as they are.
      expect(r.wear).assertDeepEquals(engineReport('tomek').wear);
      expect(r.periodIso).assertEqual(engineReport('tomek').periodIso);
      // The period line names the last scored day once a closed day lies after the wear month.
      expect(engineReport('tomek').period).assertEqual('4 Sep – 3 Oct');
      expect(r.period).assertEqual('4 Sep – 3 Oct · score to 4 Oct');
      // The counterfactual is the one of the new result.
      const change = engineWhatIf(closed);
      expect(r.whatIf).assertEqual(change === null ? '' : change.sentence);
    });

    it('reset gives the starting report again', 0, () => {
      const s = engineSession('kasia');
      s.setLive(88, 4000);
      s.closeDay();
      s.closeDay();
      s.setLive(90, 100);
      s.resetDemo();
      expect(engineReportOf('kasia', s)).assertDeepEquals(engineReport('kasia'));
      // The cached report was not touched by the session.
      expect(engineReport('kasia').live.steps).assertEqual(6000);
      expect(engineReport('kasia').live.hr).assertEqual(LIVE_NONE);
      expect(engineReport('kasia').hes).assertEqual(73);
    });

    it('closing the day adds one completed day and the score is calculated again from that history', 0, () => {
      for (let p = 0; p < HES_PROFILES.length; p++) {
        for (let i = 0; i < IDS.length; i++) {
          const s = engineSession(IDS[i]);
          const days = s.historyLength();
          s.closeDay();
          expect(s.historyLength()).assertEqual(days + 1);
          expect(s.closedDays()).assertEqual(1);
          const again = computeHes(HES_PROFILES[p], s.history());
          const r = engineReportOf(IDS[i], s, HES_PROFILES[p]);
          const againScore = again.score;
          expect(r.hes).assertEqual(againScore === undefined ? HES_NONE : againScore);
          expect(r.tier).assertEqual(again.tier);
          expect(r.coveragePct).assertEqual(again.coverage);
          s.resetDemo();
          expect(s.historyLength()).assertEqual(days);
          expect(s.closedDays()).assertEqual(0);
          expect(engineReportOf(IDS[i], s, HES_PROFILES[p])).assertDeepEquals(engineReport(IDS[i], HES_PROFILES[p]));
        }
      }
    });

    it('Ania with nothing changed stays 92 · A · High after a closed day; the report says so', 0, () => {
      const s = engineSession('ania');
      s.closeDay();
      const r = engineReportOf('ania', s);
      expect(r.hes).assertEqual(92);
      expect(r.tier).assertEqual(ReportTier.A);
      expect(r.confidence).assertEqual(ReportConfidence.HIGH);
      expect(r.coveragePct).assertEqual(100);
      expect(r.pointsToNext).assertEqual(0);
      expect(r.whatIf).assertEqual('');
    });

    it('Ewa: a closed day brings her ordinary day; the score stays 59 · C and reset gives the start again', 0, () => {
      const s = engineSession('ewa');
      expect(engineReportOf('ewa', s).hes).assertEqual(59);
      expect(engineReportOf('ewa', s).tier).assertEqual(ReportTier.C);
      s.closeDay();
      // Her source day repeats her usual values, so steps, activity, resting HR and sleep length keep
      // their raw values. Only the sleep timing moves: the new night is at her usual times, so the SD
      // falls from 85 to 85 x sqrt(16/17) = 82.46 min. That is worth about +0.3 point: 59 stays 59.
      const after = engineReportOf('ewa', s);
      expect(after.hes).assertEqual(59);
      expect(after.tier).assertEqual(ReportTier.C);
      expect(after.coveragePct).assertEqual(80);
      expect(component(after, ComponentId.STEPS).raw).assertEqual('4,400');
      expect(component(after, ComponentId.STEPS).validCount).assertEqual(21);
      expect(component(after, ComponentId.SLEEP_REGULARITY).validCount).assertEqual(17);
      expect(component(after, ComponentId.SLEEP_REGULARITY).raw).assertEqual('±82');
      expect(component(after, ComponentId.SLEEP_REGULARITY).scoreExact).assertClose(65, 0.2);
      expect(component(after, ComponentId.SLEEP_REGULARITY).scoreExact >
        component(engineReport('ewa'), ComponentId.SLEEP_REGULARITY).scoreExact).assertTrue();
      expect(component(after, ComponentId.HRV).available).assertFalse();    // 4 nights of 7
      expect(component(after, ComponentId.HRV).countText).assertEqual('4 of 7 nights');
      s.resetDemo();
      expect(engineReportOf('ewa', s).hes).assertEqual(59);
      expect(engineReportOf('ewa', s)).assertDeepEquals(engineReport('ewa'));
    });

    it('Ola: no score after seven closed days, a score after the eighth', 0, () => {
      const s = engineSession('ola');
      for (let d = 0; d < 7; d++) {
        s.closeDay();
      }
      const seven = engineReportOf('ola', s);
      expect(hasScore(seven)).assertFalse();
      expect(seven.pointsToNext).assertEqual(POINTS_UNKNOWN);
      expect(seven.coveragePct).assertEqual(55);
      expect(seven.whatIf).assertEqual('');
      s.closeDay();
      const hw = engineReportOf('ola', s, HW);
      const lw = engineReportOf('ola', s, LW);
      expect(hw.hes).assertEqual(84);
      expect(hw.tier).assertEqual(ReportTier.A);
      expect(hw.coveragePct).assertEqual(82.5);
      expect(hw.confidence).assertEqual(ReportConfidence.MEDIUM);
      expect(lw.hes).assertEqual(84);
      expect(lw.tier).assertEqual(ReportTier.A);
      expect(lw.coveragePct).assertEqual(72.5);
      expect(lw.confidence).assertEqual(ReportConfidence.MEDIUM);
      // Her wear month did not change: still 8 compliant days, so she is not eligible for a benefit.
      expect(hw.eligible).assertFalse();
      expect(hw.benefit).assertEqual(BenefitLevel.NONE);
    });

    it('live readings never change the score, before or after a closed day', 0, () => {
      for (let i = 0; i < IDS.length; i++) {
        const s = engineSession(IDS[i]);
        const start = s.current(HW).score;
        s.setLive(150, 20000);
        expect(s.current(HW).score).assertEqual(start);
        expect(engineReportOf(IDS[i], s).hes).assertEqual(engineReport(IDS[i]).hes);
        s.setLive(undefined, undefined);
        s.closeDay();
        const closed = s.current(HW).score;
        s.setLive(40, 0);
        expect(s.current(HW).score).assertEqual(closed);
        s.setLive(190, 45000);
        expect(s.current(HW).score).assertEqual(closed);
        expect(s.current(LW).status === HesStatus.OK).assertEqual(s.current(HW).status === HesStatus.OK);
      }
    });
  });

  describe('Engine reports: day details', () => {
    it('thirty days per persona, the same days and states as the report and the wear month', 0, () => {
      for (let i = 0; i < IDS.length; i++) {
        const details: DayDetail[] = engineDayDetails(IDS[i]);
        const r = engineReport(IDS[i]);
        const month = WearPersonas.result(IDS[i]);
        expect(details.length).assertEqual(30);
        expect(details[0].date).assertEqual('2026-09-04');
        expect(details[29].date).assertEqual('2026-10-03');
        let suspicious = 0;
        for (let d = 0; d < details.length; d++) {
          const day = details[d];
          expect(day.n).assertEqual(r.wear.days[d].n);
          expect(day.state).assertEqual(r.wear.days[d].state);
          expect(day.date).assertEqual(month.days[d].date);
          expect(day.wornMin).assertEqual(month.days[d].wornMin);
          expect(day.chargingMin).assertEqual(month.days[d].chargingMin);
          expect(day.nightWorn).assertEqual(month.days[d].nightWorn);
          for (let b = 0; b < day.breaks.length; b++) {
            expect(day.breaks[b].minutes >= 120).assertTrue();
            if (day.breaks[b].suspicious) {
              suspicious++;
              expect(day.breaks[b].judged).assertTrue();
            }
          }
        }
        expect(suspicious).assertEqual(r.wear.suspicious);
      }
      expect(engineDayDetails('nobody')).assertDeepEquals(engineDayDetails(ENGINE_DEFAULT_ID));
    });

    it('Marek, 17 September: the suspicious break and its reason as ready text', 0, () => {
      const day = engineDayDetails('marek')[13];
      expect(day.n).assertEqual(14);
      expect(day.date).assertEqual('2026-09-17');
      expect(day.state).assertEqual(DayState.SUSPICIOUS);
      expect(day.breaks.length).assertEqual(1);
      expect(day.breaks[0].startMin).assertEqual(13 * 60 + 5);
      expect(day.breaks[0].minutes).assertEqual(335);
      expect(day.breaks[0].judged).assertTrue();
      expect(day.breaks[0].suspicious).assertTrue();
      expect(day.breaks[0].restDeltaBpm).assertEqual(9);
      expect(day.breaks[0].stepsRatio).assertEqual(0.54);
      expect(day.reason).assertEqual(
        'Off the wrist 13:05 for 5 h 35 min after resting HR +9 bpm and 46% fewer steps in the 24 h before');
    });

    it('Kasia: the break with 8 heart-rate readings is not judged and says so; one day is suspicious', 0, () => {
      const details = engineDayDetails('kasia');
      let notJudged = 0;
      let suspicious = 0;
      for (let d = 0; d < details.length; d++) {
        const day = details[d];
        for (let b = 0; b < day.breaks.length; b++) {
          if (day.breaks[b].hrReadings24hBefore === 8) {
            notJudged++;
            expect(day.breaks[b].judged).assertFalse();
            expect(day.breaks[b].suspicious).assertFalse();
            expect(day.state).assertEqual(DayState.SHORT);
            expect(day.reason).assertEqual(
              'Not worn this day; break not judged (8 heart-rate readings before it, 12 needed)');
          }
        }
        if (day.state === DayState.SUSPICIOUS) {
          suspicious++;
          expect(day.reason).assertEqual(
            'Off the wrist all day after resting HR +8 bpm and 48% fewer steps in the 24 h before');
        }
      }
      expect(notJudged).assertEqual(1);
      expect(suspicious).assertEqual(1);
    });

    it('every day has a reason: the numbers the rule compared, one line, no forbidden wording', 0, () => {
      for (let i = 0; i < IDS.length; i++) {
        const details = engineDayDetails(IDS[i]);
        for (let d = 0; d < details.length; d++) {
          const day = details[d];
          expect(day.reason.length > 0).assertTrue();
          expect(day.reason.charAt(day.reason.length - 1) !== '.').assertTrue();
          expect(day.reason.charAt(0)).assertEqual(day.reason.charAt(0).toUpperCase());
          const text = ` ${day.reason.toLowerCase()} `;
          for (let f = 0; f < FORBIDDEN.length; f++) {
            expect(text.indexOf(FORBIDDEN[f]) < 0).assertTrue();
          }
          if (day.state === DayState.COMPLIANT) {
            expect(day.reason.indexOf('Worn ') === 0 && day.reason.indexOf('the night counts') > 0).assertTrue();
          } else if (day.state === DayState.SUSPICIOUS) {
            expect(day.reason.indexOf('Off the wrist ')).assertEqual(0);
          } else if (day.state === DayState.UNKNOWN) {
            expect(day.reason).assertEqual('No record from the watch for this day');
            expect(day.wornMin).assertEqual(0);
            expect(day.breaks.length).assertEqual(0);
          } else {
            expect(day.reason.indexOf('Worn ') === 0 || day.reason.indexOf('Not worn this day') === 0 ||
              day.reason.indexOf('Night not worn') === 0).assertTrue();
          }
        }
      }
      // A short day of Marek: the hours, with the charging time the rule counted.
      const marek = engineDayDetails('marek');
      let short = 0;
      for (let d = 0; d < marek.length; d++) {
        if (marek[d].state === DayState.SHORT) {
          short++;
          expect(marek[d].reason.indexOf(' of 20 h') > 0).assertTrue();
        }
      }
      expect(short).assertEqual(1);
    });
  });

  describe('Engine reports: the counterfactual', () => {
    // The sentences below were read from the program output and checked by hand: for each persona the score
    // with one Core component moved along its own curve was worked out from the table's component scores and
    // weights (observed = sum of weight x score / sum of weights), and the smallest relative change that
    // reaches the next tier (observed >= 79.5, or 59.5 from C) was picked. The working is in the comments.
    it('Tomek: 7 h of sleep a night instead of 6 h 30 min', 0, () => {
      // Observed 78.93 (73010 / 925). Sleep 6.5 h -> 7 h (95): +13 x 125 / 925 = +1.76 -> 80.7, tier A, a 7.7%
      // change. Steps 7,000 -> 8,000 would give 79.74 (also A) but is a 14.3% change.
      const tomek = engineReport('tomek');
      const change = whatIfOf('tomek', HW);
      expect(tomek.whatIf).assertEqual(change.sentence);
      expect(tomek.whatIf).assertEqual(
        '7 h of sleep a night instead of 6 h 30 min would be enough for Tier A, with everything else unchanged.');
      expect(change.componentId).assertEqual(ComponentId.SLEEP);
      expect(hesComponentDefinition(change.hesId).requiredCore).assertTrue();
      expect(change.fromRaw).assertClose(6.5, EPS);
      expect(change.toRaw).assertEqual(7);
      expect(change.tier).assertEqual(ReportTier.A);
      expect(change.score).assertEqual(81);
      expect(tomek.whatIf.indexOf('sleep') >= 0).assertTrue();
    });

    it('Marek: bed and wake times within ±30 min instead of ±70 min', 0, () => {
      // Observed 75.22 (65820 / 875). Timing SD 70 -> 30 (100): +26.67 x 150 / 875 = +4.57 -> 79.79, tier A,
      // a 57% change; 45 min (90) only gives 78.1. Active minutes need 250 (a 110% change); steps at 10,000
      // give 78.3 and sleep at 7.5 h gives 77.4, neither reaches A.
      const change = whatIfOf('marek', HW);
      expect(engineReport('marek').whatIf).assertEqual(
        'Bed and wake times within ±30 min instead of ±70 min would be enough for Tier A, ' +
          'with everything else unchanged.');
      expect(change.componentId).assertEqual(ComponentId.SLEEP_REGULARITY);
      expect(change.toRaw).assertEqual(30);
      expect(change.score).assertEqual(80);
    });

    it('Kasia: 250 active minutes a week instead of 98', 0, () => {
      // Observed 72.97 (79.5 needs +6.53). Active minutes 98 -> 250 (95): +36 x 267 / 1000 = +9.6 -> 82.6. At 150
      // (80) it is only 78.6; no other single Core change reaches 79.5 (timing at 30: 78.3, steps at 10,000: 77).
      const change = whatIfOf('kasia', HW);
      expect(engineReport('kasia').whatIf).assertEqual(
        '250 active minutes a week instead of 98 would be enough for Tier A, with everything else unchanged.');
      expect(change.componentId).assertEqual(ComponentId.ACTIVE_MINUTES);
      expect(change.toRaw).assertEqual(250);
    });

    it('Ewa: 6 h 30 min of sleep a night instead of 6 h 12 min, for Tier B', 0, () => {
      // Observed 58.80 (47041.7 / 800). Sleep 6.2 h -> 6.5 h (82): +10.2 x 125 / 800 = +1.59 -> 60.4, tier B, a
      // 4.8% change. Steps at 5,000 (+1.69) are a 13.6% change; timing at 60 min (+3.1) a 29% change.
      const change = whatIfOf('ewa', HW);
      expect(engineReport('ewa').whatIf).assertEqual(
        '6 h 30 min of sleep a night instead of 6 h 12 min would be enough for Tier B, ' +
          'with everything else unchanged.');
      expect(change.componentId).assertEqual(ComponentId.SLEEP);
      expect(change.tier).assertEqual(ReportTier.B);
    });

    it('Longevity weights can pick another component: Marek and Kasia are told steps', 0, () => {
      // Marek LW: observed 75.81 (58753 / 775). Steps 6,200 -> 10,000: +18 x 175 / 775 = +4.06 -> 79.9, a 61%
      // change; timing at 30 gives only 79.25 here (weight 100).
      expect(engineReport('marek', LW).whatIf).assertEqual(
        '10,000 steps a day instead of 6,200 would be enough for Tier A, with everything else unchanged.');
      // Kasia LW: observed 74.15 (48198 / 650). Steps 6,000 -> 10,000: +20 x 175 / 650 = +5.38 -> 79.53, a 67%
      // change; 8,000 gives 78.2, timing at 30 gives 78.3.
      expect(engineReport('kasia', LW).whatIf).assertEqual(
        '10,000 steps a day instead of 6,000 would be enough for Tier A, with everything else unchanged.');
      expect(whatIfOf('marek', LW).componentId).assertEqual(ComponentId.STEPS);
      expect(whatIfOf('kasia', LW).componentId).assertEqual(ComponentId.STEPS);
    });

    it('empty for Ania (tier A) and for Ola (no score), in both profiles', 0, () => {
      for (let p = 0; p < HES_PROFILES.length; p++) {
        expect(engineReport('ania', HES_PROFILES[p]).whatIf).assertEqual('');
        expect(engineReport('ola', HES_PROFILES[p]).whatIf).assertEqual('');
        expect(engineWhatIf(HesPersonas.result('ania', HES_PROFILES[p], TODAY)) === null).assertTrue();
        expect(engineWhatIf(HesPersonas.result('ola', HES_PROFILES[p], TODAY)) === null).assertTrue();
        expect(engineWhatIf(computeHes(HES_PROFILES[p], { days: [], crf: [], hrr: [] })) === null).assertTrue();
      }
    });

    it('applying the change really reaches the next tier, and no nearer curve point does', 0, () => {
      for (let p = 0; p < HES_PROFILES.length; p++) {
        let present = 0;
        for (let i = 0; i < IDS.length; i++) {
          const r = engineReport(IDS[i], HES_PROFILES[p]);
          const result = HesPersonas.result(IDS[i], HES_PROFILES[p], TODAY);
          const change = engineWhatIf(result);
          if (change === null) {
            expect(r.whatIf).assertEqual('');
            continue;
          }
          present++;
          expect(r.whatIf).assertEqual(change.sentence);
          const def = hesComponentDefinition(change.hesId);
          const before = engineComponent(result, change.hesId);
          const beforeScore = before.score;
          // One Core component, moved to a point of its own curve, to a better score.
          expect(def.requiredCore).assertTrue();
          expect(change.componentId).assertEqual(reportComponentId(change.hesId));
          expect(change.fromRaw).assertEqual(before.rawValue);
          let onCurve = false;
          for (let c = 0; c < def.curve.length; c++) {
            if (def.curve[c].x === change.toRaw) {
              onCurve = true;
            }
          }
          expect(onCurve).assertTrue();
          expect(beforeScore !== undefined && score(change.hesId, change.toRaw) > beforeScore).assertTrue();
          // Calculated again from the engine result: the next tier, not just a higher score.
          const changed = resultWithChange(result, change.hesId, change.toRaw);
          expect(changed.tier).assertEqual(nextTierOf(result.tier));
          expect(changed.tier).assertEqual(change.tier);
          expect(changed.score).assertEqual(change.score);
          const changedScore = changed.score;
          const resultScore = result.score;
          expect(changedScore !== undefined && resultScore !== undefined && changedScore > resultScore)
            .assertTrue();
          expect(changed.coverage).assertEqual(result.coverage);
          // Every curve point between today's value and the target leaves the tier as it is.
          const from = change.fromRaw;
          const low = Math.min(from, change.toRaw);
          const high = Math.max(from, change.toRaw);
          for (let c = 0; c < def.curve.length; c++) {
            const point: HesPoint = def.curve[c];
            if (point.x > low && point.x < high) {
              expect(resultWithChange(result, change.hesId, point.x).tier).assertEqual(result.tier);
            }
          }
        }
        expect(present).assertEqual(4);
      }
    });

    it('the sentences: one sentence, a unit, the next tier, no forbidden or promise wording', 0, () => {
      for (let p = 0; p < HES_PROFILES.length; p++) {
        const withSentence = ['marek', 'kasia', 'tomek', 'ewa'];
        for (let i = 0; i < withSentence.length; i++) {
          const r = engineReport(withSentence[i], HES_PROFILES[p]);
          const text = r.whatIf;
          expect(text.charAt(text.length - 1)).assertEqual('.');
          expect(text.indexOf('.')).assertEqual(text.length - 1);
          expect(text.indexOf('Tier ' + nextTierOf(r.tier)) >= 0).assertTrue();
          expect(text.indexOf('min') >= 0 || text.indexOf('steps') >= 0 || text.indexOf('bpm') >= 0 ||
            text.indexOf(' h ') >= 0).assertTrue();
          const lower = ' ' + text.toLowerCase() + ' ';
          for (let f = 0; f < FORBIDDEN.length; f++) {
            expect(lower.indexOf(FORBIDDEN[f])).assertEqual(-1);
          }
        }
      }
    });

    it('empty when no single Core change is enough', 0, () => {
      // Every Core component at the bottom of its curve except the timing (SD 0 = 100): steps 1,000 (0),
      // resting HR 110 (5), no activity (0), 4 h of sleep (0). Observed (125 x 5 + 150 x 100) / 750 = 20.8.
      // One change cannot reach 60: steps to 10,000 gives 40.8, activity at 300 gives 47.5.
      const result = computeHes(HW, steadyHistory(1000, 110, 0, 1380, 180, 240));
      expect(result.score).assertEqual(21);
      expect(result.tier).assertEqual(HesTier.C);
      expect(engineWhatIf(result) === null).assertTrue();
    });

    it('the resting heart rate is named only when no behaviour is enough', 0, () => {
      // Steps, activity, sleep and sleep timing are on the top of their curves; resting HR 100 bpm (20) and a
      // 5th-percentile VO2max (10) keep the score in tier B: (125 x 10 + 125 x 20 + 200 x 100 + 150 x 100 +
      // 150 x 100 + 125 x 100) / 875 = 75.71, which is 76.
      const history = steadyHistory(12000, 100, 60, 1380, 420, 480);
      history.crf.push({ date: dateAgo(3), percentile: 5 });
      const result = computeHes(HW, history);
      expect(result.score).assertEqual(76);
      expect(result.tier).assertEqual(HesTier.B);
      const change = engineWhatIf(result);
      if (change === null) {
        throw new Error('no counterfactual');
      }
      // 90 bpm (45) gives 75.71 + 25 x 125 / 875 = 79.29, still B; 80 bpm (66) gives 82.3, tier A.
      expect(change.hesId).assertEqual(HesComponentId.RHR);
      expect(change.componentId).assertEqual(ComponentId.RESTING_HR);
      expect(change.toRaw).assertEqual(80);
      expect(change.sentence).assertEqual(
        'A resting heart rate of 80 bpm instead of 100 bpm would be enough for Tier A, ' +
          'with everything else unchanged.');
      expect(resultWithChange(result, HesComponentId.RHR, 90).tier).assertEqual(HesTier.B);
      expect(resultWithChange(result, HesComponentId.RHR, 80).tier).assertEqual(HesTier.A);
      expect(HES_COMPONENTS.length).assertEqual(8);
    });
  });
}
