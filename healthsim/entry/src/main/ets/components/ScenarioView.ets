/**
 * Scenario tab: persona, seed, demo/live time, sync delay, access log and an honest "about".
 * Changes are reported to the page, which regenerates and persists them.
 */
import { HsPersona, HsPersonas } from '../healthsim/HsPersonas';
import { formatTime } from '../healthsim/HsSummary';
import { AccessEntry, ANCHOR_DEMO, ANCHOR_LIVE, ScenarioState } from '../model/ScenarioStore';

@Extend(Column)
function section() {
  .width('100%')
  .padding(16)
  .borderRadius(16)
  .backgroundColor($r('app.color.surface'))
  .alignItems(HorizontalAlign.Start)
}

@Extend(Text)
function sectionTitle() {
  .fontSize(15)
  .fontWeight(FontWeight.Medium)
  .fontColor($r('app.color.ink'))
}

@Component
export struct ScenarioView {
  @Prop scenario: ScenarioState = new ScenarioState();
  @Prop datasetId: string = '';
  @Prop log: AccessEntry[] = [];
  onScenarioChange: (s: ScenarioState) => void = (s: ScenarioState): void => {
  };
  private personas: HsPersona[] = HsPersonas.all();

  private copy(): ScenarioState {
    const s: ScenarioState = new ScenarioState();
    s.personaId = this.scenario.personaId;
    s.seed = this.scenario.seed;
    s.anchorMode = this.scenario.anchorMode;
    s.syncDelay = this.scenario.syncDelay;
    s.days = this.scenario.days;
    return s;
  }

  private pickPersona(id: string): void {
    const s: ScenarioState = this.copy();
    s.personaId = id;
    this.onScenarioChange(s);
  }

  private stepSeed(delta: number): void {
    const s: ScenarioState = this.copy();
    s.seed = Math.max(1, s.seed + delta);
    this.onScenarioChange(s);
  }

  private setAnchor(mode: string): void {
    const s: ScenarioState = this.copy();
    s.anchorMode = mode;
    this.onScenarioChange(s);
  }

  private setSyncDelay(on: boolean): void {
    const s: ScenarioState = this.copy();
    s.syncDelay = on;
    this.onScenarioChange(s);
  }

  private personaDesc(id: string): Resource {
    if (id === 'ania') {
      return $r('app.string.persona_ania_desc');
    }
    if (id === 'marek') {
      return $r('app.string.persona_marek_desc');
    }
    if (id === 'wei') {
      return $r('app.string.persona_wei_desc');
    }
    return $r('app.string.persona_kasia_desc');
  }

  private chipBg(selected: boolean): ResourceColor {
    return selected ? $r('app.color.accent') : $r('app.color.empty');
  }

  private chipFg(selected: boolean): ResourceColor {
    return selected ? $r('app.color.on_accent') : $r('app.color.ink');
  }

  private logLine(e: AccessEntry): string {
    // Device-local wall-clock time of the request (not the simulated time).
    const offsetMin: number = -new Date(e.timeMs).getTimezoneOffset();
    return formatTime(e.timeMs, offsetMin) + ' · ' + e.requester + ' · ' + String(e.typeCount) + ' · ' + e.datasetId;
  }

  @Builder
  personaSection() {
    Column({ space: 10 }) {
      Text($r('app.string.scenario_persona')).sectionTitle()
      ForEach(this.personas, (p: HsPersona) => {
        Row({ space: 12 }) {
          Column({ space: 2 }) {
            Text(p.name)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.ink'))
            Text(this.personaDesc(p.id))
              .fontSize(12)
              .fontColor($r('app.color.muted'))
            Text($r('app.string.expected_tier', p.expectedTier))
              .fontSize(11)
              .fontColor($r('app.color.accent'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Radio({ value: p.id, group: 'persona' })
            .checked(this.scenario.personaId === p.id)
            .onChange((isChecked: boolean) => {
              if (isChecked && this.scenario.personaId !== p.id) {
                this.pickPersona(p.id);
              }
            })
        }
        .width('100%')
        .padding({ top: 6, bottom: 6 })
        .onClick(() => {
          this.pickPersona(p.id);
        })
      }, (p: HsPersona) => p.id + (this.scenario.personaId === p.id ? '-on' : '-off'))
    }
    .section()
  }

  @Builder
  dataSection() {
    Column({ space: 12 }) {
      Text($r('app.string.scenario_data')).sectionTitle()
      Row({ space: 8 }) {
        Text($r('app.string.seed'))
          .fontSize(14)
          .fontColor($r('app.color.ink'))
          .layoutWeight(1)
        Button('−')
          .width(40)
          .height(32)
          .fontColor($r('app.color.ink'))
          .backgroundColor($r('app.color.empty'))
          .onClick(() => {
            this.stepSeed(-1);
          })
        Text(String(this.scenario.seed))
          .fontSize(15)
          .fontFamily('monospace')
          .width(44)
          .textAlign(TextAlign.Center)
        Button('+')
          .width(40)
          .height(32)
          .fontColor($r('app.color.ink'))
          .backgroundColor($r('app.color.empty'))
          .onClick(() => {
            this.stepSeed(1);
          })
      }
      .width('100%')

      Text($r('app.string.time_mode'))
        .fontSize(14)
        .fontColor($r('app.color.ink'))
      Row({ space: 8 }) {
        Text($r('app.string.time_demo'))
          .fontSize(12)
          .fontColor(this.chipFg(this.scenario.anchorMode === ANCHOR_DEMO))
          .backgroundColor(this.chipBg(this.scenario.anchorMode === ANCHOR_DEMO))
          .borderRadius(14)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .onClick(() => {
            this.setAnchor(ANCHOR_DEMO);
          })
        Text($r('app.string.time_live'))
          .fontSize(12)
          .fontColor(this.chipFg(this.scenario.anchorMode === ANCHOR_LIVE))
          .backgroundColor(this.chipBg(this.scenario.anchorMode === ANCHOR_LIVE))
          .borderRadius(14)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .onClick(() => {
            this.setAnchor(ANCHOR_LIVE);
          })
      }
      Text($r('app.string.time_note'))
        .fontSize(11)
        .fontColor($r('app.color.muted'))

      Row() {
        Column({ space: 2 }) {
          Text($r('app.string.sync_delay'))
            .fontSize(14)
            .fontColor($r('app.color.ink'))
          Text($r('app.string.sync_delay_desc'))
            .fontSize(11)
            .fontColor($r('app.color.muted'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.scenario.syncDelay })
          .selectedColor($r('app.color.accent'))
          .onChange((isOn: boolean) => {
            if (isOn !== this.scenario.syncDelay) {
              this.setSyncDelay(isOn);
            }
          })
      }
      .width('100%')

      Row({ space: 6 }) {
        Text($r('app.string.data_id', this.datasetId))
          .fontSize(12)
          .fontFamily('monospace')
          .fontColor($r('app.color.accent'))
        Text($r('app.string.days_window', this.scenario.days))
          .fontSize(12)
          .fontColor($r('app.color.muted'))
      }
    }
    .section()
  }

  @Builder
  accessSection() {
    Column({ space: 8 }) {
      Text($r('app.string.access_log')).sectionTitle()
      if (this.log.length === 0) {
        Text($r('app.string.access_none'))
          .fontSize(12)
          .fontColor($r('app.color.muted'))
      } else {
        Text($r('app.string.access_cols'))
          .fontSize(10)
          .fontColor($r('app.color.muted'))
        ForEach(this.log, (e: AccessEntry) => {
          Row({ space: 6 }) {
            Text(this.logLine(e))
              .fontSize(12)
              .fontFamily('monospace')
              .fontColor($r('app.color.ink'))
              .layoutWeight(1)
            if (e.granted) {
              Text($r('app.string.access_granted'))
                .fontSize(11)
                .fontColor($r('app.color.accent'))
            } else {
              Text($r('app.string.access_denied'))
                .fontSize(11)
                .fontColor($r('app.color.sick_text'))
            }
          }
          .width('100%')
        }, (e: AccessEntry) => String(e.timeMs) + e.requester)
      }
    }
    .section()
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Text($r('app.string.tab_scenario'))
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ink'))
          .width('100%')
        this.personaSection()
        this.dataSection()
        this.accessSection()
        Column({ space: 6 }) {
          Text($r('app.string.about_title')).sectionTitle()
          Text($r('app.string.about_body'))
            .fontSize(12)
            .lineHeight(18)
            .fontColor($r('app.color.muted'))
        }
        .section()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 24 })
    }
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .width('100%')
    .height('100%')
  }
}
