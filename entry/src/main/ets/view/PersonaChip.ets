import { PersonaRef } from 'common';
import {
  DEFAULT_PERSONA_ID,
  KEY_PERSONA,
  reportService,
  selectPersona
} from '../report/ServiceLocator';
import {
  PERSONA_CHIP_SUFFIX,
  PERSONA_SHEET_TITLE,
  personaSheetNote,
  personaSummary
} from '../report/ReportTexts';
import { SYMBOL_CHECK, SYMBOL_EXPAND } from '../ui/kit/KitTokens';

// The demo switcher: a chip with the persona on screen ("Ania · Demo") that opens a sheet with the six
// personas. Demo only: it changes which persona's report the screens show, nothing else.
@Component
export struct PersonaChip {
  @StorageProp(KEY_PERSONA) personaId: string = DEFAULT_PERSONA_ID;
  @State open: boolean = false;

  private personaName(id: string): string {
    return reportService().report(id).name;
  }

  @Builder
  personaRow(ref: PersonaRef) {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text(ref.name)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(personaSummary(reportService().report(ref.id)))
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (ref.id === this.personaId) {
        SymbolGlyph(SYMBOL_CHECK)
          .fontSize(20)
          .fontColor([$r('sys.color.icon_emphasize')])
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 60 })
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .id(`fw_persona_${ref.id}`)
    .accessibilityGroup(true)
    .accessibilityText(`${ref.name}, ${personaSummary(reportService().report(ref.id))}` +
      (ref.id === this.personaId ? ', selected' : ''))
    .onClick(() => {
      selectPersona(ref.id);
      this.open = false;
    })
  }

  @Builder
  personaSheet() {
    Column() {
      Column() {
        ForEach(reportService().personas(), (ref: PersonaRef, index: number) => {
          if (index > 0) {
            Divider()
              .color($r('sys.color.comp_divider'))
              .margin({ left: 16, right: 16 })
          }
          this.personaRow(ref)
        }, (ref: PersonaRef) => ref.id)
      }
      .width('100%')
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(20)
    }
    .width('100%')
    .padding({
      left: 16,
      right: 16,
      top: 8,
      bottom: 40
    })
  }

  build() {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: 4 }) {
        Text(`${this.personaName(this.personaId)}${PERSONA_CHIP_SUFFIX}`)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
        SymbolGlyph(SYMBOL_EXPAND)
          .fontSize(14)
          .fontColor([$r('sys.color.icon_secondary')])
      }
      .alignItems(VerticalAlign.Center)
      .padding({ left: 12, right: 10 })
    }
    .height(36)
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .id('fw_persona_chip')
    .accessibilityText(`Demo persona ${this.personaName(this.personaId)}. Change persona`)
    .onClick(() => {
      this.open = true;
    })
    .bindSheet($$this.open, this.personaSheet(), {
      height: SheetSize.FIT_CONTENT,
      title: { title: PERSONA_SHEET_TITLE, subtitle: personaSheetNote(reportService().isPreview()) },
      showClose: true,
      backgroundColor: $r('sys.color.background_secondary')
    })
  }
}
