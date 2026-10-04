import { CHART_MINUTES, HealthEngine, MinuteBucket } from '../model/HealthEngine';
import { HEART_COLOR } from './Theme';

const GRID_COLOR = 'rgba(255, 255, 255, 0.24)';
const AXIS_COLOR = 'rgba(255, 255, 255, 0.45)';
const LABEL_COLOR = 'rgba(255, 255, 255, 0.6)';
const AREA_TOP = 'rgba(255, 59, 92, 0.55)';
const AREA_BOTTOM = 'rgba(255, 59, 92, 0.05)';
const LABEL_FONT = '9vp sans-serif';
const SCALE_LOW = 40;
const SCALE_HIGH = 160;
const GRID_STEP = 50;
const SCALE_HEADROOM = 10;
// Plot insets in vp. The sides stay clear of the round bezel that clips the card.
const PLOT_LEFT = 28;
const PLOT_RIGHT = 54;
const PLOT_TOP = 9;
const PLOT_BOTTOM = 24;
const AXIS_GAP = 5;
const LINE_WIDTH = 1.8;
const LATEST_DOT_RADIUS = 2.4;

function clock(minutesAgo: number): string {
  const time = new Date(Date.now() - minutesAgo * 60000);
  return `${time.getHours().toString().padStart(2, '0')}:${time.getMinutes().toString().padStart(2, '0')}`;
}

// Line and area chart of the one-minute heart-rate averages of the last CHART_MINUTES minutes.
@Component
export struct HeartChart {
  @Prop @Watch('draw') tick: number = 0;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private ready: boolean = false;

  draw(): void {
    if (!this.ready) {
      return;
    }
    const ctx = this.ctx;
    const left = PLOT_LEFT;
    const right = ctx.width - PLOT_RIGHT;
    const top = PLOT_TOP;
    const bottom = ctx.height - PLOT_BOTTOM;
    const slots: (MinuteBucket | null)[] = HealthEngine.get().lastHour();
    let high = SCALE_HIGH;
    slots.forEach((slot) => {
      if (slot !== null) {
        high = Math.max(high, Math.ceil(slot.max / GRID_STEP) * GRID_STEP + SCALE_HEADROOM);
      }
    });
    const slotWidth = (right - left) / CHART_MINUTES;
    ctx.clearRect(0, 0, ctx.width, ctx.height);
    this.grid(left, right, top, bottom, high);
    this.axis(left, right, bottom + AXIS_GAP);

    let xs: number[] = [];
    let ys: number[] = [];
    let latestX = -1;
    let latestY = -1;
    slots.forEach((slot, index) => {
      if (slot === null) {
        this.run(xs, ys, top, bottom);
        xs = [];
        ys = [];
        return;
      }
      const average = Math.min(Math.max(slot.sum / slot.count, SCALE_LOW), high);
      latestX = left + (index + 0.5) * slotWidth;
      latestY = bottom - (average - SCALE_LOW) / (high - SCALE_LOW) * (bottom - top);
      xs.push(latestX);
      ys.push(latestY);
    });
    this.run(xs, ys, top, bottom);
    if (latestX >= 0) {
      ctx.beginPath();
      ctx.arc(latestX, latestY, LATEST_DOT_RADIUS, 0, Math.PI * 2);
      ctx.fillStyle = '#FFFFFF';
      ctx.fill();
    }
  }

  private grid(left: number, right: number, top: number, bottom: number, high: number): void {
    const ctx = this.ctx;
    ctx.font = LABEL_FONT;
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    ctx.lineWidth = 0.6;
    ctx.lineCap = 'butt';
    ctx.strokeStyle = GRID_COLOR;
    ctx.fillStyle = LABEL_COLOR;
    ctx.setLineDash([3, 3]);
    for (let value = GRID_STEP; value < high; value += GRID_STEP) {
      const y = bottom - (value - SCALE_LOW) / (high - SCALE_LOW) * (bottom - top);
      ctx.beginPath();
      ctx.moveTo(left, y);
      ctx.lineTo(right, y);
      ctx.stroke();
      ctx.fillText(value.toString(), right + 6, y);
    }
    ctx.setLineDash([]);
  }

  private axis(left: number, right: number, y: number): void {
    const ctx = this.ctx;
    ctx.strokeStyle = AXIS_COLOR;
    ctx.lineCap = 'round';
    ctx.lineWidth = 1.2;
    ctx.setLineDash([0.1, 3.4]);
    ctx.beginPath();
    ctx.moveTo(left, y);
    ctx.lineTo(right, y);
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.lineWidth = 1.6;
    [left, (left + right) / 2, right].forEach((x) => {
      ctx.beginPath();
      ctx.moveTo(x, y - 2.5);
      ctx.lineTo(x, y);
      ctx.stroke();
    });
    ctx.fillStyle = LABEL_COLOR;
    ctx.textBaseline = 'top';
    ctx.textAlign = 'left';
    ctx.fillText(clock(CHART_MINUTES), left, y + 4);
    ctx.textAlign = 'center';
    ctx.fillText(clock(CHART_MINUTES / 2), (left + right) / 2, y + 4);
    ctx.textAlign = 'right';
    ctx.fillText(clock(0), right, y + 4);
  }

  // One unbroken stretch of minutes: a dot for a single minute, otherwise an area with a line on top.
  private run(xs: number[], ys: number[], top: number, bottom: number): void {
    const ctx = this.ctx;
    if (xs.length === 0) {
      return;
    }
    if (xs.length === 1) {
      ctx.beginPath();
      ctx.arc(xs[0], ys[0], LINE_WIDTH, 0, Math.PI * 2);
      ctx.fillStyle = HEART_COLOR;
      ctx.fill();
      return;
    }
    const fill = ctx.createLinearGradient(0, top, 0, bottom);
    fill.addColorStop(0, AREA_TOP);
    fill.addColorStop(1, AREA_BOTTOM);
    ctx.beginPath();
    ctx.moveTo(xs[0], bottom);
    xs.forEach((x, index) => ctx.lineTo(x, ys[index]));
    ctx.lineTo(xs[xs.length - 1], bottom);
    ctx.closePath();
    ctx.fillStyle = fill;
    ctx.fill();
    ctx.beginPath();
    xs.forEach((x, index) => {
      if (index === 0) {
        ctx.moveTo(x, ys[index]);
      } else {
        ctx.lineTo(x, ys[index]);
      }
    });
    ctx.lineWidth = LINE_WIDTH;
    ctx.lineJoin = 'round';
    ctx.lineCap = 'round';
    ctx.strokeStyle = HEART_COLOR;
    ctx.stroke();
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.ready = true;
        this.draw();
      })
  }
}
