import { SymbolGlyphModifier } from '@kit.ArkUI';
import { FwTarget, HealthStatus } from 'common';
import { AddonSession, KEY_REVISION, KEY_STATUS } from '../addon/AddonSession';
import {
  ROUTE_DATA_CONSENT,
  ROUTE_PLATFORM_CONSENT,
  ROUTE_SETTINGS,
  ROUTE_TOUR,
  ROUTE_VERIFICATION
} from '../addon/AddonTexts';
import { syncCard } from '../nav/CardSync';
import { KEY_ENTRY_TARGET, KEY_ENTRY_TARGET_SEQ, openTarget } from '../nav/EntryRouter';
import { DashboardView } from '../view/DashboardView';
import { DataConsentPage } from '../view/DataConsentPage';
import { PlatformConsentPage } from '../view/PlatformConsentPage';
import { SettingsPage } from '../view/SettingsPage';
import { VerificationDetailsPage } from '../view/VerificationDetailsPage';
import { WatchLinkTourPage } from '../view/WatchLinkTourPage';
import { WelcomeView } from '../view/WelcomeView';

// The single start page of FairWear on the phone. Every screen of the add-on is reached from here.
@Entry
@Component
struct Index {
  @Provide('fwNav') nav: NavPathStack = new NavPathStack();
  @StorageProp(KEY_STATUS) status: string = HealthStatus.NOT_AUTHORIZED;
  @StorageProp(KEY_REVISION) @Watch('onSessionChange') revision: number = 0;
  @StorageProp(KEY_ENTRY_TARGET_SEQ) @Watch('onEntryTarget') entryTargetSeq: number = 0;

  aboutToAppear(): void {
    AddonSession.shared().publish();
    this.onSessionChange();
    if (this.entryTargetSeq > 0) {
      this.onEntryTarget();
    }
  }

  // A card tap, an icon shortcut or a host app asked for a screen (see nav/EntryRouter).
  onEntryTarget(): void {
    openTarget(this.nav, AppStorage.get<string>(KEY_ENTRY_TARGET) ?? FwTarget.DASHBOARD);
  }

  // Keeps the home-screen card in step with the session.
  onSessionChange(): void {
    syncCard(this.getUIContext().getHostContext());
  }

  @Builder
  routes(name: string) {
    if (name === ROUTE_PLATFORM_CONSENT) {
      PlatformConsentPage()
    } else if (name === ROUTE_DATA_CONSENT) {
      DataConsentPage()
    } else if (name === ROUTE_SETTINGS) {
      SettingsPage()
    } else if (name === ROUTE_VERIFICATION) {
      VerificationDetailsPage()
    } else if (name === ROUTE_TOUR) {
      WatchLinkTourPage()
    }
  }

  build() {
    Navigation(this.nav) {
      if (this.status === HealthStatus.NOT_AUTHORIZED) {
        WelcomeView()
      } else {
        DashboardView()
      }
    }
    .title('FairWear')
    .titleMode(NavigationTitleMode.Full)
    .hideBackButton(true)
    .mode(NavigationMode.Stack)
    .menus([
      {
        value: 'Settings',
        symbolIcon: new SymbolGlyphModifier($r('sys.symbol.gearshape')),
        action: () => {
          this.nav.pushPathByName(ROUTE_SETTINGS, null);
        }
      }
    ])
    .navDestination(this.routes)
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
