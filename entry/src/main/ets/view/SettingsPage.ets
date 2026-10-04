import { READS_SENTENCE } from '../addon/AddonTexts';
import { DataSourceCard, SourceStatusLine } from './SourceParts';
import { BODY_SECONDARY, CARD, TITLE } from './Styles';

// Settings: the data-source card (connect, disconnect, reconnect) and what FairWear reads.
@Component
export struct SettingsPage {
  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          SourceStatusLine()
          DataSourceCard()
          Column({ space: 8 }) {
            Text($r('app.string.settings_reads_title')).attributeModifier(TITLE)
            Text(READS_SENTENCE).attributeModifier(BODY_SECONDARY)
          }
          .attributeModifier(CARD)
        }
        .alignItems(HorizontalAlign.Start)
        .padding({
          left: $r('sys.float.padding_level8'),
          right: $r('sys.float.padding_level8'),
          bottom: $r('sys.float.padding_level12')
        })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .title($r('app.string.settings_title'))
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
