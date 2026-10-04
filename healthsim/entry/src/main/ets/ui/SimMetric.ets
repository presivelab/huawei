import {
  METRIC_EXERCISE,
  METRIC_HEART,
  METRIC_HRV,
  METRIC_SLEEP,
  METRIC_STEPS,
  METRIC_VO2MAX
} from '../data/SimData';
import {
  LABEL_EXERCISE,
  LABEL_HEART,
  LABEL_HRV,
  LABEL_SLEEP,
  LABEL_STEPS,
  LABEL_VO2MAX,
  SUB_EXERCISE,
  SUB_FITNESS,
  SUB_HEART,
  SUB_SLEEP,
  SUB_STEPS
} from '../data/SimTexts';

// How a metric looks on every Health Sim screen: one name, one symbol and one accent colour. The colours
// are Health Sim's own resources (base and dark), neutral on purpose: no brand palette is copied.

// AppStorage: the person whose days are shown, and the metric the detail page opens with.
export const KEY_PERSON: string = 'hsPerson';
export const KEY_METRIC: string = 'hsMetric';
export const DEFAULT_PERSON: string = 'ania';

export function metricColor(metric: string): Resource {
  if (metric === METRIC_EXERCISE) {
    return $r('app.color.hs_metric_exercise');
  }
  if (metric === METRIC_HEART) {
    return $r('app.color.hs_metric_heart');
  }
  if (metric === METRIC_SLEEP) {
    return $r('app.color.hs_metric_sleep');
  }
  if (metric === METRIC_VO2MAX || metric === METRIC_HRV) {
    return $r('app.color.hs_metric_fitness');
  }
  return $r('app.color.hs_metric_steps');
}

export function metricSymbol(metric: string): Resource {
  if (metric === METRIC_EXERCISE) {
    return $r('sys.symbol.flame');
  }
  if (metric === METRIC_HEART) {
    return $r('sys.symbol.heart');
  }
  if (metric === METRIC_SLEEP) {
    return $r('sys.symbol.sleep');
  }
  if (metric === METRIC_VO2MAX) {
    return $r('sys.symbol.oxygen_uptake');
  }
  if (metric === METRIC_HRV) {
    return $r('sys.symbol.waveform_path_ecg_heart');
  }
  return $r('sys.symbol.steps');
}

export function metricLabel(metric: string): string {
  if (metric === METRIC_EXERCISE) {
    return LABEL_EXERCISE;
  }
  if (metric === METRIC_HEART) {
    return LABEL_HEART;
  }
  if (metric === METRIC_SLEEP) {
    return LABEL_SLEEP;
  }
  if (metric === METRIC_VO2MAX) {
    return LABEL_VO2MAX;
  }
  if (metric === METRIC_HRV) {
    return LABEL_HRV;
  }
  return LABEL_STEPS;
}

/** The line under a value: what exactly the number is. */
export function metricSub(metric: string): string {
  if (metric === METRIC_EXERCISE) {
    return SUB_EXERCISE;
  }
  if (metric === METRIC_HEART) {
    return SUB_HEART;
  }
  if (metric === METRIC_SLEEP) {
    return SUB_SLEEP;
  }
  if (metric === METRIC_VO2MAX || metric === METRIC_HRV) {
    return SUB_FITNESS;
  }
  return SUB_STEPS;
}
