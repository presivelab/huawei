import { describe, it, expect } from '@ohos/hypium';
import {
  CLOCK_FEED_SUFFIX,
  demoFeedAt,
  demoFeedSteps,
  feedClockLabel,
  MINUTES_PER_DAY
} from '../main/ets/watchlink/DemoFeed';
import { isValidHeartRate } from '../main/ets/watchlink/WatchLinkTypes';

function at(hour: number, minute: number): number {
  return hour * 60 + minute;
}

export default function demoFeedTest() {
  describe('DemoFeed script', () => {
    it('the night is on the charger with no heart rate', 0, () => {
      const night = demoFeedAt(at(2, 0));
      expect(night.charging).assertTrue();
      expect(night.hr).assertEqual(0);
      expect(night.stepsPerMin).assertEqual(0);
      expect(demoFeedAt(at(23, 30)).charging).assertTrue();
    });

    it('worn hours have a valid heart rate and are not charging', 0, () => {
      const hours: number[] = [at(6, 0), at(7, 30), at(10, 0), at(15, 0), at(18, 30), at(21, 0)];
      for (let i = 0; i < hours.length; i++) {
        const sample = demoFeedAt(hours[i]);
        expect(sample.charging).assertFalse();
        expect(isValidHeartRate(sample.hr)).assertTrue();
      }
    });

    it('there is exactly one break: no reading and not charging from 12:00 to 15:00', 0, () => {
      let breakMinutes = 0;
      let first = -1;
      let last = -1;
      for (let m = 0; m < MINUTES_PER_DAY; m++) {
        const sample = demoFeedAt(m);
        if (!sample.charging && sample.hr === 0) {
          breakMinutes++;
          if (first < 0) {
            first = m;
          }
          last = m;
        }
      }
      expect(first).assertEqual(at(12, 0));
      expect(last).assertEqual(at(15, 0) - 1);
      expect(breakMinutes).assertEqual(180);
    });

    it('every minute of the day is scripted and the script is deterministic', 0, () => {
      for (let m = 0; m < MINUTES_PER_DAY; m++) {
        const a = demoFeedAt(m);
        const b = demoFeedAt(m);
        expect(a.hr).assertEqual(b.hr);
        expect(a.charging).assertEqual(b.charging);
        expect(a.hr === 0 || isValidHeartRate(a.hr)).assertTrue();
      }
      expect(demoFeedAt(MINUTES_PER_DAY + at(10, 0)).hr).assertEqual(demoFeedAt(at(10, 0)).hr);
    });

    it('the workout has a higher heart rate than the desk hours', 0, () => {
      expect(demoFeedAt(at(18, 30)).hr > demoFeedAt(at(10, 0)).hr + 30).assertTrue();
    });

    it('steps follow the rate, are never negative and are capped per tick', 0, () => {
      expect(demoFeedSteps(at(8, 45), 5)).assertEqual(525);
      expect(demoFeedSteps(at(8, 45), 0)).assertEqual(0);
      expect(demoFeedSteps(at(8, 45), -3)).assertEqual(0);
      expect(demoFeedSteps(at(2, 0), 5)).assertEqual(0);
      expect(demoFeedSteps(at(8, 45), 600)).assertEqual(105 * 30);
    });

    it('the clock label is marked once', 0, () => {
      expect(CLOCK_FEED_SUFFIX).assertEqual('_FEED');
      expect(feedClockLabel('DEMO_X300')).assertEqual('DEMO_X300_FEED');
      expect(feedClockLabel('DEMO_X300_FEED')).assertEqual('DEMO_X300_FEED');
    });
  });
}
