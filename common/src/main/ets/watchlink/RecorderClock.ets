// The recorder's clock on the watch: real time, or demo time that runs faster. Pure logic.
//
// Recorder time never goes back. Demo time that has run stays as an offset from real time, so a day
// that was recorded once is not recorded again, and a packet is honest about it: only a day that ran
// entirely on the real, unshifted clock is labelled REAL.
import { CLOCK_DEMO_OFFSET, DEMO_SPEED_PREFIX } from './SlotRecorder';
import { CLOCK_REAL } from './WatchLinkTypes';

export const DEMO_SPEED: number = 300;

export class RecorderClock {
  private offsetMs: number;
  private speed: number = 1;
  private anchorRealMs: number = 0;

  // offsetMs: recorder time minus real time, as stored from an earlier run.
  constructor(offsetMs: number = 0) {
    this.offsetMs = offsetMs > 0 ? offsetMs : 0;
  }

  now(realMs: number): number {
    return realMs + this.offsetAt(realMs);
  }

  // Recorder time minus real time at this instant. This is what gets stored.
  offsetAt(realMs: number): number {
    if (this.speed <= 1) {
      return this.offsetMs;
    }
    const elapsed = realMs - this.anchorRealMs;
    return this.offsetMs + (elapsed > 0 ? elapsed * (this.speed - 1) : 0);
  }

  setSpeed(realMs: number, speed: number): void {
    this.offsetMs = this.offsetAt(realMs);
    this.speed = speed > 1 ? speed : 1;
    this.anchorRealMs = realMs;
  }

  // Moves recorder time forward to the given instant. A target in the recorder's past is ignored.
  jumpTo(realMs: number, recorderMs: number): void {
    const delta = recorderMs - this.now(realMs);
    if (delta <= 0) {
      return;
    }
    this.offsetMs = this.offsetAt(realMs) + delta;
    this.anchorRealMs = realMs;
  }

  speedNow(): number {
    return this.speed;
  }

  isDemoSpeed(): boolean {
    return this.speed > 1;
  }

  label(realMs: number): string {
    if (this.speed > 1) {
      return `${DEMO_SPEED_PREFIX}${this.speed}`;
    }
    return this.offsetAt(realMs) > 0 ? CLOCK_DEMO_OFFSET : CLOCK_REAL;
  }
}
