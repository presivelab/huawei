import { HealthScope, healthSourceLabel, HealthStatus } from 'common';
import { reportsFromHealthSim, reportSourceLabel } from '../report/ServiceLocator';

// UI copy of the add-on screens. English only; the brand is written "HUAWEI Health", text only.

export const ROUTE_PLATFORM_CONSENT: string = 'consent-platform';
export const ROUTE_DATA_CONSENT: string = 'consent-data';
export const ROUTE_SETTINGS: string = 'settings';
export const ROUTE_VERIFICATION: string = 'verification-details';
export const ROUTE_WHY: string = 'why';
export const ROUTE_PARTNER: string = 'partner';
export const ROUTE_LEDGER: string = 'ledger';
export const ROUTE_TOUR: string = 'watch-link-tour';

export const VERIFICATION_LABEL: string = 'Verification details';
export const VERIFICATION_HINT: string = 'Watch key, sequence numbers, chain and sync log';
export const TOUR_LABEL: string = 'How Watch Link works';

export const BRAND: string = 'HUAWEI Health';
export const CONNECT_LABEL: string = 'Connect HUAWEI Health';
export const RECONNECT_LABEL: string = 'Reconnect';
export const DISCONNECT_LABEL: string = 'Disconnect HUAWEI Health';

export const ADDON_SENTENCE: string =
  'FairWear is an add-on for HUAWEI Health users: with their permission it reads what HUAWEI Health already ' +
    'measures, scores it on the phone, and shares only a signed tier.';

// One sentence: what is read, what is not, what leaves the phone.
export const READS_SENTENCE: string =
  'FairWear reads steps, resting heart rate, sleep, activity minutes, VO₂max, HRV and workouts from the last ' +
    '90 days; it does not read location, ECG, blood pressure, SpO₂, weight or contacts; the only thing that ' +
    'leaves this phone is a signed A/B/C tier, and only when you share it.';

// Welcome screen: one sentence of value, then three short rows. The full list sits under "Details".
export const VALUE_SENTENCE: string =
  'Your HUAWEI Health history becomes a signed A/B/C tier, scored on this phone.';
export const READS_TITLE: string = 'Reads';
export const READS_SHORT: string = 'Steps, heart rate, sleep and activity from the last 90 days';
export const NEVER_READS_TITLE: string = 'Never reads';
export const NEVER_READS_SHORT: string = 'Location, ECG, blood pressure, SpO₂, weight, contacts';
export const LEAVES_TITLE: string = 'Leaves the phone';
export const LEAVES_SHORT: string = 'Only a signed tier, and only when you share it';
export const DETAILS_LABEL: string = 'Details';

export const PRIVACY_SETTINGS_SENTENCE: string =
  'You can also end the connection in HUAWEI Health privacy settings.';

export const REFUSED_TITLE: string = 'HUAWEI Health was not connected';
export const REFUSED_BODY: string =
  'No health data was read. Without your permission FairWear cannot calculate your Health Evidence Score, ' +
    'coverage or tier, and there is nothing to share.';

// Health Sim: the separate app that plays HUAWEI Health's part on the emulators.
export const HEALTH_SIM_SENTENCE: string = 'Health Sim stands in for HUAWEI Health on this emulator.';
export const HEALTH_SIM_ASKING: string = 'Asking Health Sim for access…';
export const HEALTH_SIM_ASKING_BODY: string =
  'Health Sim shows its own consent screen. FairWear does not reproduce it and gets nothing until you allow ' +
    'it there.';
export const HEALTH_SIM_READS_SENTENCE: string =
  'Reads the simulated data Health Sim handed over after your consent. ' + HEALTH_SIM_SENTENCE;

export const DISCONNECTED_TITLE: string = 'HUAWEI Health disconnected';
export const DISCONNECTED_BODY: string =
  'Health data held in memory was cleared and the tier is hidden. Connecting again asks for your consent again.';

export function scopeLabel(scope: HealthScope): string {
  if (scope === HealthScope.STEPS) {
    return 'Steps';
  }
  if (scope === HealthScope.RESTING_HEART_RATE) {
    return 'Resting heart rate';
  }
  if (scope === HealthScope.SLEEP) {
    return 'Sleep';
  }
  if (scope === HealthScope.ACTIVITY_MINUTES) {
    return 'Activity minutes';
  }
  if (scope === HealthScope.VO2MAX) {
    return 'VO₂max';
  }
  if (scope === HealthScope.HRV) {
    return 'HRV';
  }
  return 'Workouts';
}

// The source line: brand and a readable status, for example the brand followed by "Demo data".
// The status enum never reaches the screen (see healthStatusLabel in common). The last sync is added
// only when one is known.
// While the reports come from Health Sim the line names Health Sim, not the brand.
export function sourceLine(status: string, lastSync: string): string {
  if (status === HealthStatus.NOT_AUTHORIZED) {
    return healthSourceLabel(status);
  }
  const label: string = reportsFromHealthSim() ? reportSourceLabel() : healthSourceLabel(status);
  return lastSync === '—' ? label : label + ' · last sync ' + lastSync;
}

export function statusExplanation(status: string): string {
  if (status !== HealthStatus.NOT_AUTHORIZED && reportsFromHealthSim()) {
    return HEALTH_SIM_READS_SENTENCE;
  }
  if (status === HealthStatus.CONNECTED) {
    return 'Reads from HUAWEI Health.';
  }
  if (status === HealthStatus.DEMO) {
    return 'Demo mode: nothing is read from HUAWEI Health in this build.';
  }
  if (status === HealthStatus.UNAVAILABLE) {
    return 'HUAWEI Health is unavailable in this build.';
  }
  return 'Not connected: FairWear has no permission to read from HUAWEI Health.';
}
