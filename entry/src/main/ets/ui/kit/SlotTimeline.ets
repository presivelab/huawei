import { SlotRun } from 'common';
import { wearColor } from './KitTokens';

export interface SlotTimelineParams {
  runs: SlotRun[];      // from slotRuns(): the 288 five-minute slots of one day, merged into runs
}

// One day in time order: when the watch was worn, charging, off the wrist or not observed.
// WearBar shows how much of each; this shows when. WearLegend names the four colours.
@Builder
export function SlotTimeline(p: SlotTimelineParams) {
  Row() {
    ForEach(p.runs, (run: SlotRun) => {
      Row()
        .layoutWeight(run.count)
        .height('100%')
        .backgroundColor(wearColor(run.state))
    }, (run: SlotRun, index: number) => `${index}|${run.state}|${run.count}`)
  }
  .width('100%')
  .height(12)
  .borderRadius(6)
  .clip(true)
}
