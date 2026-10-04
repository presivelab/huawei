/**
 * Today tab: steps, heart rate with wear gaps, last night's sleep and night metrics.
 * Everything is computed from the simulated dataset by HsSummary.
 */
import { TodayModel } from '../healthsim/HsSummary';
import { HrLineChart, SleepStagesChart, StepsBarsChart } from './Charts';
import { formatInt, LegendItem, MetricTile, orDash } from './Common';
import { Palette } from '../common/Palette';

@Extend(Column)
function card() {
  .width('100%')
  .padding(16)
  .borderRadius(16)
  .backgroundColor($r('app.color.surface'))
  .alignItems(HorizontalAlign.Start)
}

@Extend(Text)
function cardTitle() {
  .fontSize(15)
  .fontWeight(FontWeight.Medium)
  .fontColor($r('app.color.ink'))
}

@Extend(Text)
function caption() {
  .fontSize(11)
  .fontColor($r('app.color.muted'))
}

@Component
export struct TodayView {
  @Prop model: TodayModel = new TodayModel();
  @Prop personaName: string = '';
  @Prop datasetId: string = '';
  @Prop syncLabel: string = '';

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

  private skinTempText(): string {
    if (!this.model.hasSkinTemp) {
      return '—';
    }
    const v: number = this.model.skinTempDelta;
    return (v > 0 ? '+' : '') + v.toFixed(1);
  }

  @Builder
  header() {
    Column({ space: 4 }) {
      Row({ space: 6 }) {
        Text($r('app.string.today_title', this.model.dateLabel))
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Text(this.weekdayName(this.model.weekday))
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
      }
      Text($r('app.string.sim_now', this.model.timeLabel, this.personaName))
        .fontSize(13)
        .fontColor($r('app.color.muted'))
      Text($r('app.string.data_id', this.datasetId))
        .fontSize(12)
        .fontFamily('monospace')
        .fontColor($r('app.color.accent'))
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .borderRadius(8)
        .backgroundColor($r('app.color.accent_soft'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  stepsCard() {
    Column({ space: 8 }) {
      Text($r('app.string.steps')).cardTitle()
      Text(formatInt(this.model.stepsToday))
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ink'))
      StepsBarsChart({ values: this.model.hourlySteps })
      Row() {
        Text('00').caption()
        Blank()
        Text('06').caption()
        Blank()
        Text('12').caption()
        Blank()
        Text('18').caption()
        Blank()
        Text('24').caption()
      }
      .width('100%')
    }
    .card()
  }

  @Builder
  heartCard() {
    Column({ space: 8 }) {
      Text($r('app.string.hr')).cardTitle()
      Row({ space: 4 }) {
        Text(orDash(this.model.hrLatest, 0))
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor(Palette.HEART)
        Text($r('app.string.bpm')).caption()
      }
      .alignItems(VerticalAlign.Bottom)
      Row({ space: 4 }) {
        Text($r('app.string.hr_range')).caption()
        Text(orDash(this.model.hrMin, 0) + '–' + orDash(this.model.hrMax, 0)).caption()
        Text('·').caption()
        Text($r('app.string.resting_hr')).caption()
        Text(orDash(this.model.restingHr, 0)).caption()
        Text('·').caption()
        Text($r('app.string.resting_avg')).caption()
        Text(orDash(this.model.restingHrAvg7, 0)).caption()
      }
      HrLineChart({ values: this.model.hr24h })
      Row() {
        Text($r('app.string.minus_24h')).caption()
        Blank()
        Text($r('app.string.minus_12h')).caption()
        Blank()
        Text($r('app.string.now')).caption()
      }
      .width('100%')
      Text($r('app.string.hr_gaps')).caption()
      Row({ space: 4 }) {
        Text($r('app.string.hr_coverage')).caption()
        Text(String(this.model.hrCoverageTodayPct) + '%').caption()
      }
    }
    .card()
  }

  @Builder
  sleepCard() {
    Column({ space: 8 }) {
      Text($r('app.string.sleep')).cardTitle()
      if (this.model.sleepSlots.length > 0) {
        Text($r('app.string.duration_hm', Math.floor(this.model.sleepMinutes / 60), this.model.sleepMinutes % 60))
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
        Text(this.model.sleepStartLabel + ' – ' + this.model.sleepEndLabel).caption()
        SleepStagesChart({ stages: this.model.sleepSlots })
        Flex({ wrap: FlexWrap.Wrap }) {
          LegendItem({ color: Palette.DEEP, label: $r('app.string.sleep_deep'), minutes: this.model.deepMinutes })
          LegendItem({ color: Palette.LIGHT, label: $r('app.string.sleep_light'), minutes: this.model.lightMinutes })
          LegendItem({ color: Palette.REM, label: $r('app.string.sleep_rem'), minutes: this.model.remMinutes })
          LegendItem({ color: Palette.AWAKE, label: $r('app.string.sleep_awake'), minutes: this.model.awakeMinutes })
        }
        Text($r('app.string.minutes_unit')).caption()
      } else {
        Text($r('app.string.sleep_none'))
          .fontSize(13)
          .fontColor($r('app.color.muted'))
      }
    }
    .card()
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        this.header()
        this.stepsCard()
        this.heartCard()
        this.sleepCard()
        Row({ space: 12 }) {
          MetricTile({
            title: $r('app.string.spo2'),
            unit: '%',
            detailLabel: $r('app.string.spo2_min'),
            value: orDash(this.model.spo2Avg, 0),
            detailValue: orDash(this.model.spo2Min, 0)
          })
          MetricTile({
            title: $r('app.string.skin_temp'),
            unit: '°C',
            detailLabel: $r('app.string.skin_temp_detail'),
            value: this.skinTempText(),
            detailValue: ''
          })
        }
        .width('100%')
        Row({ space: 12 }) {
          MetricTile({
            title: $r('app.string.stress'),
            unit: '',
            detailLabel: $r('app.string.stress_avg'),
            value: orDash(this.model.stressLatest, 0),
            detailValue: orDash(this.model.stressAvgToday, 0)
          })
          MetricTile({
            title: $r('app.string.vo2'),
            unit: $r('app.string.vo2_unit'),
            detailLabel: $r('app.string.vo2_weekly'),
            value: orDash(this.model.vo2max, 1),
            detailValue: ''
          })
        }
        .width('100%')
        Text($r('app.string.last_sync', this.syncLabel))
          .fontSize(12)
          .fontColor($r('app.color.muted'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 24 })
    }
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .width('100%')
    .height('100%')
  }
}
