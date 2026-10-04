import { READINESS_NOTE, READINESS_TITLE, ReadinessPreview, ReadinessRow } from 'common';
import { simReadiness } from '../data/SimData';
import { CARD } from './SimBanner';

// The Scenario tool's card: for the chosen person, how much of each component the history holds against what
// the score needs, and a preview in both weight profiles. Everything shown is the model of `common`
// (healthSimReadiness); nothing is calculated here. A tick or a cross always comes with its word.
@Component
export struct ReadinessView {
  @Prop personId: string = '';

  private previewLine(p: ReadinessPreview): string {
    return p.scored ? `${p.scoreText} · Tier ${p.tier} · Confidence ${p.confidenceText}` : p.scoreText;
  }

  @Builder
  rowView(row: ReadinessRow) {
    Row({ space: 10 }) {
      SymbolGlyph(row.ready ? $r('sys.symbol.checkmark') : $r('sys.symbol.xmark'))
        .fontSize(18)
        .fontColor([row.ready ? $r('sys.color.icon_emphasize') : $r('sys.color.warning')])
        .accessibilityLevel('no')
      Column({ space: 2 }) {
        Text(row.label)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_primary'))
        Text(`${row.countText} · ${row.ready ? 'Ready' : 'Not ready'}`)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(row.kind)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_primary'))
        .padding({ left: 8, right: 8, top: 2, bottom: 2 })
        .borderRadius(10)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
    }
    .width('100%')
    .constraintSize({ minHeight: 48 })
    .alignItems(VerticalAlign.Center)
    .accessibilityGroup(true)
    .accessibilityText(`${row.label}, ${row.kind}, ${row.countText}, ${row.ready ? 'ready' : 'not ready'}`)
    .id(`hs_readiness_row_${row.id}`)
  }

  @Builder
  previewView(p: ReadinessPreview) {
    Column({ space: 2 }) {
      Text(p.profileLabel)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
      Text(`Evidence coverage ${p.coverageText}`)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_secondary'))
      Text(`Preview: ${this.previewLine(p)}`)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_primary'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 6, bottom: 6 })
    .accessibilityGroup(true)
    .id(`hs_readiness_preview_${p.profile}`)
  }

  build() {
    Column({ space: 6 }) {
      Text(READINESS_TITLE)
        .fontSize($r('sys.float.Subtitle_M'))
        .fontWeight(600)
        .fontColor($r('sys.color.font_primary'))
        .id('hs_readiness_title')
      ForEach(simReadiness(this.personId).rows, (row: ReadinessRow) => {
        this.rowView(row)
      }, (row: ReadinessRow) => `${this.personId}|${row.id}`)
      Divider()
        .color($r('sys.color.comp_divider'))
        .margin({ top: 4, bottom: 4 })
      ForEach(simReadiness(this.personId).previews, (p: ReadinessPreview) => {
        this.previewView(p)
      }, (p: ReadinessPreview) => `${this.personId}|${p.profile}`)
      Text(READINESS_NOTE)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_tertiary'))
        .id('hs_readiness_note')
    }
    .attributeModifier(CARD)
    .id('hs_readiness')
  }
}
