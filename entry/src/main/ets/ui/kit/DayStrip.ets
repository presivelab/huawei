import { STRIP_DAYS } from 'common';
import { COLOR_CHARGING, COLOR_OFF, COLOR_UNOBSERVED, COLOR_WORN } from './KitTokens';

const RING: number = 36;
const RING_STROKE: number = 5;
const DAY_TOTAL_MIN: number = 1440;

// One day on the strip. Minutes of the four states; `missing` is a day that never reached the phone.
export class DayStripItem {
  key: string = '';
  top: string = '';         // weekday, "Wed"
  bottom: string = '';      // day of the month, "7"
  spoken: string = '';      // the whole day in words, for screen readers
  worn: number = 0;
  charging: number = 0;
  off: number = 0;
  unobserved: number = 0;
  missing: boolean = false;
}

export interface DayStripParams {
  items: DayStripItem[];    // oldest first, at most seven
}

@Builder
function dayRing(item: DayStripItem) {
  if (item.missing) {
    // A missing day is a dashed outline, not a ring of zeros.
    Circle()
      .width(RING - RING_STROKE)
      .height(RING - RING_STROKE)
      .fillOpacity(0)
      .stroke($r('sys.color.font_tertiary'))
      .strokeWidth(2)
      .strokeDashArray([3, 3])
      .margin(RING_STROKE / 2)
  } else {
    DataPanel({
      values: [item.worn, item.charging, item.off, item.unobserved],
      max: DAY_TOTAL_MIN,
      type: DataPanelType.Circle
    })
      .closeEffect(true)
      .valueColors([COLOR_WORN, COLOR_CHARGING, COLOR_OFF, COLOR_UNOBSERVED])
      .trackBackgroundColor($r('sys.color.comp_background_tertiary'))
      .strokeWidth(RING_STROKE)
      .width(RING)
      .height(RING)
  }
}

// The last seven days as small rings split into worn, charging, off the wrist and not observed.
// Fewer than seven days fill from the left; the remaining columns stay empty.
@Builder
export function DayStrip(p: DayStripParams) {
  Row() {
    ForEach(p.items, (item: DayStripItem) => {
      Column({ space: 4 }) {
        dayRing(item)
        Text(item.top)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
        Text(item.bottom)
          .fontSize($r('sys.float.Body_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
      }
      .layoutWeight(1)
      .accessibilityGroup(true)
      .accessibilityText(item.spoken)
    }, (item: DayStripItem) => item.key)
    if (p.items.length < STRIP_DAYS) {
      Blank()
        .layoutWeight(STRIP_DAYS - p.items.length)
    }
  }
  .width('100%')
  .alignItems(VerticalAlign.Top)
}
