import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

/*
 * Zgoda w aplikacji = uprawnienie systemowe. Tętno prosimy o READ_HEALTH_DATA tylko przy zgodzie na tętno.
 */

export class PermissionOutcome {
  granted: string[] = [];
  denied: string[] = [];
  error: string = '';
}

export class PermissionHelper {
  static readonly HEALTH: Permissions = 'ohos.permission.READ_HEALTH_DATA';
  static readonly MOTION: Permissions = 'ohos.permission.ACTIVITY_MOTION';

  static forConsents(heartRate: boolean): Permissions[] {
    const list: Permissions[] = [PermissionHelper.MOTION];
    if (heartRate) {
      list.push(PermissionHelper.HEALTH);
    }
    return list;
  }

  static async request(context: common.Context, perms: Permissions[]): Promise<PermissionOutcome> {
    const out = new PermissionOutcome();
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const res = await atManager.requestPermissionsFromUser(context, perms);
      for (let i = 0; i < res.permissions.length; i++) {
        if (res.authResults[i] === 0) {
          out.granted.push(res.permissions[i]);
        } else {
          out.denied.push(res.permissions[i]);
        }
      }
    } catch (e) {
      const err = e as BusinessError;
      out.error = `${err.code}: ${err.message}`;
    }
    return out;
  }
}
