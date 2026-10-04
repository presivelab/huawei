import { LengthMetrics } from '@kit.ArkUI';
import { dayStateLabel } from 'common';
import { dayStateColor } from './KitTokens';

export interface MonthBarParams {
  states: string[];     // DayState of every day of the period, oldest first
  spoken: string;       // the bar in words, for screen readers
}

export interface DayStateLegendParams {
  states: string[];     // the DayState values to name, in the order shown
  note?: string;        // a closing remark without a colour, "85% needed"
}

// A month as one bar: a segment per day in the colour of the day's state.
@Builder
export function MonthBar(p: MonthBarParams) {
  Row({ space: 2 }) {
    ForEach(p.states, (state: string) => {
      Row()
        .layoutWeight(1)
        .height('100%')
        .backgroundColor(dayStateColor(state))
        .borderRadius(3)
    }, (state: string, index: number) => `${index}|${state}`)
  }
  .width('100%')
  .height(14)
  .accessibilityGroup(true)
  .accessibilityText(p.spoken)
}

// What the colours of the month bar and of the day rings mean.
@Builder
export function DayStateLegend(p: DayStateLegendParams) {
  Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(14), cross: LengthMetrics.vp(4) } }) {
    ForEach(p.states, (state: string) => {
      Row({ space: 6 }) {
        Row()
          .width(8)
          .height(8)
          .borderRadius(2)
          .backgroundColor(dayStateColor(state))
        Text(dayStateLabel(state))
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(VerticalAlign.Center)
    }, (state: string) => state)
    if (p.note !== undefined) {
      Text(p.note)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_secondary'))
    }
  }
  .width('100%')
}
