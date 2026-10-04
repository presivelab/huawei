import {
  ComponentRow,
  hasScore,
  PARTNER_HES_PROFILE,
  PersonaReport,
  whySections,
  WhySections
} from 'common';
import {
  DISCLAIMER,
  measuredLine,
  NO_SCORE_BODY,
  NO_SCORE_HEADLINE,
  noScoreSubline,
  WHY_ASSUMPTIONS,
  WHY_HOW_LINES,
  WHY_HOW_TITLE,
  WHY_IMPROVE,
  WHY_LABEL,
  WHY_MEASURED,
  WHY_MISSING,
  WHY_MISSING_NOTE,
  WHY_NEEDED,
  WHY_OPTIONAL_NOT_YET,
  WHY_STRONGEST,
  whyHeadline,
  whyRowDetail,
  whySubline
} from '../report/ReportTexts';
import {
  DEFAULT_PERSONA_ID,
  KEY_PERSONA,
  KEY_PROFILE,
  KEY_REPORT_REVISION,
  selectedReport
} from '../report/ServiceLocator';
import {
  componentColor,
  componentSymbol,
  SYMBOL_EXPAND,
  SYMBOL_FORWARD,
  SYMBOL_INFO
} from '../ui/kit/KitTokens';
import { TierBadge } from '../ui/kit/TierBadge';
import { profileSwitch } from './ProfileSwitch';
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
  @StorageProp(KEY_PROFILE) @Watch('reload') profile: string = PARTNER_HES_PROFILE;
  @StorageProp(KEY_REPORT_REVISION) @Watch('reload') reportRevision: number = 0;
  @State report: PersonaReport = selectedReport();
  @State howOpen: boolean = false;

  reload(): void {
    this.report = selectedReport();
  }

  private sections(): WhySections {
    return whySections(this.report);
  }

  // Without a score: the rows that have data (raw values only), the Core rows still short of their minimum,
  // and the optional rows without enough data. Every row is in exactly one list.
  private rowsWhere(core: boolean, available: boolean): ComponentRow[] {
    const out: ComponentRow[] = [];
    for (let i = 0; i < this.report.components.length; i++) {
      const row = this.report.components[i];
      if (available ? row.available : (!row.available && row.core === core)) {
        out.push(row);
      }
    }
    return out;
  }

  // The sections read the report on screen themselves, so they follow a closed day or another persona.
  private scoredRows(improve: boolean): ComponentRow[] {
    return improve ? this.sections().improvement : this.sections().strongest;
  }

  private missingRows(): ComponentRow[] {
    return this.sections().missingOptional;
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
      Text(noScoreSubline(this.report))
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

      Text(whyRowDetail(row, this.report.showWeights))
        .attributeModifier(CAPTION)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .accessibilityGroup(true)
    .accessibilityText(`${row.label}, score ${row.score} of 100, ${whyRowDetail(row, this.report.showWeights)}`)
  }

  @Builder
  scoredSection(title: string, improve: boolean, sectionId: string) {
    if (this.scoredRows(improve).length > 0) {
      Column({ space: 14 }) {
        Text(title)
          .attributeModifier(HEADING)
        ForEach(this.scoredRows(improve), (row: ComponentRow) => {
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

  // A component without enough data: named, with how far its data is ("0 of 1") where a score would be.
  // Never a score and never a zero.
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
  missingSection() {
    if (this.missingRows().length > 0) {
      Column({ space: 10 }) {
        Text(WHY_MISSING)
          .attributeModifier(HEADING)
        ForEach(this.missingRows(), (row: ComponentRow) => {
          this.plainRow(row, row.countText)
        }, (row: ComponentRow) => `${this.report.id}|missing|${row.id}|${row.countText}`)
        Text(WHY_MISSING_NOTE)
          .attributeModifier(CAPTION)
      }
      .attributeModifier(CARD_LARGE)
      .id('fw_why_missing')
    }
  }

  // Without a score: a measure that has data, as its raw value and the count behind it. No component score.
  @Builder
  measuredRow(row: ComponentRow) {
    Row({ space: 8 }) {
      SymbolGlyph(componentSymbol(row.id))
        .fontSize(18)
        .fontColor([componentColor(row.id)])
      Text(measuredLine(row))
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_primary'))
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .accessibilityGroup(true)
    .accessibilityText(measuredLine(row))
  }

  @Builder
  noScoreSections() {
    if (this.rowsWhere(false, true).length > 0) {
      Column({ space: 12 }) {
        Text(WHY_MEASURED)
          .attributeModifier(HEADING)
        ForEach(this.rowsWhere(false, true), (row: ComponentRow) => {
          this.measuredRow(row)
        }, (row: ComponentRow) => `${this.report.id}|measured|${row.id}|${row.validCount}|${row.rawText}`)
      }
      .attributeModifier(CARD_LARGE)
      .id('fw_why_measured')
    }
    if (this.rowsWhere(true, false).length > 0) {
      Column({ space: 10 }) {
        Text(WHY_NEEDED)
          .attributeModifier(HEADING)
        ForEach(this.rowsWhere(true, false), (row: ComponentRow) => {
          this.plainRow(row, row.countText)
        }, (row: ComponentRow) => `${this.report.id}|needed|${row.id}|${row.countText}`)
      }
      .attributeModifier(CARD_LARGE)
      .id('fw_why_needed')
    }
    if (this.rowsWhere(false, false).length > 0) {
      Column({ space: 10 }) {
        Text(WHY_OPTIONAL_NOT_YET)
          .attributeModifier(HEADING)
        ForEach(this.rowsWhere(false, false), (row: ComponentRow) => {
          this.plainRow(row, row.countText)
        }, (row: ComponentRow) => `${this.report.id}|optional|${row.id}|${row.countText}`)
      }
      .attributeModifier(CARD_LARGE)
      .id('fw_why_optional')
    }
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
          profileSwitch(this.profile)
          if (hasScore(this.report)) {
            this.headerCard()
            this.scoredSection(WHY_STRONGEST, false, 'fw_why_strongest')
            this.scoredSection(WHY_IMPROVE, true, 'fw_why_improve')
            this.whatIfCard()
            this.missingSection()
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
