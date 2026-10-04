import { describe, it, expect } from '@ohos/hypium';
import {
  BUILT_IN_SCRIPT,
  CLOCK_FEED_SUFFIX,
  decodeWatchScript,
  demoFeedAt,
  demoFeedSteps,
  encodeWatchScript,
  feedClockLabel,
  FEED_SOURCE_BUILT_IN,
  FEED_SOURCE_HEALTH_SIM,
  feedScriptSource,
  FeedStretch,
  HEALTH_SIM_WATCH_PARAM,
  MINUTES_PER_DAY,
  setFeedScript
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

  describe('DemoFeed script from Health Sim', () => {
    it('the built-in script round-trips through the text Health Sim sends', 0, () => {
      expect(HEALTH_SIM_WATCH_PARAM).assertEqual('fwhsw1');
      const decoded = decodeWatchScript(encodeWatchScript(BUILT_IN_SCRIPT));
      expect(decoded !== null).assertTrue();
      expect(decoded).assertDeepEquals(BUILT_IN_SCRIPT);
    });

    it('a script that does not cover the day exactly, or is malformed, gives null', 0, () => {
      const good = encodeWatchScript(BUILT_IN_SCRIPT);
      expect(decodeWatchScript('') === null).assertTrue();
      expect(decodeWatchScript('{') === null).assertTrue();
      expect(decodeWatchScript(good.replace('"v":1', '"v":2')) === null).assertTrue();
      // A gap (the first stretch ends a minute early), an overlap, a day that ends before 24:00.
      expect(decodeWatchScript(good.replace('[0,330,', '[0,329,')) === null).assertTrue();
      expect(decodeWatchScript(good.replace('[0,330,', '[0,331,')) === null).assertTrue();
      expect(decodeWatchScript(good.replace(',1440,', ',1439,')) === null).assertTrue();
      // A row one field short, a text where a number belongs, a heart rate out of range.
      expect(decodeWatchScript(good.replace('[0,330,0,0,0,1]', '[0,330,0,0,0]')) === null).assertTrue();
      expect(decodeWatchScript(good.replace('[0,330,0,0,0,1]', '[0,330,"0",0,0,1]')) === null).assertTrue();
      expect(decodeWatchScript(good.replace('[0,330,0,0,0,1]', '[0,330,999,0,0,1]')) === null).assertTrue();
    });

    it('a script in use drives the feed; null brings back the built-in one', 0, () => {
      const allDayWalk: FeedStretch[] = [new FeedStretch(0, MINUTES_PER_DAY, 90, 0, 100, false)];
      try {
        expect(feedScriptSource()).assertEqual(FEED_SOURCE_BUILT_IN);
        setFeedScript(allDayWalk);
        expect(feedScriptSource()).assertEqual(FEED_SOURCE_HEALTH_SIM);
        expect(demoFeedAt(at(2, 0)).hr).assertEqual(90);
        expect(demoFeedAt(at(2, 0)).charging).assertFalse();
        expect(demoFeedSteps(at(13, 0), 1)).assertEqual(100);
      } finally {
        setFeedScript(null);
      }
      expect(feedScriptSource()).assertEqual(FEED_SOURCE_BUILT_IN);
      expect(demoFeedAt(at(2, 0)).charging).assertTrue();
      expect(demoFeedAt(at(13, 0)).hr).assertEqual(0);
    });

    it('Health Sim sends the same day as the built-in script, so the demo day is unchanged', 0, () => {
      const fromSim = decodeWatchScript(encodeWatchScript(BUILT_IN_SCRIPT));
      try {
        setFeedScript(fromSim);
        for (let m = 0; m < MINUTES_PER_DAY; m += 7) {
          setFeedScript(null);
          const builtIn = demoFeedAt(m);
          setFeedScript(fromSim);
          expect(demoFeedAt(m)).assertDeepEquals(builtIn);
        }
      } finally {
        setFeedScript(null);
      }
    });
  });
}
