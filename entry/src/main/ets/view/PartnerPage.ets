import {
  CheckRow,
  checkRows,
  CheckState,
  claimBenefitLabel,
  claimLine,
  keySourceLabel,
  ReportTier,
  tamperedTierToken,
  tamperTargetTier,
  tokenClaim,
  verdictLine,
  VerifyResult
} from 'common';
import { selectedReport } from '../report/ServiceLocator';
import { ShareCode, ShareService } from '../share/ShareService';
import {
  ATTEMPT_AGAIN,
  ATTEMPT_FIRST,
  attemptTampered,
  CHEAT_NEEDS_CODE,
  CHEAT_TITLE,
  CHECK_NOT_RUN,
  CHECKS_TITLE,
  NO_CODE_ON_PHONE,
  NOTHING_CHECKED,
  PARTNER_BAND,
  PARTNER_BAND_NOTE,
  PARTNER_TITLE,
  tamperLabel,
  USE_CODE_LABEL,
  VERIFY_AGAIN_LABEL
} from '../share/ShareTexts';
import { EmptyState } from '../ui/kit/EmptyState';
import { str } from '../ui/Strings';
import {
  COLOR_FLAG_TEXT,
  COLOR_FLAG_TINT,
  COLOR_OK_TEXT,
  SYMBOL_CHECK,
  SYMBOL_CROSS,
  SYMBOL_INFO,
  SYMBOL_NOT_RUN,
  tierTint
} from '../ui/kit/KitTokens';
import { BODY, BODY_SECONDARY, CAPTION, CARD_LARGE, HEADING } from './Styles';

interface VerdictParams {
  text: string;
  ok: boolean;
  lineId: string;
}

// The partner view of the demo (route ROUTE_PARTNER), opened from the Share tab. It plays the other side:
// it takes the code this phone is showing, runs PartnerVerifier on it and shows where the run stopped.
// The two "try to cheat" buttons send the same code a second time and the same code with another tier.
@Component
export struct PartnerPage {
  // The token the partner received; empty until "Use the code from this phone".
  @State held: string = '';
  // The latest verification, whichever button started it.
  @State latest: VerifyResult | null = null;
  @State attempt: string = '';
  @State againLine: string = '';
  @State againOk: boolean = false;
  @State tamperLine: string = '';
  @State tamperOk: boolean = false;
  @State busy: boolean = false;
  @State missing: boolean = false;

  private run(token: string, attempt: string, done: (result: VerifyResult) => void): void {
    if (this.busy) {
      return;
    }
    this.busy = true;
    ShareService.shared().verify(token).then((result: VerifyResult) => {
      this.latest = result;
      this.attempt = attempt;
      this.busy = false;
      done(result);
    }).catch(() => {
      this.busy = false;
    });
  }

  // Takes the code for the persona on screen. A code that was already checked, or whose nonce is about to
  // expire (10 min), is replaced by a new one first, so a rehearsal or a long pause never leaves the partner
  // holding a dead code. The Share tab shows the same new code (KEY_SHARE_REVISION).
  private useCode(): void {
    if (this.busy) {
      return;
    }
    const have: ShareCode | null = ShareService.shared().current();
    this.busy = true;
    ShareService.shared().codeFor(selectedReport(), have !== null && have.used).then((code: ShareCode | null) => {
      this.busy = false;
      if (code === null) {
        this.missing = true;
        return;
      }
      this.missing = false;
      this.held = code.token;
      this.againLine = '';
      this.tamperLine = '';
      this.run(code.token, str(ATTEMPT_FIRST), (): void => {
      });
    }).catch(() => {
      this.busy = false;
      this.missing = true;
    });
  }

  private verifyAgain(): void {
    this.run(this.held, str(ATTEMPT_AGAIN), (result: VerifyResult): void => {
      this.againLine = verdictLine(result);
      this.againOk = result.ok;
    });
  }

  // The tier the forged code claims: read from the held code, which the cheater can read too.
  private forgedTier(): string {
    const claim = tokenClaim(this.held);
    return tamperTargetTier(claim === null ? '' : claim.tier);
  }

  private verifyTampered(): void {
    const forged = tamperedTierToken(this.held);
    if (forged === null) {
      return;
    }
    this.run(forged, attemptTampered(this.forgedTier()), (result: VerifyResult): void => {
      this.tamperLine = verdictLine(result);
      this.tamperOk = result.ok;
    });
  }

  @Builder
  band() {
    Column({ space: 4 }) {
      Text(PARTNER_BAND)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_on_primary'))
        .id('fw_partner_band')
      Text(PARTNER_BAND_NOTE)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_on_primary'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: 20,
      right: 20,
      top: 12,
      bottom: 12
    })
    .backgroundColor($r('sys.color.comp_background_emphasize'))
    .borderRadius(24)
  }

  @Builder
  statusCard() {
    Column() {
      if (this.latest === null) {
        EmptyState({ symbol: SYMBOL_INFO, sentence: this.missing ? NO_CODE_ON_PHONE : NOTHING_CHECKED })
      } else {
        Column({ space: 8 }) {
          SymbolGlyph(this.latest.ok ? SYMBOL_CHECK : SYMBOL_CROSS)
            .fontSize(36)
            .fontColor([this.latest.ok ? COLOR_OK_TEXT : COLOR_FLAG_TEXT])
            .width(72)
            .height(72)
            .backgroundColor(this.latest.ok ? tierTint(ReportTier.A) : COLOR_FLAG_TINT)
            .borderRadius(36)
          Text(this.latest.status)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .id('fw_partner_status')
          Text(this.attempt)
            .attributeModifier(CAPTION)
            .id('fw_partner_attempt')
          if (this.latest.claim !== null) {
            Text(claimLine(this.latest.claim))
              .attributeModifier(BODY)
              .textAlign(TextAlign.Center)
              .id('fw_partner_claim')
          }
          if (this.latest.ok && this.latest.claim !== null) {
            Text(this.latest.claim.eligible ? claimBenefitLabel(this.latest.claim) :
              str($r('app.string.partner_page_benefit_no_reason'), claimBenefitLabel(this.latest.claim)))
              .attributeModifier(BODY_SECONDARY)
              .textAlign(TextAlign.Center)
              .id('fw_partner_benefit')
          }
          if (this.latest.keySource.length > 0) {
            Text(str($r('app.string.partner_page_key_registry'), keySourceLabel(this.latest.keySource)))
              .attributeModifier(CAPTION)
              .textAlign(TextAlign.Center)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
    }
    .attributeModifier(CARD_LARGE)
  }

  @Builder
  checkRow(row: CheckRow) {
    Row({ space: 10 }) {
      SymbolGlyph(row.state === CheckState.PASSED ? SYMBOL_CHECK :
        (row.state === CheckState.FAILED ? SYMBOL_CROSS : SYMBOL_NOT_RUN))
        .fontSize(18)
        .fontColor([row.state === CheckState.PASSED ? COLOR_OK_TEXT :
          (row.state === CheckState.FAILED ? COLOR_FLAG_TEXT : $r('sys.color.icon_tertiary'))])
      Text(row.label)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(row.state === CheckState.FAILED ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(row.state === CheckState.NOT_RUN ? $r('sys.color.font_tertiary') : $r('sys.color.font_primary'))
        .layoutWeight(1)
      if (row.state === CheckState.NOT_RUN) {
        Text(CHECK_NOT_RUN).attributeModifier(CAPTION)
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 28 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  checksCard() {
    Column({ space: 6 }) {
      Text(CHECKS_TITLE).attributeModifier(HEADING)
      if (this.latest !== null) {
        ForEach(checkRows(this.latest), (row: CheckRow) => {
          this.checkRow(row)
        }, (row: CheckRow, index: number) => `${index}|${row.state}`)
      }
    }
    .attributeModifier(CARD_LARGE)
  }

  @Builder
  verdict(p: VerdictParams) {
    Row({ space: 8 }) {
      SymbolGlyph(p.ok ? SYMBOL_CHECK : SYMBOL_CROSS)
        .fontSize(16)
        .fontColor([p.ok ? COLOR_OK_TEXT : COLOR_FLAG_TEXT])
      Text(p.text)
        .fontSize($r('sys.float.Body_M'))
        .fontColor(p.ok ? COLOR_OK_TEXT : COLOR_FLAG_TEXT)
        .layoutWeight(1)
        .id(p.lineId)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  cheatCard() {
    Column({ space: 10 }) {
      Text(CHEAT_TITLE).attributeModifier(HEADING)
      if (this.held.length === 0) {
        Text(CHEAT_NEEDS_CODE).attributeModifier(CAPTION)
      }
      Button(VERIFY_AGAIN_LABEL)
        .buttonStyle(ButtonStyleMode.NORMAL)
        .width('100%')
        .constraintSize({ minHeight: 48 })
        .enabled(this.held.length > 0 && !this.busy)
        .id('fw_partner_again')
        .onClick(() => {
          this.verifyAgain();
        })
      if (this.againLine.length > 0) {
        this.verdict({ text: this.againLine, ok: this.againOk, lineId: 'fw_partner_again_line' })
      }
      Button(tamperLabel(this.forgedTier()))
        .buttonStyle(ButtonStyleMode.NORMAL)
        .width('100%')
        .constraintSize({ minHeight: 48 })
        .enabled(this.held.length > 0 && !this.busy)
        .id('fw_partner_tamper')
        .onClick(() => {
          this.verifyTampered();
        })
      if (this.tamperLine.length > 0) {
        this.verdict({ text: this.tamperLine, ok: this.tamperOk, lineId: 'fw_partner_tamper_line' })
      }
    }
    .attributeModifier(CARD_LARGE)
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 14 }) {
          this.band()
          Button(USE_CODE_LABEL)
            .buttonStyle(ButtonStyleMode.EMPHASIZED)
            .width('100%')
            .constraintSize({ minHeight: 52 })
            .enabled(!this.busy)
            .id('fw_partner_use')
            .onClick(() => {
              this.useCode();
            })
          this.statusCard()
          if (this.latest !== null) {
            this.checksCard()
          }
          this.cheatCard()
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
    .title(PARTNER_TITLE)
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
