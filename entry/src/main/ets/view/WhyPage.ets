import {
  ComponentRow,
  hasScore,
  PersonaReport,
  scoreEvidence,
  ScoreEvidence,
  whySections,
  WhySections
} from 'common';
import {
  countLine,
  countUnit,
  DISCLAIMER,
  NO_SCORE_BODY,
  NO_SCORE_HEADLINE,
  WHY_ASSUMPTIONS,
  WHY_ENOUGH,
  WHY_HOW_LINES,
  WHY_HOW_TITLE,
  WHY_IMPROVE,
  WHY_LABEL,
  WHY_MEASURED,
  WHY_MISSING,
  WHY_MISSING_NOTE,
  WHY_NEEDED,
  WHY_NOT_MEASURED,
  WHY_STRONGEST,
  whyHeadline,
  whyRowDetail,
  whySubline
} from '../report/ReportTexts';
import {
  DEFAULT_PERSONA_ID,
  KEY_PERSONA,
  KEY_REPORT_REVISION,
  reportService,
  selectedReport
} from '../report/ServiceLocator';
import { CountBar } from '../ui/kit/CountBar';
import {
  COLOR_OK_TEXT,
  componentColor,
  componentSymbol,
  SYMBOL_CHECK,
  SYMBOL_EXPAND,
  SYMBOL_FORWARD,
  SYMBOL_INFO
} from '../ui/kit/KitTokens';
import { TierBadge } from '../ui/kit/TierBadge';
import { CAPTION, CARD_LARGE, HEADING } from './Styles';

const CARD_GAP: number = 14;
const SCORE_TOP: number = 100;

// "Why this tier" (route ROUTE_WHY), opened from the score card of the Report tab: the components behind
// the tier as Strongest, To improve and Missing data, the one change that would reach the next tier, and
// how the score is calculated. Without a score there is no tier to explain: the page then shows what is
// measured so far and what a score still needs.
@Component
export struct WhyPage {
  @StorageProp(KEY_PERSONA) @Watch('reload') personaId: string = DEFAULT_PERSONA_ID;
  @StorageProp(KEY_REPORT_REVISION) @Watch('reload') reportRevision: number = 0;
  @State report: PersonaReport = selectedReport();
  @State howOpen: boolean = false;

  reload(): void {
    this.report = reportService().report(this.personaId);
  }

  private sections(): WhySections {
    return whySections(this.report);
  }

  private evidence(): ScoreEvidence {
    return scoreEvidence(this.report);
  }

  @Builder
  headerCard() {
    Row({ space: 14 }) {
      TierBadge({ tier: this.report.tier, size: 52 })
      Column({ space: 4 }) {
        Text(whyHeadline(this.report))
          .fontSize($r('sys.float.Subtitle_L'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .id('fw_why_headline')
        Text(whySubline(this.report))
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({
      left: 20,
      right: 20,
      top: 18,
      bottom: 18
    })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(24)
    .alignItems(VerticalAlign.Center)
    .accessibilityGroup(true)
  }

  @Builder
  noScoreHeader() {
    Column({ space: 6 }) {
      Text(NO_SCORE_HEADLINE)
        .fontSize($r('sys.float.Subtitle_L'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .id('fw_why_no_score')
      Text(`Coverage ${this.report.coveragePct}% · ${this.report.benefitReason}`)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
      Text(NO_SCORE_BODY)
        .attributeModifier(CAPTION)
    }
    .attributeModifier(CARD_LARGE)
  }

  // One scored component: its symbol and name, the score, a bar from 0 to 100 and the measured value.
  @Builder
  scoredRow(row: ComponentRow) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        SymbolGlyph(componentSymbol(row.id))
          .fontSize(18)
          .fontColor([componentColor(row.id)])
        Text(row.label)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(`${row.score}`)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Progress({ value: row.score, total: SCORE_TOP, type: ProgressType.Linear })
        .style({ strokeWidth: 6, enableSmoothEffect: false })
        .color(componentColor(row.id))
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .width('100%')

      Text(whyRowDetail(row))
        .attributeModifier(CAPTION)
    }
    .width('100%')
    .accessibilityGroup(true)
    .accessibilityText(`${row.label}, score ${row.score} of 100, ${whyRowDetail(row)}`)
  }

  @Builder
  scoredSection(title: string, rows: ComponentRow[], sectionId: string) {
    if (rows.length > 0) {
      Column({ space: 14 }) {
        Text(title)
          .attributeModifier(HEADING)
        ForEach(rows, (row: ComponentRow) => {
          this.scoredRow(row)
        }, (row: ComponentRow) => `${this.report.id}|${title}|${row.id}|${row.score}|${row.raw}`)
      }
      .attributeModifier(CARD_LARGE)
      .id(sectionId)
    }
  }

  @Builder
  whatIfCard() {
    if (this.report.whatIf.length > 0) {
      Row({ space: 10 }) {
        SymbolGlyph(SYMBOL_FORWARD)
          .fontSize(16)
          .fontColor([$r('sys.color.icon_emphasize')])
        Text(this.report.whatIf)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
          .id('fw_why_whatif')
      }
      .width('100%')
      .padding({
        left: 20,
        right: 20,
        top: 14,
        bottom: 14
      })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(24)
      .alignItems(VerticalAlign.Center)
    }
  }

  // A component without a value: named, with "Not measured" where a score would be. Never a number.
  @Builder
  plainRow(row: ComponentRow, note: string) {
    Row({ space: 8 }) {
      SymbolGlyph(componentSymbol(row.id))
        .fontSize(18)
        .fontColor([$r('sys.color.icon_secondary')])
      Text(row.label)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text(note)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
    }
    .width('100%')
    .constraintSize({ minHeight: 28 })
    .alignItems(VerticalAlign.Center)
    .accessibilityGroup(true)
    .accessibilityText(`${row.label}, ${note}`)
  }

  @Builder
  missingSection(rows: ComponentRow[]) {
    if (rows.length > 0) {
      Column({ space: 10 }) {
        Text(WHY_MISSING)
          .attributeModifier(HEADING)
        ForEach(rows, (row: ComponentRow) => {
          this.plainRow(row, WHY_NOT_MEASURED)
        }, (row: ComponentRow) => `${this.report.id}|missing|${row.id}`)
        Text(WHY_MISSING_NOTE)
          .attributeModifier(CAPTION)
      }
      .attributeModifier(CARD_LARGE)
      .id('fw_why_missing')
    }
  }

  // Without a score: a component that already has enough days, with the count behind it.
  @Builder
  measuredRow(row: ComponentRow) {
    Row({ space: 8 }) {
      SymbolGlyph(componentSymbol(row.id))
        .fontSize(18)
        .fontColor([componentColor(row.id)])
      Column({ space: 2 }) {
        Text(row.label)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(row.minCount > 0 ? `${countLine(row)} · ${WHY_ENOUGH}` : countLine(row))
          .attributeModifier(CAPTION)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (row.raw.length > 0) {
        Text(`${row.raw} ${row.unit}`)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
      }
      if (row.minCount > 0) {
        SymbolGlyph(SYMBOL_CHECK)
          .fontSize(16)
          .fontColor([COLOR_OK_TEXT])
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .accessibilityGroup(true)
    .accessibilityText(`${row.label}, ${countLine(row)}` + (row.raw.length > 0 ? `, ${row.raw} ${row.unit}` : ''))
  }

  @Builder
  noScoreSections() {
    if (this.evidence().measured.length > 0) {
      Column({ space: 12 }) {
        Text(WHY_MEASURED)
          .attributeModifier(HEADING)
        ForEach(this.evidence().measured, (row: ComponentRow) => {
          this.measuredRow(row)
        }, (row: ComponentRow) => `${this.report.id}|measured|${row.id}|${row.validCount}|${row.raw}`)
      }
      .attributeModifier(CARD_LARGE)
      .id('fw_why_measured')
    }
    if (this.evidence().needed.length > 0) {
      Column({ space: 12 }) {
        Text(WHY_NEEDED)
          .attributeModifier(HEADING)
        ForEach(this.evidence().needed, (row: ComponentRow) => {
          CountBar({
            name: row.label,
            have: row.validCount,
            need: row.minCount,
            unit: countUnit(row.id),
            tint: componentColor(row.id)
          })
        }, (row: ComponentRow) => `${this.report.id}|needed|${row.id}|${row.validCount}`)
      }
      .attributeModifier(CARD_LARGE)
      .id('fw_why_needed')
    }
    this.missingSection(this.evidence().notMeasured)
  }

  @Builder
  howCard() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(WHY_HOW_TITLE)
          .attributeModifier(HEADING)
          .layoutWeight(1)
        SymbolGlyph(SYMBOL_EXPAND)
          .fontSize(16)
          .fontColor([$r('sys.color.icon_secondary')])
          .rotate({ angle: this.howOpen ? 180 : 0 })
      }
      .width('100%')
      .constraintSize({ minHeight: 44 })
      .alignItems(VerticalAlign.Center)
      .id('fw_why_how')
      .accessibilityGroup(true)
      .accessibilityText(`${WHY_HOW_TITLE}, ${this.howOpen ? 'expanded' : 'collapsed'}`)
      .onClick(() => {
        this.howOpen = !this.howOpen;
      })

      if (this.howOpen) {
        ForEach(WHY_HOW_LINES, (line: string) => {
          Row({ space: 8 }) {
            SymbolGlyph(SYMBOL_INFO)
              .fontSize(14)
              .fontColor([$r('sys.color.icon_secondary')])
              .margin({ top: 3 })
            Text(line)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_primary'))
              .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }, (line: string) => line)
      }
      Text(WHY_ASSUMPTIONS)
        .attributeModifier(CAPTION)
    }
    .width('100%')
    .padding({
      left: 20,
      right: 20,
      top: 8,
      bottom: 18
    })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(24)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: CARD_GAP }) {
          if (hasScore(this.report)) {
            this.headerCard()
            this.scoredSection(WHY_STRONGEST, this.sections().strongest, 'fw_why_strongest')
            this.scoredSection(WHY_IMPROVE, this.sections().improvement, 'fw_why_improve')
            this.whatIfCard()
            this.missingSection(this.sections().missing)
          } else {
            this.noScoreHeader()
            this.noScoreSections()
          }
          this.howCard()
          Text(DISCLAIMER)
            .attributeModifier(CAPTION)
            .padding({ left: 4, right: 4 })
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
    .title(WHY_LABEL)
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
