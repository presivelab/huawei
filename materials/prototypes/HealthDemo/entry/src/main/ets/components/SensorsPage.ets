import { ArcList, ArcListItem, ComponentContent, LengthMetrics } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { sensor } from '@kit.SensorServiceKit';
import {
  BackgroundSnapshot,
  PROBE_ABSENT,
  PROBE_SUBSCRIBED,
  ProbeSnapshot,
  SensorInfo,
  StepSnapshot,
  UNKNOWN,
  WEAR_SOURCE_HR
} from '../model/HealthEngine';
import { AWAKE_OFF, ScreenAwake } from '../model/ScreenAwake';
import { grouped, NO_VALUE, shown, SYSTEM_BACKGROUND, TEXT_SECONDARY, WORN_COLOR } from './Theme';

// The list takes focus through its one focusable control; a request on the list itself is refused.
export const SENSOR_FOCUS_ID = 'keep_screen_on';

const ROW_WIDTH = 200;
const ROW_FILL = '#24FFFFFF';
const ROW_RADIUS = 26;
const WARNING_COLOR = '#FFB340';
const TITLE_HEIGHT = 56;
// Where the list header rests when the list is at its top, so the title does not jump when the list opens.
const COVER_TITLE_TOP = 20;
// Pulling the list this far down from its top (vp) goes back to the previous page.
const LEAVE_PULL = 36;

function seconds(milliseconds: number): string {
  return milliseconds === UNKNOWN ? NO_VALUE : `${(milliseconds / 1000).toFixed(1)} s`;
}

function probeColor(probe: ProbeSnapshot): string {
  if (probe.status === PROBE_SUBSCRIBED) {
    return WORN_COLOR;
  }
  return probe.status === PROBE_ABSENT ? TEXT_SECONDARY : WARNING_COLOR;
}

function probeState(probe: ProbeSnapshot): string {
  return `${probe.present ? 'Present' : 'Not listed'} · ${probe.status}`;
}

function probeDetail(probe: ProbeSnapshot, unit: string): string {
  if (!probe.hasValue) {
    return 'no event yet';
  }
  return `last ${probe.value}${unit} · ${probe.eventsPerSecond.toFixed(1)} ev/s\n` +
    `${probe.secondsSinceEvent} s ago · ${grouped(probe.events)} events`;
}

@Builder
function sensorsTitle() {
  Text('Sensors')
    .fontSize(18)
    .fontWeight(FontWeight.Bold)
    .fontColor(Color.White)
    .textAlign(TextAlign.Center)
    .width('100%')
    .height(TITLE_HEIGHT)
    .padding({ top: 22 })
}

@Component
struct InfoRow {
  @Prop label: string = '';
  @Prop value: string = NO_VALUE;
  @Prop detail: string = '';
  @Prop color: string = '#FFFFFF';

  build() {
    Column({ space: 1 }) {
      Text(this.label)
        .fontSize(11)
        .fontColor(TEXT_SECONDARY)
      Text(this.value)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.color)
        .textAlign(TextAlign.Center)
        .maxLines(2)
      if (this.detail.length > 0) {
        Text(this.detail)
          .fontSize(11)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
      }
    }
    .width(ROW_WIDTH)
    .padding({ top: 9, bottom: 9, left: 16, right: 16 })
    .backgroundColor(ROW_FILL)
    .borderRadius(ROW_RADIUS)
  }
}

// What the pager shows while it slides to the last page; the list itself is laid over it.
@Component
export struct SensorsCover {
  build() {
    Column() {
      sensorsTitle()
    }
    .width('100%')
    .height('100%')
    .padding({ top: COVER_TITLE_TOP })
    .linearGradient({ direction: GradientDirection.Bottom, colors: SYSTEM_BACKGROUND })
  }
}

// Lives outside the pager: a pager page cannot take focus, and the crown scrolls whatever has focus.
@Component
export struct SensorsPage {
  @StorageProp('hd_probe_hr') heart: ProbeSnapshot = new ProbeSnapshot();
  @StorageProp('hd_probe_steps') steps: ProbeSnapshot = new ProbeSnapshot();
  @StorageProp('hd_probe_wear') wear: ProbeSnapshot = new ProbeSnapshot();
  @StorageProp('hd_step_counter') counter: StepSnapshot = new StepSnapshot();
  @StorageProp('hd_steps') today: number = UNKNOWN;
  @StorageProp('hd_background') away: BackgroundSnapshot = new BackgroundSnapshot();
  @StorageProp('hd_worn') worn: boolean = false;
  @StorageProp('hd_wear_source') wearSource: string = WEAR_SOURCE_HR;
  @StorageProp('hd_sensors') sensors: SensorInfo[] = [];
  @StorageProp('hd_keep_on') keepOn: boolean = true;
  @StorageProp('hd_keep_on_state') keepOnState: string = AWAKE_OFF;
  leave: () => void = () => {
  };
  private scroller: Scroller = new Scroller();
  private title: ComponentContent<Object> | undefined = undefined;
  private pull: number = 0;
  private left: boolean = false;

  aboutToAppear(): void {
    this.title = new ComponentContent(this.getUIContext(), wrapBuilder(sensorsTitle));
  }

  private onPull(offset: number, source: ScrollSource): void {
    if (this.left || offset >= 0 || source === ScrollSource.FLING || source === ScrollSource.EDGE_EFFECT ||
      this.scroller.currentOffset().yOffset > 0) {
      this.pull = offset > 0 ? 0 : this.pull;
      return;
    }
    this.pull -= offset;
    if (this.pull >= LEAVE_PULL) {
      this.left = true;
      this.leave();
    }
  }

  build() {
    ArcList({ initialIndex: 0, scroller: this.scroller, header: this.title }) {
      ArcListItem() {
        InfoRow({ label: 'Device', value: deviceInfo.marketName, detail: deviceInfo.productModel })
      }

      ArcListItem() {
        InfoRow({
          label: 'System',
          value: `${deviceInfo.distributionOSName} ${deviceInfo.distributionOSVersion}`,
          detail: `API ${deviceInfo.sdkApiVersion}`
        })
      }

      ArcListItem() {
        InfoRow({ label: 'Build', value: deviceInfo.osFullName, detail: deviceInfo.displayVersion })
      }

      ArcListItem() {
        InfoRow({
          label: 'Wear state',
          value: this.worn ? 'On wrist' : 'Off wrist',
          detail: `source ${this.wearSource}`,
          color: this.worn ? WORN_COLOR : '#FFFFFF'
        })
      }

      ArcListItem() {
        InfoRow({
          label: `Heart rate · id ${sensor.SensorId.HEART_RATE}`,
          value: probeState(this.heart),
          detail: probeDetail(this.heart, ' bpm'),
          color: probeColor(this.heart)
        })
      }

      ArcListItem() {
        InfoRow({
          label: `Step counter · id ${sensor.SensorId.PEDOMETER}`,
          value: probeState(this.steps),
          detail: probeDetail(this.steps, ''),
          color: probeColor(this.steps)
        })
      }

      ArcListItem() {
        InfoRow({
          label: 'Steps today',
          value: shown(this.today),
          detail: `raw ${shown(this.counter.raw)} − base ${shown(this.counter.baseline)}\n` +
            `kept after restart ${grouped(this.counter.carried)}`
        })
      }

      ArcListItem() {
        InfoRow({
          label: `Wear detection · id ${sensor.SensorId.WEAR_DETECTION}`,
          value: probeState(this.wear),
          detail: probeDetail(this.wear, ''),
          color: probeColor(this.wear)
        })
      }

      ArcListItem() {
        InfoRow({
          label: 'App state',
          value: this.away.foreground ? 'Foreground' : 'Background',
          detail: `in background ${this.away.visits}× · ${grouped(this.away.seconds)} s`
        })
      }

      ArcListItem() {
        InfoRow({
          label: 'Events in background',
          value: `HR ${grouped(this.away.heartRateEvents)} · steps ${grouped(this.away.stepEvents)}`,
          detail: `wear ${grouped(this.away.wearEvents)} · timer ticks ${grouped(this.away.ticks)}`
        })
      }

      ArcListItem() {
        InfoRow({
          label: 'Longest heart-rate gap',
          value: `${seconds(this.away.gapForegroundMs)} · ${seconds(this.away.gapBackgroundMs)}`,
          detail: 'foreground · background'
        })
      }

      ArcListItem() {
        Row() {
          Column({ space: 1 }) {
            Text('Keep screen on')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
            Text(`lock ${this.keepOnState}`)
              .fontSize(11)
              .fontColor(TEXT_SECONDARY)
          }
          .alignItems(HorizontalAlign.Start)

          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.keepOn })
            .onChange((isOn: boolean) => ScreenAwake.setEnabled(isOn))
            .id(SENSOR_FOCUS_ID)
        }
        .width(ROW_WIDTH)
        .padding({ top: 9, bottom: 9, left: 20, right: 14 })
        .backgroundColor(ROW_FILL)
        .borderRadius(ROW_RADIUS)
      }

      ArcListItem() {
        Text(`Sensor list (${this.sensors.length})`)
          .fontSize(13)
          .fontColor(TEXT_SECONDARY)
          .height(30)
      }

      ForEach(this.sensors, (item: SensorInfo) => {
        ArcListItem() {
          InfoRow({ label: `id ${item.id}`, value: item.name })
        }
      }, (item: SensorInfo) => item.id.toString())
    }
    .space(LengthMetrics.vp(6))
    .scrollBar(BarState.Auto)
    .digitalCrownSensitivity(CrownSensitivity.MEDIUM)
    .focusable(true)
    .focusOnTouch(true)
    .onWillScroll((offset: number, state: ScrollState, source: ScrollSource) => this.onPull(offset, source))
    .onScrollStop(() => {
      this.pull = 0;
    })
    .width('100%')
    .height('100%')
    .linearGradient({ direction: GradientDirection.Bottom, colors: SYSTEM_BACKGROUND })
  }
}
