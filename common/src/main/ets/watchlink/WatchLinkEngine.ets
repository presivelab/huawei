// Everything the watch does for Watch Link, without the platform: wear state, slot recorder, recorder
// clock, day close, signing, outbox, pairing request and ACK handling. Sensors, timer, files and keys
// are passed in, so the same code runs on the watch and in the Node tests.
//
// Files (relative to the app's files directory):
//   days/<date>.json    slot records, 3 days
//   outbox/<seq>.json   signed day packets, deleted after the phone's ACK, at most 30
//   pair.json           the pairing request
//   acks/<seq>.json     incoming ACKs (seq 0 answers the pairing request)
//   state.json          seq, lastHash, kid, paired
//   clock.json          recorder-clock offset
import { DayBuilder } from './DayBuilder';
import { demoFeedAt, demoFeedSteps, feedClockLabel } from './DemoFeed';
import { AckPacketCodec, DayPacketCodec, PAIR_ACK_SEQ } from './DayPacketCodec';
import { DayTransport } from './DayTransport';
import { MSG_UNKNOWN_KEY } from './DayPacketVerifier';
import { parseJsonObject, readNumber } from './JsonRead';
import { chainStateFromJson, chainStateToJson, newChainState, PacketSealer, WatchChainState } from './PacketSealer';
import { DEMO_SPEED, RecorderClock } from './RecorderClock';
import { SlotRecorder } from './SlotRecorder';
import { Clock, Hasher, Signer, TextStore } from './WatchLinkPorts';
import { daySigningString } from './WatchLinkSigning';
import {
  dateOfDayNumber,
  dayNumberOfDate,
  DayRecord,
  isValidHeartRate,
  localDayNumber,
  localSlotIndex,
  SlotState,
  SLOT_MINUTES,
  SLOT_MS,
  slotStartMs,
  SLOTS_PER_DAY,
  WearSource
} from './WatchLinkTypes';
import { FRESHNESS_DEMO_CLOCK_MS, FRESHNESS_REAL_CLOCK_MS, WearStateMachine } from './WearStateMachine';

export const OUTBOX_DIR: string = 'outbox';
export const ACKS_DIR: string = 'acks';
export const DAYS_DIR: string = 'days';
export const PAIR_FILE: string = 'pair.json';
export const STATE_FILE: string = 'state.json';
export const CLOCK_FILE: string = 'clock.json';
export const OUTBOX_CAP: number = 30;

export const STATUS_NOT_PAIRED: string = 'Not paired';
export const STATUS_SYNCED: string = 'Synced ✓';

const JSON_SUFFIX: string = '.json';

class ClockFile {
  offsetMs: number = 0;
}

// What the watch screens show.
export class WatchLinkView {
  slots: string = 'U'.repeat(SLOTS_PER_DAY);
  openSlot: number = -1;
  state: SlotState = 'U';             // U until a sensor has reported
  wearSource: WearSource = 'HR_SIGNAL';
  demoClock: boolean = false;
  clockLabel: string = '';
  recorderDate: string = '';
  recorderMinute: number = 0;         // minute of the recorder day, 0..1439
  kid: string = '';
  paired: boolean = false;
  pending: number = 0;
  statusLine: string = STATUS_NOT_PAIRED;
  lastAck: string = '';
  demoFeed: boolean = false;          // scripted readings stand in for the sensors
  feedHr: number = 0;                 // the scripted heart rate now; 0 = no reading
  stepsToday: number = 0;             // steps recorded in the open recorder day
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

export function syncStatusLine(paired: boolean, pending: number): string {
  if (!paired) {
    return STATUS_NOT_PAIRED;
  }
  return pending > 0 ? `${pending} to sync` : STATUS_SYNCED;
}

export class WatchLinkEngine {
  private store: TextStore;
  private signer: Signer;
  private hasher: Hasher;
  private realClock: Clock;
  private tzOffsetMin: number;
  private machine: WearStateMachine = new WearStateMachine(FRESHNESS_REAL_CLOCK_MS);
  private recorder: SlotRecorder;
  private recClock: RecorderClock = new RecorderClock(0);
  private chain: WatchChainState;
  private transports: DayTransport[] = [];
  private pendingHr: number | null = null;
  private packing: boolean = false;
  private started: boolean = false;
  private lastAck: string = '';
  private lastState: SlotState = 'U';
  private feedOn: boolean = false;
  private feedHr: number = 0;
  private feedLastRecorderMs: number = -1;

  constructor(store: TextStore, signer: Signer, hasher: Hasher, realClock: Clock, tzOffsetMin: number) {
    this.store = store;
    this.signer = signer;
    this.hasher = hasher;
    this.realClock = realClock;
    this.tzOffsetMin = tzOffsetMin;
    this.recorder = new SlotRecorder(store, tzOffsetMin);
    this.chain = newChainState(signer.kid());
  }

  setTransports(transports: DayTransport[]): void {
    this.transports = transports;
  }

  // Restores the chain state and the clock offset. Call once before the first tick.
  async start(): Promise<void> {
    if (this.started) {
      return;
    }
    this.started = true;
    this.chain = chainStateFromJson(this.store.read(STATE_FILE), this.signer.kid());
    const now = this.realClock.nowMs();
    this.recClock = new RecorderClock(this.readClockOffset());
    this.recorder.setClock(1, this.recClock.label(now));
    await this.adoptOutbox();
    this.processAcks();
  }

  // While the demo feed runs, the script stands in for the sensors: sensor events are not mixed in.
  onHr(bpm: number): void {
    if (this.feedOn) {
      return;
    }
    this.machine.onHr(this.realClock.nowMs(), bpm);
    if (isValidHeartRate(bpm)) {
      this.pendingHr = bpm;
    }
  }

  onWear(value: number): void {
    if (this.feedOn) {
      return;
    }
    this.machine.onWear(this.realClock.nowMs(), value);
  }

  onCharging(isCharging: boolean): void {
    if (this.feedOn) {
      return;
    }
    this.machine.onCharging(this.realClock.nowMs(), isCharging);
  }

  // About once per real second while the app is observing.
  async tick(stepsDelta: number): Promise<void> {
    const realMs = this.realClock.nowMs();
    const steps = this.feedOn ? this.applyFeed(realMs) : stepsDelta;
    const state: SlotState = this.machine.hasSignal() ? this.machine.state(realMs) : 'U';
    this.lastState = state;
    this.recorder.setWearSource(this.machine.source());
    this.recorder.tick(realMs, this.recClock.now(realMs), state, this.pendingHr, steps);
    this.pendingHr = null;
    if (this.recClock.isDemoSpeed()) {
      this.saveClock(realMs);
    }
    await this.packFinishedDays();
    this.processAcks();
  }

  // Observation stops (app to background). The time until the next tick stays not observed.
  pause(): void {
    this.recorder.pause();
    this.saveClock(this.realClock.nowMs());
  }

  isDemoClock(): boolean {
    return this.recClock.isDemoSpeed();
  }

  setDemoClock(on: boolean): void {
    if (!on) {
      // The feed exists only on the demo clock.
      this.setDemoFeed(false);
    }
    const realMs = this.realClock.nowMs();
    this.recClock.setSpeed(realMs, on ? DEMO_SPEED : 1);
    this.machine.setFreshnessMs(on ? FRESHNESS_DEMO_CLOCK_MS : FRESHNESS_REAL_CLOCK_MS);
    this.recorder.setClock(this.recClock.speedNow(), this.clockLabelNow(realMs));
    this.saveClock(realMs);
  }

  isDemoFeed(): boolean {
    return this.feedOn;
  }

  // "Demo feed": scripted heart rate, steps and charging instead of the sensors. It can only be on while
  // the demo clock runs. Returns whether the feed is on after the call.
  setDemoFeed(on: boolean): boolean {
    const want = on && this.recClock.isDemoSpeed();
    if (want === this.feedOn) {
      return this.feedOn;
    }
    const realMs = this.realClock.nowMs();
    this.feedOn = want;
    this.feedHr = 0;
    this.feedLastRecorderMs = -1;
    this.pendingHr = null;
    // A fresh wear state on both edges, so scripted and sensor readings are never judged together.
    this.machine = new WearStateMachine(this.recClock.isDemoSpeed() ? FRESHNESS_DEMO_CLOCK_MS :
      FRESHNESS_REAL_CLOCK_MS);
    this.recorder.setClock(this.recClock.speedNow(), this.clockLabelNow(realMs));
    return this.feedOn;
  }

  // "Close day (demo)": finishes the recorder day now (the slots not reached stay U), moves the
  // recorder clock to the next local midnight and puts the signed packet in the outbox.
  // Returns the packet's seq, or 0 when nothing had been recorded.
  async closeDayNow(): Promise<number> {
    const realMs = this.realClock.nowMs();
    const day = this.recorder.closeDayNow();
    if (day === null) {
      return 0;
    }
    const nextMidnight = slotStartMs(dayNumberOfDate(day.date) + 1, 0, this.tzOffsetMin);
    this.recClock.jumpTo(realMs, nextMidnight);
    this.feedLastRecorderMs = -1;
    this.recorder.setClock(this.recClock.speedNow(), this.clockLabelNow(realMs));
    this.saveClock(realMs);
    await this.packFinishedDays();
    return this.chain.seq;
  }

  // "Pair phone": writes the self-signed pairing request and returns the 8-hex code to show.
  async pair(): Promise<string> {
    const json = await PacketSealer.makePair(this.signer, this.realClock);
    this.store.writeAtomic(PAIR_FILE, json);
    this.sendOut(json);
    return this.signer.kid();
  }

  // "Reset watch data": slot files, outbox, ACKs, chain state and clock offset. The key stays.
  // The phone has to forget the watch and pair again: the chain starts over at seq 1.
  reset(): void {
    this.removeAll(DAYS_DIR);
    this.removeAll(OUTBOX_DIR);
    this.removeAll(ACKS_DIR);
    this.store.remove(PAIR_FILE);
    this.store.remove(STATE_FILE);
    this.store.remove(CLOCK_FILE);
    const realMs = this.realClock.nowMs();
    this.chain = newChainState(this.signer.kid());
    this.recClock = new RecorderClock(0);
    this.feedOn = false;
    this.feedHr = 0;
    this.feedLastRecorderMs = -1;
    this.machine = new WearStateMachine(FRESHNESS_REAL_CLOCK_MS);
    this.recorder = new SlotRecorder(this.store, this.tzOffsetMin);
    this.recorder.setClock(1, this.recClock.label(realMs));
    this.lastAck = '';
  }

  // Reads incoming ACKs. ACCEPTED or DUPLICATE: the packet is delivered and leaves the outbox.
  // REJECTED: the packet stays (the copy the phone saw may have been damaged on the way).
  processAcks(): void {
    const names = this.store.list(ACKS_DIR);
    let changed = false;
    for (let i = 0; i < names.length; i++) {
      const path = `${ACKS_DIR}/${names[i]}`;
      const text = this.store.read(path);
      this.store.remove(path);
      if (text === null) {
        continue;
      }
      const ack = AckPacketCodec.fromJson(text).packet;
      if (ack === null) {
        continue;
      }
      if (ack.status === 'REJECTED') {
        this.lastAck = ack.seq === PAIR_ACK_SEQ ? `Pairing: ${ack.reason}` : `#${ack.seq}: ${ack.reason}`;
        if (ack.reason === MSG_UNKNOWN_KEY && this.chain.paired) {
          this.chain.paired = false;
          changed = true;
        }
        continue;
      }
      if (ack.seq !== PAIR_ACK_SEQ) {
        this.store.remove(`${OUTBOX_DIR}/${ack.seq}${JSON_SUFFIX}`);
        this.lastAck = `#${ack.seq}: ${ack.reason}`;
      }
      if (!this.chain.paired) {
        this.chain.paired = true;
        changed = true;
      }
    }
    if (changed) {
      this.saveState();
    }
  }

  pendingCount(): number {
    let count = 0;
    const names = this.store.list(OUTBOX_DIR);
    for (let i = 0; i < names.length; i++) {
      if (seqOfName(names[i]) > 0) {
        count++;
      }
    }
    return count;
  }

  view(): WatchLinkView {
    const realMs = this.realClock.nowMs();
    const out = new WatchLinkView();
    out.slots = this.recorder.slotString();
    out.openSlot = this.recorder.openSlotIndex();
    out.state = this.lastState;
    out.wearSource = this.machine.source();
    out.demoClock = this.recClock.isDemoSpeed();
    out.clockLabel = this.clockLabelNow(realMs);
    const recorderMs = this.recClock.now(realMs);
    out.recorderDate = dateOfDayNumber(localDayNumber(recorderMs, this.tzOffsetMin));
    out.recorderMinute = this.minuteOfDay(recorderMs);
    out.demoFeed = this.feedOn;
    out.feedHr = this.feedHr;
    const today = this.recorder.currentDay();
    if (today !== null) {
      let steps = 0;
      for (let i = 0; i < today.slots.length; i++) {
        steps += today.slots[i].steps;
      }
      out.stepsToday = steps;
    }
    out.kid = this.signer.kid();
    out.paired = this.chain.paired;
    out.pending = this.pendingCount();
    out.statusLine = syncStatusLine(out.paired, out.pending);
    out.lastAck = this.lastAck;
    return out;
  }

  // Minute of the recorder's local day, 0..1439.
  private minuteOfDay(recorderMs: number): number {
    return localSlotIndex(recorderMs, this.tzOffsetMin) * SLOT_MINUTES + Math.floor((recorderMs % SLOT_MS) / 60000);
  }

  // The label that goes into the day packet: the clock's own label, marked when scripted readings are fed.
  private clockLabelNow(realMs: number): string {
    const label = this.recClock.label(realMs);
    return this.feedOn ? feedClockLabel(label) : label;
  }

  // Feeds this second's scripted readings into the same wear state machine the sensors feed.
  // Returns the scripted steps for the recorder time since the last tick.
  private applyFeed(realMs: number): number {
    const recorderMs = this.recClock.now(realMs);
    const minute = this.minuteOfDay(recorderMs);
    const sample = demoFeedAt(minute);
    this.machine.onCharging(realMs, sample.charging);
    this.machine.onHr(realMs, sample.hr);
    this.feedHr = sample.hr;
    if (isValidHeartRate(sample.hr)) {
      this.pendingHr = sample.hr;
    }
    const elapsedMin = this.feedLastRecorderMs < 0 ? 0 : (recorderMs - this.feedLastRecorderMs) / 60000;
    this.feedLastRecorderMs = recorderMs;
    return demoFeedSteps(minute, elapsedMin);
  }

  // Builds, signs and stores the packet of every finished day. One at a time: signing is asynchronous
  // and two packets must never get the same seq.
  private async packFinishedDays(): Promise<void> {
    if (this.packing) {
      return;
    }
    this.packing = true;
    try {
      const days: DayRecord[] = this.recorder.takeFinishedDays();
      for (let i = 0; i < days.length; i++) {
        const day = days[i];
        const yesterday = this.recorder.loadDay(dateOfDayNumber(dayNumberOfDate(day.date) - 1));
        const sealed = await PacketSealer.sealDay(DayBuilder.build(day, yesterday), this.chain, this.signer,
          this.hasher, this.realClock);
        this.store.writeAtomic(`${OUTBOX_DIR}/${sealed.packet.seq}${JSON_SUFFIX}`, sealed.json);
        this.chain.seq = sealed.packet.seq;
        this.chain.lastHash = sealed.hash;
        this.saveState();
        this.recorder.markPacked(day.date);
        this.capOutbox();
        this.sendOut(sealed.json);
      }
    } finally {
      this.packing = false;
    }
  }

  // After a crash between "packet written" and "state saved": continue the chain from the newest
  // packet in the outbox instead of signing a second packet under its seq.
  private async adoptOutbox(): Promise<void> {
    let newest = this.chain.seq;
    const names = this.store.list(OUTBOX_DIR);
    for (let i = 0; i < names.length; i++) {
      const seq = seqOfName(names[i]);
      if (seq > newest) {
        newest = seq;
      }
    }
    if (newest === this.chain.seq) {
      return;
    }
    const text = this.store.read(`${OUTBOX_DIR}/${newest}${JSON_SUFFIX}`);
    const packet = text === null ? null : DayPacketCodec.fromJson(text).packet;
    if (packet === null || packet.kid !== this.chain.kid || packet.seq !== newest) {
      return;
    }
    this.chain.seq = newest;
    this.chain.lastHash = await this.hasher.sha256B64url(daySigningString(packet));
    this.saveState();
    this.recorder.markPacked(packet.date);
  }

  private capOutbox(): void {
    const seqs: number[] = [];
    const names = this.store.list(OUTBOX_DIR);
    for (let i = 0; i < names.length; i++) {
      const seq = seqOfName(names[i]);
      if (seq > 0) {
        seqs.push(seq);
      }
    }
    seqs.sort((a: number, b: number) => a - b);
    while (seqs.length > OUTBOX_CAP) {
      const oldest = seqs.shift();
      if (oldest !== undefined) {
        this.store.remove(`${OUTBOX_DIR}/${oldest}${JSON_SUFFIX}`);
      }
    }
  }

  // The outbox file is the delivery guarantee. A direct transport is tried on top and may fail.
  private sendOut(json: string): void {
    for (let i = 0; i < this.transports.length; i++) {
      const transport = this.transports[i];
      transport.isAvailable().then((available: boolean) => {
        if (available) {
          transport.send(json).catch(() => {
          });
        }
      }).catch(() => {
      });
    }
  }

  private removeAll(dir: string): void {
    const names = this.store.list(dir);
    for (let i = 0; i < names.length; i++) {
      this.store.remove(`${dir}/${names[i]}`);
    }
  }

  private saveState(): void {
    this.store.writeAtomic(STATE_FILE, chainStateToJson(this.chain));
  }

  private saveClock(realMs: number): void {
    const file = new ClockFile();
    file.offsetMs = Math.round(this.recClock.offsetAt(realMs));
    this.store.writeAtomic(CLOCK_FILE, JSON.stringify(file));
  }

  private readClockOffset(): number {
    const text = this.store.read(CLOCK_FILE);
    if (text === null) {
      return 0;
    }
    const o = parseJsonObject(text);
    if (o === null) {
      return 0;
    }
    const offset = readNumber(o, 'offsetMs');
    return offset === null || offset < 0 ? 0 : offset;
  }
}
