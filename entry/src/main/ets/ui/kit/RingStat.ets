import { VALUE_MEDIUM, ValueWithUnit } from './ValueWithUnit';

const RING_FILL_MS: number = 500;
const RING_STROKE: number = 6;
const DASH: number = 6;

// Lets the ring's value run through an animation of a fixed length instead of the system's own smoothing.
@AnimatableExtend(Progress)
function ringValue(value: number) {
  .value(value)
}

// A ring (system Progress) with a value and its unit in the middle. It fills from empty in 500 ms when it
// appears and moves to a new value the same way. A component because the fill is state.
//
// `stacked` puts a large value above a small unit (the score ring); `dashed` draws the track as dashes,
// for a ring that shows how much evidence there is while there is no score.
@Component
export struct RingStat {
  @Prop @Watch('onTarget') value: number = 0;
  @Prop total: number = 1;
  @Prop valueText: string = '';
  @Prop unit: string = '';
  @Prop ringColor: ResourceColor = $r('sys.color.confirm');
  @Prop spoken: string = '';        // what a screen reader says; empty: the value and the unit
  diameter: number = 80;
  stroke: number = RING_STROKE;
  stacked: boolean = false;
  valueFont: number = 40;           // size of the value when stacked
  dashed: boolean = false;
  // `shown` is what the animation runs to. `settled` is where the last animation ended: a rebuild (for
  // example a switch between light and dark mode) recreates the ring from it instead of from empty.
  @State private shown: number = 0;
  @State private settled: number = 0;

  onTarget(): void {
    this.shown = this.value;
  }

  build() {
    Stack() {
      if (this.dashed) {
        Circle()
          .width(this.diameter - this.stroke)
          .height(this.diameter - this.stroke)
          .fillOpacity(0)
          .stroke($r('sys.color.comp_background_tertiary'))
          .strokeWidth(this.stroke)
          .strokeDashArray([DASH, DASH])
      }
      Progress({ value: this.settled, total: this.total > 0 ? this.total : 1, type: ProgressType.Ring })
        .style({ strokeWidth: this.stroke, enableSmoothEffect: false, shadow: false })
        .color(this.ringColor)
        .backgroundColor(this.dashed ? Color.Transparent : $r('sys.color.comp_background_tertiary'))
        .ringValue(this.shown)
        .animation({
          duration: RING_FILL_MS,
          curve: Curve.EaseOut,
          onFinish: () => {
            this.settled = this.shown;
          }
        })
        .width(this.diameter)
        .height(this.diameter)
      if (this.stacked) {
        Column({ space: 2 }) {
          Text(this.valueText)
            .fontSize(this.valueFont)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
          Text(this.unit)
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
        }
      } else {
        ValueWithUnit({ value: this.valueText, unit: this.unit, level: VALUE_MEDIUM })
      }
    }
    .width(this.diameter)
    .height(this.diameter)
    .accessibilityGroup(true)
    .accessibilityText(this.spoken.length > 0 ? this.spoken : `${this.valueText} ${this.unit}`)
    .onAppear(() => {
      this.shown = this.value;
    })
  }
}
