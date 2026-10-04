// Watch Link security checks under Node: signed ACKs, one packet per day, the cap on a sequence jump, the
// demo-clock default, and the order in which the phone stores an accepted day.
// Not part of List.test.ets (the ports come from tools/logic-tests/node-ports.ts).
import { describe, it, expect } from '@ohos/hypium';
import {
  FsTextStore,
  makeTempDir,
  NodeHasher,
  NodeSigner,
  NodeSigVerifier,
  removeDir
} from '@fairwear/node-ports';
import { ChainLedger, MAX_GAP } from '../main/ets/watchlink/ChainLedger';
import { DayBuilder } from '../main/ets/watchlink/DayBuilder';
import { AckPacketCodec, DayPacketCodec, PAIR_ACK_SEQ, PairPacketCodec } from '../main/ets/watchlink/DayPacketCodec';
import {
  DayPacketVerifier,
  MSG_ACCEPTED,
  MSG_DATE_ORDER,
  MSG_DEMO_CLOCK,
  MSG_SEQ_JUMP
} from '../main/ets/watchlink/DayPacketVerifier';
import { newChainState, PacketSealer, SealedDay, WatchChainState } from '../main/ets/watchlink/PacketSealer';
import { PhoneLinkEngine } from '../main/ets/watchlink/PhoneLinkEngine';
import {
  ACK_BAD_SIGNATURE,
  ACK_OTHER_PHONE,
  STATUS_NOT_PAIRED,
  STATUS_SYNCED,
  WatchLinkEngine
} from '../main/ets/watchlink/WatchLinkEngine';
import { Clock, TextStore } from '../main/ets/watchlink/WatchLinkPorts';
import { daySigningString, pairSigningString } from '../main/ets/watchlink/WatchLinkSigning';
import { dayNumberOfDate, DayRecord, emptyDay, slotStartMs } from '../main/ets/watchlink/WatchLinkTypes';

const TZ = 120;
const D1 = '2026-10-01';
const D2 = '2026-10-02';
const D4 = '2026-10-04';

class StepClock implements Clock {
  ms: number;

  constructor(ms: number) {
    this.ms = ms;
  }

  nowMs(): number {
    return this.ms;
  }
}

// A store whose writes under one directory fail once `failing` is set: a full disk, a killed write.
class FlakyStore implements TextStore {
  inner: FsTextStore;
  failing: boolean = false;
  prefix: string;

  constructor(inner: FsTextStore, prefix: string) {
    this.inner = inner;
    this.prefix = prefix;
  }

  read(path: string): string | null {
    return this.inner.read(path);
  }

  writeAtomic(path: string, text: string): void {
    if (this.failing && path.startsWith(this.prefix)) {
      throw new Error('write failed');
    }
    this.inner.writeAtomic(path, text);
  }

  list(dir: string): string[] {
    return this.inner.list(dir);
  }

  remove(path: string): void {
    this.inner.remove(path);
  }
}

function wornDay(date: string): DayRecord {
  const day = emptyDay(date, TZ);
  for (let i = 0; i < day.slots.length; i++) {
    const slot = day.slots[i];
    slot.observedSec = 300;
    slot.wornSec = 300;
    slot.hrSampleCount = 5;
    slot.hrSum = 62 * 5;
  }
  day.closedCount = day.slots.length;
  day.sealed = true;
  return day;
}

class Rig {
  signer: NodeSigner = new NodeSigner();
  verifier: NodeSigVerifier = new NodeSigVerifier();
  hasher: NodeHasher = new NodeHasher();
  clock: StepClock = new StepClock(slotStartMs(dayNumberOfDate(D4), 0, TZ) + 12 * 3600 * 1000);
  state: WatchChainState;
  ledger: ChainLedger;

  constructor() {
    this.state = newChainState(this.signer.kid());
    this.ledger = new ChainLedger(this.signer.kid(), this.signer.publicKeySpkiB64());
  }

  async next(date: string): Promise<SealedDay> {
    const sealed = await PacketSealer.sealDay(DayBuilder.build(wornDay(date), null), this.state, this.signer,
      this.hasher, this.clock);
    this.state.seq = sealed.packet.seq;
    this.state.lastHash = sealed.hash;
    return sealed;
  }
}

class Bench {
  watchDir: string = makeTempDir();
  phoneDir: string = makeTempDir();
  watchStore: FsTextStore;
  phoneFs: FsTextStore;
  phoneStore: FlakyStore;
  clock: StepClock = new StepClock(slotStartMs(dayNumberOfDate(D4), 0, TZ) + 12 * 3600 * 1000);
  signer: NodeSigner = new NodeSigner();
  phoneSigner: NodeSigner = new NodeSigner();
  watch: WatchLinkEngine;
  phone: PhoneLinkEngine;

  constructor() {
    this.watchStore = new FsTextStore(this.watchDir);
    this.phoneFs = new FsTextStore(this.phoneDir);
    this.phoneStore = new FlakyStore(this.phoneFs, 'watchlink/days');
    this.watch = new WatchLinkEngine(this.watchStore, this.signer, new NodeHasher(), this.clock, TZ,
      new NodeSigVerifier());
    this.phone = new PhoneLinkEngine(this.phoneStore, new NodeSigVerifier(), new NodeHasher(), this.clock,
      this.phoneSigner, true);
    this.phone.load();
  }

  async run(seconds: number, bpm: number): Promise<void> {
    for (let i = 0; i < seconds; i++) {
      this.clock.ms += 1000;
      if (bpm > 0) {
        this.watch.onHr(bpm);
      }
      await this.watch.tick(0);
    }
  }

  // The relay: watch pair.json + outbox -> phone inbox, the phone answers, phone acks -> watch acks.
  async relay(): Promise<void> {
    const pair = this.watchStore.read('pair.json');
    if (pair !== null) {
      this.phoneStore.writeAtomic('inbox/pair.json', pair);
    }
    const names = this.watchStore.list('outbox');
    for (let i = 0; i < names.length; i++) {
      const text = this.watchStore.read(`outbox/${names[i]}`);
      if (text !== null) {
        this.phoneStore.writeAtomic(`inbox/${names[i]}`, text);
      }
    }
    await this.phone.scanInbox();
    this.deliverAcks();
    await this.watch.processAcks();
  }

  deliverAcks(): void {
    const acks = this.phoneStore.list('acks');
    for (let i = 0; i < acks.length; i++) {
      const text = this.phoneStore.read(`acks/${acks[i]}`);
      if (text !== null) {
        this.watchStore.writeAtomic(`acks/${acks[i]}`, text);
      }
    }
  }

  async paired(): Promise<void> {
    await this.watch.start();
    await this.watch.pair();
    await this.relay();
    await this.phone.confirmPair();
    await this.relay();
  }

  // One recorded demo day, closed and in the outbox. Returns its seq.
  async oneDay(): Promise<number> {
    this.watch.setDemoClock(true);
    await this.run(12, 70);
    return this.watch.closeDayNow();
  }

  dispose(): void {
    removeDir(this.watchDir);
    removeDir(this.phoneDir);
  }
}

// An ACK for `seq` signed by `signer`, as an attacker on the transport would write it.
async function forgedAck(signer: NodeSigner, seq: number, watchKid: string, ref: string): Promise<string> {
  const ack = await PacketSealer.sealAck(AckPacketCodec.make(seq, 'ACCEPTED', MSG_ACCEPTED, watchKid, ref, '', '',
    1700000000), signer);
  return AckPacketCodec.toJson(ack);
}

export default function watchLinkSecurityTest() {
  describe('WatchLink security: ACKs are signed by the phone', () => {
    it('pairing pins the phone key on the watch; the phone kid is shown', 0, async () => {
      const b = new Bench();
      await b.paired();
      expect(b.watch.view().paired).assertTrue();
      expect(b.watch.view().lastAck.indexOf(b.phoneSigner.kid()) >= 0).assertTrue();
      expect(b.phone.phoneKid()).assertEqual(b.phoneSigner.kid());
      const ack = AckPacketCodec.fromJson(b.phoneStore.read('acks/0.json') as string).packet;
      expect(ack !== null && ack.phoneKid === b.phoneSigner.kid() && ack.watchKid === b.signer.kid()).assertTrue();
      b.dispose();
    });

    it('an ACK signed by another key does not take a day out of the outbox', 0, async () => {
      const b = new Bench();
      await b.paired();
      expect(await b.oneDay()).assertEqual(1);
      const packet = DayPacketCodec.fromJson(b.watchStore.read('outbox/1.json') as string).packet;
      expect(packet !== null).assertTrue();
      if (packet !== null) {
        const ref = await new NodeHasher().sha256B64url(daySigningString(packet));
        b.watchStore.writeAtomic('acks/1.json', await forgedAck(new NodeSigner(), 1, b.signer.kid(), ref));
        await b.watch.processAcks();
        expect(b.watch.pendingCount()).assertEqual(1);
        expect(b.watch.view().lastAck).assertEqual(ACK_OTHER_PHONE);
      }
      // The real answer still delivers it.
      await b.relay();
      expect(b.watch.pendingCount()).assertEqual(0);
      expect(b.watch.view().statusLine).assertEqual(STATUS_SYNCED);
      b.dispose();
    });

    it('a pinned phone key with a broken signature is ignored', 0, async () => {
      const b = new Bench();
      await b.paired();
      await b.oneDay();
      const packet = b.watchStore.read('outbox/1.json') as string;
      b.phoneStore.writeAtomic('inbox/1.json', packet);
      await b.phone.scanInbox();
      const real = b.phoneStore.read('acks/1.json') as string;
      // Same key, same packet, the status text changed after signing.
      b.watchStore.writeAtomic('acks/1.json', real.replace('"Accepted"', '"Accepted again"'));
      await b.watch.processAcks();
      expect(b.watch.pendingCount()).assertEqual(1);
      expect(b.watch.view().lastAck).assertEqual(ACK_BAD_SIGNATURE);
      b.watchStore.writeAtomic('acks/1.json', real);
      await b.watch.processAcks();
      expect(b.watch.pendingCount()).assertEqual(0);
      b.dispose();
    });

    it('an unsigned ACK of the old format changes nothing', 0, async () => {
      const b = new Bench();
      await b.paired();
      await b.oneDay();
      b.watchStore.writeAtomic('acks/1.json', '{"v":1,"type":"ACK","seq":1,"status":"ACCEPTED","reason":"Accepted"}');
      await b.watch.processAcks();
      expect(b.watch.pendingCount()).assertEqual(1);
      // A forged "Unknown watch key" cannot unpair either.
      b.watchStore.writeAtomic('acks/1.json',
        '{"v":1,"type":"ACK","seq":1,"status":"REJECTED","reason":"Unknown watch key"}');
      await b.watch.processAcks();
      expect(b.watch.view().paired).assertTrue();
      b.dispose();
    });

    it('a genuine answer about another packet with the same seq does not deliver this one', 0, async () => {
      const b = new Bench();
      await b.paired();
      await b.oneDay();
      b.phoneStore.writeAtomic('inbox/1.json', b.watchStore.read('outbox/1.json') as string);
      await b.phone.scanInbox();
      const answer = b.phoneStore.read('acks/1.json') as string;
      // The watch is reset and pairs again: a new day 1 waits, and the old answer is played back.
      b.watch.reset();
      b.phone.forget();
      await b.paired();
      await b.oneDay();
      b.watchStore.writeAtomic('acks/1.json', answer);
      await b.watch.processAcks();
      expect(b.watch.pendingCount()).assertEqual(1);
      b.dispose();
    });

    it('a copy of the pairing answer cannot pin another phone once the request was answered', 0, async () => {
      const b = new Bench();
      await b.paired();
      const pairText = b.watchStore.read('pair.json') as string;
      const request = PairPacketCodec.fromJson(pairText).packet;
      expect(request !== null).assertTrue();
      if (request !== null) {
        const ref = await new NodeHasher().sha256B64url(pairSigningString(request));
        const intruder = new NodeSigner();
        b.watchStore.writeAtomic('acks/0.json', await forgedAck(intruder, PAIR_ACK_SEQ, b.signer.kid(), ref));
        await b.watch.processAcks();
      }
      // Still the real phone: its answers deliver days.
      await b.oneDay();
      await b.relay();
      expect(b.watch.pendingCount()).assertEqual(0);
      b.dispose();
    });

    it('"Unknown watch key" from the pinned phone unpairs the watch', 0, async () => {
      const b = new Bench();
      await b.paired();
      await b.oneDay();
      b.phone.forget();
      await b.relay();
      expect(b.watch.view().paired).assertFalse();
      expect(b.watch.view().statusLine).assertEqual(STATUS_NOT_PAIRED);
      expect(b.watch.pendingCount()).assertEqual(1);
      b.dispose();
    });
  });

  describe('WatchLink security: the phone stores a day before the chain counts it', () => {
    it('a failed day write leaves the chain unchanged and the watch sends the day again', 0, async () => {
      const b = new Bench();
      await b.paired();
      await b.oneDay();
      b.phoneStore.failing = true;
      let threw = false;
      try {
        await b.relay();
      } catch (e) {
        threw = true;
      }
      expect(threw).assertTrue();
      expect(b.phone.view().lastSeq).assertEqual(0);
      expect(b.phoneStore.read('acks/1.json') === null).assertTrue();
      expect(b.watch.pendingCount()).assertEqual(1);
      b.phoneStore.failing = false;
      await b.relay();
      expect(b.phone.view().lastSeq).assertEqual(1);
      expect(b.phone.timeline().length).assertEqual(1);
      expect(b.phone.timeline()[0].received).assertTrue();
      expect(b.watch.pendingCount()).assertEqual(0);
      b.dispose();
    });
  });

  describe('WatchLink security: verifier limits', () => {
    it('two packets for the same date: the second is out of order', 0, async () => {
      const rig = new Rig();
      const check = new DayPacketVerifier(rig.verifier, rig.hasher, rig.clock);
      const first = await rig.next(D1);
      const again = await rig.next(D1);
      expect((await check.verify(first.json, rig.ledger)).message).assertEqual(MSG_ACCEPTED);
      expect((await check.verify(again.json, rig.ledger)).message).assertEqual(MSG_DATE_ORDER);
      expect(rig.ledger.lastSeq).assertEqual(1);
      // A late day must lie strictly between its neighbours.
      const r2 = new Rig();
      const c2 = new DayPacketVerifier(r2.verifier, r2.hasher, r2.clock);
      const a = await r2.next(D1);
      const held = await r2.next(D2);
      const c = await r2.next(D4);
      expect((await c2.verify(a.json, r2.ledger)).message).assertEqual(MSG_ACCEPTED);
      expect((await c2.verify(c.json, r2.ledger)).message).assertEqual(MSG_ACCEPTED);
      expect((await c2.verify(held.json, r2.ledger)).message).assertEqual(MSG_ACCEPTED);
    });

    it(`a sequence jump over ${MAX_GAP} is refused before any missing list is built`, 0, async () => {
      const rig = new Rig();
      const check = new DayPacketVerifier(rig.verifier, rig.hasher, rig.clock);
      rig.state.seq = MAX_GAP + 1;
      const far = await rig.next(D1);
      const out = await check.verify(far.json, rig.ledger);
      expect(out.message).assertEqual(MSG_SEQ_JUMP);
      expect(out.status).assertEqual('REJECTED');
      expect(rig.ledger.lastSeq).assertEqual(0);
      expect(rig.ledger.missingSeqs.length).assertEqual(0);
      // Exactly MAX_GAP skipped days is still a gap.
      const r2 = new Rig();
      const c2 = new DayPacketVerifier(r2.verifier, r2.hasher, r2.clock);
      r2.state.seq = MAX_GAP;
      const edge = await r2.next(D1);
      expect((await c2.verify(edge.json, r2.ledger)).message).assertEqual(MSG_ACCEPTED);
      expect(r2.ledger.missingSeqs.length).assertEqual(MAX_GAP);
      // The worst jump the codec allows never builds a list.
      const r3 = new Rig();
      r3.state.seq = 2147483646;
      const huge = await r3.next(D1);
      expect((await new DayPacketVerifier(r3.verifier, r3.hasher, r3.clock).verify(huge.json, r3.ledger)).message)
        .assertEqual(MSG_SEQ_JUMP);
    });

    it('by default demo-clock packets are refused; only the demo build takes them', 0, async () => {
      const rig = new Rig();
      const day = wornDay(D1);
      day.clock = 'DEMO_X300';
      const sealed = await PacketSealer.sealDay(DayBuilder.build(day, null), rig.state, rig.signer, rig.hasher,
        rig.clock);
      const byDefault = new DayPacketVerifier(rig.verifier, rig.hasher, rig.clock);
      expect((await byDefault.verify(sealed.json, rig.ledger)).message).assertEqual(MSG_DEMO_CLOCK);
      const demoBuild = new DayPacketVerifier(rig.verifier, rig.hasher, rig.clock, true);
      expect((await demoBuild.verify(sealed.json, rig.ledger)).message).assertEqual(MSG_ACCEPTED);
    });
  });
}
