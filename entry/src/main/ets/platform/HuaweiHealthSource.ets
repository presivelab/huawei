import {
  DailyActivity,
  HealthSource,
  HealthStatus,
  HrvNight,
  SleepSession,
  Vo2MaxEstimate,
  Workout
} from 'common';

// Stub. FairWear does not read from HUAWEI Health in this build.
//
// The real adapter would read through Health Service Kit:
//   https://developer.huawei.com/consumer/en/doc/harmonyos-guides/health-service-kit-guide
// Access to health data through that kit has to be granted by Huawei for the specific app, after a manual
// review of an application. FairWear has not been granted that access, so nothing here calls the kit and
// the status is UNAVAILABLE. No demo or synthetic record is ever returned from this class.
export class HuaweiHealthSource implements HealthSource {
  status(): HealthStatus {
    return HealthStatus.UNAVAILABLE;
  }

  daily(days: number): DailyActivity[] {
    return [];
  }

  sleep(days: number): SleepSession[] {
    return [];
  }

  vo2max(days: number): Vo2MaxEstimate[] {
    return [];
  }

  hrv(days: number): HrvNight[] {
    return [];
  }

  workouts(days: number): Workout[] {
    return [];
  }
}
