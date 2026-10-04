/**
 * WatchAbility: the Health Sim screen on the watch. It shows the simulated day that
 * WatchExportAbility hands to FairWear.
 */
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'HealthSimWatch';

export default class WatchAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'WatchAbility onCreate');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    try {
      windowStage.loadContent('pages/Index', (err: BusinessError) => {
        if (err.code) {
          hilog.error(DOMAIN, TAG, 'Failed to load Index: %{public}s', JSON.stringify(err));
        }
      });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'loadContent threw: %{public}s', JSON.stringify(e));
    }
  }
}
