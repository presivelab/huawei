import { EXERCISE_GOAL_MIN, MOVE_GOAL_KCAL, STAND_GOAL_HOURS, UNKNOWN } from '../model/HealthEngine';
import { ActivityRings } from './ActivityRings';
import { GoalArc } from './GoalArc';
import {
  ACTIVITY_BACKGROUND,
  EXERCISE_COLOR,
  EXERCISE_TRACK,
  MOVE_COLOR,
  MOVE_TRACK,
  NO_VALUE,
  RINGS_BACKGROUND,
  share,
  shown,
  STAND_COLOR,
  STAND_TRACK,
  STEPS_COLOR,
  TEXT_SECONDARY
} from './Theme';

const ROW_WIDTH = 150;
const ROW_ICON = 40;

@Component
struct RingNumber {
  @Prop value: number = UNKNOWN;
  @Prop color: string = '#FFFFFF';

  build() {
    Text(shown(this.value))
      .fontSize(26)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.color)
      .lineHeight(29)
      .height(29)
  }
}

@Component
struct PageTitle {
  @Prop text: string = '';

  build() {
    Text(this.text)
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .fontColor(Color.White)
      .margin({ top: 26, bottom: 4 })
  }
}

@Component
struct GoalRow {
  @Prop icon: Resource = $r('sys.symbol.flame_fill');
  @Prop label: string = '';
  @Prop value: number = UNKNOWN;
  @Prop goal: number = 1;
  @Prop unit: string = '';
  @Prop color: string = '#FFFFFF';
  @Prop track: string = '#333333';

  build() {
    Row({ space: 9 }) {
      GoalArc({
        value: share(this.value, this.goal),
        color: this.color,
        track: this.track,
        icon: this.icon,
        diameter: ROW_ICON
      })
      Column() {
        Text(this.label)
          .fontSize(12)
          .fontColor(TEXT_SECONDARY)
        Text() {
          Span(shown(this.value))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.color)
          Span(` /${this.goal} ${this.unit}`)
            .fontSize(11)
            .fontColor(Color.White)
        }
        .maxLines(1)
      }
      .alignItems(HorizontalAlign.Start)
    }
    .width(ROW_WIDTH)
    .height(48)
  }
}

@Component
struct ValueRow {
  @Prop icon: Resource = $r('sys.symbol.steps_fill');
  @Prop label: string = '';
  @Prop value: string = NO_VALUE;
  @Prop unit: string = '';

  build() {
    Row({ space: 9 }) {
      SymbolGlyph(this.icon)
        .fontSize(26)
        .fontColor([STEPS_COLOR])
        .width(ROW_ICON)
      Column() {
        Text(this.label)
          .fontSize(12)
          .fontColor(TEXT_SECONDARY)
        Text() {
          Span(this.value)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Span(` ${this.unit}`)
            .fontSize(11)
            .fontColor(Color.White)
        }
        .maxLines(1)
      }
      .alignItems(HorizontalAlign.Start)
    }
    .width(ROW_WIDTH)
    .height(56)
  }
}

@Component
export struct RingsPage {
  @StorageProp('hd_kcal') kcal: number = UNKNOWN;
  @StorageProp('hd_exercise') exercise: number = UNKNOWN;
  @StorageProp('hd_stand') stand: number = UNKNOWN;

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      ActivityRings({
        move: share(this.kcal, MOVE_GOAL_KCAL),
        exercise: share(this.exercise, EXERCISE_GOAL_MIN),
        stand: share(this.stand, STAND_GOAL_HOURS)
      })
      Column() {
        RingNumber({ value: this.stand, color: STAND_COLOR })
        RingNumber({ value: this.exercise, color: EXERCISE_COLOR })
        RingNumber({ value: this.kcal, color: MOVE_COLOR })
      }
      .margin({ bottom: 4 })
    }
    .width('100%')
    .height('100%')
    .linearGradient({ direction: GradientDirection.Bottom, colors: RINGS_BACKGROUND })
  }
}

@Component
export struct TodayGoalsPage {
  @StorageProp('hd_kcal') kcal: number = UNKNOWN;
  @StorageProp('hd_exercise') exercise: number = UNKNOWN;
  @StorageProp('hd_stand') stand: number = UNKNOWN;

  build() {
    Column({ space: 5 }) {
      PageTitle({ text: 'Today' })
      GoalRow({
        icon: $r('sys.symbol.flame_fill'),
        label: 'Move',
        value: this.kcal,
        goal: MOVE_GOAL_KCAL,
        unit: 'kcal',
        color: MOVE_COLOR,
        track: MOVE_TRACK
      })
      GoalRow({
        icon: $r('sys.symbol.figure_run'),
        label: 'Exercise',
        value: this.exercise,
        goal: EXERCISE_GOAL_MIN,
        unit: 'min',
        color: EXERCISE_COLOR,
        track: EXERCISE_TRACK
      })
      GoalRow({
        icon: $r('sys.symbol.figure_arms_open'),
        label: 'Stand',
        value: this.stand,
        goal: STAND_GOAL_HOURS,
        unit: 'h',
        color: STAND_COLOR,
        track: STAND_TRACK
      })
    }
    .width('100%')
    .height('100%')
    .linearGradient({ direction: GradientDirection.Bottom, colors: ACTIVITY_BACKGROUND })
  }
}

@Component
export struct TodayStepsPage {
  @StorageProp('hd_steps') steps: number = UNKNOWN;
  @StorageProp('hd_meters') meters: number = UNKNOWN;

  build() {
    Column({ space: 5 }) {
      PageTitle({ text: 'Today' })
      ValueRow({
        icon: $r('sys.symbol.steps_fill'),
        label: 'Steps',
        value: shown(this.steps),
        unit: 'steps'
      })
        .margin({ top: 14 })
      ValueRow({
        icon: $r('sys.symbol.distance_fill'),
        label: 'Distance',
        value: this.meters === UNKNOWN ? NO_VALUE : (this.meters / 1000).toFixed(2),
        unit: 'km'
      })
    }
    .width('100%')
    .height('100%')
    .linearGradient({ direction: GradientDirection.Bottom, colors: ACTIVITY_BACKGROUND })
  }
}
