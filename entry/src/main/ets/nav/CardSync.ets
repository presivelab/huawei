import { common } from '@kit.AbilityKit';
import { buildCardDigest, hasScore, PersonaReport } from 'common';
import { AddonSession } from '../addon/AddonSession';
import { CardStore } from '../platform/CardStore';
import { reportsFromHealthSim, reportSourceLabel, selectedReport } from '../report/ServiceLocator';

/*
 * Pushes the current state to the home-screen card. Called by the start page whenever the session or the
 * selected report changes. The card gets the data source, the coverage of the selected report and whether
 * a score exists ("Score ready"). It never gets the tier or the score. Without a connection the digest
 * carries no coverage and no result (buildCardDigest). While the reports come from Health Sim the source
 * line says so, the same words the Report screen uses.
 */
export function syncCard(context: common.Context | undefined): void {
  if (context === undefined) {
    return;
  }
  const status = AddonSession.shared().source().status();
  const report: PersonaReport = selectedReport();
  const label: string | undefined = reportsFromHealthSim() ? reportSourceLabel() : undefined;
  CardStore.publish(context, buildCardDigest(status, report.coveragePct, hasScore(report), label)).catch(() => {
    // CardStore logs its own failures; a card that cannot be refreshed must not affect the app.
  });
}
