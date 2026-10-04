import {
  claimPeriodText,
  claimTierLine,
  FW_TAB_REPORT,
  FW_TAB_SHARE,
  keySourceLabel,
  logTimeText,
  PersonaReport,
  ShareOffer,
  shareOffer,
  tokenLengthLine
} from 'common';
import { ROUTE_PARTNER } from '../addon/AddonTexts';
import { KEY_TAB } from '../nav/EntryRouter';
import { SHARE_NEEDS_SCORE } from '../report/ReportTexts';
import {
  DEFAULT_PERSONA_ID,
  KEY_PERSONA,
  KEY_REPORT_REVISION,
  reportService,
  selectedReport
} from '../report/ServiceLocator';
import { KEY_SHARE_REVISION, ShareCode, ShareService } from '../share/ShareService';
import {
  CODE_USED,
  NEW_CODE_LABEL,
  NO_CODE_SENTENCE,
  NOT_IN_CODE,
  OPEN_PARTNER_LABEL,
  PARTNER_SEES_TITLE,
  PERIOD_PREFIX,
  QR_SPOKEN,
  SHARE_INTRO,
  SHARE_INTRO_NO_SCORE,
  SIGN_FAILED,
  SIGNING,
  TECH_ISSUED,
  TECH_KEY_ID,
  TECH_NONCE,
  TECHNICAL_LABEL,
  TIER_FROM_PREVIEW
} from '../share/ShareTexts';
import { EmptyState } from '../ui/kit/EmptyState';
import { InfoChip } from '../ui/kit/InfoChip';
import {
  COLOR_NOTE_TEXT,
  COLOR_NOTE_TINT,
  COLOR_OK_TEXT,
  SYMBOL_EXPAND,
  SYMBOL_INFO,
  SYMBOL_KEY_HELD,
  SYMBOL_TAB_SHARE
} from '../ui/kit/KitTokens';
import { TierBadge } from '../ui/kit/TierBadge';
import { BODY_SECONDARY, CAPTION, CARD_LARGE, HEADING } from './Styles';

const QR_SIDE: number = 232;

interface TechParams {
  label: string;
  value: string;
}

// The Share tab: what the partner will see, the signed claim as a QR code, and the way to the partner
// view of the demo. The code is made when the tab is on screen, never before, and every code that is
// shown is in the ledger. Without a score there is no code and the button is off.
@Component
export struct ShareView {
  @Consume('fwNav') nav: NavPathStack;
  @StorageProp(KEY_PERSONA) @Watch('reload') personaId: string = DEFAULT_PERSONA_ID;
  @StorageProp(KEY_REPORT_REVISION) @Watch('reload') reportRevision: number = 0;
  @StorageProp(KEY_TAB) @Watch('reload') tab: number = FW_TAB_REPORT;
  @StorageProp(KEY_SHARE_REVISION) @Watch('syncCode') shareRevision: number = 0;
  @State report: PersonaReport = selectedReport();
  @State code: ShareCode | null = null;
  @State failure: string = '';
  @State technical: boolean = false;
  private preview: boolean = reportService().isPreview();

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      ShareService.shared().attach(context.filesDir);
    }
    this.reload();
  }

  reload(): void {
    this.report = reportService().report(this.personaId);
    this.syncCode();
    if (this.tab === FW_TAB_SHARE) {
      this.request(false);
    }
  }

  // Shows the service's code when it belongs to the persona on screen.
  syncCode(): void {
    const have = ShareService.shared().current();
    this.code = have !== null && have.personaId === this.report.id ? have : null;
  }

  private offer(): ShareOffer {
    return shareOffer(this.report);
  }

  private request(fresh: boolean): void {
    if (!this.offer().available) {
      return;
    }
    this.failure = '';
    ShareService.shared().codeFor(this.report, fresh).then((): void => {
      this.syncCode();
    }).catch((e: Error) => {
      this.failure = SIGN_FAILED + e.message;
    });
  }

  @Builder
  techRow(p: TechParams) {
    Row({ space: 12 }) {
      Text(p.label).attributeModifier(CAPTION)
      Text(p.value)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.End)
        .layoutWeight(1)
    }
    .width('100%')
  }

  @Builder
  partnerSeesCard() {
    Column({ space: 10 }) {
      Text(PARTNER_SEES_TITLE).attributeModifier(HEADING)
      Row({ space: 12 }) {
        if (this.offer().available) {
          TierBadge({ tier: this.offer().tier, size: 40 })
        }
        Column({ space: 2 }) {
          Text(claimTierLine(this.offer().tier, this.offer().eligible))
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(600)
            .fontColor($r('sys.color.font_primary'))
            .id('fw_share_tier_line')
          Text(PERIOD_PREFIX + claimPeriodText(this.offer().periodIso)).attributeModifier(CAPTION)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.offer().note.length > 0) {
        Text(this.offer().note)
          .attributeModifier(BODY_SECONDARY)
          .id('fw_share_note')
      }
      if (this.code !== null) {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 4 }) {
            Text(TECHNICAL_LABEL)
              .fontSize($r('sys.float.Body_M'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_emphasize'))
            SymbolGlyph(SYMBOL_EXPAND)
              .fontSize(14)
              .fontColor([$r('sys.color.icon_emphasize')])
              .rotate({ angle: this.technical ? 180 : 0 })
          }
          .alignItems(VerticalAlign.Center)
        }
        .backgroundColor(Color.Transparent)
        .borderRadius($r('sys.float.corner_radius_level4'))
        .constraintSize({ minHeight: 44 })
        .accessibilityText(TECHNICAL_LABEL)
        .id('fw_share_technical')
        .onClick(() => {
          this.technical = !this.technical;
        })

        if (this.technical) {
          Column({ space: 6 }) {
            this.techRow({ label: TECH_KEY_ID, value: this.code.claim.kid })
            this.techRow({ label: TECH_NONCE, value: this.code.claim.nonce })
            this.techRow({ label: TECH_ISSUED, value: logTimeText(this.code.claim.issuedAt) })
          }
          .width('100%')
        }
      }
    }
    .attributeModifier(CARD_LARGE)
  }

  @Builder
  codeCard() {
    Column() {
      Column({ space: 14 }) {
        if (this.code !== null) {
          // A QR code stays dark on white in dark mode too, or a scanner cannot read it.
          QRCode(this.code.token)
            .width(QR_SIDE)
            .height(QR_SIDE)
            .color(Color.Black)
            .backgroundColor(Color.White)
            .contentOpacity(this.code.used ? 0.25 : 1)
            .padding(10)
            .borderRadius(12)
            .accessibilityText(QR_SPOKEN)
            .id('fw_share_qr')
          if (this.code.used) {
            InfoChip({
              text: CODE_USED,
              fill: COLOR_NOTE_TINT,
              textColor: COLOR_NOTE_TEXT,
              strong: true
            })
            Button(NEW_CODE_LABEL)
              .buttonStyle(ButtonStyleMode.NORMAL)
              .id('fw_share_new_code')
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
              .id('fw_share_key')
          }
          .alignItems(VerticalAlign.Center)

          Text(NOT_IN_CODE)
            .attributeModifier(CAPTION)
            .textAlign(TextAlign.Center)
          if (this.preview) {
            InfoChip({ text: TIER_FROM_PREVIEW })
          }
        } else if (!this.offer().available) {
          EmptyState({ symbol: SYMBOL_TAB_SHARE, sentence: NO_CODE_SENTENCE, textId: 'fw_share_no_code' })
        } else if (this.failure.length > 0) {
          EmptyState({ symbol: SYMBOL_INFO, sentence: this.failure })
        } else {
          Row({ space: 12 }) {
            LoadingProgress()
              .width(24)
              .height(24)
              .color($r('sys.color.icon_secondary'))
            Text(SIGNING).attributeModifier(BODY_SECONDARY)
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
    Scroll() {
      Column({ space: 14 }) {
        Text(this.offer().available ? SHARE_INTRO : SHARE_INTRO_NO_SCORE)
          .attributeModifier(BODY_SECONDARY)
          .padding({ left: 4, right: 4 })
        this.partnerSeesCard()
        this.codeCard()
        Button(OPEN_PARTNER_LABEL)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .width('100%')
          .constraintSize({ minHeight: 48 })
          .enabled(this.code !== null)
          .id('fw_share_open_partner')
          .onClick(() => {
            this.nav.pushPathByName(ROUTE_PARTNER, null);
          })
        if (!this.offer().available) {
          Text(SHARE_NEEDS_SCORE)
            .attributeModifier(CAPTION)
            .padding({ left: 4, right: 4 })
            .id('fw_share_needs_score')
        }
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
}
