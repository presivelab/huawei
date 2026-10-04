import { DailyActivity, HealthStatus, HrvNight, SleepSession, Vo2MaxEstimate, Workout } from './HealthRecords';

// Where FairWear gets health history from. The methods are synchronous over records that are already in
// memory; fetching (async) is the job of the adapter in the phone module.
// `days` is how many days back from today the caller wants.
// A source with nothing to give returns an empty list, never records filled with zeros.
export interface HealthSource {
  status(): HealthStatus;
  daily(days: number): DailyActivity[];
  sleep(days: number): SleepSession[];
  vo2max(days: number): Vo2MaxEstimate[];
  hrv(days: number): HrvNight[];
  workouts(days: number): Workout[];
}

// A source that holds no records and reports the status it was given.
// It stands in for the demo source until the demo data set is part of the build.
export class EmptyHealthSource implements HealthSource {
  private fixedStatus: HealthStatus;

  constructor(status: HealthStatus) {
    this.fixedStatus = status;
  }

  status(): HealthStatus {
    return this.fixedStatus;
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
