import { DayDetail, PersonaReport, PREVIEW_DEFAULT_ID } from 'common';
import { EngineReportService } from './EngineReportService';
import { ReportService } from './ReportService';

/*
 * The one place that decides where reports come from.
 *
 * In use: the scoring engine (`EngineReportService`), so `isPreview()` is false and no screen writes
 * "preview". The fixed preview (`PreviewReportService`) stays in ReportService.ets as the other
 * implementation of the same interface.
 *
 * The selected persona id lives in AppStorage under KEY_PERSONA. A screen reads the report like this:
 *
 *   @StorageProp(KEY_PERSONA) @Watch('reload') personaId: string = DEFAULT_PERSONA_ID;
 *   @StorageProp(KEY_REPORT_REVISION) @Watch('reload') reportRevision: number = 0;
 *   @State report: PersonaReport = selectedReport();
 *   reload(): void { this.report = reportService().report(this.personaId); }
 */

export const KEY_PERSONA: string = 'fwPersonaId';               // id of the persona on screen
export const KEY_REPORT_REVISION: string = 'fwReportRevision';  // bumped when a report's content changes
export const DEFAULT_PERSONA_ID: string = PREVIEW_DEFAULT_ID;

const service: ReportService = new EngineReportService();
let revision: number = 0;

// Tells the screens that the content of a report changed (see the @Watch above).
function bumpRevision(): void {
  revision += 1;
  AppStorage.setOrCreate<number>(KEY_REPORT_REVISION, revision);
}

export function reportService(): ReportService {
  return service;
}

export function selectedPersonaId(): string {
  return AppStorage.get<string>(KEY_PERSONA) ?? DEFAULT_PERSONA_ID;
}

export function selectPersona(id: string): void {
  AppStorage.setOrCreate<string>(KEY_PERSONA, service.report(id).id);
}

export function selectedReport(): PersonaReport {
  return service.report(selectedPersonaId());
}

/** The days of the selected persona's wear month in detail; `[n - 1]` is day `n` of `wear.days`. */
export function selectedDayDetails(): DayDetail[] {
  return service.dayDetails(selectedPersonaId());
}

/** Demo controls: the live readings of the selected persona. Screens reload through KEY_REPORT_REVISION. */
export function setSelectedLive(hr: number, steps: number): void {
  service.liveSet(selectedPersonaId(), hr, steps);
  bumpRevision();
}

/** Demo controls: closes the running day of the selected persona; the score is calculated again. */
export function closeSelectedDay(): void {
  service.closeDay(selectedPersonaId());
  bumpRevision();
}

/** Demo controls: the selected persona goes back to its starting history, with no live readings. */
export function resetSelected(): void {
  service.resetDemo(selectedPersonaId());
  bumpRevision();
}
