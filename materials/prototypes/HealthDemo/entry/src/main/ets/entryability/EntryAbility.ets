import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { HealthEngine } from '../model/HealthEngine';
import { ScreenAwake } from '../model/ScreenAwake';

const DOMAIN = 0x0002;
const TAG = 'HealthDemo';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    HealthEngine.get().init(this.context);
    ScreenAwake.init(this.context);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    try {
      ScreenAwake.attach(windowStage.getMainWindowSync());
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'main window unavailable: %{public}s', JSON.stringify(err));
    }
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}s', JSON.stringify(err));
      }
    });
  }

  onForeground(): void {
    HealthEngine.get().setForeground(true);
    ScreenAwake.setForeground(true);
  }

  onBackground(): void {
    HealthEngine.get().setForeground(false);
    ScreenAwake.setForeground(false);
  }

  onDestroy(): void {
    HealthEngine.get().stopSensors();
  }
}
