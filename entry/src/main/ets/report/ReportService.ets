import { DayDetail, HesProfile, LiveNow, PersonaRef, PersonaReport, previewPersonas, previewReport } from 'common';

/*
 * Where the phone screens get the monthly report from. Two implementations: the scoring engine
 * (EngineReportService, the one in use) and the fixed preview below. ServiceLocator chooses; no screen
 * changes with the choice.
 */
export interface ReportService {
  /** The personas the demo switcher lists. */
  personas(): PersonaRef[];

  /** The report of one persona; an unknown id gives the default persona. Always for health insurance. */
  report(id: string): PersonaReport;

  /**
   * The same report with the weights of `profile`, on the same completed days. For the Report tab and
   * "Why this tier" only: Share, the partner, the home-screen card and speech use `report(id)`.
   */
  reportFor(id: string, profile: HesProfile): PersonaReport;

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

/** Fixed preview reports from `common` (PreviewReports). Nothing is calculated here. */
export class PreviewReportService implements ReportService {
  private live: Map<string, LiveNow> = new Map<string, LiveNow>();

  personas(): PersonaRef[] {
    return previewPersonas();
  }

  report(id: string): PersonaReport {
    const base: PersonaReport = previewReport(id);
    const live: LiveNow | undefined = this.live.get(base.id);
    if (live === undefined) {
      return base;
    }
    const copy: PersonaReport = {
      id: base.id,
      name: base.name,
      profile: base.profile,
      period: base.period,
      periodIso: base.periodIso,
      hes: base.hes,
      tier: base.tier,
      coveragePct: base.coveragePct,
      confidence: base.confidence,
      eligible: base.eligible,
      benefit: base.benefit,
      benefitReason: base.benefitReason,
      discountPct: base.discountPct,
      pointsToNext: base.pointsToNext,
      components: base.components,
      wear: base.wear,
      live: live,
      whatIf: base.whatIf
    };
    return copy;
  }

  // The preview is fixed: it has one set of results, whatever the profile.
  reportFor(id: string, profile: HesProfile): PersonaReport {
    return this.report(id);
  }

  liveSet(id: string, hr: number, steps: number): void {
    const live: LiveNow = { hr: hr, steps: steps };
    this.live.set(previewReport(id).id, live);
  }

  // The preview is fixed: there is no day to close and nothing to go back to.
  closeDay(id: string): void {
  }

  resetDemo(id: string): void {
  }

  dayDetails(id: string): DayDetail[] {
    return [];
  }

  isPreview(): boolean {
    return true;
  }
}
