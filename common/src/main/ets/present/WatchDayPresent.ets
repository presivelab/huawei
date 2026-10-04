// How watch days and the link state are worded on the phone. Pure functions over the facts the Watch Link
// engine already holds: nothing here verifies, judges or changes a day.
import { CLOCK_FEED_SUFFIX } from '../watchlink/DemoFeed';
import { SyncLogEntry, TRANSPORT_RELAY, WatchDayFacts } from '../watchlink/PhoneLinkEngine';
import { BreakContext, CLOCK_REAL, DAY_MINUTES } from '../watchlink/WatchLinkTypes';

export const WEAR_WORN: string = 'worn';
export const WEAR_CHARGING: string = 'charging';
export const WEAR_OFF: string = 'off';
export const WEAR_UNOBSERVED: string = 'unobserved';

export const WEAR_LABEL_WORN: string = 'Worn';
export const WEAR_LABEL_CHARGING: string = 'Charging';
export const WEAR_LABEL_OFF: string = 'Off wrist';
export const WEAR_LABEL_UNOBSERVED: string = 'Not observed';

export const STRIP_DAYS: number = 7;
export const NOT_SYNCED: string = 'Not synced yet';
export const DAY_NOT_RECEIVED: string = 'Day not received';
export const DEMO_CLOCK_LABEL: string = 'Demo clock: simulated time';
export const DEMO_FEED_LABEL: string = 'Demo feed: scripted readings on the demo clock';
export const RELAY_LABEL: string = 'Demo relay (hdc)';

const WEEKDAYS: string[] = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MONTHS: string[] = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const DAY_MS: number = 86400000;

// One of the four states of a day with the minutes spent in it.
export class WearPart {
  state: string = WEAR_UNOBSERVED;
  label: string = WEAR_LABEL_UNOBSERVED;
  minutes: number = 0;

  constructor(state: string, label: string, minutes: number) {
    this.state = state;
    this.label = label;
    this.minutes = minutes;
  }
}

// A duration split into the two numbers that are shown, each with its unit. Empty strings are not shown.
export class DurationParts {
  hours: string = '';
  minutes: string = '';
}

function two(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

// 0 -> "0 min", 35 -> "35 min", 120 -> "2 h", 1160 -> "19 h 20 min".
export function durationParts(totalMinutes: number): DurationParts {
  const parts = new DurationParts();
  const total = totalMinutes > 0 ? Math.floor(totalMinutes) : 0;
  const h = Math.floor(total / 60);
  const m = total % 60;
  if (h > 0) {
    parts.hours = `${h}`;
  }
  if (m > 0 || h === 0) {
    parts.minutes = `${m}`;
  }
  return parts;
}

export function durationText(totalMinutes: number): string {
  const parts = durationParts(totalMinutes);
  if (parts.hours.length > 0 && parts.minutes.length > 0) {
    return `${parts.hours} h ${parts.minutes} min`;
  }
  return parts.hours.length > 0 ? `${parts.hours} h` : `${parts.minutes} min`;
}

// Minutes from midnight as a clock time; a negative value is a time on the day before.
export function minuteClock(minuteOfDay: number): string {
  const total = ((minuteOfDay % DAY_MINUTES) + DAY_MINUTES) % DAY_MINUTES;
  return `${two(Math.floor(total / 60))}:${two(total % 60)}`;
}

// UTC milliseconds of a "YYYY-MM-DD" date, or -1 when the text is not such a date.
function dateMs(date: string): number {
  if (date.length !== 10 || date.charAt(4) !== '-' || date.charAt(7) !== '-') {
    return -1;
  }
  const y = Number.parseInt(date.substring(0, 4), 10);
  const m = Number.parseInt(date.substring(5, 7), 10);
  const d = Number.parseInt(date.substring(8, 10), 10);
  if (Number.isNaN(y) || Number.isNaN(m) || Number.isNaN(d) || m < 1 || m > 12 || d < 1 || d > 31) {
    return -1;
  }
  return Date.UTC(y, m - 1, d);
}

// "2026-10-07" -> "Wed". Empty when the text is not a date.
export function weekdayShort(date: string): string {
  const ms = dateMs(date);
  return ms < 0 ? '' : WEEKDAYS[new Date(ms).getUTCDay()];
}

// "2026-10-07" -> "7". Empty when the text is not a date.
export function dayOfMonth(date: string): string {
  const ms = dateMs(date);
  return ms < 0 ? '' : `${new Date(ms).getUTCDate()}`;
}

// "2026-10-07" -> "Wed 7 Oct". Text that is not a date is returned as it is.
export function dayTitle(date: string): string {
  const ms = dateMs(date);
  if (ms < 0) {
    return date;
  }
  const d = new Date(ms);
  return `${WEEKDAYS[d.getUTCDay()]} ${d.getUTCDate()} ${MONTHS[d.getUTCMonth()]}`;
}

// The four states of a received day, always in the same order, zero minutes included.
export function wearParts(day: WatchDayFacts): WearPart[] {
  return [
    new WearPart(WEAR_WORN, WEAR_LABEL_WORN, day.wornMin),
    new WearPart(WEAR_CHARGING, WEAR_LABEL_CHARGING, day.chargingMin),
    new WearPart(WEAR_OFF, WEAR_LABEL_OFF, day.offMin),
    new WearPart(WEAR_UNOBSERVED, WEAR_LABEL_UNOBSERVED, day.notObservedMin)
  ];
}

// Minutes of the day the watch was observing (worn, charging or off the wrist).
export function observedMinutes(day: WatchDayFacts): number {
  return day.wornMin + day.chargingMin + day.offMin;
}

// The states written out under a day. "Worn" is listed whenever the watch observed anything, so an
// observed day with no wear reads "Worn 0 min"; a day with nothing observed lists only "Not observed",
// because a zero there would stand in for missing data.
export function listedWearParts(day: WatchDayFacts): WearPart[] {
  const out: WearPart[] = [];
  const all = wearParts(day);
  const observed = observedMinutes(day) > 0;
  for (let i = 0; i < all.length; i++) {
    if (all[i].minutes > 0 || (observed && all[i].state === WEAR_WORN)) {
      out.push(all[i]);
    }
  }
  return out;
}

// A received day is stored only after its signature and its place in the chain were checked.
export function isVerifiedDay(day: WatchDayFacts): boolean {
  return day.received;
}

export function verifiedDayCount(days: WatchDayFacts[]): number {
  let n = 0;
  for (let i = 0; i < days.length; i++) {
    if (isVerifiedDay(days[i])) {
      n++;
    }
  }
  return n;
}

// True for a day any part of which ran on the watch demo clock.
export function isDemoDay(day: WatchDayFacts): boolean {
  return day.received && day.clock !== CLOCK_REAL;
}

// The label shown on a demo day; empty for a day recorded on the real clock.
export function demoDayLabel(day: WatchDayFacts): string {
  if (!isDemoDay(day)) {
    return '';
  }
  return day.clock.endsWith(CLOCK_FEED_SUFFIX) ? DEMO_FEED_LABEL : DEMO_CLOCK_LABEL;
}

// "Off wrist 06:50–10:25"; a break that began the day before starts at "the day before".
export function breakText(b: BreakContext): string {
  const from = b.startMin < 0 ? `the day before ${minuteClock(b.startMin)}` : minuteClock(b.startMin);
  return `${WEAR_LABEL_OFF} ${from}–${minuteClock(b.endMin)}`;
}

// The newest `count` days of a newest-first list, returned oldest first (left to right on the strip).
export function stripDays(daysNewestFirst: WatchDayFacts[], count: number = STRIP_DAYS): WatchDayFacts[] {
  const out: WatchDayFacts[] = [];
  for (let i = Math.min(count, daysNewestFirst.length) - 1; i >= 0; i--) {
    out.push(daysNewestFirst[i]);
  }
  return out;
}

// Local midnight of the day that holds `ms`.
function localDayStart(ms: number): number {
  const d = new Date(ms);
  return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
}

// "Today 07:51", "Yesterday 21:10", "3 Oct 21:10" in the phone's local time.
export function syncTimeText(atMs: number, nowMs: number): string {
  if (atMs <= 0) {
    return NOT_SYNCED;
  }
  const d = new Date(atMs);
  const time = `${two(d.getHours())}:${two(d.getMinutes())}`;
  const dayGap = Math.round((localDayStart(nowMs) - localDayStart(atMs)) / DAY_MS);
  if (dayGap === 0) {
    return `Today ${time}`;
  }
  if (dayGap === 1) {
    return `Yesterday ${time}`;
  }
  return `${d.getDate()} ${MONTHS[d.getMonth()]} ${time}`;
}

// When the phone last heard from the watch: the newest entry of the sync log (newest first).
export function lastSyncText(log: SyncLogEntry[], nowMs: number): string {
  return log.length === 0 ? NOT_SYNCED : syncTimeText(log[0].atMs, nowMs);
}

// "2026-10-04 07:51:09", the raw local time for the sync log on "Verification details".
export function logTimeText(atMs: number): string {
  const d = new Date(atMs);
  return `${d.getFullYear()}-${two(d.getMonth() + 1)}-${two(d.getDate())} ` +
    `${two(d.getHours())}:${two(d.getMinutes())}:${two(d.getSeconds())}`;
}

// One line of the sync log: "#4 · Accepted · Missing 1 day(s)".
export function logLineText(entry: SyncLogEntry): string {
  const head = entry.seq > 0 ? `#${entry.seq} · ` : '';
  return entry.note.length > 0 ? `${head}${entry.message} · ${entry.note}` : `${head}${entry.message}`;
}

// The transport as named on "Verification details": the development relay is demo plumbing and says so.
export function transportLabel(transport: string): string {
  return transport === TRANSPORT_RELAY ? RELAY_LABEL : transport;
}

// "All 4 days verified", "3 of 4 days verified", "No day received yet".
export function verifiedSummary(verified: number, total: number): string {
  if (total <= 0) {
    return 'No day received yet';
  }
  if (verified === total) {
    return total === 1 ? '1 day verified' : `All ${total} days verified`;
  }
  return `${verified} of ${total} days verified`;
}

// "1 day never reached this phone"; empty when nothing is missing.
export function missingSummary(missing: number): string {
  if (missing <= 0) {
    return '';
  }
  return missing === 1 ? '1 day never reached this phone' : `${missing} days never reached this phone`;
}
