import { ComponentId, DayState, ReportTier, WEAR_CHARGING, WEAR_OFF, WEAR_WORN } from 'common';

// FairWear's own colours and the one symbol of each metric. Values: resources/*/element/fw_tokens.json.
export const COLOR_WORN: Resource = $r('app.color.fw_wear_worn');
export const COLOR_CHARGING: Resource = $r('app.color.fw_wear_charging');
export const COLOR_OFF: Resource = $r('app.color.fw_wear_off');
export const COLOR_UNOBSERVED: Resource = $r('app.color.fw_wear_unobserved');

export const COLOR_STEPS: Resource = $r('app.color.fw_metric_steps');
export const COLOR_HEART: Resource = $r('app.color.fw_metric_heart');
export const COLOR_SLEEP: Resource = $r('app.color.fw_metric_sleep');
export const COLOR_ACTIVITY: Resource = $r('app.color.fw_metric_activity');
export const COLOR_VO2MAX: Resource = $r('app.color.fw_metric_vo2max');
export const COLOR_HRV: Resource = $r('app.color.fw_metric_hrv');
export const COLOR_WORKOUT: Resource = $r('app.color.fw_metric_workout');

// A flag (suspicious breaks): the tint behind a label and the text colour on it.
export const COLOR_FLAG_TINT: Resource = $r('app.color.fw_flag_tint');
export const COLOR_FLAG_TEXT: Resource = $r('app.color.fw_flag_text');
// A note that something is not final (live, preview): amber, the tier B pair.
export const COLOR_NOTE_TINT: Resource = $r('app.color.fw_tier_b_tint');
export const COLOR_NOTE_TEXT: Resource = $r('app.color.fw_tier_b_text');
// Text that says "this is fine" on a card: the tier A text colour.
export const COLOR_OK_TEXT: Resource = $r('app.color.fw_tier_a_text');

export const SYMBOL_STEPS: Resource = $r('sys.symbol.steps');
export const SYMBOL_HEART: Resource = $r('sys.symbol.heart');
export const SYMBOL_SLEEP: Resource = $r('sys.symbol.sleep');
export const SYMBOL_SLEEP_REGULARITY: Resource = $r('sys.symbol.alarm');
export const SYMBOL_ACTIVITY: Resource = $r('sys.symbol.flame');
export const SYMBOL_VO2MAX: Resource = $r('sys.symbol.oxygen_uptake');
export const SYMBOL_HRV: Resource = $r('sys.symbol.waveform_path_ecg_heart');
export const SYMBOL_WORKOUT: Resource = $r('sys.symbol.dumbbell');
export const SYMBOL_RECOVERY: Resource = $r('sys.symbol.stopwatch');
export const SYMBOL_WATCH: Resource = $r('sys.symbol.watch');
export const SYMBOL_VERIFIED: Resource = $r('sys.symbol.checkmark_shield_fill');

// Navigation and state symbols.
export const SYMBOL_SETTINGS: Resource = $r('sys.symbol.gearshape');
export const SYMBOL_TAB_REPORT: Resource = $r('sys.symbol.doc_text');
export const SYMBOL_TAB_EVIDENCE: Resource = $r('sys.symbol.calendar');
export const SYMBOL_TAB_SHARE: Resource = $r('sys.symbol.qrcode');
export const SYMBOL_FORWARD: Resource = $r('sys.symbol.chevron_right');
export const SYMBOL_EXPAND: Resource = $r('sys.symbol.chevron_down');
export const SYMBOL_CHECK: Resource = $r('sys.symbol.checkmark');
export const SYMBOL_BENEFIT_FULL: Resource = $r('sys.symbol.checkmark_circle_fill');
export const SYMBOL_BENEFIT_PARTIAL: Resource = $r('sys.symbol.checkmark_circle');
export const SYMBOL_BENEFIT_NONE: Resource = $r('sys.symbol.minus_circle');
export const SYMBOL_INFO: Resource = $r('sys.symbol.info_circle');
// Share and the partner view: where the signing key is held, a failed check, a check that was not run.
export const SYMBOL_KEY_HELD: Resource = $r('sys.symbol.lock');
export const SYMBOL_CROSS: Resource = $r('sys.symbol.xmark');
export const SYMBOL_NOT_RUN: Resource = $r('sys.symbol.minus');

// The colour of one wear state (WEAR_WORN, WEAR_CHARGING, WEAR_OFF; anything else is "not observed").
export function wearColor(state: string): Resource {
  if (state === WEAR_WORN) {
    return COLOR_WORN;
  }
  if (state === WEAR_CHARGING) {
    return COLOR_CHARGING;
  }
  if (state === WEAR_OFF) {
    return COLOR_OFF;
  }
  return COLOR_UNOBSERVED;
}

// The colour of one day of the month (DayState): compliant, short, suspicious break; sick and unknown
// days share the "not observed" grey.
export function dayStateColor(state: string): Resource {
  if (state === DayState.COMPLIANT) {
    return COLOR_WORN;
  }
  if (state === DayState.SHORT) {
    return COLOR_CHARGING;
  }
  if (state === DayState.SUSPICIOUS) {
    return COLOR_OFF;
  }
  return COLOR_UNOBSERVED;
}

// Tier colours: the ring, the tint behind the tier letter and the text on that tint. No tier is grey.
export function tierColor(tier: string): Resource {
  if (tier === ReportTier.A) {
    return $r('app.color.fw_tier_a');
  }
  if (tier === ReportTier.B) {
    return $r('app.color.fw_tier_b');
  }
  if (tier === ReportTier.C) {
    return $r('app.color.fw_tier_c');
  }
  return $r('sys.color.icon_secondary');
}

export function tierTint(tier: string): Resource {
  if (tier === ReportTier.A) {
    return $r('app.color.fw_tier_a_tint');
  }
  if (tier === ReportTier.B) {
    return $r('app.color.fw_tier_b_tint');
  }
  if (tier === ReportTier.C) {
    return $r('app.color.fw_tier_c_tint');
  }
  return $r('sys.color.comp_background_tertiary');
}

export function tierTextColor(tier: string): Resource {
  if (tier === ReportTier.A) {
    return $r('app.color.fw_tier_a_text');
  }
  if (tier === ReportTier.B) {
    return $r('app.color.fw_tier_b_text');
  }
  if (tier === ReportTier.C) {
    return $r('app.color.fw_tier_c_text');
  }
  return $r('sys.color.font_secondary');
}

// The colour and the symbol of a score component (ComponentId), the same on every screen.
export function componentColor(id: string): Resource {
  if (id === ComponentId.STEPS) {
    return COLOR_STEPS;
  }
  if (id === ComponentId.ACTIVE_MINUTES) {
    return COLOR_ACTIVITY;
  }
  if (id === ComponentId.RESTING_HR) {
    return COLOR_HEART;
  }
  if (id === ComponentId.SLEEP || id === ComponentId.SLEEP_REGULARITY) {
    return COLOR_SLEEP;
  }
  if (id === ComponentId.VO2MAX) {
    return COLOR_VO2MAX;
  }
  if (id === ComponentId.HRV) {
    return COLOR_HRV;
  }
  return COLOR_WORKOUT;
}

export function componentSymbol(id: string): Resource {
  if (id === ComponentId.STEPS) {
    return SYMBOL_STEPS;
  }
  if (id === ComponentId.ACTIVE_MINUTES) {
    return SYMBOL_ACTIVITY;
  }
  if (id === ComponentId.RESTING_HR) {
    return SYMBOL_HEART;
  }
  if (id === ComponentId.SLEEP) {
    return SYMBOL_SLEEP;
  }
  if (id === ComponentId.SLEEP_REGULARITY) {
    return SYMBOL_SLEEP_REGULARITY;
  }
  if (id === ComponentId.VO2MAX) {
    return SYMBOL_VO2MAX;
  }
  if (id === ComponentId.HRV) {
    return SYMBOL_HRV;
  }
  return SYMBOL_RECOVERY;
}
