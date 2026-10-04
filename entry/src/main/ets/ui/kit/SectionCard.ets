import { CARD, TITLE } from '../../view/Styles';
import { StatusPill } from './StatusPill';

// A rounded card with a title and no border; an optional status pill sits at the right of the title.
// A component (not a builder) because it takes its content as a trailing closure.
@Component
export struct SectionCard {
  @Prop title: ResourceStr = '';
  @Prop status: string = '';
  @Prop statusColor: ResourceColor = $r('sys.color.font_tertiary');
  statusId: string = '';
  @BuilderParam content: () => void = this.nothing;

  @Builder
  nothing() {
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text(this.title)
          .attributeModifier(TITLE)
          .layoutWeight(1)
        if (this.status.length > 0) {
          StatusPill({ text: this.status, dot: this.statusColor, compact: true, textId: this.statusId })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      this.content()
    }
    .attributeModifier(CARD)
  }
}
