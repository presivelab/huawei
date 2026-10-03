import { SymbolGlyphModifier } from '@kit.ArkUI';
import { HealthStatus } from 'common';
import { AddonSession, KEY_STATUS } from '../addon/AddonSession';
import { ROUTE_DATA_CONSENT, ROUTE_PLATFORM_CONSENT, ROUTE_SETTINGS } from '../addon/AddonTexts';
import { DashboardView } from '../view/DashboardView';
import { DataConsentPage } from '../view/DataConsentPage';
import { PlatformConsentPage } from '../view/PlatformConsentPage';
import { SettingsPage } from '../view/SettingsPage';
import { WelcomeView } from '../view/WelcomeView';

// The single start page of FairWear on the phone. Every screen of the add-on is reached from here.
@Entry
@Component
struct Index {
  @Provide('fwNav') nav: NavPathStack = new NavPathStack();
  @StorageProp(KEY_STATUS) status: string = HealthStatus.NOT_AUTHORIZED;

  aboutToAppear(): void {
    AddonSession.shared().publish();
  }

  @Builder
  routes(name: string) {
    if (name === ROUTE_PLATFORM_CONSENT) {
      PlatformConsentPage()
    } else if (name === ROUTE_DATA_CONSENT) {
      DataConsentPage()
    } else if (name === ROUTE_SETTINGS) {
      SettingsPage()
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
