import { describe, it, expect } from '@ohos/hypium';
import { validateTierClaimJson } from '../main/ets/claim/ClaimValidation';
import { buildTierClaim, encodeTierClaim } from '../main/ets/claim/TierClaimCodec';
import { componentScore } from '../main/ets/hes/HesComponents';
import { hesDefinition } from '../main/ets/hes/HesCurves';
import { composeHes, computeHes } from '../main/ets/hes/HesEngine';
import { hesRound } from '../main/ets/hes/HesMath';
import { HesPersonas } from '../main/ets/hes/HesPersonas';
import { piecewiseScore } from '../main/ets/hes/HesPiecewise';
import { pointsToNextTier } from '../main/ets/hes/HesTier';
import {
  emptyHesDay,
  HesComponentId,
  HesComponentResult,
  HesDay,
  HesPoint,
  HesResult,
  HES_MISSING
} from '../main/ets/hes/HesTypes';
import { WearPersonas } from '../main/ets/wear/WearPersonas';
import { benefitLevel, benefitReason } from '../main/ets/report/Benefit';
import {
  ENGINE_DEFAULT_ID,
  ENGINE_SOURCE,
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
import { previewPersonas, previewReport } from '../main/ets/report/PreviewReports';
import {
  BAR_NO_DATA,
  BenefitLevel,
  ComponentId,
  ComponentRow,
  DayState,
  hasScore,
  HES_NONE,
  PersonaReport,
  POINTS_UNKNOWN,
  ReportConfidence,
  ReportTier
} from '../main/ets/report/ReportModels';

const IDS: string[] = ['ania', 'marek', 'kasia', 'tomek', 'ewa', 'ola'];
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
const DAY_STATES: string[] = [DayState.COMPLIANT, DayState.SHORT, DayState.SUSPICIOUS, DayState.SICK,
  DayState.UNKNOWN];
// Wording the plan forbids in user text (appendix C) and promise wording.
const FORBIDDEN: string[] = ['risk', 'validated', 'healthy', ' ai ', 'predict', 'guarantee', ' will ', 'disease'];

// The expected result of one persona: the fixed table of the plan (appendix B).
function expectPersona(id: string, hes: number, tier: string, coverage: number, confidence: string,
  benefit: string, eligible: boolean): void {
  const r: PersonaReport = engineReport(id);
  expect(r.id).assertEqual(id);
  expect(r.hes).assertEqual(hes);
  expect(r.tier).assertEqual(tier);
  expect(r.coveragePct).assertEqual(coverage);
  expect(r.confidence).assertEqual(confidence);
  expect(r.benefit).assertEqual(benefit);
  expect(r.eligible).assertEqual(eligible);
}

function component(r: PersonaReport, id: string): ComponentRow {
  for (let i = 0; i < r.components.length; i++) {
    if (r.components[i].id === id) {
      return r.components[i];
    }
  }
  throw new Error('component not in the report');
}

function engineComponent(result: HesResult, id: HesComponentId): HesComponentResult {
  for (let i = 0; i < result.components.length; i++) {
    if (result.components[i].id === id) {
      return result.components[i];
    }
  }
  throw new Error('component not in the result');
}

function engineComponentOfRow(result: HesResult, rowId: string): HesComponentResult {
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

// Everything of a report except the live readings, as one text.
function withoutLive(r: PersonaReport): string {
  const copy: PersonaReport = {
    id: r.id,
    name: r.name,
    period: r.period,
    periodIso: r.periodIso,
    hes: r.hes,
    tier: r.tier,
    coveragePct: r.coveragePct,
    confidence: r.confidence,
    eligible: r.eligible,
    benefit: r.benefit,
    benefitReason: r.benefitReason,
    pointsToNext: r.pointsToNext,
    components: r.components,
    wear: r.wear,
    live: { hr: HES_MISSING, steps: HES_MISSING },
    whatIf: r.whatIf
  };
  return JSON.stringify(copy);
}

// The engine result when one component has another value: calculated here, not taken from the report.
function resultWithChange(result: HesResult, id: HesComponentId, toRaw: number): HesResult {
  const components: HesComponentResult[] = [];
  for (let i = 0; i < result.components.length; i++) {
    const c = result.components[i];
    const changed = c.id === id;
    components.push({
      id: c.id,
      label: c.label,
      unit: c.unit,
      core: c.core,
      rawValue: changed ? toRaw : c.rawValue,
      score: changed ? componentScore(hesDefinition(id), toRaw) : c.score,
      available: c.available,
      validCount: c.validCount,
      minCount: c.minCount,
      targetCount: c.targetCount,
      quality: c.quality,
      baseWeight: c.baseWeight,
      effectiveWeight: 0
    });
  }
  return composeHes(components);
}

function whatIfOf(id: string): EngineWhatIf {
  const change = engineWhatIf(HesPersonas.result(id));
  if (change === null) {
    throw new Error('no counterfactual');
  }
  return change;
}

// 28 identical days: the same steps, resting heart rate, activity and night every day.
function steadyHistory(steps: number, rhr: number, moderate: number, sleepStartMin: number, sleepEndMin: number,
  sleepMinutes: number, vo2maxPercentile: number): HesDay[] {
  const out: HesDay[] = [];
  for (let i = 0; i < 28; i++) {
    const day = emptyHesDay('');
    day.steps = steps;
    day.restingHeartRate = rhr;
    day.moderateMinutes = moderate;
    day.vigorousMinutes = 0;
    day.sleepStartMin = sleepStartMin;
    day.sleepEndMin = sleepEndMin;
    day.sleepMinutes = sleepMinutes;
    day.vo2maxPercentile = vo2maxPercentile;
    out.push(day);
  }
  return out;
}

export default function engineReportsTest() {
  describe('Engine reports: the fixed results', () => {
    it('the six personas equal the fixed table: score, tier, coverage, confidence, benefit, eligible', 0, () => {
      expect(engineReports().length).assertEqual(6);
      expectPersona('ania', 92, ReportTier.A, 100, ReportConfidence.HIGH, BenefitLevel.FULL, true);
      expectPersona('marek', 75, ReportTier.B, 85, ReportConfidence.HIGH, BenefitLevel.NONE, false);
      expectPersona('kasia', 73, ReportTier.B, 70, ReportConfidence.MEDIUM, BenefitLevel.PARTIAL, true);
      expectPersona('tomek', 79, ReportTier.B, 90, ReportConfidence.HIGH, BenefitLevel.PARTIAL, true);
      expectPersona('ewa', 59, ReportTier.C, 75, ReportConfidence.MEDIUM, BenefitLevel.NONE, true);
      expectPersona('ola', HES_NONE, ReportTier.NONE, 43, ReportConfidence.INSUFFICIENT, BenefitLevel.NONE,
        false);
      expect(hasScore(engineReport('ola'))).assertFalse();
      expect(hasScore(engineReport('ewa'))).assertTrue();
    });

    it('engine and preview agree on score, tier, coverage, confidence, benefit and eligible', 0, () => {
      for (let i = 0; i < IDS.length; i++) {
        const engine = engineReport(IDS[i]);
        const preview = previewReport(IDS[i]);
        expect(engine.id).assertEqual(preview.id);
        expect(engine.hes).assertEqual(preview.hes);
        expect(engine.tier).assertEqual(preview.tier);
        expect(engine.coveragePct).assertEqual(preview.coveragePct);
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
      const session = engineSession('nobody');
      expect(engineReportOf('nobody', session)).assertDeepEquals(engineReport(ENGINE_DEFAULT_ID));
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

    it('points to the next tier come from the engine; no score gives "not known", never 0', 0, () => {
      expect(engineReport('ania').pointsToNext).assertEqual(0);
      expect(engineReport('marek').pointsToNext).assertEqual(5);
      expect(engineReport('kasia').pointsToNext).assertEqual(7);
      expect(engineReport('tomek').pointsToNext).assertEqual(1);
      expect(engineReport('ewa').pointsToNext).assertEqual(1);       // to B
      expect(engineReport('ola').pointsToNext).assertEqual(POINTS_UNKNOWN);
      for (let i = 0; i < IDS.length; i++) {
        const r = engineReport(IDS[i]);
        if (hasScore(r)) {
          expect(r.pointsToNext).assertEqual(pointsToNextTier(HesPersonas.result(IDS[i]).score));
        }
      }
      expect(nextTierOf(ReportTier.B)).assertEqual(ReportTier.A);
      expect(nextTierOf(ReportTier.C)).assertEqual(ReportTier.B);
      expect(nextTierOf(ReportTier.A)).assertEqual('');
      expect(nextTierOf(ReportTier.NONE)).assertEqual('');
    });
  });

  describe('Engine reports: components', () => {
    it('eight components in the report order, with the engine scores and weights', 0, () => {
      for (let i = 0; i < IDS.length; i++) {
        const r = engineReport(IDS[i]);
        const result = HesPersonas.result(IDS[i]);
        expect(r.components.length).assertEqual(8);
        for (let c = 0; c < r.components.length; c++) {
          const row = r.components[c];
          const source = engineComponentOfRow(result, row.id);
          expect(row.id).assertEqual(REPORT_ORDER[c]);
          expect(row.label).assertEqual(source.label);
          expect(row.available).assertEqual(source.available);
          expect(row.validCount).assertEqual(source.validCount);
          expect(row.bars7.length).assertEqual(7);
          if (row.available) {
            expect(row.score).assertEqual(hesRound(source.score));
            expect(row.score >= 0 && row.score <= 100).assertTrue();
            expect(row.source).assertEqual(ENGINE_SOURCE);
          }
          if (row.available && hasScore(r)) {
            expect(Math.abs(row.weightPct - source.effectiveWeight * 100) <= 0.05).assertTrue();
          }
        }
      }
      expect(ENGINE_SOURCE).assertEqual('HUAWEI Health · Demo data');
    });

    it('weights of the available components add up to 100 (±1); without a score nothing is weighed', 0, () => {
      const all = engineReports();
      for (let i = 0; i < all.length; i++) {
        let sum = 0;
        for (let c = 0; c < all[i].components.length; c++) {
          const row = all[i].components[c];
          if (row.available) {
            sum += row.weightPct;
          } else {
            expect(row.weightPct).assertEqual(0);
          }
        }
        if (hasScore(all[i])) {
          expect(Math.abs(sum - 100) <= 1).assertTrue();
        } else {
          expect(sum).assertEqual(0);
        }
      }
    });

    it('component scores weighted by their weights give the score (±1)', 0, () => {
      const all = engineReports();
      for (let i = 0; i < all.length; i++) {
        if (!hasScore(all[i])) {
          continue;
        }
        let weighted = 0;
        for (let c = 0; c < all[i].components.length; c++) {
          const row = all[i].components[c];
          if (row.available) {
            weighted += row.score * row.weightPct / 100;
          }
        }
        expect(Math.abs(weighted - all[i].hes) <= 1).assertTrue();
      }
    });

    it('a component that is not available has no value, score, weight or bar, and carries its counts', 0, () => {
      let unavailable = 0;
      for (let i = 0; i < IDS.length; i++) {
        const r = engineReport(IDS[i]);
        const result = HesPersonas.result(IDS[i]);
        for (let c = 0; c < r.components.length; c++) {
          const row = r.components[c];
          const source = engineComponentOfRow(result, row.id);
          if (row.available) {
            expect(row.raw.length > 0).assertTrue();
            expect(row.unit.length > 0).assertTrue();
            continue;
          }
          unavailable++;
          expect(row.score).assertEqual(HES_NONE);
          expect(row.raw).assertEqual('');
          expect(row.unit).assertEqual('');
          expect(row.weightPct).assertEqual(0);
          expect(row.source).assertEqual('');
          expect(countBars(row)).assertEqual(0);
          expect(row.validCount).assertEqual(source.validCount);
          if (source.core) {
            // A Core component: "X of Y", with X below Y.
            expect(row.minCount).assertEqual(source.minCount);
            expect(row.minCount > 0).assertTrue();
            expect(row.validCount < row.minCount).assertTrue();
          } else {
            // The score does not require it.
            expect(row.minCount).assertEqual(0);
          }
        }
      }
      expect(unavailable).assertEqual(13);
      const ola = engineReport('ola');
      expect(component(ola, ComponentId.SLEEP).validCount).assertEqual(8);
      expect(component(ola, ComponentId.SLEEP).minCount).assertEqual(14);
      expect(component(ola, ComponentId.SLEEP_REGULARITY).validCount).assertEqual(8);
      expect(component(ola, ComponentId.SLEEP_REGULARITY).minCount).assertEqual(14);
      expect(component(ola, ComponentId.HR_RECOVERY).validCount).assertEqual(1);
      expect(component(ola, ComponentId.STEPS).available).assertTrue();
      expect(component(ola, ComponentId.STEPS).validCount).assertEqual(24);
      expect(component(ola, ComponentId.STEPS).minCount).assertEqual(14);
      expect(component(ola, ComponentId.RESTING_HR).minCount).assertEqual(10);
      expect(component(engineReport('tomek'), ComponentId.HRV).available).assertFalse();
      expect(component(engineReport('ania'), ComponentId.HRV).available).assertTrue();
    });

    it('raw values are the engine values, written with their units', 0, () => {
      const tomek = engineReport('tomek');
      expect(component(tomek, ComponentId.STEPS).raw).assertEqual('6,374');
      expect(component(tomek, ComponentId.STEPS).unit).assertEqual('/day');
      expect(component(tomek, ComponentId.ACTIVE_MINUTES).raw).assertEqual('124');
      expect(component(tomek, ComponentId.ACTIVE_MINUTES).unit).assertEqual('min/week');
      expect(component(tomek, ComponentId.RESTING_HR).raw).assertEqual('76');
      expect(component(tomek, ComponentId.RESTING_HR).unit).assertEqual('bpm');
      expect(component(tomek, ComponentId.SLEEP).raw).assertEqual('6 h 6');
      expect(component(tomek, ComponentId.SLEEP).unit).assertEqual('min');
      expect(component(tomek, ComponentId.SLEEP_REGULARITY).raw).assertEqual('±35');
      expect(component(tomek, ComponentId.SLEEP_REGULARITY).unit).assertEqual('min');
      expect(component(tomek, ComponentId.VO2MAX).raw).assertEqual('76th');
      expect(component(tomek, ComponentId.VO2MAX).unit).assertEqual('percentile');
      expect(component(tomek, ComponentId.HR_RECOVERY).raw).assertEqual('25');
      expect(component(tomek, ComponentId.HR_RECOVERY).unit).assertEqual('bpm in 60 s');
      expect(component(engineReport('ania'), ComponentId.HRV).raw).assertEqual('60th');
      expect(component(engineReport('ania'), ComponentId.HRV).unit).assertEqual('percentile');
      expect(component(engineReport('marek'), ComponentId.VO2MAX).raw).assertEqual('46th');
      // The numbers behind the text are the engine's.
      const result = HesPersonas.result('tomek');
      expect(hesRound(engineComponent(result, HesComponentId.STEPS).rawValue)).assertEqual(6374);
      expect(hesRound(engineComponent(result, HesComponentId.SLEEP_DURATION).rawValue * 60)).assertEqual(366);
      expect(hesRound(engineComponent(result, HesComponentId.CRF).rawValue)).assertEqual(76);
    });

    it('seven-day bars: each of the last seven days on the component curve; no data is not a zero', 0, () => {
      for (let i = 0; i < IDS.length; i++) {
        const r = engineReport(IDS[i]);
        const history = HesPersonas.history(IDS[i]);
        const steps = component(r, ComponentId.STEPS);
        const rhr = component(r, ComponentId.RESTING_HR);
        for (let b = 0; b < 7; b++) {
          const day = history[history.length - 7 + b];
          if (day.steps < 0) {
            expect(steps.bars7[b]).assertEqual(BAR_NO_DATA);
            expect(rhr.bars7[b]).assertEqual(BAR_NO_DATA);
          } else {
            expect(steps.bars7[b]).assertEqual(hesRound(piecewiseScore(day.steps,
              hesDefinition(HesComponentId.STEPS).curve)));
            expect(rhr.bars7[b]).assertEqual(hesRound(piecewiseScore(day.restingHeartRate,
              hesDefinition(HesComponentId.RHR).curve)));
          }
        }
        for (let c = 0; c < r.components.length; c++) {
          for (let b = 0; b < 7; b++) {
            const bar = r.components[c].bars7[b];
            expect(bar === BAR_NO_DATA || (bar >= 0 && bar <= 100)).assertTrue();
          }
        }
      }
      // Kasia left the watch off on 30 September: the fourth of the last seven days has no bar.
      const kasia = engineReport('kasia');
      expect(component(kasia, ComponentId.STEPS).bars7[3]).assertEqual(BAR_NO_DATA);
      expect(component(kasia, ComponentId.SLEEP).bars7[3]).assertEqual(BAR_NO_DATA);
      expect(countBars(component(kasia, ComponentId.STEPS))).assertEqual(6);
      // A VO2max estimate comes once a week: one bar, the other days have no data.
      expect(countBars(component(engineReport('ania'), ComponentId.VO2MAX))).assertEqual(1);
      expect(countBars(component(engineReport('ania'), ComponentId.SLEEP_REGULARITY))).assertEqual(7);
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
        // Eligible needs the wear month and a score.
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
    it('a new session gives the persona report, with no live reading', 0, () => {
      for (let i = 0; i < IDS.length; i++) {
        const session = engineSession(IDS[i]);
        const r = engineReportOf(IDS[i], session);
        expect(r).assertDeepEquals(engineReport(IDS[i]));
        expect(r.live.hr).assertEqual(HES_MISSING);
        expect(r.live.steps).assertEqual(HES_MISSING);
      }
    });

    it('live heart rate 200 and 99999 steps change `live` and nothing else', 0, () => {
      for (let i = 0; i < IDS.length; i++) {
        const session = engineSession(IDS[i]);
        const before = engineReportOf(IDS[i], session);
        session.setLive(200, 99999);
        const after = engineReportOf(IDS[i], session);
        expect(after.live.hr).assertEqual(200);
        expect(after.live.steps).assertEqual(99999);
        expect(withoutLive(after)).assertEqual(withoutLive(before));
        expect(after.hes).assertEqual(before.hes);
        expect(after.tier).assertEqual(before.tier);
        expect(after.components).assertDeepEquals(before.components);
        expect(after.wear).assertDeepEquals(before.wear);
        expect(after.whatIf).assertEqual(before.whatIf);
      }
    });

    it('no live reading is missing, never zero; zero steps is a reading', 0, () => {
      const session = engineSession('tomek');
      session.setLive(0, -5);
      expect(engineReportOf('tomek', session).live.hr).assertEqual(HES_MISSING);
      expect(engineReportOf('tomek', session).live.steps).assertEqual(HES_MISSING);
      session.setLive(72, 0);
      expect(engineReportOf('tomek', session).live.hr).assertEqual(72);
      expect(engineReportOf('tomek', session).live.steps).assertEqual(0);
    });

    it('closing the day: the report follows the session, the live steps enter the history', 0, () => {
      const session = engineSession('tomek');
      session.setLive(70, 12000);
      const closed = session.closeDay();
      const r = engineReportOf('tomek', session);
      expect(r.hes).assertEqual(closed.score);
      expect(r.tier).assertEqual(closed.tier);
      expect(r.coveragePct).assertEqual(closed.coverage);
      expect(r.pointsToNext).assertEqual(pointsToNextTier(closed.score));
      expect(r.benefit).assertEqual(benefitLevel(r.eligible, r.tier, hasScore(r)));
      // Today's steps are a completed day now: the newest bar is 12,000 steps on the curve.
      const bars = component(r, ComponentId.STEPS).bars7;
      expect(bars[6]).assertEqual(100);
      expect(bars[5]).assertEqual(component(engineReport('tomek'), ComponentId.STEPS).bars7[6]);
      // The live heart rate is never stored; the steps of the new day have no reading yet.
      expect(r.live.hr).assertEqual(70);
      expect(r.live.steps).assertEqual(HES_MISSING);
      // The wear month and the period stay as they are.
      expect(r.wear).assertDeepEquals(engineReport('tomek').wear);
      expect(r.periodIso).assertEqual(engineReport('tomek').periodIso);
      // The counterfactual is the one of the new result.
      const change = engineWhatIf(closed);
      expect(r.whatIf).assertEqual(change === null ? '' : change.sentence);
    });

    it('reset gives the starting report again', 0, () => {
      const session = engineSession('kasia');
      session.setLive(88, 4000);
      session.closeDay();
      session.closeDay();
      session.setLive(90, 100);
      session.reset();
      expect(engineReportOf('kasia', session)).assertDeepEquals(engineReport('kasia'));
      // The cached report was not touched by the session.
      expect(engineReport('kasia').live.steps).assertEqual(HES_MISSING);
      expect(engineReport('kasia').hes).assertEqual(73);
    });
  });

  describe('Engine reports: the counterfactual', () => {
    it('Tomek: one sentence that names a Core component and a unit', 0, () => {
      const tomek = engineReport('tomek');
      const change = whatIfOf('tomek');
      expect(tomek.whatIf).assertEqual(change.sentence);
      expect(tomek.whatIf).assertEqual(
        '6 h 30 min of sleep a night instead of 6 h 6 min would be enough for Tier A, with everything else unchanged.');
      expect(change.componentId).assertEqual(ComponentId.SLEEP);
      expect(hesDefinition(change.hesId).requiredCore).assertTrue();
      expect(change.toRaw).assertEqual(6.5);
      expect(change.tier).assertEqual(ReportTier.A);
      expect(tomek.whatIf.indexOf('sleep') >= 0).assertTrue();
      expect(tomek.whatIf.indexOf(' h ') >= 0).assertTrue();
      expect(tomek.whatIf.indexOf(' min ') >= 0).assertTrue();
    });

    it('empty for Ania (tier A) and for Ola (no score)', 0, () => {
      expect(engineReport('ania').whatIf).assertEqual('');
      expect(engineReport('ola').whatIf).assertEqual('');
      expect(engineWhatIf(HesPersonas.result('ania')) === null).assertTrue();
      expect(engineWhatIf(HesPersonas.result('ola')) === null).assertTrue();
      expect(engineWhatIf(computeHes([])) === null).assertTrue();
    });

    it('applying the change really reaches the next tier, and no nearer curve point does', 0, () => {
      let present = 0;
      for (let i = 0; i < IDS.length; i++) {
        const r = engineReport(IDS[i]);
        const result = HesPersonas.result(IDS[i]);
        const change = engineWhatIf(result);
        if (change === null) {
          expect(r.whatIf).assertEqual('');
          continue;
        }
        present++;
        expect(r.whatIf).assertEqual(change.sentence);
        const def = hesDefinition(change.hesId);
        const before = engineComponent(result, change.hesId);
        // One Core component, moved to a point of its own curve, to a better score.
        expect(def.requiredCore).assertTrue();
        expect(change.componentId).assertEqual(reportComponentId(change.hesId));
        expect(change.fromRaw).assertEqual(before.rawValue);
        let onCurve = false;
        for (let p = 0; p < def.curve.length; p++) {
          if (def.curve[p].x === change.toRaw) {
            onCurve = true;
          }
        }
        expect(onCurve).assertTrue();
        expect(componentScore(def, change.toRaw) > before.score).assertTrue();
        // Calculated again from the engine result: the next tier, not just a higher score.
        const changed = resultWithChange(result, change.hesId, change.toRaw);
        expect(changed.tier).assertEqual(nextTierOf(result.tier));
        expect(changed.tier).assertEqual(change.tier);
        expect(changed.score).assertEqual(change.score);
        expect(changed.score > result.score).assertTrue();
        expect(changed.coverage).assertEqual(result.coverage);
        // Every curve point between today's value and the target leaves the tier as it is.
        const low = Math.min(change.fromRaw, change.toRaw);
        const high = Math.max(change.fromRaw, change.toRaw);
        for (let p = 0; p < def.curve.length; p++) {
          const point: HesPoint = def.curve[p];
          if (point.x > low && point.x < high) {
            expect(resultWithChange(result, change.hesId, point.x).tier).assertEqual(result.tier);
          }
        }
      }
      expect(present).assertEqual(4);
    });

    it('the sentences: one sentence, a unit, the next tier, no forbidden or promise wording', 0, () => {
      expect(engineReport('marek').whatIf).assertEqual(
        '250 active minutes a week instead of 117 would be enough for Tier A, with everything else unchanged.');
      expect(engineReport('kasia').whatIf).assertEqual(
        'Bed and wake times within ±30 min instead of ±88 min would be enough for Tier A, ' +
          'with everything else unchanged.');
      expect(engineReport('ewa').whatIf).assertEqual(
        'Bed and wake times within ±90 min instead of ±94 min would be enough for Tier B, ' +
          'with everything else unchanged.');
      const withSentence = ['marek', 'kasia', 'tomek', 'ewa'];
      for (let i = 0; i < withSentence.length; i++) {
        const r = engineReport(withSentence[i]);
        const text = r.whatIf;
        expect(text.charAt(text.length - 1)).assertEqual('.');
        expect(text.indexOf('.')).assertEqual(text.length - 1);
        expect(text.indexOf('Tier ' + nextTierOf(r.tier)) >= 0).assertTrue();
        expect(text.indexOf('min') >= 0 || text.indexOf('steps') >= 0 || text.indexOf('bpm') >= 0).assertTrue();
        const lower = ' ' + text.toLowerCase() + ' ';
        for (let f = 0; f < FORBIDDEN.length; f++) {
          expect(lower.indexOf(FORBIDDEN[f])).assertEqual(-1);
        }
      }
    });

    it('empty when no single Core change is enough', 0, () => {
      // Every Core component at the bottom of its curve: one change cannot reach 60.
      const result = computeHes(steadyHistory(1000, 110, 0, 1380, 180, 240, HES_MISSING));
      expect(result.tier).assertEqual(ReportTier.C);
      expect(engineWhatIf(result) === null).assertTrue();
    });

    it('the resting heart rate is named only when no behaviour is enough', 0, () => {
      // Steps, activity, sleep and sleep timing on the top of their curves; resting heart rate 100 bpm
      // and a low VO2max percentile keep the score in tier B.
      const result = computeHes(steadyHistory(12000, 100, 60, 1380, 420, 480, 5));
      expect(result.score).assertEqual(70);
      expect(result.tier).assertEqual(ReportTier.B);
      const change = engineWhatIf(result);
      if (change === null) {
        throw new Error('no counterfactual');
      }
      expect(change.hesId).assertEqual(HesComponentId.RHR);
      expect(change.componentId).assertEqual(ComponentId.RESTING_HR);
      expect(change.toRaw).assertEqual(75);
      expect(change.sentence).assertEqual(
        'A resting heart rate of 75 bpm instead of 100 bpm would be enough for Tier A, ' +
          'with everything else unchanged.');
      expect(resultWithChange(result, HesComponentId.RHR, 75).tier).assertEqual(ReportTier.A);
      expect(resultWithChange(result, HesComponentId.RHR, 80).tier).assertEqual(ReportTier.B);
    });
  });
}
