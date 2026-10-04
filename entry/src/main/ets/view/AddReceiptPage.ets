import { AddReceiptResult, DEMO_RECEIPT_IDS, demoReceiptHint, demoReceiptLabel, receiptStatusMessage } from 'common';
import { DEFAULT_PERSONA_ID, KEY_PERSONA } from '../report/ServiceLocator';
import {
  COLOR_FLAG_TEXT,
  COLOR_FLAG_TINT,
  COLOR_OK_TEXT,
  SYMBOL_CHECK,
  SYMBOL_CROSS,
  SYMBOL_FORWARD,
  tierTint
} from '../ui/kit/KitTokens';
import { VisitService } from '../visits/VisitService';
import {
  ADD_DEMO_TITLE,
  ADD_INTRO,
  ADD_PASTE_BUTTON,
  ADD_PASTE_HINT,
  ADD_PASTE_TITLE,
  ADD_TITLE,
  addOutcome
} from '../visits/VisitTexts';
import { BODY_SECONDARY, CAPTION, CARD_LARGE, HEADING } from './Styles';

const TIER_A: string = 'A';

// "Add receipt" (route ROUTE_ADD_RECEIPT): one of the five demo receipts, or the text of a receipt's QR
// code. Either way the receipt goes through the same check at the source, and the screen says what the
// source answered.
@Component
export struct AddReceiptPage {
  @StorageProp(KEY_PERSONA) personaId: string = DEFAULT_PERSONA_ID;
  @State pasted: string = '';
  @State busy: boolean = false;
  @State checkedLabel: string = '';
  @State message: string = '';
  @State outcome: string = '';
  @State ok: boolean = false;

  private show(label: string, result: AddReceiptResult): void {
    this.checkedLabel = label;
    this.message = receiptStatusMessage(result.status);
    this.outcome = addOutcome(result.status, result.visit !== null, result.duplicate);
    this.ok = result.status === 'VERIFIED';
    this.busy = false;
  }

  private addDemo(demoId: string): void {
    if (this.busy) {
      return;
    }
    this.busy = true;
    VisitService.shared().addDemoReceipt(this.personaId, demoId).then((result: AddReceiptResult): void => {
      this.show(demoReceiptLabel(demoId), result);
    }).catch((): void => {
      this.busy = false;
    });
  }

  private addPasted(): void {
    if (this.busy) {
      return;
    }
    this.busy = true;
    VisitService.shared().addReceiptFromQr(this.personaId, this.pasted).then((result: AddReceiptResult): void => {
      this.show(ADD_PASTE_TITLE, result);
    }).catch((): void => {
      this.busy = false;
    });
  }

  @Builder
  resultCard() {
    Row({ space: 12 }) {
      SymbolGlyph(this.ok ? SYMBOL_CHECK : SYMBOL_CROSS)
        .fontSize(22)
        .fontColor([this.ok ? COLOR_OK_TEXT : COLOR_FLAG_TEXT])
        .width(44)
        .height(44)
        .backgroundColor(this.ok ? tierTint(TIER_A) : COLOR_FLAG_TINT)
        .borderRadius(22)
      Column({ space: 2 }) {
        Text(this.checkedLabel).attributeModifier(CAPTION)
        Text(this.message)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(600)
          .fontColor($r('sys.color.font_primary'))
          .id('fw_receipt_status')
        Text(this.outcome)
          .attributeModifier(CAPTION)
          .id('fw_receipt_outcome')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({
      left: 20,
      right: 20,
      top: 16,
      bottom: 16
    })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(24)
    .alignItems(VerticalAlign.Center)
    .accessibilityGroup(true)
  }

  @Builder
  demoRow(demoId: string) {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Text(demoReceiptLabel(demoId))
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_primary'))
        Text(demoReceiptHint(demoId)).attributeModifier(CAPTION)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SymbolGlyph(SYMBOL_FORWARD)
        .fontSize(14)
        .fontColor([$r('sys.color.icon_tertiary')])
    }
    .width('100%')
    .constraintSize({ minHeight: 52 })
    .alignItems(VerticalAlign.Center)
    .accessibilityGroup(true)
    .id(`fw_receipt_demo_${demoId}`)
    .onClick(() => {
      this.addDemo(demoId);
    })
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 14 }) {
          Text(ADD_INTRO)
            .attributeModifier(BODY_SECONDARY)
            .padding({ left: 4, right: 4 })

          if (this.message.length > 0) {
            this.resultCard()
          }

          Column({ space: 4 }) {
            Text(ADD_DEMO_TITLE).attributeModifier(HEADING)
            ForEach(DEMO_RECEIPT_IDS, (demoId: string, index: number) => {
              if (index > 0) {
                Divider().color($r('sys.color.comp_divider'))
              }
              this.demoRow(demoId)
            }, (demoId: string) => demoId)
          }
          .attributeModifier(CARD_LARGE)

          Column({ space: 10 }) {
            Text(ADD_PASTE_TITLE).attributeModifier(HEADING)
            TextArea({ placeholder: ADD_PASTE_HINT, text: this.pasted })
              .width('100%')
              .height(96)
              .fontSize($r('sys.float.Body_M'))
              .id('fw_receipt_paste')
              .onChange((value: string) => {
                this.pasted = value;
              })
            Button(ADD_PASTE_BUTTON)
              .buttonStyle(ButtonStyleMode.NORMAL)
              .width('100%')
              .constraintSize({ minHeight: 48 })
              .enabled(!this.busy && this.pasted.trim().length > 0)
              .id('fw_receipt_check')
              .onClick(() => {
                this.addPasted();
              })
          }
          .attributeModifier(CARD_LARGE)
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
    .title(ADD_TITLE)
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
