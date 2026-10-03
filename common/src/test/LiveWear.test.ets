import { describe, it, expect } from '@ohos/hypium';
import { LiveWearState, WearState, NO_HEART_RATE } from '../main/ets/live/LiveWearState';
import { FRESHNESS_REAL_CLOCK_MS } from '../main/ets/watchlink/WearStateMachine';

const SECOND_MS = 1000;
const N_MS = 10000;

export default function liveWearTest() {
  describe('LiveWearState', () => {
    it('before any reading the state is no data; zeros only are not on wrist and never a heart rate', 0, () => {
      const live = new LiveWearState(N_MS);
      expect(live.state()).assertEqual(WearState.NO_DATA);
      expect(live.heartRate()).assertEqual(NO_HEART_RATE);
      expect(live.lastValidHeartRate()).assertEqual(NO_HEART_RATE);
      // The sensor reports, but never a valid value: the same answer WearStateMachine gives the recorder.
      for (let t = 0; t <= 3 * N_MS; t += SECOND_MS) {
        live.onReading(t, 0);
        expect(live.state()).assertEqual(WearState.REMOVED);
        expect(live.heartRate()).assertEqual(NO_HEART_RATE);
      }
      expect(live.lastValidHeartRate()).assertEqual(NO_HEART_RATE);
    });

    it('70, 70, 0 for more than 60 s, 70 gives worn, removed, worn', 0, () => {
      const live = new LiveWearState();
      const limit = FRESHNESS_REAL_CLOCK_MS;
      const seen: WearState[] = [];
      const note = (): void => {
        const now = live.state();
        if (seen.length === 0 || seen[seen.length - 1] !== now) {
          seen.push(now);
        }
      };

      live.onReading(0, 70);
      note();
      expect(live.state()).assertEqual(WearState.WORN);
      expect(live.heartRate()).assertEqual(70);

      live.onReading(SECOND_MS, 70);
      note();
      expect(live.state()).assertEqual(WearState.WORN);

      // Zeros once a second. The last valid reading was at 1 s: worn up to and including 61 s.
      for (let t = 2 * SECOND_MS; t <= SECOND_MS + limit; t += SECOND_MS) {
        live.onReading(t, 0);
        note();
        expect(live.state()).assertEqual(WearState.WORN);
        expect(live.heartRate()).assertEqual(NO_HEART_RATE);
      }
      live.onReading(SECOND_MS + limit + SECOND_MS, 0);
      note();
      expect(live.state()).assertEqual(WearState.REMOVED);
      expect(live.heartRate()).assertEqual(NO_HEART_RATE);

      live.onReading(SECOND_MS + limit + 2 * SECOND_MS, 70);
      note();
      expect(live.state()).assertEqual(WearState.WORN);
      expect(live.heartRate()).assertEqual(70);

      expect(seen.length).assertEqual(3);
      expect(seen[0]).assertEqual(WearState.WORN);
      expect(seen[1]).assertEqual(WearState.REMOVED);
      expect(seen[2]).assertEqual(WearState.WORN);
    });

    it('a reading of zero or below, or outside 25-230 bpm, never appears as heart rate', 0, () => {
      const live = new LiveWearState(N_MS);
      const invalid: number[] = [0, -1, -70, Number.NaN, 24, 231];
      let t = 0;
      for (let i = 0; i < invalid.length; i++) {
        live.onReading(t, invalid[i]);
        expect(live.heartRate()).assertEqual(NO_HEART_RATE);
        expect(live.lastValidHeartRate()).assertEqual(NO_HEART_RATE);
        t += SECOND_MS;
      }
      live.onReading(t, 64);
      expect(live.heartRate()).assertEqual(64);
      for (let i = 0; i < invalid.length; i++) {
        t += SECOND_MS;
        live.onReading(t, invalid[i]);
        // The live value is withheld; the last valid reading stays the last valid one.
        expect(live.heartRate()).assertEqual(NO_HEART_RATE);
        expect(live.lastValidHeartRate()).assertEqual(64);
        expect(live.heartRate() === 0).assertFalse();
      }
    });

    it('silence from the sensor also turns into removed once the clock is advanced', 0, () => {
      const live = new LiveWearState(N_MS);
      live.onReading(0, 72);
      live.advance(N_MS);
      expect(live.state()).assertEqual(WearState.WORN);
      expect(live.heartRate()).assertEqual(72);
      live.advance(N_MS + 1);
      expect(live.state()).assertEqual(WearState.REMOVED);
      expect(live.heartRate()).assertEqual(NO_HEART_RATE);
      expect(live.msSinceValid()).assertEqual(N_MS + 1);
    });

    it('the limit is a parameter; the default is the 60 s of the real clock', 0, () => {
      expect(FRESHNESS_REAL_CLOCK_MS).assertEqual(60000);
      const quick = new LiveWearState(3 * SECOND_MS);
      quick.onReading(0, 70);
      quick.onReading(3 * SECOND_MS, 0);
      expect(quick.state()).assertEqual(WearState.WORN);
      quick.onReading(4 * SECOND_MS, 0);
      expect(quick.state()).assertEqual(WearState.REMOVED);
      const byDefault = new LiveWearState();
      byDefault.onReading(0, 70);
      byDefault.advance(60000);
      expect(byDefault.state()).assertEqual(WearState.WORN);
      byDefault.advance(60001);
      expect(byDefault.state()).assertEqual(WearState.REMOVED);
    });

    it('an older timestamp never moves the clock back', 0, () => {
      const live = new LiveWearState(N_MS);
      live.onReading(5 * SECOND_MS, 70);
      live.advance(20 * SECOND_MS);
      expect(live.state()).assertEqual(WearState.REMOVED);
      live.advance(6 * SECOND_MS);
      expect(live.state()).assertEqual(WearState.REMOVED);
    });

    it('charging overrides a fresh heart rate and withholds it', 0, () => {
      const live = new LiveWearState(N_MS);
      live.onReading(0, 70);
      live.onCharging(SECOND_MS, true);
      expect(live.state()).assertEqual(WearState.CHARGING);
      expect(live.heartRate()).assertEqual(NO_HEART_RATE);
      live.onCharging(2 * SECOND_MS, false);
      expect(live.state()).assertEqual(WearState.WORN);
      expect(live.heartRate()).assertEqual(70);
    });

    it('the wear-detection sensor decides once it has reported', 0, () => {
      const live = new LiveWearState(N_MS);
      live.onReading(0, 70);
      live.onWear(SECOND_MS, 0);
      expect(live.state()).assertEqual(WearState.REMOVED);
      live.onWear(2 * SECOND_MS, 1);
      live.advance(5 * N_MS);
      expect(live.state()).assertEqual(WearState.WORN);
    });
  });
}
