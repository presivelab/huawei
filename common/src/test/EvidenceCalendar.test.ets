import { describe, it, expect } from '@ohos/hypium';
import { DEFAULT_THRESHOLDS } from '../main/ets/model/defaults';
import { DayState, PersonaReport } from '../main/ets/report/ReportModels';
import { previewReport } from '../main/ets/report/PreviewReports';
import {
  appealKey,
  appealsIn,
  CALENDAR_WEEKDAYS,
  calendarCells,
  CalendarCell,
  calendarDaySpoken,
  canAppeal,
  clockText,
  daysInState,
  flagRuleText,
  isAppealed,
  minutesText,
  redDays,
  withAppeal,
  withoutAppealsOf
} from '../main/ets/report/EvidenceCalendar';

function cellOf(cells: CalendarCell[], n: number): CalendarCell {
  for (let i = 0; i < cells.length; i++) {
    if (cells[i].n === n) {
      return cells[i];
    }
  }
  return { n: -1, date: '', label: '', state: '' };
}

export default function evidenceCalendarTest() {
  describe('Evidence calendar', () => {
    it('the month sits in whole weeks, Monday first, with the first day under its weekday', 0, () => {
      const marek: PersonaReport = previewReport('marek');
      const cells = calendarCells(marek);
      expect(CALENDAR_WEEKDAYS.length).assertEqual(7);
      expect(cells.length % 7).assertEqual(0);
      // 4 September 2026 is a Friday: four empty cells, then the first day.
      expect(cells[3].n).assertEqual(0);
      expect(cells[4].n).assertEqual(1);
      expect(cells[4].date).assertEqual('2026-09-04');
      expect(cells[4].label).assertEqual('4');
      // 30 days after four empty cells end in the fifth week, one empty cell after them.
      expect(cells.length).assertEqual(35);
      expect(cells[33].n).assertEqual(30);
      expect(cells[33].date).assertEqual('2026-10-03');
      expect(cells[33].label).assertEqual('3');
      expect(cells[34].n).assertEqual(0);
    });

    it('every day of the period is in the calendar once, with its state', 0, () => {
      const marek: PersonaReport = previewReport('marek');
      const cells = calendarCells(marek);
      let days = 0;
      for (let i = 0; i < cells.length; i++) {
        if (cells[i].n > 0) {
          days++;
          expect(cells[i].state).assertEqual(marek.wear.days[cells[i].n - 1].state);
        } else {
          expect(cells[i].state).assertEqual('');
          expect(cells[i].date).assertEqual('');
        }
      }
      expect(days).assertEqual(marek.wear.days.length);
      expect(cellOf(cells, 17).state).assertEqual(DayState.SUSPICIOUS);
    });

    it('a period that is not a date still gives a calendar', 0, () => {
      const r: PersonaReport = previewReport('ania');
      const copy: PersonaReport = {
        id: r.id, name: r.name, period: r.period, periodIso: 'this month', profile: r.profile,
        profileLabel: r.profileLabel, partnerProfile: r.partnerProfile, hes: r.hes, tier: r.tier,
        coveragePct: r.coveragePct, coverageText: r.coverageText, confidence: r.confidence,
        showWeights: r.showWeights, eligible: r.eligible, benefit: r.benefit, benefitReason: r.benefitReason,
        pointsToNext: r.pointsToNext, components: r.components, wear: r.wear, live: r.live, whatIf: r.whatIf
      };
      const cells = calendarCells(copy);
      expect(cells[0].n).assertEqual(1);
      expect(cells[0].label).assertEqual('1');
      expect(cells.length).assertEqual(35);
    });

    it('red days are the short and the suspicious days', 0, () => {
      const marek: PersonaReport = previewReport('marek');
      expect(daysInState(marek, DayState.SUSPICIOUS)).assertEqual(3);
      expect(daysInState(marek, DayState.SHORT)).assertEqual(1);
      expect(redDays(marek)).assertEqual(4);
      const kasia: PersonaReport = previewReport('kasia');
      expect(daysInState(kasia, DayState.SUSPICIOUS)).assertEqual(1);
      expect(kasia.wear.flagged).assertFalse();
    });

    it('only a short or a suspicious day can be appealed', 0, () => {
      expect(canAppeal(DayState.SUSPICIOUS)).assertTrue();
      expect(canAppeal(DayState.SHORT)).assertTrue();
      expect(canAppeal(DayState.COMPLIANT)).assertFalse();
      expect(canAppeal(DayState.SICK)).assertFalse();
      expect(canAppeal(DayState.UNKNOWN)).assertFalse();
    });

    it('an appeal is kept per persona and calendar day, once', 0, () => {
      const none: string[] = [];
      const one = withAppeal(none, 'marek', '2026-09-20');
      expect(none.length).assertEqual(0);
      expect(one.length).assertEqual(1);
      expect(one[0]).assertEqual(appealKey('marek', '2026-09-20'));
      expect(isAppealed(one, 'marek', '2026-09-20')).assertTrue();
      expect(isAppealed(one, 'kasia', '2026-09-20')).assertFalse();
      expect(isAppealed(one, 'marek', '2026-09-21')).assertFalse();
      expect(withAppeal(one, 'marek', '2026-09-20').length).assertEqual(1);
      expect(withAppeal(one, 'marek', '').length).assertEqual(1);
      const two = withAppeal(one, 'kasia', '2026-09-17');
      expect(two.length).assertEqual(2);
      const reset = withoutAppealsOf(two, 'marek');
      expect(two.length).assertEqual(2);
      expect(reset.length).assertEqual(1);
      expect(isAppealed(reset, 'kasia', '2026-09-17')).assertTrue();
    });

    it('appeals are counted for the days of the report on screen', 0, () => {
      const marek: PersonaReport = previewReport('marek');
      let appeals: string[] = withAppeal([], 'marek', '2026-09-20');
      appeals = withAppeal(appeals, 'marek', '2026-09-06');
      appeals = withAppeal(appeals, 'kasia', '2026-09-17');
      appeals = withAppeal(appeals, 'marek', '2026-08-01');
      expect(appealsIn(marek, appeals)).assertEqual(2);
      expect(appealsIn(previewReport('ania'), appeals)).assertEqual(0);
    });

    it('minutes and clock times read as on a watch', 0, () => {
      expect(minutesText(860)).assertEqual('14 h 20 min');
      expect(minutesText(40)).assertEqual('40 min');
      expect(minutesText(120)).assertEqual('2 h');
      expect(minutesText(0)).assertEqual('0 min');
      expect(minutesText(-5)).assertEqual('0 min');
      expect(clockText(785)).assertEqual('13:05');
      expect(clockText(0)).assertEqual('00:00');
      expect(clockText(1439)).assertEqual('23:59');
      expect(clockText(5000)).assertEqual('23:59');
    });

    it('the flag rule is written with the thresholds in force', 0, () => {
      expect(flagRuleText(DEFAULT_THRESHOLDS)).assertEqual(
        'One break never flags. A flag needs 3 suspicious breaks, or 2 that are more than 30% of all breaks.');
    });

    it('a calendar day says when an appeal was sent', 0, () => {
      expect(calendarDaySpoken('20 September, suspicious break', false))
        .assertEqual('20 September, suspicious break');
      expect(calendarDaySpoken('20 September, suspicious break', true))
        .assertEqual('20 September, suspicious break, appeal sent');
    });
  });
}
