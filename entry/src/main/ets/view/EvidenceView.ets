import { ROUTE_VERIFICATION, VERIFICATION_HINT, VERIFICATION_LABEL } from '../addon/AddonTexts';
import { CAPTION } from './Styles';
import { WatchDaysCard, WatchLinkCard } from './WatchLinkCard';

// The Evidence tab. For now it holds the watch days: the Watch link card, the days from the watch and the
// way to "Verification details". The calendar of the month and the day sheet are added here next.
@Component
export struct EvidenceView {
  @Consume('fwNav') nav: NavPathStack;

  build() {
    Scroll() {
      Column({ space: 14 }) {
        WatchLinkCard()

        WatchDaysCard()

        // Everything technical about the watch link sits behind this one button.
        Column({ space: 8 }) {
          Button(VERIFICATION_LABEL)
            .buttonStyle(ButtonStyleMode.NORMAL)
            .width('100%')
            .id('fw_link_details')
            .onClick(() => {
              this.nav.pushPathByName(ROUTE_VERIFICATION, null);
            })
          Text(VERIFICATION_HINT).attributeModifier(CAPTION)
        }
        .width('100%')
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
}
