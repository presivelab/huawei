import { describe, it, expect } from '@ohos/hypium';
import { aggregate } from '../main/ets/hes/HesAggregate';
import { computeHes } from '../main/ets/hes/HesEngine';
import { HES_PROFILES } from '../main/ets/hes/HesModel';
import { HesPersonas } from '../main/ets/hes/HesPersonas';
import { emptyHesSnapshot, HesSession } from '../main/ets/hes/HesSession';
import {
  ComponentId,
  ComponentResult,
  HesConfidence,
  HesProfile,
  HesResult,
  HesStatus,
  HesTier
} from '../main/ets/hes/HesTypes';

const TODAY = '2026-10-04';
const EPS = 1e-9;
const THREE_PLACES = 5e-4;
const HW = HesProfile.HEALTH_WELLNESS;
const LW = HesProfile.LONGEVITY_WELLNESS;

function byId(result: HesResult, id: ComponentId): ComponentResult {
  for (let i = 0; i < result.components.length; i++) {
    if (result.components[i].id === id) {
      return result.components[i];
    }
  }
  throw new Error('component not in the result');
}

export default function hesSessionTest() {
  describe('HES session: live values are shown and never scored', () => {
    it('a live heart rate going from 70 to 145 does not change the score', 0, () => {
      for (let p = 0; p < HES_PROFILES.length; p++) {
        const session = HesPersonas.session('tomek', TODAY);
        session.setLiveHeartRate(70);
        const before = session.current(HES_PROFILES[p]);
        session.setLiveHeartRate(145);
        expect(session.liveHeartRate()).assertEqual(145);
        expect(session.current(HES_PROFILES[p])).assertDeepEquals(before);
      }
    });

    it('today\'s steps going from 1200 to 8000 do not change the score', 0, () => {
      for (let p = 0; p < HES_PROFILES.length; p++) {
        const session = HesPersonas.session('tomek', TODAY);
        session.setLiveSteps(1200);
        const before = session.current(HES_PROFILES[p]);
        session.setLiveSteps(8000);
        expect(session.liveSteps()).assertEqual(8000);
        expect(session.current(HES_PROFILES[p])).assertDeepEquals(before);
        expect(session.historyLength()).assertEqual(28);
      }
    });

    it('the live heart rate never reaches the resting heart rate, before or after the day is closed', 0, () => {
      const session = HesPersonas.session('ania', TODAY);
      session.setLive(145, 5000);
      expect(byId(session.current(HW), ComponentId.RHR).rawValue).assertEqual(58);
      session.closeDay();
      const days = session.history().days;
      expect(days[days.length - 1].restingHr).assertEqual(58);
      expect(aggregate(session.history()).rhr.raw).assertClose(59, EPS);
      for (let i = 0; i < days.length; i++) {
        expect(days[i].restingHr === 145).assertFalse();
      }
    });

    it('before any live value the Live card shows the source\'s steps for today, not zero', 0, () => {
      const session = HesPersonas.session('ola', TODAY);
      expect(session.liveSteps()).assertEqual(6800);
      expect(session.liveHeartRate()).assertUndefined();
      session.setLive(-5, -1);
      expect(session.liveSteps()).assertEqual(6800);
      expect(session.liveHeartRate()).assertUndefined();
      session.setLive(NaN, Infinity);
      expect(session.liveSteps()).assertEqual(6800);
      expect(session.liveHeartRate()).assertUndefined();
      session.setLiveSteps(0);
      expect(session.liveSteps()).assertEqual(0);
    });
  });

  describe('HES session: close the day', () => {
    it('the history grows by one day and the running day moves to the next date', 0, () => {
      const session = HesPersonas.session('ania', TODAY);
      expect(session.historyLength()).assertEqual(28);
      expect(session.today().date).assertEqual(TODAY);
      session.closeDay();
      expect(session.historyLength()).assertEqual(29);
      expect(session.closedDays()).assertEqual(1);
      const days = session.history().days;
      expect(days[days.length - 1].date).assertEqual(TODAY);
      expect(session.today().date).assertEqual('2026-10-05');
    });

    it('Ania, today as the source has it: the aggregates move and the score is 92 · A · High', 0, () => {
      const session = HesPersonas.session('ania', TODAY);
      session.closeDay();
      const aggregates = aggregate(session.history());
      expect(aggregates.steps.raw).assertClose(8821.428571429, 1e-6);
      expect(aggregates.mvpa.raw).assertClose(239.5, EPS);
      expect(aggregates.rhr.raw).assertClose(59, EPS);
      expect(aggregates.sleepDuration.raw).assertClose(7.55, EPS);
      expect(aggregates.hrv.raw).assertClose(62.5, EPS);
      const result = session.current(HW);
      expect(result.score).assertEqual(92);
      expect(result.tier).assertEqual(HesTier.A);
      expect(result.confidence).assertEqual(HesConfidence.HIGH);
      expect(result.observed).assertClose(92.365, THREE_PLACES);
    });

    it('the closed day takes today\'s live steps; the next day starts from the source\'s steps again', 0, () => {
      const session = HesPersonas.session('ania', TODAY);
      session.setLiveSteps(8000);
      session.closeDay();
      const days = session.history().days;
      expect(days[days.length - 1].steps).assertEqual(8000);
      expect(session.liveSteps()).assertEqual(8800);
      session.closeDay();
      const after = session.history().days;
      expect(after[after.length - 1].steps).assertEqual(8800);
    });

    it('a value that was never there stays absent: nothing is closed as zero', 0, () => {
      const snapshot = HesPersonas.snapshot('tomek', TODAY);
      snapshot.today.steps = undefined;
      const session = new HesSession(snapshot);
      expect(session.liveSteps()).assertUndefined();
      session.closeDay();
      const days = session.history().days;
      expect(days[days.length - 1].steps).assertUndefined();
      expect(days[days.length - 1].hrv).assertUndefined();
      // 27 valid days left in the window, with the same mean: the missing day is not a zero.
      expect(aggregate(session.history()).steps.validCount).assertEqual(27);
    });

    it('Ola: eight closed days without touching the live steps give 84 · A · Medium', 0, () => {
      const session = HesPersonas.session('ola', TODAY);
      for (let i = 0; i < 7; i++) {
        session.closeDay();
      }
      const seven = session.current(HW);
      expect(seven.status).assertEqual(HesStatus.INSUFFICIENT_DATA);
      expect(seven.coverage).assertEqual(55);
      expect(seven.tier).assertEqual(HesTier.NONE);
      session.closeDay();
      expect(session.historyLength()).assertEqual(24);
      const inHw = session.current(HW);
      expect(inHw.score).assertEqual(84);
      expect(inHw.tier).assertEqual(HesTier.A);
      expect(inHw.coverage).assertEqual(82.5);
      expect(inHw.confidence).assertEqual(HesConfidence.MEDIUM);
      expect(inHw.observed).assertClose(84.194, THREE_PLACES);
      expect(inHw.confidenceIndex).assertClose(0.733, THREE_PLACES);
      const inLw = session.current(LW);
      expect(inLw.score).assertEqual(84);
      expect(inLw.tier).assertEqual(HesTier.A);
      expect(inLw.coverage).assertEqual(72.5);
      expect(inLw.confidence).assertEqual(HesConfidence.MEDIUM);
      expect(inLw.observed).assertClose(83.903, THREE_PLACES);
      expect(inLw.confidenceIndex).assertClose(0.667, THREE_PLACES);
    });

    it('the session gives the same result as the engine on the same history', 0, () => {
      const session = HesPersonas.session('ewa', TODAY);
      session.closeDay();
      session.closeDay();
      for (let p = 0; p < HES_PROFILES.length; p++) {
        expect(session.current(HES_PROFILES[p])).assertDeepEquals(computeHes(HES_PROFILES[p], session.history()));
      }
    });
  });

  describe('HES session: reset', () => {
    it('reset goes back to the snapshot the session started from', 0, () => {
      const session = HesPersonas.session('ewa', TODAY);
      const start = session.current(HW);
      session.setLive(120, 9000);
      session.closeDay();
      session.closeDay();
      session.resetDemo();
      expect(session.historyLength()).assertEqual(28);
      expect(session.closedDays()).assertEqual(0);
      expect(session.liveHeartRate()).assertUndefined();
      expect(session.liveSteps()).assertEqual(4400);
      expect(session.today().date).assertEqual(TODAY);
      expect(session.current(HW)).assertDeepEquals(start);
      expect(session.history()).assertDeepEquals(HesPersonas.history('ewa', TODAY));
    });

    it('the session works on its own copy: changing what it returned changes nothing', 0, () => {
      const snapshot = HesPersonas.snapshot('ania', TODAY);
      const session = new HesSession(snapshot);
      snapshot.history.days[27].steps = 1;
      session.history().days[27].steps = 2;
      session.today().steps = 3;
      expect(session.current(HW).score).assertEqual(92);
      expect(session.liveSteps()).assertEqual(8800);
    });

    it('an empty snapshot has no score and closing a day does not invent one', 0, () => {
      const session = new HesSession(emptyHesSnapshot());
      expect(session.current(HW).status).assertEqual(HesStatus.INSUFFICIENT_DATA);
      session.closeDay();
      expect(session.historyLength()).assertEqual(1);
      expect(session.current(HW).status).assertEqual(HesStatus.INSUFFICIENT_DATA);
      expect(session.current(HW).coveragePermille).assertEqual(0);
    });
  });
}
