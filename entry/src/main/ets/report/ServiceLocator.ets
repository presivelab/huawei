import {
  ALL_HEALTH_SCOPES,
  DayDetail,
  decodeHealthSimPayload,
  encodeHealthSimPayload,
  FileTextStore,
  HEALTH_SIM_LABEL,
  HealthSimPayload,
  HealthScope,
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
// The data types of FairWear's own consent, as a JSON array of HealthScope names. Kept next to the data so a
// restart does not bring a switched-off type back when a day is closed.
const SCOPES_FILE: string = 'healthsim/scopes.json';
let store: FileTextStore | null = null;

// The stored consent, read strictly: an array of known names with no repeats. Anything else gives null.
function decodeScopes(text: string): HealthScope[] | null {
  try {
    const parsed: Object | null = JSON.parse(text) as Object | null;
    if (parsed === null || !Array.isArray(parsed)) {
      return null;
    }
    const items: Object[] = parsed as Object[];
    const out: HealthScope[] = [];
    for (let i = 0; i < items.length; i++) {
      const item: Object = items[i];
      if (typeof item !== 'string') {
        return null;
      }
      let found: HealthScope | null = null;
      for (let k = 0; k < ALL_HEALTH_SCOPES.length; k++) {
        if (ALL_HEALTH_SCOPES[k] === item) {
          found = ALL_HEALTH_SCOPES[k];
        }
      }
      if (found === null || out.indexOf(found) >= 0) {
        return null;
      }
      out.push(found);
    }
    return out;
  } catch (e) {
    return null;
  }
}

function encodeScopes(scopes: HealthScope[]): string {
  const names: string[] = [];
  for (let i = 0; i < scopes.length; i++) {
    names.push(scopes[i]);
  }
  return JSON.stringify(names);
}

function storeScopes(scopes: HealthScope[]): void {
  const s = store;
  if (s !== null) {
    try {
      s.writeAtomic(SCOPES_FILE, encodeScopes(scopes));
    } catch (e) {
      // The consent stays in memory for this session.
    }
  }
}

function removeStored(path: string): void {
  const s = store;
  if (s !== null) {
    try {
      s.remove(path);
    } catch (e) {
      // Nothing to remove.
    }
  }
}

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
 * Gives the reports their folder in the app sandbox and puts back what an earlier session left there: the
 * data types of the consent and the Health Sim data. A consent file that does not read as a list of known
 * data types counts as every type. Call once at start (EntryAbility.onCreate) with the context's filesDir.
 */
export function attachReportStore(filesDir: string): void {
  if (store !== null || filesDir.length === 0) {
    return;
  }
  const s = new FileTextStore(filesDir);
  store = s;
  let changed = false;
  const scopesText = s.read(SCOPES_FILE);
  if (scopesText !== null) {
    const scopes = decodeScopes(scopesText);
    engine.useScopes(scopes === null ? ALL_HEALTH_SCOPES : scopes);
    changed = true;
  }
  const text = s.read(HEALTH_SIM_FILE);
  if (text !== null) {
    const payload = decodeHealthSimPayload(text);
    if (payload !== null) {
      engine.useHealthSim(payload);
      changed = true;
    }
  }
  if (changed) {
    bumpRevision();
  }
}

/**
 * Reports now come from the data Health Sim sent (after both consents). `scopes` are the data types the
 * user left switched on: they also apply to every day closed later. Kept across restarts.
 */
export function useHealthSim(payload: HealthSimPayload, scopes: HealthScope[] = ALL_HEALTH_SCOPES): void {
  engine.useHealthSim(payload);
  engine.useScopes(scopes);
  storeScopes(scopes);
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

/**
 * Consent without Health Sim: the built-in demo histories with the data types the user left switched on.
 * Any Health Sim data from an earlier session is forgotten. Kept across restarts.
 */
export function useBuiltIn(scopes: HealthScope[]): void {
  engine.useHealthSim(null);
  engine.useScopes(scopes);
  removeStored(HEALTH_SIM_FILE);
  storeScopes(scopes);
  bumpRevision();
}

/**
 * "Disconnect": the Health Sim data and the consent are forgotten; the built-in demo histories are used
 * again with every data type, until the next consent.
 */
export function clearHealthSim(): void {
  engine.useHealthSim(null);
  engine.useScopes(ALL_HEALTH_SCOPES);
  removeStored(HEALTH_SIM_FILE);
  removeStored(SCOPES_FILE);
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
