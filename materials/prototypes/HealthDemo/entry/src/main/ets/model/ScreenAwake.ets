import { window } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0002;
const TAG = 'HealthDemo';
const STORE_NAME = 'settings';
const STORE_KEY = 'keep_screen_on';

export const AWAKE_OFF = 'off';
export const AWAKE_ON = 'on';

// Holds the screen on while the app is in the foreground and the setting is enabled.
export class ScreenAwake {
  private static store: preferences.Preferences | null = null;
  private static mainWindow: window.Window | null = null;
  private static enabled: boolean = true;
  private static foreground: boolean = false;

  static init(context: common.Context): void {
    try {
      ScreenAwake.store = preferences.getPreferencesSync(context, { name: STORE_NAME });
      ScreenAwake.enabled = ScreenAwake.store.getSync(STORE_KEY, true) as boolean;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'settings load failed: %{public}s', JSON.stringify(err));
    }
    AppStorage.setOrCreate('hd_keep_on', ScreenAwake.enabled);
    AppStorage.setOrCreate('hd_keep_on_state', AWAKE_OFF);
  }

  static attach(mainWindow: window.Window): void {
    ScreenAwake.mainWindow = mainWindow;
  }

  static setForeground(foreground: boolean): void {
    ScreenAwake.foreground = foreground;
    ScreenAwake.apply();
  }

  static setEnabled(enabled: boolean): void {
    if (enabled === ScreenAwake.enabled) {
      return;
    }
    ScreenAwake.enabled = enabled;
    AppStorage.setOrCreate('hd_keep_on', enabled);
    try {
      ScreenAwake.store?.putSync(STORE_KEY, enabled);
      ScreenAwake.store?.flush();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'settings save failed: %{public}s', JSON.stringify(err));
    }
    ScreenAwake.apply();
  }

  private static apply(): void {
    if (ScreenAwake.mainWindow === null) {
      return;
    }
    const keepOn = ScreenAwake.enabled && ScreenAwake.foreground;
    ScreenAwake.mainWindow.setWindowKeepScreenOn(keepOn).then(() => {
      AppStorage.setOrCreate('hd_keep_on_state', keepOn ? AWAKE_ON : AWAKE_OFF);
      hilog.info(DOMAIN, TAG, 'keepScreenOn=%{public}s', keepOn ? AWAKE_ON : AWAKE_OFF);
    }).catch((err: BusinessError) => {
      AppStorage.setOrCreate('hd_keep_on_state', `error ${err.code}`);
      hilog.warn(DOMAIN, TAG, 'keepScreenOn failed: %{public}s', JSON.stringify(err));
    });
  }
}
