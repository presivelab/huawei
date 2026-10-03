import { AbilityConstant, UIAbility, Want } from "@kit.AbilityKit";
import { hilog } from "@kit.PerformanceAnalysisKit";
import { window } from "@kit.ArkUI";

const DOMAIN = 0x0000;
const TAG = "FairWear";

export default class WatchAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, "%{public}s", "WatchAbility onCreate");
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent("pages/Index", (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, "Failed to load the content. Cause: %{public}s", JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, "%{public}s", "WatchAbility content loaded");
    });
  }
}
