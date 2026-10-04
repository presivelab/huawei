import { NEXT_STEP_SENTENCE } from '../report/ReportTexts';
import { EmptyState } from '../ui/kit/EmptyState';
import { SYMBOL_INFO } from '../ui/kit/KitTokens';
import { CARD_LARGE } from './Styles';

// The partner view of the demo (route ROUTE_PARTNER), opened from the Share tab once that exists.
// Verification of the code with PartnerVerifier is built here next.
// A builder while the screen has no state of its own; make it a @Component when it gets some.
@Builder
export function PartnerPage() {
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
  .title('Partner view · demo')
  .backgroundColor($r('sys.color.background_secondary'))
}
