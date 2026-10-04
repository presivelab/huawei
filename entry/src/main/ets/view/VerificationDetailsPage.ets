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
import { str } from '../ui/Strings';
import { SectionCard } from '../ui/kit/SectionCard';
import { KEY_LINK_REVISION, WatchLinkService } from '../watchlink/WatchLinkService';
import { BODY, BODY_SECONDARY, CAPTION } from './Styles';

const INTRO: Resource = $r('app.string.verification_intro');
const NONE: Resource = $r('app.string.verification_none');

interface DetailParams {
  label: ResourceStr;
  value: string;
}

function daysCount(n: number): string {
  return n === 1 ? str($r('app.string.verification_days_one')) : str($r('app.string.verification_days_many'), n);
}

function breakDetail(b: BreakContext): string {
  return str(b.startMin < 0 ? $r('app.string.verification_break_from_day_before') : $r('app.string.verification_break'),
    minuteClock(b.startMin), minuteClock(b.endMin), b.hrSlots24hBefore);
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
        Text(str($r('app.string.verification_packet_head'), day.seq, day.date)).attributeModifier(BODY)
        Text(day.sourceLine).attributeModifier(CAPTION)
        Text(str($r('app.string.verification_packet_clock'), day.clock, day.wearSource)).attributeModifier(CAPTION)
        Text(str($r('app.string.verification_packet_slots'), day.hrSlotCount, day.steps)).attributeModifier(CAPTION)
        Text(str($r('app.string.verification_packet_night'), durationText(day.nightWornMin),
          durationText(day.nightChargingMin)))
          .attributeModifier(CAPTION)
        ForEach(day.breaks, (b: BreakContext) => {
          Text(breakDetail(b)).attributeModifier(CAPTION)
        }, (b: BreakContext) => `${b.startMin}|${b.endMin}`)
      } else {
        Text(str($r('app.string.verification_packet_not_received'), day.seq)).attributeModifier(BODY)
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

          SectionCard({ title: $r('app.string.verification_key_title') }) {
            if (this.state(this.revision).paired) {
              this.detailRow({ label: $r('app.string.verification_key_id'), value: this.state(this.revision).kid })
            } else {
              this.detailRow({
                label: $r('app.string.verification_key_id'),
                value: str($r('app.string.verification_no_watch_paired'))
              })
            }
            if (this.state(this.revision).pendingPairKid.length > 0) {
              this.detailRow({
                label: $r('app.string.verification_pairing_request'),
                value: this.state(this.revision).pendingPairKid
              })
            }
            this.detailRow({
              label: $r('app.string.verification_transport'),
              value: transportLabel(this.state(this.revision).transport)
            })
            if (this.wearEngine(this.revision).length > 0) {
              this.detailRow({ label: $r('app.string.verification_wear_engine'), value: this.wearEngine(this.revision) })
            }
            if (this.lastError(this.revision).length > 0) {
              this.detailRow({ label: $r('app.string.verification_last_error'), value: this.lastError(this.revision) })
            }
          }

          SectionCard({ title: $r('app.string.verification_chain_title') }) {
            this.detailRow({
              label: $r('app.string.verification_last_seq'),
              value: this.state(this.revision).lastSeq > 0
                ? str($r('app.string.verification_seq_number'), this.state(this.revision).lastSeq)
                : str(NONE)
            })
            this.detailRow({
              label: $r('app.string.verification_last_day'),
              value: this.state(this.revision).lastDate.length > 0 ? this.state(this.revision).lastDate : str(NONE)
            })
            this.detailRow({
              label: $r('app.string.verification_state'),
              value: this.state(this.revision).chainLine.length > 0 ? this.state(this.revision).chainLine : str(NONE)
            })
            this.detailRow({
              label: $r('app.string.verification_missing'),
              value: daysCount(this.state(this.revision).missingCount)
            })
          }

          SectionCard({ title: $r('app.string.verification_packets_title') }) {
            if (this.days(this.revision).length === 0) {
              EmptyState({ symbol: $r('sys.symbol.doc_text'), sentence: $r('app.string.verification_no_packets') })
            }
            ForEach(this.days(this.revision), (day: WatchDayFacts) => {
              this.dayPacket(day)
            }, (day: WatchDayFacts) => `${day.seq}|${day.received}|${day.date}`)
          }

          SectionCard({ title: $r('app.string.verification_log_title') }) {
            if (this.state(this.revision).log.length === 0) {
              EmptyState({ symbol: $r('sys.symbol.list_bullet'), sentence: $r('app.string.verification_log_empty') })
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
    .title($r('app.string.verification_title'))
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
