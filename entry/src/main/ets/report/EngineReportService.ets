import {
  ALL_HEALTH_SCOPES,
  DayDetail,
  ENGINE_DEFAULT_ID,
  engineDayDetails,
  engineDayDetailsFrom,
  enginePersonas,
  engineReportFor,
  engineReportFromPerson,
  engineReportFromPersonFor,
  engineReportOf,
  engineSession,
  engineSessionFrom,
  HealthSimPayload,
  HealthSimPerson,
  healthSimPerson,
  HealthScope,
  HesDay,
  HesPersonas,
  HesProfile,
  HesSession,
  PersonaRef,
  PersonaReport,
  SHARE_PROFILE
} from 'common';
import { ReportService } from './ReportService';

/*
 * Reports calculated by the scoring engine (HES-Lite) on the persona histories.
 *
 * One demo session per persona, created the first time the persona is asked for. A session holds the
 * completed days, the live readings of the running day and the score for the completed days. The live
 * readings are shown and never scored; closing the day adds one completed day and the score is calculated
 * again; reset goes back to the persona's starting history. The wear month and the day details do not move.
 *
 * The consent is applied here: a data type the user switched off is missing in the starting history and in
 * every day that is closed later, whether the days are the built-in ones or the ones Health Sim sent.
 */
export class EngineReportService implements ReportService {
  private sessions: Map<string, HesSession> = new Map<string, HesSession>();
  // The report of a persona as its session stands now; dropped whenever the session changes.
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
    const known: string = this.known(id);
    let report: PersonaReport | undefined = this.reports.get(known);
    if (report === undefined) {
      const person = this.person(known);
      report = person === null ? engineReportOf(known, this.session(known)) :
        engineReportFromPerson(person, this.session(known));
      this.reports.set(known, report);
    }
    return report;
  }

  // The same session with the weights of another profile. The session keeps its own profile, so
  // `report(id)` (Share, the partner, the card) is not touched.
  reportFor(id: string, profile: HesProfile): PersonaReport {
    if (profile === SHARE_PROFILE) {
      return this.report(id);
    }
    const known: string = this.known(id);
    const person = this.person(known);
    return person === null ? engineReportFor(known, this.session(known), profile) :
      engineReportFromPersonFor(person, this.session(known), profile);
  }

  liveSet(id: string, hr: number, steps: number): void {
    const known: string = this.known(id);
    this.session(known).setLive(hr, steps);
    this.reports.delete(known);
  }

  closeDay(id: string): void {
    const known: string = this.known(id);
    this.session(known).closeDay();
    this.reports.delete(known);
  }

  resetDemo(id: string): void {
    const known: string = this.known(id);
    this.session(known).reset();
    this.reports.delete(known);
  }

  dayDetails(id: string): DayDetail[] {
    const person = this.person(this.known(id));
    return person === null ? engineDayDetails(id) : engineDayDetailsFrom(person);
  }

  isPreview(): boolean {
    return false;
  }

  // The same session report() reads: closed days, Health Sim data and the consent are in it.
  dayHistory(id: string): HesDay[] {
    return this.session(this.known(id)).history();
  }
}
