import { claimLine, LedgerEntry, logTimeText, TierClaim, tokenClaim } from 'common';
import { KEY_SHARE_REVISION, ShareService } from '../share/ShareService';
import { LEDGER_EMPTY, LEDGER_NOTE, LEDGER_TITLE, ledgerBytesLine } from '../share/ShareTexts';
import { EmptyState } from '../ui/kit/EmptyState';
import { SYMBOL_INFO } from '../ui/kit/KitTokens';
import { BODY, BODY_SECONDARY, CAPTION, CARD_LARGE } from './Styles';

// "What left this phone" (route ROUTE_LEDGER), opened from the Share tab. Every code the phone has shown,
// newest first, with its exact text, its size and what the claim in it says. The list comes from the
// ledger file the Share service writes before a code is shown (share/ledger.json).
@Component
export struct LedgerPage {
  @StorageProp(KEY_SHARE_REVISION) @Watch('load') shareRevision: number = 0;
  @State entries: LedgerEntry[] = [];

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      ShareService.shared().attach(context.filesDir);
    }
    this.load();
  }

  load(): void {
    this.entries = ShareService.shared().ledgerEntries().reverse();
  }

  private claimText(token: string): string {
    const claim: TierClaim | null = tokenClaim(token);
    return claim === null ? '' : claimLine(claim);
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 14 }) {
          Text(LEDGER_NOTE)
            .attributeModifier(BODY_SECONDARY)
            .padding({ left: 4, right: 4 })
          if (this.entries.length === 0) {
            Column() {
              EmptyState({ symbol: SYMBOL_INFO, sentence: LEDGER_EMPTY, textId: 'fw_ledger_empty' })
            }
            .attributeModifier(CARD_LARGE)
          } else {
            ForEach(this.entries, (e: LedgerEntry) => {
              Column({ space: 6 }) {
                Text(`${logTimeText(e.t)} · ${e.destination}`)
                  .attributeModifier(CAPTION)
                Text(this.claimText(e.payload))
                  .attributeModifier(BODY)
                Text(e.payload)
                  .fontSize($r('sys.float.Body_S'))
                  .fontFamily('monospace')
                  .fontColor($r('sys.color.font_secondary'))
                  .wordBreak(WordBreak.BREAK_ALL)
                  .copyOption(CopyOptions.LocalDevice)
                Text(ledgerBytesLine(e.bytes))
                  .attributeModifier(CAPTION)
              }
              .attributeModifier(CARD_LARGE)
              .alignItems(HorizontalAlign.Start)
            }, (e: LedgerEntry, i: number) => `${e.t}|${i}|${e.payload.length}`)
          }
        }
        .width('100%')
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
    .title(LEDGER_TITLE)
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
