import {
  simCrfRows,
  simHistoryDays,
  simHrrRows,
  SimCrfRow,
  SimHistoryDay,
  SimHrrRow
} from '../data/SimData';
import {
  CRF_EMPTY,
  CRF_TITLE,
  HISTORY_DAYS_NOTE,
  HISTORY_DAYS_TITLE,
  HRR_EMPTY,
  HRR_TITLE
} from '../data/SimTexts';
import { CARD } from './SimBanner';

// The History tab: the completed days of the demo person newest first, then the VO₂max estimates and the
// heart-rate recovery tests. A reading that does not exist is "—", never zero.
@Component
export struct HistoryView {
  @Prop personId: string = '';

  @Builder
  dayRow(day: SimHistoryDay) {
    Column({ space: 4 }) {
      Row({ space: 8 }) {
        Text(day.title)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
        Text(day.steps)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
      }
      .width('100%')
      Text(`Intensity ${day.moderate} / ${day.vigorous} min · Resting ${day.resting}`)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_secondary'))
      Text(`Sleep ${day.sleepClock} · ${day.sleepTotal} · HRV ${day.hrv}`)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 8, bottom: 8 })
    .accessibilityGroup(true)
    .id(`hs_history_day_${day.date}`)
  }

  @Builder
  sectionTitle(title: string) {
    Text(title)
      .fontSize($r('sys.float.Subtitle_M'))
      .fontWeight(600)
      .fontColor($r('sys.color.font_primary'))
      .padding({ bottom: 4 })
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Column({ space: 2 }) {
          this.sectionTitle(HISTORY_DAYS_TITLE)
          Text(HISTORY_DAYS_NOTE)
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_secondary'))
            .padding({ bottom: 6 })
          ForEach(simHistoryDays(this.personId), (day: SimHistoryDay) => {
            this.dayRow(day)
          }, (day: SimHistoryDay) => `${this.personId}|${day.date}`)
        }
        .attributeModifier(CARD)
        .id('hs_history_days')

        Column({ space: 6 }) {
          this.sectionTitle(CRF_TITLE)
          if (simCrfRows(this.personId).length === 0) {
            Text(CRF_EMPTY)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_secondary'))
          }
          ForEach(simCrfRows(this.personId), (row: SimCrfRow) => {
            Row({ space: 8 }) {
              Text(row.title)
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_primary'))
                .layoutWeight(1)
              Text(row.text)
                .fontSize($r('sys.float.Body_M'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_primary'))
            }
            .width('100%')
            .constraintSize({ minHeight: 36 })
            .alignItems(VerticalAlign.Center)
            .accessibilityGroup(true)
          }, (row: SimCrfRow) => `${this.personId}|${row.date}`)
        }
        .attributeModifier(CARD)
        .id('hs_history_crf')

        Column({ space: 6 }) {
          this.sectionTitle(HRR_TITLE)
          if (simHrrRows(this.personId).length === 0) {
            Text(HRR_EMPTY)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_secondary'))
          }
          ForEach(simHrrRows(this.personId), (row: SimHrrRow) => {
            Column({ space: 2 }) {
              Row({ space: 8 }) {
                Text(row.title)
                  .fontSize($r('sys.float.Body_M'))
                  .fontColor($r('sys.color.font_primary'))
                  .layoutWeight(1)
                Text(row.drop)
                  .fontSize($r('sys.float.Body_M'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('sys.color.font_primary'))
              }
              .width('100%')
              Text(`${row.detail} · ${row.protocol}`)
                .fontSize($r('sys.float.Body_S'))
                .fontColor($r('sys.color.font_secondary'))
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ top: 4, bottom: 4 })
            .accessibilityGroup(true)
          }, (row: SimHrrRow) => `${this.personId}|${row.date}|${row.protocol}`)
        }
        .attributeModifier(CARD)
        .id('hs_history_hrr')
      }
      .padding({
        left: 16,
        right: 16,
        top: 4,
        bottom: 24
      })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
  }
}
