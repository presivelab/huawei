import { SYMBOL_FORWARD } from './KitTokens';

export interface TextLinkParams {
  text: string;
  linkId?: string;        // element id, for UI tests
  onTap: () => void;
}

// A link to another screen: the text and a forward chevron in the accent colour, inside a text button
// at least 44 vp high.
@Builder
export function TextLink(p: TextLinkParams) {
  Button({ type: ButtonType.Normal, stateEffect: true }) {
    Row({ space: 2 }) {
      Text(p.text)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_emphasize'))
        .maxLines(1)
      SymbolGlyph(SYMBOL_FORWARD)
        .fontSize(14)
        .fontColor([$r('sys.color.icon_emphasize')])
    }
    .alignItems(VerticalAlign.Center)
  }
  .backgroundColor(Color.Transparent)
  .borderRadius($r('sys.float.corner_radius_level4'))
  .constraintSize({ minHeight: 44 })
  .padding({ left: 4, right: 0 })
  .id(p.linkId ?? '')
  .accessibilityText(p.text)
  .onClick(() => {
    p.onTap();
  })
}
