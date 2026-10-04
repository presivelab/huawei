// What the Health Sim watch screen shows about the day script. Pure logic.
//
// The script itself is FairWear's (fw/watchlink/DemoFeed.ets, an unchanged copy): this file only reads it.
// A stretch on the charger is "charging", a stretch with a heart rate is "worn", anything else is
// "off wrist". The same reading FairWear's wear rule makes of the scripted values.
import { FeedStretch, MINUTES_PER_DAY } from '../fw/watchlink/DemoFeed';

export const KIND_WORN: string = 'W';
export const KIND_CHARGING: string = 'C';
export const KIND_OFF: string = 'O';

const NONE_TEXT: string = 'none';

/** The daily goals the two rings of the first watch page are drawn against. Display only. */
export const STEPS_GOAL: number = 10000;
export const EXERCISE_GOAL_MIN: number = 30;
// A scripted stretch counts as exercise when its heart rate starts at 100 bpm or more: the brisk walk and
// the workout of the built-in day. A reading of the script for the screen, not a measurement.
const EXERCISE_HR_FROM: number = 100;

export class DayArc {
  fromMin: number;
  toMin: number;
  kind: string;

  constructor(fromMin: number, toMin: number, kind: string) {
    this.fromMin = fromMin;
    this.toMin = toMin;
    this.kind = kind;
  }
}

export function kindOf(s: FeedStretch): string {
  if (s.charging) {
    return KIND_CHARGING;
  }
  return s.hrLow > 0 ? KIND_WORN : KIND_OFF;
}

/** The day as arcs, neighbours of the same kind joined. */
export function arcsOf(script: FeedStretch[]): DayArc[] {
  const out: DayArc[] = [];
  for (let i = 0; i < script.length; i++) {
    const s = script[i];
    const kind = kindOf(s);
    const last = out.length > 0 ? out[out.length - 1] : null;
    if (last !== null && last.kind === kind && last.toMin === s.fromMin) {
      last.toMin = s.toMin;
    } else {
      out.push(new DayArc(s.fromMin, s.toMin, kind));
    }
  }
  return out;
}

export function minutesOf(script: FeedStretch[], kind: string): number {
  let total = 0;
  for (let i = 0; i < script.length; i++) {
    if (kindOf(script[i]) === kind) {
      total += script[i].toMin - script[i].fromMin;
    }
  }
  return total;
}

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

/** "12:00"; the end of the day is written "24:00". */
export function clockText(minute: number): string {
  const m = minute < 0 ? 0 : (minute > MINUTES_PER_DAY ? MINUTES_PER_DAY : minute);
  return `${pad2(Math.floor(m / 60))}:${pad2(m % 60)}`;
}

/** "14 h 30 min", "3 h", "45 min". Units always written. */
export function durationText(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  if (h === 0) {
    return `${m} min`;
  }
  return m === 0 ? `${h} h` : `${h} h ${m} min`;
}

/** The off-wrist stretches as clock ranges: "12:00–15:00". "none" when the script has none. */
export function offWristText(script: FeedStretch[]): string {
  const parts: string[] = [];
  const arcs = arcsOf(script);
  for (let i = 0; i < arcs.length; i++) {
    if (arcs[i].kind === KIND_OFF) {
      parts.push(`${clockText(arcs[i].fromMin)}–${clockText(arcs[i].toMin)}`);
    }
  }
  return parts.length === 0 ? NONE_TEXT : parts.join(', ');
}

/** Steps of the whole scripted day: steps per minute times the length of every stretch. */
export function stepsOf(script: FeedStretch[]): number {
  let total = 0;
  for (let i = 0; i < script.length; i++) {
    total += script[i].stepsPerMin * (script[i].toMin - script[i].fromMin);
  }
  return total;
}

/** Minutes of the scripted day spent in a stretch that counts as exercise. */
export function exerciseMinutesOf(script: FeedStretch[]): number {
  let total = 0;
  for (let i = 0; i < script.length; i++) {
    if (!script[i].charging && script[i].hrLow >= EXERCISE_HR_FROM) {
      total += script[i].toMin - script[i].fromMin;
    }
  }
  return total;
}

/** 12090 -> "12,090". */
export function groupedText(n: number): string {
  let text = `${Math.floor(n)}`;
  let out = '';
  while (text.length > 3) {
    out = `,${text.substring(text.length - 3)}${out}`;
    text = text.substring(0, text.length - 3);
  }
  return text + out;
}

/** A value against its goal as a ring share 0..100. */
export function goalShare(value: number, goal: number): number {
  return goal <= 0 || value <= 0 ? 0 : Math.min(100, Math.round(value * 100 / goal));
}
