export interface InfoChipParams {
  text: string;
  fill?: ResourceColor;       // background; the neutral chip grey by default
  textColor?: ResourceColor;  // primary text by default
  strong?: boolean;           // medium weight, for a chip that states a condition ("Flagged")
}

// A small rounded label without a dot: a fact about the thing next to it ("Coverage 100%"), or, with a
// tint, a condition ("Live · not scored", "Flagged").
@Builder
export function InfoChip(p: InfoChipParams) {
  Text(p.text)
    .fontSize($r('sys.float.Body_S'))
    .fontWeight(p.strong ? FontWeight.Medium : FontWeight.Regular)
    .fontColor(p.textColor ?? $r('sys.color.font_primary'))
    .maxLines(1)
    .padding({
      left: 10,
      right: 10,
      top: 4,
      bottom: 4
    })
    .backgroundColor(p.fill ?? $r('sys.color.comp_background_tertiary'))
    .borderRadius(12)
}
