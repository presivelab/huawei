// The day as a ring of 288 five-minute slots, 00:00 at the top, clockwise.
// Worn, charging and off-wrist are coloured; "not observed" stays neutral grey: it is never shown as off-wrist.

const TWO_PI = Math.PI * 2;
const SLOTS = 288;
const RING_WIDTH_VP = 9;
const EDGE_GAP_VP = 5;
const MARKER_RADIUS_VP = 3.5;

export const SLOT_COLOR_WORN = '#30D158';
export const SLOT_COLOR_CHARGING = '#0A84FF';
export const SLOT_COLOR_OFF = '#FF453A';
export const SLOT_COLOR_UNKNOWN = '#3A3A3C';
const MARKER_COLOR = '#FFFFFF';

function colorOf(state: string): string {
  if (state === 'W') {
    return SLOT_COLOR_WORN;
  }
  if (state === 'C') {
    return SLOT_COLOR_CHARGING;
  }
  if (state === 'O') {
    return SLOT_COLOR_OFF;
  }
  return SLOT_COLOR_UNKNOWN;
}

function angleOf(slot: number): number {
  return -Math.PI / 2 + slot * TWO_PI / SLOTS;
}

@Component
export struct SlotRing {
  @Prop @Watch('onChanged') slots: string = '';
  @Prop @Watch('onChanged') openSlot: number = -1;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private ready: boolean = false;

  onChanged(propName: string): void {
    this.draw();
  }

  private draw(): void {
    if (!this.ready) {
      return;
    }
    const ctx = this.ctx;
    const w = ctx.width;
    const h = ctx.height;
    const cx = w / 2;
    const cy = h / 2;
    const radius = Math.min(w, h) / 2 - EDGE_GAP_VP - RING_WIDTH_VP / 2;
    ctx.clearRect(0, 0, w, h);
    ctx.lineWidth = RING_WIDTH_VP;
    ctx.lineCap = 'butt';

    // The whole day in neutral grey first, then every run of worn / charging / off-wrist on top.
    ctx.beginPath();
    ctx.strokeStyle = SLOT_COLOR_UNKNOWN;
    ctx.arc(cx, cy, radius, 0, TWO_PI);
    ctx.stroke();

    const slots = this.slots;
    let i = 0;
    while (i < slots.length && i < SLOTS) {
      const state = slots.charAt(i);
      let end = i + 1;
      while (end < slots.length && end < SLOTS && slots.charAt(end) === state) {
        end++;
      }
      if (state !== 'U') {
        ctx.beginPath();
        ctx.strokeStyle = colorOf(state);
        ctx.arc(cx, cy, radius, angleOf(i), angleOf(end));
        ctx.stroke();
      }
      i = end;
    }

    // Where the recorder is now.
    if (this.openSlot >= 0 && this.openSlot < SLOTS) {
      const a = angleOf(this.openSlot + 0.5);
      ctx.beginPath();
      ctx.fillStyle = MARKER_COLOR;
      ctx.arc(cx + radius * Math.cos(a), cy + radius * Math.sin(a), MARKER_RADIUS_VP, 0, TWO_PI);
      ctx.fill();
    }
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
