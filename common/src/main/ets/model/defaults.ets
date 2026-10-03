// common/src/main/ets/model/defaults.ets
import { Thresholds } from './types';

// The single source of default thresholds. The Settings sliders override a copy of these.
export const DEFAULT_THRESHOLDS: Thresholds = {
  minDailyHours: 20,
  maxChargingCountedMin: 120,
  nightRequired: true,
  minMonthlyPct: 85,
  gapMinMinutes: 120,
  restDeltaBpm: 7,
  stepsDropRatio: 0.6,
  minSuspicious: 3,
  maxSuspiciousShare: 0.3,
  maxPauseDaysPer30: 5
};
