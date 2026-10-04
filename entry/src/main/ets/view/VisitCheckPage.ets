import {
  CheckRow,
  CheckState,
  keySourceLabel,
  tamperedVisitDateToken,
  visitCheckRows,
  visitClaimLine,
  visitVerdictLine,
  VisitVerifyResult
} from 'common';
import { EmptyState } from '../ui/kit/EmptyState';
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
import { VisitCode, VisitService } from '../visits/VisitService';
import {
  ATTEMPT_AGAIN,
  ATTEMPT_DATE,
  ATTEMPT_FIRST,
  ATTEMPT_NEW,
  CHEAT_NEEDS_CODE,
  CHEAT_TITLE,
  CHECK_AGAIN,
  CHECK_BAND,
  CHECK_BAND_NOTE,
  CHECK_CHANGE_DATE,
  CHECK_NEW_FROM_RECEIPT,
  CHECK_NO_CODE,
  CHECK_NOT_RUN,
  CHECK_NOTHING,
  CHECK_TITLE,
  CHECK_USE_CODE,
  CHECKS_TITLE,
  KEY_PREFIX,
  KEY_VISIT_SELECTED,
  REGISTRY_SUFFIX
} from '../visits/VisitTexts';
import { BODY, CAPTION, CARD_LARGE, HEADING } from './Styles';

const TIER_A: string = 'A';

interface VerdictParams {
  text: string;
  ok: boolean;
  lineId: string;
}

// "Partner check · visit" (route ROUTE_VISIT_CHECK). It plays the other side for a visit code: it takes
// the code this phone is showing, runs VisitVerifier on it and shows, check by check, where the run
// stopped. Three ways to cheat: the same code again, the same code with another visit date, and a new
// code made from a receipt the partner already accepted.
@Component
export struct VisitCheckPage {
  @StorageProp(KEY_VISIT_SELECTED) visitId: string = '';
  @State held: string = '';
  @State latest: VisitVerifyResult | null = null;
  @State attempt: string = '';
  @State againLine: string = '';
  @State againOk: boolean = false;
  @State dateLine: string = '';
  @State dateOk: boolean = false;
  @State newLine: string = '';
  @State newOk: boolean = false;
  @State busy: boolean = false;
  @State missing: boolean = false;

  private run(token: string, attempt: string, done: (result: VisitVerifyResult) => void): void {
    if (this.busy) {
      return;
    }
    this.busy = true;
    VisitService.shared().verifyVisitClaim(token).then((result: VisitVerifyResult) => {
      this.latest = result;
      this.attempt = attempt;
      this.busy = false;
      done(result);
    }).catch(() => {
      this.busy = false;
    });
  }

  // Takes the code of the visit on screen. A code that was already checked is replaced by a new one
  // first, so the partner never starts with a dead code.
  private useCode(): void {
    if (this.busy) {
      return;
    }
    const have: VisitCode | null = VisitService.shared().current();
    this.busy = true;
    VisitService.shared().codeFor(this.visitId, have !== null && have.used).then((code: VisitCode) => {
      this.busy = false;
      this.missing = false;
      this.held = code.token;
      this.againLine = '';
      this.dateLine = '';
      this.newLine = '';
      this.run(code.token, ATTEMPT_FIRST, (): void => {
      });
    }).catch(() => {
      this.busy = false;
      this.missing = true;
    });
  }

  private verifyAgain(): void {
    this.run(this.held, ATTEMPT_AGAIN, (result: VisitVerifyResult): void => {
      this.againLine = visitVerdictLine(result);
      this.againOk = result.ok;
    });
  }

  private verifyChangedDate(): void {
    const forged = tamperedVisitDateToken(this.held);
    if (forged === null) {
      return;
    }
    this.run(forged, ATTEMPT_DATE, (result: VisitVerifyResult): void => {
      this.dateLine = visitVerdictLine(result);
      this.dateOk = result.ok;
    });
  }

  // A fresh, correctly signed code from the same receipt: new nonce, good signature, and still refused.
  private verifyNewFromReceipt(): void {
    if (this.busy) {
      return;
    }
    this.busy = true;
    VisitService.shared().codeFor(this.visitId, true).then((code: VisitCode) => {
      this.busy = false;
      this.run(code.token, ATTEMPT_NEW, (result: VisitVerifyResult): void => {
        this.newLine = visitVerdictLine(result);
        this.newOk = result.ok;
        if (result.ok) {
          this.held = code.token;
        }
      });
    }).catch(() => {
      this.busy = false;
    });
  }

  @Builder
  band() {
    Column({ space: 4 }) {
      Text(CHECK_BAND)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_on_primary'))
        .id('fw_visit_check_band')
      Text(CHECK_BAND_NOTE)
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
        EmptyState({ symbol: SYMBOL_INFO, sentence: this.missing ? CHECK_NO_CODE : CHECK_NOTHING })
      } else {
        Column({ space: 8 }) {
          SymbolGlyph(this.latest.ok ? SYMBOL_CHECK : SYMBOL_CROSS)
            .fontSize(36)
            .fontColor([this.latest.ok ? COLOR_OK_TEXT : COLOR_FLAG_TEXT])
            .width(72)
            .height(72)
            .backgroundColor(this.latest.ok ? tierTint(TIER_A) : COLOR_FLAG_TINT)
            .borderRadius(36)
          Text(this.latest.status)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .id('fw_visit_check_status')
          Text(this.attempt)
            .attributeModifier(CAPTION)
            .id('fw_visit_check_attempt')
          if (this.latest.claim !== null) {
            Text(visitClaimLine(this.latest.claim))
              .attributeModifier(BODY)
              .textAlign(TextAlign.Center)
              .id('fw_visit_check_claim')
          }
          if (this.latest.keySource.length > 0) {
            Text(KEY_PREFIX + keySourceLabel(this.latest.keySource) + REGISTRY_SUFFIX)
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
        ForEach(visitCheckRows(this.latest), (row: CheckRow) => {
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
      Button(CHECK_CHANGE_DATE)
        .buttonStyle(ButtonStyleMode.NORMAL)
        .width('100%')
        .constraintSize({ minHeight: 48 })
        .enabled(this.held.length > 0 && !this.busy)
        .id('fw_visit_check_date')
        .onClick(() => {
          this.verifyChangedDate();
        })
      if (this.dateLine.length > 0) {
        this.verdict({ text: this.dateLine, ok: this.dateOk, lineId: 'fw_visit_check_date_line' })
      }
      Button(CHECK_AGAIN)
        .buttonStyle(ButtonStyleMode.NORMAL)
        .width('100%')
        .constraintSize({ minHeight: 48 })
        .enabled(this.held.length > 0 && !this.busy)
        .id('fw_visit_check_again')
        .onClick(() => {
          this.verifyAgain();
        })
      if (this.againLine.length > 0) {
        this.verdict({ text: this.againLine, ok: this.againOk, lineId: 'fw_visit_check_again_line' })
      }
      Button(CHECK_NEW_FROM_RECEIPT)
        .buttonStyle(ButtonStyleMode.NORMAL)
        .width('100%')
        .constraintSize({ minHeight: 48 })
        .enabled(this.held.length > 0 && !this.busy)
        .id('fw_visit_check_new')
        .onClick(() => {
          this.verifyNewFromReceipt();
        })
      if (this.newLine.length > 0) {
        this.verdict({ text: this.newLine, ok: this.newOk, lineId: 'fw_visit_check_new_line' })
      }
    }
    .attributeModifier(CARD_LARGE)
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 14 }) {
          this.band()
          Button(CHECK_USE_CODE)
            .buttonStyle(ButtonStyleMode.EMPHASIZED)
            .width('100%')
            .constraintSize({ minHeight: 52 })
            .enabled(!this.busy)
            .id('fw_visit_check_use')
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
    .title(CHECK_TITLE)
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
