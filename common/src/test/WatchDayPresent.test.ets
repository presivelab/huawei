import { describe, it, expect } from '@ohos/hypium';
import { CLOCK_FEED_SUFFIX } from '../main/ets/watchlink/DemoFeed';
import { factsOfMissing, SyncLogEntry, TRANSPORT_RELAY, TRANSPORT_WEAR_ENGINE, WatchDayFacts }
  from '../main/ets/watchlink/PhoneLinkEngine';
import { BreakContext, CLOCK_REAL } from '../main/ets/watchlink/WatchLinkTypes';
import {
  breakText,
  DAY_NOT_RECEIVED,
  DEMO_CLOCK_LABEL,
  DEMO_FEED_LABEL,
  demoDayLabel,
  durationParts,
  durationText,
  dayOfMonth,
  dayTitle,
  isDemoDay,
  isVerifiedDay,
  lastSyncText,
  listedWearParts,
  logLineText,
  logTimeText,
  minuteClock,
  missingSummary,
  NOT_SYNCED,
  observedMinutes,
  RELAY_LABEL,
  stripDays,
  syncTimeText,
  transportLabel,
  verifiedDayCount,
  verifiedSummary,
  WEAR_CHARGING,
  WEAR_OFF,
  WEAR_UNOBSERVED,
  WEAR_WORN,
  wearParts,
  weekdayShort
} from '../main/ets/present/WatchDayPresent';

function day(seq: number, date: string, worn: number, charging: number, off: number, clock: string): WatchDayFacts {
  const f = new WatchDayFacts();
  f.seq = seq;
  f.date = date;
  f.received = true;
  f.wornMin = worn;
  f.chargingMin = charging;
  f.offMin = off;
  f.notObservedMin = 1440 - worn - charging - off;
  f.clock = clock;
  return f;
}

function localMs(y: number, m: number, d: number, h: number, min: number): number {
  return new Date(y, m - 1, d, h, min, 9).getTime();
}

export default function watchDayPresentTest() {
  describe('WatchDayPresent', () => {
    it('a duration always carries its units', 0, () => {
      expect(durationText(0)).assertEqual('0 min');
      expect(durationText(35)).assertEqual('35 min');
      expect(durationText(120)).assertEqual('2 h');
      expect(durationText(1160)).assertEqual('19 h 20 min');
      expect(durationText(1440)).assertEqual('24 h');
      expect(durationText(-5)).assertEqual('0 min');
      const whole = durationParts(1440);
      expect(whole.hours).assertEqual('24');
      expect(whole.minutes).assertEqual('');
      const none = durationParts(0);
      expect(none.hours).assertEqual('');
      expect(none.minutes).assertEqual('0');
    });

    it('a date reads as weekday, day and month, and other text is left alone', 0, () => {
      expect(dayTitle('2026-10-07')).assertEqual('Wed 7 Oct');
      expect(dayTitle('2026-10-04')).assertEqual('Sun 4 Oct');
      expect(weekdayShort('2026-10-05')).assertEqual('Mon');
      expect(dayOfMonth('2026-10-05')).assertEqual('5');
      expect(dayTitle('')).assertEqual('');
      expect(dayTitle('not a date')).assertEqual('not a date');
      expect(weekdayShort('2026-13-01')).assertEqual('');
      expect(dayOfMonth('')).assertEqual('');
    });

    it('minutes from midnight read as a clock time, also for the day before', 0, () => {
      expect(minuteClock(0)).assertEqual('00:00');
      expect(minuteClock(410)).assertEqual('06:50');
      expect(minuteClock(1435)).assertEqual('23:55');
      expect(minuteClock(-30)).assertEqual('23:30');
      const b: BreakContext = { startMin: 410, endMin: 625, hrSlots24hBefore: 0, rhr24hBefore: -1, steps24hBefore: 0 };
      expect(breakText(b)).assertEqual('Off wrist 06:50–10:25');
      const early: BreakContext =
        { startMin: -30, endMin: 60, hrSlots24hBefore: 0, rhr24hBefore: -1, steps24hBefore: 0 };
      expect(breakText(early)).assertEqual('Off wrist the day before 23:30–01:00');
    });

    it('the four states of a day keep their order and add up to the day', 0, () => {
      const parts = wearParts(day(1, '2026-10-04', 600, 420, 215, CLOCK_REAL));
      expect(parts.length).assertEqual(4);
      expect(parts[0].state).assertEqual(WEAR_WORN);
      expect(parts[1].state).assertEqual(WEAR_CHARGING);
      expect(parts[2].state).assertEqual(WEAR_OFF);
      expect(parts[3].state).assertEqual(WEAR_UNOBSERVED);
      expect(parts[0].minutes + parts[1].minutes + parts[2].minutes + parts[3].minutes).assertEqual(1440);
      expect(parts[3].minutes).assertEqual(205);
    });

    it('an observed day with no wear lists "Worn" at zero; an unobserved day does not', 0, () => {
      const offOnly = day(1, '2026-10-04', 0, 0, 215, CLOCK_REAL);
      expect(observedMinutes(offOnly)).assertEqual(215);
      const listed = listedWearParts(offOnly);
      expect(listed.length).assertEqual(3);
      expect(listed[0].state).assertEqual(WEAR_WORN);
      expect(listed[0].minutes).assertEqual(0);
      expect(listed[1].state).assertEqual(WEAR_OFF);
      expect(listed[2].state).assertEqual(WEAR_UNOBSERVED);

      const blind = day(3, '2026-10-06', 0, 0, 0, CLOCK_REAL);
      const blindListed = listedWearParts(blind);
      expect(blindListed.length).assertEqual(1);
      expect(blindListed[0].state).assertEqual(WEAR_UNOBSERVED);
      expect(blindListed[0].minutes).assertEqual(1440);
    });

    it('a missing day is not verified, not a demo day and has nothing observed', 0, () => {
      const missing = factsOfMissing(3);
      expect(isVerifiedDay(missing)).assertFalse();
      expect(isDemoDay(missing)).assertFalse();
      expect(demoDayLabel(missing)).assertEqual('');
      expect(observedMinutes(missing)).assertEqual(0);
      expect(DAY_NOT_RECEIVED.length > 0).assertTrue();
      const days: WatchDayFacts[] = [day(4, '2026-10-07', 0, 0, 0, CLOCK_REAL), missing,
        day(2, '2026-10-05', 0, 0, 100, CLOCK_REAL)];
      expect(verifiedDayCount(days)).assertEqual(2);
    });

    it('demo days are labelled, and scripted readings are named', 0, () => {
      expect(demoDayLabel(day(1, '2026-10-04', 0, 0, 0, CLOCK_REAL))).assertEqual('');
      expect(demoDayLabel(day(1, '2026-10-04', 0, 0, 0, 'DEMO_X300'))).assertEqual(DEMO_CLOCK_LABEL);
      expect(demoDayLabel(day(1, '2026-10-04', 0, 0, 0, 'DEMO_OFFSET'))).assertEqual(DEMO_CLOCK_LABEL);
      expect(demoDayLabel(day(1, '2026-10-04', 0, 0, 0, 'DEMO_X300' + CLOCK_FEED_SUFFIX)))
        .assertEqual(DEMO_FEED_LABEL);
      expect(isDemoDay(day(1, '2026-10-04', 0, 0, 0, 'DEMO_X300'))).assertTrue();
      expect(isDemoDay(day(1, '2026-10-04', 0, 0, 0, CLOCK_REAL))).assertFalse();
    });

    it('the strip takes the newest seven days and runs oldest to newest', 0, () => {
      const newestFirst: WatchDayFacts[] = [];
      for (let seq = 9; seq >= 1; seq--) {
        newestFirst.push(day(seq, `2026-10-0${seq}`, 0, 0, 0, CLOCK_REAL));
      }
      const strip = stripDays(newestFirst);
      expect(strip.length).assertEqual(7);
      expect(strip[0].seq).assertEqual(3);
      expect(strip[6].seq).assertEqual(9);
      const short = stripDays(newestFirst.slice(0, 2));
      expect(short.length).assertEqual(2);
      expect(short[0].seq).assertEqual(8);
      expect(short[1].seq).assertEqual(9);
      expect(stripDays([]).length).assertEqual(0);
    });

    it('the last sync reads as today, yesterday or a date', 0, () => {
      const now = localMs(2026, 10, 4, 9, 0);
      expect(syncTimeText(localMs(2026, 10, 4, 7, 51), now)).assertEqual('Today 07:51');
      expect(syncTimeText(localMs(2026, 10, 3, 21, 10), now)).assertEqual('Yesterday 21:10');
      expect(syncTimeText(localMs(2026, 9, 28, 6, 5), now)).assertEqual('28 Sep 06:05');
      expect(syncTimeText(0, now)).assertEqual(NOT_SYNCED);
      expect(lastSyncText([], now)).assertEqual(NOT_SYNCED);
      const log: SyncLogEntry[] = [
        { atMs: localMs(2026, 10, 4, 7, 51), seq: 4, message: 'Accepted', note: 'Missing 1 day(s)' },
        { atMs: localMs(2026, 10, 3, 7, 0), seq: 0, message: 'Paired', note: '' }
      ];
      expect(lastSyncText(log, now)).assertEqual('Today 07:51');
      expect(logTimeText(log[0].atMs)).assertEqual('2026-10-04 07:51:09');
      expect(logLineText(log[0])).assertEqual('#4 · Accepted · Missing 1 day(s)');
      expect(logLineText(log[1])).assertEqual('Paired');
    });

    it('the relay is named as a demo relay; another transport keeps its name', 0, () => {
      expect(transportLabel(TRANSPORT_RELAY)).assertEqual(RELAY_LABEL);
      expect(RELAY_LABEL).assertEqual('Demo relay (hdc)');
      expect(transportLabel(TRANSPORT_WEAR_ENGINE)).assertEqual(TRANSPORT_WEAR_ENGINE);
    });

    it('the summaries count days and never show a bare number', 0, () => {
      expect(verifiedSummary(0, 0)).assertEqual('No day received yet');
      expect(verifiedSummary(1, 1)).assertEqual('1 day verified');
      expect(verifiedSummary(4, 4)).assertEqual('All 4 days verified');
      expect(verifiedSummary(3, 4)).assertEqual('3 of 4 days verified');
      expect(missingSummary(0)).assertEqual('');
      expect(missingSummary(1)).assertEqual('1 day never reached this phone');
      expect(missingSummary(2)).assertEqual('2 days never reached this phone');
      expect(WEAR_CHARGING.length > 0).assertTrue();
    });
  });
}
