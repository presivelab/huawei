import { SymbolGlyphModifier } from '@kit.ArkUI';
import { FW_TAB_EVIDENCE, FW_TAB_REPORT, FW_TAB_SHARE, FwTarget, HealthStatus } from 'common';
import { AddonSession, KEY_REVISION, KEY_STATUS } from '../addon/AddonSession';
import {
  ROUTE_DATA_CONSENT,
  ROUTE_LEDGER,
  ROUTE_PARTNER,
  ROUTE_PLATFORM_CONSENT,
  ROUTE_SETTINGS,
  ROUTE_TOUR,
  ROUTE_VERIFICATION,
  ROUTE_WHY
} from '../addon/AddonTexts';
import { syncCard } from '../nav/CardSync';
import { KEY_ENTRY_TARGET, KEY_ENTRY_TARGET_SEQ, KEY_TAB, openTarget } from '../nav/EntryRouter';
import { DEFAULT_PERSONA_ID, KEY_PERSONA, KEY_REPORT_REVISION } from '../report/ServiceLocator';
import { EVIDENCE_TAB_TITLE, SHARE_TAB_TITLE } from '../report/ReportTexts';
import { SYMBOL_SETTINGS } from '../ui/kit/KitTokens';
import { DataConsentPage } from '../view/DataConsentPage';
import { LedgerPage } from '../view/LedgerPage';
import { MainTabs } from '../view/MainTabs';
import { PartnerPage } from '../view/PartnerPage';
import { PersonaChip } from '../view/PersonaChip';
import { PlatformConsentPage } from '../view/PlatformConsentPage';
import { SettingsPage } from '../view/SettingsPage';
import { VerificationDetailsPage } from '../view/VerificationDetailsPage';
import { WatchLinkTourPage } from '../view/WatchLinkTourPage';
import { WelcomeView } from '../view/WelcomeView';
import { WhyPage } from '../view/WhyPage';

const APP_TITLE: string = 'FairWear';
const TITLE_BAR_HEIGHT: number = 56;
// The system menu (the settings gear) is drawn over the right end of the title bar: 40 vp and its margins.
const MENU_SPACE: number = 64;

// The single start page of FairWear on the phone. Every screen of the add-on is reached from here:
// the welcome screen before consent, three tabs (Report, Evidence, Share) after it, and the pushed pages.
@Entry
@Component
struct Index {
  @Provide('fwNav') nav: NavPathStack = new NavPathStack();
  @StorageProp(KEY_STATUS) @Watch('onStatus') status: string = HealthStatus.NOT_AUTHORIZED;
  @StorageProp(KEY_REVISION) @Watch('onSessionChange') revision: number = 0;
  @StorageProp(KEY_ENTRY_TARGET_SEQ) @Watch('onEntryTarget') entryTargetSeq: number = 0;
  @StorageProp(KEY_PERSONA) @Watch('onSessionChange') personaId: string = DEFAULT_PERSONA_ID;
  @StorageProp(KEY_REPORT_REVISION) @Watch('onSessionChange') reportRevision: number = 0;
  @StorageLink(KEY_TAB) tab: number = FW_TAB_REPORT;

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

  // Keeps the home-screen card in step with the session and with the report on screen.
  onSessionChange(): void {
    syncCard(this.getUIContext().getHostContext());
  }

  // After a disconnect the next consent starts on the Report tab again.
  onStatus(): void {
    if (this.status === HealthStatus.NOT_AUTHORIZED) {
      this.tab = FW_TAB_REPORT;
    }
  }

  private connected(): boolean {
    return this.status !== HealthStatus.NOT_AUTHORIZED;
  }

  private titleText(): string {
    if (!this.connected() || this.tab === FW_TAB_REPORT) {
      return APP_TITLE;
    }
    return this.tab === FW_TAB_EVIDENCE ? EVIDENCE_TAB_TITLE : (this.tab === FW_TAB_SHARE ? SHARE_TAB_TITLE : APP_TITLE);
  }

  // The title bar of the start page: the large title of the tab and, after consent, the demo persona chip.
  // The settings gear is the system menu of the Navigation.
  @Builder
  titleBar() {
    Row({ space: 8 }) {
      Text(this.titleText())
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .id('fw_title')
      if (this.connected()) {
        PersonaChip()
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: MENU_SPACE })
    .alignItems(VerticalAlign.Center)
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
    } else if (name === ROUTE_WHY) {
      WhyPage()
    } else if (name === ROUTE_PARTNER) {
      PartnerPage()
    } else if (name === ROUTE_LEDGER) {
      LedgerPage()
    } else if (name === ROUTE_TOUR) {
      WatchLinkTourPage()
    }
  }

  build() {
    Navigation(this.nav) {
      if (this.connected()) {
        MainTabs()
      } else {
        WelcomeView()
      }
    }
    .title({ builder: this.titleBar, height: TITLE_BAR_HEIGHT })
    .hideBackButton(true)
    .mode(NavigationMode.Stack)
    .menus([
      {
        value: 'Settings',
        symbolIcon: new SymbolGlyphModifier(SYMBOL_SETTINGS),
        action: () => {
          this.nav.pushPathByName(ROUTE_SETTINGS, null);
        }
      }
    ])
    .navDestination(this.routes)
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
