import { VALUE_TILE, ValueWithUnit } from './ValueWithUnit';

export const BAR_MISSING: number = -1;
export const METRIC_OFF_TEXT: string = 'Off · missing evidence';
export const METRIC_EMPTY_TEXT: string = 'No records yet';

const BAR_AREA: number = 26;
const BAR_WIDTH: number = 8;
const BAR_MIN: number = 8;
const BAR_ZERO: number = 2;
const VALUE_AREA: number = 32;
const TILE_RADIUS: number = 20;
const TILE_PADDING: number = 14;

export interface MetricTileParams {
  symbol: Resource;
  name: string;
  tint: ResourceColor;
  value: string;      // empty: no reading yet
  unit: string;
  extraValue?: string;    // second pair of a duration: "7 h 24 min"
  extraUnit?: string;
  bars: number[];     // seven days, oldest first; BAR_MISSING is a day without data
  barsTop?: number;   // the value a full-height bar stands for; default: the largest of the seven
  off?: boolean;      // the data type is switched off
  emptyText?: string; // what stands in place of a missing value; default "No records yet"
  source?: string;    // where the value comes from, or why there is none; one small line
  spoken?: string;    // the whole tile in words, for screen readers
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
  return Math.min(BAR_AREA, Math.max(BAR_MIN, Math.round(BAR_AREA * value / max)));
}

function missing(p: MetricTileParams): boolean {
  return p.off === true || p.value.length === 0;
}

function spokenTile(p: MetricTileParams): string {
  if (p.spoken !== undefined && p.spoken.length > 0) {
    return p.spoken;
  }
  if (p.off) {
    return `${p.name}, ${METRIC_OFF_TEXT}`;
  }
  return p.value.length === 0 ? `${p.name}, ${p.emptyText ?? METRIC_EMPTY_TEXT}` : `${p.name}, ${p.value} ${p.unit}`;
}

// One metric: its symbol and name, the value with its unit, seven small bars for the last seven days and
// one line naming the source. A switched-off data type reads "Off · missing evidence"; a missing value is
// said in words and its symbol turns grey; days without data are dots, never bars.
@Builder
export function MetricTile(p: MetricTileParams) {
  Column({ space: 8 }) {
    Row({ space: 6 }) {
      SymbolGlyph(p.symbol)
        .fontSize(18)
        .fontColor([missing(p) ? $r('sys.color.icon_tertiary') : p.tint])
      Text(p.name)
        .maxFontSize($r('sys.float.Body_M'))
        .minFontSize($r('sys.float.Caption_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)

    // The same height in every state, so tiles in one row line up.
    Row() {
      if (missing(p)) {
        Text(p.off ? METRIC_OFF_TEXT : (p.emptyText ?? METRIC_EMPTY_TEXT))
          .maxFontSize($r('sys.float.Body_L'))
          .minFontSize($r('sys.float.Caption_M'))
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .fontColor($r('sys.color.font_secondary'))
      } else {
        ValueWithUnit({
          value: p.value,
          unit: p.unit,
          extraValue: p.extraValue,
          extraUnit: p.extraUnit,
          level: VALUE_TILE
        })
      }
    }
    .width('100%')
    .height(VALUE_AREA)
    .alignItems(VerticalAlign.Center)

    Row() {
      ForEach(p.bars, (value: number) => {
        Column() {
          if (p.off || value < 0) {
            Circle()
              .width(4)
              .height(4)
              .fill($r('sys.color.font_fourth'))
          } else {
            Rect()
              .width(BAR_WIDTH)
              .height(barHeight(value, p.barsTop ?? barsMax(p.bars)))
              .radius(BAR_WIDTH / 2)
              .fill(p.tint)
          }
        }
        .layoutWeight(1)
        .height(BAR_AREA)
        .justifyContent(FlexAlign.End)
      }, (value: number, index: number) => `${index}|${value}`)
    }
    .width('100%')

    if (p.source !== undefined) {
      Text(p.source)
        .fontSize($r('sys.float.Caption_L'))
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
  }
  .width('100%')
  .alignItems(HorizontalAlign.Start)
  .padding(TILE_PADDING)
  .backgroundColor($r('sys.color.comp_background_primary'))
  .borderRadius(TILE_RADIUS)
  .accessibilityGroup(true)
  .accessibilityText(spokenTile(p))
}
