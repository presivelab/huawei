import { describe, it, expect } from '@ohos/hypium';
import { HealthScope, ALL_HEALTH_SCOPES } from '../main/ets/health/HealthConnection';
import {
  decodeHealthSimPayload,
  encodeHealthSimPayload,
  HEALTH_SIM_MAX_CHARS,
  HEALTH_SIM_PARAM,
  healthSimPayloadFromPersonas,
  healthSimPerson,
  HealthSimPayload,
  HealthSimPerson,
  withScopes
} from '../main/ets/health/HealthSimPayload';
import { HesPersonas } from '../main/ets/hes/HesPersonas';
import { copyHesDay, HesDay, HES_MISSING } from '../main/ets/hes/HesTypes';
import { WearPersonas } from '../main/ets/wear/WearPersonas';
import {
  engineDayDetails,
  engineDayDetailsFrom,
  engineReport,
  engineReportFromPerson,
  engineSession,
  engineSessionFrom,
  HEALTH_SIM_LABEL
} from '../main/ets/report/EngineReports';
import { ComponentRow, PersonaReport } from '../main/ets/report/ReportModels';

function decoded(): HealthSimPayload {
  const p = decodeHealthSimPayload(encodeHealthSimPayload(healthSimPayloadFromPersonas()));
  expect(p !== null).assertTrue();
  return p === null ? new HealthSimPayload() : p;
}

function personOf(p: HealthSimPayload, id: string): HealthSimPerson {
  const person = healthSimPerson(p, id);
  expect(person !== null).assertTrue();
  return person === null ? new HealthSimPerson() : person;
}

// The built-in report with the source line Health Sim reports carry.
function withSimSource(r: PersonaReport): PersonaReport {
  const rows: ComponentRow[] = [];
  for (let i = 0; i < r.components.length; i++) {
    const c = r.components[i];
    rows.push({
      id: c.id,
      label: c.label,
      score: c.score,
      raw: c.raw,
      unit: c.unit,
      weightPct: c.weightPct,
      available: c.available,
      validCount: c.validCount,
      minCount: c.minCount,
      bars7: c.bars7,
      source: c.available ? HEALTH_SIM_LABEL : c.source
    });
  }
  return {
    id: r.id,
    name: r.name,
    profile: r.profile,
    period: r.period,
    periodIso: r.periodIso,
    hes: r.hes,
    tier: r.tier,
    coveragePct: r.coveragePct,
    confidence: r.confidence,
    eligible: r.eligible,
    benefit: r.benefit,
    benefitReason: r.benefitReason,
    discountPct: r.discountPct,
    pointsToNext: r.pointsToNext,
    components: rows,
    wear: r.wear,
    live: r.live,
    whatIf: r.whatIf
  };
}

// Replaces the first occurrence of `from` in `text`.
function swap(text: string, from: string, to: string): string {
  const at = text.indexOf(from);
  return at < 0 ? text : text.substring(0, at) + to + text.substring(at + from.length);
}

export default function healthSimPayloadTest() {
  describe('Health Sim payload', () => {
    it('the parameter is fwhs1 and the six people round-trip unchanged', 0, () => {
      expect(HEALTH_SIM_PARAM).assertEqual('fwhs1');
      const original = healthSimPayloadFromPersonas();
      const p = decoded();
      expect(p.people.length).assertEqual(6);
      expect(p.end).assertEqual('2026-10-03');
      for (let i = 0; i < HesPersonas.IDS.length; i++) {
        const id = HesPersonas.IDS[i];
        const person = personOf(p, id);
        expect(person.name).assertEqual(HesPersonas.displayName(id));
        expect(person.days).assertDeepEquals(HesPersonas.history(id));
        expect(person.wear).assertDeepEquals(WearPersonas.month(id));
      }
      expect(encodeHealthSimPayload(p)).assertEqual(encodeHealthSimPayload(original));
    });

    it('six people fit easily in one Want parameter', 0, () => {
      const text = encodeHealthSimPayload(healthSimPayloadFromPersonas());
      expect(text.length < 40000).assertTrue();
      expect(text.length < HEALTH_SIM_MAX_CHARS).assertTrue();
    });

    it('a report from the Health Sim data is the built-in report, with Health Sim as its source', 0, () => {
      const p = decoded();
      for (let i = 0; i < HesPersonas.IDS.length; i++) {
        const id = HesPersonas.IDS[i];
        const person = personOf(p, id);
        const r = engineReportFromPerson(person, engineSessionFrom(person));
        expect(r).assertDeepEquals(withSimSource(engineReport(id)));
        expect(engineDayDetailsFrom(person)).assertDeepEquals(engineDayDetails(id));
      }
      // The fixed results, read from the Health Sim data.
      const ania = engineReportFromPerson(personOf(p, 'ania'), engineSessionFrom(personOf(p, 'ania')));
      expect(ania.hes).assertEqual(92);
      expect(ania.tier).assertEqual('A');
      const marek = engineReportFromPerson(personOf(p, 'marek'), engineSessionFrom(personOf(p, 'marek')));
      expect(marek.wear.flagged).assertTrue();
      expect(marek.eligible).assertFalse();
    });

    it('closing a day on Health Sim data continues the persona series, as the built-in session does', 0, () => {
      const person = personOf(decoded(), 'ewa');
      const fromSim = engineSessionFrom(person);
      const builtIn = engineSession('ewa');
      expect(fromSim.closeDay()).assertDeepEquals(builtIn.closeDay());
      expect(fromSim.reset()).assertDeepEquals(builtIn.reset());
    });

    it('a history has to be one entry per calendar day, oldest first, ending on the end date', 0, () => {
      const make = (edit: (days: HesDay[]) => HesDay[]): string => {
        const payload = healthSimPayloadFromPersonas();
        payload.people[0].days = edit(payload.people[0].days);
        return encodeHealthSimPayload(payload);
      };
      expect(decodeHealthSimPayload(make((d: HesDay[]): HesDay[] => d)) !== null).assertTrue();
      // Every other day removed: the same number of entries would cover twice the days.
      expect(decodeHealthSimPayload(make((d: HesDay[]): HesDay[] =>
        d.filter((x: HesDay, i: number): boolean => i % 2 === 1))) === null).assertTrue();
      // One day twice, the order turned round, the last day not on the end date, a date that does not exist.
      expect(decodeHealthSimPayload(make((d: HesDay[]): HesDay[] => d.concat([d[d.length - 1]]))) === null)
        .assertTrue();
      expect(decodeHealthSimPayload(make((d: HesDay[]): HesDay[] => d.slice().reverse())) === null).assertTrue();
      expect(decodeHealthSimPayload(make((d: HesDay[]): HesDay[] => d.slice(0, d.length - 1))) === null)
        .assertTrue();
      expect(decodeHealthSimPayload(make((d: HesDay[]): HesDay[] => {
        const copy = d.slice();
        copy[0] = copyHesDay(copy[0]);
        copy[0].date = '2026-02-30';
        return copy;
      })) === null).assertTrue();
      // The same rule for the wear month.
      const wearGap = healthSimPayloadFromPersonas();
      wearGap.people[1].wear = wearGap.people[1].wear.slice(1, 10).concat(wearGap.people[1].wear.slice(11));
      expect(decodeHealthSimPayload(encodeHealthSimPayload(wearGap)) === null).assertTrue();
    });

    it('anything that is not a valid version-1 text gives null and never throws', 0, () => {
      const good = encodeHealthSimPayload(healthSimPayloadFromPersonas());
      expect(decodeHealthSimPayload('') === null).assertTrue();
      expect(decodeHealthSimPayload('{') === null).assertTrue();
      expect(decodeHealthSimPayload('[]') === null).assertTrue();
      expect(decodeHealthSimPayload('null') === null).assertTrue();
      expect(decodeHealthSimPayload(swap(good, '"v":1', '"v":2')) === null).assertTrue();
      expect(decodeHealthSimPayload(swap(good, '"id":"ania"', '"id":"nobody"')) === null).assertTrue();
      expect(decodeHealthSimPayload(swap(good, '"id":"marek"', '"id":"ania"')) === null).assertTrue();
      expect(decodeHealthSimPayload(swap(good, '"end":"2026-10-03"', '"end":"03.10.2026"')) === null)
        .assertTrue();
      expect(decodeHealthSimPayload(swap(good, '"people":[', '"people":[]')) === null).assertTrue();
      // A day row one field short, a text where a number belongs, a broken break row.
      const day = good.substring(good.indexOf('[["2026-'), good.indexOf(']', good.indexOf('[["2026-')) + 1);
      expect(decodeHealthSimPayload(swap(good, day, day.substring(0, day.lastIndexOf(',')) + ']')) === null)
        .assertTrue();
      expect(decodeHealthSimPayload(swap(good, day, swap(day, ',', ',"9529",'))) === null).assertTrue();
      expect(decodeHealthSimPayload(swap(good, ',[[', ',[["x"]')) === null).assertTrue();
      // Too long, refused before parsing.
      let longText = good;
      while (longText.length <= HEALTH_SIM_MAX_CHARS) {
        longText = longText + ' ';
      }
      expect(decodeHealthSimPayload(longText) === null).assertTrue();
    });

    it('a data type the user did not allow arrives as no value; the rest is unchanged', 0, () => {
      const all = healthSimPayloadFromPersonas();
      const scopes = ALL_HEALTH_SCOPES.filter((s: HealthScope) => s !== HealthScope.HRV);
      const p = withScopes(all, scopes);
      const before = personOf(all, 'ania');
      const after = personOf(p, 'ania');
      for (let i = 0; i < after.days.length; i++) {
        expect(after.days[i].hrvPercentile).assertEqual(HES_MISSING);
        expect(after.days[i].steps).assertEqual(before.days[i].steps);
        expect(after.days[i].vo2maxPercentile).assertEqual(before.days[i].vo2maxPercentile);
      }
      expect(after.wear).assertDeepEquals(before.wear);
      // Everything allowed changes nothing; the original is not touched.
      expect(encodeHealthSimPayload(withScopes(all, ALL_HEALTH_SCOPES))).assertEqual(encodeHealthSimPayload(all));
      expect(personOf(all, 'ania').days).assertDeepEquals(HesPersonas.history('ania'));
      // Without HRV Ania keeps a score, with less evidence.
      const r = engineReportFromPerson(after, engineSessionFrom(after));
      expect(r.coveragePct < 100).assertTrue();
    });
  });
}
