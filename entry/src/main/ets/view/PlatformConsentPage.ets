import { common } from '@kit.AbilityKit';
import { ALL_HEALTH_SCOPES, HealthScope, HealthStatus } from 'common';
import { AddonSession } from '../addon/AddonSession';
import {
  HEALTH_SIM_ASK_AGAIN,
  HEALTH_SIM_ASKING,
  HEALTH_SIM_ASKING_BODY,
  HEALTH_SIM_USE_BUILT_IN,
  HEALTH_SIM_SENTENCE,
  ROUTE_DATA_CONSENT,
  scopeLabel
} from '../addon/AddonTexts';
import { HealthSimAnswerKind } from '../platform/HealthSimClient';
import { BODY, BODY_SECONDARY, CAPTION, LABEL, TITLE } from './Styles';

// Health Sim is being asked: its own consent screen is on top of this page.
const PHASE_ASKING: string = 'asking';
// Health Sim is not installed or did not answer: the built-in demo placeholder, as before Health Sim.
const PHASE_PLACEHOLDER: string = 'placeholder';

// AD-2, step 1. HUAWEI Health shows its own authorization screen at this point; FairWear does not copy it.
// On the emulators the separate app Health Sim stands in for HUAWEI Health: this page asks it for access
// as soon as it opens, and Health Sim shows its own consent screen. When Health Sim is not installed or
// does not answer, the page falls back to the neutral DEMO placeholder that lists the data types FairWear
// asks for and lets the demo operator simulate the user's answer.
@Component
export struct PlatformConsentPage {
  @Consume('fwNav') nav: NavPathStack;
  @State phase: string = PHASE_ASKING;
  @State note: string = '';
  private answered: boolean = false;
  private unavailable: boolean = AddonSession.shared().platformStatus() === HealthStatus.UNAVAILABLE;

  aboutToAppear(): void {
    this.askHealthSim();
  }

  // Leaving the page while Health Sim has not answered gives the request up, so a late answer changes nothing.
  aboutToDisappear(): void {
    if (this.phase === PHASE_ASKING && !this.answered) {
      AddonSession.shared().abandonHealthSim();
    }
  }

  private showPlaceholder(): void {
    this.note = AddonSession.shared().healthSimNote();
    this.phase = PHASE_PLACEHOLDER;
  }

  private askHealthSim(): void {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.showPlaceholder();
      return;
    }
    AddonSession.shared().askHealthSim(context as common.UIAbilityContext).then((kind: string) => {
      if (kind === HealthSimAnswerKind.STALE) {
        return;
      }
      this.answered = true;
      if (kind === HealthSimAnswerKind.OK) {
        this.nav.replacePathByName(ROUTE_DATA_CONSENT, null);
      } else if (kind === HealthSimAnswerKind.REFUSED) {
        this.nav.clear();
      } else {
        this.showPlaceholder();
      }
    }).catch(() => {
      this.showPlaceholder();
    });
  }

  @Builder
  asking() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        LoadingProgress()
          .width(24)
          .height(24)
          .color($r('sys.color.icon_secondary'))
        Text(HEALTH_SIM_ASKING)
          .attributeModifier(TITLE)
          .layoutWeight(1)
          .id('fw_healthsim_asking')
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(HEALTH_SIM_SENTENCE).attributeModifier(BODY_SECONDARY)
      Text(HEALTH_SIM_ASKING_BODY).attributeModifier(BODY_SECONDARY)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level8'))
    .borderRadius($r('sys.float.corner_radius_level8'))
    .border({ width: 1, color: $r('sys.color.font_tertiary'), style: BorderStyle.Dashed })
  }

  @Builder
  placeholder() {
    Column({ space: 8 }) {
      Text('Demo')
        .fontSize($r('sys.float.Body_S'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .padding({
          left: $r('sys.float.padding_level4'),
          right: $r('sys.float.padding_level4'),
          top: $r('sys.float.padding_level1'),
          bottom: $r('sys.float.padding_level1')
        })
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius($r('sys.float.corner_radius_level4'))
      Text('Here HUAWEI Health shows its own authorization screen.').attributeModifier(TITLE)
      Text('FairWear does not reproduce that screen. The two buttons below stand in for the answer the ' +
        'user gives there.')
        .attributeModifier(BODY_SECONDARY)
      if (this.note.length > 0) {
        Text(this.note)
          .attributeModifier(BODY_SECONDARY)
          .fontWeight(FontWeight.Medium)
          .id('fw_healthsim_note')
      }
      if (this.unavailable) {
        Text('HUAWEI Health is unavailable in this build: access to health data through Health Service ' +
          'Kit has to be granted to the app by Huawei, and FairWear does not have it yet.')
          .attributeModifier(BODY_SECONDARY)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding($r('sys.float.padding_level8'))
    .borderRadius($r('sys.float.corner_radius_level8'))
    .border({ width: 1, color: $r('sys.color.font_tertiary'), style: BorderStyle.Dashed })
    .id('fw_demo_placeholder')
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          Text('Step 1 of 2 · HUAWEI Health authorization').attributeModifier(LABEL)

          if (this.phase === PHASE_ASKING) {
            this.asking()
          } else {
            this.placeholder()
          }

          Column({ space: 4 }) {
            Text('Read access FairWear asks for').attributeModifier(TITLE)
            Text('Last 90 days, read only.').attributeModifier(CAPTION)
            ForEach(ALL_HEALTH_SCOPES, (scope: HealthScope) => {
              Text('•  ' + scopeLabel(scope)).attributeModifier(BODY).margin({ top: 4 })
            }, (scope: HealthScope) => scope)
            Text('Not requested: location, ECG, blood pressure, SpO₂, weight, contacts.')
              .attributeModifier(CAPTION)
              .margin({ top: 8 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          if (this.phase === PHASE_ASKING) {
            // Health Sim's screen covers these while it is open. They matter when it never opens: the system
            // asks first whether FairWear may open another app, and a Cancel there reports nothing back.
            Button(HEALTH_SIM_ASK_AGAIN)
              .buttonStyle(ButtonStyleMode.NORMAL)
              .width('100%')
              .id('fw_healthsim_again')
              .onClick(() => {
                this.askHealthSim();
              })
            Button(HEALTH_SIM_USE_BUILT_IN)
              .buttonStyle(ButtonStyleMode.TEXTUAL)
              .width('100%')
              .id('fw_healthsim_built_in')
              .onClick(() => {
                AddonSession.shared().abandonHealthSim();
                this.showPlaceholder();
              })
          }
          if (this.phase === PHASE_PLACEHOLDER) {
            Button('Simulate consent')
              .buttonStyle(ButtonStyleMode.EMPHASIZED)
              .width('100%')
              .id('fw_simulate_consent')
              .onClick(() => {
                AddonSession.shared().recordPlatformConsent(true);
                this.nav.replacePathByName(ROUTE_DATA_CONSENT, null);
              })
            Button('Simulate refusal')
              .buttonStyle(ButtonStyleMode.NORMAL)
              .width('100%')
              .id('fw_simulate_refusal')
              .onClick(() => {
                AddonSession.shared().recordPlatformConsent(false);
                this.nav.clear();
              })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .padding({
          left: $r('sys.float.padding_level8'),
          right: $r('sys.float.padding_level8'),
          bottom: $r('sys.float.padding_level12')
        })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .title('Connect HUAWEI Health')
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
