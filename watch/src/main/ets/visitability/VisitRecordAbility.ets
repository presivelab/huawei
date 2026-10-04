import { AbilityConstant, UIAbility, Want } from "@kit.AbilityKit";
import { hilog } from "@kit.PerformanceAnalysisKit";
import { window } from "@kit.ArkUI";

const DOMAIN = 0x0000;
const TAG = "FairWear";

// "Visit notes" on the watch: its own entry in the app list, so the recorder of the wear day
// (WatchAbility) stays as it is. Loads pages/VisitRecord.
export default class VisitRecordAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, "%{public}s", "VisitRecordAbility onCreate");
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent("pages/VisitRecord", (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, "Failed to load the content. Cause: %{public}s", JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, "%{public}s", "VisitRecordAbility content loaded");
    });
  }
}
