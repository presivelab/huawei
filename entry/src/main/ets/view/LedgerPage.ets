import { NEXT_STEP_SENTENCE } from '../report/ReportTexts';
import { EmptyState } from '../ui/kit/EmptyState';
import { SYMBOL_INFO } from '../ui/kit/KitTokens';
import { CARD_LARGE } from './Styles';

// "What left this phone" (route ROUTE_LEDGER), to be opened from Settings › Privacy. The list of
// everything that was shared, export and delete are built here next.
// A builder while the screen has no state of its own; make it a @Component when it gets some.
@Builder
export function LedgerPage() {
  NavDestination() {
    Column() {
      Column() {
        EmptyState({ symbol: SYMBOL_INFO, sentence: NEXT_STEP_SENTENCE })
      }
      .attributeModifier(CARD_LARGE)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4 })
  }
  .title('What left this phone')
  .backgroundColor($r('sys.color.background_secondary'))
}
