import { describe, it, expect } from '@ohos/hypium';
import { generatePersonaDay, HesPersonas, HesPersonaSpec } from '../main/ets/hes/HesPersonas';
import { HesSession } from '../main/ets/hes/HesSession';
import { HesComponentResult, HesDay, HesResult, HES_MISSING } from '../main/ets/hes/HesTypes';

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

export default function hesSessionTest() {
  describe('HES-Lite session: live values are shown, not scored', () => {
    it('a new session has the persona score and no live values', 0, () => {
      const session = HesPersonas.session('ania');
      expect(session.result()).assertDeepEquals(HesPersonas.result('ania'));
      expect(session.history()).assertDeepEquals(HesPersonas.history('ania'));
      expect(session.liveHeartRate()).assertEqual(HES_MISSING);
      expect(session.liveSteps()).assertEqual(HES_MISSING);
      expect(session.closedDays()).assertEqual(0);
    });

    it('S-19: setLive(200, 99999) does not change the score', 0, () => {
      for (let i = 0; i < HesPersonas.IDS.length; i++) {
        const id = HesPersonas.IDS[i];
        const session = HesPersonas.session(id);
        const before = session.result();
        session.setLive(200, 99999);
        expect(session.liveHeartRate()).assertEqual(200);
        expect(session.liveSteps()).assertEqual(99999);
        expect(session.result()).assertDeepEquals(before);
        expect(session.result()).assertDeepEquals(HesPersonas.result(id));
        expect(session.history().length).assertEqual(HesPersonas.history(id).length);
      }
    });

    it('a live heart rate of 0 bpm or less is no reading; negative steps are no reading', 0, () => {
      const session = HesPersonas.session('tomek');
      session.setLive(72, 3000);
      session.setLiveHeartRate(0);
      expect(session.liveHeartRate()).assertEqual(HES_MISSING);
      session.setLiveSteps(-5);
      expect(session.liveSteps()).assertEqual(HES_MISSING);
      session.setLiveSteps(0);
      expect(session.liveSteps()).assertEqual(0);
    });
  });

  describe('HES-Lite session: close the day', () => {
    it('closing the day appends exactly one completed day and scores again', 0, () => {
      const session = HesPersonas.session('tomek');
      const start = session.history();
      session.setLiveSteps(99999);
      const closed = session.closeDay();
      const days = session.history();
      expect(days.length).assertEqual(start.length + 1);
      expect(session.closedDays()).assertEqual(1);
      expect(days[days.length - 1].date).assertEqual('2026-10-04');
      expect(days[days.length - 1].steps).assertEqual(99999);
      expect(closed).assertDeepEquals(session.result());
      expect(byId(closed, 'steps').rawValue).assertLarger(byId(HesPersonas.result('tomek'), 'steps').rawValue);
      // Today starts again with no reading.
      expect(session.liveSteps()).assertEqual(HES_MISSING);
    });

    it('the live heart rate is never used as a resting heart rate', 0, () => {
      const session = HesPersonas.session('tomek');
      session.setLive(200, 5000);
      session.closeDay();
      const days = session.history();
      const expected = generatePersonaDay(specOf('tomek'), 1);
      expect(days[days.length - 1].restingHeartRate).assertEqual(expected.restingHeartRate);
      for (let i = 0; i < days.length; i++) {
        expect(days[i].restingHeartRate === 200).assertFalse();
      }
      expect(byId(session.result(), 'rhr').rawValue).assertLess(100);
      // The live reading is still on the Live card.
      expect(session.liveHeartRate()).assertEqual(200);
    });

    it('without live steps the closed day keeps the generated steps', 0, () => {
      const session = HesPersonas.session('ania');
      session.closeDay();
      const days = session.history();
      expect(days[days.length - 1]).assertDeepEquals(generatePersonaDay(specOf('ania'), 1));
    });

    it('without a day source the closed day carries only today\'s steps', 0, () => {
      const session = new HesSession(HesPersonas.history('kasia'), null);
      session.setLive(88, 4321);
      session.closeDay();
      const days = session.history();
      const last: HesDay = days[days.length - 1];
      expect(last.steps).assertEqual(4321);
      expect(last.restingHeartRate).assertEqual(HES_MISSING);
      expect(last.sleepMinutes).assertEqual(HES_MISSING);
    });

    it('Ola still has no score after 20 more days: the recorded nights stay too few', 0, () => {
      const session = HesPersonas.session('ola');
      expect(session.result().score).assertEqual(HES_MISSING);
      // She wears the watch every third night: 28 days hold at most 10 nights, never 14.
      for (let i = 0; i < 20; i++) {
        session.closeDay();
      }
      expect(session.history().length).assertEqual(44);
      expect(byId(session.result(), 'sleepDuration').available).assertFalse();
      expect(session.result().score).assertEqual(HES_MISSING);
      expect(session.result().coverage).assertEqual(48);
    });

    it('the session does not change the history it was given', 0, () => {
      const start = HesPersonas.history('ewa');
      const session = new HesSession(start, null);
      session.setLiveSteps(12000);
      session.closeDay();
      expect(start.length).assertEqual(90);
      expect(start).assertDeepEquals(HesPersonas.history('ewa'));
      const copy = session.history();
      copy[0].steps = 1;
      expect(session.history()[0].steps === 1).assertFalse();
    });
  });

  describe('HES-Lite session: reset', () => {
    it('reset restores the starting history, the score and empty live values', 0, () => {
      const session = HesPersonas.session('marek');
      session.setLive(150, 20000);
      session.closeDay();
      session.setLive(160, 30000);
      session.closeDay();
      session.setLive(170, 1234);
      expect(session.closedDays()).assertEqual(2);
      expect(session.history().length).assertEqual(92);

      const result = session.reset();
      expect(result).assertDeepEquals(HesPersonas.result('marek'));
      expect(session.result()).assertDeepEquals(HesPersonas.result('marek'));
      expect(session.history()).assertDeepEquals(HesPersonas.history('marek'));
      expect(session.closedDays()).assertEqual(0);
      expect(session.liveHeartRate()).assertEqual(HES_MISSING);
      expect(session.liveSteps()).assertEqual(HES_MISSING);
    });

    it('after a reset, closing the day gives the same day as the first time', 0, () => {
      const session = HesPersonas.session('kasia');
      session.setLiveSteps(7777);
      const first = session.closeDay();
      session.reset();
      session.setLiveSteps(7777);
      expect(session.closeDay()).assertDeepEquals(first);
    });
  });
}
