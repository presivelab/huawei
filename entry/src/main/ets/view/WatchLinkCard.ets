import {
  BreakContext,
  breakText,
  DAY_NOT_RECEIVED,
  dayOfMonth,
  dayTitle,
  demoDayLabel,
  durationParts,
  durationText,
  isVerifiedDay,
  lastSyncText,
  listedWearParts,
  missingSummary,
  NOT_SYNCED,
  observedMinutes,
  PhoneLinkView,
  stripDays,
  verifiedDayCount,
  verifiedSummary,
  WatchDayFacts,
  WearPart,
  weekdayShort
} from 'common';
import { DayStrip, DayStripItem } from '../ui/kit/DayStrip';
import { EmptyState } from '../ui/kit/EmptyState';
import { SYMBOL_STEPS, SYMBOL_VERIFIED, SYMBOL_WATCH, wearColor } from '../ui/kit/KitTokens';
import { RingStat } from '../ui/kit/RingStat';
import { SectionCard } from '../ui/kit/SectionCard';
import { StatusPill } from '../ui/kit/StatusPill';
import { ValueUnit, ValueWithUnit } from '../ui/kit/ValueWithUnit';
import { WearBar, WearLegend } from '../ui/kit/WearBar';
import { ROUTE_TOUR, TOUR_LABEL } from '../addon/AddonTexts';
import { KEY_LINK_REVISION, WatchLinkService } from '../watchlink/WatchLinkService';
import { CAPTION } from './Styles';

const LINKED: string = 'Linked';
const NOT_LINKED: string = 'Not linked';
const PAIR_WAITING: string = 'Waiting for you';
const VERIFIED: string = 'Verified';
const MISSING: string = 'Missing';
const NOT_LINKED_SENTENCE: string = 'No watch linked. On the watch, open FairWear and choose Pair phone.';
const LINKED_NO_DAYS_SENTENCE: string = 'Watch linked. Its first day appears after the watch closes it and syncs.';
const NO_DAYS_SENTENCE: string = 'No day received yet.';
const LINK_EXPLAINED: string =
  'The watch signs one summary per day. This phone checks every signature, so a day cannot be edited or ' +
    'removed without it showing.';
const NOTHING_OBSERVED: string = 'The watch recorded nothing on this day.';
const MISSING_EXPLAINED: string =
  'The watch closed this day, but it never reached this phone. It is shown as missing, not as zero.';

// A duration as the value-and-unit pairs the kit draws: "19 h 20 min", "24 h", "35 min".
function durationValue(minutes: number): ValueUnit {
  const d = durationParts(minutes);
  if (d.hours.length > 0) {
    return { value: d.hours, unit: 'h', extraValue: d.minutes, extraUnit: d.minutes.length > 0 ? 'min' : '' };
  }
  return { value: d.minutes, unit: 'min' };
}

// 12480 -> "12,480".
function grouped(n: number): string {
  let text = `${Math.floor(n)}`;
  let out = '';
  while (text.length > 3) {
    out = `,${text.substring(text.length - 3)}${out}`;
    text = text.substring(0, text.length - 3);
  }
  return text + out;
}

function spokenDay(day: WatchDayFacts): string {
  const parts = listedWearParts(day);
  const words: string[] = [];
  for (let i = 0; i < parts.length; i++) {
    words.push(`${parts[i].label} ${durationText(parts[i].minutes)}`);
  }
  return `${dayTitle(day.date)}: ${words.join(', ')}`;
}

function stripItems(daysNewestFirst: WatchDayFacts[]): DayStripItem[] {
  const days = stripDays(daysNewestFirst);
  const out: DayStripItem[] = [];
  for (let i = 0; i < days.length; i++) {
    const day = days[i];
    const item = new DayStripItem();
    item.key = `${day.seq}|${day.received}`;
    if (day.received) {
      item.top = weekdayShort(day.date);
      item.bottom = dayOfMonth(day.date);
      item.spoken = spokenDay(day);
      item.worn = day.wornMin;
      item.charging = day.chargingMin;
      item.off = day.offMin;
      item.unobserved = day.notObservedMin;
    } else {
      item.missing = true;
      item.top = MISSING;
      item.spoken = DAY_NOT_RECEIVED;
    }
    out.push(item);
  }
  return out;
}

// Watch link: is a watch linked, when did it last sync, and how many of its days were verified.
// Keys, sequence numbers, the chain and the sync log are on "Verification details".
@Component
export struct WatchLinkCard {
  @Consume('fwNav') nav: NavPathStack;
  @StorageProp(KEY_LINK_REVISION) revision: number = 0;
  private daysRevision: number = -1;
  private daysCache: WatchDayFacts[] = [];

  // `revision` is a parameter so the card is rebuilt whenever the service state changes.
  private state(revision: number): PhoneLinkView {
    return WatchLinkService.shared().view();
  }

  // The days are read from files, so one read serves a whole build.
  private days(revision: number): WatchDayFacts[] {
    if (this.daysRevision !== revision) {
      this.daysCache = WatchLinkService.shared().days();
      this.daysRevision = revision;
    }
    return this.daysCache;
  }

  private verified(revision: number): number {
    return verifiedDayCount(this.days(revision));
  }

  private pillText(view: PhoneLinkView): string {
    if (view.paired) {
      return LINKED;
    }
    return view.pendingPairKid.length > 0 ? PAIR_WAITING : NOT_LINKED;
  }

  private pillColor(view: PhoneLinkView): Resource {
    if (view.paired) {
      return $r('sys.color.confirm');
    }
    return view.pendingPairKid.length > 0 ? $r('sys.color.brand') : $r('sys.color.font_tertiary');
  }

  private syncLine(view: PhoneLinkView): string {
    const text = lastSyncText(view.log, Date.now());
    return text === NOT_SYNCED ? text : `Last synced: ${text}`;
  }

  build() {
    SectionCard({
      title: 'Watch link',
      status: this.pillText(this.state(this.revision)),
      statusColor: this.pillColor(this.state(this.revision)),
      statusId: 'fw_link_pair'
    }) {
      if (this.state(this.revision).pendingPairKid.length > 0) {
        Column({ space: 8 }) {
          Text(`Pair watch ${this.state(this.revision).pendingPairKid}?`)
            .fontSize($r('sys.float.Subtitle_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .id('fw_link_pair_prompt')
          Text('Confirm only if the watch shows the same code.').attributeModifier(CAPTION)
          Row({ space: 12 }) {
            Button('Confirm')
              .layoutWeight(1)
              .id('fw_link_confirm')
              .onClick(() => {
                WatchLinkService.shared().confirmPair();
              })
            Button('Not now')
              .buttonStyle(ButtonStyleMode.NORMAL)
              .layoutWeight(1)
              .onClick(() => {
                WatchLinkService.shared().declinePair();
              })
          }
          .width('100%')
          .margin({ top: 4 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(12)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius($r('sys.float.corner_radius_level6'))
      }

      if (!this.state(this.revision).paired) {
        if (this.state(this.revision).pendingPairKid.length === 0) {
          EmptyState({ symbol: SYMBOL_WATCH, sentence: NOT_LINKED_SENTENCE })
        }
      } else if (this.days(this.revision).length === 0) {
        EmptyState({ symbol: SYMBOL_WATCH, sentence: LINKED_NO_DAYS_SENTENCE })
      } else {
        Row({ space: 16 }) {
          RingStat({
            value: this.verified(this.revision),
            total: this.days(this.revision).length,
            valueText: `${this.verified(this.revision)}`,
            unit: this.verified(this.revision) === 1 ? 'day' : 'days'
          })
          Column({ space: 4 }) {
            Text(verifiedSummary(this.verified(this.revision), this.days(this.revision).length))
              .fontSize($r('sys.float.Subtitle_M'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
            Text(this.syncLine(this.state(this.revision)))
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_secondary'))
            if (this.state(this.revision).missingCount > 0) {
              Text(missingSummary(this.state(this.revision).missingCount))
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.warning'))
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }

      Row({ space: 12 }) {
        Button('Sync now')
          .layoutWeight(1)
          .id('fw_link_sync')
          .onClick(() => {
            WatchLinkService.shared().syncNow();
          })
        if (this.state(this.revision).paired) {
          Button('Forget watch')
            .buttonStyle(ButtonStyleMode.NORMAL)
            .layoutWeight(1)
            .id('fw_link_forget')
            .onClick(() => {
              WatchLinkService.shared().forget();
            })
        }
      }
      .width('100%')

      Text(LINK_EXPLAINED).attributeModifier(CAPTION)

      Button(TOUR_LABEL)
        .buttonStyle(ButtonStyleMode.TEXTUAL)
        .id('fw_link_tour')
        .onClick(() => {
          this.nav.pushPathByName(ROUTE_TOUR, null);
        })
    }
  }
}

// Days received from the watch: a strip of the last seven, then one row per day, newest first, with the
// day as a bar and the hours in each state. What the watch measured; nothing is judged here.
@Component
export struct WatchDaysCard {
  @StorageProp(KEY_LINK_REVISION) revision: number = 0;
  private daysRevision: number = -1;
  private daysCache: WatchDayFacts[] = [];

  private days(revision: number): WatchDayFacts[] {
    if (this.daysRevision !== revision) {
      this.daysCache = WatchLinkService.shared().days();
      this.daysRevision = revision;
    }
    return this.daysCache;
  }

  @Builder
  partItem(part: WearPart) {
    Row({ space: 4 }) {
      Circle()
        .width(8)
        .height(8)
        .fill(wearColor(part.state))
      Text(part.label)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
      ValueWithUnit(durationValue(part.minutes))
    }
    .alignItems(VerticalAlign.Center)
    .margin({ right: 16, bottom: 4 })
  }

  @Builder
  dayRow(day: WatchDayFacts) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(day.received ? dayTitle(day.date) : DAY_NOT_RECEIVED)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
        if (isVerifiedDay(day)) {
          StatusPill({ text: VERIFIED, dot: $r('sys.color.confirm'), symbol: SYMBOL_VERIFIED, compact: true })
        } else {
          StatusPill({ text: MISSING, dot: $r('sys.color.warning'), compact: true })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (day.received) {
        WearBar({
          worn: day.wornMin,
          charging: day.chargingMin,
          off: day.offMin,
          unobserved: day.notObservedMin
        })
        Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
          ForEach(listedWearParts(day), (part: WearPart) => {
            this.partItem(part)
          }, (part: WearPart) => part.state)
          if (day.steps > 0) {
            Row({ space: 4 }) {
              SymbolGlyph(SYMBOL_STEPS)
                .fontSize(14)
                .fontColor([$r('sys.color.icon_secondary')])
              ValueWithUnit({ value: grouped(day.steps), unit: 'steps' })
            }
            .alignItems(VerticalAlign.Center)
            .margin({ right: 16, bottom: 4 })
          }
        }
        .width('100%')

        ForEach(day.breaks, (b: BreakContext) => {
          Text(breakText(b)).attributeModifier(CAPTION)
        }, (b: BreakContext) => `${b.startMin}|${b.endMin}`)
        if (observedMinutes(day) === 0) {
          Text(NOTHING_OBSERVED).attributeModifier(CAPTION)
        }
        if (demoDayLabel(day).length > 0) {
          Row({ space: 4 }) {
            Circle()
              .width(6)
              .height(6)
              .fill($r('sys.color.brand'))
            Text(demoDayLabel(day)).attributeModifier(CAPTION)
          }
          .alignItems(VerticalAlign.Center)
        }
      } else {
        Text(MISSING_EXPLAINED).attributeModifier(CAPTION)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    SectionCard({ title: 'Days from the watch' }) {
      if (this.days(this.revision).length === 0) {
        EmptyState({ symbol: $r('sys.symbol.calendar'), sentence: NO_DAYS_SENTENCE })
      } else {
        DayStrip({ items: stripItems(this.days(this.revision)) })
        WearLegend()
        ForEach(this.days(this.revision), (day: WatchDayFacts) => {
          Column({ space: 12 }) {
            Divider().color($r('sys.color.comp_divider'))
            this.dayRow(day)
          }
          .width('100%')
        }, (day: WatchDayFacts) => `${day.seq}|${day.received}|${day.date}`)
      }
    }
  }
}
