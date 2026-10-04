// Missing data is said, not drawn as zero: one system symbol and one sentence.
export interface EmptyParams {
  symbol: Resource;
  sentence: string;
  textId?: string;
}

@Builder
export function EmptyState(p: EmptyParams) {
  Row({ space: 12 }) {
    SymbolGlyph(p.symbol)
      .fontSize(24)
      .fontColor([$r('sys.color.icon_secondary')])
      .width(48)
      .height(48)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(24)
    Text(p.sentence)
      .fontSize($r('sys.float.Body_M'))
      .fontColor($r('sys.color.font_secondary'))
      .layoutWeight(1)
      .id(p.textId ?? '')
  }
  .width('100%')
  .alignItems(VerticalAlign.Center)
}
