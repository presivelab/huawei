// A dot (or a system symbol) and a readable status. The dot colour of a data-source status comes from
// statusDotColor in view/Styles and its text from healthSourceLabel in common.
export interface PillParams {
  text: string;
  dot: ResourceColor;
  symbol?: Resource;    // a system symbol in place of the dot
  compact?: boolean;    // the small pill used inside a card
  textId?: string;      // element id of the text, for UI tests
}

@Builder
export function StatusPill(p: PillParams) {
  Row({ space: p.compact ? 4 : 8 }) {
    if (p.symbol !== undefined) {
      SymbolGlyph(p.symbol)
        .fontSize(16)
        .fontColor([p.dot])
    } else {
      Circle()
        .width(8)
        .height(8)
        .fill(p.dot)
    }
    Text(p.text)
      .fontSize(p.compact ? $r('sys.float.Body_S') : $r('sys.float.Body_M'))
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_primary'))
      .maxLines(1)
      .id(p.textId ?? '')
  }
  .alignItems(VerticalAlign.Center)
  .padding({
    left: p.compact ? 8 : 12,
    right: p.compact ? 8 : 12,
    top: 4,
    bottom: 4
  })
  .backgroundColor($r('sys.color.comp_background_tertiary'))
  .borderRadius($r('sys.float.corner_radius_level8'))
}
