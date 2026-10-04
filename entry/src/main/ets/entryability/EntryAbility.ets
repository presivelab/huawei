import { AbilityConstant, UIAbility, Want } from "@kit.AbilityKit";
import { hilog } from "@kit.PerformanceAnalysisKit";
import { window } from "@kit.ArkUI";
import { DeviceKey, ProofSigner } from "../platform/ProofSigner";
import { routeFromWant } from "../nav/EntryRouter";
import { attachReportStore } from "../report/ServiceLocator";
import { WatchLinkService } from "../watchlink/WatchLinkService";

const DOMAIN = 0x0000;
const TAG = "FairWear";

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, "%{public}s", "EntryAbility onCreate");
    // Probe the keystore once; the key that passes signs for the whole session.
    ProofSigner.shared().ensureKey().then((key: DeviceKey) => {
      hilog.info(DOMAIN, TAG, "signing key: %{public}s kid=%{public}s (%{public}s)", key.source, key.kid, key.note);
    }).catch((e: Error) => {
      hilog.error(DOMAIN, TAG, "signing key unavailable: %{public}s", e.message);
    });
    hilog.info(DOMAIN, TAG, "entry target: %{public}s", routeFromWant(want));
    // Health Sim data received in an earlier session (after the user's consent) is used again.
    attachReportStore(this.context.filesDir);
    // Watch Link: restore the pinned watch and its chain; packets are read when the app comes to the front.
    WatchLinkService.shared().init(this.context);
  }

  // The app is already running and a card tap, an icon shortcut or a host app starts it again.
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, "entry target (new want): %{public}s", routeFromWant(want));
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent("pages/Index", (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, "Failed to load the content. Cause: %{public}s", JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, "%{public}s", "EntryAbility content loaded");
    });
  }

  onForeground(): void {
    WatchLinkService.shared().onForeground();
  }

  onBackground(): void {
    WatchLinkService.shared().onBackground();
  }
}
