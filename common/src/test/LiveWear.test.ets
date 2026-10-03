import { describe, it, expect } from '@ohos/hypium';
import {
  LiveWearState,
  WearState,
  NO_HEART_RATE,
  DEFAULT_REMOVED_AFTER_MS
} from '../main/ets/live/LiveWearState';

const SECOND_MS = 1000;
const N_MS = 10000;

export default function liveWearTest() {
  describe('LiveWearState', () => {
    it('before the first valid reading the state is no data and there is no heart rate', 0, () => {
      const live = new LiveWearState(N_MS);
      expect(live.state()).assertEqual(WearState.NO_DATA);
      expect(live.heartRate()).assertEqual(NO_HEART_RATE);
      expect(live.lastValidHeartRate()).assertEqual(NO_HEART_RATE);
      // Zeros only, for longer than N: still no data, never "removed" and never a heart rate.
      for (let t = 0; t <= 3 * N_MS; t += SECOND_MS) {
        live.onReading(t, 0);
        expect(live.state()).assertEqual(WearState.NO_DATA);
        expect(live.heartRate()).assertEqual(NO_HEART_RATE);
      }
      expect(live.lastValidHeartRate()).assertEqual(NO_HEART_RATE);
    });

    it('70, 70, 0 for N s, 70 gives worn, removed, worn', 0, () => {
      const live = new LiveWearState(N_MS);
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

      // Zeros once a second. The last valid reading was at 1 s, so N s without one ends at 11 s.
      for (let t = 2 * SECOND_MS; t < SECOND_MS + N_MS; t += SECOND_MS) {
        live.onReading(t, 0);
        note();
        expect(live.state()).assertEqual(WearState.WORN);
        expect(live.heartRate()).assertEqual(NO_HEART_RATE);
      }
      live.onReading(SECOND_MS + N_MS, 0);
      note();
      expect(live.state()).assertEqual(WearState.REMOVED);
      expect(live.heartRate()).assertEqual(NO_HEART_RATE);

      live.onReading(SECOND_MS + N_MS + SECOND_MS, 70);
      note();
      expect(live.state()).assertEqual(WearState.WORN);
      expect(live.heartRate()).assertEqual(70);

      expect(seen.length).assertEqual(3);
      expect(seen[0]).assertEqual(WearState.WORN);
      expect(seen[1]).assertEqual(WearState.REMOVED);
      expect(seen[2]).assertEqual(WearState.WORN);
    });

    it('a reading of zero or below never appears as heart rate', 0, () => {
      const live = new LiveWearState(N_MS);
      const invalid: number[] = [0, -1, -70, Number.NaN];
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
      live.advance(N_MS - 1);
      expect(live.state()).assertEqual(WearState.WORN);
      expect(live.heartRate()).assertEqual(72);
      live.advance(N_MS);
      expect(live.state()).assertEqual(WearState.REMOVED);
      expect(live.heartRate()).assertEqual(NO_HEART_RATE);
      expect(live.msSinceValid()).assertEqual(N_MS);
    });

    it('N is a parameter; the default is the 10 s demo value', 0, () => {
      expect(DEFAULT_REMOVED_AFTER_MS).assertEqual(10000);
      const quick = new LiveWearState(3 * SECOND_MS);
      quick.onReading(0, 70);
      quick.onReading(2 * SECOND_MS, 0);
      expect(quick.state()).assertEqual(WearState.WORN);
      quick.onReading(3 * SECOND_MS, 0);
      expect(quick.state()).assertEqual(WearState.REMOVED);
      const byDefault = new LiveWearState();
      byDefault.onReading(0, 70);
      byDefault.advance(9999);
      expect(byDefault.state()).assertEqual(WearState.WORN);
      byDefault.advance(10000);
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
  });
}
