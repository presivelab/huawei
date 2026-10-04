import { VALUE_MEDIUM, ValueWithUnit } from './ValueWithUnit';

const RING_FILL_MS: number = 500;
const RING_STROKE: number = 6;

// Lets the ring's value run through an animation of a fixed length instead of the system's own smoothing.
@AnimatableExtend(Progress)
function ringValue(value: number) {
  .value(value)
}

// A ring (system Progress) with a value and its unit in the middle. It fills from empty in 500 ms when it
// appears and moves to a new value the same way. A component because the fill is state.
@Component
export struct RingStat {
  @Prop @Watch('onTarget') value: number = 0;
  @Prop total: number = 1;
  @Prop valueText: string = '';
  @Prop unit: string = '';
  @Prop ringColor: ResourceColor = $r('sys.color.confirm');
  diameter: number = 80;
  // `shown` is what the animation runs to. `settled` is where the last animation ended: a rebuild (for
  // example a switch between light and dark mode) recreates the ring from it instead of from empty.
  @State private shown: number = 0;
  @State private settled: number = 0;

  onTarget(): void {
    this.shown = this.value;
  }

  build() {
    Stack() {
      Progress({ value: this.settled, total: this.total > 0 ? this.total : 1, type: ProgressType.Ring })
        .style({ strokeWidth: RING_STROKE, enableSmoothEffect: false, shadow: false })
        .color(this.ringColor)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
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
      ValueWithUnit({ value: this.valueText, unit: this.unit, level: VALUE_MEDIUM })
    }
    .width(this.diameter)
    .height(this.diameter)
    .onAppear(() => {
      this.shown = this.value;
    })
  }
}
