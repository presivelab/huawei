// Records in the native units HUAWEI Health reports (not percentiles).
// A value that is not available is HEALTH_MISSING (-1), the same convention as MISSING in HES.
// Zero is never written in place of a missing value: zero steps is a real reading, "no reading" is -1.

export const HEALTH_MISSING: number = -1;

export enum HealthStatus {
  CONNECTED = 'CONNECTED',           // reading from HUAWEI Health through Health Service Kit
  NOT_AUTHORIZED = 'NOT_AUTHORIZED', // the user has not given consent, refused it or disconnected
  UNAVAILABLE = 'UNAVAILABLE',       // this build cannot reach HUAWEI Health
  DEMO = 'DEMO'                      // demo source, no data from HUAWEI Health
}

export interface DailyActivity {
  date: string;              // local calendar day, YYYY-MM-DD
  steps: number;
  restingHeartRate: number;  // bpm
  moderateMinutes: number;
  vigorousMinutes: number;
}

export interface SleepSession {
  start: number;             // epoch ms
  end: number;               // epoch ms
  asleepMinutes: number;
}

export interface Vo2MaxEstimate {
  date: string;
  mlPerKgMin: number;
}

export interface HrvNight {
  date: string;
  rmssdMs: number;
}

export interface Workout {
  date: string;
  peakHeartRate: number;     // bpm
  heartRate60s: number;      // bpm, 60 s after the workout ended
}
