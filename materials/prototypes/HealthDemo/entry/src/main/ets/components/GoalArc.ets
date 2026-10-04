import { paintGoalArc } from './ActivityRings';

const STROKE_RATIO = 0.15;
const GLYPH_RATIO = 0.4;

// One small goal arc with its icon in the middle, used in the "Today" rows.
@Component
export struct GoalArc {
  @Prop @Watch('draw') value: number = 0;
  @Prop color: string = '#FFFFFF';
  @Prop track: string = '#333333';
  @Prop icon: Resource = $r('sys.symbol.flame_fill');
  @Prop diameter: number = 40;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private ready: boolean = false;

  draw(): void {
    if (!this.ready) {
      return;
    }
    const size = Math.min(this.ctx.width, this.ctx.height);
    const stroke = size * STROKE_RATIO;
    this.ctx.clearRect(0, 0, this.ctx.width, this.ctx.height);
    paintGoalArc(this.ctx, this.ctx.width / 2, this.ctx.height / 2, (size - stroke) / 2, stroke, this.color,
      this.track, this.value, false);
  }

  build() {
    Stack() {
      Canvas(this.ctx)
        .width('100%')
        .height('100%')
        .onReady(() => {
          this.ready = true;
          this.draw();
        })
      SymbolGlyph(this.icon)
        .fontSize(this.diameter * GLYPH_RATIO)
        .fontColor([this.color])
    }
    .width(this.diameter)
    .height(this.diameter)
  }
}
