/**
 * HealthSim main page: Today / History / Scenario tabs under a permanent "simulated" banner.
 * Holds the scenario, regenerates the dataset on every change and persists the scenario.
 */
import { common } from '@kit.AbilityKit';
import { HsCodec, HsSyncDelay } from '../healthsim/HsCodec';
import { HsPersonas } from '../healthsim/HsPersonas';
import { DayRow, formatTime, HsSummary, TodayModel } from '../healthsim/HsSummary';
import { HsDataset, HsDataType, MINUTE_MS } from '../healthsim/HsTypes';
import { HistoryView } from '../components/HistoryView';
import { ScenarioView } from '../components/ScenarioView';
import { SimBanner } from '../components/Common';
import { TodayView } from '../components/TodayView';
import { AccessEntry, generateFor, ScenarioState, ScenarioStore } from '../model/ScenarioStore';

@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  @State scenario: ScenarioState = new ScenarioState();
  @State today: TodayModel = new TodayModel();
  @State days: DayRow[] = [];
  @State datasetId: string = '';
  @State personaName: string = '';
  @State syncLabel: string = '';
  @State accessLog: AccessEntry[] = [];
  private store: ScenarioStore | null = null;
  private tabsController: TabsController = new TabsController();

  aboutToAppear(): void {
    const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.store = new ScenarioStore(ctx);
    this.scenario = this.store.load();
    this.regenerate();
  }

  onPageShow(): void {
    // FairWear may have requested data while we were in the background.
    if (this.store !== null) {
      this.accessLog = this.store.loadLog();
    }
  }

  private regenerate(): void {
    const ds: HsDataset = generateFor(this.scenario);
    this.today = HsSummary.today(ds);
    this.days = HsSummary.days(ds);
    this.datasetId = HsCodec.datasetId(ds);
    this.personaName = HsPersonas.byId(this.scenario.personaId).name;
    const delay: number = this.scenario.syncDelay ? HsSyncDelay.minutesFor(HsDataType.STEPS) : 0;
    this.syncLabel = formatTime(ds.anchorMs - delay * MINUTE_MS, ds.tzOffsetMin);
    if (this.store !== null) {
      this.accessLog = this.store.loadLog();
    }
  }

  private applyScenario(s: ScenarioState): void {
    this.scenario = s;
    if (this.store !== null) {
      this.store.save(s);
    }
    this.regenerate();
  }

  @Builder
  tabBarItem(index: number, title: Resource) {
    Column({ space: 4 }) {
      Row()
        .width(18)
        .height(3)
        .borderRadius(2)
        .backgroundColor(this.currentTab === index ? $r('app.color.accent') : Color.Transparent)
      Text(title)
        .fontSize(13)
        .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentTab === index ? $r('app.color.accent') : $r('app.color.muted'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      SimBanner()
      Tabs({ barPosition: BarPosition.End, index: this.currentTab, controller: this.tabsController }) {
        TabContent() {
          TodayView({
            model: this.today,
            personaName: this.personaName,
            datasetId: this.datasetId,
            syncLabel: this.syncLabel
          })
        }
        .tabBar(this.tabBarItem(0, $r('app.string.tab_today')))

        TabContent() {
          HistoryView({ rows: this.days, datasetId: this.datasetId })
        }
        .tabBar(this.tabBarItem(1, $r('app.string.tab_history')))

        TabContent() {
          ScenarioView({
            scenario: this.scenario,
            datasetId: this.datasetId,
            log: this.accessLog,
            onScenarioChange: (s: ScenarioState): void => {
              this.applyScenario(s);
            }
          })
        }
        .tabBar(this.tabBarItem(2, $r('app.string.tab_scenario')))
      }
      .layoutWeight(1)
      .barHeight(56)
      .barBackgroundColor($r('app.color.surface'))
      .onChange((index: number) => {
        this.currentTab = index;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page'))
  }
}
