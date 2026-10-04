/**
 * FairWear side: asks Health Sim for data and returns a healthStore-shaped store.
 *
 * 1. openLink('healthsim://authorize?...') with a result callback (Deep Linking, API 12+).
 * 2. If no app answers the link, explicit startAbilityForResult to com.fairwear.healthsim/AuthAbility.
 * 3. If Health Sim is not installed at all, connectLocal() generates the same data inside FairWear
 *    (same persona, seed and demo anchor give the same Data ID) and labels it as local.
 *
 * Copy this folder (healthsim/) into FairWear's common module unchanged.
 */
import { common, OpenLinkOptions, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { HsCodec, HsSyncDelay, HsWantKeys } from './HsCodec';
import { DEMO_ANCHOR_MS, HsGenerator } from './HsGenerator';
import { HsPersonas } from './HsPersonas';
import { HsSimStore } from './HsStore';
import {
  HS_AUTH_ABILITY,
  HS_AUTH_LINK,
  HS_BUNDLE_NAME,
  HS_RESULT_GRANTED,
  HsDataset,
  HsDataType,
  MAX_DAYS,
  MINUTE_MS
} from './HsTypes';

export class HsConnectStatus {
  static readonly GRANTED: string = 'granted';
  static readonly DENIED: string = 'denied';
  static readonly NOT_INSTALLED: string = 'not_installed';
  static readonly ERROR: string = 'error';
}

export class HsConnectResult {
  status: string = HsConnectStatus.ERROR;
  /** 'healthsim-app' when data came from the simulator app, 'local' for connectLocal(). */
  origin: string = '';
  store: HsSimStore | null = null;
  message: string = '';
}

/** Business error code: no ability matches the link. */
const NO_MATCHING_ABILITY: number = 16000019;
/** Business error code: the specified ability does not exist. */
const ABILITY_NOT_FOUND: number = 16000001;

function resultFrom(result: common.AbilityResult): HsConnectResult {
  const r: HsConnectResult = new HsConnectResult();
  r.origin = 'healthsim-app';
  const params: Record<string, Object> | undefined = result.want !== undefined ? result.want.parameters : undefined;
  const payload: Object | undefined = params !== undefined ? params[HsWantKeys.PAYLOAD] : undefined;
  if (result.resultCode !== HS_RESULT_GRANTED || payload === undefined || typeof payload !== 'string') {
    r.status = HsConnectStatus.DENIED;
    r.message = 'User did not allow access (resultCode ' + String(result.resultCode) + ')';
    return r;
  }
  try {
    r.store = HsSimStore.fromPayloadJson(payload as string);
    r.status = HsConnectStatus.GRANTED;
  } catch (e) {
    r.status = HsConnectStatus.ERROR;
    r.message = 'Invalid payload: ' + String(e);
  }
  return r;
}

function failure(status: string, message: string): HsConnectResult {
  const r: HsConnectResult = new HsConnectResult();
  r.status = status;
  r.message = message;
  return r;
}

function buildParams(types: string[], days: number, requester: string): Record<string, Object> {
  const params: Record<string, Object> = {};
  params[HsWantKeys.TYPES] = types.join(',');
  params[HsWantKeys.DAYS] = String(Math.max(1, Math.min(MAX_DAYS, Math.round(days))));
  params[HsWantKeys.REQUESTER] = requester;
  return params;
}

export class HealthSimClient {
  /**
   * Opens the Health Sim consent screen and resolves with the store (never rejects).
   * @param context the caller's UIAbilityContext (getUIContext().getHostContext())
   * @param types HsDataType values to request; the user can untick some
   * @param days 1..30
   * @param requester name shown on the consent screen, e.g. 'FairWear'
   */
  static connect(context: common.UIAbilityContext, types: string[], days: number,
    requester: string): Promise<HsConnectResult> {
    return new Promise<HsConnectResult>((resolve: (value: HsConnectResult) => void) => {
      const params: Record<string, Object> = buildParams(types, days, requester);
      const link: string = HS_AUTH_LINK + '?requester=' + encodeURIComponent(requester);
      const options: OpenLinkOptions = { appLinkingOnly: false, parameters: params };
      try {
        context.openLink(link, options, (err: BusinessError, result: common.AbilityResult) => {
          if (err !== undefined && err !== null && err.code) {
            resolve(failure(HsConnectStatus.ERROR, 'openLink result error ' + String(err.code)));
            return;
          }
          resolve(resultFrom(result));
        }).catch((err: BusinessError) => {
          if (err.code === NO_MATCHING_ABILITY || err.code === ABILITY_NOT_FOUND) {
            HealthSimClient.connectExplicit(context, params).then((r: HsConnectResult) => {
              resolve(r);
            });
            return;
          }
          resolve(failure(HsConnectStatus.ERROR, 'openLink failed ' + String(err.code) + ': ' + err.message));
        });
      } catch (e) {
        resolve(failure(HsConnectStatus.ERROR, 'openLink threw: ' + String(e)));
      }
    });
  }

  /** Fallback: explicit start of the simulator's AuthAbility. */
  static connectExplicit(context: common.UIAbilityContext, params: Record<string, Object>): Promise<HsConnectResult> {
    const want: Want = { bundleName: HS_BUNDLE_NAME, abilityName: HS_AUTH_ABILITY, parameters: params };
    return new Promise<HsConnectResult>((resolve: (value: HsConnectResult) => void) => {
      try {
        context.startAbilityForResult(want).then((result: common.AbilityResult) => {
          resolve(resultFrom(result));
        }).catch((err: BusinessError) => {
          if (err.code === ABILITY_NOT_FOUND || err.code === NO_MATCHING_ABILITY) {
            resolve(failure(HsConnectStatus.NOT_INSTALLED, 'Health Sim is not installed'));
            return;
          }
          resolve(failure(HsConnectStatus.ERROR, 'startAbilityForResult failed ' + String(err.code)));
        });
      } catch (e) {
        resolve(failure(HsConnectStatus.ERROR, 'startAbilityForResult threw: ' + String(e)));
      }
    });
  }

  /**
   * Last-resort fallback without the simulator app: same generator, same demo anchor,
   * so the Data ID matches what Health Sim shows in demo mode. Label it as local in the UI.
   */
  static connectLocal(personaId: string, seed: number, days: number, types: string[],
    simulateSyncDelay: boolean): HsConnectResult {
    const ds: HsDataset = HsGenerator.generate(HsPersonas.byId(personaId), seed, DEMO_ANCHOR_MS, days);
    const granted: string[] = types.length > 0 ? types : HsDataType.all();
    const syncTimes: number[] = [];
    for (let i = 0; i < granted.length; i++) {
      const delay: number = simulateSyncDelay ? HsSyncDelay.minutesFor(granted[i]) : 0;
      syncTimes.push(ds.anchorMs - delay * MINUTE_MS);
    }
    const r: HsConnectResult = new HsConnectResult();
    r.status = HsConnectStatus.GRANTED;
    r.origin = 'local';
    r.store = new HsSimStore(ds, granted, granted.slice(0), syncTimes, HsCodec.datasetId(ds));
    return r;
  }
}
