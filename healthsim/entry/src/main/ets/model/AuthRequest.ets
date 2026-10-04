/**
 * A data request from another app (FairWear), parsed from the incoming Want.
 * Accepts types/days/requester from Want parameters or from the deep-link query:
 *   healthsim://authorize?types=hh.steps.delta,hh.heart_rate&days=30&requester=FairWear
 */
import { Want } from '@kit.AbilityKit';
import { HsDataType, MAX_DAYS } from '../healthsim/HsTypes';
import { HsWantKeys } from '../healthsim/HsCodec';

export const AUTH_REQUEST_KEY: string = 'healthsim.authRequest';
const CALLER_BUNDLE_KEY: string = 'ohos.aafwk.param.callerBundleName';

export class AuthRequest {
  requester: string = '';
  callerBundle: string = '';
  types: string[] = [];
  days: number = MAX_DAYS;
  receivedAt: number = 0;
}

function queryValue(uri: string, key: string): string {
  const q: number = uri.indexOf('?');
  if (q < 0) {
    return '';
  }
  const pairs: string[] = uri.substring(q + 1).split('&');
  for (let i = 0; i < pairs.length; i++) {
    const eq: number = pairs[i].indexOf('=');
    if (eq > 0 && pairs[i].substring(0, eq) === key) {
      return decodeURIComponent(pairs[i].substring(eq + 1));
    }
  }
  return '';
}

function paramString(want: Want, key: string): string {
  const params: Record<string, Object> | undefined = want.parameters;
  if (params === undefined) {
    return '';
  }
  const v: Object | undefined = params[key];
  if (v === undefined || v === null) {
    return '';
  }
  if (typeof v === 'string') {
    return v as string;
  }
  if (typeof v === 'number') {
    return String(v as number);
  }
  if (Array.isArray(v)) {
    return (v as string[]).join(',');
  }
  return '';
}

export function parseAuthRequest(want: Want): AuthRequest {
  const r: AuthRequest = new AuthRequest();
  const uri: string = want.uri !== undefined ? want.uri : '';
  let types: string = paramString(want, HsWantKeys.TYPES);
  if (types.length === 0) {
    types = queryValue(uri, HsWantKeys.TYPES);
  }
  const list: string[] = types.length > 0 ? types.split(',') : HsDataType.all();
  for (let i = 0; i < list.length; i++) {
    const t: string = list[i].trim();
    if (HsDataType.isKnown(t) && r.types.indexOf(t) < 0) {
      r.types.push(t);
    }
  }
  let days: string = paramString(want, HsWantKeys.DAYS);
  if (days.length === 0) {
    days = queryValue(uri, HsWantKeys.DAYS);
  }
  const n: number = days.length > 0 ? Number.parseInt(days) : MAX_DAYS;
  r.days = Number.isNaN(n) ? MAX_DAYS : Math.max(1, Math.min(MAX_DAYS, n));
  r.requester = paramString(want, HsWantKeys.REQUESTER);
  if (r.requester.length === 0) {
    r.requester = queryValue(uri, HsWantKeys.REQUESTER);
  }
  r.callerBundle = paramString(want, CALLER_BUNDLE_KEY);
  if (r.requester.length === 0) {
    r.requester = r.callerBundle.length > 0 ? r.callerBundle : 'App';
  }
  r.receivedAt = Date.now();
  return r;
}
