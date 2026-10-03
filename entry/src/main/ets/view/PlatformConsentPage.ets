import { ALL_HEALTH_SCOPES, HealthScope, HealthStatus } from 'common';
import { AddonSession } from '../addon/AddonSession';
import { ROUTE_DATA_CONSENT, scopeLabel } from '../addon/AddonTexts';
import { BODY, BODY_SECONDARY, CAPTION, LABEL, TITLE } from './Styles';

// AD-2, step 1. HUAWEI Health shows its own authorization screen at this point. FairWear does not copy it:
// this is a neutral DEMO placeholder that lists the data types FairWear asks for and lets the demo
// operator simulate the user's answer.
@Component
export struct PlatformConsentPage {
  @Consume('fwNav') nav: NavPathStack;
  private unavailable: boolean = AddonSession.shared().platformStatus() === HealthStatus.UNAVAILABLE;

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          Text('Step 1 of 2 · HUAWEI Health authorization').attributeModifier(LABEL)

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
