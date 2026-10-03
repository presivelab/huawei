// Live wear state for the watch screen: a thin adapter over WearStateMachine, the one wear rule of the
// watch (charging, then the wear-detection sensor, then a valid heart rate within the freshness window).
// This class adds only what the screen needs on top: the heart rate to show and a no-argument clock.
// Pure logic: no sensor, UI or clock imports, so it runs in Node tests. Time comes only from the
// timestamps passed in. Live data shown on the watch; it never enters the score.
import { isValidHeartRate, SlotState } from '../watchlink/WatchLinkTypes';
import { FRESHNESS_REAL_CLOCK_MS, WearStateMachine } from '../watchlink/WearStateMachine';

export enum WearState {
  NO_DATA = 'NO_DATA',
  WORN = 'WORN',
  REMOVED = 'REMOVED',
  CHARGING = 'CHARGING'
}

// Returned instead of a heart rate when there is no valid reading. Never zero.
export const NO_HEART_RATE: number = -1;

export class LiveWearState {
  private machine: WearStateMachine;
  private clockMs: number = -1;
  private lastValidRate: number = NO_HEART_RATE;
  private lastValidAtMs: number = -1;
  private latestReadingValid: boolean = false;

  constructor(freshnessMs: number = FRESHNESS_REAL_CLOCK_MS) {
    this.machine = new WearStateMachine(freshnessMs);
  }

  // Feed one raw sensor reading. A reading the wear rule does not accept (0 and below included) is
  // "no reading": it moves the clock forward but never becomes a heart-rate value.
  onReading(timestampMs: number, heartRate: number): void {
    this.advance(timestampMs);
    this.machine.onHr(timestampMs, heartRate);
    this.latestReadingValid = isValidHeartRate(heartRate);
    if (this.latestReadingValid) {
      this.lastValidRate = heartRate;
      this.lastValidAtMs = timestampMs;
    }
  }

  // One event from the wear-detection sensor: 1 = on the wrist, 0 = off.
  onWear(timestampMs: number, value: number): void {
    this.advance(timestampMs);
    this.machine.onWear(timestampMs, value);
  }

  onCharging(timestampMs: number, isCharging: boolean): void {
    this.advance(timestampMs);
    this.machine.onCharging(timestampMs, isCharging);
  }

  // Move the clock without a reading, so silence from the sensor also ages the last valid reading.
  advance(timestampMs: number): void {
    if (timestampMs > this.clockMs) {
      this.clockMs = timestampMs;
    }
  }

  // NO_DATA until any sensor has reported; after that whatever WearStateMachine says.
  state(): WearState {
    if (!this.machine.hasSignal()) {
      return WearState.NO_DATA;
    }
    const slot: SlotState = this.machine.state(this.clockMs);
    if (slot === 'C') {
      return WearState.CHARGING;
    }
    return slot === 'W' ? WearState.WORN : WearState.REMOVED;
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
