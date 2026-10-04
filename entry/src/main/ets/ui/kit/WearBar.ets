import { WEAR_LABEL_CHARGING, WEAR_LABEL_OFF, WEAR_LABEL_UNOBSERVED, WEAR_LABEL_WORN } from 'common';
import { COLOR_CHARGING, COLOR_OFF, COLOR_UNOBSERVED, COLOR_WORN } from './KitTokens';

export interface WearSplit {
  worn: number;
  charging: number;
  off: number;
  unobserved: number;
}

@Builder
function wearSegment(minutes: number, color: Resource) {
  if (minutes > 0) {
    Row()
      .layoutWeight(minutes)
      .constraintSize({ minWidth: 2 })
      .height('100%')
      .backgroundColor(color)
  }
}

// One day as a bar: worn, charging, off the wrist, not observed, each as wide as its share of the day.
@Builder
export function WearBar(p: WearSplit) {
  Row({ space: 2 }) {
    wearSegment(p.worn, COLOR_WORN)
    wearSegment(p.charging, COLOR_CHARGING)
    wearSegment(p.off, COLOR_OFF)
    wearSegment(p.unobserved, COLOR_UNOBSERVED)
  }
  .width('100%')
  .height(8)
  .borderRadius(4)
  .clip(true)
}

@Builder
function legendItem(label: string, color: Resource) {
  Row({ space: 4 }) {
    Circle()
      .width(8)
      .height(8)
      .fill(color)
    Text(label)
      .fontSize($r('sys.float.Body_S'))
      .fontColor($r('sys.color.font_secondary'))
  }
  .alignItems(VerticalAlign.Center)
  .margin({ right: 12 })
}

// What the four colours mean; shown once per card, above the first bar or ring.
@Builder
export function WearLegend() {
  Flex({ wrap: FlexWrap.Wrap }) {
    legendItem(WEAR_LABEL_WORN, COLOR_WORN)
    legendItem(WEAR_LABEL_CHARGING, COLOR_CHARGING)
    legendItem(WEAR_LABEL_OFF, COLOR_OFF)
    legendItem(WEAR_LABEL_UNOBSERVED, COLOR_UNOBSERVED)
  }
  .width('100%')
}
