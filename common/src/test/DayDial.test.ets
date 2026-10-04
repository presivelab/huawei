import { describe, it, expect } from '@ohos/hypium';
import { HesPersonas } from '../main/ets/hes/HesPersonas';
import { emptyHesDay, HesDay } from '../main/ets/hes/HesTypes';
import {
  dayDial,
  DIAL_CHARGING,
  DIAL_NO_VALUE,
  DIAL_NO_WEAR_SEGMENTS,
  DIAL_OFF,
  DIAL_SLEEP,
  DIAL_SLEEP_NOT_MEASURED,
  DIAL_STEPS_NOT_MEASURED,
  DIAL_WORN,
  DialSegment,
  dialSegmentsOfRuns,
  groupedNumber,
  minuteToDeg,
  sleepArcs,
  wearArcs
} from '../main/ets/present/DayDialModel';
import { slotRuns } from '../main/ets/present/TourContent';

function night(startMin: number, endMin: number, minutes: number, steps: number): HesDay {
  const day = emptyHesDay('2026-10-03');
  day.sleepStartMin = startMin;
  day.sleepEndMin = endMin;
  day.sleepMinutes = minutes;
  day.steps = steps;
  return day;
}

export default function dayDialTest() {
  describe('Day dial', () => {
    it('a night across midnight is one arc that passes 00:00', 0, () => {
      // 23:30 to 07:10
      const arcs = sleepArcs(night(1410, 430, 430, 7954));
      expect(arcs.length).assertEqual(1);
      expect(arcs[0].kind).assertEqual(DIAL_SLEEP);
      expect(arcs[0].startDeg).assertEqual(352.5);
      expect(arcs[0].sweepDeg).assertEqual(115);
      expect(arcs[0].startDeg + arcs[0].sweepDeg > 360).assertTrue();
    });

    it('a night after midnight stays inside the day', 0, () => {
      // 00:40 to 07:00
      const arcs = sleepArcs(night(40, 420, 360, 5000));
      expect(arcs.length).assertEqual(1);
      expect(arcs[0].startDeg).assertEqual(10);
      expect(arcs[0].sweepDeg).assertEqual(95);
    });

    it('the now marker: 00:00, 12:00 and 23:59', 0, () => {
      const day = night(1410, 430, 430, 7954);
      expect(dayDial(day, [], 0).nowDeg).assertEqual(0);
      expect(dayDial(day, [], 720).nowDeg).assertEqual(180);
      expect(dayDial(day, [], 1439).nowDeg).assertEqual(359.75);
      expect(minuteToDeg(1440)).assertEqual(0);
      expect(minuteToDeg(360)).assertEqual(90);
    });

    it('a day without sleep has no sleep arc and says so', 0, () => {
      const day = emptyHesDay('2026-10-03');
      day.steps = 3120;
      const dial = dayDial(day, [], 600);
      expect(dial.sleepArcs.length).assertEqual(0);
      expect(dial.sleepNote).assertEqual(DIAL_SLEEP_NOT_MEASURED);
      expect(dial.legend.indexOf(DIAL_SLEEP)).assertEqual(-1);
      expect(dial.centerText).assertEqual('3,120 steps');
    });

    it('Ola: every day without a measured night gives no arc', 0, () => {
      const history = HesPersonas.session('ola').history();
      expect(history.length > 0).assertTrue();
      let unmeasured = 0;
      for (let i = 0; i < history.length; i++) {
        const dial = dayDial(history[i], [], 600);
        if (history[i].sleepMinutes < 0) {
          unmeasured++;
          expect(dial.sleepArcs.length).assertEqual(0);
          expect(dial.sleepNote).assertEqual(DIAL_SLEEP_NOT_MEASURED);
        } else {
          expect(dial.sleepArcs.length).assertEqual(1);
        }
      }
      expect(unmeasured > 0).assertTrue();
    });

    it('no day at all: nothing is drawn and nothing is invented', 0, () => {
      const dial = dayDial(null, [], 600);
      expect(dial.sleepArcs.length).assertEqual(0);
      expect(dial.wearArcs.length).assertEqual(0);
      expect(dial.centerValue).assertEqual(DIAL_NO_VALUE);
      expect(dial.centerText).assertEqual(DIAL_STEPS_NOT_MEASURED);
      expect(dial.wearNote).assertEqual(DIAL_NO_WEAR_SEGMENTS);
    });

    it('the middle shows the steps of the day, grouped', 0, () => {
      expect(dayDial(night(1410, 430, 430, 7954), [], 600).centerText).assertEqual('7,954 steps');
      expect(groupedNumber(954)).assertEqual('954');
      expect(groupedNumber(12034)).assertEqual('12,034');
      expect(groupedNumber(1000000)).assertEqual('1,000,000');
      expect(groupedNumber(-1)).assertEqual(DIAL_NO_VALUE);
    });

    it('wear segments map to angles: worn, charging, off', 0, () => {
      const segments: DialSegment[] = [
        new DialSegment(0, 360, DIAL_WORN),          // 00:00 to 06:00
        new DialSegment(360, 60, DIAL_CHARGING),     // 06:00 to 07:00
        new DialSegment(420, 600, DIAL_WORN),        // 07:00 to 17:00
        new DialSegment(1020, 120, DIAL_OFF)         // 17:00 to 19:00
      ];
      const arcs = wearArcs(segments);
      expect(arcs.length).assertEqual(4);
      expect(arcs[0].startDeg).assertEqual(0);
      expect(arcs[0].sweepDeg).assertEqual(90);
      expect(arcs[0].kind).assertEqual(DIAL_WORN);
      expect(arcs[1].startDeg).assertEqual(90);
      expect(arcs[1].sweepDeg).assertEqual(15);
      expect(arcs[1].kind).assertEqual(DIAL_CHARGING);
      expect(arcs[2].startDeg).assertEqual(105);
      expect(arcs[2].sweepDeg).assertEqual(150);
      expect(arcs[3].startDeg).assertEqual(255);
      expect(arcs[3].sweepDeg).assertEqual(30);
      expect(arcs[3].kind).assertEqual(DIAL_OFF);

      const dial = dayDial(night(1410, 430, 430, 7954), segments, 600);
      expect(dial.wearNote).assertEqual('');
      expect(dial.legend.join(',')).assertEqual(`${DIAL_SLEEP},${DIAL_WORN},${DIAL_CHARGING},${DIAL_OFF}`);
    });

    it('a slot string from the watch becomes segments; not-observed time is left out', 0, () => {
      // 12 slots worn (1 h), 12 not observed, 6 charging (30 min), 6 off the wrist (30 min)
      const slots = 'W'.repeat(12) + '-'.repeat(12) + 'C'.repeat(6) + 'O'.repeat(6);
      const segments = dialSegmentsOfRuns(slotRuns(slots));
      expect(segments.length).assertEqual(3);
      expect(segments[0].startMin).assertEqual(0);
      expect(segments[0].minutes).assertEqual(60);
      expect(segments[0].kind).assertEqual(DIAL_WORN);
      expect(segments[1].startMin).assertEqual(120);
      expect(segments[1].minutes).assertEqual(30);
      expect(segments[1].kind).assertEqual(DIAL_CHARGING);
      expect(segments[2].startMin).assertEqual(150);
      expect(segments[2].kind).assertEqual(DIAL_OFF);
      const arcs = wearArcs(segments);
      expect(arcs[1].startDeg).assertEqual(30);
      expect(arcs[1].sweepDeg).assertEqual(7.5);
    });

    it('without watch segments the dial says when they appear', 0, () => {
      const dial = dayDial(night(1410, 430, 430, 7954), [], 600);
      expect(dial.wearArcs.length).assertEqual(0);
      expect(dial.wearNote).assertEqual(DIAL_NO_WEAR_SEGMENTS);
      expect(dial.sleepNote).assertEqual('Sleep 23:30–07:10');
    });
  });
}
