import { DayState, periodDayIso, PersonaReport } from 'common';

/*
 * One day of the month as the day sheet of the Evidence tab reads it, and the appeals kept on this phone.
 *
 * The sheet draws; it does not judge. Minutes, breaks and the sentence that says why a day counts or does
 * not come ready from the report service. While the service has no details for a day (the fixed preview
 * has none), the sheet shows the state of the day and nothing it would have to work out itself.
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

// Day `n` of the report on screen. TODO(G1): fill the details from reportService().dayDetails(report.id)
// once the engine-backed service is merged; the preview service has no day details.
export function evidenceDay(report: PersonaReport, n: number): EvidenceDay {
  const day = noEvidenceDay();
  if (n < 1 || n > report.wear.days.length) {
    return day;
  }
  day.n = n;
  day.date = periodDayIso(report.periodIso, n);
  day.state = report.wear.days[n - 1].state;
  return day;
}
