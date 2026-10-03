import { common } from '@kit.AbilityKit';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';
import { wearEngine } from '@kit.WearEngine';

const DOMAIN = 0x0000;
const TAG = 'FairWear';
const SYSCAP = 'SystemCapability.Health.WearEngine';
const LOCAL_CONFIG = 'local.json';

// rawfile/local.json (not in the repository; see local.example.json): the watch app this phone talks to.
class LocalConfig {
  watchBundleName: string = '';
  watchFingerprint: string = '';
}

/*
 * Phone side of the direct watch -> phone path: Wear Engine P2P messages.
 *
 * Works only with a real watch paired through the Huawei Health app, both FairWear apps running, and the
 * Wear Engine service approved for the app in AppGallery Connect. On an emulator there is no paired device:
 * this reports "unavailable" and packets arrive through inbox/ files carried by the dev relay.
 *
 * NOT VERIFIED on paired devices: this code path compiles against the SDK and has not been run end to end.
 */
export class WearEngineReceiver {
  private context: common.UIAbilityContext;
  private statusText: string = 'Wear Engine not tried yet';
  private remote: wearEngine.AppInfo | null = null;
  private peerId: string = '';

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  status(): string {
    return this.statusText;
  }

  isConnected(): boolean {
    return this.peerId.length > 0;
  }

  filesDir(): string {
    return this.context.getApplicationContext().filesDir;
  }

  // Registers for messages from the watch app. The callback gets the message text (a packet as JSON).
  start(onText: (text: string) => void): void {
    this.register(onText).catch((e: BusinessError) => {
      this.statusText = this.unavailable(WearEngineReceiver.errText(e));
    });
  }

  // Sends one ACK back to the watch. Failures are logged; the ACK file stays for the next try.
  send(json: string): void {
    const remote = this.remote;
    if (remote === null || this.peerId.length === 0) {
      return;
    }
    const appParam: wearEngine.P2pAppParam = { remoteApp: remote };
    const message: wearEngine.P2pMessage = { content: new util.TextEncoder().encodeInto(json) };
    wearEngine.getP2pClient(this.context).sendMessage(this.peerId, appParam, message).catch((e: BusinessError) => {
      hilog.warn(DOMAIN, TAG, 'wear engine ACK not sent: %{public}s', WearEngineReceiver.errText(e));
    });
  }

  private async register(onText: (text: string) => void): Promise<void> {
    if (!canIUse(SYSCAP)) {
      this.statusText = this.unavailable('not supported on this device');
      return;
    }
    const remote = this.remoteApp();
    if (remote === null) {
      this.statusText = 'Wear Engine not configured (no rawfile/local.json)';
      return;
    }
    try {
      const devices = await wearEngine.getDeviceClient(this.context).getConnectedDevices();
      if (devices.length === 0) {
        this.statusText = this.unavailable('no connected watch');
        return;
      }
      const appParam: wearEngine.P2pAppParam = { remoteApp: remote };
      await wearEngine.getP2pClient(this.context).registerMessageReceiver(devices[0].randomId, appParam,
        (message: wearEngine.P2pMessage) => {
          onText(util.TextDecoder.create('utf-8').decodeToString(message.content));
        });
      this.peerId = devices[0].randomId;
      this.statusText = 'Wear Engine: listening';
    } catch (e) {
      this.statusText = this.unavailable(WearEngineReceiver.errText(e as BusinessError));
    }
  }

  private remoteApp(): wearEngine.AppInfo | null {
    if (this.remote !== null) {
      return this.remote;
    }
    try {
      const bytes = this.context.resourceManager.getRawFileContentSync(LOCAL_CONFIG);
      const config = JSON.parse(util.TextDecoder.create('utf-8').decodeToString(bytes)) as LocalConfig;
      if (typeof config.watchBundleName === 'string' && config.watchBundleName.length > 0 &&
        typeof config.watchFingerprint === 'string' && config.watchFingerprint.length > 0) {
        const app: wearEngine.AppInfo = {
          bundleName: config.watchBundleName,
          fingerprint: config.watchFingerprint
        };
        this.remote = app;
      }
    } catch (e) {
      hilog.info(DOMAIN, TAG, 'wear engine: no %{public}s in rawfile', LOCAL_CONFIG);
    }
    return this.remote;
  }

  private unavailable(why: string): string {
    const model = `${deviceInfo.productModel} ${deviceInfo.marketName}`.toLowerCase();
    if (model.indexOf('emulator') >= 0) {
      return 'Wear Engine unavailable (emulator)';
    }
    return `Wear Engine unavailable (${why})`;
  }

  private static errText(err: BusinessError): string {
    if (err === undefined || err === null) {
      return 'unknown error';
    }
    return err.code !== undefined ? `${err.code}` : `${err.message}`;
  }
}
