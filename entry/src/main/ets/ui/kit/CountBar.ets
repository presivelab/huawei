import { str } from '../Strings';
import { COLOR_OK_TEXT, SYMBOL_CHECK } from './KitTokens';

export interface CountBarParams {
  name: string;
  have: number;         // days or nights with data
  need: number;         // days or nights needed
  unit: string;         // "days", "nights"
  tint: ResourceColor;
}

function reached(p: CountBarParams): boolean {
  return p.have >= p.need;
}

// How much evidence there is against how much is needed: a name, "9 of 14 nights" and a bar (system
// Progress). A reached count gets a check mark; a count is never drawn as a score.
@Builder
export function CountBar(p: CountBarParams) {
  Column({ space: 6 }) {
    Row({ space: 8 }) {
      Text(p.name)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text(str($r('app.string.kit_count_of'), Math.min(p.have, p.need), p.need, p.unit))
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
      if (reached(p)) {
        SymbolGlyph(SYMBOL_CHECK)
          .fontSize(16)
          .fontColor([COLOR_OK_TEXT])
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)

    Progress({ value: Math.min(p.have, p.need), total: p.need > 0 ? p.need : 1, type: ProgressType.Linear })
      .style({ strokeWidth: 6, enableSmoothEffect: false })
      .color(p.tint)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .width('100%')
  }
  .width('100%')
  .accessibilityGroup(true)
  .accessibilityText(reached(p) ?
  str($r('app.string.kit_count_spoken_enough'), p.name, Math.min(p.have, p.need), p.need, p.unit) :
  str($r('app.string.kit_count_spoken'), p.name, Math.min(p.have, p.need), p.need, p.unit))
}
