// The Watch Link tour on the phone: what each step does, the real code behind it and the tests that prove it.
// Pure data and helpers. Every code line below is copied verbatim from the named file; a logic test
// (TourSnippets.test.ets) fails if a line no longer exists there, so the tour cannot drift from the code.
import { ProbeStep, ReceivedPacketInfo } from '../watchlink/LinkProbe';
import { CLOCK_FEED_SUFFIX } from '../watchlink/DemoFeed';
import { CLOCK_REAL, SLOT_MINUTES } from '../watchlink/WatchLinkTypes';
import {
  dayTitle,
  DEMO_CLOCK_LABEL,
  DEMO_FEED_LABEL,
  minuteClock,
  WEAR_CHARGING,
  WEAR_LABEL_CHARGING,
  WEAR_LABEL_OFF,
  WEAR_LABEL_UNOBSERVED,
  WEAR_LABEL_WORN,
  WEAR_OFF,
  WEAR_UNOBSERVED,
  WEAR_WORN
} from './WatchDayPresent';

export const TOUR_TITLE: string = 'How Watch Link works';
export const TOUR_INTRO: string =
  'This page runs on this phone. Every value on it comes from the days your watch signed and sent.';
export const CODE_ELLIPSIS: string = '…';

export class TourStep {
  num: number;
  title: string;
  sentence: string;
  file: string;                     // path from the repository root
  code: string[];                   // verbatim lines; CODE_ELLIPSIS marks skipped lines
  testFile: string;                 // '' when no logic test covers the step
  provedBy: string[];               // test names in testFile
  limit: string;                    // what is not shown or not run, '' when nothing

  constructor(num: number, title: string, sentence: string, file: string, code: string[], testFile: string,
    provedBy: string[], limit: string) {
    this.num = num;
    this.title = title;
    this.sentence = sentence;
    this.file = file;
    this.code = code;
    this.testFile = testFile;
    this.provedBy = provedBy;
    this.limit = limit;
  }
}

const WATCHLINK_TESTS: string = 'common/src/test/WatchLink.test.ets';

export const TOUR_STEPS: TourStep[] = [
  new TourStep(1, 'The watch measures',
    'Sensor Service Kit reports heart rate, steps and wear; the battery state reports charging. Every second ' +
      'the watch decides: charging first, then the wear sensor, then a recent heart rate.',
    'common/src/main/ets/watchlink/WearStateMachine.ets',
    [
      '  state(realMs: number): SlotState {',
      '    if (this.charging) {',
      '      return \'C\';',
      '    }',
      '    if (this.wearSeen) {',
      '      return this.wearValue >= 1 ? \'W\' : \'O\';',
      '    }',
      '    if (this.lastValidHrMs >= 0 && realMs - this.lastValidHrMs <= this.freshnessMs) {',
      '      return \'W\';',
      '    }',
      '    return \'O\';',
      '  }'
    ],
    WATCHLINK_TESTS,
    [
      '1a. heart-rate gap of 59 s is worn, 61 s is off-wrist',
      '1b. charging overrides everything',
      '1c. the wear sensor wins over the heart-rate signal'
    ],
    ''),
  new TourStep(2, 'Time not observed is never held against you',
    'A five-minute slot the app watched for less than 150 seconds is "not observed". It never counts as ' +
      'off wrist and never becomes a break.',
    'common/src/main/ets/watchlink/WatchLinkTypes.ets',
    [
      'export function classifySlot(slot: SlotRecord): SlotState {',
      '  if (slot.observedSec < MIN_OBSERVED_SEC) {',
      '    return \'U\';',
      '  }',
      '  if (slot.chargingSec >= slot.wornSec && slot.chargingSec >= slot.offSec) {',
      '    return \'C\';',
      '  }',
      '  if (slot.wornSec >= slot.offSec) {',
      '    return \'W\';',
      '  }',
      '  return \'O\';',
      '}'
    ],
    WATCHLINK_TESTS,
    [
      '3a. 100 s observed is U; 200 s worn + 100 s off is W; a charging tie is C',
      '4. a suspension gap of 3 h is not observed (U) and creates no break',
      '6b. U never joins a break: O U O does not add up'
    ],
    ''),
  new TourStep(3, 'The day is sealed on the wrist',
    'At the end of a day the watch signs one summary with its own key in Universal Keystore Kit (HUKS) and ' +
      'links it to the day before. Measurements only: no verdict leaves the watch.',
    'common/src/main/ets/watchlink/PacketSealer.ets',
    [
      '      seq: state.seq + 1,',
      '      prev: state.lastHash,',
      CODE_ELLIPSIS,
      '    const signed = daySigningString(p);',
      '    p.sig = await signer.sign(signed);',
      '    const hash = await hasher.sha256B64url(signed);'
    ],
    WATCHLINK_TESTS,
    [
      '10a. the signing string is the fixed list of lines',
      '10b. sign then verify: the first packet of a chain is accepted',
      'a packet holds measurements only'
    ],
    'The watch key lives in HUKS on the watch; a software fallback is labelled and starts a new chain.'),
  new TourStep(4, 'Wear Engine carries it to the phone',
    'On paired devices Wear Engine Kit carries one day per message. Emulators cannot pair, so there the ' +
      'same files travel over hdc with the dev relay.',
    'watch/src/main/ets/watchlink/WearEngineTransport.ets',
    [
      'const MAX_MESSAGE_BYTES = 4096;',
      CODE_ELLIPSIS,
      '      const result = await wearEngine.getP2pClient(this.context).sendMessage(peer.randomId, appParam, message);',
      CODE_ELLIPSIS,
      '      const devices = await wearEngine.getDeviceClient(this.context).getConnectedDevices();'
    ],
    '',
    [],
    'Not run end to end: needs a paired watch and the Wear Engine service approved for the app.'),
  new TourStep(5, 'This phone checks every day',
    'A fixed order: format, version, the paired watch key, the signature (Crypto Architecture Kit, on this ' +
      'phone), the chain, the date. Only then is a day taken in.',
    'common/src/main/ets/watchlink/DayPacketVerifier.ets',
    [
      '    // 3: the key has to be the pinned one',
      '    if (ledger === null || ledger.kid !== p.kid) {',
      '      out.message = MSG_UNKNOWN_KEY;',
      '      return out;',
      '    }',
      '    // 4: signature over the signing string',
      '    const signed = daySigningString(p);',
      '    const sigOk = await this.verifier.verify(ledger.pubB64, signed, p.sig);',
      '    if (!sigOk) {',
      '      out.message = MSG_INVALID_SIGNATURE;',
      '      return out;',
      '    }'
    ],
    WATCHLINK_TESTS,
    [
      '11. one changed slots character is an invalid signature',
      '14. unknown key, bad JSON, unsupported version'
    ],
    ''),
  new TourStep(6, 'A missing day stays visible',
    'Each day carries the hash of the one before. A skipped day is recorded as missing, a replay counts ' +
      'once, a late day must link to both neighbours.',
    'common/src/main/ets/watchlink/ChainLedger.ets',
    [
      '      for (let s = this.lastSeq + 1; s < seq; s++) {',
      '        out.missing.push(s);',
      '      }',
      '      out.kind = \'GAP\';',
      CODE_ELLIPSIS,
      '      out.kind = known.hash === hash ? \'DUPLICATE\' : \'CONFLICT\';'
    ],
    WATCHLINK_TESTS,
    [
      '12. a replay is a duplicate; the same seq with other content is a chain conflict',
      '13. seq 3 after 1 is accepted with "Missing 1 day(s)"; the late day then fills the gap',
      '13b. a late day that does not link to its neighbours is a chain conflict'
    ],
    '')
];

// The verifier's order, as the tour lists it next to the newest accepted day.
export const VERIFY_ORDER: string[] = [
  'Format and fields',
  'Version',
  'Paired watch key',
  'Signature',
  'Chain',
  'Date',
  'Taken in'
];

export const LEAVES_PHONE: string =
  'Only the signed tier claim leaves this phone. The phone app declares no permissions, so it has no network ' +
    'access; the days from the watch stay here.';

export class ReviewRow {
  left: string;
  right: string;

  constructor(left: string, right: string) {
    this.left = left;
    this.right = right;
  }
}

// What is real and what is simulated in this build. Keep in step with the README.
export const REAL_ROWS: ReviewRow[] = [
  new ReviewRow('Recorder, signed days, chain, checks', 'Real code, run on both emulators and in the logic tests.'),
  new ReviewRow('Watch key', 'HUKS on the wearable emulator; a software key is labelled when HUKS fails.'),
  new ReviewRow('Heart rate and steps', 'The emulator sends 0 bpm, so a scripted demo feed runs; its days say so.'),
  new ReviewRow('Watch to phone', 'Dev relay over hdc on the emulators; Wear Engine code is in place, not run.'),
  new ReviewRow('Recording time', 'Only while the watch app is open; time in the background is not observed.'),
  new ReviewRow('Score', 'Days from the watch are shown, not scored.')
];

export class SlotRun {
  state: string;                    // WEAR_WORN, WEAR_CHARGING, WEAR_OFF or WEAR_UNOBSERVED
  count: number;                    // number of five-minute slots

  constructor(state: string, count: number) {
    this.state = state;
    this.count = count;
  }
}

export function slotState(c: string): string {
  if (c === 'W') {
    return WEAR_WORN;
  }
  if (c === 'C') {
    return WEAR_CHARGING;
  }
  if (c === 'O') {
    return WEAR_OFF;
  }
  return WEAR_UNOBSERVED;
}

export function slotStateLabel(state: string): string {
  if (state === WEAR_WORN) {
    return WEAR_LABEL_WORN;
  }
  if (state === WEAR_CHARGING) {
    return WEAR_LABEL_CHARGING;
  }
  if (state === WEAR_OFF) {
    return WEAR_LABEL_OFF;
  }
  return WEAR_LABEL_UNOBSERVED;
}

// The 288-character slot string as runs of one state, for drawing the day as one bar.
export function slotRuns(slots: string): SlotRun[] {
  const out: SlotRun[] = [];
  for (let i = 0; i < slots.length; i++) {
    const state = slotState(slots.charAt(i));
    const last = out.length > 0 ? out[out.length - 1] : null;
    if (last !== null && last.state === state) {
      last.count++;
    } else {
      out.push(new SlotRun(state, 1));
    }
  }
  return out;
}

export function wearSourceText(source: string): string {
  return source === 'SENSOR' ? 'wear sensor' : 'heart-rate signal';
}

// What was sent in one step of a check, in plain words.
export function probeStepLabel(step: ProbeStep): string {
  const day = step.date.length > 0 ? dayTitle(step.date) : 'The newest day';
  if (step.action === 'CHANGED') {
    const from = slotStateLabel(slotState(step.fromSlot)).toLowerCase();
    const to = slotStateLabel(slotState(step.toSlot)).toLowerCase();
    return `${day}, ${minuteClock(0)}–${minuteClock(5)} changed from ${from} to ${to}`;
  }
  if (step.action === 'SENT_AGAIN') {
    return `${day} sent again, unchanged`;
  }
  if (step.action === 'SENT_AHEAD') {
    const held = step.heldDate.length > 0 ? dayTitle(step.heldDate) : 'the day before';
    return `${day} arrives while ${held} is held back`;
  }
  return `${day} arrives late`;
}

// One result line of a check: the verifier message, then the note.
export function probeLine(step: ProbeStep): string {
  return step.note.length > 0 ? `${step.message} · ${step.note}` : step.message;
}

export function elapsedText(ms: number): string {
  return ms < 1 ? 'Checked on this phone in under 1 ms' : `Checked on this phone in ${Math.round(ms)} ms`;
}

// Code lines as shown on screen: the common indentation removed, skipped parts kept as "…".
export function displayCode(lines: string[]): string[] {
  let indent = -1;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line === CODE_ELLIPSIS || line.trim().length === 0) {
      continue;
    }
    let n = 0;
    while (n < line.length && line.charAt(n) === ' ') {
      n++;
    }
    if (indent < 0 || n < indent) {
      indent = n;
    }
  }
  const out: string[] = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    out.push(line === CODE_ELLIPSIS || indent <= 0 ? line : line.substring(Math.min(indent, line.length)));
  }
  return out;
}

// "Thu 8 Oct · 812 bytes · signed by your watch · linked to the day before": the newest day in one line.
// No key id, hash or sequence number: those stay on "Verification details".
export function packetLine(info: ReceivedPacketInfo): string {
  const link = info.firstOfChain ? 'the first day from this watch' : 'linked to the day before';
  return `${dayTitle(info.date)} · ${info.bytes} bytes · signed by your watch · ${link}`;
}

// Minutes of a slot string that the watch did not observe.
export function notObservedMinutes(slots: string): number {
  let n = 0;
  for (let i = 0; i < slots.length; i++) {
    if (slotState(slots.charAt(i)) === WEAR_UNOBSERVED) {
      n++;
    }
  }
  return n * SLOT_MINUTES;
}

// The demo label of a packet's clock; empty for the real clock.
export function demoClockText(clock: string): string {
  if (clock === CLOCK_REAL || clock.length === 0) {
    return '';
  }
  return clock.endsWith(CLOCK_FEED_SUFFIX) ? DEMO_FEED_LABEL : DEMO_CLOCK_LABEL;
}
