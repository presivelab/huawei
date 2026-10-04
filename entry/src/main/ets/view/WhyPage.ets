import { NEXT_STEP_SENTENCE, WHY_LABEL } from '../report/ReportTexts';
import { EmptyState } from '../ui/kit/EmptyState';
import { SYMBOL_INFO } from '../ui/kit/KitTokens';
import { CARD_LARGE } from './Styles';

// "Why this tier" (route ROUTE_WHY), opened from the score card of the Report tab. The components behind
// the tier (strongest, to improve, missing evidence) are built here next; the page reads the selected
// report the same way ReportView does.
// A builder while the screen has no state of its own; make it a @Component when it gets some.
@Builder
export function WhyPage() {
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
  .title(WHY_LABEL)
  .backgroundColor($r('sys.color.background_secondary'))
}
