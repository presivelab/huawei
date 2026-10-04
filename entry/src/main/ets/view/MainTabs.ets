import { SymbolGlyphModifier } from '@kit.ArkUI';
import { FW_TAB_REPORT } from 'common';
import { KEY_TAB } from '../nav/EntryRouter';
import { EVIDENCE_TAB_TITLE, REPORT_TAB_TITLE, SHARE_TAB_TITLE } from '../report/ReportTexts';
import { SYMBOL_TAB_EVIDENCE, SYMBOL_TAB_REPORT, SYMBOL_TAB_SHARE } from '../ui/kit/KitTokens';
import { EvidenceView } from './EvidenceView';
import { ReportView } from './ReportView';
import { ShareView } from './ShareView';

// The start page after consent: three tabs under the system bottom tab bar (symbol and label).
// The tab on screen is AppStorage[KEY_TAB]: FW_TAB_REPORT, FW_TAB_EVIDENCE, FW_TAB_SHARE.
@Component
export struct MainTabs {
  @StorageLink(KEY_TAB) tab: number = FW_TAB_REPORT;

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.tab }) {
      TabContent() {
        ReportView()
      }
      .tabBar(new BottomTabBarStyle({ normal: new SymbolGlyphModifier(SYMBOL_TAB_REPORT) }, REPORT_TAB_TITLE))

      TabContent() {
        EvidenceView()
      }
      .tabBar(new BottomTabBarStyle({ normal: new SymbolGlyphModifier(SYMBOL_TAB_EVIDENCE) }, EVIDENCE_TAB_TITLE))

      TabContent() {
        ShareView()
      }
      .tabBar(new BottomTabBarStyle({ normal: new SymbolGlyphModifier(SYMBOL_TAB_SHARE) }, SHARE_TAB_TITLE))
    }
    .width('100%')
    .height('100%')
    .barBackgroundColor($r('sys.color.comp_background_primary'))
    .divider({ strokeWidth: 0.5, color: $r('sys.color.comp_divider') })
    .onChange((index: number) => {
      this.tab = index;
    })
  }
}
