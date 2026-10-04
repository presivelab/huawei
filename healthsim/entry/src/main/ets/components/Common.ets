/**
 * Shared small components: the always-visible "simulated" banner and metric tiles.
 */

/** Amber strip shown on every screen. The simulator must never pass for real health data. */
@Component
export struct SimBanner {
  build() {
    Row() {
      Text($r('app.string.sim_banner'))
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.banner_text'))
        .maxLines(2)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
    .backgroundColor($r('app.color.banner_bg'))
  }
}

/**
 * Metric tile. Labels are fixed at construction; values are @Prop so they refresh.
 */
@Component
export struct MetricTile {
  title: ResourceStr = '';
  unit: ResourceStr = '';
  detailLabel: ResourceStr = '';
  @Prop value: string = '';
  @Prop detailValue: string = '';

  build() {
    Column({ space: 4 }) {
      Text(this.title)
        .fontSize(13)
        .fontColor($r('app.color.muted'))
      Row({ space: 4 }) {
        Text(this.value)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Text(this.unit)
          .fontSize(12)
          .fontColor($r('app.color.muted'))
      }
      .alignItems(VerticalAlign.Bottom)
      Row({ space: 4 }) {
        Text(this.detailLabel)
          .fontSize(11)
          .fontColor($r('app.color.muted'))
        Text(this.detailValue)
          .fontSize(11)
          .fontColor($r('app.color.muted'))
      }
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .borderRadius(16)
    .backgroundColor($r('app.color.surface'))
  }
}

/** Colored dot, label and minutes for the sleep legend. */
@Component
export struct LegendItem {
  color: string = '';
  label: ResourceStr = '';
  @Prop minutes: number = 0;

  build() {
    Row({ space: 4 }) {
      Circle()
        .width(8)
        .height(8)
        .fill(this.color)
      Text(this.label)
        .fontSize(11)
        .fontColor($r('app.color.muted'))
      Text(String(this.minutes))
        .fontSize(11)
        .fontColor($r('app.color.ink'))
    }
    .margin({ right: 12, bottom: 4 })
  }
}

/** 12,345 */
export function formatInt(n: number): string {
  const s: string = String(Math.round(n));
  let out: string = '';
  for (let i = 0; i < s.length; i++) {
    const fromEnd: number = s.length - i;
    out += s.charAt(i);
    if (fromEnd > 1 && fromEnd % 3 === 1 && s.charAt(0) !== '-') {
      out += ',';
    }
  }
  return out;
}

/** Number or a dash when there is no data. */
export function orDash(n: number, digits: number): string {
  if (n === 0) {
    return '—';
  }
  return digits > 0 ? n.toFixed(digits) : String(Math.round(n));
}
