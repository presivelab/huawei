// Live wear state derived from raw heart-rate readings. Pure logic: no sensor, UI or clock imports,
// so it runs in Node tests. Time comes only from the timestamps passed in.
// Live data shown on the watch; it never enters the score.

export enum WearState {
  NO_DATA = 'NO_DATA',
  WORN = 'WORN',
  REMOVED = 'REMOVED'
}

// Returned instead of a heart rate when there is no valid reading. Never zero.
export const NO_HEART_RATE: number = -1;

// "Removed" = no valid heart-rate reading for this long. Demo value.
export const DEFAULT_REMOVED_AFTER_MS: number = 10000;

export class LiveWearState {
  private removedAfterMs: number;
  private clockMs: number = -1;
  private lastValidRate: number = NO_HEART_RATE;
  private lastValidAtMs: number = -1;
  private latestReadingValid: boolean = false;

  constructor(removedAfterMs: number = DEFAULT_REMOVED_AFTER_MS) {
    this.removedAfterMs = removedAfterMs;
  }

  // Feed one raw sensor reading. A reading <= 0 (or not a number) is "no reading": it moves the
  // clock forward but never becomes a heart-rate value.
  onReading(timestampMs: number, heartRate: number): void {
    this.advance(timestampMs);
    if (heartRate > 0) {
      this.lastValidRate = heartRate;
      this.lastValidAtMs = timestampMs;
      this.latestReadingValid = true;
    } else {
      this.latestReadingValid = false;
    }
  }

  // Move the clock without a reading, so silence from the sensor also ages the last valid reading.
  advance(timestampMs: number): void {
    if (timestampMs > this.clockMs) {
      this.clockMs = timestampMs;
    }
  }

  state(): WearState {
    if (this.lastValidAtMs < 0) {
      return WearState.NO_DATA;
    }
    if (this.clockMs - this.lastValidAtMs >= this.removedAfterMs) {
      return WearState.REMOVED;
    }
    return WearState.WORN;
  }

  // Heart rate to show as live: the last valid reading while the watch counts as worn and the
  // newest reading was valid; NO_HEART_RATE otherwise.
  heartRate(): number {
    if (this.latestReadingValid && this.state() === WearState.WORN) {
      return this.lastValidRate;
    }
    return NO_HEART_RATE;
  }

  // Last valid reading ever seen, NO_HEART_RATE before the first one.
  lastValidHeartRate(): number {
    return this.lastValidRate;
  }

  // Milliseconds since the last valid reading, -1 before the first one.
  msSinceValid(): number {
    if (this.lastValidAtMs < 0) {
      return -1;
    }
    return this.clockMs - this.lastValidAtMs;
  }
}
