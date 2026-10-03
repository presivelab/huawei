import { BreakContext, PhoneLinkView, SyncLogEntry, WatchDayFacts } from 'common';
import { KEY_LINK_REVISION, WatchLinkService } from '../watchlink/WatchLinkService';
import { BODY, BODY_SECONDARY, CAPTION, CARD, LABEL, TITLE } from './Styles';

const CLOCK_REAL = 'REAL';
const LOG_LINES = 4;

function hoursText(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return `${h} h ${m < 10 ? '0' : ''}${m} min`;
}

function clockText(minuteOfDay: number): string {
  const total = ((minuteOfDay % 1440) + 1440) % 1440;
  const h = Math.floor(total / 60);
  const m = total % 60;
  return `${h < 10 ? '0' : ''}${h}:${m < 10 ? '0' : ''}${m}`;
}

function logText(entry: SyncLogEntry): string {
  const head = entry.seq > 0 ? `#${entry.seq} · ` : '';
  return entry.note.length > 0 ? `${head}${entry.message} · ${entry.note}` : `${head}${entry.message}`;
}

@Component
struct LinkRow {
  @Prop label: string = '';
  @Prop value: string = '';

  build() {
    Row() {
      Text(this.label).attributeModifier(BODY).layoutWeight(1)
      Text(this.value).attributeModifier(BODY_SECONDARY)
    }
    .width('100%')
    .constraintSize({ minHeight: 36 })
  }
}

// Watch link: the paired watch, the state of its chain of signed day packets, and the last sync messages.
@Component
export struct WatchLinkCard {
  @StorageProp(KEY_LINK_REVISION) revision: number = 0;

  // `revision` is a parameter so the card is rebuilt whenever the service state changes.
  private state(revision: number): PhoneLinkView {
    return WatchLinkService.shared().view();
  }

  private recentLog(revision: number): SyncLogEntry[] {
    return WatchLinkService.shared().view().log.slice(0, LOG_LINES);
  }

  private lastDay(view: PhoneLinkView): string {
    return view.lastSeq > 0 ? `${view.lastDate} · #${view.lastSeq}` : 'none yet';
  }

  build() {
    Column({ space: 4 }) {
      Text('Watch link').attributeModifier(TITLE)
      Text(this.state(this.revision).pairLine)
        .attributeModifier(BODY)
        .id('fw_link_pair')

      if (this.state(this.revision).pendingPairKid.length > 0) {
        Column({ space: 8 }) {
          Text(`Pair watch ${this.state(this.revision).pendingPairKid}?`)
            .attributeModifier(TITLE)
            .id('fw_link_pair_prompt')
          Text('Confirm only if the watch shows the same code.').attributeModifier(CAPTION)
          Row({ space: 12 }) {
            Button('Confirm')
              .id('fw_link_confirm')
              .onClick(() => {
                WatchLinkService.shared().confirmPair();
              })
            Button('Not now')
              .buttonStyle(ButtonStyleMode.NORMAL)
              .onClick(() => {
                WatchLinkService.shared().declinePair();
              })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ top: 4, bottom: 4 })
      }

      if (this.state(this.revision).paired) {
        Divider().color($r('sys.color.comp_divider')).margin({ top: 4, bottom: 4 })
        LinkRow({ label: 'Last received day', value: this.lastDay(this.state(this.revision)) })
        if (this.state(this.revision).chainLine.length > 0) {
          LinkRow({ label: 'Chain', value: this.state(this.revision).chainLine })
        }
        LinkRow({ label: 'Transport', value: this.state(this.revision).transport })
      }

      Row({ space: 12 }) {
        Button('Sync now')
          .id('fw_link_sync')
          .onClick(() => {
            WatchLinkService.shared().syncNow();
          })
        if (this.state(this.revision).paired) {
          Button('Forget watch')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .id('fw_link_forget')
            .onClick(() => {
              WatchLinkService.shared().forget();
            })
        }
      }
      .margin({ top: 8 })

      if (this.recentLog(this.revision).length > 0) {
        Text('Last sync').attributeModifier(LABEL).margin({ top: 8 })
        ForEach(this.recentLog(this.revision), (entry: SyncLogEntry) => {
          Text(logText(entry)).attributeModifier(CAPTION)
        }, (entry: SyncLogEntry, index: number) => `${index}|${entry.atMs}|${entry.seq}|${entry.message}`)
      }

      Text('The watch records what its sensors saw and signs one summary per day. This phone checks the ' +
        'signature and the chain, so a day cannot be removed or edited without it showing.')
        .attributeModifier(CAPTION)
        .margin({ top: 8 })
    }
    .attributeModifier(CARD)
  }
}

// Days received from the watch, newest first: what the watch measured, where it came from, nothing judged.
@Component
export struct WatchDaysCard {
  @StorageProp(KEY_LINK_REVISION) revision: number = 0;

  private days(revision: number): WatchDayFacts[] {
    return WatchLinkService.shared().days();
  }

  @Builder
  dayRows(day: WatchDayFacts) {
    Column({ space: 2 }) {
      if (day.received) {
        Text(`${day.date} · #${day.seq}`).attributeModifier(BODY)
        Text(day.sourceLine).attributeModifier(CAPTION)
        Text(`Worn ${hoursText(day.wornMin)} · charging ${hoursText(day.chargingMin)} · off-wrist ` +
          `${hoursText(day.offMin)} · not observed ${hoursText(day.notObservedMin)}`)
          .attributeModifier(CAPTION)
        Text(`Night 00:00–06:00: worn ${hoursText(day.nightWornMin)} · steps ${day.steps}`)
          .attributeModifier(CAPTION)
        ForEach(day.breaks, (b: BreakContext) => {
          Text(`Break ${b.startMin < 0 ? 'from the day before ' : ''}${clockText(b.startMin)}–` +
            `${clockText(b.endMin)} · heart-rate slots in the 24 h before: ${b.hrSlots24hBefore}`)
            .attributeModifier(CAPTION)
        }, (b: BreakContext) => `${b.startMin}|${b.endMin}`)
        if (day.clock !== CLOCK_REAL) {
          Text('Recorded on the watch demo clock: simulated time.')
            .attributeModifier(CAPTION)
            .fontColor($r('sys.color.warning'))
        }
      } else {
        Text(`#${day.seq} · not received`).attributeModifier(BODY)
        Text(day.reason).attributeModifier(CAPTION)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 6, bottom: 6 })
  }

  build() {
    Column({ space: 4 }) {
      Text('Days from the watch').attributeModifier(TITLE)
      if (this.days(this.revision).length === 0) {
        Text('No day received yet.').attributeModifier(BODY_SECONDARY)
      }
      ForEach(this.days(this.revision), (day: WatchDayFacts) => {
        this.dayRows(day)
      }, (day: WatchDayFacts) => `${day.seq}|${day.received}|${day.date}`)
    }
    .attributeModifier(CARD)
  }
}
