import { common } from '@kit.AbilityKit';
import { buildCardDigest, hasScore, PersonaReport } from 'common';
import { AddonSession } from '../addon/AddonSession';
import { CardStore } from '../platform/CardStore';
import { selectedReport } from '../report/ServiceLocator';

/*
 * Pushes the current state to the home-screen card. Called by the start page whenever the session or the
 * selected report changes. The card gets the data source, the coverage of the selected report and whether
 * a score exists ("Score ready"). It never gets the tier or the score. Without a connection the digest
 * carries no coverage and no result (buildCardDigest).
 */
export function syncCard(context: common.Context | undefined): void {
  if (context === undefined) {
    return;
  }
  const status = AddonSession.shared().source().status();
  const report: PersonaReport = selectedReport();
  CardStore.publish(context, buildCardDigest(status, report.coveragePct, hasScore(report))).catch(() => {
    // CardStore logs its own failures; a card that cannot be refreshed must not affect the app.
  });
}
