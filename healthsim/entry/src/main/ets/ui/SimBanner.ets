import { BANNER } from '../data/SimTexts';

// The banner at the top of every Health Sim screen: the data is simulated and the app only stands in for
// HUAWEI Health. Neutral inverse colours (the text colour as background), so it stands out in light and
// in dark mode without using a brand colour.
@Builder
export function SimBanner() {
  Row({ space: 8 }) {
    SymbolGlyph($r('sys.symbol.info_circle'))
      .fontSize(16)
      .fontColor([$r('sys.color.background_primary')])
    Text(BANNER)
      .fontSize($r('sys.float.Body_S'))
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.background_primary'))
      .layoutWeight(1)
  }
  .width('100%')
  .padding({
    left: 16,
    right: 16,
    top: 8,
    bottom: 8
  })
  .backgroundColor($r('sys.color.font_primary'))
  .alignItems(VerticalAlign.Center)
  .id('hs_banner')
  .accessibilityGroup(true)
  .accessibilityText(BANNER)
}

export class CardStyle implements AttributeModifier<ColumnAttribute> {
  applyNormalAttribute(instance: ColumnAttribute): void {
    instance
      .width('100%')
      .padding({
        left: 20,
        right: 20,
        top: 18,
        bottom: 18
      })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(24)
      .alignItems(HorizontalAlign.Start);
  }
}

export const CARD: CardStyle = new CardStyle();
