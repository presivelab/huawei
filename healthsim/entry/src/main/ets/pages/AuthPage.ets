import { common } from '@kit.AbilityKit';
import { ALL_HEALTH_SCOPES, HealthScope } from '../fw/health/HealthConnection';
import {
  encodeHealthSimPayload,
  HEALTH_SIM_PARAM,
  healthSimPayloadFromPersonas,
  withScopes
} from '../fw/health/HealthSimPayload';
import { scopeLabel, scopeOf } from '../data/SimData';
import {
  AUTH_ALLOW,
  AUTH_DENY,
  AUTH_FAILED,
  AUTH_LIST_TITLE,
  AUTH_NOTE,
  AUTH_STANDS_IN,
  AUTH_TITLE
} from '../data/SimTexts';
import { CARD, SimBanner } from '../ui/SimBanner';

// AppStorage: the data type names the calling app asked for (Want parameter `fwScopes`).
export const KEY_AUTH_SCOPES: string = 'hsAuthScopes';

const RESULT_ALLOWED: number = 0;
const RESULT_DENIED: number = 1;

// One requested data type and whether the person lets FairWear read it.
interface ScopeChoice {
  scope: HealthScope;
  label: string;
  allowed: boolean;
}

// The scopes of a request, in the order Health Sim lists them. Names it does not know are left out; a
// request without a list asks for every type.
function requested(names: string[]): HealthScope[] {
  const out: HealthScope[] = [];
  for (let i = 0; i < ALL_HEALTH_SCOPES.length; i++) {
    for (let n = 0; n < names.length; n++) {
      if (scopeOf(names[n]) === ALL_HEALTH_SCOPES[i]) {
        out.push(ALL_HEALTH_SCOPES[i]);
        break;
      }
    }
  }
  return out.length > 0 ? out : ALL_HEALTH_SCOPES.slice();
}

// The consent screen FairWear opens for a result. "Allow" hands over the simulated history of the six
// people with the switched-off types blanked; "Don't allow" hands over nothing.
@Entry
@Component
struct AuthPage {
  @StorageProp(KEY_AUTH_SCOPES) @Watch('onRequest') names: string[] = [];
  @State choices: ScopeChoice[] = [];
  @State failed: boolean = false;

  aboutToAppear(): void {
    this.onRequest();
  }

  // A new request: every requested type starts switched on.
  onRequest(): void {
    const scopes = requested(this.names);
    const next: ScopeChoice[] = [];
    for (let i = 0; i < scopes.length; i++) {
      next.push({ scope: scopes[i], label: scopeLabel(scopes[i]), allowed: true });
    }
    this.choices = next;
    this.failed = false;
  }

  private setAllowed(scope: HealthScope, allowed: boolean): void {
    const next: ScopeChoice[] = [];
    for (let i = 0; i < this.choices.length; i++) {
      const c = this.choices[i];
      next.push({ scope: c.scope, label: c.label, allowed: c.scope === scope ? allowed : c.allowed });
    }
    this.choices = next;
  }

  private allowedScopes(): HealthScope[] {
    const out: HealthScope[] = [];
    for (let i = 0; i < this.choices.length; i++) {
      if (this.choices[i].allowed) {
        out.push(this.choices[i].scope);
      }
    }
    return out;
  }

  private answer(allow: boolean): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const parameters: Record<string, Object> = {};
    if (allow) {
      parameters[HEALTH_SIM_PARAM] =
        encodeHealthSimPayload(withScopes(healthSimPayloadFromPersonas(), this.allowedScopes()));
    }
    try {
      context.terminateSelfWithResult({
        resultCode: allow ? RESULT_ALLOWED : RESULT_DENIED,
        want: { parameters: parameters }
      }).catch(() => {
        this.failed = true;
      });
    } catch (e) {
      this.failed = true;
    }
  }

  build() {
    Column() {
      SimBanner()

      Scroll() {
        Column({ space: 14 }) {
          Text(AUTH_TITLE)
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .id('hs_auth_title')
          Text(AUTH_STANDS_IN)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_secondary'))

          Column({ space: 2 }) {
            Text(AUTH_LIST_TITLE)
              .fontSize($r('sys.float.Subtitle_M'))
              .fontWeight(600)
              .fontColor($r('sys.color.font_primary'))
              .padding({ bottom: 6 })
            ForEach(this.choices, (choice: ScopeChoice) => {
              Row({ space: 12 }) {
                Text(choice.label)
                  .fontSize($r('sys.float.Body_L'))
                  .fontColor($r('sys.color.font_primary'))
                  .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: choice.allowed })
                  .id(`hs_scope_${choice.scope}`)
                  .accessibilityText(choice.label)
                  .onChange((isOn: boolean) => {
                    this.setAllowed(choice.scope, isOn);
                  })
              }
              .width('100%')
              .constraintSize({ minHeight: 48 })
              .alignItems(VerticalAlign.Center)
            }, (choice: ScopeChoice) => `${choice.scope}`)
          }
          .attributeModifier(CARD)

          Text(AUTH_NOTE)
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_secondary'))
            .padding({ left: 4, right: 4 })

          if (this.failed) {
            Text(AUTH_FAILED)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.warning'))
              .padding({ left: 4, right: 4 })
          }
        }
        .padding({
          left: 16,
          right: 16,
          top: 16,
          bottom: 16
        })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)

      Row({ space: 12 }) {
        Button(AUTH_DENY)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .layoutWeight(1)
          .height(48)
          .id('hs_auth_deny')
          .onClick(() => {
            this.answer(false);
          })
        Button(AUTH_ALLOW)
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .layoutWeight(1)
          .height(48)
          .id('hs_auth_allow')
          .onClick(() => {
            this.answer(true);
          })
      }
      .width('100%')
      .padding({
        left: 16,
        right: 16,
        top: 8,
        bottom: 24
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
