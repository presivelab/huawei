import { common } from '@kit.AbilityKit';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';
import { wearEngine } from '@kit.WearEngine';
import { DayTransport } from 'common';

const DOMAIN = 0x0000;
const TAG = 'FairWear';
const SYSCAP = 'SystemCapability.Health.WearEngine';
// One Wear Engine P2P message carries at most 4096 bytes; day packets are kept under 3800.
const MAX_MESSAGE_BYTES = 4096;
const LOCAL_CONFIG = 'local.json';

// rawfile/local.json (not in the repository; see local.example.json): the phone app this watch talks to.
class LocalConfig {
  phoneBundleName: string = '';
  phoneFingerprint: string = '';
}

/*
 * Direct watch -> phone path over Wear Engine P2P messages.
 *
 * Works only on a real watch paired with a phone through the Huawei Health app, with both FairWear apps
 * running and the Wear Engine service approved for the app in AppGallery Connect. On an emulator there is
 * no paired device, so this reports "unavailable" and the outbox files (carried by the dev relay) are the
 * only path. A failure here never blocks the outbox.
 *
 * NOT VERIFIED on paired devices: this code path compiles against the SDK and has not been run end to end.
 */
export class WearEngineTransport implements DayTransport {
  private context: common.UIAbilityContext;
  private statusText: string = 'Wear Engine not tried yet';
  private remote: wearEngine.AppInfo | null = null;
  private configRead: boolean = false;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  name(): string {
    return 'Wear Engine';
  }

  status(): string {
    return this.statusText;
  }

  async isAvailable(): Promise<boolean> {
    if (!canIUse(SYSCAP)) {
      this.statusText = this.unavailable('not supported on this device');
      return false;
    }
    if (this.remoteApp() === null) {
      this.statusText = 'Wear Engine not configured (no rawfile/local.json)';
      return false;
    }
    const peer = await this.peer();
    return peer !== null;
  }

  async send(json: string): Promise<string> {
    const remote = this.remoteApp();
    const peer = await this.peer();
    if (remote === null || peer === null) {
      throw new Error(this.statusText);
    }
    const content = new util.TextEncoder().encodeInto(json);
    if (content.length > MAX_MESSAGE_BYTES) {
      // TODO(watch-link): fall back to P2pClient.transferFile for a packet above the message limit.
      // Day packets are capped at 3800 bytes, so this is not reached today.
      this.statusText = `Wear Engine: packet too large (${content.length} bytes)`;
      throw new Error(this.statusText);
    }
    try {
      const appParam: wearEngine.P2pAppParam = { remoteApp: remote };
      const message: wearEngine.P2pMessage = { content: content };
      const result = await wearEngine.getP2pClient(this.context).sendMessage(peer.randomId, appParam, message);
      this.statusText = `Wear Engine: sent (${result.code})`;
      return this.statusText;
    } catch (e) {
      this.statusText = this.unavailable(WearEngineTransport.errText(e as BusinessError));
      throw new Error(this.statusText);
    }
  }

  // Incoming messages from the phone (ACKs). The callback gets the message text.
  async startReceiver(onText: (text: string) => void): Promise<boolean> {
    const remote = this.remoteApp();
    if (!canIUse(SYSCAP) || remote === null) {
      return false;
    }
    const peer = await this.peer();
    if (peer === null) {
      return false;
    }
    try {
      const appParam: wearEngine.P2pAppParam = { remoteApp: remote };
      await wearEngine.getP2pClient(this.context).registerMessageReceiver(peer.randomId, appParam,
        (message: wearEngine.P2pMessage) => {
          onText(util.TextDecoder.create('utf-8').decodeToString(message.content));
        });
      return true;
    } catch (e) {
      this.statusText = this.unavailable(WearEngineTransport.errText(e as BusinessError));
      return false;
    }
  }

  // The connected phone, or null.
  private async peer(): Promise<wearEngine.Device | null> {
    try {
      const devices = await wearEngine.getDeviceClient(this.context).getConnectedDevices();
      if (devices.length === 0) {
        this.statusText = this.unavailable('no connected phone');
        return null;
      }
      return devices[0];
    } catch (e) {
      this.statusText = this.unavailable(WearEngineTransport.errText(e as BusinessError));
      return null;
    }
  }

  private remoteApp(): wearEngine.AppInfo | null {
    if (this.configRead) {
      return this.remote;
    }
    this.configRead = true;
    try {
      const bytes = this.context.resourceManager.getRawFileContentSync(LOCAL_CONFIG);
      const text = util.TextDecoder.create('utf-8').decodeToString(bytes);
      const config = JSON.parse(text) as LocalConfig;
      if (typeof config.phoneBundleName === 'string' && config.phoneBundleName.length > 0 &&
        typeof config.phoneFingerprint === 'string' && config.phoneFingerprint.length > 0) {
        const app: wearEngine.AppInfo = {
          bundleName: config.phoneBundleName,
          fingerprint: config.phoneFingerprint
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
