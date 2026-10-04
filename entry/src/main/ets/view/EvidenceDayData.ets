import { DayDetail, DayState, periodDayIso, PersonaReport } from 'common';
import { reportService } from '../report/ServiceLocator';

/*
 * One day of the month as the day sheet of the Evidence tab reads it, and the appeals kept on this phone.
 *
 * The sheet draws; it does not judge. Minutes, breaks and the sentence that says why a day counts or does
 * not come ready from the report service (DayDetail). When the service has no details for a day, the sheet
 * shows the state of the day and nothing it would have to work out itself.
 */

// AppStorage: the appeals sent from this phone, one text per persona and calendar day (appealKey in common).
export const KEY_APPEALS: string = 'fwAppeals';

export interface EvidenceBreak {
  startMin: number;      // minute of the day the break started, 0..1439
  minutes: number;
  judged: boolean;       // enough heart-rate readings before it to judge it
  suspicious: boolean;
}

export interface EvidenceDay {
  n: number;             // day of the period, 1 is the first; 0 when no day is selected
  date: string;          // "2026-09-17"
  state: string;         // DayState
  detailed: boolean;     // false: only the state is known, the fields below are not filled
  wornMin: number;
  chargingMin: number;
  nightWorn: boolean;
  breaks: EvidenceBreak[];
  reason: string;        // ready sentence; empty when not detailed
}

export function noEvidenceDay(): EvidenceDay {
  return {
    n: 0,
    date: '',
    state: DayState.UNKNOWN,
    detailed: false,
    wornMin: 0,
    chargingMin: 0,
    nightWorn: false,
    breaks: [],
    reason: ''
  };
}

// Day `n` of the report on screen: its state from the report, its details from the report service.
export function evidenceDay(report: PersonaReport, n: number): EvidenceDay {
  const day = noEvidenceDay();
  if (n < 1 || n > report.wear.days.length) {
    return day;
  }
  day.n = n;
  day.date = periodDayIso(report.periodIso, n);
  day.state = report.wear.days[n - 1].state;
  const details: DayDetail[] = reportService().dayDetails(report.id);
  if (n > details.length) {
    return day;
  }
  const detail = details[n - 1];
  day.detailed = true;
  day.wornMin = detail.wornMin;
  day.chargingMin = detail.chargingMin;
  day.nightWorn = detail.nightWorn;
  day.reason = detail.reason;
  for (let i = 0; i < detail.breaks.length; i++) {
    day.breaks.push({
      startMin: detail.breaks[i].startMin,
      minutes: detail.breaks[i].minutes,
      judged: detail.breaks[i].judged,
      suspicious: detail.breaks[i].suspicious
    });
  }
  return day;
}
