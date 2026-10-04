import { ALL_HEALTH_SCOPES, HealthScope } from 'common';
import { AddonSession } from '../addon/AddonSession';
import { scopeLabel } from '../addon/AddonTexts';
import { BODY, BODY_SECONDARY, CAPTION, CARD, LABEL } from './Styles';

@Component
struct ScopeSwitch {
  @Prop label: string = '';
  @Link isOn: boolean;

  build() {
    Row() {
      Text(this.label).attributeModifier(BODY).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.isOn })
        .onChange((on: boolean) => {
          this.isOn = on;
        })
    }
    .width('100%')
    .constraintSize({ minHeight: 48 })
  }
}

// AD-2, step 2. FairWear's own consent to process health data (GDPR art. 9), separate from the platform's
// authorization. Each data type can be switched off; a switched-off type is missing evidence, not zero.
@Component
export struct DataConsentPage {
  @Consume('fwNav') nav: NavPathStack;
  @State steps: boolean = true;
  @State restingHeartRate: boolean = true;
  @State sleep: boolean = true;
  @State activityMinutes: boolean = true;
  @State vo2max: boolean = true;
  @State hrv: boolean = true;
  @State workouts: boolean = true;
  @State agreed: boolean = false;

  private chosen(): HealthScope[] {
    const flags: boolean[] = [this.steps, this.restingHeartRate, this.sleep, this.activityMinutes, this.vo2max,
      this.hrv, this.workouts];
    const out: HealthScope[] = [];
    for (let i = 0; i < ALL_HEALTH_SCOPES.length; i++) {
      if (flags[i]) {
        out.push(ALL_HEALTH_SCOPES[i]);
      }
    }
    return out;
  }

  private cancel(): void {
    AddonSession.shared().disconnect();
    this.nav.clear();
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          Text($r('app.string.consent_data_step_label')).attributeModifier(LABEL)
          Text($r('app.string.consent_data_intro'))
            .attributeModifier(BODY)

          Column() {
            ScopeSwitch({ label: scopeLabel(HealthScope.STEPS), isOn: $steps }).id('fw_scope_steps')
            ScopeSwitch({ label: scopeLabel(HealthScope.RESTING_HEART_RATE), isOn: $restingHeartRate })
            ScopeSwitch({ label: scopeLabel(HealthScope.SLEEP), isOn: $sleep })
            ScopeSwitch({ label: scopeLabel(HealthScope.ACTIVITY_MINUTES), isOn: $activityMinutes })
            ScopeSwitch({ label: scopeLabel(HealthScope.VO2MAX), isOn: $vo2max })
            ScopeSwitch({ label: scopeLabel(HealthScope.HRV), isOn: $hrv }).id('fw_scope_hrv')
            ScopeSwitch({ label: scopeLabel(HealthScope.WORKOUTS), isOn: $workouts })
          }
          .attributeModifier(CARD)

          Text($r('app.string.consent_data_switch_off_note'))
            .attributeModifier(CAPTION)

          // The wear month is not filtered by these switches; the page says so.
          Text($r('app.string.consent_data_wear_note'))
            .attributeModifier(CAPTION)
            .id('fw_consent_wear_note')

          Row({ space: 8 }) {
            Checkbox()
              .select(this.agreed)
              .shape(CheckBoxShape.ROUNDED_SQUARE)
              .id('fw_agree_checkbox')
              .onChange((on: boolean) => {
                this.agreed = on;
              })
            Text($r('app.string.consent_data_agree_statement'))
              .attributeModifier(BODY)
              .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)

          Button($r('app.string.consent_data_agree'))
            .buttonStyle(ButtonStyleMode.EMPHASIZED)
            .width('100%')
            .enabled(this.agreed && this.chosen().length > 0)
            .id('fw_agree')
            .onClick(() => {
              if (AddonSession.shared().confirmDataConsent(this.chosen())) {
                this.nav.clear();
              }
            })
          Button($r('app.string.consent_data_cancel'))
            .buttonStyle(ButtonStyleMode.NORMAL)
            .width('100%')
            .id('fw_cancel_consent')
            .onClick(() => {
              this.cancel();
            })
          Text($r('app.string.consent_data_withdraw'))
            .attributeModifier(BODY_SECONDARY)
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
    .title($r('app.string.consent_data_title'))
    .backgroundColor($r('sys.color.background_secondary'))
    .onBackPressed(() => {
      // Leaving without agreeing withdraws the first step too, so nothing stays half-connected.
      this.cancel();
      return true;
    })
  }
}
