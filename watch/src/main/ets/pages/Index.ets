import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { NO_HEART_RATE, STATUS_NOT_PAIRED, STATUS_SYNCED, WatchLinkView, WearState } from 'common';
import { LiveSensors, LiveSnapshot, SensorLink } from '../sensors/LiveSensors';
import { NO_STEPS } from '../model/DaySteps';
import { SlotRing } from '../watchlink/SlotRing';
import { WatchLinkRuntime } from '../watchlink/WatchLinkRuntime';
import { str } from '../ui/Strings';

const DOMAIN = 0x0000;
const TAG = 'FairWear';
const TICK_MS = 1000;
const PERMISSIONS: Permissions[] = ['ohos.permission.READ_HEALTH_DATA', 'ohos.permission.ACTIVITY_MOTION'];
const MISSING: Resource = $r('app.string.watch_missing');
const CLOCK_REAL = 'REAL';
const FEED_FROM_HEALTH_SIM = 'Health Sim';
const ASKING_HEALTH_SIM: Resource = $r('app.string.watch_action_asking_health_sim');

// Whether a sensor has a note to show (no sensor, no permission, error).
function hasLinkNote(link: SensorLink): boolean {
  return link === SensorLink.ABSENT || link === SensorLink.NO_PERMISSION || link === SensorLink.ERROR;
}

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

@Component
struct ValueTile {
  @Prop label: ResourceStr = '';
  @Prop value: ResourceStr = MISSING;
  @Prop valueColor: ResourceColor = $r('sys.color.font_primary');
  @Prop labelColor: ResourceColor = $r('sys.color.font_secondary');

  build() {
    Column({ space: 1 }) {
      Text(this.value)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.valueColor)
        .maxLines(1)
        // A longer value ("not on wrist") shrinks instead of being cut off.
        .maxFontSize($r('app.float.tile_value_font_size'))
        .minFontSize($r('app.float.label_font_size'))
        .width('100%')
        .textAlign(TextAlign.Center)
      Text(this.label)
        .fontSize($r('app.float.label_font_size'))
        .fontColor(this.labelColor)
        .maxLines(1)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }
}

@Component
struct ControlButton {
  @Prop label: ResourceStr = '';
  @Prop labelColor: ResourceColor = $r('sys.color.font_primary');
  // A page with four buttons uses the lower height, so the round screen cuts nothing.
  @Prop compact: boolean = false;
  onTap: () => void = () => {
  };

  build() {
    Button(this.label, { type: ButtonType.Capsule })
      .width('100%')
      .height(this.compact ? 32 : 40)
      .fontSize($r('app.float.button_font_size'))
      // A long label ("Get today from Health Sim") shrinks instead of being cut off.
      .labelStyle({ maxLines: 1, minFontSize: 8, maxFontSize: $r('app.float.button_font_size') })
      .padding({ left: 6, right: 6 })
      .fontColor(this.labelColor)
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .onClick(() => {
        this.onTap();
      })
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
  // Watch Link: what the recorder has for today, and the sync state.
  @State linkReady: boolean = false;
  @State slots: string = '';
  @State openSlot: number = -1;
  @State slotState: string = 'U';
  @State statusLine: string = STATUS_NOT_PAIRED;
  @State demoOn: boolean = false;
  // Demo feed: scripted readings shown in place of the sensor values, always labelled.
  @State feedOn: boolean = false;
  @State feedHr: number = 0;
  @State feedSteps: number = 0;
  // Where the feed script comes from: Health Sim on this watch, or the one built into FairWear.
  @State feedSource: string = '';
  @State clockLabel: string = CLOCK_REAL;
  @State recorderDate: string = '';
  @State recorderMinute: number = 0;
  @State kid: string = '';
  @State pairShown: boolean = false;
  @State lastAction: string = '';
  @State lastAck: string = '';
  @State keyNote: string = '';
  @State wearEngineText: string = '';
  @State linkError: string = '';
  @State resetArmed: boolean = false;
  private sensors: LiveSensors = new LiveSensors();
  private link: WatchLinkRuntime = WatchLinkRuntime.shared();
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
    this.link.attach(this.sensors);
    this.link.init(context).then(() => {
      this.showLink();
    });
    try {
      const result = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context, PERMISSIONS);
      hilog.info(DOMAIN, TAG, 'permissions: %{public}s', JSON.stringify(result.authResults));
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'requestPermissions failed: %{public}s', JSON.stringify(err));
    }
    // A refused permission is not fatal: that sensor fails to subscribe, its value shows a message,
    // and the recorder keeps what is available.
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
        this.link.tick(this.sensors).then(() => {
          this.showLink();
        });
      }, TICK_MS);
    }
  }

  private stopLive(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    this.sensors.stop();
    // The recorder is not fed while the app is hidden: that time stays "not observed".
    this.link.pause();
  }

  private show(view: LiveSnapshot): void {
    this.heartRate = view.heartRate;
    this.steps = view.steps;
    this.wear = view.wear;
    this.heartSensor = view.heartSensor;
    this.stepSensor = view.stepSensor;
  }

  private showLink(): void {
    const view: WatchLinkView = this.link.view();
    this.linkReady = this.link.isReady();
    this.slots = view.slots;
    this.openSlot = view.openSlot;
    this.slotState = view.state;
    this.statusLine = view.statusLine;
    this.demoOn = view.demoClock;
    this.feedOn = view.demoFeed;
    this.feedHr = view.feedHr;
    this.feedSteps = view.stepsToday;
    this.feedSource = this.link.feedSource();
    this.clockLabel = view.clockLabel.length > 0 ? view.clockLabel : CLOCK_REAL;
    this.recorderDate = view.recorderDate;
    this.recorderMinute = view.recorderMinute;
    this.kid = view.kid;
    this.lastAck = view.lastAck;
    this.keyNote = this.link.keyNote;
    this.wearEngineText = this.link.wearEngineStatus();
    this.linkError = this.link.error;
  }

  private heartText(): string {
    if (this.feedOn) {
      return this.feedHr > 0 ? this.feedHr.toString() : str(MISSING);
    }
    return this.heartRate > 0 ? Math.round(this.heartRate).toString() : str(MISSING);
  }

  private heartLabel(): string {
    if (this.feedOn) {
      return str($r('app.string.watch_heart_demo_feed'));
    }
    if (this.heartSensor === SensorLink.ABSENT) {
      return str($r('app.string.watch_heart_no_sensor'));
    }
    if (this.heartSensor === SensorLink.NO_PERMISSION) {
      return str($r('app.string.watch_heart_unavailable'));
    }
    if (this.heartSensor === SensorLink.ERROR) {
      return str($r('app.string.watch_heart_sensor_error'));
    }
    return str($r('app.string.watch_heart_live'));
  }

  private stepsText(): string {
    if (this.feedOn) {
      return this.feedSteps.toString();
    }
    return this.steps >= 0 ? this.steps.toString() : str(MISSING);
  }

  private stepsLabel(): string {
    if (this.feedOn) {
      return str($r('app.string.watch_steps_demo_feed'));
    }
    if (this.stepSensor === SensorLink.ABSENT) {
      return str($r('app.string.watch_steps_no_sensor'));
    }
    if (this.stepSensor === SensorLink.NO_PERMISSION) {
      return str($r('app.string.watch_steps_unavailable'));
    }
    if (this.stepSensor === SensorLink.ERROR) {
      return str($r('app.string.watch_steps_sensor_error'));
    }
    return str($r('app.string.watch_steps_today'));
  }

  // The wear state the recorder uses (60 s without heart rate, 3 s on the demo clock), once it runs.
  // Until then the same rule (WearStateMachine) answers through the live sensors.
  private wearText(): string {
    if (this.linkReady) {
      if (this.slotState === 'W') {
        return str($r('app.string.watch_wear_worn'));
      }
      if (this.slotState === 'C') {
        return str($r('app.string.watch_wear_charging'));
      }
      if (this.slotState === 'O') {
        return str($r('app.string.watch_wear_not_on_wrist'));
      }
      return str($r('app.string.watch_wear_no_data'));
    }
    if (this.wear === WearState.WORN) {
      return str($r('app.string.watch_wear_worn'));
    }
    if (this.wear === WearState.CHARGING) {
      return str($r('app.string.watch_wear_charging'));
    }
    if (this.wear === WearState.REMOVED) {
      return str($r('app.string.watch_wear_not_on_wrist'));
    }
    return str($r('app.string.watch_wear_no_data'));
  }

  private wearColor(): ResourceColor {
    if (this.linkReady) {
      if (this.slotState === 'W') {
        return $r('sys.color.confirm');
      }
      if (this.slotState === 'O') {
        return $r('sys.color.warning');
      }
      return $r('sys.color.font_secondary');
    }
    if (this.wear === WearState.WORN) {
      return $r('sys.color.confirm');
    }
    if (this.wear === WearState.REMOVED) {
      return $r('sys.color.warning');
    }
    return $r('sys.color.font_secondary');
  }

  private noteColor(link: SensorLink): ResourceColor {
    return hasLinkNote(link) ? $r('sys.color.warning') : $r('sys.color.font_secondary');
  }

  private statusColor(): ResourceColor {
    if (this.statusLine === STATUS_SYNCED) {
      return $r('sys.color.confirm');
    }
    if (this.statusLine === STATUS_NOT_PAIRED) {
      return $r('sys.color.font_secondary');
    }
    return $r('sys.color.font_primary');
  }

  private recorderTime(): string {
    return `${pad2(Math.floor(this.recorderMinute / 60))}:${pad2(this.recorderMinute % 60)}`;
  }

  // Shown whenever recorder time is not real time. 'DEMO ×300' while the fast clock runs.
  private demoText(): string {
    if (this.demoOn) {
      if (this.feedOn && this.feedSource === FEED_FROM_HEALTH_SIM) {
        return str($r('app.string.watch_demo_feed_health_sim'), this.recorderTime());
      }
      return this.feedOn ? str($r('app.string.watch_demo_x300_feed'), this.recorderTime()) :
        str($r('app.string.watch_demo_x300'), this.recorderTime());
    }
    return str($r('app.string.watch_demo_time'), this.recorderDate.substring(5), this.recorderTime());
  }

  private toggleDemo(): void {
    const turnOn = !this.demoOn;
    this.link.setDemoClock(turnOn);
    this.lastAction = turnOn ? str($r('app.string.watch_action_demo_clock_on')) :
      str($r('app.string.watch_action_demo_clock_off'));
    this.showLink();
  }

  private toggleFeed(): void {
    const on = this.link.setDemoFeed(!this.feedOn);
    this.lastAction = on ? str($r('app.string.watch_action_demo_feed_on')) :
      str($r('app.string.watch_action_demo_feed_off'));
    this.showLink();
  }

  // Health Sim on this watch hands over the script of the demo day. Without Health Sim the built-in
  // script stays in use and the watch says so.
  private getFromHealthSim(): void {
    if (this.lastAction === str(ASKING_HEALTH_SIM)) {
      return;
    }
    this.lastAction = str(ASKING_HEALTH_SIM);
    this.link.fetchDayScript().then((taken: boolean) => {
      this.lastAction = taken ? str($r('app.string.watch_action_health_sim_used')) :
        str($r('app.string.watch_action_health_sim_missing'));
      this.showLink();
    });
  }

  private closeDay(): void {
    // A second tap while the first is still sealing would seal an empty next day.
    if (this.lastAction === str($r('app.string.watch_action_closing_day'))) {
      return;
    }
    this.lastAction = str($r('app.string.watch_action_closing_day'));
    this.link.closeDay().then((seq: number) => {
      if (seq > 0) {
        this.lastAction = str($r('app.string.watch_action_day_closed'), seq);
      } else if (seq === 0) {
        this.lastAction = str($r('app.string.watch_action_nothing_recorded'));
      } else {
        this.lastAction = str($r('app.string.watch_action_close_day_failed'));
      }
      this.showLink();
    });
  }

  private pairPhone(): void {
    this.link.pair().then((code: string) => {
      this.pairShown = code.length > 0;
      this.lastAction = code.length > 0 ? str($r('app.string.watch_action_pairing_ready')) :
        str($r('app.string.watch_action_pairing_failed'));
      this.showLink();
    });
  }

  private resetData(): void {
    if (!this.resetArmed) {
      this.resetArmed = true;
      return;
    }
    this.resetArmed = false;
    this.pairShown = false;
    this.link.reset();
    this.lastAction = str($r('app.string.watch_action_data_reset'));
    this.showLink();
  }

  @Builder
  DialPage() {
    Stack() {
      // Today as 288 five-minute slots. The wear state is always written out as text as well.
      SlotRing({ slots: this.slots, openSlot: this.openSlot })

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
          Text($r('app.string.watch_bpm'))
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
            label: $r('app.string.watch_wear_state'),
            value: this.wearText(),
            valueColor: this.wearColor()
          })
        }
        .width(188)
        .margin({ top: 2 })

        Text(this.statusLine)
          .fontSize($r('app.float.label_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.statusColor())
          .maxLines(1)
          .margin({ top: 7 })

        if (this.clockLabel !== CLOCK_REAL) {
          Text(this.demoText())
            .fontSize($r('app.float.note_font_size'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.warning'))
            .maxLines(1)
            .margin({ top: 2 })
        }

        Text($r('app.string.watch_dial_footer'))
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('sys.color.font_tertiary'))
          .textAlign(TextAlign.Center)
          .margin({ top: 5 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
  }

  // Two short pages instead of one scrolling list: on a watch a swipe to the right leaves the app,
  // so the pages are stacked vertically and none of them scrolls.
  @Builder
  DemoPage() {
    Column({ space: 7 }) {
      if (!this.demoOn) {
        // On the demo clock the page has four buttons and no room for its title.
        Text($r('app.string.watch_link_title'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
      }
      Text(this.statusLine)
        .fontSize($r('app.float.label_font_size'))
        .fontColor(this.statusColor())

      ControlButton({
        label: $r('app.string.watch_button_close_day'),
        compact: this.demoOn,
        onTap: () => {
          this.closeDay();
        }
      })
      ControlButton({
        label: $r('app.string.watch_button_demo_clock'),
        labelColor: this.demoOn ? $r('sys.color.warning') : $r('sys.color.font_primary'),
        compact: this.demoOn,
        onTap: () => {
          this.toggleDemo();
        }
      })
      if (this.demoOn) {
        // The script of the demo day from Health Sim on this watch; the dial then reads "FEED · Health Sim".
        ControlButton({
          label: $r('app.string.watch_button_get_from_health_sim'),
          labelColor: this.feedSource === FEED_FROM_HEALTH_SIM ? $r('sys.color.warning') :
          $r('sys.color.font_primary'),
          compact: true,
          onTap: () => {
            this.getFromHealthSim();
          }
        })
        // Only offered on the demo clock. The dial then reads "DEMO ×300 · FEED".
        ControlButton({
          label: this.feedOn ? $r('app.string.watch_button_demo_feed_on') : $r('app.string.watch_button_demo_feed_off'),
          labelColor: this.feedOn ? $r('sys.color.warning') : $r('sys.color.font_primary'),
          compact: true,
          onTap: () => {
            this.toggleFeed();
          }
        })
      }
      if (this.lastAction.length > 0) {
        Text(this.lastAction)
          .fontSize($r('app.float.note_font_size'))
          .fontColor($r('sys.color.font_primary'))
          .textAlign(TextAlign.Center)
          .maxLines(2)
      }
      if (this.lastAck.length > 0) {
        Text(str($r('app.string.watch_phone_ack'), this.lastAck))
          .fontSize($r('app.float.note_font_size'))
          .fontColor($r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
          .maxLines(2)
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    // Round screen: nothing in the corners.
    .padding({ left: 46, right: 46 })
  }

  @Builder
  PhonePage() {
    Column({ space: 6 }) {
      ControlButton({
        label: $r('app.string.watch_button_pair_phone'),
        onTap: () => {
          this.pairPhone();
        }
      })
      if (this.pairShown) {
        Text(this.kid)
          .fontSize($r('app.float.code_font_size'))
          .fontWeight(FontWeight.Bold)
          .fontFamily('monospace')
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
        Text($r('app.string.watch_confirm_code'))
          .fontSize($r('app.float.note_font_size'))
          .fontColor($r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
      }
      ControlButton({
        label: this.resetArmed ? $r('app.string.watch_button_reset_again') : $r('app.string.watch_button_reset'),
        labelColor: $r('sys.color.warning'),
        onTap: () => {
          this.resetData();
        }
      })
      if (this.keyNote.length > 0 && !this.pairShown) {
        Text(this.keyNote)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('sys.color.font_tertiary'))
          .textAlign(TextAlign.Center)
          .maxLines(2)
      }
      if (this.wearEngineText.length > 0 && !this.pairShown) {
        Text(this.wearEngineText)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('sys.color.font_tertiary'))
          .textAlign(TextAlign.Center)
          .maxLines(2)
      }
      if (this.linkError.length > 0) {
        Text(this.linkError)
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('sys.color.warning'))
          .textAlign(TextAlign.Center)
          .maxLines(2)
      }
      Text($r('app.string.watch_records_note'))
        .fontSize($r('app.float.caption_font_size'))
        .fontColor($r('sys.color.font_tertiary'))
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 46, right: 46 })
  }

  build() {
    Swiper() {
      this.DialPage()
      this.DemoPage()
      this.PhonePage()
    }
    .vertical(true)
    .loop(false)
    .indicator(false)
    .width('100%')
    .height('100%')
  }
}
