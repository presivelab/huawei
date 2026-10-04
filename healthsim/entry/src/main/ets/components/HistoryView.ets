/**
 * History tab: one row per day, newest first, with optional scenario ground truth
 * (sick, watch removed, charging, padded steps). Ground truth is never sent to FairWear.
 */
import { DayRow } from '../healthsim/HsSummary';
import { formatInt } from './Common';

@Extend(Text)
function tag(bg: ResourceColor, fg: ResourceColor) {
  .fontSize(10)
  .fontWeight(FontWeight.Medium)
  .fontColor(fg)
  .backgroundColor(bg)
  .borderRadius(6)
  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
}

@Component
struct HistoryRow {
  @Prop row: DayRow = new DayRow();
  @Prop showTruth: boolean = true;

  private weekdayName(d: number): Resource {
    if (d === 1) {
      return $r('app.string.wd_1');
    }
    if (d === 2) {
      return $r('app.string.wd_2');
    }
    if (d === 3) {
      return $r('app.string.wd_3');
    }
    if (d === 4) {
      return $r('app.string.wd_4');
    }
    if (d === 5) {
      return $r('app.string.wd_5');
    }
    if (d === 6) {
      return $r('app.string.wd_6');
    }
    return $r('app.string.wd_0');
  }

  private sleepText(): string {
    if (this.row.sleepMinutes === 0) {
      return '—';
    }
    return (this.row.sleepMinutes / 60).toFixed(1) + ' h';
  }

  private rhrText(): string {
    return this.row.restingHr > 0 ? String(this.row.restingHr) : '—';
  }

  build() {
    Column({ space: 6 }) {
      Row() {
        Column() {
          Text(this.row.dateLabel)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink'))
          Text(this.weekdayName(this.row.weekday))
            .fontSize(11)
            .fontColor($r('app.color.muted'))
        }
        .width(56)
        .alignItems(HorizontalAlign.Start)

        Column() {
          Text(formatInt(this.row.steps))
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ink'))
          Text($r('app.string.col_steps'))
            .fontSize(10)
            .fontColor($r('app.color.muted'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column() {
          Text(this.rhrText())
            .fontSize(15)
            .fontColor($r('app.color.ink'))
          Text($r('app.string.col_rhr'))
            .fontSize(10)
            .fontColor($r('app.color.muted'))
        }
        .width(52)
        .alignItems(HorizontalAlign.Start)

        Column() {
          Text(this.sleepText())
            .fontSize(15)
            .fontColor($r('app.color.ink'))
          Text($r('app.string.col_sleep'))
            .fontSize(10)
            .fontColor($r('app.color.muted'))
        }
        .width(56)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      Row({ space: 8 }) {
        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%')
            .height(6)
            .borderRadius(3)
            .backgroundColor($r('app.color.empty'))
          Row()
            .width(String(this.row.hrCoveragePct) + '%')
            .height(6)
            .borderRadius(3)
            .backgroundColor($r('app.color.accent'))
        }
        .layoutWeight(1)
        Text(String(this.row.hrCoveragePct) + '%')
          .fontSize(11)
          .fontColor($r('app.color.muted'))
          .width(36)
        Text($r('app.string.col_worn'))
          .fontSize(10)
          .fontColor($r('app.color.muted'))
      }
      .width('100%')

      if (this.showTruth) {
        Row({ space: 6 }) {
          if (this.row.partial) {
            Text($r('app.string.tag_partial')).tag($r('app.color.empty'), $r('app.color.muted'))
          }
          if (this.row.sick) {
            Text($r('app.string.tag_sick')).tag($r('app.color.sick_bg'), $r('app.color.sick_text'))
          }
          if (this.row.removal) {
            Text($r('app.string.tag_off')).tag($r('app.color.off_bg'), $r('app.color.off_text'))
          }
          if (this.row.charged) {
            Text($r('app.string.tag_charge')).tag($r('app.color.empty'), $r('app.color.muted'))
          }
          if (this.row.paddedSlots > 0) {
            Text($r('app.string.tag_pad', this.row.paddedSlots)).tag($r('app.color.pad_bg'), $r('app.color.pad_text'))
          }
        }
      }
    }
    .width('100%')
    .padding(14)
    .borderRadius(14)
    .backgroundColor($r('app.color.surface'))
  }
}

@Component
export struct HistoryView {
  @Prop rows: DayRow[] = [];
  @Prop datasetId: string = '';
  @State showTruth: boolean = true;

  build() {
    Column({ space: 8 }) {
      Row() {
        Text($r('app.string.history_title'))
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .layoutWeight(1)
        Text($r('app.string.show_truth'))
          .fontSize(12)
          .fontColor($r('app.color.muted'))
        Toggle({ type: ToggleType.Switch, isOn: this.showTruth })
          .selectedColor($r('app.color.accent'))
          .onChange((isOn: boolean) => {
            this.showTruth = isOn;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 8, top: 12 })

      Text($r('app.string.truth_note'))
        .fontSize(11)
        .fontColor($r('app.color.muted'))
        .padding({ left: 16, right: 16 })
        .width('100%')

      List({ space: 8 }) {
        ForEach(this.rows, (r: DayRow) => {
          ListItem() {
            HistoryRow({ row: r, showTruth: this.showTruth })
          }
        }, (r: DayRow) => this.datasetId + '-' + String(r.dayStartMs))
      }
      .cachedCount(4)
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .padding({ left: 16, right: 16, bottom: 16 })
    }
    .width('100%')
    .height('100%')
  }
}
