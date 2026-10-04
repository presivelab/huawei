import {
  ALL_HEALTH_SCOPES,
  DayDetail,
  ENGINE_DEFAULT_ID,
  engineDayDetails,
  engineDayDetailsFrom,
  enginePersonas,
  engineReportFromPerson,
  engineReportOf,
  engineSession,
  engineSessionFrom,
  HealthSimPayload,
  HealthSimPerson,
  healthSimPerson,
  HealthScope,
  HES_PROFILES,
  HesDayRecord,
  HesPersonas,
  HesProfile,
  HesSession,
  PersonaRef,
  PARTNER_HES_PROFILE,
  PersonaReport
} from 'common';
import { ReportService } from './ReportService';

/*
 * Reports calculated by the scoring engine (HES) on the persona histories.
 *
 * One demo session per persona, created the first time the persona is asked for. A session holds the
 * completed days, the live readings of the running day and the score for the completed days. The live
 * readings are shown and never scored; closing the day adds one completed day and the score is calculated
 * again; reset goes back to the snapshot the session started from (the built-in history or the one Health
 * Sim sent). The wear month and the day details do not move.
 *
 * One session serves every weight profile: `report(id)` is the report in the partner's profile, `reportIn`
 * the same session read in another profile.
 *
 * The consent is applied here: a data type the user switched off is missing in the starting history and in
 * every day that is closed later, whether the days are the built-in ones or the ones Health Sim sent.
 */
export class EngineReportService implements ReportService {
  private sessions: Map<string, HesSession> = new Map<string, HesSession>();
  // The report of a persona in one profile as its session stands now (key: id|profile); dropped whenever the
  // session changes.
  private reports: Map<string, PersonaReport> = new Map<string, PersonaReport>();
  // The data Health Sim sent after the user's consent; null: the built-in persona histories.
  private payload: HealthSimPayload | null = null;
  // The data types the user agreed to in FairWear's own consent. Every type until a consent says otherwise.
  private scopes: HealthScope[] = ALL_HEALTH_SCOPES;

  /** Reports from now on come from the data Health Sim sent (null: the built-in histories). */
  useHealthSim(payload: HealthSimPayload | null): void {
    this.payload = payload;
    this.sessions.clear();
    this.reports.clear();
  }

  /** The data types the reports may use from now on. Every session starts again with them. */
  useScopes(scopes: HealthScope[]): void {
    this.scopes = scopes.slice();
    this.sessions.clear();
    this.reports.clear();
  }

  /** True while the reports come from Health Sim. */
  fromHealthSim(): boolean {
    return this.payload !== null;
  }

  // The person Health Sim sent for this persona, or null (no Health Sim data, or not this person).
  private person(known: string): HealthSimPerson | null {
    const payload = this.payload;
    return payload === null ? null : healthSimPerson(payload, known);
  }

  private known(id: string): string {
    return HesPersonas.has(id) ? id : ENGINE_DEFAULT_ID;
  }

  private session(known: string): HesSession {
    let session: HesSession | undefined = this.sessions.get(known);
    if (session === undefined) {
      const person = this.person(known);
      session = person === null ? engineSession(known, this.scopes) : engineSessionFrom(person, this.scopes);
      this.sessions.set(known, session);
    }
    return session;
  }

  personas(): PersonaRef[] {
    return enginePersonas();
  }

  report(id: string): PersonaReport {
    return this.reportIn(id, PARTNER_HES_PROFILE);
  }

  reportIn(id: string, profile: HesProfile): PersonaReport {
    const known: string = this.known(id);
    const key: string = `${known}|${profile}`;
    let report: PersonaReport | undefined = this.reports.get(key);
    if (report === undefined) {
      const person = this.person(known);
      report = person === null ? engineReportOf(known, this.session(known), profile) :
        engineReportFromPerson(person, this.session(known), profile);
      this.reports.set(key, report);
    }
    return report;
  }

  completedDays(id: string): HesDayRecord[] {
    return this.session(this.known(id)).history().days;
  }

  // A persona's cached reports in every profile.
  private dropReports(known: string): void {
    for (let i = 0; i < HES_PROFILES.length; i++) {
      this.reports.delete(`${known}|${HES_PROFILES[i]}`);
    }
  }

  liveSet(id: string, hr: number, steps: number): void {
    const known: string = this.known(id);
    this.session(known).setLive(hr < 0 ? undefined : hr, steps < 0 ? undefined : steps);
    this.dropReports(known);
  }

  closeDay(id: string): void {
    const known: string = this.known(id);
    this.session(known).closeDay();
    this.dropReports(known);
  }

  resetDemo(id: string): void {
    const known: string = this.known(id);
    this.session(known).resetDemo();
    this.dropReports(known);
  }

  dayDetails(id: string): DayDetail[] {
    const person = this.person(this.known(id));
    return person === null ? engineDayDetails(id) : engineDayDetailsFrom(person);
  }

  isPreview(): boolean {
    return false;
  }
}
