import { describe, it, expect } from '@ohos/hypium';
import { DaySteps, NO_STEPS } from '../main/ets/model/DaySteps';

const TODAY = '2026-10-4';
const TOMORROW = '2026-10-5';

export default function dayStepsTest() {
  describe('DaySteps', () => {
    it('before the first reading of the day there is no step count, not zero', 0, () => {
      const steps = new DaySteps();
      expect(steps.today(TODAY)).assertEqual(NO_STEPS);
      steps.onRaw(TODAY, 1000);
      expect(steps.today(TOMORROW)).assertEqual(NO_STEPS);
    });

    it('today = raw counter minus the first raw reading of the day', 0, () => {
      const steps = new DaySteps();
      steps.onRaw(TODAY, 1000);
      expect(steps.today(TODAY)).assertEqual(0);
      steps.onRaw(TODAY, 1000);
      expect(steps.today(TODAY)).assertEqual(0);
      steps.onRaw(TODAY, 1250);
      expect(steps.today(TODAY)).assertEqual(250);
    });

    it('a dropped counter re-bases and keeps what was counted', 0, () => {
      const steps = new DaySteps();
      steps.onRaw(TODAY, 1000);
      steps.onRaw(TODAY, 1300);
      steps.onRaw(TODAY, 40);
      expect(steps.today(TODAY)).assertEqual(300);
      steps.onRaw(TODAY, 100);
      expect(steps.today(TODAY)).assertEqual(360);
    });

    it('a new day starts again from its own first reading', 0, () => {
      const steps = new DaySteps();
      steps.onRaw(TODAY, 1000);
      steps.onRaw(TODAY, 1500);
      steps.onRaw(TOMORROW, 1700);
      expect(steps.today(TOMORROW)).assertEqual(0);
      steps.onRaw(TOMORROW, 1720);
      expect(steps.today(TOMORROW)).assertEqual(20);
    });

    it('a saved state restores; a broken one is ignored', 0, () => {
      const steps = new DaySteps();
      steps.onRaw(TODAY, 1000);
      steps.onRaw(TODAY, 1100);
      const back = new DaySteps();
      back.restore(steps.save());
      expect(back.today(TODAY)).assertEqual(100);
      back.onRaw(TODAY, 1150);
      expect(back.today(TODAY)).assertEqual(150);
      const broken = new DaySteps();
      broken.restore('{not json');
      expect(broken.today(TODAY)).assertEqual(NO_STEPS);
      broken.restore('{"dayKey":5}');
      expect(broken.today(TODAY)).assertEqual(NO_STEPS);
    });

    it('a negative counter value is ignored', 0, () => {
      const steps = new DaySteps();
      expect(steps.onRaw(TODAY, -1)).assertFalse();
      expect(steps.today(TODAY)).assertEqual(NO_STEPS);
    });
  });
}
