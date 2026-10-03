import { common } from '@kit.AbilityKit';
import { buildCardDigest, CARD_COVERAGE_NONE } from 'common';
import { AddonSession } from '../addon/AddonSession';
import { CardStore } from '../platform/CardStore';

/*
 * Pushes the current state to the home-screen card. Called by the start page whenever the session changes.
 * HES-Lite is not part of this build yet, so there is no coverage figure and no result to report:
 * the card shows the data source and dashes.
 */
export function syncCard(context: common.Context | undefined): void {
  if (context === undefined) {
    return;
  }
  const status = AddonSession.shared().source().status();
  CardStore.publish(context, buildCardDigest(status, CARD_COVERAGE_NONE, false)).catch(() => {
    // CardStore logs its own failures; a card that cannot be refreshed must not affect the app.
  });
}
