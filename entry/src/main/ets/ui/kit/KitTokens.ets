import { WEAR_CHARGING, WEAR_OFF, WEAR_WORN } from 'common';

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

export const SYMBOL_STEPS: Resource = $r('sys.symbol.steps');
export const SYMBOL_HEART: Resource = $r('sys.symbol.heart');
export const SYMBOL_SLEEP: Resource = $r('sys.symbol.sleep');
export const SYMBOL_ACTIVITY: Resource = $r('sys.symbol.flame');
export const SYMBOL_VO2MAX: Resource = $r('sys.symbol.oxygen_uptake');
export const SYMBOL_HRV: Resource = $r('sys.symbol.waveform_path_ecg_heart');
export const SYMBOL_WORKOUT: Resource = $r('sys.symbol.dumbbell');
export const SYMBOL_WATCH: Resource = $r('sys.symbol.watch');
export const SYMBOL_VERIFIED: Resource = $r('sys.symbol.checkmark_shield_fill');

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
