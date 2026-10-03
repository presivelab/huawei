import { HealthStatus } from './HealthRecords';

/*
 * What a person reads for each source status. The enum values (NOT_AUTHORIZED, DEMO, ...) are for
 * logs and tests; they never appear in the UI.
 */

export const HEALTH_BRAND: string = 'HUAWEI Health';

/** `status` is the enum value as stored in app state, hence a string. Unknown values read as not connected. */
export function healthStatusLabel(status: string): string {
  if (status === HealthStatus.CONNECTED) {
    return 'Connected';
  }
  if (status === HealthStatus.DEMO) {
    return 'Demo data';
  }
  if (status === HealthStatus.UNAVAILABLE) {
    return 'Unavailable in this build';
  }
  return 'Not connected';
}

/** "HUAWEI Health · Demo data": the source line shown on every screen with data. */
export function healthSourceLabel(status: string): string {
  return HEALTH_BRAND + ' · ' + healthStatusLabel(status);
}
