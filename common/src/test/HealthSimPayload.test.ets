import { describe, it, expect } from '@ohos/hypium';
import { HealthScope, ALL_HEALTH_SCOPES } from '../main/ets/health/HealthConnection';
import {
  decodeHealthSimPayload,
  encodeHealthSimPayload,
  HEALTH_SIM_MAX_CHARS,
  HEALTH_SIM_OUTDATED_TEXT,
  HEALTH_SIM_PARAM,
  HEALTH_SIM_SCHEMA,
  HEALTH_SIM_SOURCE,
  HEALTH_SIM_VERSION,
  healthSimPayloadFromPersonas,
  healthSimPerson,
  HealthSimPayload,
  HealthSimPerson,
  HealthSimReadStatus,
  readHealthSimPayload,
  withScopes
} from '../main/ets/health/HealthSimPayload';
import { HES_PROFILES } from '../main/ets/hes/HesModel';
import { HES_PERSONA_END_DATE, HesPersonas } from '../main/ets/hes/HesPersonas';
import { HesProfile, HesStatus, HesTier } from '../main/ets/hes/HesTypes';
import { WearPersonas } from '../main/ets/wear/WearPersonas';
import {
  ENGINE_SOURCE,
  engineDayDetails,
  engineDayDetailsFrom,
  engineReport,
  engineReportFromPerson,
  engineSession,
  engineSessionFrom,
  HEALTH_SIM_LABEL
} from '../main/ets/report/EngineReports';
import { hasScore, PersonaReport } from '../main/ets/report/ReportModels';

const HW = HesProfile.HEALTH_WELLNESS;
const LW = HesProfile.LONGEVITY_WELLNESS;

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

function reportOf(person: HealthSimPerson, profile: HesProfile): PersonaReport {
  return engineReportFromPerson(person, engineSessionFrom(person), profile);
}

// Replaces the first occurrence of `from` in `text`.
function swap(text: string, from: string, to: string): string {
  const at = text.indexOf(from);
  return at < 0 ? text : text.substring(0, at) + to + text.substring(at + from.length);
}

// The text of one person's list of days, from `"days":[` to the end of the list.
function daysText(text: string, id: string): string {
  const start = text.indexOf(`"personaId":"${id}"`);
  const from = text.indexOf('"days":[', start);
  const to = text.indexOf('],"crf":', from);
  return text.substring(from, to + 1);
}

export default function healthSimPayloadTest() {
  describe('Health Sim payload: the version 2 contract', () => {
    it('the parameter, schema, version and outdated text are fixed', 0, () => {
      expect(HEALTH_SIM_PARAM).assertEqual('fwhs1');
      expect(HEALTH_SIM_SCHEMA).assertEqual('fairwear.health-export');
      expect(HEALTH_SIM_VERSION).assertEqual(2);
      expect(HEALTH_SIM_SOURCE).assertEqual('Health Sim');
      expect(HEALTH_SIM_OUTDATED_TEXT).assertEqual('Health Sim data format is outdated — update Health Sim');
      const text = encodeHealthSimPayload(healthSimPayloadFromPersonas());
      expect(text.indexOf('{"schema":"fairwear.health-export","version":2,"source":"Health Sim"') === 0)
        .assertTrue();
      const read = readHealthSimPayload(text);
      expect(read.status).assertEqual(HealthSimReadStatus.OK);
      expect(read.payload !== null).assertTrue();
    });

    it('the six people round-trip unchanged: decode(encode(x)) equals x', 0, () => {
      const original = healthSimPayloadFromPersonas();
      const p = decoded();
      expect(p).assertDeepEquals(original);
      expect(p.people.length).assertEqual(6);
      expect(p.exportedAt).assertEqual('2026-10-04');
      for (let i = 0; i < HesPersonas.IDS.length; i++) {
        const id = HesPersonas.IDS[i];
        const person = personOf(p, id);
        expect(person.name).assertEqual(HesPersonas.displayName(id));
        expect(person.history).assertDeepEquals(HesPersonas.history(id));
        expect(person.today).assertDeepEquals(HesPersonas.today(id));
        expect(person.wear).assertDeepEquals(WearPersonas.month(id));
      }
      expect(encodeHealthSimPayload(p)).assertEqual(encodeHealthSimPayload(original));
    });

    it('a missing reading stays an absent key: never 0, never -1, never null', 0, () => {
      const text = encodeHealthSimPayload(healthSimPayloadFromPersonas());
      // Kasia's oldest day has no reading at all (her watch has 20 days of steps and 28 days of history).
      const kasiaDays = daysText(text, 'kasia');
      expect(kasiaDays.indexOf('"days":[{"date":"2026-09-06"}')).assertEqual(0);
      const first = kasiaDays.substring(kasiaDays.indexOf('{'), kasiaDays.indexOf('}') + 1);
      expect(first).assertEqual('{"date":"2026-09-06"}');
      expect(first.indexOf('"steps"')).assertEqual(-1);
      expect(first.indexOf('-1')).assertEqual(-1);
      // In every person's days no reading is written as -1 or null.
      for (let i = 0; i < HesPersonas.IDS.length; i++) {
        const days = daysText(text, HesPersonas.IDS[i]);
        expect(days.indexOf(':-1')).assertEqual(-1);
        expect(days.indexOf('null')).assertEqual(-1);
      }
      // Tomek's watch has no HRV at all: no hrv key anywhere in his days or today.
      const start = text.indexOf('"personaId":"tomek"');
      const end = text.indexOf('"personaId":"ewa"');
      expect(text.substring(start, end).indexOf('"hrv"')).assertEqual(-1);
      // And decoded, the reading is undefined, not a number.
      const kasia = personOf(decoded(), 'kasia');
      expect(kasia.history.days[0].steps).assertUndefined();
      expect(kasia.history.days[0].sleep).assertUndefined();
      expect(kasia.history.days[27].steps !== undefined).assertTrue();
    });

    it('a day key that is absent or null is fine', 0, () => {
      const good = encodeHealthSimPayload(healthSimPayloadFromPersonas());
      const withNull = good.replace(/"steps":\d+/, '"steps":null');
      const p = decodeHealthSimPayload(withNull);
      expect(p !== null).assertTrue();
      const ania = personOf(p === null ? new HealthSimPayload() : p, 'ania');
      // The first "steps" key in the text is the running day's.
      expect(ania.today.steps).assertUndefined();
      expect(ania.history.days[0].steps !== undefined).assertTrue();
      const noSleep = decodeHealthSimPayload(good.replace(/"sleep":\{[^}]*\}/, '"sleep":null'));
      expect(noSleep !== null).assertTrue();
    });

    it('size: six people and Ania alone fit in one Want parameter', 0, () => {
      const all = healthSimPayloadFromPersonas();
      const six = encodeHealthSimPayload(all);
      all.people = [personOf(all, 'ania')];
      const one = encodeHealthSimPayload(all);
      // Measured when the test was written: 31067 characters for the six people, 6993 for Ania alone.
      expect(six.length < 60000).assertTrue();
      expect(six.length < HEALTH_SIM_MAX_CHARS).assertTrue();
      expect(one.length < HEALTH_SIM_MAX_CHARS).assertTrue();
      expect(one.length < six.length).assertTrue();
    });
  });

  describe('Health Sim payload: refused texts', () => {
    it('a version 1 text is outdated: no payload, and the outdated text is the one to show', 0, () => {
      const old = '{"v":1,"source":"Health Sim","end":"2026-10-03","people":[{"id":"ania","name":"Ania",' +
        '"days":[["2026-10-03",8200,16,6,56,1320,360,426,55,-1,-1,-1]],"wear":[]}]}';
      const read = readHealthSimPayload(old);
      expect(read.status).assertEqual(HealthSimReadStatus.OUTDATED);
      expect(read.payload === null).assertTrue();
      expect(decodeHealthSimPayload(old) === null).assertTrue();
      // A text of the right schema with "version":1 is outdated too.
      const good = encodeHealthSimPayload(healthSimPayloadFromPersonas());
      const v1 = swap(good, '"version":2', '"version":1');
      expect(v1 === good).assertFalse();
      const readV1 = readHealthSimPayload(v1);
      expect(readV1.status).assertEqual(HealthSimReadStatus.OUTDATED);
      expect(readV1.payload === null).assertTrue();
      expect(decodeHealthSimPayload(v1) === null).assertTrue();
      // So is a version from the future, and another schema.
      expect(readHealthSimPayload(swap(good, '"version":2', '"version":3')).status)
        .assertEqual(HealthSimReadStatus.OUTDATED);
      expect(readHealthSimPayload(swap(good, 'fairwear.health-export', 'something.else')).status)
        .assertEqual(HealthSimReadStatus.OUTDATED);
    });

    it('garbage and wrong shapes are invalid: no payload, never a throw', 0, () => {
      const good = encodeHealthSimPayload(healthSimPayloadFromPersonas());
      const bad: string[] = [
        '',
        '{',
        '[]',
        'null',
        '42',
        '"text"',
        // A string where a number is expected.
        good.replace(/"steps":(\d+)/, '"steps":"$1"'),
        good.replace(/"percentile":(\d+)/, '"percentile":"$1"'),
        swap(good, '"peakHr":', '"peakHr":"high","x":'),
        // An unknown persona id, and one person twice.
        swap(good, '"personaId":"ania"', '"personaId":"nobody"'),
        swap(good, '"personaId":"marek"', '"personaId":"ania"'),
        // No people; a person without the running day; a date that is not a date.
        swap(good, '"people":[', '"people":[],"x":['),
        swap(good, '"today":', '"tomorrow":'),
        swap(good, '"date":"2026-09-', '"date":"26-09-'),
        // A sleep object without a wake time; an HRV night without a protocol.
        good.replace(/"wakeMin":\d+,/, ''),
        good.replace(/,"protocol":"nocturnal"/, ''),
        // A wear row one field short, a text where a number belongs, a broken break row.
        good.replace(/\["2026-09-04",(\d),(\d+),(\d+),(\d+),\[/, '["2026-09-04",$1,$2,$3,['),
        good.replace(/\["2026-09-04",(\d),(\d+),/, '["2026-09-04",$1,"x",'),
        swap(good, ',[[', ',[["x"]')
      ];
      for (let i = 0; i < bad.length; i++) {
        const read = readHealthSimPayload(bad[i]);
        expect(read.status).assertEqual(HealthSimReadStatus.INVALID);
        expect(read.payload === null).assertTrue();
        expect(decodeHealthSimPayload(bad[i]) === null).assertTrue();
      }
    });

    it('a text longer than the limit is refused before it is parsed', 0, () => {
      const good = encodeHealthSimPayload(healthSimPayloadFromPersonas());
      let longText = good;
      while (longText.length <= HEALTH_SIM_MAX_CHARS) {
        longText = longText + ' ';
      }
      const read = readHealthSimPayload(longText);
      expect(read.status).assertEqual(HealthSimReadStatus.INVALID);
      expect(read.payload === null).assertTrue();
      expect(decodeHealthSimPayload(longText) === null).assertTrue();
    });
  });

  describe('Health Sim payload: reports from the data', () => {
    it('Ania from a version 2 payload: 92 · A', 0, () => {
      const person = personOf(decoded(), 'ania');
      const r = engineReportFromPerson(person, engineSessionFrom(person));
      expect(r.hes).assertEqual(92);
      expect(r.tier).assertEqual('A');
      expect(r.components[0].source).assertEqual(HEALTH_SIM_LABEL);
    });

    it('for every persona and both profiles the report from the payload equals the built-in one', 0, () => {
      const p = decoded();
      expect(HEALTH_SIM_LABEL).assertEqual('Health Sim · Simulated data');
      for (let q = 0; q < HES_PROFILES.length; q++) {
        for (let i = 0; i < HesPersonas.IDS.length; i++) {
          const id = HesPersonas.IDS[i];
          const person = personOf(p, id);
          const fromSim = reportOf(person, HES_PROFILES[q]);
          const builtIn = engineReport(id, HES_PROFILES[q]);
          expect(fromSim.id).assertEqual(builtIn.id);
          expect(fromSim.profile).assertEqual(builtIn.profile);
          expect(fromSim.hes).assertEqual(builtIn.hes);
          expect(fromSim.tier).assertEqual(builtIn.tier);
          expect(fromSim.coveragePct).assertEqual(builtIn.coveragePct);
          expect(fromSim.coverageText).assertEqual(builtIn.coverageText);
          expect(fromSim.confidence).assertEqual(builtIn.confidence);
          expect(fromSim.pointsToNext).assertEqual(builtIn.pointsToNext);
          expect(fromSim.whatIf).assertEqual(builtIn.whatIf);
          expect(fromSim.eligible).assertEqual(builtIn.eligible);
          expect(fromSim.benefit).assertEqual(builtIn.benefit);
          expect(fromSim.wear).assertDeepEquals(builtIn.wear);
          expect(fromSim.live).assertDeepEquals(builtIn.live);
          expect(fromSim.components.length).assertEqual(builtIn.components.length);
          for (let c = 0; c < builtIn.components.length; c++) {
            const a = fromSim.components[c];
            const b = builtIn.components[c];
            expect(a.id).assertEqual(b.id);
            expect(a.score).assertEqual(b.score);
            expect(a.scoreExact).assertEqual(b.scoreExact);
            expect(a.raw).assertEqual(b.raw);
            expect(a.rawText).assertEqual(b.rawText);
            expect(a.weightText).assertEqual(b.weightText);
            expect(a.countText).assertEqual(b.countText);
            expect(a.bars7).assertDeepEquals(b.bars7);
            // Only the source line differs.
            expect(a.source).assertEqual(b.available ? HEALTH_SIM_LABEL : '');
            expect(b.source).assertEqual(b.available ? ENGINE_SOURCE : '');
          }
        }
      }
      for (let i = 0; i < HesPersonas.IDS.length; i++) {
        const person = personOf(p, HesPersonas.IDS[i]);
        expect(engineDayDetailsFrom(person)).assertDeepEquals(engineDayDetails(HesPersonas.IDS[i]));
      }
      const marek = reportOf(personOf(p, 'marek'), HW);
      expect(marek.wear.flagged).assertTrue();
      expect(marek.eligible).assertFalse();
    });

    it('closing a day on Health Sim data continues the persona series, as the built-in session does', 0, () => {
      const person = personOf(decoded(), 'ewa');
      const fromSim = engineSessionFrom(person);
      const builtIn = engineSession('ewa');
      fromSim.closeDay();
      builtIn.closeDay();
      expect(fromSim.history()).assertDeepEquals(builtIn.history());
      expect(fromSim.current(HW)).assertDeepEquals(builtIn.current(HW));
      expect(fromSim.current(LW)).assertDeepEquals(builtIn.current(LW));
      fromSim.resetDemo();
      builtIn.resetDemo();
      expect(fromSim.history()).assertDeepEquals(builtIn.history());
      expect(fromSim.current(HW)).assertDeepEquals(builtIn.current(HW));
    });
  });

  describe('Health Sim payload: consent scopes', () => {
    it('a data type the user did not allow arrives as no value; the rest is unchanged', 0, () => {
      const all = healthSimPayloadFromPersonas();
      const scopes = ALL_HEALTH_SCOPES.filter((s: HealthScope) => s !== HealthScope.HRV);
      const p = withScopes(all, scopes);
      const before = personOf(all, 'ania');
      const after = personOf(p, 'ania');
      expect(after.history.days.length).assertEqual(before.history.days.length);
      for (let i = 0; i < after.history.days.length; i++) {
        expect(after.history.days[i].hrv).assertUndefined();
        expect(after.history.days[i].steps).assertEqual(before.history.days[i].steps);
        expect(after.history.days[i].sleep).assertDeepEquals(before.history.days[i].sleep);
      }
      expect(after.today.hrv).assertUndefined();
      expect(after.history.crf).assertDeepEquals(before.history.crf);
      expect(after.wear).assertDeepEquals(before.wear);
      // Everything allowed changes nothing; the original is not touched.
      expect(encodeHealthSimPayload(withScopes(all, ALL_HEALTH_SCOPES))).assertEqual(encodeHealthSimPayload(all));
      expect(personOf(all, 'ania').history).assertDeepEquals(HesPersonas.history('ania'));
      // The text has no HRV key for her, and the scoped payload survives the round trip.
      const text = encodeHealthSimPayload(p);
      const start = text.indexOf('"personaId":"ania"');
      expect(text.substring(start, text.indexOf('"personaId":"marek"')).indexOf('"hrv"')).assertEqual(-1);
      expect(encodeHealthSimPayload(decodeHealthSimPayload(text) as HealthSimPayload)).assertEqual(text);
    });

    it('without HRV Ania has 93 · A · 92.5%; without sleep no score, and the coverage is still reported', 0, () => {
      const all = healthSimPayloadFromPersonas();
      const noHrvScopes = ALL_HEALTH_SCOPES.filter((s: HealthScope) => s !== HealthScope.HRV);
      const noHrv = personOf(withScopes(all, noHrvScopes), 'ania');
      const r = engineReportFromPerson(noHrv, engineSessionFrom(noHrv, noHrvScopes));
      expect(r.hes).assertEqual(93);
      expect(r.tier).assertEqual('A');
      expect(r.coveragePct).assertEqual(92.5);
      expect(r.confidence).assertEqual('High');

      const noSleepScopes = ALL_HEALTH_SCOPES.filter((s: HealthScope) => s !== HealthScope.SLEEP);
      const noSleep = personOf(withScopes(all, noSleepScopes), 'ania');
      const s = engineSessionFrom(noSleep, noSleepScopes);
      const result = s.current(HW);
      // A Core component (sleep) is missing: no score and no tier; the coverage is the 72.5% that remains.
      expect(result.status).assertEqual(HesStatus.INSUFFICIENT_DATA);
      expect(result.score).assertUndefined();
      expect(result.tier).assertEqual(HesTier.NONE);
      expect(result.coverage).assertEqual(72.5);
      const noScore = engineReportFromPerson(noSleep, s);
      expect(hasScore(noScore)).assertFalse();
      expect(noScore.coveragePct).assertEqual(72.5);
      expect(noScore.coverageText).assertEqual('72.5%');
    });

    it('without VO2MAX the estimates are gone and without WORKOUTS the recovery sessions', 0, () => {
      const all = healthSimPayloadFromPersonas();
      const before = personOf(all, 'tomek');
      expect(before.history.crf.length > 0).assertTrue();
      expect(before.history.hrr.length > 0).assertTrue();
      const noCrf = personOf(withScopes(all, ALL_HEALTH_SCOPES.filter((s: HealthScope) =>
        s !== HealthScope.VO2MAX)), 'tomek');
      expect(noCrf.history.crf.length).assertEqual(0);
      expect(noCrf.history.hrr).assertDeepEquals(before.history.hrr);
      const noHrr = personOf(withScopes(all, ALL_HEALTH_SCOPES.filter((s: HealthScope) =>
        s !== HealthScope.WORKOUTS)), 'tomek');
      expect(noHrr.history.hrr.length).assertEqual(0);
      expect(noHrr.history.crf).assertDeepEquals(before.history.crf);
      expect(personOf(all, 'tomek').history.crf.length > 0).assertTrue();
    });
  });

  describe('Health Sim payload: the persona end date', () => {
    it('the export carries the running day, and the history ends the day before it', 0, () => {
      const p = decoded();
      for (let i = 0; i < HesPersonas.IDS.length; i++) {
        const person = personOf(p, HesPersonas.IDS[i]);
        const days = person.history.days;
        expect(days[days.length - 1].date).assertEqual(HES_PERSONA_END_DATE);
        expect(person.today.date).assertEqual('2026-10-04');
        expect(person.wear[person.wear.length - 1].date).assertEqual(HES_PERSONA_END_DATE);
      }
      expect(personOf(p, 'ola').history.days.length).assertEqual(16);
      expect(personOf(p, 'ania').history.days.length).assertEqual(28);
    });
  });
}
