// Demo feed: a scripted day of heart rate, steps and charging for the watch recorder. Pure logic.
//
// The wearable emulator sends heart rate 0 and a fixed step counter, so a recorded day is all "off wrist".
// The demo feed replaces the sensor readings with a fixed script so the dial and the day packets have a
// real shape: night charging, worn hours, one break, a walk and a workout.
//
// It is demo data and is labelled as such: it only runs while the demo clock runs, the dial says so, and
// every day that received any of it carries the clock label DEMO_X300_FEED in its signed packet.
// The readings go through the same WearStateMachine and SlotRecorder as sensor readings. There is no
// second wear rule here: an "off wrist" stretch is simply a stretch with no valid heart rate.

/** Appended to the demo-speed clock label of a day that received scripted readings. */
export const CLOCK_FEED_SUFFIX: string = '_FEED';

export class DemoFeedSample {
  hr: number = 0;              // bpm; 0 = no reading (the watch is off the wrist or on the charger)
  charging: boolean = false;
  stepsPerMin: number = 0;
}

class FeedStretch {
  fromMin: number;             // minute of the local day, inclusive
  toMin: number;               // exclusive
  hrLow: number;               // 0 = no reading
  hrSpan: number;              // heart rate varies in [hrLow, hrLow + hrSpan]
  stepsPerMin: number;
  charging: boolean;

  constructor(fromMin: number, toMin: number, hrLow: number, hrSpan: number, stepsPerMin: number,
    charging: boolean) {
    this.fromMin = fromMin;
    this.toMin = toMin;
    this.hrLow = hrLow;
    this.hrSpan = hrSpan;
    this.stepsPerMin = stepsPerMin;
    this.charging = charging;
  }
}

function at(hour: number, minute: number): number {
  return hour * 60 + minute;
}

// One day, the same every day. Illustrative values, not measurements of anyone.
const SCRIPT: FeedStretch[] = [
  new FeedStretch(at(0, 0), at(5, 30), 0, 0, 0, true),          // on the charger overnight
  new FeedStretch(at(5, 30), at(7, 0), 54, 5, 0, false),        // worn, asleep
  new FeedStretch(at(7, 0), at(8, 30), 66, 9, 12, false),       // morning at home
  new FeedStretch(at(8, 30), at(9, 0), 104, 14, 105, false),    // brisk walk
  new FeedStretch(at(9, 0), at(12, 0), 64, 10, 6, false),       // desk
  new FeedStretch(at(12, 0), at(15, 0), 0, 0, 0, false),        // the one break: watch taken off, 3 h
  new FeedStretch(at(15, 0), at(18, 0), 66, 12, 9, false),      // afternoon
  new FeedStretch(at(18, 0), at(19, 0), 124, 22, 70, false),    // workout
  new FeedStretch(at(19, 0), at(23, 0), 60, 10, 4, false),      // evening
  new FeedStretch(at(23, 0), at(24, 0), 0, 0, 0, true)          // back on the charger
];

export const MINUTES_PER_DAY: number = 1440;

/** The scripted reading for one minute of the local day (0..1439). Deterministic: no random numbers. */
export function demoFeedAt(minuteOfDay: number): DemoFeedSample {
  const minute = ((Math.floor(minuteOfDay) % MINUTES_PER_DAY) + MINUTES_PER_DAY) % MINUTES_PER_DAY;
  const out = new DemoFeedSample();
  for (let i = 0; i < SCRIPT.length; i++) {
    const s = SCRIPT[i];
    if (minute >= s.fromMin && minute < s.toMin) {
      out.charging = s.charging;
      out.stepsPerMin = s.stepsPerMin;
      if (s.hrLow > 0) {
        // A fixed zig-zag inside the stretch's range, so the line is not flat.
        out.hr = s.hrLow + ((minute * 7) % (s.hrSpan + 1));
      }
      return out;
    }
  }
  return out;
}

/** Steps for a stretch of recorder time ending at `minuteOfDay`, at that minute's rate. Never negative. */
export function demoFeedSteps(minuteOfDay: number, elapsedMinutes: number): number {
  if (elapsedMinutes <= 0) {
    return 0;
  }
  // One tick never stands for more than 30 recorder minutes of walking.
  const minutes = elapsedMinutes > 30 ? 30 : elapsedMinutes;
  return Math.round(demoFeedAt(minuteOfDay).stepsPerMin * minutes);
}

/** "DEMO_X300" becomes "DEMO_X300_FEED". A label that already has the suffix is returned unchanged. */
export function feedClockLabel(speedLabel: string): string {
  return speedLabel.endsWith(CLOCK_FEED_SUFFIX) ? speedLabel : speedLabel + CLOCK_FEED_SUFFIX;
}
