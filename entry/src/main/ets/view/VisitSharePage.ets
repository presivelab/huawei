import { ClaimLine, keySourceLabel, tokenLengthLine, Visit, VISIT_NEVER_SHARED, visitClaimLines, visitShareBlock } from 'common';
import { EmptyState } from '../ui/kit/EmptyState';
import { InfoChip } from '../ui/kit/InfoChip';
import {
  COLOR_NOTE_TEXT,
  COLOR_NOTE_TINT,
  COLOR_OK_TEXT,
  SYMBOL_INFO,
  SYMBOL_KEY_HELD,
  SYMBOL_TAB_SHARE
} from '../ui/kit/KitTokens';
import { KEY_VISITS_REVISION, VisitCode, VisitService } from '../visits/VisitService';
import {
  KEY_VISIT_SELECTED,
  PARTNER_SEES_TITLE,
  ROUTE_VISIT_CHECK,
  SHARE_DISABLED_LABEL,
  SHARE_FAILED,
  SHARE_INTRO,
  SHARE_NEW_CODE,
  SHARE_NOT_IN_LEDGER,
  SHARE_OPEN_CHECK,
  SHARE_QR_SPOKEN,
  SHARE_SIGNING,
  SHARE_TITLE,
  SHARE_USED
} from '../visits/VisitTexts';
import { BODY_SECONDARY, CAPTION, CARD_LARGE, HEADING } from './Styles';

const QR_SIDE: number = 232;

interface LineParams {
  label: string;
  value: string;
}

// "Share visit" (route ROUTE_VISIT_SHARE): the visit claim signed with the device key, as a QR code, and
// what it says in plain words. The nonce comes from the demo partner. A visit that may not be shared
// (emergency or inpatient care, or a receipt that did not verify) gets no code: the button is off and the
// screen says why.
@Component
export struct VisitSharePage {
  @Consume('fwNav') nav: NavPathStack;
  @StorageProp(KEY_VISIT_SELECTED) visitId: string = '';
  @StorageProp(KEY_VISITS_REVISION) @Watch('syncCode') visitsRevision: number = 0;
  @State code: VisitCode | null = null;
  @State block: string = '';
  @State failure: string = '';
  @State pending: number = 0;

  aboutToAppear(): void {
    VisitService.shared().ready().then((): void => {
      const visit: Visit | null = VisitService.shared().visit(this.visitId);
      this.block = visit === null ? SHARE_DISABLED_LABEL : visitShareBlock(visit);
      this.syncCode();
      if (this.block.length === 0) {
        this.request(false);
      }
    });
  }

  syncCode(): void {
    const have = VisitService.shared().current();
    this.code = have !== null && have.visitId === this.visitId ? have : null;
  }

  private request(fresh: boolean): void {
    if (this.block.length > 0) {
      return;
    }
    this.failure = '';
    this.pending += 1;
    VisitService.shared().codeFor(this.visitId, fresh).then((): void => {
      this.pending -= 1;
      this.syncCode();
    }).catch((e: Error) => {
      this.pending -= 1;
      this.failure = SHARE_FAILED + e.message;
    });
  }

  @Builder
  line(p: LineParams) {
    Row({ space: 12 }) {
      Text(p.label).attributeModifier(CAPTION)
      Text(p.value)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.End)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  partnerSeesCard() {
    Column({ space: 10 }) {
      Text(PARTNER_SEES_TITLE).attributeModifier(HEADING)
      if (this.code !== null) {
        ForEach(visitClaimLines(this.code.claim), (l: ClaimLine) => {
          this.line({ label: l.label, value: l.value })
        }, (l: ClaimLine) => `${l.label}|${l.value}`)
      }
      Text(VISIT_NEVER_SHARED)
        .attributeModifier(CAPTION)
        .id('fw_visit_share_never')
    }
    .attributeModifier(CARD_LARGE)
  }

  @Builder
  codeCard() {
    Column() {
      Column({ space: 14 }) {
        if (this.block.length > 0) {
          EmptyState({ symbol: SYMBOL_TAB_SHARE, sentence: this.block, textId: 'fw_visit_share_block' })
        } else if (this.code !== null) {
          // A QR code stays dark on white in dark mode too, with a white margin around it.
          Column() {
            QRCode(this.code.token)
              .width(QR_SIDE)
              .height(QR_SIDE)
              .color(Color.Black)
              .backgroundColor(Color.White)
              .contentOpacity(this.code.used ? 0.25 : 1)
              .accessibilityText(SHARE_QR_SPOKEN)
              .id('fw_visit_qr')
          }
          .padding(12)
          .backgroundColor(Color.White)
          .borderRadius(12)

          if (this.code.used) {
            InfoChip({
              text: SHARE_USED,
              fill: COLOR_NOTE_TINT,
              textColor: COLOR_NOTE_TEXT,
              strong: true
            })
            Button(SHARE_NEW_CODE)
              .buttonStyle(ButtonStyleMode.NORMAL)
              .enabled(this.pending === 0)
              .id('fw_visit_new_code')
              .onClick(() => {
                this.request(true);
              })
          }
          Row({ space: 8 }) {
            Text(tokenLengthLine(this.code.token)).attributeModifier(CAPTION)
            Text('·').attributeModifier(CAPTION)
            SymbolGlyph(SYMBOL_KEY_HELD)
              .fontSize(14)
              .fontColor([COLOR_OK_TEXT])
            Text(keySourceLabel(this.code.keySource))
              .attributeModifier(CAPTION)
              .id('fw_visit_share_key')
          }
          .alignItems(VerticalAlign.Center)

          Text(SHARE_NOT_IN_LEDGER)
            .attributeModifier(CAPTION)
            .textAlign(TextAlign.Center)
        } else if (this.failure.length > 0) {
          EmptyState({ symbol: SYMBOL_INFO, sentence: this.failure })
        } else {
          Row({ space: 12 }) {
            LoadingProgress()
              .width(24)
              .height(24)
              .color($r('sys.color.icon_secondary'))
            Text(SHARE_SIGNING).attributeModifier(BODY_SECONDARY)
          }
          .alignItems(VerticalAlign.Center)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .attributeModifier(CARD_LARGE)
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 14 }) {
          Text(SHARE_INTRO)
            .attributeModifier(BODY_SECONDARY)
            .padding({ left: 4, right: 4 })
          if (this.block.length === 0) {
            this.partnerSeesCard()
          }
          this.codeCard()
          Button(this.block.length > 0 ? SHARE_DISABLED_LABEL : SHARE_OPEN_CHECK)
            .buttonStyle(ButtonStyleMode.NORMAL)
            .width('100%')
            .constraintSize({ minHeight: 48 })
            .enabled(this.block.length === 0 && this.code !== null)
            .id('fw_visit_open_check')
            .onClick(() => {
              this.nav.pushPathByName(ROUTE_VISIT_CHECK, null);
            })
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
    .title(SHARE_TITLE)
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
