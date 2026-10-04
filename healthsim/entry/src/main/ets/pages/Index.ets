import { LengthMetrics, SymbolGlyphModifier } from '@kit.ArkUI';
import { common, Want } from '@kit.AbilityKit';
import {
  HISTORY_DAYS,
  NO_VALUE,
  simHistory,
  SimDayRow,
  simPeople,
  SimPerson,
  simPersonName
} from '../data/SimData';
import {
  ABOUT_BODY,
  ABOUT_TITLE,
  APP_TITLE,
  APPS_TITLE,
  FAIRWEAR_LINE,
  FAIRWEAR_MISSING,
  FAIRWEAR_NAME,
  FAIRWEAR_NOTE,
  HISTORY_NOTE,
  HISTORY_TITLE,
  LABEL_ACTIVE,
  LABEL_RESTING,
  LABEL_SLEEP,
  LABEL_STEPS,
  LABEL_WORN,
  OPEN_FAIRWEAR,
  PERSON_LABEL,
  TAB_APPS,
  TAB_HISTORY,
  TAB_TODAY,
  TODAY_NOTE,
  UNIT_BPM,
  UNIT_MIN,
  UNIT_STEPS
} from '../data/SimTexts';
import { CARD, SimBanner } from '../ui/SimBanner';

const CARD_GAP: number = 14;
const DEFAULT_PERSON: string = 'ania';
const FAIRWEAR_BUNDLE: string = 'com.fairwear.app';

// One figure of the Today tab: a name, the value and its unit.
interface TodayItem {
  label: string;
  value: string;
  unit: string;
  symbol: Resource;
}

// The start page of Health Sim: the banner, the person of the simulation, and three tabs. Today and
// History show that person's days; Apps holds the FairWear card, which opens FairWear as an add-on.
@Entry
@Component
struct Index {
  @State personId: string = DEFAULT_PERSON;
  @State rows: SimDayRow[] = simHistory(DEFAULT_PERSON);
  @State tab: number = 0;
  @State openError: string = '';

  private pick(id: string): void {
    this.personId = id;
    this.rows = simHistory(id);
  }

  private todayItems(): TodayItem[] {
    if (this.rows.length === 0) {
      return [];
    }
    const day = this.rows[0];
    return [
      { label: LABEL_STEPS, value: day.steps, unit: UNIT_STEPS, symbol: $r('sys.symbol.steps') },
      { label: LABEL_RESTING, value: day.restingHr, unit: UNIT_BPM, symbol: $r('sys.symbol.heart') },
      { label: LABEL_SLEEP, value: day.sleep, unit: '', symbol: $r('sys.symbol.sleep') },
      { label: LABEL_ACTIVE, value: day.active, unit: UNIT_MIN, symbol: $r('sys.symbol.flame') },
      { label: LABEL_WORN, value: day.worn, unit: '', symbol: $r('sys.symbol.watch') }
    ];
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

  @Builder
  personPicker() {
    Column({ space: 6 }) {
      Text(PERSON_LABEL)
        .fontSize($r('sys.float.Body_S'))
        .fontColor($r('sys.color.font_secondary'))
        .padding({ left: 16 })
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
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 10, bottom: 10 })
  }

  @Builder
  todayTab() {
    Scroll() {
      Column({ space: CARD_GAP }) {
        Column({ space: 14 }) {
          Text(this.rows.length > 0 ? this.rows[0].title : NO_VALUE)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .id('hs_today_date')
          ForEach(this.todayItems(), (item: TodayItem) => {
            Row({ space: 12 }) {
              SymbolGlyph(item.symbol)
                .fontSize(22)
                .fontColor([$r('sys.color.icon_secondary')])
              Text(item.label)
                .fontSize($r('sys.float.Body_L'))
                .fontColor($r('sys.color.font_primary'))
                .layoutWeight(1)
              Text() {
                Span(item.value)
                  .fontSize($r('sys.float.Subtitle_L'))
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('sys.color.font_primary'))
                Span(item.unit.length > 0 && item.value !== NO_VALUE ? ` ${item.unit}` : '')
                  .fontSize($r('sys.float.Body_M'))
                  .fontColor($r('sys.color.font_secondary'))
              }
              .maxLines(1)
            }
            .width('100%')
            .constraintSize({ minHeight: 44 })
            .alignItems(VerticalAlign.Center)
            .accessibilityGroup(true)
            .accessibilityText(item.value === NO_VALUE ? `${item.label}, not measured` :
              `${item.label}, ${item.value} ${item.unit}`)
          }, (item: TodayItem) => `${this.personId}|${item.label}|${item.value}`)
        }
        .attributeModifier(CARD)
        .id('hs_today')

        Text(TODAY_NOTE)
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
  historyTab() {
    Scroll() {
      Column({ space: CARD_GAP }) {
        Column({ space: 4 }) {
          Row({ space: 8 }) {
            Text(HISTORY_TITLE)
              .fontSize($r('sys.float.Subtitle_M'))
              .fontWeight(600)
              .fontColor($r('sys.color.font_primary'))
              .layoutWeight(1)
            Text(`${LABEL_STEPS} · ${LABEL_SLEEP}`)
              .fontSize($r('sys.float.Body_S'))
              .fontColor($r('sys.color.font_secondary'))
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .padding({ bottom: 8 })

          ForEach(this.rows, (row: SimDayRow) => {
            Column({ space: 4 }) {
              Row({ space: 8 }) {
                Text(row.title)
                  .fontSize($r('sys.float.Body_M'))
                  .fontColor($r('sys.color.font_primary'))
                  .layoutWeight(1)
                Text(row.steps)
                  .fontSize($r('sys.float.Body_M'))
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('sys.color.font_primary'))
                  .textAlign(TextAlign.End)
                  .width(72)
                Text(row.sleep)
                  .fontSize($r('sys.float.Body_M'))
                  .fontColor($r('sys.color.font_secondary'))
                  .textAlign(TextAlign.End)
                  .width(96)
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)

              Progress({ value: row.stepsShare, total: 100, type: ProgressType.Linear })
                .style({ strokeWidth: 4, enableSmoothEffect: false })
                .color($r('sys.color.icon_emphasize'))
                .backgroundColor($r('sys.color.comp_background_tertiary'))
                .width('100%')
            }
            .width('100%')
            .padding({ top: 6, bottom: 6 })
            .accessibilityGroup(true)
            .accessibilityText(`${row.title}, ` +
              (row.steps === NO_VALUE ? 'steps not measured' : `${row.steps} steps`) + ', ' +
              (row.sleep === NO_VALUE ? 'sleep not measured' : `sleep ${row.sleep}`))
          }, (row: SimDayRow) => `${this.personId}|${row.date}`)
        }
        .attributeModifier(CARD)
        .id('hs_history')

        Text(HISTORY_NOTE)
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
  appsTab() {
    Scroll() {
      Column({ space: CARD_GAP }) {
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
        Text(`${simPersonName(this.personId)} · ${HISTORY_DAYS} days`)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12 })
      .alignItems(VerticalAlign.Center)

      this.personPicker()

      Tabs({ barPosition: BarPosition.End, index: this.tab }) {
        TabContent() {
          this.todayTab()
        }
        .tabBar(new BottomTabBarStyle({ normal: new SymbolGlyphModifier($r('sys.symbol.heart')) }, TAB_TODAY))

        TabContent() {
          this.historyTab()
        }
        .tabBar(new BottomTabBarStyle({ normal: new SymbolGlyphModifier($r('sys.symbol.calendar')) }, TAB_HISTORY))

        TabContent() {
          this.appsTab()
        }
        .tabBar(new BottomTabBarStyle({ normal: new SymbolGlyphModifier($r('sys.symbol.list_bullet')) }, TAB_APPS))
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
