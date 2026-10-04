import { DayDetail, PersonaRef, PersonaReport } from 'common';

/*
 * Where the phone screens get the monthly report from: the scoring engine (EngineReportService). The fixed
 * preview that once stood in for it is now only a test fixture (common/src/test/fixtures/PreviewReports.ets).
 */
export interface ReportService {
  /** The personas the demo switcher lists. */
  personas(): PersonaRef[];

  /** The report of one persona; an unknown id gives the default persona. */
  report(id: string): PersonaReport;

  /** Sets the live readings of the running day for one persona (demo controls). Shown, never scored. */
  liveSet(id: string, hr: number, steps: number): void;

  /** Demo controls: today becomes a completed day of this persona and the score is calculated again. */
  closeDay(id: string): void;

  /** Demo controls: this persona goes back to its starting history, with no live readings. */
  resetDemo(id: string): void;

  /**
   * The days of the persona's wear month in detail, oldest first: `dayDetails(id)[n - 1]` is day `n` of
   * `report(id).wear.days`. Empty when the source has no details.
   */
  dayDetails(id: string): DayDetail[];

  /** True while the values are fixed preview values and not calculated: the screens then say so. */
  isPreview(): boolean;
}
