import {
  DEMO_CLOSE_DAY,
  DEMO_HR_LABEL,
  DEMO_NOTE,
  DEMO_RESET,
  DEMO_STEPS_LABEL,
  DEMO_TITLE,
  LIVE_CHIP,
  LIVE_NOTE,
  LIVE_TITLE,
  liveText,
  NO_READING
} from '../report/ReportTexts';
import { InfoChip } from '../ui/kit/InfoChip';
import {
  COLOR_HEART,
  COLOR_NOTE_TEXT,
  COLOR_NOTE_TINT,
  COLOR_STEPS,
  SYMBOL_HEART,
  SYMBOL_STEPS
} from '../ui/kit/KitTokens';
import { VALUE_TILE, ValueWithUnit } from '../ui/kit/ValueWithUnit';
import { demoCloseDay, demoReset, demoSetLive } from './DemoActions';
import { CAPTION, CARD_LARGE, HEADING } from './Styles';

const CARD_GAP: number = 14;
const HR_MIN: number = 40;
const HR_MAX: number = 200;
const STEPS_MAX: number = 20000;
const STEPS_STEP: number = 250;

// The live readings of the running day and the controls that drive the demo: two sliders for the
// readings, "Close the day" and "Reset demo". The readings are demo values and are labelled so; moving
// them never changes the score. Only closing the day does.
@Component
export struct DemoLiveCard {
  @Prop @Watch('onReadings') hr: number = -1;       // bpm; below zero: no reading
  @Prop @Watch('onReadings') steps: number = -1;    // since midnight; below zero: no reading
  @Prop @Watch('onReadings') personaId: string = '';
  @State hrDraft: number = -1;
  @State stepsDraft: number = -1;

  aboutToAppear(): void {
    this.onReadings();
  }

  // New readings from the report (another persona, a closed day, a reset): the sliders follow.
  onReadings(): void {
    this.hrDraft = this.hr;
    this.stepsDraft = this.steps;
  }

  private apply(): void {
    demoSetLive(this.hrDraft, this.stepsDraft);
  }

  @Builder
  liveCard() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(LIVE_TITLE)
          .attributeModifier(HEADING)
          .layoutWeight(1)
        InfoChip({
          text: LIVE_CHIP,
          fill: COLOR_NOTE_TINT,
          textColor: COLOR_NOTE_TEXT,
          strong: true
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 24 }) {
        Row({ space: 6 }) {
          SymbolGlyph(SYMBOL_HEART)
            .fontSize(20)
            .fontColor([COLOR_HEART])
          ValueWithUnit({ value: liveText(this.hr), unit: 'bpm now', level: VALUE_TILE })
        }
        .alignItems(VerticalAlign.Center)
        .id('fw_live_hr')
        .accessibilityGroup(true)
        .accessibilityText(this.hr < 0 ? 'Heart rate now, no reading' :
          `Heart rate now, ${this.hr} beats per minute`)

        Row({ space: 6 }) {
          SymbolGlyph(SYMBOL_STEPS)
            .fontSize(20)
            .fontColor([COLOR_STEPS])
          ValueWithUnit({ value: liveText(this.steps), unit: 'steps today', level: VALUE_TILE })
        }
        .alignItems(VerticalAlign.Center)
        .id('fw_live_steps')
        .accessibilityGroup(true)
        .accessibilityText(this.steps < 0 ? 'Steps today, no reading' : `${this.steps} steps today`)
      }
      .width('100%')

      Text(LIVE_NOTE)
        .attributeModifier(CAPTION)
    }
    .attributeModifier(CARD_LARGE)
  }

  @Builder
  controlsCard() {
    Column({ space: 12 }) {
      Text(DEMO_TITLE)
        .attributeModifier(HEADING)

      Column({ space: 2 }) {
        Row({ space: 8 }) {
          Text(DEMO_HR_LABEL)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_primary'))
            .layoutWeight(1)
          Text(this.hrDraft < 0 ? NO_READING : `${this.hrDraft} bpm`)
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        Slider({
          value: Math.max(HR_MIN, this.hrDraft),
          min: HR_MIN,
          max: HR_MAX,
          step: 1,
          style: SliderStyle.OutSet
        })
          .selectedColor(COLOR_HEART)
          .width('100%')
          .id('fw_demo_hr')
          .accessibilityText(DEMO_HR_LABEL)
          .onChange((value: number, mode: SliderChangeMode) => {
            this.hrDraft = Math.round(value);
            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
              this.apply();
            }
          })
      }
      .width('100%')

      Column({ space: 2 }) {
        Row({ space: 8 }) {
          Text(DEMO_STEPS_LABEL)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_primary'))
            .layoutWeight(1)
          Text(liveText(this.stepsDraft))
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        Slider({
          value: Math.max(0, this.stepsDraft),
          min: 0,
          max: STEPS_MAX,
          step: STEPS_STEP,
          style: SliderStyle.OutSet
        })
          .selectedColor(COLOR_STEPS)
          .width('100%')
          .id('fw_demo_steps')
          .accessibilityText(DEMO_STEPS_LABEL)
          .onChange((value: number, mode: SliderChangeMode) => {
            this.stepsDraft = Math.round(value);
            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
              this.apply();
            }
          })
      }
      .width('100%')

      Row({ space: 12 }) {
        Button(DEMO_CLOSE_DAY)
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .layoutWeight(1)
          .height(44)
          .id('fw_demo_close_day')
          .onClick(() => {
            demoCloseDay();
          })
        Button(DEMO_RESET)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .layoutWeight(1)
          .height(44)
          .id('fw_demo_reset')
          .onClick(() => {
            demoReset();
          })
      }
      .width('100%')

      Text(DEMO_NOTE)
        .attributeModifier(CAPTION)
    }
    .attributeModifier(CARD_LARGE)
  }

  build() {
    Column({ space: CARD_GAP }) {
      this.liveCard()
      this.controlsCard()
    }
    .width('100%')
  }
}
