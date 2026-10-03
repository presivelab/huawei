import { HeartChart } from './HeartChart';
import {
  CARD_FILL,
  HAIRLINE,
  HEART_BACKGROUND,
  HEART_COLOR,
  NO_VALUE,
  TEXT_FAINT,
  TEXT_SECONDARY,
  WORN_COLOR
} from './Theme';

const CARD_RADIUS = 20;

function bpm(value: number): string {
  return value > 0 ? value.toString() : NO_VALUE;
}

@Component
struct WearTag {
  @Prop worn: boolean = false;

  build() {
    Row({ space: 5 }) {
      Circle()
        .width(6)
        .height(6)
        .fill(this.worn ? WORN_COLOR : TEXT_FAINT)
      Text(this.worn ? 'On wrist' : 'Off wrist')
        .fontSize(11)
        .fontColor(TEXT_SECONDARY)
    }
  }
}

@Component
struct Extreme {
  @Prop icon: Resource = $r('sys.symbol.arrowtriangle_up_fill');
  @Prop color: string = '#FFFFFF';
  @Prop value: number = 0;

  build() {
    Row({ space: 4 }) {
      SymbolGlyph(this.icon)
        .fontSize(12)
        .fontColor([this.color])
      Text(bpm(this.value))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
    }
  }
}

@Component
struct CardStat {
  @Prop label: string = '';
  @Prop value: string = NO_VALUE;
  @Prop unit: string = '';

  build() {
    Column({ space: 2 }) {
      Text() {
        Span(this.value)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
        Span(this.unit.length > 0 ? ` ${this.unit}` : '')
          .fontSize(11)
      }
      .fontColor(Color.White)
      .maxLines(1)
      Text(this.label)
        .fontSize(11)
        .fontColor(TEXT_SECONDARY)
    }
    .width(78)
  }
}

@Component
export struct HeartPage {
  @StorageProp('hd_hr') heartRate: number = 0;
  @StorageProp('hd_hour_min') low: number = 0;
  @StorageProp('hd_hour_max') high: number = 0;
  @StorageProp('hd_worn') worn: boolean = false;
  @StorageProp('hd_tick') @Watch('beat') tick: number = 0;
  @State pulse: number = 1;

  beat(): void {
    this.pulse = this.heartRate > 0 && this.tick % 2 === 0 ? 1.15 : 1;
  }

  build() {
    Column() {
      WearTag({ worn: this.worn })
        .margin({ top: 19 })
      Row({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.heart_fill'))
          .fontSize(26)
          .fontColor([HEART_COLOR])
          .scale({ x: this.pulse, y: this.pulse })
          .animation({ duration: 280, curve: Curve.EaseOut })
        Text() {
          Span(bpm(this.heartRate))
            .fontSize(42)
            .fontWeight(FontWeight.Bold)
          Span(' bpm')
            .fontSize(14)
        }
        .fontColor(Color.White)
      }
      .height(50)
      Stack() {
        HeartChart({ tick: this.tick })
      }
      .width('100%')
      .height(88)
      .backgroundColor(CARD_FILL)
      .borderRadius(CARD_RADIUS)
      Row({ space: 22 }) {
        Extreme({ icon: $r('sys.symbol.arrowtriangle_up_fill'), color: HEART_COLOR, value: this.high })
        Extreme({ icon: $r('sys.symbol.arrowtriangle_down_fill'), color: TEXT_SECONDARY, value: this.low })
      }
      .margin({ top: 5 })
    }
    .width('100%')
    .height('100%')
    .linearGradient({ direction: GradientDirection.Bottom, colors: HEART_BACKGROUND })
  }
}

@Component
export struct RestingPage {
  @StorageProp('hd_resting') resting: number = 0;
  @StorageProp('hd_hr_min') low: number = 0;
  @StorageProp('hd_hr_max') high: number = 0;
  @StorageProp('hd_hr_minutes') minutes: number = 0;

  build() {
    Column() {
      Text('Resting heart rate')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .margin({ top: 30 })
      Text() {
        Span('Today ')
          .fontSize(13)
          .fontColor(TEXT_SECONDARY)
        Span(bpm(this.resting))
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
        Span(' bpm')
          .fontSize(13)
          .fontColor(TEXT_SECONDARY)
      }
      .fontColor(Color.White)
      .margin({ top: 4, bottom: 8 })
      Row() {
        CardStat({ label: 'Range today', value: this.high > 0 ? `${this.low}–${this.high}` : NO_VALUE })
        Divider()
          .vertical(true)
          .height(34)
          .strokeWidth(1)
          .color(HAIRLINE)
          .margin({ left: 6, right: 6 })
        CardStat({ label: 'Measured', value: this.minutes > 0 ? this.minutes.toString() : NO_VALUE, unit: 'min' })
      }
      .width('100%')
      .height(72)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(CARD_FILL)
      .borderRadius(CARD_RADIUS)
      Text('Lowest minute at rest')
        .fontSize(11)
        .fontColor(TEXT_SECONDARY)
        .margin({ top: 9 })
    }
    .width('100%')
    .height('100%')
    .linearGradient({ direction: GradientDirection.Bottom, colors: HEART_BACKGROUND })
  }
}
