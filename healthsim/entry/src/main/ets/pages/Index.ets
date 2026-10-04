import { hesThousands } from 'common';
import { LengthMetrics, SymbolGlyphModifier } from '@kit.ArkUI';
import { common, Want } from '@kit.AbilityKit';
import {
  EXERCISE_GOAL_MIN,
  METRIC_EXERCISE,
  METRIC_HEART,
  METRIC_HRV,
  METRIC_RESTING,
  METRIC_SLEEP,
  METRIC_STEPS,
  METRIC_VO2MAX,
  metricUnit,
  NO_VALUE,
  simActivity,
  SimActivity,
  simCard,
  SimCard,
  simPeople,
  SimPerson,
  simPersonName,
  STEPS_GOAL
} from '../data/SimData';
import {
  ABOUT_BODY,
  ABOUT_TITLE,
  ACTIVITY_TITLE,
  APP_TITLE,
  APPS_TITLE,
  FAIRWEAR_LINE,
  FAIRWEAR_MISSING,
  FAIRWEAR_NAME,
  FAIRWEAR_NOTE,
  FAIRWEAR_SIMULATED,
  FAIRWEAR_WEAR,
  HEALTH_NOTE,
  LABEL_EXERCISE,
  LABEL_STEPS,
  OPEN_FAIRWEAR,
  PERSON_LABEL,
  PERSON_NOTE,
  SCENARIO_NOTE,
  SCENARIO_TAG,
  SCENARIO_TITLE,
  TAB_HEALTH,
  TAB_HISTORY,
  TAB_ME
} from '../data/SimTexts';
import { CARD, SimBanner } from '../ui/SimBanner';
import { HistoryView } from '../ui/HistoryView';
import { ReadinessView } from '../ui/ReadinessView';
import { DEFAULT_PERSON, KEY_METRIC, KEY_PERSON, metricColor, metricLabel, metricSymbol } from '../ui/SimMetric';

const CARD_GAP: number = 14;
const FAIRWEAR_BUNDLE: string = 'com.fairwear.app';
const TAB_INDEX_ME: number = 3;
const RING_OUTER: number = 132;
const RING_INNER: number = 92;
const RING_STROKE: number = 14;
const BAR_HEIGHT: number = 36;
const BAR_MIN: number = 4;

// The start page of Health Sim: the banner and four tabs. Health shows the running day of the demo person
// ("Activity records" with two rings, then one card per metric; a card opens that metric over the completed
// days). History lists the completed days, the VO2max estimates and the heart-rate recovery tests. Me holds
// the demo-person picker, the Scenario tool (a developer tool) and the connected apps, where the FairWear
// card opens FairWear as an add-on.
@Entry
@Component
struct Index {
  @StorageLink(KEY_PERSON) personId: string = DEFAULT_PERSON;
  @State activity: SimActivity = simActivity(DEFAULT_PERSON);
  @State cards: SimCard[] = [];
  @State tiles: SimCard[] = [];
  @State tab: number = 0;
  @State openError: string = '';

  aboutToAppear(): void {
    this.load(this.personId);
  }

  private load(id: string): void {
    this.activity = simActivity(id);
    this.cards = [simCard(id, METRIC_HEART), simCard(id, METRIC_RESTING), simCard(id, METRIC_SLEEP),
      simCard(id, METRIC_EXERCISE)];
    this.tiles = [simCard(id, METRIC_VO2MAX), simCard(id, METRIC_HRV)];
  }

  private pick(id: string): void {
    this.personId = id;
    this.load(id);
  }

  private openMetric(metric: string): void {
    AppStorage.setOrCreate(KEY_METRIC, metric);
    this.getUIContext().getRouter().pushUrl({ url: 'pages/MetricPage' }).catch(() => {
      // The page stays where it is; there is nothing to recover.
    });
  }

  private openFairWear(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const want: Want = {
      bundleName: FAIRWEAR_BUNDLE,
      moduleName: 'entry',
      abilityName: 'EntryAbility',
      parameters: { 'fwTarget': 'dashboard' }
    };
    this.openError = '';
    try {
      context.startAbility(want).catch(() => {
        this.openError = FAIRWEAR_MISSING;
      });
    } catch (e) {
      this.openError = FAIRWEAR_MISSING;
    }
  }

  private spoken(metric: string, value: string): string {
    const unit = metricUnit(metric);
    return value === NO_VALUE ? `${metricLabel(metric)}, not measured` :
      `${metricLabel(metric)}, ${value}${unit.length > 0 ? ` ${unit}` : ''}`;
  }

  @Builder
  ringLine(metric: string, label: string, value: string, goal: string) {
    Row({ space: 10 }) {
      Circle()
        .width(10)
        .height(10)
        .fill(metricColor(metric))
      Column({ space: 2 }) {
        Text(label)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
        Text() {
          Span(value)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Span(` / ${goal}`)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .maxLines(1)
      }
      .alignItems(HorizontalAlign.Start)
    }
    .alignItems(VerticalAlign.Center)
    .accessibilityGroup(true)
    .accessibilityText(value === NO_VALUE ? `${label}, not measured` : `${label}, ${value} of ${goal}`)
  }

  @Builder
  activityCard() {
    Column({ space: 16 }) {
      Row({ space: 8 }) {
        Text(ACTIVITY_TITLE)
          .fontSize($r('sys.float.Subtitle_M'))
          .fontWeight(600)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
        Text(this.activity.title)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
          .id('hs_today_date')
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 20 }) {
        Stack() {
          Progress({
            value: this.activity.stepsShare,
            total: 100,
            type: ProgressType.Ring
          })
            .width(RING_OUTER)
            .height(RING_OUTER)
            .style({ strokeWidth: RING_STROKE })
            .color(metricColor(METRIC_STEPS))
            .backgroundColor($r('app.color.hs_track'))
          Progress({
            value: this.activity.exerciseShare,
            total: 100,
            type: ProgressType.Ring
          })
            .width(RING_INNER)
            .height(RING_INNER)
            .style({ strokeWidth: RING_STROKE })
            .color(metricColor(METRIC_EXERCISE))
            .backgroundColor($r('app.color.hs_track'))
        }
        .width(RING_OUTER)
        .height(RING_OUTER)
        .accessibilityLevel('no')

        Column({ space: 14 }) {
          this.ringLine(METRIC_STEPS, LABEL_STEPS, this.activity.steps,
            `${hesThousands(STEPS_GOAL)} ${metricUnit(METRIC_STEPS)}`)
          this.ringLine(METRIC_EXERCISE, LABEL_EXERCISE, this.activity.exercise,
            `${EXERCISE_GOAL_MIN} ${metricUnit(METRIC_EXERCISE)}`)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .attributeModifier(CARD)
    .id('hs_activity')
    .onClick(() => {
      this.openMetric(METRIC_EXERCISE);
    })
  }

  @Builder
  valueText(card: SimCard) {
    Text() {
      Span(card.value)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Span(metricUnit(card.metric).length > 0 && card.value !== NO_VALUE ? ` ${metricUnit(card.metric)}` : '')
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .maxLines(1)
  }

  @Builder
  cardHead(metric: string, opens: boolean) {
    Row({ space: 8 }) {
      SymbolGlyph(metricSymbol(metric))
        .fontSize(20)
        .fontColor([metricColor(metric)])
      Text(metricLabel(metric))
        .fontSize($r('sys.float.Subtitle_M'))
        .fontWeight(600)
        .fontColor($r('sys.color.font_primary'))
        .layoutWeight(1)
      if (opens) {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([$r('sys.color.font_tertiary')])
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  metricCard(card: SimCard) {
    Column({ space: 10 }) {
      this.cardHead(card.metric, true)
      Row({ space: 12 }) {
        Column({ space: 2 }) {
          this.valueText(card)
          Text(card.sub)
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Row({ space: 4 }) {
          ForEach(card.bars, (share: number) => {
            Column()
              .width(6)
              .height(share < 0 ? 2 : Math.max(BAR_MIN, Math.round(BAR_HEIGHT * share / 100)))
              .borderRadius(3)
              .backgroundColor(share < 0 ? $r('app.color.hs_track') : metricColor(card.metric))
          }, (share: number, index: number) => `${this.personId}|${card.metric}|${index}|${share}`)
        }
        .height(BAR_HEIGHT)
        .alignItems(VerticalAlign.Bottom)
        .accessibilityLevel('no')
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
    }
    .attributeModifier(CARD)
    .id(`hs_card_${card.metric}`)
    .accessibilityGroup(true)
    .accessibilityText(this.spoken(card.metric, card.value))
    .onClick(() => {
      this.openMetric(card.metric === METRIC_HEART ? METRIC_RESTING : card.metric);
    })
  }

  @Builder
  metricTile(card: SimCard) {
    Column({ space: 8 }) {
      this.cardHead(card.metric, true)
      this.valueText(card)
      Text(card.sub)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .attributeModifier(CARD)
    .layoutWeight(1)
    .id(`hs_card_${card.metric}`)
    .accessibilityGroup(true)
    .accessibilityText(this.spoken(card.metric, card.value))
    .onClick(() => {
      this.openMetric(card.metric === METRIC_HEART ? METRIC_RESTING : card.metric);
    })
  }

  @Builder
  healthTab() {
    Scroll() {
      Column({ space: CARD_GAP }) {
        this.activityCard()

        ForEach(this.cards, (card: SimCard) => {
          this.metricCard(card)
        }, (card: SimCard) => `${this.personId}|${card.metric}|${card.value}`)

        Row({ space: CARD_GAP }) {
          ForEach(this.tiles, (card: SimCard) => {
            this.metricTile(card)
          }, (card: SimCard) => `${this.personId}|${card.metric}|${card.value}`)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Text(HEALTH_NOTE)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
          .padding({ left: 4, right: 4 })
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

  @Builder
  meTab() {
    Scroll() {
      Column({ space: CARD_GAP }) {
        Column({ space: 10 }) {
          Text(PERSON_LABEL)
            .fontSize($r('sys.float.Subtitle_M'))
            .fontWeight(600)
            .fontColor($r('sys.color.font_primary'))
          Text(PERSON_NOTE)
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_secondary'))
          Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
            ForEach(simPeople(), (person: SimPerson) => {
              Button(person.name)
                .buttonStyle(person.id === this.personId ? ButtonStyleMode.EMPHASIZED : ButtonStyleMode.NORMAL)
                .height(40)
                .id(`hs_person_${person.id}`)
                .accessibilityText(person.name + (person.id === this.personId ? ', selected' : ''))
                .onClick(() => {
                  this.pick(person.id);
                })
            }, (person: SimPerson) => `${person.id}|${person.id === this.personId}`)
          }
          .width('100%')
        }
        .attributeModifier(CARD)
        .id('hs_person')

        Row({ space: 8 }) {
          Text(SCENARIO_TITLE)
            .fontSize($r('sys.float.Subtitle_M'))
            .fontWeight(600)
            .fontColor($r('sys.color.font_primary'))
          Text(SCENARIO_TAG)
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_primary'))
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .borderRadius(10)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .id('hs_scenario_tag')
        }
        .padding({ left: 4, top: 6 })
        .alignItems(VerticalAlign.Center)
        Text(SCENARIO_NOTE)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
          .padding({ left: 4, right: 4 })
        ReadinessView({ personId: this.personId })

        Text(APPS_TITLE)
          .fontSize($r('sys.float.Subtitle_M'))
          .fontWeight(600)
          .fontColor($r('sys.color.font_primary'))
          .padding({ left: 4, top: 6 })

        Column({ space: 12 }) {
          Row({ space: 12 }) {
            SymbolGlyph($r('sys.symbol.checkmark_shield'))
              .fontSize(28)
              .fontColor([$r('sys.color.icon_emphasize')])
            Column({ space: 2 }) {
              Text(FAIRWEAR_NAME)
                .fontSize($r('sys.float.Subtitle_L'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.font_primary'))
              Text(FAIRWEAR_LINE)
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .accessibilityGroup(true)

          Text(FAIRWEAR_NOTE)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_secondary'))
          Text(FAIRWEAR_WEAR)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_secondary'))
            .id('hs_fairwear_wear')

          Button(OPEN_FAIRWEAR)
            .buttonStyle(ButtonStyleMode.EMPHASIZED)
            .width('100%')
            .height(48)
            .id('hs_open_fairwear')
            .onClick(() => {
              this.openFairWear();
            })

          if (this.openError.length > 0) {
            Text(this.openError)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.warning'))
              .id('hs_open_error')
          }

          Text(FAIRWEAR_SIMULATED)
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_tertiary'))
            .id('hs_fairwear_simulated')
        }
        .attributeModifier(CARD)
        .id('hs_fairwear_card')

        Column({ space: 6 }) {
          Text(ABOUT_TITLE)
            .fontSize($r('sys.float.Subtitle_M'))
            .fontWeight(600)
            .fontColor($r('sys.color.font_primary'))
          Text(ABOUT_BODY)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .attributeModifier(CARD)
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

  build() {
    Column() {
      SimBanner()

      Row({ space: 8 }) {
        Text(APP_TITLE)
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
          .id('hs_title')
        Text(`${PERSON_LABEL} · ${simPersonName(this.personId)}`)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_primary'))
          .padding({ left: 12, right: 12 })
          .height(40)
          .borderRadius(20)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .id('hs_person_chip')
          .accessibilityText(`${PERSON_LABEL}, ${simPersonName(this.personId)}. Change it under Me.`)
          .onClick(() => {
            this.tab = TAB_INDEX_ME;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 10 })
      .alignItems(VerticalAlign.Center)

      Tabs({ barPosition: BarPosition.End, index: this.tab }) {
        TabContent() {
          this.healthTab()
        }
        .tabBar(new BottomTabBarStyle({ normal: new SymbolGlyphModifier($r('sys.symbol.heart')) }, TAB_HEALTH))

        TabContent() {
          HistoryView({ personId: this.personId })
        }
        .tabBar(new BottomTabBarStyle({ normal: new SymbolGlyphModifier($r('sys.symbol.clock')) }, TAB_HISTORY))

        TabContent() {
          this.meTab()
        }
        .tabBar(new BottomTabBarStyle({ normal: new SymbolGlyphModifier($r('sys.symbol.person')) }, TAB_ME))
      }
      .layoutWeight(1)
      .width('100%')
      .barBackgroundColor($r('sys.color.comp_background_primary'))
      .divider({ strokeWidth: 0.5, color: $r('sys.color.comp_divider') })
      .onChange((index: number) => {
        this.tab = index;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
