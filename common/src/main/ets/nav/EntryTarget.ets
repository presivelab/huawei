/*
 * The single entry into FairWear. A home-screen card, an icon shortcut or a host app opens the same
 * ability with one optional parameter, `fwTarget`, and this function decides which screen that means.
 *
 * The value comes from outside the app, so it is treated as untrusted input:
 * anything that is not exactly one of the known targets opens the dashboard. It never throws.
 */

export const FW_TARGET_PARAM: string = 'fwTarget';

export class FwTarget {
  static readonly DASHBOARD: string = 'dashboard';
  static readonly SHARE: string = 'share';
  static readonly SOURCE: string = 'source';
}

/** A home-screen card delivers its parameters as one JSON string under this key of the want. */
export const CARD_PARAMS_KEY: string = 'params';

const MAX_TARGET_LENGTH: number = 32;
const MAX_CARD_PARAMS_LENGTH: number = 512;

/*
 * Reads the target from the two places it can arrive in:
 *  - `direct`: want.parameters['fwTarget'], set by an icon shortcut or a host app;
 *  - `cardParams`: want.parameters['params'], the JSON string a card tap sends.
 * A direct string wins. Malformed JSON, a non-object or an oversized string opens the dashboard.
 */
export function resolveFwTargetFromWant(direct: Object | null | undefined,
  cardParams: Object | null | undefined): string {
  if (typeof direct === 'string') {
    return resolveFwTarget(direct);
  }
  if (typeof cardParams !== 'string') {
    return FwTarget.DASHBOARD;
  }
  const text: string = cardParams as string;
  if (text.length === 0 || text.length > MAX_CARD_PARAMS_LENGTH) {
    return FwTarget.DASHBOARD;
  }
  let parsed: Record<string, Object>;
  try {
    parsed = JSON.parse(text) as Record<string, Object>;
  } catch (e) {
    return FwTarget.DASHBOARD;
  }
  if (parsed === null || typeof parsed !== 'object') {
    return FwTarget.DASHBOARD;
  }
  return resolveFwTarget(parsed[FW_TARGET_PARAM]);
}

export function resolveFwTarget(value: Object | null | undefined): string {
  if (value === null || value === undefined || typeof value !== 'string') {
    return FwTarget.DASHBOARD;
  }
  const raw: string = value as string;
  if (raw.length === 0 || raw.length > MAX_TARGET_LENGTH) {
    return FwTarget.DASHBOARD;
  }
  const name = raw.trim().toLowerCase();
  if (name === FwTarget.SHARE) {
    return FwTarget.SHARE;
  }
  if (name === FwTarget.SOURCE) {
    return FwTarget.SOURCE;
  }
  return FwTarget.DASHBOARD;
}
