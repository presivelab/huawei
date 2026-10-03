import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { ArcDirection, ArcDotIndicator, ArcSwiper, ArcSwiperController } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { RingsPage, TodayGoalsPage, TodayStepsPage } from '../components/ActivityPages';
import { HeartPage, RestingPage } from '../components/HeartPages';
import { SENSOR_FOCUS_ID, SensorsCover, SensorsPage } from '../components/SensorsPage';
import { HealthEngine } from '../model/HealthEngine';

const DOMAIN = 0x0002;
const TAG = 'HealthDemo';
const PERMISSIONS: Permissions[] = ['ohos.permission.READ_HEALTH_DATA', 'ohos.permission.ACTIVITY_MOTION'];
const PAGER_ID = 'pager';
const SENSORS_PAGE = 5;
// The pager dots sit straight on each page's own gradient.
const NO_MASK = new LinearGradient([{ color: '#00000000', offset: 0 }, { color: '#00000000', offset: 1 }]);

@Entry
@Component
struct Index {
  @State sensorsOpen: boolean = false;
  private pager: ArcSwiperController = new ArcSwiperController();

  aboutToAppear(): void {
    this.start();
  }

  private async start(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      const result = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context, PERMISSIONS);
      hilog.info(DOMAIN, TAG, 'permissions: %{public}s', JSON.stringify(result.authResults));
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'requestPermissions failed: %{public}s', JSON.stringify(err));
    }
    HealthEngine.get().startSensors();
  }

  // The crown drives whatever has focus: the sensor list while it is open, the pager otherwise.
  private focus(id: string): void {
    try {
      this.getUIContext().getFocusController().requestFocus(id);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'focus %{public}s failed: %{public}s', id, JSON.stringify(err));
    }
  }

  private leaveSensors(): void {
    this.sensorsOpen = false;
    this.pager.showPrevious();
    this.focus(PAGER_ID);
  }

  build() {
    Stack() {
      // Declared ahead of the pager: a sibling that follows ArcSwiper is adopted by it as one more page.
      if (this.sensorsOpen) {
        SensorsPage({ leave: () => this.leaveSensors() })
          .zIndex(1)
          .transition(TransitionEffect.OPACITY.animation({ duration: 160 }), (appearing: boolean) => {
            if (appearing) {
              this.focus(SENSOR_FOCUS_ID);
            }
          })
      }

      ArcSwiper(this.pager) {
        RingsPage()
        TodayGoalsPage()
        TodayStepsPage()
        HeartPage()
        RestingPage()
        SensorsCover()
      }
      .id(PAGER_ID)
      .vertical(true)
      .indicator(new ArcDotIndicator()
        .arcDirection(ArcDirection.THREE_CLOCK_DIRECTION)
        .itemColor('#4DFFFFFF')
        .selectedItemColor(Color.White)
        .maskColor(NO_MASK))
      .digitalCrownSensitivity(CrownSensitivity.MEDIUM)
      .focusable(true)
      .defaultFocus(true)
      .focusOnTouch(true)
      .onAnimationEnd((index: number) => {
        this.sensorsOpen = index === SENSORS_PAGE;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }
}
