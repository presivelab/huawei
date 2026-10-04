/**
 * AuthAbility: the consent screen another app opens to read the simulated data.
 * FairWear starts it for a result with the bundle and ability name and the Want parameter `fwScopes`
 * (names of the data types it asks for). The answer goes back with terminateSelfWithResult (see AuthPage).
 */
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { KEY_AUTH_SCOPES } from '../pages/AuthPage';

const DOMAIN: number = 0x0000;
const TAG: string = 'HealthSimAuth';
const PARAM_SCOPES: string = 'fwScopes';
const SCOPES_MAX: number = 32;

// The requested data type names of a Want: texts only, at most SCOPES_MAX of them. Anything else is ignored.
function scopeNames(want: Want): string[] {
  const out: string[] = [];
  if (want.parameters === undefined) {
    return out;
  }
  const raw: Object | undefined = want.parameters[PARAM_SCOPES];
  if (raw === undefined || !Array.isArray(raw)) {
    return out;
  }
  const list = raw as Object[];
  for (let i = 0; i < list.length && out.length < SCOPES_MAX; i++) {
    if (typeof list[i] === 'string') {
      out.push(list[i] as string);
    }
  }
  return out;
}

export default class AuthAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppStorage.setOrCreate<string[]>(KEY_AUTH_SCOPES, scopeNames(want));
    hilog.info(DOMAIN, TAG, '%{public}s', 'Auth request received');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppStorage.setOrCreate<string[]>(KEY_AUTH_SCOPES, scopeNames(want));
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
