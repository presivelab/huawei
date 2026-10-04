import {
  DayDetail,
  decodeHealthSimPayload,
  encodeHealthSimPayload,
  FileTextStore,
  HEALTH_SIM_LABEL,
  HealthSimPayload,
  healthSourceLabel,
  HealthStatus,
  PersonaReport,
  PREVIEW_DEFAULT_ID
} from 'common';
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

const engine: EngineReportService = new EngineReportService();
const service: ReportService = engine;
let revision: number = 0;

// Health Sim: the data it sent after the user's consent is kept in the app sandbox, so a restart keeps it.
const HEALTH_SIM_FILE: string = 'healthsim/fwhs1.json';
let store: FileTextStore | null = null;

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

/**
 * Gives the reports their folder in the app sandbox and puts back the Health Sim data an earlier session
 * received. Call once at start (EntryAbility.onCreate) with the context's filesDir.
 */
export function attachReportStore(filesDir: string): void {
  if (store !== null || filesDir.length === 0) {
    return;
  }
  const s = new FileTextStore(filesDir);
  store = s;
  const text = s.read(HEALTH_SIM_FILE);
  if (text === null) {
    return;
  }
  const payload = decodeHealthSimPayload(text);
  if (payload !== null) {
    engine.useHealthSim(payload);
    bumpRevision();
  }
}

/** Reports now come from the data Health Sim sent (after both consents). Kept across restarts. */
export function useHealthSim(payload: HealthSimPayload): void {
  engine.useHealthSim(payload);
  const s = store;
  if (s !== null) {
    try {
      s.writeAtomic(HEALTH_SIM_FILE, encodeHealthSimPayload(payload));
    } catch (e) {
      // The data stays in memory for this session.
    }
  }
  bumpRevision();
}

/** "Disconnect": the Health Sim data is forgotten and the built-in demo histories are used again. */
export function clearHealthSim(): void {
  engine.useHealthSim(null);
  const s = store;
  if (s !== null) {
    try {
      s.remove(HEALTH_SIM_FILE);
    } catch (e) {
      // Nothing to remove.
    }
  }
  bumpRevision();
}

/** True while the reports come from Health Sim. */
export function reportsFromHealthSim(): boolean {
  return engine.fromHealthSim();
}

/** The source line for the screens: "Health Sim · Simulated data" or "HUAWEI Health · Demo data". */
export function reportSourceLabel(): string {
  return engine.fromHealthSim() ? HEALTH_SIM_LABEL : healthSourceLabel(HealthStatus.DEMO);
}
