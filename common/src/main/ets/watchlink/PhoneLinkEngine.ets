// Everything the phone does for Watch Link, without the platform: reads the inbox, checks pairing
// requests and day packets, keeps the chain ledger, writes ACKs and keeps the accepted packets.
// It checks origin and integrity only. Whether a day is compliant, whether a break is suspicious,
// the flag and the tier are decided by the existing rule code from the facts below.
//
// Files (relative to the app's files directory):
//   inbox/pair.json, inbox/<seq>.json   delivered by a transport, removed once processed
//   acks/<seq>.json                     ACKs for the watch (seq 0 answers the pairing request), each signed
//                                       with the phone's Watch Link key and tied to the packet it answers
//   watchlink/ledger.json               the pinned watch and its chain
//   watchlink/pending-pair.json         a valid pairing request waiting for the user
//   watchlink/days/<seq>.json           accepted day packets
//   watchlink/log.json                  the last sync messages
import { ChainLedger } from './ChainLedger';
import { AckPacketCodec, DayPacketCodec, PAIR_ACK_SEQ, PairPacketCodec } from './DayPacketCodec';
import { DayPacketVerifier, PairVerifier, VerifyOutcome } from './DayPacketVerifier';
import { PacketSealer } from './PacketSealer';
import { asObject, parseJsonObject, readArray, readInt, readString } from './JsonRead';
import { SettleGate } from './SettleGate';
import {
  flippedSlot,
  NOTE_COUNTED_ONCE,
  NOTE_FILLS_GAP,
  NOTE_NOT_TAKEN,
  PROBE_LEDGER_UNREADABLE,
  PROBE_NEEDS_DAY,
  PROBE_NEEDS_TWO,
  ProbeAction,
  ProbeKind,
  ProbeResult,
  ProbeStep,
  ReceivedPacketInfo,
  utf8Length
} from './LinkProbe';
import { Clock, Hasher, Signer, SigVerifier, TextStore } from './WatchLinkPorts';
import { daySigningString, pairSigningString } from './WatchLinkSigning';
import {
  AckStatus,
  BreakContext,
  DayPacket,
  GENESIS,
  NIGHT_SLOT_COUNT,
  PairPacket,
  SLOT_MINUTES,
  SLOTS_PER_DAY,
  TYPE_PAIR
} from './WatchLinkTypes';

export const INBOX_DIR: string = 'inbox';
export const PHONE_ACKS_DIR: string = 'acks';
export const LEDGER_FILE: string = 'watchlink/ledger.json';
export const PENDING_PAIR_FILE: string = 'watchlink/pending-pair.json';
export const LINK_DAYS_DIR: string = 'watchlink/days';
export const LOG_FILE: string = 'watchlink/log.json';

export const MSG_PAIR_REQUEST: string = 'Pairing request received';
export const MSG_PAIRED: string = 'Paired';
export const MSG_OTHER_WATCH: string = 'Another watch is paired';
export const TRANSPORT_RELAY: string = 'Dev relay (emulator)';
export const TRANSPORT_WEAR_ENGINE: string = 'Wear Engine';

const JSON_SUFFIX: string = '.json';
const PAIR_NAME: string = 'pair.json';
const LOG_CAP: number = 12;
const ACK_CAP: number = 40;

export interface SyncLogEntry {
  atMs: number;
  seq: number;        // 0 for pairing and for packets that did not decode
  message: string;    // the verifier message
  note: string;       // 'Missing N day(s)', the transport, ...
}

class LogFile {
  entries: SyncLogEntry[] = [];
}

// What the watch reported for one day, as plain minutes. Inputs for the rules; no verdict.
export class WatchDayFacts {
  seq: number = 0;
  date: string = '';
  received: boolean = false;        // false: the phone knows the seq exists but never got the packet
  reason: string = '';              // for a missing day: 'No data received from watch (#seq)'
  wornMin: number = 0;
  chargingMin: number = 0;
  offMin: number = 0;
  notObservedMin: number = 0;
  nightWornMin: number = 0;
  nightChargingMin: number = 0;
  steps: number = 0;
  hrSlotCount: number = 0;
  breaks: BreakContext[] = [];
  wearSource: string = '';
  clock: string = '';
  sourceLine: string = '';          // 'Source: FairWear watch · #7 · Signature valid'
}

export class PhoneLinkView {
  paired: boolean = false;
  kid: string = '';
  pendingPairKid: string = '';      // not empty: ask 'Pair watch <kid>?'
  lastSeq: number = 0;
  lastDate: string = '';
  missingCount: number = 0;
  pairLine: string = 'Not paired';
  chainLine: string = '';           // 'Chain #7 ✓' or '1 day missing'
  transport: string = TRANSPORT_RELAY;
  log: SyncLogEntry[] = [];
}

export class SyncReport {
  processed: number = 0;
  accepted: number = 0;
  rejected: number = 0;
  pairRequested: boolean = false;
}

function seqOfName(name: string): number {
  if (!name.endsWith(JSON_SUFFIX)) {
    return -1;
  }
  const text = name.substring(0, name.length - JSON_SUFFIX.length);
  if (text.length === 0 || text.length > 10) {
    return -1;
  }
  for (let i = 0; i < text.length; i++) {
    const c = text.charCodeAt(i);
    if (c < 48 || c > 57) {
      return -1;
    }
  }
  return Number.parseInt(text, 10);
}

export function missingDayReason(seq: number): string {
  return `No data received from watch (#${seq})`;
}

export function sourceLine(seq: number): string {
  return `Source: FairWear watch · #${seq} · Signature valid`;
}

export function factsOfPacket(p: DayPacket): WatchDayFacts {
  const f = new WatchDayFacts();
  f.seq = p.seq;
  f.date = p.date;
  f.received = true;
  let worn = 0;
  let charging = 0;
  let off = 0;
  let unknown = 0;
  for (let i = 0; i < SLOTS_PER_DAY; i++) {
    const ch = p.slots.charAt(i);
    if (ch === 'W') {
      worn++;
    } else if (ch === 'C') {
      charging++;
    } else if (ch === 'O') {
      off++;
    } else {
      unknown++;
    }
  }
  f.wornMin = worn * SLOT_MINUTES;
  f.chargingMin = charging * SLOT_MINUTES;
  f.offMin = off * SLOT_MINUTES;
  f.notObservedMin = unknown * SLOT_MINUTES;
  f.nightWornMin = p.nightWornMin;
  f.nightChargingMin = p.nightChargingMin;
  let steps = 0;
  for (let h = 0; h < p.stepsByHour.length; h++) {
    steps += p.stepsByHour[h];
  }
  f.steps = steps;
  f.hrSlotCount = p.hrSlotCount;
  f.breaks = p.breaks;
  f.wearSource = p.wearSource;
  f.clock = p.clock;
  f.sourceLine = sourceLine(p.seq);
  return f;
}

// A day the chain proves exists but that never arrived: zero worn minutes, no breaks.
// It counts as not worn; it must never create a break or a suspicious day.
export function factsOfMissing(seq: number): WatchDayFacts {
  const f = new WatchDayFacts();
  f.seq = seq;
  f.received = false;
  f.reason = missingDayReason(seq);
  f.notObservedMin = SLOTS_PER_DAY * SLOT_MINUTES;
  return f;
}

// Night minutes of a slot string, for callers that only kept the string.
export function nightWornMinutes(slots: string): number {
  let worn = 0;
  for (let i = 0; i < NIGHT_SLOT_COUNT && i < slots.length; i++) {
    if (slots.charAt(i) === 'W') {
      worn++;
    }
  }
  return worn * SLOT_MINUTES;
}

export class PhoneLinkEngine {
  private store: TextStore;
  private verifier: SigVerifier;
  private hasher: Hasher;
  private clock: Clock;
  private signer: Signer;
  private dayVerifier: DayPacketVerifier;
  private ledger: ChainLedger | null = null;
  private pendingPair: PairPacket | null = null;
  private log: SyncLogEntry[] = [];
  private lastTransport: string = TRANSPORT_RELAY;
  private busy: boolean = false;
  // inbox/ files that may still be on their way: left for one more look before they are answered.
  private inboxGate: SettleGate = new SettleGate();

  // `signer` is the phone's Watch Link key: every ACK is signed with it, and the watch pins it at pairing.
  // allowDemoClock: see DayPacketVerifier. Off by default; the demo build turns it on explicitly.
  constructor(store: TextStore, verifier: SigVerifier, hasher: Hasher, clock: Clock, signer: Signer,
    allowDemoClock: boolean = false) {
    this.store = store;
    this.verifier = verifier;
    this.hasher = hasher;
    this.clock = clock;
    this.signer = signer;
    this.dayVerifier = new DayPacketVerifier(verifier, hasher, clock, allowDemoClock);
  }

  // Restores the pinned watch, a waiting pairing request and the log. Call once at app start.
  load(): void {
    const ledgerText = this.store.read(LEDGER_FILE);
    this.ledger = ledgerText === null ? null : ChainLedger.fromJson(ledgerText);
    const pairText = this.store.read(PENDING_PAIR_FILE);
    this.pendingPair = pairText === null ? null : PairPacketCodec.fromJson(pairText).packet;
    this.log = this.readLog();
  }

  // Processes everything in inbox/: the pairing request first, then day packets by seq.
  async scanInbox(): Promise<SyncReport> {
    const report = new SyncReport();
    if (this.busy) {
      return report;
    }
    this.busy = true;
    try {
      const names = this.store.list(INBOX_DIR);
      const seqs: number[] = [];
      let hasPair = false;
      for (let i = 0; i < names.length; i++) {
        if (names[i] === PAIR_NAME) {
          hasPair = true;
        } else if (seqOfName(names[i]) > 0) {
          seqs.push(seqOfName(names[i]));
        }
      }
      if (hasPair) {
        const path = `${INBOX_DIR}/${PAIR_NAME}`;
        const text = this.store.read(path);
        // A file the relay is still writing is left for the next look (see SettleGate).
        if (this.inboxGate.ready(PAIR_NAME, text)) {
          // Removed only after the answer is written: the relay fetches acks/ once inbox/ is empty.
          try {
            if (text !== null) {
              report.processed++;
              report.pairRequested = await this.receivePair(text, TRANSPORT_RELAY);
            }
          } finally {
            this.store.remove(path);
          }
        }
      }
      seqs.sort((a: number, b: number) => a - b);
      for (let i = 0; i < seqs.length; i++) {
        const name = `${seqs[i]}${JSON_SUFFIX}`;
        const path = `${INBOX_DIR}/${name}`;
        const text = this.store.read(path);
        if (!this.inboxGate.ready(name, text)) {
          continue;
        }
        if (text === null) {
          this.store.remove(path);
          continue;
        }
        report.processed++;
        // As above: the file goes only once the ACK is on disk (or the attempt failed).
        let out: VerifyOutcome = new VerifyOutcome();
        try {
          out = await this.receiveDay(text, seqs[i], TRANSPORT_RELAY);
        } finally {
          this.store.remove(path);
        }
        if (out.status === 'REJECTED') {
          report.rejected++;
        } else if (out.status === 'ACCEPTED') {
          report.accepted++;
        }
      }
    } finally {
      this.busy = false;
    }
    return report;
  }

  // One message from a direct transport (Wear Engine): a pairing request or a day packet.
  async receive(json: string, transport: string): Promise<void> {
    const o = parseJsonObject(json);
    const type = o === null ? null : readString(o, 'type');
    if (type === TYPE_PAIR) {
      await this.receivePair(json, transport);
    } else {
      await this.receiveDay(json, 0, transport);
    }
  }

  // True when the request is valid and now waits for the user's confirmation.
  async receivePair(json: string, transport: string): Promise<boolean> {
    this.lastTransport = transport;
    const out = await PairVerifier.verify(json, this.verifier, this.hasher);
    const p = out.packet;
    const ref = p === null ? '' : await this.hasher.sha256B64url(pairSigningString(p));
    const watchKid = p === null ? '' : p.kid;
    if (!out.ok || p === null) {
      this.addLog(PAIR_ACK_SEQ, out.message, 'Pairing request');
      await this.writeAck(PAIR_ACK_SEQ, 'REJECTED', out.message, watchKid, ref);
      return false;
    }
    const pinned = this.ledger;
    if (pinned !== null) {
      if (pinned.kid === p.kid && pinned.pubB64 === p.pub) {
        // The same watch asks again (its ACK was lost): answer again, change nothing.
        await this.writeAck(PAIR_ACK_SEQ, 'ACCEPTED', MSG_PAIRED, watchKid, ref);
        return false;
      }
      this.addLog(PAIR_ACK_SEQ, MSG_OTHER_WATCH, `Forget ${pinned.kid} first`);
      await this.writeAck(PAIR_ACK_SEQ, 'REJECTED', MSG_OTHER_WATCH, watchKid, ref);
      return false;
    }
    this.pendingPair = p;
    this.store.writeAtomic(PENDING_PAIR_FILE, PairPacketCodec.toJson(p));
    this.addLog(PAIR_ACK_SEQ, MSG_PAIR_REQUEST, p.kid);
    return true;
  }

  // The user confirmed the code shown on both screens: pin the watch key. The ACK carries the phone key,
  // which the watch pins in turn.
  async confirmPair(): Promise<boolean> {
    const p = this.pendingPair;
    if (p === null) {
      return false;
    }
    this.ledger = new ChainLedger(p.kid, p.pub);
    this.saveLedger();
    this.pendingPair = null;
    this.store.remove(PENDING_PAIR_FILE);
    this.addLog(PAIR_ACK_SEQ, MSG_PAIRED, p.kid);
    const ref = await this.hasher.sha256B64url(pairSigningString(p));
    await this.writeAck(PAIR_ACK_SEQ, 'ACCEPTED', MSG_PAIRED, p.kid, ref);
    return true;
  }

  // Key id of the phone's Watch Link key (the watch shows it once paired).
  phoneKid(): string {
    return this.signer.kid();
  }

  declinePair(): void {
    this.pendingPair = null;
    this.store.remove(PENDING_PAIR_FILE);
  }

  // "Forget watch": unpins the key and clears the ledger and the days received from it.
  forget(): void {
    this.ledger = null;
    this.pendingPair = null;
    this.store.remove(LEDGER_FILE);
    this.store.remove(PENDING_PAIR_FILE);
    const names = this.store.list(LINK_DAYS_DIR);
    for (let i = 0; i < names.length; i++) {
      this.store.remove(`${LINK_DAYS_DIR}/${names[i]}`);
    }
    // Old ACKs must not reach a watch that pairs again: it would see "paired" before Confirm.
    const acks = this.store.list(PHONE_ACKS_DIR);
    for (let i = 0; i < acks.length; i++) {
      this.store.remove(`${PHONE_ACKS_DIR}/${acks[i]}`);
    }
    this.inboxGate.clear();
    this.log = [];
    this.saveLog();
  }

  // Verifies one day packet, answers with an ACK and keeps it when accepted.
  // `fileSeq` is the seq from the file name, used for the ACK when the content does not decode.
  async receiveDay(json: string, fileSeq: number, transport: string): Promise<VerifyOutcome> {
    this.lastTransport = transport;
    const ledger = this.ledger;
    // Verified without committing: the day file is written first, then the chain records the day. If the
    // write fails, the chain is unchanged and no ACK is written, so the watch keeps the packet and sends it
    // again (never "Duplicate day" for a day the phone does not have).
    const out = await this.dayVerifier.verify(json, ledger, false);
    const p = out.packet;
    const seq = p === null ? fileSeq : p.seq;
    if (out.status === 'ACCEPTED' && p !== null && ledger !== null) {
      this.store.writeAtomic(`${LINK_DAYS_DIR}/${p.seq}${JSON_SUFFIX}`, DayPacketCodec.toJson(p));
      // The same packet may have arrived over the other transport while this one was awaited: it is then
      // already in the chain, and is not counted twice.
      const again = ledger.check(p.seq, p.prev, out.hash).kind;
      if (again === 'NEXT' || again === 'GAP' || again === 'FILL') {
        ledger.commit(p.seq, p.prev, out.hash, p.date);
        this.saveLedger();
      }
    }
    this.addLog(seq, out.message, out.note);
    if (seq > 0) {
      const ref = p === null ? '' : await this.hasher.sha256B64url(daySigningString(p));
      const watchKid = p !== null ? p.kid : (ledger !== null ? ledger.kid : '');
      await this.writeAck(seq, out.status, out.note.length > 0 ? `${out.message} · ${out.note}` : out.message,
        watchKid, ref);
    }
    return out;
  }

  isPaired(): boolean {
    return this.ledger !== null;
  }

  // True when a transport left something in inbox/.
  hasInbox(): boolean {
    return this.store.list(INBOX_DIR).length > 0;
  }

  // Every day the chain knows about, by seq: the facts of the packets received, and a placeholder
  // for each one the chain proves exists but that never arrived.
  timeline(): WatchDayFacts[] {
    const out: WatchDayFacts[] = [];
    const ledger = this.ledger;
    if (ledger === null) {
      return out;
    }
    for (let seq = 1; seq <= ledger.lastSeq; seq++) {
      if (ledger.isMissing(seq)) {
        out.push(factsOfMissing(seq));
        continue;
      }
      const p = this.packet(seq);
      if (p !== null) {
        out.push(factsOfPacket(p));
      }
    }
    return out;
  }

  packet(seq: number): DayPacket | null {
    const text = this.store.read(`${LINK_DAYS_DIR}/${seq}${JSON_SUFFIX}`);
    return text === null ? null : DayPacketCodec.fromJson(text).packet;
  }

  view(): PhoneLinkView {
    const v = new PhoneLinkView();
    const ledger = this.ledger;
    v.transport = this.lastTransport;
    v.log = this.log.slice();
    v.pendingPairKid = this.pendingPair === null ? '' : this.pendingPair.kid;
    if (ledger === null) {
      return v;
    }
    v.paired = true;
    v.kid = ledger.kid;
    v.pairLine = `Paired · ${ledger.kid}`;
    v.lastSeq = ledger.lastSeq;
    v.lastDate = ledger.lastDate;
    v.missingCount = ledger.missingSeqs.length;
    if (v.missingCount > 0) {
      v.chainLine = v.missingCount === 1 ? '1 day missing' : `${v.missingCount} days missing`;
    } else if (ledger.lastSeq > 0) {
      v.chainLine = `Chain #${ledger.lastSeq} ✓`;
    }
    return v;
  }

  // ---- Watch Link tour: read-only. Nothing below writes a file, the log or an ACK. ----

  // The newest day received from the watch (not a missing placeholder), or -1.
  latestReceivedSeq(): number {
    const ledger = this.ledger;
    if (ledger === null) {
      return -1;
    }
    for (let seq = ledger.lastSeq; seq >= 1; seq--) {
      if (!ledger.isMissing(seq) && this.packetText(seq) !== null) {
        return seq;
      }
    }
    return -1;
  }

  // What the newest received packet carried, for the tour. Null when no day was received yet.
  latestReceived(): ReceivedPacketInfo | null {
    const seq = this.latestReceivedSeq();
    const text = seq < 0 ? null : this.packetText(seq);
    const p = text === null ? null : DayPacketCodec.fromJson(text).packet;
    if (text === null || p === null) {
      return null;
    }
    const info = new ReceivedPacketInfo();
    info.seq = p.seq;
    info.date = p.date;
    info.bytes = utf8Length(text);
    info.firstOfChain = p.prev === GENESIS;
    info.clock = p.clock;
    info.wearSource = p.wearSource;
    info.slots = p.slots;
    info.breakCount = p.breaks.length;
    return info;
  }

  // Runs the real verifier on received days against a copy of the chain. See LinkProbe.ets.
  async probe(kind: ProbeKind): Promise<ProbeResult> {
    const out = new ProbeResult(kind);
    const ledger = this.ledger;
    const seq = this.latestReceivedSeq();
    if (ledger === null || seq < 0) {
      out.reason = PROBE_NEEDS_DAY;
      return out;
    }
    const before = ledger.toJson();
    const started = this.clock.nowMs();
    if (kind === 'TAMPER') {
      await this.probeTamper(ledger, seq, out);
    } else if (kind === 'REPLAY') {
      await this.probeReplay(ledger, seq, out);
    } else {
      await this.probeLate(ledger, seq, out);
    }
    out.elapsedMs = Math.max(0, this.clock.nowMs() - started);
    out.storedUnchanged = this.ledger !== null && this.ledger.toJson() === before;
    return out;
  }

  private async probeTamper(ledger: ChainLedger, seq: number, out: ProbeResult): Promise<void> {
    const text = this.packetText(seq);
    const p = text === null ? null : DayPacketCodec.fromJson(text).packet;
    const copy = ChainLedger.fromJson(ledger.toJson());
    if (p === null || copy === null) {
      out.reason = PROBE_LEDGER_UNREADABLE;
      return;
    }
    const from = p.slots.charAt(0);
    const to = flippedSlot(from);
    const date = p.date;
    p.slots = to + p.slots.substring(1);
    const res = await this.dayVerifier.verify(DayPacketCodec.toJson(p), copy);
    const step = PhoneLinkEngine.probeStep('CHANGED', date, res, res.status === 'REJECTED' ? NOTE_NOT_TAKEN : '');
    step.fromSlot = from;
    step.toSlot = to;
    out.steps.push(step);
    out.ran = true;
  }

  private async probeReplay(ledger: ChainLedger, seq: number, out: ProbeResult): Promise<void> {
    const text = this.packetText(seq);
    const copy = ChainLedger.fromJson(ledger.toJson());
    if (text === null || copy === null) {
      out.reason = PROBE_LEDGER_UNREADABLE;
      return;
    }
    const countBefore = copy.acceptedCount();
    const res = await this.dayVerifier.verify(text, copy);
    out.steps.push(PhoneLinkEngine.probeStep('SENT_AGAIN', PhoneLinkEngine.dateOf(res), res,
      res.status === 'DUPLICATE' && copy.acceptedCount() === countBefore ? NOTE_COUNTED_ONCE : ''));
    out.ran = true;
  }

  // Rebuilds the chain as it stood before day seq-1, then delivers day seq first and day seq-1 late.
  private async probeLate(ledger: ChainLedger, seq: number, out: ProbeResult): Promise<void> {
    const later = this.packetText(seq);
    const held = seq >= 2 && !ledger.isMissing(seq - 1) ? this.packetText(seq - 1) : null;
    if (later === null || held === null) {
      out.reason = PROBE_NEEDS_TWO;
      return;
    }
    const rebuilt = new ChainLedger(ledger.kid, ledger.pubB64);
    for (let s = 1; s <= seq - 2; s++) {
      const e = ledger.entry(s);
      if (e !== null) {
        rebuilt.commit(e.seq, e.prev, e.hash, e.date);
      }
    }
    const first = await this.dayVerifier.verify(later, rebuilt);
    const second = await this.dayVerifier.verify(held, rebuilt);
    const ahead = PhoneLinkEngine.probeStep('SENT_AHEAD', PhoneLinkEngine.dateOf(first), first, first.note);
    ahead.heldDate = PhoneLinkEngine.dateOf(second);
    out.steps.push(ahead);
    out.steps.push(PhoneLinkEngine.probeStep('SENT_LATE', PhoneLinkEngine.dateOf(second), second,
      second.filledMissing ? NOTE_FILLS_GAP : second.note));
    out.ran = true;
  }

  private static dateOf(res: VerifyOutcome): string {
    return res.packet === null ? '' : res.packet.date;
  }

  private static probeStep(action: ProbeAction, date: string, res: VerifyOutcome, note: string): ProbeStep {
    const step = new ProbeStep();
    step.action = action;
    step.date = date;
    step.status = res.status;
    step.message = res.message;
    step.note = note;
    return step;
  }

  private packetText(seq: number): string | null {
    return this.store.read(`${LINK_DAYS_DIR}/${seq}${JSON_SUFFIX}`);
  }

  private async writeAck(seq: number, status: AckStatus, reason: string, watchKid: string, ref: string):
    Promise<void> {
    const unsigned = AckPacketCodec.make(seq, status, reason, watchKid, ref, '', '',
      Math.floor(this.clock.nowMs() / 1000));
    const ack = await PacketSealer.sealAck(unsigned, this.signer);
    this.store.writeAtomic(`${PHONE_ACKS_DIR}/${seq}${JSON_SUFFIX}`, AckPacketCodec.toJson(ack));
    // ACK files are picked up by the transport; the app only keeps the newest ones.
    const seqs: number[] = [];
    const names = this.store.list(PHONE_ACKS_DIR);
    for (let i = 0; i < names.length; i++) {
      const s = seqOfName(names[i]);
      if (s > 0) {
        seqs.push(s);
      }
    }
    seqs.sort((a: number, b: number) => a - b);
    while (seqs.length > ACK_CAP) {
      const oldest = seqs.shift();
      if (oldest !== undefined) {
        this.store.remove(`${PHONE_ACKS_DIR}/${oldest}${JSON_SUFFIX}`);
      }
    }
  }

  private saveLedger(): void {
    const ledger = this.ledger;
    if (ledger !== null) {
      this.store.writeAtomic(LEDGER_FILE, ledger.toJson());
    }
  }

  private addLog(seq: number, message: string, note: string): void {
    const entry: SyncLogEntry = { atMs: this.clock.nowMs(), seq: seq, message: message, note: note };
    this.log.unshift(entry);
    while (this.log.length > LOG_CAP) {
      this.log.pop();
    }
    this.saveLog();
  }

  private saveLog(): void {
    const file = new LogFile();
    file.entries = this.log;
    this.store.writeAtomic(LOG_FILE, JSON.stringify(file));
  }

  private readLog(): SyncLogEntry[] {
    const out: SyncLogEntry[] = [];
    const text = this.store.read(LOG_FILE);
    const o = text === null ? null : parseJsonObject(text);
    const raw = o === null ? null : readArray(o, 'entries');
    if (raw === null) {
      return out;
    }
    for (let i = 0; i < raw.length && out.length < LOG_CAP; i++) {
      const e = asObject(raw[i]);
      if (e === null) {
        continue;
      }
      const atMs = readInt(e, 'atMs');
      const seq = readInt(e, 'seq');
      const message = readString(e, 'message');
      const note = readString(e, 'note');
      if (atMs !== null && seq !== null && message !== null && note !== null) {
        const entry: SyncLogEntry = { atMs: atMs, seq: seq, message: message, note: note };
        out.push(entry);
      }
    }
    return out;
  }
}
