import {
  DayDetail,
  ENGINE_DEFAULT_ID,
  engineDayDetails,
  enginePersonas,
  engineReportOf,
  engineSession,
  HesPersonas,
  HesSession,
  PersonaRef,
  PersonaReport
} from 'common';
import { ReportService } from './ReportService';

/*
 * Reports calculated by the scoring engine (HES-Lite) on the persona histories.
 *
 * One demo session per persona, created the first time the persona is asked for. A session holds the
 * completed days, the live readings of the running day and the score for the completed days. The live
 * readings are shown and never scored; closing the day adds one completed day and the score is calculated
 * again; reset goes back to the persona's starting history. The wear month and the day details do not move.
 */
export class EngineReportService implements ReportService {
  private sessions: Map<string, HesSession> = new Map<string, HesSession>();
  // The report of a persona as its session stands now; dropped whenever the session changes.
  private reports: Map<string, PersonaReport> = new Map<string, PersonaReport>();

  private known(id: string): string {
    return HesPersonas.has(id) ? id : ENGINE_DEFAULT_ID;
  }

  private session(known: string): HesSession {
    let session: HesSession | undefined = this.sessions.get(known);
    if (session === undefined) {
      session = engineSession(known);
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
      report = engineReportOf(known, this.session(known));
      this.reports.set(known, report);
    }
    return report;
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
    return engineDayDetails(id);
  }

  isPreview(): boolean {
    return false;
  }
}
