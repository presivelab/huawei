import {
  EXERCISE_COLOR,
  EXERCISE_TRACK,
  MOVE_COLOR,
  MOVE_TRACK,
  STAND_COLOR,
  STAND_TRACK
} from './Theme';

const BADGE_GLYPH = '#241000';
const BADGE_OUTLINE = 'rgba(0, 0, 0, 0.3)';
const BADGE_GLYPH_SIZE = 14;
// Geometry as a share of the canvas side, measured on the reference screen.
const STROKE_RATIO = 0.105;
const PITCH_RATIO = 0.116;
const OUTER_RADIUS_RATIO = 0.445;
// Open horseshoe: starts lower left, runs clockwise over the top, leaves the bottom quarter open.
const ARC_START = Math.PI * 0.75;
const ARC_SWEEP = Math.PI * 1.5;

// Draws the track, the filled part and the start badge of one goal arc.
export function paintGoalArc(ctx: CanvasRenderingContext2D, centerX: number, centerY: number, radius: number,
  stroke: number, color: string, track: string, value: number, badge: boolean): void {
  ctx.lineWidth = stroke;
  ctx.lineCap = 'round';
  ctx.beginPath();
  ctx.arc(centerX, centerY, radius, ARC_START, ARC_START + ARC_SWEEP);
  ctx.strokeStyle = track;
  ctx.stroke();
  const filled = Math.min(Math.max(value, 0), 1);
  if (filled > 0) {
    ctx.beginPath();
    ctx.arc(centerX, centerY, radius, ARC_START, ARC_START + ARC_SWEEP * filled);
    ctx.strokeStyle = color;
    ctx.stroke();
  }
  if (!badge) {
    return;
  }
  const badgeX = centerX + radius * Math.cos(ARC_START);
  const badgeY = centerY + radius * Math.sin(ARC_START);
  ctx.beginPath();
  ctx.arc(badgeX, badgeY, stroke / 2, 0, Math.PI * 2);
  ctx.fillStyle = color;
  ctx.fill();
  ctx.beginPath();
  ctx.arc(badgeX, badgeY, stroke / 2 - 1, 0, Math.PI * 2);
  ctx.lineWidth = 1.5;
  ctx.strokeStyle = BADGE_OUTLINE;
  ctx.stroke();
}

function radiusRatio(ring: number): number {
  return OUTER_RADIUS_RATIO - PITCH_RATIO * ring;
}

@Component
struct BadgeGlyph {
  @Prop icon: Resource = $r('sys.symbol.flame_fill');
  @Prop ring: number = 0;

  build() {
    SymbolGlyph(this.icon)
      .fontSize(BADGE_GLYPH_SIZE)
      .fontColor([BADGE_GLYPH])
      .position({
        x: `${(0.5 + radiusRatio(this.ring) * Math.cos(ARC_START)) * 100}%`,
        y: `${(0.5 + radiusRatio(this.ring) * Math.sin(ARC_START)) * 100}%`
      })
      .translate({ x: '-50%', y: '-50%' })
  }
}

@Component
export struct ActivityRings {
  @Prop @Watch('draw') move: number = 0;
  @Prop @Watch('draw') exercise: number = 0;
  @Prop @Watch('draw') stand: number = 0;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private ready: boolean = false;

  draw(): void {
    if (!this.ready) {
      return;
    }
    const size = Math.min(this.ctx.width, this.ctx.height);
    const centerX = this.ctx.width / 2;
    const centerY = this.ctx.height / 2;
    const stroke = size * STROKE_RATIO;
    this.ctx.clearRect(0, 0, this.ctx.width, this.ctx.height);
    paintGoalArc(this.ctx, centerX, centerY, size * radiusRatio(0), stroke, MOVE_COLOR, MOVE_TRACK, this.move, true);
    paintGoalArc(this.ctx, centerX, centerY, size * radiusRatio(1), stroke, EXERCISE_COLOR, EXERCISE_TRACK,
      this.exercise, true);
    paintGoalArc(this.ctx, centerX, centerY, size * radiusRatio(2), stroke, STAND_COLOR, STAND_TRACK, this.stand,
      true);
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
      BadgeGlyph({ icon: $r('sys.symbol.flame_fill'), ring: 0 })
      BadgeGlyph({ icon: $r('sys.symbol.figure_run'), ring: 1 })
      BadgeGlyph({ icon: $r('sys.symbol.figure_arms_open'), ring: 2 })
    }
    .width('100%')
    .height('100%')
  }
}
