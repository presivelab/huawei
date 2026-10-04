import { VALUE_LARGE, ValueWithUnit } from './ValueWithUnit';

export const BAR_MISSING: number = -1;
export const METRIC_OFF_TEXT: string = 'Off · missing evidence';
export const METRIC_EMPTY_TEXT: string = 'No records yet';

const BAR_AREA: number = 32;
const BAR_MIN: number = 4;
const BAR_ZERO: number = 2;

export interface MetricTileParams {
  symbol: Resource;
  name: string;
  tint: ResourceColor;
  value: string;      // empty: no reading yet
  unit: string;
  bars: number[];     // seven days, oldest first; BAR_MISSING is a day without data
  off?: boolean;      // the data type is switched off
}

function barsMax(bars: number[]): number {
  let max = 0;
  for (let i = 0; i < bars.length; i++) {
    if (bars[i] > max) {
      max = bars[i];
    }
  }
  return max;
}

// A measured zero is a thin line; a day without data is a dot, never a bar.
function barHeight(value: number, max: number): number {
  if (value <= 0 || max <= 0) {
    return BAR_ZERO;
  }
  return Math.max(BAR_MIN, Math.round(BAR_AREA * value / max));
}

// One metric: its symbol and name, the value with its unit, and seven small bars for the last seven days.
// A switched-off data type reads "Off · missing evidence" and draws no bars.
@Builder
export function MetricTile(p: MetricTileParams) {
  Column({ space: 8 }) {
    Row({ space: 8 }) {
      SymbolGlyph(p.symbol)
        .fontSize(20)
        .fontColor([p.off ? $r('sys.color.icon_tertiary') : p.tint])
      Text(p.name)
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)

    if (p.off) {
      Text(METRIC_OFF_TEXT)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
    } else if (p.value.length === 0) {
      Text(METRIC_EMPTY_TEXT)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
    } else {
      ValueWithUnit({ value: p.value, unit: p.unit, level: VALUE_LARGE })
    }

    Row({ space: 4 }) {
      ForEach(p.bars, (value: number) => {
        Column() {
          if (p.off || value < 0) {
            Circle()
              .width(4)
              .height(4)
              .fill($r('sys.color.font_fourth'))
          } else {
            Rect()
              .width('100%')
              .height(barHeight(value, barsMax(p.bars)))
              .radius(2)
              .fill(p.tint)
          }
        }
        .layoutWeight(1)
        .height(BAR_AREA)
        .justifyContent(FlexAlign.End)
      }, (value: number, index: number) => `${index}|${value}`)
    }
    .width('100%')
  }
  .alignItems(HorizontalAlign.Start)
  .padding({
    left: 16,
    right: 16,
    top: 12,
    bottom: 12
  })
  .backgroundColor($r('sys.color.comp_background_primary'))
  .borderRadius($r('sys.float.corner_radius_level8'))
}
