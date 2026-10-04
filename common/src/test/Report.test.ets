import { describe, it, expect } from '@ohos/hypium';
import {
  BENEFIT_FULL_LABEL,
  BENEFIT_NONE_LABEL,
  BENEFIT_PARTIAL_LABEL,
  benefitLabel,
  benefitLevel,
  benefitReason,
  discountPct
} from '../main/ets/report/Benefit';
import { HesProfile } from '../main/ets/hes/HesTypes';
import {
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
import {
  PREVIEW_DEFAULT_ID,
  PREVIEW_PERIOD_ISO,
  previewPersonas,
  previewReport,
  previewReports
} from '../main/ets/report/PreviewReports';
import { dayStateLabel, metricSpoken, scoreSpoken, wearSpoken } from '../main/ets/report/ReportSpeech';
import { periodDayIso, periodDaySpoken } from '../main/ets/report/ReportDates';
import { validateTierClaimJson } from '../main/ets/claim/ClaimValidation';
import { buildTierClaim, encodeTierClaim } from '../main/ets/claim/TierClaimCodec';
import { buildCardDigest, encodeCardDigest } from '../main/ets/card/CardDigest';
import { HealthStatus } from '../main/ets/health/HealthRecords';

// The expected result of one persona: the fixed table of the plan.
function expectPersona(id: string, hes: number, tier: string, coverage: number, confidence: string,
  benefit: string, eligible: boolean): void {
  const r: PersonaReport = previewReport(id);
  expect(r.id).assertEqual(id);
  expect(r.hes).assertEqual(hes);
  expect(r.tier).assertEqual(tier);
  expect(r.coveragePct).assertEqual(coverage);
  expect(r.confidence).assertEqual(confidence);
  expect(r.benefit).assertEqual(benefit);
  expect(r.eligible).assertEqual(eligible);
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

function component(r: PersonaReport, id: string): ComponentRow {
  for (let i = 0; i < r.components.length; i++) {
    if (r.components[i].id === id) {
      return r.components[i];
    }
  }
  return r.components[0];
}

export default function reportTest() {
  describe('Report', () => {
    it('benefitLevel: every combination of eligible, tier and score', 0, () => {
      const tiers = [ReportTier.A, ReportTier.B, ReportTier.C, ReportTier.NONE];
      for (let t = 0; t < tiers.length; t++) {
        // Not eligible or no score: never a benefit, whatever the tier.
        expect(benefitLevel(false, tiers[t], true)).assertEqual(BenefitLevel.NONE);
        expect(benefitLevel(false, tiers[t], false)).assertEqual(BenefitLevel.NONE);
        expect(benefitLevel(true, tiers[t], false)).assertEqual(BenefitLevel.NONE);
      }
      expect(benefitLevel(true, ReportTier.A, true)).assertEqual(BenefitLevel.FULL);
      expect(benefitLevel(true, ReportTier.B, true)).assertEqual(BenefitLevel.PARTIAL);
      expect(benefitLevel(true, ReportTier.C, true)).assertEqual(BenefitLevel.NONE);
      expect(benefitLevel(true, ReportTier.NONE, true)).assertEqual(BenefitLevel.NONE);
      expect(benefitLevel(true, 'D', true)).assertEqual(BenefitLevel.NONE);
    });

    it('discount per profile: health 15 / 8 / 0, life 10 / 5 / 0, never negative', 0, () => {
      expect(discountPct(HesProfile.HEALTH_WELLNESS, BenefitLevel.FULL)).assertEqual(15);
      expect(discountPct(HesProfile.HEALTH_WELLNESS, BenefitLevel.PARTIAL)).assertEqual(8);
      expect(discountPct(HesProfile.HEALTH_WELLNESS, BenefitLevel.NONE)).assertEqual(0);
      expect(discountPct(HesProfile.LONGEVITY_WELLNESS, BenefitLevel.FULL)).assertEqual(10);
      expect(discountPct(HesProfile.LONGEVITY_WELLNESS, BenefitLevel.PARTIAL)).assertEqual(5);
      expect(discountPct(HesProfile.LONGEVITY_WELLNESS, BenefitLevel.NONE)).assertEqual(0);
      expect(discountPct(HesProfile.HEALTH_WELLNESS, 'unknown')).assertEqual(0);
    });

    it('benefit labels and reasons are readable text, never an enum name', 0, () => {
      expect(benefitLabel(BenefitLevel.FULL)).assertEqual(BENEFIT_FULL_LABEL);
      expect(benefitLabel(BenefitLevel.PARTIAL)).assertEqual(BENEFIT_PARTIAL_LABEL);
      expect(benefitLabel(BenefitLevel.NONE)).assertEqual(BENEFIT_NONE_LABEL);
      expect(benefitLabel('anything')).assertEqual(BENEFIT_NONE_LABEL);
      expect(benefitReason(true, ReportTier.A, true, false, 0)).assertEqual('Eligible');
      expect(benefitReason(true, ReportTier.B, true, false, 1)).assertEqual('Score B');
      expect(benefitReason(true, ReportTier.C, true, false, 0)).assertEqual('Score C');
      expect(benefitReason(false, ReportTier.B, true, true, 3)).assertEqual('3 suspicious breaks');
      expect(benefitReason(false, ReportTier.B, true, true, 1)).assertEqual('1 suspicious break');
      expect(benefitReason(false, ReportTier.B, true, false, 0)).assertEqual('Wear below the required days');
      expect(benefitReason(false, ReportTier.NONE, false, false, 0)).assertEqual('Not enough data yet');
    });

    it('preview: the six personas equal the expected results', 0, () => {
      expect(previewReports().length).assertEqual(6);
      expectPersona('ania', 92, ReportTier.A, 100, ReportConfidence.HIGH, BenefitLevel.FULL, true);
      expectPersona('marek', 75, ReportTier.B, 88, ReportConfidence.HIGH, BenefitLevel.NONE, false);
      expectPersona('kasia', 71, ReportTier.B, 75, ReportConfidence.MEDIUM, BenefitLevel.PARTIAL, true);
      expectPersona('tomek', 79, ReportTier.B, 93, ReportConfidence.HIGH, BenefitLevel.PARTIAL, true);
      expectPersona('ewa', 58, ReportTier.C, 80, ReportConfidence.HIGH, BenefitLevel.NONE, true);
      expectPersona('ola', HES_NONE, ReportTier.NONE, 48, ReportConfidence.INSUFFICIENT, BenefitLevel.NONE,
        false);
    });

    it('preview: notes of the expected results (flag, breaks, one point to A, no score)', 0, () => {
      const marek = previewReport('marek');
      expect(marek.wear.flagged).assertTrue();
      expect(marek.wear.suspicious).assertEqual(3);
      expect(marek.wear.totalDays - marek.wear.compliantDays).assertEqual(4);
      expect(marek.benefitReason).assertEqual('3 suspicious breaks');
      const kasia = previewReport('kasia');
      expect(kasia.wear.suspicious).assertEqual(1);
      expect(kasia.wear.flagged).assertFalse();
      expect(previewReport('tomek').pointsToNext).assertEqual(1);
      expect(previewReport('ania').pointsToNext).assertEqual(0);
      expect(previewReport('ania').benefitReason).assertEqual('Eligible');
      expect(previewReport('ewa').benefitReason).assertEqual('Score C');
      const ola = previewReport('ola');
      expect(hasScore(ola)).assertFalse();
      expect(ola.pointsToNext).assertEqual(POINTS_UNKNOWN);
      expect(ola.benefitReason).assertEqual('Not enough data yet');
    });

    it('preview: the stored benefit is the one benefitLevel gives', 0, () => {
      const all = previewReports();
      for (let i = 0; i < all.length; i++) {
        expect(all[i].benefit).assertEqual(benefitLevel(all[i].eligible, all[i].tier, hasScore(all[i])));
      }
    });

    it('preview: weights of the available components add up to 100 (±1)', 0, () => {
      const all = previewReports();
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

    it('preview: component scores weighted by their weights give the score (±1)', 0, () => {
      const all = previewReports();
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

    it('preview: eight components each, a missing one has no value, no score and no bar', 0, () => {
      const all = previewReports();
      for (let i = 0; i < all.length; i++) {
        expect(all[i].components.length).assertEqual(8);
        for (let c = 0; c < all[i].components.length; c++) {
          const row = all[i].components[c];
          expect(row.bars7.length).assertEqual(7);
          if (!row.available) {
            expect(row.score).assertEqual(HES_NONE);
            expect(row.raw).assertEqual('');
            for (let b = 0; b < row.bars7.length; b++) {
              expect(row.bars7[b] < 0).assertTrue();
            }
          } else {
            expect(row.raw.length > 0).assertTrue();
            expect(row.unit.length > 0).assertTrue();
          }
        }
      }
      expect(component(previewReport('tomek'), ComponentId.HRV).available).assertFalse();
      expect(component(previewReport('ania'), ComponentId.HRV).available).assertTrue();
    });

    it('preview: thirty days each, and the day states agree with the wear summary', 0, () => {
      const all = previewReports();
      for (let i = 0; i < all.length; i++) {
        const r = all[i];
        expect(r.wear.totalDays).assertEqual(30);
        expect(r.wear.days.length).assertEqual(30);
        for (let d = 0; d < r.wear.days.length; d++) {
          expect(r.wear.days[d].n).assertEqual(d + 1);
          expect(r.wear.days[d].wornPct >= 0 && r.wear.days[d].wornPct <= 100).assertTrue();
        }
        const notCompliant = countDays(r, DayState.SHORT) + countDays(r, DayState.SUSPICIOUS) +
          countDays(r, DayState.UNKNOWN);
        expect(r.wear.compliantDays).assertEqual(30 - notCompliant);
        expect(r.wear.suspicious).assertEqual(countDays(r, DayState.SUSPICIOUS));
        // One break never flags.
        if (r.wear.suspicious < 2) {
          expect(r.wear.flagged).assertFalse();
        }
      }
      const marek = previewReport('marek');
      expect(marek.wear.days[16].state).assertEqual(DayState.SUSPICIOUS);
      expect(countDays(marek, DayState.SICK)).assertEqual(3);
      expect(countDays(marek, DayState.SHORT)).assertEqual(1);
    });

    it('preview: Ola has counters below the minimum instead of a score', 0, () => {
      const ola = previewReport('ola');
      const sleep = component(ola, ComponentId.SLEEP_REGULARITY);
      expect(sleep.validCount).assertEqual(9);
      expect(sleep.minCount).assertEqual(14);
      const rhr = component(ola, ComponentId.RESTING_HR);
      expect(rhr.validCount).assertEqual(6);
      expect(rhr.minCount).assertEqual(10);
      const steps = component(ola, ComponentId.STEPS);
      expect(steps.validCount).assertEqual(14);
      expect(steps.minCount).assertEqual(14);
      for (let c = 0; c < ola.components.length; c++) {
        expect(ola.components[c].score).assertEqual(HES_NONE);
      }
    });

    it('preview: persona list, default persona and an unknown id', 0, () => {
      const refs = previewPersonas();
      expect(refs.length).assertEqual(6);
      expect(refs[0].id).assertEqual(PREVIEW_DEFAULT_ID);
      expect(refs[0].name).assertEqual('Ania');
      expect(refs[5].name).assertEqual('Ola');
      expect(previewReport('nobody').id).assertEqual(PREVIEW_DEFAULT_ID);
      expect(previewReport('').id).assertEqual(PREVIEW_DEFAULT_ID);
    });

    it('preview: the period is written the way the claim accepts it', 0, () => {
      const r = previewReport('tomek');
      expect(r.periodIso).assertEqual(PREVIEW_PERIOD_ISO);
      const issuedAt = 1791000000000;
      const json = encodeTierClaim(buildTierClaim(r.periodIso, r.tier, r.eligible, 'AAAAAAAAAAAAAAAAAAAAAA',
        issuedAt, '0a1b2c3d'));
      expect(validateTierClaimJson(json, issuedAt) !== null).assertTrue();
    });

    it('the home-screen card takes coverage and "score ready" from a report, never the tier', 0, () => {
      const ania = previewReport('ania');
      const json = encodeCardDigest(buildCardDigest(HealthStatus.DEMO, ania.coveragePct, hasScore(ania)));
      expect(json.indexOf('"coveragePct":100') >= 0).assertTrue();
      expect(json.indexOf('"resultReady":true') >= 0).assertTrue();
      expect(json.indexOf('92')).assertEqual(-1);
      const ola = previewReport('ola');
      const olaJson = encodeCardDigest(buildCardDigest(HealthStatus.DEMO, ola.coveragePct, hasScore(ola)));
      expect(olaJson.indexOf('"coveragePct":48') >= 0).assertTrue();
      expect(olaJson.indexOf('"resultReady":false') >= 0).assertTrue();
    });

    it('spoken texts: score ring, metric tile, month bar', 0, () => {
      expect(scoreSpoken(previewReport('ania'))).assertEqual('Score 92, tier A, coverage 100 percent');
      expect(scoreSpoken(previewReport('ola'))).assertEqual('No score yet, coverage 48 percent');
      expect(metricSpoken('Steps', '9,412', '/day', true)).assertEqual('Steps, 9412 per day');
      expect(metricSpoken('Sleep', '7 h 24', 'min', true)).assertEqual('Sleep, 7 hours 24 minutes');
      expect(metricSpoken('Sleep regularity', '±22', 'min', true))
        .assertEqual('Sleep regularity, plus or minus 22 minutes');
      expect(metricSpoken('VO₂max', '82nd', 'percentile', true)).assertEqual('VO₂max, 82nd percentile');
      expect(metricSpoken('HRV', '', '', false)).assertEqual('HRV, not measured');
      expect(wearSpoken(previewReport('ania'))).assertEqual('28 of 30 days compliant, 2 short');
      expect(wearSpoken(previewReport('marek')))
        .assertEqual('26 of 30 days compliant, 1 short, 3 with a suspicious break, 3 marked as sick days');
    });

    it('day states read as words, an unknown state as no data', 0, () => {
      expect(dayStateLabel(DayState.COMPLIANT)).assertEqual('Compliant');
      expect(dayStateLabel(DayState.SHORT)).assertEqual('Short');
      expect(dayStateLabel(DayState.SUSPICIOUS)).assertEqual('Suspicious break');
      expect(dayStateLabel(DayState.SICK)).assertEqual('Sick day');
      expect(dayStateLabel(DayState.UNKNOWN)).assertEqual('No data');
      expect(dayStateLabel('')).assertEqual('No data');
    });

    it('days of the period have dates: day 1 is the first day, day 30 the last', 0, () => {
      expect(periodDayIso(PREVIEW_PERIOD_ISO, 1)).assertEqual('2026-09-04');
      expect(periodDayIso(PREVIEW_PERIOD_ISO, 17)).assertEqual('2026-09-20');
      expect(periodDayIso(PREVIEW_PERIOD_ISO, 27)).assertEqual('2026-09-30');
      expect(periodDayIso(PREVIEW_PERIOD_ISO, 28)).assertEqual('2026-10-01');
      expect(periodDayIso(PREVIEW_PERIOD_ISO, 30)).assertEqual('2026-10-03');
      expect(periodDayIso(PREVIEW_PERIOD_ISO, 0)).assertEqual('');
      expect(periodDayIso(PREVIEW_PERIOD_ISO, 1.5)).assertEqual('');
      expect(periodDayIso('4 Sep – 3 Oct', 1)).assertEqual('');
      expect(periodDayIso('', 1)).assertEqual('');
    });

    it('a day is spoken as its date and its state', 0, () => {
      expect(periodDaySpoken(PREVIEW_PERIOD_ISO, 14, DayState.SUSPICIOUS)).assertEqual('17 September, suspicious break');
      expect(periodDaySpoken(PREVIEW_PERIOD_ISO, 30, DayState.COMPLIANT)).assertEqual('3 October, compliant');
      expect(periodDaySpoken(PREVIEW_PERIOD_ISO, 8, DayState.SICK)).assertEqual('11 September, sick day');
      expect(periodDaySpoken('not a date', 3, DayState.SHORT)).assertEqual('Day 3, short');
    });
  });
}
