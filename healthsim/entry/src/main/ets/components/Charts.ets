/**
 * Small canvas charts: hourly steps, 24 h heart rate with wear gaps, sleep stages.
 * Inputs are plain number arrays from HsSummary; charts redraw when the @Prop changes.
 */
import { HsSleepStage } from '../healthsim/HsTypes';
import { Palette } from '../common/Palette';

@Component
export struct StepsBarsChart {
  @Prop @Watch('redraw') values: number[] = [];
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  redraw(): void {
    this.draw();
  }

  private draw(): void {
    const w: number = this.ctx.width;
    const h: number = this.ctx.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    this.ctx.clearRect(0, 0, w, h);
    const n: number = 24;
    let max: number = 1;
    for (let i = 0; i < this.values.length; i++) {
      max = Math.max(max, this.values[i]);
    }
    const gap: number = 3;
    const barW: number = (w - gap * (n - 1)) / n;
    this.ctx.fillStyle = Palette.EMPTY;
    this.ctx.fillRect(0, h - 1, w, 1);
    for (let i = 0; i < n && i < this.values.length; i++) {
      const barH: number = Math.max(this.values[i] > 0 ? 2 : 0, (this.values[i] / max) * (h - 4));
      this.ctx.fillStyle = Palette.ACCENT;
      this.ctx.fillRect(i * (barW + gap), h - barH, barW, barH);
    }
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height(84)
      .onReady(() => {
        this.draw();
      })
  }
}

@Component
export struct HrLineChart {
  /** One value per 5-minute slot, 0 = no sample. */
  @Prop @Watch('redraw') values: number[] = [];
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  redraw(): void {
    this.draw();
  }

  private draw(): void {
    const w: number = this.ctx.width;
    const h: number = this.ctx.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    this.ctx.clearRect(0, 0, w, h);
    const n: number = this.values.length;
    if (n === 0) {
      return;
    }
    let minV: number = 999;
    let maxV: number = 0;
    for (let i = 0; i < n; i++) {
      const v: number = this.values[i];
      if (v > 0) {
        minV = Math.min(minV, v);
        maxV = Math.max(maxV, v);
      }
    }
    if (maxV === 0) {
      return;
    }
    const lo: number = minV - 5;
    const hi: number = maxV + 5;
    const dx: number = w / n;
    const yOf = (v: number): number => h - ((v - lo) / (hi - lo)) * h;

    // Watch-off stretches as shaded bands.
    this.ctx.fillStyle = Palette.EMPTY;
    for (let i = 0; i < n; i++) {
      if (this.values[i] === 0) {
        this.ctx.fillRect(i * dx, 0, dx + 0.5, h);
      }
    }
    // Grid.
    this.ctx.strokeStyle = Palette.GRID;
    this.ctx.lineWidth = 1;
    for (let g = 1; g <= 3; g++) {
      const y: number = (g * h) / 4;
      this.ctx.beginPath();
      this.ctx.moveTo(0, y);
      this.ctx.lineTo(w, y);
      this.ctx.stroke();
    }
    // Line, broken at gaps.
    this.ctx.strokeStyle = Palette.HEART;
    this.ctx.lineWidth = 1.5;
    this.ctx.beginPath();
    let drawing: boolean = false;
    for (let i = 0; i < n; i++) {
      const v: number = this.values[i];
      if (v === 0) {
        drawing = false;
        continue;
      }
      const x: number = i * dx + dx / 2;
      if (drawing) {
        this.ctx.lineTo(x, yOf(v));
      } else {
        this.ctx.moveTo(x, yOf(v));
        drawing = true;
      }
    }
    this.ctx.stroke();
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height(110)
      .onReady(() => {
        this.draw();
      })
  }
}

@Component
export struct SleepStagesChart {
  /** One stage code per 5-minute slot, 0 = no data. */
  @Prop @Watch('redraw') stages: number[] = [];
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  redraw(): void {
    this.draw();
  }

  private rowOf(stage: number): number {
    if (stage === HsSleepStage.AWAKE) {
      return 0;
    }
    if (stage === HsSleepStage.REM) {
      return 1;
    }
    if (stage === HsSleepStage.LIGHT) {
      return 2;
    }
    return 3;
  }

  private colorOf(stage: number): string {
    if (stage === HsSleepStage.AWAKE) {
      return Palette.AWAKE;
    }
    if (stage === HsSleepStage.REM) {
      return Palette.REM;
    }
    if (stage === HsSleepStage.LIGHT) {
      return Palette.LIGHT;
    }
    return Palette.DEEP;
  }

  private draw(): void {
    const w: number = this.ctx.width;
    const h: number = this.ctx.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    this.ctx.clearRect(0, 0, w, h);
    const n: number = this.stages.length;
    if (n === 0) {
      return;
    }
    const dx: number = w / n;
    const rowH: number = h / 4;
    for (let i = 0; i < n; i++) {
      const st: number = this.stages[i];
      if (st === 0) {
        this.ctx.fillStyle = Palette.EMPTY;
        this.ctx.fillRect(i * dx, 0, dx + 0.5, h);
        continue;
      }
      this.ctx.fillStyle = this.colorOf(st);
      this.ctx.fillRect(i * dx, this.rowOf(st) * rowH + 2, dx + 0.5, rowH - 4);
    }
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height(80)
      .onReady(() => {
        this.draw();
      })
  }
}
