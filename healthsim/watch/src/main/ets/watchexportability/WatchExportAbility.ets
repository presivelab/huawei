/**
 * WatchExportAbility: hands the simulated day to FairWear on the same watch.
 * FairWear starts it with startAbilityForResult; it answers at once and closes, without a screen and
 * without a question (consent was given in Health Sim on the phone). The answer is the day script as
 * text under the parameter 'fwhsw1' (HEALTH_SIM_WATCH_PARAM), result code 0.
 */
import { AbilityConstant, common, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { BUILT_IN_SCRIPT, encodeWatchScript, HEALTH_SIM_WATCH_PARAM } from 'common';

const DOMAIN: number = 0x0000;
const TAG: string = 'HealthSimWatch';
const RESULT_OK: number = 0;

export default class WatchExportAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Export requested');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.answer();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.answer();
  }

  private answer(): void {
    const parameters: Record<string, Object> = {};
    parameters[HEALTH_SIM_WATCH_PARAM] = encodeWatchScript(BUILT_IN_SCRIPT);
    const want: Want = { parameters: parameters };
    const result: common.AbilityResult = { resultCode: RESULT_OK, want: want };
    this.context.terminateSelfWithResult(result).then(() => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'Day script handed over');
    }).catch((e: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'terminateSelfWithResult failed: %{public}d', e.code);
    });
  }
}
