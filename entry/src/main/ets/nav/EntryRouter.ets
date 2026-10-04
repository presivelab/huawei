import { Want } from '@kit.AbilityKit';
import {
  CARD_PARAMS_KEY,
  FwTarget,
  FW_TARGET_PARAM,
  fwTargetOpensSettings,
  fwTargetTab,
  resolveFwTargetFromWant
} from 'common';
import { ROUTE_SETTINGS, ROUTE_TOUR } from '../addon/AddonTexts';

/*
 * The one entry into FairWear. A card tap, an icon shortcut and a host app all start EntryAbility with
 * the same optional parameter, `fwTarget`; EntryAbility hands the want to routeFromWant() and the start
 * page opens the screen. The value is untrusted input: resolveFwTargetFromWant() maps anything unknown
 * to the dashboard.
 *
 * After consent the start page is three tabs: 'dashboard' selects Report, 'evidence' Evidence and 'share'
 * Share; 'source' opens Settings (the data-source card) above the Report tab.
 */

export const KEY_ENTRY_TARGET: string = 'fwEntryTarget';
export const KEY_ENTRY_TARGET_SEQ: string = 'fwEntryTargetSeq';   // bumped on every want, so a repeated target still fires

// Index of the tab on screen (FW_TAB_REPORT, FW_TAB_EVIDENCE, FW_TAB_SHARE). The tab bar and any link that
// switches tabs bind to it.
export const KEY_TAB: string = 'fwTab';

let sequence: number = 0;

/** Called from EntryAbility.onCreate and onNewWant. Returns the resolved target. */
export function routeFromWant(want: Want): string {
  const params = want.parameters;
  const target: string = params === undefined ? FwTarget.DASHBOARD :
    resolveFwTargetFromWant(params[FW_TARGET_PARAM], params[CARD_PARAMS_KEY]);
  sequence += 1;
  AppStorage.setOrCreate<string>(KEY_ENTRY_TARGET, target);
  AppStorage.setOrCreate<number>(KEY_ENTRY_TARGET_SEQ, sequence);
  return target;
}

/** Called from the start page. Always returns to the start page first, then opens the target. */
export function openTarget(nav: NavPathStack, target: string): void {
  nav.clear();
  AppStorage.setOrCreate<number>(KEY_TAB, fwTargetTab(target));
  if (fwTargetOpensSettings(target)) {
    nav.pushPathByName(ROUTE_SETTINGS, null);
  } else if (target === FwTarget.TOUR) {
    nav.pushPathByName(ROUTE_TOUR, null);
  }
}
