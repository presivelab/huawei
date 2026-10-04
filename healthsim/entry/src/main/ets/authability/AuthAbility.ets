/**
 * AuthAbility: the consent screen other apps open to read simulated data.
 * Started by FairWear via openLink('healthsim://authorize?...') with a result callback
 * (or startAbilityForResult as a fallback). Returns the payload with terminateSelfWithResult.
 */
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { AUTH_REQUEST_KEY, AuthRequest, parseAuthRequest } from '../model/AuthRequest';

const DOMAIN: number = 0x0000;
const TAG: string = 'HealthSimAuth';

export default class AuthAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppStorage.setOrCreate<AuthRequest>(AUTH_REQUEST_KEY, parseAuthRequest(want));
    hilog.info(DOMAIN, TAG, '%{public}s', 'Auth request received');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppStorage.setOrCreate<AuthRequest>(AUTH_REQUEST_KEY, parseAuthRequest(want));
    hilog.info(DOMAIN, TAG, '%{public}s', 'Auth request updated');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    try {
      windowStage.loadContent('pages/AuthPage', (err: BusinessError) => {
        if (err.code) {
          hilog.error(DOMAIN, TAG, 'Failed to load AuthPage: %{public}s', JSON.stringify(err));
        }
      });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'loadContent threw: %{public}s', JSON.stringify(e));
    }
  }
}
