import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { WearState, NO_HEART_RATE } from 'common';
import { LiveSensors, LiveSnapshot, SensorLink } from '../sensors/LiveSensors';
import { NO_STEPS } from '../model/DaySteps';

const DOMAIN = 0x0000;
const TAG = 'FairWear';
const TICK_MS = 1000;
const PERMISSIONS: Permissions[] = ['ohos.permission.READ_HEALTH_DATA', 'ohos.permission.ACTIVITY_MOTION'];
const MISSING = '—';

function linkNote(link: SensorLink): string {
  if (link === SensorLink.ABSENT) {
    return 'no sensor';
  }
  if (link === SensorLink.NO_PERMISSION) {
    return 'no permission';
  }
  if (link === SensorLink.ERROR) {
    return 'sensor error';
  }
  return '';
}

@Component
struct ValueTile {
  @Prop label: string = '';
  @Prop value: string = MISSING;
  @Prop valueColor: ResourceColor = $r('sys.color.font_primary');
  @Prop labelColor: ResourceColor = $r('sys.color.font_secondary');

  build() {
    Column({ space: 1 }) {
      Text(this.value)
        .fontSize($r('app.float.tile_value_font_size'))
        .fontWeight(FontWeight.Medium)
        .fontColor(this.valueColor)
        .maxLines(1)
      Text(this.label)
        .fontSize($r('app.float.label_font_size'))
        .fontColor(this.labelColor)
        .maxLines(1)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }
}

@Entry
@Component
struct Index {
  @State heartRate: number = NO_HEART_RATE;
  @State steps: number = NO_STEPS;
  @State wear: WearState = WearState.NO_DATA;
  @State heartSensor: SensorLink = SensorLink.WAITING;
  @State stepSensor: SensorLink = SensorLink.WAITING;
  private sensors: LiveSensors = new LiveSensors();
  private timer: number = -1;
  private permissionsAsked: boolean = false;
  private visible: boolean = false;

  aboutToAppear(): void {
    this.askPermissions();
  }

  onPageShow(): void {
    this.visible = true;
    this.startIfReady();
  }

  onPageHide(): void {
    this.visible = false;
    this.stopLive();
  }

  aboutToDisappear(): void {
    this.stopLive();
  }

  private async askPermissions(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.sensors.init(context);
    try {
      const result = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context, PERMISSIONS);
      hilog.info(DOMAIN, TAG, 'permissions: %{public}s', JSON.stringify(result.authResults));
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'requestPermissions failed: %{public}s', JSON.stringify(err));
    }
    // A refused permission is not fatal: that sensor fails to subscribe and its value shows a message.
    this.permissionsAsked = true;
    this.startIfReady();
  }

  private startIfReady(): void {
    if (!this.permissionsAsked || !this.visible) {
      return;
    }
    this.sensors.start();
    this.show(this.sensors.snapshot());
    if (this.timer < 0) {
      this.timer = setInterval(() => {
        this.show(this.sensors.tick(Date.now()));
      }, TICK_MS);
    }
  }

  private stopLive(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    this.sensors.stop();
  }

  private show(view: LiveSnapshot): void {
    this.heartRate = view.heartRate;
    this.steps = view.steps;
    this.wear = view.wear;
    this.heartSensor = view.heartSensor;
    this.stepSensor = view.stepSensor;
  }

  private heartText(): string {
    return this.heartRate > 0 ? Math.round(this.heartRate).toString() : MISSING;
  }

  private heartLabel(): string {
    const note = linkNote(this.heartSensor);
    return note.length > 0 ? `Heart rate · ${note}` : 'Heart rate · live';
  }

  private stepsText(): string {
    return this.steps >= 0 ? this.steps.toString() : MISSING;
  }

  private stepsLabel(): string {
    const note = linkNote(this.stepSensor);
    return note.length > 0 ? `Steps · ${note}` : 'Steps today';
  }

  private wearText(): string {
    if (this.wear === WearState.WORN) {
      return 'worn';
    }
    if (this.wear === WearState.REMOVED) {
      return 'removed';
    }
    return 'no data';
  }

  private wearColor(): ResourceColor {
    if (this.wear === WearState.WORN) {
      return $r('sys.color.confirm');
    }
    if (this.wear === WearState.REMOVED) {
      return $r('sys.color.warning');
    }
    return $r('sys.color.font_secondary');
  }

  private noteColor(link: SensorLink): ResourceColor {
    return linkNote(link).length > 0 ? $r('sys.color.warning') : $r('sys.color.font_secondary');
  }

  build() {
    Stack() {
      // Thin ring in the colour of the wear state; the state is always written out as text as well.
      Circle()
        .width('95%')
        .height('95%')
        .fill(Color.Transparent)
        .stroke(this.wearColor())
        .strokeWidth(2)
        .opacity(this.wear === WearState.NO_DATA ? 0.35 : 1)

      Column() {
        Text(this.heartLabel())
          .fontSize($r('app.float.label_font_size'))
          .fontColor(this.noteColor(this.heartSensor))
          .maxLines(1)

        Row({ space: 4 }) {
          Text(this.heartText())
            .fontSize($r('app.float.heart_font_size'))
            .fontWeight(this.heartRate > 0 ? FontWeight.Bold : FontWeight.Lighter)
            .fontColor(this.heartRate > 0 ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
            .maxLines(1)
          Text('bpm')
            .fontSize($r('app.float.unit_font_size'))
            .fontColor($r('sys.color.font_secondary'))
            .margin({ bottom: this.heartRate > 0 ? 9 : 0 })
        }
        .alignItems(this.heartRate > 0 ? VerticalAlign.Bottom : VerticalAlign.Center)

        Row() {
          ValueTile({
            label: this.stepsLabel(),
            value: this.stepsText(),
            labelColor: this.noteColor(this.stepSensor)
          })
          Divider()
            .vertical(true)
            .height(26)
            .color($r('sys.color.comp_divider'))
          ValueTile({
            label: 'Wear state',
            value: this.wearText(),
            valueColor: this.wearColor()
          })
        }
        .width(176)
        .margin({ top: 2 })

        Text('Live from FairWear on your watch.\nNot part of the score\nuntil the day closes.')
          .fontSize($r('app.float.note_font_size'))
          .fontColor($r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
          .margin({ top: 7 })

        Text('FairWear · add-on for\nHUAWEI Health · DEMO')
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('sys.color.font_tertiary'))
          .textAlign(TextAlign.Center)
          .margin({ top: 6 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
  }
}
