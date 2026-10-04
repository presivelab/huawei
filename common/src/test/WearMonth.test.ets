import { describe, it, expect } from '@ohos/hypium';
import { HesPersonas } from '../main/ets/hes/HesPersonas';
import { HES_MISSING } from '../main/ets/hes/HesTypes';
import { DEFAULT_THRESHOLDS } from '../main/ets/model/defaults';
import { Thresholds } from '../main/ets/model/types';
import {
  buildWearMonth,
  countedWearMinutes,
  isDayCompliant,
  isNightWorn,
  judgeBreak,
  WearBreak,
  WearDayRecord,
  WearDayResult,
  WearDayState,
  WearMonthResult
} from '../main/ets/wear/WearMonth';
import { WearPersonas, WEAR_MONTH_DAYS } from '../main/ets/wear/WearPersonas';

const TH = DEFAULT_THRESHOLDS;

function gap(minutes: number, readings: number, restDelta: number, stepsRatio: number): WearBreak {
  return {
    startMin: 13 * 60,
    minutes: minutes,
    hrReadings24hBefore: readings,
    restDeltaBpm: restDelta,
    stepsRatio: stepsRatio
  };
}

function day(wornMin: number, nightWornMin: number, chargingMin: number, breaks: WearBreak[]): WearDayRecord {
  return {
    date: '2026-09-10',
    observed: true,
    wornMin: wornMin,
    nightWornMin: nightWornMin,
    chargingMin: chargingMin,
    breaks: breaks
  };
}

function goodDay(): WearDayRecord {
  return day(1380, 360, 60, []);
}

function unobservedDay(): WearDayRecord {
  return { date: '2026-09-10', observed: false, wornMin: 0, nightWornMin: 0, chargingMin: 0, breaks: [] };
}

// A month of good days with the given breaks, one per day, on the first days.
function monthWithBreaks(breaks: WearBreak[]): WearDayRecord[] {
  const out: WearDayRecord[] = [];
  for (let i = 0; i < 30; i++) {
    out.push(i < breaks.length ? day(1380 - breaks[i].minutes, 360, 60, [breaks[i]]) : goodDay());
  }
  return out;
}

function countState(result: WearMonthResult, state: WearDayState): number {
  let n = 0;
  for (let i = 0; i < result.days.length; i++) {
    if (result.days[i].state === state) {
      n++;
    }
  }
  return n;
}

function dayOf(result: WearMonthResult, date: string): WearDayResult {
  for (let i = 0; i < result.days.length; i++) {
    if (result.days[i].date === date) {
      return result.days[i];
    }
  }
  throw new Error('no such day');
}

const SUSPICIOUS: WearBreak = gap(300, 200, 9, 0.5);
const ORDINARY: WearBreak = gap(300, 200, 1, 0.95);

export default function wearMonthTest() {
  describe('Wear month: rules', () => {
    it('the night counts when worn at least 4 h between 00:00 and 06:00', 0, () => {
      expect(isNightWorn(239, TH)).assertFalse();
      expect(isNightWorn(240, TH)).assertTrue();
      expect(isNightWorn(360, TH)).assertTrue();
      // 23 h on the wrist, but only 3 h 59 min of the night: the day does not count.
      expect(isDayCompliant(day(1380, 239, 60, []), TH)).assertFalse();
      expect(isDayCompliant(day(1380, 240, 60, []), TH)).assertTrue();
      // Minutes that are not numbers never pass, also when the night is not required.
      const noNight = JSON.parse(JSON.stringify(TH)) as Thresholds;
      noNight.nightRequired = false;
      expect(isDayCompliant(day(Number.NaN, 240, 60, []), noNight)).assertFalse();
      expect(isDayCompliant(day(1380, Number.NaN, 60, []), TH)).assertFalse();
      expect(isDayCompliant(day(1380, 240, Number.POSITIVE_INFINITY, []), noNight)).assertFalse();
      const result = buildWearMonth([day(1380, 239, 60, []), day(1380, 240, 60, [])], TH, []);
      expect(result.nightsWorn).assertEqual(1);
      expect(result.days[0].nightWorn).assertFalse();
      expect(result.days[0].state).assertEqual(WearDayState.SHORT);
      expect(result.days[1].nightWorn).assertTrue();
      expect(result.days[1].state).assertEqual(WearDayState.COMPLIANT);
    });

    it('a day counts from 20 h, with charging counted up to 120 min', 0, () => {
      expect(countedWearMinutes(1080, 120, TH)).assertEqual(1200);
      expect(countedWearMinutes(1000, 600, TH)).assertEqual(1120);
      expect(isDayCompliant(day(1080, 360, 120, []), TH)).assertTrue();
      expect(isDayCompliant(day(1079, 360, 120, []), TH)).assertFalse();
      expect(isDayCompliant(day(1000, 360, 600, []), TH)).assertFalse();
      expect(isDayCompliant(day(1200, 360, 0, []), TH)).assertTrue();
    });

    it('a break is judged only with at least 12 heart-rate readings in the 24 h before it', 0, () => {
      const few = judgeBreak(gap(300, 11, 9, 0.5), TH);
      expect(few.counted).assertTrue();
      expect(few.judged).assertFalse();
      expect(few.suspicious).assertFalse();
      const enough = judgeBreak(gap(300, 12, 9, 0.5), TH);
      expect(enough.judged).assertTrue();
      expect(enough.suspicious).assertTrue();
    });

    it('a break is suspicious only with both signs: resting heart rate +7 bpm and steps below 0.6', 0, () => {
      expect(judgeBreak(gap(300, 200, 7, 0.59), TH).suspicious).assertTrue();
      expect(judgeBreak(gap(300, 200, 6, 0.3), TH).suspicious).assertFalse();
      expect(judgeBreak(gap(300, 200, 12, 0.6), TH).suspicious).assertFalse();
      expect(judgeBreak(gap(300, 200, 0, 1), TH).suspicious).assertFalse();
    });

    it('an off-wrist stretch shorter than 2 h is not a break', 0, () => {
      const short = judgeBreak(gap(119, 200, 9, 0.5), TH);
      expect(short.counted).assertFalse();
      expect(short.judged).assertFalse();
      expect(short.suspicious).assertFalse();
      expect(judgeBreak(gap(120, 200, 9, 0.5), TH).suspicious).assertTrue();
      const result = buildWearMonth([day(1261, 360, 60, [gap(119, 200, 9, 0.5)])], TH, []);
      expect(result.totalBreaks).assertEqual(0);
      expect(result.suspiciousBreaks).assertEqual(0);
      expect(result.days[0].state).assertEqual(WearDayState.COMPLIANT);
    });

    it('charging time never hides a break', 0, () => {
      const chargingValues = [0, 60, 120, 600, 1290];
      for (let i = 0; i < chargingValues.length; i++) {
        // 150 minutes off the wrist after a suspicious day, the rest of the day worn or on the charger.
        const record = day(1290 - chargingValues[i], 360, chargingValues[i], [gap(150, 200, 9, 0.5)]);
        const result = buildWearMonth([record], TH, []);
        expect(result.totalBreaks).assertEqual(1);
        expect(result.suspiciousBreaks).assertEqual(1);
        expect(result.days[0].breaks[0].minutes).assertEqual(150);
        expect(result.days[0].breaks[0].suspicious).assertTrue();
        expect(result.days[0].state).assertEqual(WearDayState.SUSPICIOUS);
      }
      // With 120 minutes of charging the hours are enough for the day; the break is still there.
      const counted = buildWearMonth([day(1170, 360, 120, [gap(150, 200, 9, 0.5)])], TH, []);
      expect(counted.days[0].compliant).assertTrue();
      expect(counted.compliantDays).assertEqual(1);
      expect(counted.suspiciousBreaks).assertEqual(1);
      expect(counted.days[0].state).assertEqual(WearDayState.SUSPICIOUS);
    });

    it('one suspicious break never flags; three always do; two do when they are over 30% of the breaks', 0, () => {
      expect(buildWearMonth(monthWithBreaks([SUSPICIOUS]), TH, []).flagged).assertFalse();
      expect(buildWearMonth(monthWithBreaks([SUSPICIOUS, SUSPICIOUS, SUSPICIOUS]), TH, []).flagged).assertTrue();
      const twoOfFive = monthWithBreaks([SUSPICIOUS, SUSPICIOUS, ORDINARY, ORDINARY, ORDINARY]);
      expect(buildWearMonth(twoOfFive, TH, []).flagged).assertTrue();
      const twoOfSeven = monthWithBreaks([SUSPICIOUS, SUSPICIOUS, ORDINARY, ORDINARY, ORDINARY, ORDINARY, ORDINARY]);
      const result = buildWearMonth(twoOfSeven, TH, []);
      expect(result.suspiciousBreaks).assertEqual(2);
      expect(result.totalBreaks).assertEqual(7);
      expect(result.flagged).assertFalse();
      expect(buildWearMonth(monthWithBreaks([]), TH, []).flagged).assertFalse();
    });

    it('a flagged month is not eligible even when the compliance passes', 0, () => {
      const short: WearBreak[] = [gap(150, 200, 9, 0.5), gap(150, 200, 9, 0.5), gap(150, 200, 9, 0.5)];
      const result = buildWearMonth(monthWithBreaks(short), TH, []);
      expect(result.compliantDays).assertEqual(30);
      expect(result.passes).assertTrue();
      expect(result.flagged).assertTrue();
      expect(result.eligible).assertFalse();
    });

    it('the month passes from 85% of days', 0, () => {
      const month = (shortDays: number): WearDayRecord[] => {
        const out: WearDayRecord[] = [];
        for (let i = 0; i < 20; i++) {
          out.push(i < shortDays ? day(900, 360, 60, []) : goodDay());
        }
        return out;
      };
      const seventeen = buildWearMonth(month(3), TH, []);
      expect(seventeen.compliantDays).assertEqual(17);
      expect(seventeen.pct).assertEqual(85);
      expect(seventeen.passes).assertTrue();
      const sixteen = buildWearMonth(month(4), TH, []);
      expect(sixteen.pct).assertEqual(80);
      expect(sixteen.passes).assertFalse();
      expect(sixteen.redDays).assertEqual(4);
    });

    it('a day the watch did not observe is unknown: no break, not compliant, still in the total', 0, () => {
      const result = buildWearMonth([goodDay(), unobservedDay(), goodDay()], TH, []);
      expect(result.days[1].state).assertEqual(WearDayState.UNKNOWN);
      expect(result.days[1].compliant).assertFalse();
      expect(result.days[1].breaks.length).assertEqual(0);
      expect(result.unknownDays).assertEqual(1);
      expect(result.totalDays).assertEqual(3);
      expect(result.compliantDays).assertEqual(2);
      expect(result.totalBreaks).assertEqual(0);
      expect(result.redDays).assertEqual(0);
    });

    it('a sick day is left out of the total and its break is not counted', 0, () => {
      const records = [goodDay(), day(1000, 360, 60, [SUSPICIOUS]), goodDay(), goodDay()];
      const plain = buildWearMonth(records, TH, []);
      expect(plain.suspiciousBreaks).assertEqual(1);
      expect(plain.totalDays).assertEqual(4);
      const paused = buildWearMonth(records, TH, [1]);
      expect(paused.days[1].state).assertEqual(WearDayState.SICK);
      expect(paused.days[1].breaks.length).assertEqual(0);
      expect(paused.suspiciousBreaks).assertEqual(0);
      expect(paused.totalBreaks).assertEqual(0);
      expect(paused.sickDays).assertEqual(1);
      expect(paused.totalDays).assertEqual(3);
      expect(paused.compliantDays).assertEqual(3);
      expect(paused.pct).assertEqual(100);
    });

    it('at most 5 sick days are honoured', 0, () => {
      const records: WearDayRecord[] = [];
      for (let i = 0; i < 30; i++) {
        records.push(i < 8 ? day(600, 360, 60, []) : goodDay());
      }
      const result = buildWearMonth(records, TH, [7, 6, 5, 4, 3, 2, 1, 0, 0, 99, -1]);
      expect(result.sickDays).assertEqual(5);
      expect(result.totalDays).assertEqual(25);
      expect(countState(result, WearDayState.SICK)).assertEqual(5);
      expect(result.days[4].state).assertEqual(WearDayState.SICK);
      expect(result.days[5].state).assertEqual(WearDayState.SHORT);
      expect(result.redDays).assertEqual(3);
    });

    it('an empty month gives zeros, never NaN', 0, () => {
      const result = buildWearMonth([], TH, []);
      expect(result.totalDays).assertEqual(0);
      expect(result.pct).assertEqual(0);
      expect(result.passes).assertFalse();
      expect(result.flagged).assertFalse();
      expect(result.eligible).assertFalse();
      expect(result.period).assertEqual('');
    });
  });

  describe('Wear month: personas', () => {
    it('Marek: 3 suspicious breaks, flagged, 4 red days', 0, () => {
      const marek = WearPersonas.result('marek');
      expect(marek.suspiciousBreaks).assertEqual(3);
      expect(marek.flagged).assertTrue();
      expect(marek.redDays).assertEqual(4);
      expect(marek.compliantDays).assertEqual(26);
      expect(marek.totalDays).assertEqual(30);
      expect(marek.passes).assertTrue();
      expect(marek.eligible).assertFalse();
      expect(marek.totalBreaks).assertEqual(5);
      expect(countState(marek, WearDayState.COMPLIANT)).assertEqual(26);
      expect(countState(marek, WearDayState.SUSPICIOUS)).assertEqual(3);
      expect(countState(marek, WearDayState.SHORT)).assertEqual(1);
      expect(marek.nightsWorn).assertEqual(30);
    });

    it('Kasia: 1 suspicious break and no flag', 0, () => {
      const kasia = WearPersonas.result('kasia');
      expect(kasia.suspiciousBreaks).assertEqual(1);
      expect(kasia.flagged).assertFalse();
      expect(kasia.passes).assertTrue();
      expect(kasia.eligible).assertTrue();
      expect(kasia.redDays).assertEqual(4);
      expect(countState(kasia, WearDayState.SUSPICIOUS)).assertEqual(1);
      expect(countState(kasia, WearDayState.SHORT)).assertEqual(3);
      expect(kasia.nightsWorn).assertEqual(26);
    });

    it('Marek and Kasia have the same wear compliance', 0, () => {
      const marek = WearPersonas.result('marek');
      const kasia = WearPersonas.result('kasia');
      expect(kasia.compliantDays).assertEqual(marek.compliantDays);
      expect(kasia.totalDays).assertEqual(marek.totalDays);
      expect(kasia.pct).assertEqual(marek.pct);
      expect(kasia.passes).assertEqual(marek.passes);
      expect(marek.pct).assertEqual(86.7);
    });

    it('Kasia: the break with only 8 heart-rate readings before it is not judged', 0, () => {
      const kasia = WearPersonas.result('kasia');
      expect(kasia.totalBreaks).assertEqual(4);
      expect(kasia.judgedBreaks).assertEqual(3);
      const unjudged = dayOf(kasia, '2026-09-22');
      expect(unjudged.breaks[0].hrReadings24hBefore).assertEqual(8);
      expect(unjudged.breaks[0].restDeltaBpm).assertEqual(9);
      expect(unjudged.breaks[0].judged).assertFalse();
      expect(unjudged.breaks[0].suspicious).assertFalse();
      expect(unjudged.state).assertEqual(WearDayState.SHORT);
      expect(dayOf(kasia, '2026-09-14').state).assertEqual(WearDayState.SUSPICIOUS);
    });

    it('Marek, 17 September: off the wrist 13:05 for 5 h 35 min after +9 bpm and 46% fewer steps', 0, () => {
      const sheet = dayOf(WearPersonas.result('marek'), '2026-09-17');
      expect(sheet.state).assertEqual(WearDayState.SUSPICIOUS);
      expect(sheet.compliant).assertFalse();
      expect(sheet.nightWorn).assertTrue();
      expect(sheet.breaks.length).assertEqual(1);
      expect(sheet.breaks[0].startMin).assertEqual(13 * 60 + 5);
      expect(sheet.breaks[0].minutes).assertEqual(335);
      expect(sheet.breaks[0].restDeltaBpm).assertEqual(9);
      expect(sheet.breaks[0].stepsRatio).assertEqual(0.54);
      expect(sheet.breaks[0].suspicious).assertTrue();
      expect(sheet.wornMin + sheet.chargingMin + 335 <= 1440).assertTrue();
    });

    it('Ania, Tomek and Ewa are not flagged: 30, 29 and 27 compliant days', 0, () => {
      const ania = WearPersonas.result('ania');
      expect(ania.compliantDays).assertEqual(30);
      expect(ania.totalBreaks).assertEqual(0);
      expect(ania.eligible).assertTrue();
      const tomek = WearPersonas.result('tomek');
      expect(tomek.compliantDays).assertEqual(29);
      expect(tomek.suspiciousBreaks).assertEqual(0);
      expect(tomek.eligible).assertTrue();
      const ewa = WearPersonas.result('ewa');
      expect(ewa.compliantDays).assertEqual(27);
      expect(ewa.suspiciousBreaks).assertEqual(0);
      expect(ewa.flagged).assertFalse();
      expect(ewa.passes).assertTrue();
    });

    it('Ola: 6 days before she had the watch are unknown, and the watch is on for 8 nights', 0, () => {
      const ola = WearPersonas.result('ola');
      expect(ola.unknownDays).assertEqual(6);
      expect(countState(ola, WearDayState.UNKNOWN)).assertEqual(6);
      expect(ola.days[0].state).assertEqual(WearDayState.UNKNOWN);
      expect(ola.nightsWorn).assertEqual(8);
      expect(ola.compliantDays).assertEqual(8);
      expect(ola.totalDays).assertEqual(30);
      expect(ola.passes).assertFalse();
      expect(ola.suspiciousBreaks).assertEqual(0);
      expect(ola.flagged).assertFalse();
      expect(ola.eligible).assertFalse();
    });

    it('a month is 30 days ending on the persona end date, the same every time', 0, () => {
      for (let i = 0; i < HesPersonas.IDS.length; i++) {
        const id = HesPersonas.IDS[i];
        const month = WearPersonas.month(id);
        expect(month.length).assertEqual(WEAR_MONTH_DAYS);
        expect(month).assertDeepEquals(WearPersonas.month(id));
        expect(WearPersonas.result(id).period).assertEqual('2026-09-04..2026-10-03');
      }
      expect(WearPersonas.month('nobody').length).assertEqual(0);
    });

    it('the wear month and the health history describe the same days', 0, () => {
      for (let p = 0; p < HesPersonas.IDS.length; p++) {
        const id = HesPersonas.IDS[p];
        const history = HesPersonas.history(id);
        const month = WearPersonas.month(id);
        for (let i = 0; i < month.length; i++) {
          const h = history.length - month.length + i;
          if (h < 0) {
            expect(month[i].observed).assertFalse();
            continue;
          }
          expect(month[i].date).assertEqual(history[h].date);
          if (history[h].steps === HES_MISSING) {
            // No health data that day: the watch was off the wrist all day.
            expect(month[i].wornMin).assertEqual(0);
            expect(month[i].breaks[0].minutes).assertEqual(1440);
          } else {
            expect(month[i].wornMin).assertLarger(0);
            expect(month[i].nightWornMin >= 240).assertEqual(history[h].sleepMinutes !== HES_MISSING);
            expect(month[i].wornMin + month[i].chargingMin <= 1440).assertTrue();
          }
        }
      }
    });
  });
}
