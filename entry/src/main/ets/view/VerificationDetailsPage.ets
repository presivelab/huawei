import {
  BreakContext,
  durationText,
  logLineText,
  logTimeText,
  minuteClock,
  PhoneLinkView,
  SyncLogEntry,
  transportLabel,
  WatchDayFacts
} from 'common';
import { EmptyState } from '../ui/kit/EmptyState';
import { SectionCard } from '../ui/kit/SectionCard';
import { KEY_LINK_REVISION, WatchLinkService } from '../watchlink/WatchLinkService';
import { BODY, BODY_SECONDARY, CAPTION } from './Styles';

const INTRO: string =
  'The technical data behind the Watch link cards: the watch key, sequence numbers, the chain of signed ' +
    'days and the sync log.';
const NONE: string = 'None yet';

interface DetailParams {
  label: string;
  value: string;
}

function daysCount(n: number): string {
  return n === 1 ? '1 day' : `${n} days`;
}

function breakDetail(b: BreakContext): string {
  return `Break ${b.startMin < 0 ? 'from the day before ' : ''}${minuteClock(b.startMin)}–` +
    `${minuteClock(b.endMin)} · heart-rate slots in the 24 h before: ${b.hrSlots24hBefore}`;
}

// "Verification details": the only screen that shows key ids, sequence numbers, the chain, raw dates,
// clock labels, the sync log and the transport.
@Component
export struct VerificationDetailsPage {
  @StorageProp(KEY_LINK_REVISION) revision: number = 0;
  private daysRevision: number = -1;
  private daysCache: WatchDayFacts[] = [];

  // `revision` is a parameter so the page is rebuilt whenever the service state changes.
  private state(revision: number): PhoneLinkView {
    return WatchLinkService.shared().view();
  }

  private days(revision: number): WatchDayFacts[] {
    if (this.daysRevision !== revision) {
      this.daysCache = WatchLinkService.shared().days();
      this.daysRevision = revision;
    }
    return this.daysCache;
  }

  private wearEngine(revision: number): string {
    return WatchLinkService.shared().wearEngineStatus();
  }

  private lastError(revision: number): string {
    return WatchLinkService.shared().lastError;
  }

  @Builder
  detailRow(p: DetailParams) {
    Row({ space: 12 }) {
      Text(p.label).attributeModifier(BODY)
      Text(p.value)
        .attributeModifier(BODY_SECONDARY)
        .textAlign(TextAlign.End)
        .layoutWeight(1)
    }
    .width('100%')
    .constraintSize({ minHeight: 32 })
  }

  @Builder
  dayPacket(day: WatchDayFacts) {
    Column({ space: 4 }) {
      if (day.received) {
        Text(`#${day.seq} · ${day.date}`).attributeModifier(BODY)
        Text(day.sourceLine).attributeModifier(CAPTION)
        Text(`Clock ${day.clock} · wear source ${day.wearSource}`).attributeModifier(CAPTION)
        Text(`Heart-rate slots: ${day.hrSlotCount} · steps: ${day.steps}`).attributeModifier(CAPTION)
        Text(`Night 00:00–06:00: worn ${durationText(day.nightWornMin)} · charging ` +
          `${durationText(day.nightChargingMin)}`)
          .attributeModifier(CAPTION)
        ForEach(day.breaks, (b: BreakContext) => {
          Text(breakDetail(b)).attributeModifier(CAPTION)
        }, (b: BreakContext) => `${b.startMin}|${b.endMin}`)
      } else {
        Text(`#${day.seq} · not received`).attributeModifier(BODY)
        Text(day.reason).attributeModifier(CAPTION)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  logEntry(entry: SyncLogEntry) {
    Column({ space: 4 }) {
      Text(logLineText(entry)).attributeModifier(BODY)
      Text(logTimeText(entry.atMs)).attributeModifier(CAPTION)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          Text(INTRO).attributeModifier(BODY_SECONDARY)

          SectionCard({ title: 'Watch key' }) {
            if (this.state(this.revision).paired) {
              this.detailRow({ label: 'Key ID', value: this.state(this.revision).kid })
            } else {
              this.detailRow({ label: 'Key ID', value: 'No watch paired' })
            }
            if (this.state(this.revision).pendingPairKid.length > 0) {
              this.detailRow({ label: 'Pairing request', value: this.state(this.revision).pendingPairKid })
            }
            this.detailRow({ label: 'Transport', value: transportLabel(this.state(this.revision).transport) })
            if (this.wearEngine(this.revision).length > 0) {
              this.detailRow({ label: 'Wear Engine', value: this.wearEngine(this.revision) })
            }
            if (this.lastError(this.revision).length > 0) {
              this.detailRow({ label: 'Last error', value: this.lastError(this.revision) })
            }
          }

          SectionCard({ title: 'Chain' }) {
            this.detailRow({
              label: 'Last sequence number',
              value: this.state(this.revision).lastSeq > 0 ? `#${this.state(this.revision).lastSeq}` : NONE
            })
            this.detailRow({
              label: 'Last day',
              value: this.state(this.revision).lastDate.length > 0 ? this.state(this.revision).lastDate : NONE
            })
            this.detailRow({
              label: 'State',
              value: this.state(this.revision).chainLine.length > 0 ? this.state(this.revision).chainLine : NONE
            })
            this.detailRow({ label: 'Missing', value: daysCount(this.state(this.revision).missingCount) })
          }

          SectionCard({ title: 'Day packets' }) {
            if (this.days(this.revision).length === 0) {
              EmptyState({ symbol: $r('sys.symbol.doc_text'), sentence: 'No day packet received yet.' })
            }
            ForEach(this.days(this.revision), (day: WatchDayFacts) => {
              this.dayPacket(day)
            }, (day: WatchDayFacts) => `${day.seq}|${day.received}|${day.date}`)
          }

          SectionCard({ title: 'Sync log' }) {
            if (this.state(this.revision).log.length === 0) {
              EmptyState({ symbol: $r('sys.symbol.list_bullet'), sentence: 'Nothing has been synced yet.' })
            }
            ForEach(this.state(this.revision).log, (entry: SyncLogEntry) => {
              this.logEntry(entry)
            }, (entry: SyncLogEntry, index: number) => `${index}|${entry.atMs}|${entry.seq}|${entry.message}`)
          }
        }
        .alignItems(HorizontalAlign.Start)
        .padding({
          left: $r('sys.float.padding_level8'),
          right: $r('sys.float.padding_level8'),
          bottom: $r('sys.float.padding_level12')
        })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .title('Verification details')
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
