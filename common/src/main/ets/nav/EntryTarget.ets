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

const MAX_TARGET_LENGTH: number = 32;

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
