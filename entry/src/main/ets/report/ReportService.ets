import { LiveNow, PersonaRef, PersonaReport, previewPersonas, previewReport } from 'common';

/*
 * Where the phone screens get the monthly report from. One implementation today: the fixed preview.
 * When the scoring engine (HES-Lite) is part of the build, an engine-backed implementation takes its
 * place in ServiceLocator and no screen changes.
 */
export interface ReportService {
  /** The personas the demo switcher lists. */
  personas(): PersonaRef[];

  /** The report of one persona; an unknown id gives the default persona. */
  report(id: string): PersonaReport;

  /** Sets the live readings of the running day for one persona (demo controls). Shown, never scored. */
  liveSet(id: string, hr: number, steps: number): void;

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
      period: base.period,
      periodIso: base.periodIso,
      hes: base.hes,
      tier: base.tier,
      coveragePct: base.coveragePct,
      confidence: base.confidence,
      eligible: base.eligible,
      benefit: base.benefit,
      benefitReason: base.benefitReason,
      pointsToNext: base.pointsToNext,
      components: base.components,
      wear: base.wear,
      live: live,
      whatIf: base.whatIf
    };
    return copy;
  }

  liveSet(id: string, hr: number, steps: number): void {
    const live: LiveNow = { hr: hr, steps: steps };
    this.live.set(previewReport(id).id, live);
  }

  isPreview(): boolean {
    return true;
  }
}
