import { PersonaReport, PREVIEW_DEFAULT_ID } from 'common';
import { PreviewReportService, ReportService } from './ReportService';

/*
 * The one place that decides where reports come from.
 *
 * Today: the fixed preview. When HES-Lite is in the build, replace `PreviewReportService` below with the
 * engine-backed service; `isPreview()` then returns false and the preview labels disappear by themselves.
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

const service: ReportService = new PreviewReportService();
let revision: number = 0;

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

/** Demo controls: the live readings of the selected persona. Screens reload through KEY_REPORT_REVISION. */
export function setSelectedLive(hr: number, steps: number): void {
  service.liveSet(selectedPersonaId(), hr, steps);
  revision += 1;
  AppStorage.setOrCreate<number>(KEY_REPORT_REVISION, revision);
}
