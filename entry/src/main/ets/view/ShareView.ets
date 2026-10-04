import { SHARE_PLACEHOLDER } from '../report/ReportTexts';
import { EmptyState } from '../ui/kit/EmptyState';
import { SYMBOL_TAB_SHARE } from '../ui/kit/KitTokens';
import { CARD_LARGE } from './Styles';

// The Share tab. The code for the partner (signed claim, QR code, "What the partner sees") is built here
// next; until then the tab says so.
// A builder while the screen has no state of its own; make it a @Component when it gets some.
@Builder
export function ShareView() {
  Scroll() {
    Column({ space: 14 }) {
      Column() {
        EmptyState({ symbol: SYMBOL_TAB_SHARE, sentence: SHARE_PLACEHOLDER, textId: 'fw_share_placeholder' })
      }
      .attributeModifier(CARD_LARGE)
    }
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: 16,
      right: 16,
      top: 4,
      bottom: 24
    })
  }
  .width('100%')
  .height('100%')
  .align(Alignment.Top)
  .scrollBar(BarState.Off)
}
