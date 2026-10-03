// Real-time wear state of the watch from charging, the wear-detection sensor and the heart-rate signal.
// Pure logic: time comes only from the timestamps passed in.
//
// Freshness of the heart-rate signal is always measured in REAL time, never in demo time. With a x300
// demo clock two heart-rate samples one second apart are five recorder minutes apart; judged in recorder
// time the watch would flip to off-wrist between them.
import { isValidHeartRate, SlotState, WearSource } from './WatchLinkTypes';

// Real clock: off-wrist after more than 60 s without a valid heart rate.
export const FRESHNESS_REAL_CLOCK_MS: number = 60000;
// Demo clock: 3 s, because 60 real seconds would be 5 recorder hours at x300.
export const FRESHNESS_DEMO_CLOCK_MS: number = 3000;

export class WearStateMachine {
  private freshnessMs: number;
  private charging: boolean = false;
  private chargingSeen: boolean = false;
  private wearSeen: boolean = false;
  private wearValue: number = 0;
  private hrSeen: boolean = false;
  private lastValidHrMs: number = -1;

  constructor(freshnessMs: number = FRESHNESS_REAL_CLOCK_MS) {
    this.freshnessMs = freshnessMs;
  }

  setFreshnessMs(freshnessMs: number): void {
    this.freshnessMs = freshnessMs;
  }

  // One heart-rate event from the sensor. A value outside 25-230 bpm (0 included) is "no reading".
  onHr(realMs: number, bpm: number): void {
    this.hrSeen = true;
    if (isValidHeartRate(bpm)) {
      this.lastValidHrMs = realMs;
    }
  }

  // One event from the wear-detection sensor: 1 = on the wrist, 0 = off.
  onWear(realMs: number, value: number): void {
    this.wearSeen = true;
    this.wearValue = value;
  }

  onCharging(realMs: number, isCharging: boolean): void {
    this.chargingSeen = true;
    this.charging = isCharging;
  }

  // False until any sensor has reported. While false the watch observes nothing, and the recorder
  // must not be fed: that time is "not observed", never "off-wrist".
  hasSignal(): boolean {
    return this.charging || this.wearSeen || this.hrSeen;
  }

  // Charging overrides everything. Then the wear-detection sensor, when the watch has one and it has
  // reported. Otherwise the heart-rate signal: a valid reading within the freshness window means worn.
  state(realMs: number): SlotState {
    if (this.charging) {
      return 'C';
    }
    if (this.wearSeen) {
      return this.wearValue >= 1 ? 'W' : 'O';
    }
    if (this.lastValidHrMs >= 0 && realMs - this.lastValidHrMs <= this.freshnessMs) {
      return 'W';
    }
    return 'O';
  }

  source(): WearSource {
    return this.wearSeen ? 'SENSOR' : 'HR_SIGNAL';
  }

  chargingKnown(): boolean {
    return this.chargingSeen;
  }
}
