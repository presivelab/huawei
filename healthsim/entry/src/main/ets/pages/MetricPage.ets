import {
  METRIC_STEPS,
  metricUnit,
  NO_VALUE,
  SimMetricRow,
  simMetricRows,
  simPersonName
} from '../data/SimData';
import { BACK, HISTORY_NOTE, HISTORY_TITLE, PERSON_LABEL } from '../data/SimTexts';
import { CARD, SimBanner } from '../ui/SimBanner';
import { DEFAULT_PERSON, KEY_METRIC, KEY_PERSON, metricColor, metricLabel, metricSub, metricSymbol } from '../ui/SimMetric';

// One metric of the demo person over the last 30 days: the newest value on top, then one row per day with
// a bar against the highest day. A day that was not measured shows "—" and no bar, never zero.
@Entry
@Component
struct MetricPage {
  @StorageProp(KEY_PERSON) personId: string = DEFAULT_PERSON;
  @StorageProp(KEY_METRIC) metric: string = METRIC_STEPS;
  @State rows: SimMetricRow[] = [];

  aboutToAppear(): void {
    this.rows = simMetricRows(this.personId, this.metric);
  }

  private withUnit(value: string): string {
    const unit = metricUnit(this.metric);
    return value === NO_VALUE || unit.length === 0 ? value : `${value} ${unit}`;
  }

  build() {
    Column() {
      SimBanner()

      Row({ space: 8 }) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(20)
            .fontColor([$r('sys.color.font_primary')])
        }
        .width(40)
        .height(40)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .accessibilityText(BACK)
        .id('hs_back')
        .onClick(() => {
          this.getUIContext().getRouter().back();
        })
        Text(metricLabel(this.metric))
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
          .id('hs_metric_title')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 10 })
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Column({ space: 14 }) {
          Row({ space: 12 }) {
            SymbolGlyph(metricSymbol(this.metric))
              .fontSize(28)
              .fontColor([metricColor(this.metric)])
            Column({ space: 2 }) {
              Text(this.rows.length > 0 ? this.withUnit(this.rows[0].value) : NO_VALUE)
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.font_primary'))
                .id('hs_metric_value')
              Text(`${metricSub(this.metric)} · ${this.rows.length > 0 ? this.rows[0].title : NO_VALUE}`)
                .fontSize($r('sys.float.Body_S'))
                .fontColor($r('sys.color.font_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 4, right: 4 })
          .alignItems(VerticalAlign.Center)
          .accessibilityGroup(true)

          Column({ space: 4 }) {
            Row({ space: 8 }) {
              Text(HISTORY_TITLE)
                .fontSize($r('sys.float.Subtitle_M'))
                .fontWeight(600)
                .fontColor($r('sys.color.font_primary'))
                .layoutWeight(1)
              Text(`${PERSON_LABEL} · ${simPersonName(this.personId)}`)
                .fontSize($r('sys.float.Body_S'))
                .fontColor($r('sys.color.font_secondary'))
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .padding({ bottom: 8 })

            ForEach(this.rows, (row: SimMetricRow) => {
              Column({ space: 4 }) {
                Row({ space: 8 }) {
                  Text(row.title)
                    .fontSize($r('sys.float.Body_M'))
                    .fontColor($r('sys.color.font_primary'))
                    .layoutWeight(1)
                  Text(this.withUnit(row.value))
                    .fontSize($r('sys.float.Body_M'))
                    .fontWeight(FontWeight.Medium)
                    .fontColor(row.value === NO_VALUE ? $r('sys.color.font_secondary') :
                    $r('sys.color.font_primary'))
                    .textAlign(TextAlign.End)
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)

                Progress({ value: row.share, total: 100, type: ProgressType.Linear })
                  .style({ strokeWidth: 6, enableSmoothEffect: false })
                  .color(metricColor(this.metric))
                  .backgroundColor($r('app.color.hs_track'))
                  .width('100%')
              }
              .width('100%')
              .padding({ top: 6, bottom: 6 })
              .accessibilityGroup(true)
              .accessibilityText(`${row.title}, ` +
                (row.value === NO_VALUE ? 'not measured' : this.withUnit(row.value)))
            }, (row: SimMetricRow) => `${this.personId}|${this.metric}|${row.date}`)
          }
          .attributeModifier(CARD)
          .id('hs_history')

          Text(`${HISTORY_NOTE} ${this.rows.length} entries.`)
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_secondary'))
            .padding({ left: 4, right: 4 })
        }
        .padding({
          left: 16,
          right: 16,
          top: 4,
          bottom: 24
        })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
