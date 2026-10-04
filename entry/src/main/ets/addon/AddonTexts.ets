import { HealthScope, healthSourceLabel, HealthStatus } from 'common';
import { reportsFromHealthSim, reportSourceLabel } from '../report/ServiceLocator';
import { str } from '../ui/Strings';

// UI copy of the add-on screens, kept in string resources (base = English); the brand is written
// "HUAWEI Health", text only. A constant is the resource; a function returns the text.

export const ROUTE_PLATFORM_CONSENT: string = 'consent-platform';
export const ROUTE_DATA_CONSENT: string = 'consent-data';
export const ROUTE_SETTINGS: string = 'settings';
export const ROUTE_VERIFICATION: string = 'verification-details';
export const ROUTE_WHY: string = 'why';
export const ROUTE_PARTNER: string = 'partner';
export const ROUTE_LEDGER: string = 'ledger';
export const ROUTE_TOUR: string = 'watch-link-tour';

export const VERIFICATION_LABEL: Resource = $r('app.string.addon_verification_label');
export const VERIFICATION_HINT: Resource = $r('app.string.addon_verification_hint');
export const TOUR_LABEL: Resource = $r('app.string.addon_tour_label');

export const BRAND: Resource = $r('app.string.addon_brand');
export const CONNECT_LABEL: Resource = $r('app.string.addon_connect_label');
export const RECONNECT_LABEL: Resource = $r('app.string.addon_reconnect_label');
export const DISCONNECT_LABEL: Resource = $r('app.string.addon_disconnect_label');

export const ADDON_SENTENCE: Resource = $r('app.string.addon_sentence');

// One sentence: what is read, what is not, what leaves the phone.
export const READS_SENTENCE: Resource = $r('app.string.addon_reads_sentence');

// Welcome screen: one sentence of value, then three short rows. The full list sits under "Details".
export const VALUE_SENTENCE: Resource = $r('app.string.addon_value_sentence');
export const READS_TITLE: Resource = $r('app.string.addon_reads_title');
export const READS_SHORT: Resource = $r('app.string.addon_reads_short');
export const NEVER_READS_TITLE: Resource = $r('app.string.addon_never_reads_title');
export const NEVER_READS_SHORT: Resource = $r('app.string.addon_never_reads_short');
export const LEAVES_TITLE: Resource = $r('app.string.addon_leaves_title');
export const LEAVES_SHORT: Resource = $r('app.string.addon_leaves_short');
export const DETAILS_LABEL: Resource = $r('app.string.addon_details_label');

export const PRIVACY_SETTINGS_SENTENCE: Resource = $r('app.string.addon_privacy_settings_sentence');

export const REFUSED_TITLE: Resource = $r('app.string.addon_refused_title');
export const REFUSED_BODY: Resource = $r('app.string.addon_refused_body');

// Health Sim: the separate app that plays HUAWEI Health's part on the emulators.
export const HEALTH_SIM_SENTENCE: Resource = $r('app.string.addon_health_sim_sentence');
export const HEALTH_SIM_ASKING: Resource = $r('app.string.addon_health_sim_asking');
export const HEALTH_SIM_ASKING_BODY: Resource = $r('app.string.addon_health_sim_asking_body');
export const HEALTH_SIM_ASK_AGAIN: Resource = $r('app.string.addon_health_sim_ask_again');
export const HEALTH_SIM_USE_BUILT_IN: Resource = $r('app.string.addon_health_sim_use_built_in');
export const HEALTH_SIM_READS_SENTENCE: Resource = $r('app.string.addon_health_sim_reads_sentence');

export const DISCONNECTED_TITLE: Resource = $r('app.string.addon_disconnected_title');
export const DISCONNECTED_BODY: Resource = $r('app.string.addon_disconnected_body');

export function scopeLabel(scope: HealthScope): string {
  if (scope === HealthScope.STEPS) {
    return str($r('app.string.addon_scope_steps'));
  }
  if (scope === HealthScope.RESTING_HEART_RATE) {
    return str($r('app.string.addon_scope_resting_heart_rate'));
  }
  if (scope === HealthScope.SLEEP) {
    return str($r('app.string.addon_scope_sleep'));
  }
  if (scope === HealthScope.ACTIVITY_MINUTES) {
    return str($r('app.string.addon_scope_activity_minutes'));
  }
  if (scope === HealthScope.VO2MAX) {
    return str($r('app.string.addon_scope_vo2max'));
  }
  if (scope === HealthScope.HRV) {
    return str($r('app.string.addon_scope_hrv'));
  }
  return str($r('app.string.addon_scope_workouts'));
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
  return lastSync === '—' ? label : str($r('app.string.addon_source_last_sync'), label, lastSync);
}

export function statusExplanation(status: string): string {
  if (status !== HealthStatus.NOT_AUTHORIZED && reportsFromHealthSim()) {
    return str(HEALTH_SIM_READS_SENTENCE);
  }
  if (status === HealthStatus.CONNECTED) {
    return str($r('app.string.addon_status_connected'));
  }
  if (status === HealthStatus.DEMO) {
    return str($r('app.string.addon_status_demo'));
  }
  if (status === HealthStatus.UNAVAILABLE) {
    return str($r('app.string.addon_status_unavailable'));
  }
  return str($r('app.string.addon_status_not_connected'));
}
