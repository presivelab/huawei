/**
 * Health Sim on the watch: the simulated day as a 24-hour ring (midnight at the top) with what it holds.
 * Nothing here is measured. FairWear on this watch asks WatchExportAbility for the same script.
 */
import { BUILT_IN_SCRIPT, FeedStretch, MINUTES_PER_DAY } from '../fw/watchlink/DemoFeed';
import {
  arcsOf,
  DayArc,
  durationText,
  KIND_CHARGING,
  KIND_OFF,
  KIND_WORN,
  minutesOf,
  offWristText
} from '../model/DayScript';

const RING_WIDTH: number = 14;
const RING_MARGIN: number = 6;
const FULL_TURN: number = Math.PI * 2;
const TOP: number = -Math.PI / 2;

@Component
struct LegendRow {
  @Prop label: ResourceStr = '';
  @Prop value: string = '';
  dot: ResourceColor = $r('app.color.muted');

  build() {
    Row({ space: 6 }) {
      Circle()
        .width(8)
        .height(8)
        .fill(this.dot)
      Text(this.label)
        .fontSize($r('app.float.label_font_size'))
        .fontColor($r('app.color.muted'))
      Text(this.value)
        .fontSize($r('app.float.label_font_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.ink'))
    }
    .alignItems(VerticalAlign.Center)
  }
}

@Entry
@Component
struct Index {
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ring: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private script: FeedStretch[] = BUILT_IN_SCRIPT;

  private colorOf(kind: string): number {
    const manager = this.getUIContext().getHostContext()?.resourceManager;
    if (manager === undefined) {
      return 0;
    }
    let color: Resource = $r('app.color.ring_track');
    if (kind === KIND_WORN) {
      color = $r('app.color.ring_worn');
    } else if (kind === KIND_CHARGING) {
      color = $r('app.color.ring_charging');
    } else if (kind === KIND_OFF) {
      color = $r('app.color.ring_off');
    }
    try {
      return manager.getColorSync(color.id);
    } catch (e) {
      return 0;
    }
  }

  private drawRing(): void {
    const w = this.ring.width;
    const h = this.ring.height;
    const radius = Math.min(w, h) / 2 - RING_WIDTH / 2 - RING_MARGIN;
    this.ring.clearRect(0, 0, w, h);
    this.ring.lineWidth = RING_WIDTH;
    this.ring.lineCap = 'butt';
    this.ring.beginPath();
    this.ring.arc(w / 2, h / 2, radius, 0, FULL_TURN);
    this.ring.strokeStyle = this.colorOf('');
    this.ring.stroke();
    const arcs: DayArc[] = arcsOf(this.script);
    for (let i = 0; i < arcs.length; i++) {
      const from = TOP + FULL_TURN * arcs[i].fromMin / MINUTES_PER_DAY;
      const to = TOP + FULL_TURN * arcs[i].toMin / MINUTES_PER_DAY;
      this.ring.beginPath();
      this.ring.arc(w / 2, h / 2, radius, from, to);
      this.ring.strokeStyle = this.colorOf(arcs[i].kind);
      this.ring.stroke();
    }
  }

  build() {
    Stack() {
      Canvas(this.ring)
        .width('100%')
        .height('100%')
        .onReady(() => {
          this.drawRing();
        })

      Column({ space: 6 }) {
        Text($r('app.string.sim_banner'))
          .fontSize($r('app.float.banner_font_size'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.banner_text'))
          .backgroundColor($r('app.color.banner_bg'))
          .borderRadius(10)
          .padding({ left: 10, right: 10, top: 3, bottom: 3 })
        Text($r('app.string.app_title'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ink'))
        Text($r('app.string.day_title'))
          .fontSize($r('app.float.note_font_size'))
          .fontColor($r('app.color.muted'))

        Column({ space: 3 }) {
          LegendRow({
            label: $r('app.string.worn'),
            value: durationText(minutesOf(this.script, KIND_WORN)),
            dot: $r('app.color.ring_worn')
          })
          LegendRow({
            label: $r('app.string.charging'),
            value: durationText(minutesOf(this.script, KIND_CHARGING)),
            dot: $r('app.color.ring_charging')
          })
          LegendRow({
            label: $r('app.string.off_wrist'),
            value: offWristText(this.script),
            dot: $r('app.color.ring_off')
          })
        }
        .alignItems(HorizontalAlign.Start)

        Text($r('app.string.shared_line'))
          .fontSize($r('app.float.note_font_size'))
          .fontColor($r('app.color.muted'))
          .textAlign(TextAlign.Center)
          .maxLines(2)
      }
      .width('66%')
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page'))
  }
}
