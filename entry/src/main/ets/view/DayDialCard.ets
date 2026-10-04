import {
  DayDial,
  dayDial,
  dayTitle,
  DIAL_CHARGING,
  DIAL_DEMO_NOTE,
  DIAL_NOW_NOTE,
  DIAL_OFF,
  DIAL_SLEEP,
  DIAL_TICK_LABELS,
  DIAL_TITLE,
  DIAL_WORN,
  DialArc,
  dialKindLabel,
  DialSegment,
  dialSegmentsOfRuns,
  engineSession,
  HesDay,
  slotRuns
} from 'common';
import { DEFAULT_PERSONA_ID } from '../report/ServiceLocator';
import { InfoChip } from '../ui/kit/InfoChip';
import { COLOR_CHARGING, COLOR_NOTE_TEXT, COLOR_NOTE_TINT, COLOR_OFF, COLOR_SLEEP, COLOR_WORN } from '../ui/kit/KitTokens';
import { KEY_LINK_REVISION, WatchLinkService } from '../watchlink/WatchLinkService';
import { CAPTION, CARD_LARGE, HEADING } from './Styles';

const DIAL_SIZE: number = 196;          // outer diameter of the wear ring
const RING_STROKE: number = 12;
const RING_GAP: number = 6;
const TICK_STROKE: number = 6;
const NOW_DOT: number = 12;
const HOURS_ON_DIAL: number = 4;        // labelled ticks: 00, 06, 12, 18
const TICK_LENGTH: number = 2;
const MINUTE_MS: number = 60000;
// A Circle is stroked from its rightmost point, clockwise; the dial starts at the top.
const START_AT_TOP: number = -90;

function dialColor(kind: string): Resource {
  if (kind === DIAL_SLEEP) {
    return COLOR_SLEEP;
  }
  if (kind === DIAL_WORN) {
    return COLOR_WORN;
  }
  return kind === DIAL_CHARGING ? COLOR_CHARGING : COLOR_OFF;
}

function localMinuteNow(): number {
  const d = new Date();
  return d.getHours() * 60 + d.getMinutes();
}

function newestDay(personaId: string): HesDay | null {
  const days: HesDay[] = engineSession(personaId).history();
  return days.length === 0 ? null : days[days.length - 1];
}

// The 24-hour dial of the Report tab: the newest completed day of the persona's history (sleep as an arc,
// the day's steps in the middle), the wear segments of the newest day the watch sent, when the phone has
// one, and a marker at the time now. A picture of facts already held; nothing here reaches the score.
@Component
export struct DayDialCard {
  @Prop @Watch('reload') personaId: string = DEFAULT_PERSONA_ID;
  @StorageProp(KEY_LINK_REVISION) @Watch('reload') linkRevision: number = 0;
  @State dial: DayDial = new DayDial();
  @State dayDate: string = '';
  @State watchDate: string = '';
  private timer: number = -1;

  aboutToAppear(): void {
    this.reload();
    this.timer = setInterval(() => {
      this.reload();
    }, MINUTE_MS);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  reload(): void {
    const day = newestDay(this.personaId);
    const received = WatchLinkService.shared().latestReceived();
    const segments: DialSegment[] = received === null ? [] : dialSegmentsOfRuns(slotRuns(received.slots));
    this.dayDate = day === null ? '' : day.date;
    this.watchDate = received === null || segments.length === 0 ? '' : received.date;
    this.dial = dayDial(day, segments, localMinuteNow());
  }

  // The radius of the centre line of a ring whose outer diameter is `outer`.
  private nowX(): number {
    const r = (DIAL_SIZE - RING_STROKE) / 2;
    return DIAL_SIZE / 2 + r * Math.sin(this.dial.nowDeg * Math.PI / 180) - NOW_DOT / 2;
  }

  private nowY(): number {
    const r = (DIAL_SIZE - RING_STROKE) / 2;
    return DIAL_SIZE / 2 - r * Math.cos(this.dial.nowDeg * Math.PI / 180) - NOW_DOT / 2;
  }

  @Builder
  track(outer: number, stroke: number) {
    Circle()
      .width(outer - stroke)
      .height(outer - stroke)
      .fillOpacity(0)
      .stroke($r('sys.color.comp_background_tertiary'))
      .strokeWidth(stroke)
  }

  // One arc on the ring whose outer diameter is `outer`: a single dash of the arc's length, turned to
  // its start. The gap is longer than the whole circle, so the dash is never repeated.
  @Builder
  arc(a: DialArc, outer: number, stroke: number) {
    Circle()
      .width(outer - stroke)
      .height(outer - stroke)
      .fillOpacity(0)
      .stroke(dialColor(a.kind))
      .strokeWidth(stroke)
      .strokeDashArray([Math.PI * (outer - stroke) * Math.min(a.sweepDeg, 360) / 360, Math.PI * outer * 2])
      .rotate({ angle: START_AT_TOP + a.startDeg })
  }

  // Four short ticks at 00, 06, 12 and 18, inside the sleep ring.
  @Builder
  ticks(outer: number) {
    Circle()
      .width(outer - TICK_STROKE)
      .height(outer - TICK_STROKE)
      .fillOpacity(0)
      .stroke($r('sys.color.font_tertiary'))
      .strokeWidth(TICK_STROKE)
      .strokeDashArray([TICK_LENGTH, Math.PI * (outer - TICK_STROKE) / HOURS_ON_DIAL - TICK_LENGTH])
      .rotate({ angle: START_AT_TOP })
  }

  @Builder
  tickLabel(index: number) {
    Text(DIAL_TICK_LABELS[index])
      .fontSize($r('sys.float.Body_S'))
      .fontColor($r('sys.color.font_secondary'))
      .width(24)
      .textAlign(TextAlign.Center)
  }

  @Builder
  face() {
    Stack() {
      this.track(DIAL_SIZE, RING_STROKE)
      ForEach(this.dial.wearArcs, (a: DialArc) => {
        this.arc(a, DIAL_SIZE, RING_STROKE)
      }, (a: DialArc, index: number) => `w|${index}|${a.kind}|${a.startDeg}|${a.sweepDeg}`)

      this.track(DIAL_SIZE - 2 * (RING_STROKE + RING_GAP), RING_STROKE)
      ForEach(this.dial.sleepArcs, (a: DialArc) => {
        this.arc(a, DIAL_SIZE - 2 * (RING_STROKE + RING_GAP), RING_STROKE)
      }, (a: DialArc, index: number) => `s|${index}|${a.startDeg}|${a.sweepDeg}`)

      this.ticks(DIAL_SIZE - 4 * (RING_STROKE + RING_GAP))

      Column({ space: 2 }) {
        Text(this.dial.centerValue)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .id('fw_dial_steps')
        Text(this.dial.centerUnit)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
      }

      Circle()
        .width(NOW_DOT)
        .height(NOW_DOT)
        .fill($r('sys.color.font_primary'))
        .stroke($r('sys.color.comp_background_primary'))
        .strokeWidth(2)
        .position({ x: this.nowX(), y: this.nowY() })
        .id('fw_dial_now')
    }
    .width(DIAL_SIZE)
    .height(DIAL_SIZE)
  }

  @Builder
  legendItem(kind: string) {
    Row({ space: 4 }) {
      Circle()
        .width(8)
        .height(8)
        .fill(dialColor(kind))
      Text(dialKindLabel(kind))
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .alignItems(VerticalAlign.Center)
    .margin({ right: 12 })
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text(DIAL_TITLE)
          .attributeModifier(HEADING)
          .layoutWeight(1)
        if (this.dayDate.length > 0) {
          InfoChip({ text: dayTitle(this.dayDate) })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column({ space: 2 }) {
        this.tickLabel(0)
        Row({ space: 2 }) {
          this.tickLabel(3)
          this.face()
          this.tickLabel(1)
        }
        .alignItems(VerticalAlign.Center)

        this.tickLabel(2)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .accessibilityGroup(true)
      .accessibilityText(this.dial.spoken)

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.dial.legend, (kind: string) => {
          this.legendItem(kind)
        }, (kind: string) => kind)
        Row({ space: 4 }) {
          Circle()
            .width(8)
            .height(8)
            .fill($r('sys.color.font_primary'))
          Text('Now')
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')

      Column({ space: 4 }) {
        Text(this.dial.sleepNote)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_primary'))
          .id('fw_dial_sleep')
        Text(this.dial.wearNote.length > 0 ? this.dial.wearNote : `Wear from the watch day ${dayTitle(this.watchDate)}`)
          .attributeModifier(CAPTION)
          .id('fw_dial_wear')
        Text(DIAL_NOW_NOTE)
          .attributeModifier(CAPTION)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      InfoChip({ text: DIAL_DEMO_NOTE, fill: COLOR_NOTE_TINT, textColor: COLOR_NOTE_TEXT })
    }
    .attributeModifier(CARD_LARGE)
  }
}
