// Read-only checks the phone can run on the days it already received, for the Watch Link tour.
// Each check runs the real DayPacketVerifier against a COPY of the chain ledger: nothing is written,
// no ACK is sent, the stored days and the chain stay exactly as they were.
// Facts only: the wording of each step is in present/TourContent.ets.
import { AckStatus } from './WatchLinkTypes';

export type ProbeKind = 'TAMPER' | 'REPLAY' | 'LATE';

// What was sent in one step of a check.
export type ProbeAction = 'CHANGED' | 'SENT_AGAIN' | 'SENT_AHEAD' | 'SENT_LATE';

export const PROBE_NEEDS_DAY: string = 'Needs one day received from the watch';
export const PROBE_NEEDS_TWO: string = 'Needs two days in a row received from the watch';
export const PROBE_LEDGER_UNREADABLE: string = 'The stored days could not be read';
export const NOTE_NOT_TAKEN: string = 'Not taken in';
export const NOTE_COUNTED_ONCE: string = 'Acknowledged again, counted once';
export const NOTE_FILLS_GAP: string = 'Fills the gap';
export const STORED_UNCHANGED: string = 'Your stored days were not changed.';

export class ProbeStep {
  action: ProbeAction = 'CHANGED';
  date: string = '';                // the day that was sent
  heldDate: string = '';            // SENT_AHEAD: the day held back
  fromSlot: string = '';            // CHANGED: the first slot before and after the change
  toSlot: string = '';
  status: AckStatus = 'REJECTED';
  message: string = '';             // the verifier message
  note: string = '';
}

export class ProbeResult {
  kind: ProbeKind;
  ran: boolean = false;
  reason: string = '';              // why the check did not run
  steps: ProbeStep[] = [];
  elapsedMs: number = 0;
  storedUnchanged: boolean = true;

  constructor(kind: ProbeKind) {
    this.kind = kind;
  }
}

// The newest day received from the watch, as the tour shows it. Facts only; no key id, hash or
// sequence number is meant for the screen.
export class ReceivedPacketInfo {
  seq: number = 0;
  date: string = '';
  bytes: number = 0;                // size of the signed packet as stored, in bytes
  firstOfChain: boolean = false;    // true for the first day from this watch
  clock: string = '';
  wearSource: string = '';
  slots: string = '';
  breakCount: number = 0;
}

export function probeTitle(kind: ProbeKind): string {
  if (kind === 'TAMPER') {
    return 'Change five minutes of one day';
  }
  if (kind === 'REPLAY') {
    return 'Send the same day again';
  }
  return 'Hold a day back';
}

// "W" -> "O", anything else -> "W": a valid slot character, so only the signature can catch it.
export function flippedSlot(c: string): string {
  return c === 'W' ? 'O' : 'W';
}

// UTF-8 byte length without a platform encoder.
export function utf8Length(text: string): number {
  let n = 0;
  for (let i = 0; i < text.length; i++) {
    const c = text.charCodeAt(i);
    if (c < 0x80) {
      n += 1;
    } else if (c < 0x800) {
      n += 2;
    } else if (c >= 0xD800 && c <= 0xDBFF) {
      n += 4;
      i++;
    } else {
      n += 3;
    }
  }
  return n;
}
