// The Watch Link tour's checks under Node: the real verifier against a copy of the chain.
// Not part of List.test.ets (the ports come from tools/logic-tests/node-ports.ts).
import { describe, it, expect } from '@ohos/hypium';
import {
  FsTextStore,
  makeTempDir,
  NodeHasher,
  NodeSigner,
  NodeSigVerifier,
  removeDir,
  utf8ByteLength
} from '@fairwear/node-ports';
import { MSG_ACCEPTED, MSG_DUPLICATE, MSG_INVALID_SIGNATURE } from '../main/ets/watchlink/DayPacketVerifier';
import {
  NOTE_COUNTED_ONCE,
  NOTE_FILLS_GAP,
  NOTE_NOT_TAKEN,
  PROBE_NEEDS_DAY,
  PROBE_NEEDS_TWO
} from '../main/ets/watchlink/LinkProbe';
import { PhoneLinkEngine } from '../main/ets/watchlink/PhoneLinkEngine';
import { WatchLinkEngine } from '../main/ets/watchlink/WatchLinkEngine';
import { Clock } from '../main/ets/watchlink/WatchLinkPorts';
import { dayNumberOfDate, slotStartMs } from '../main/ets/watchlink/WatchLinkTypes';

const TZ = 120;
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

class ProbeBench {
  watchDir: string = makeTempDir();
  phoneDir: string = makeTempDir();
  watchStore: FsTextStore;
  phoneStore: FsTextStore;
  clock: StepClock = new StepClock(slotStartMs(dayNumberOfDate(D4), 0, TZ) + 12 * 3600 * 1000);
  signer: NodeSigner = new NodeSigner();
  watch: WatchLinkEngine;
  phone: PhoneLinkEngine;

  constructor() {
    this.watchStore = new FsTextStore(this.watchDir);
    this.phoneStore = new FsTextStore(this.phoneDir);
    this.watch = new WatchLinkEngine(this.watchStore, this.signer, new NodeHasher(), this.clock, TZ);
    this.phone = new PhoneLinkEngine(this.phoneStore, new NodeSigVerifier(), new NodeHasher(), this.clock);
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

  // What tools/watch-phone-relay.mjs does over hdc; `drop` holds one packet back.
  async relay(drop: number = 0): Promise<void> {
    const pair = this.watchStore.read('pair.json');
    if (pair !== null) {
      this.phoneStore.writeAtomic('inbox/pair.json', pair);
    }
    const names = this.watchStore.list('outbox');
    for (let i = 0; i < names.length; i++) {
      if (drop > 0 && names[i] === `${drop}.json`) {
        continue;
      }
      const text = this.watchStore.read(`outbox/${names[i]}`);
      if (text !== null) {
        this.phoneStore.writeAtomic(`inbox/${names[i]}`, text);
      }
    }
    await this.phone.scanInbox();
    const acks = this.phoneStore.list('acks');
    for (let i = 0; i < acks.length; i++) {
      const text = this.phoneStore.read(`acks/${acks[i]}`);
      if (text !== null) {
        this.watchStore.writeAtomic(`acks/${acks[i]}`, text);
      }
    }
    this.watch.processAcks();
  }

  async pairAndStart(): Promise<void> {
    await this.watch.start();
    await this.watch.pair();
    await this.relay();
    this.phone.confirmPair();
    await this.relay();
    this.watch.setDemoClock(true);
  }

  async closeDay(): Promise<number> {
    await this.run(20, 70);
    return this.watch.closeDayNow();
  }

  // Everything the phone keeps on disk, to prove a check wrote nothing.
  snapshot(): string {
    const parts: string[] = [];
    const dirs = ['watchlink', 'watchlink/days', 'acks', 'inbox'];
    for (let d = 0; d < dirs.length; d++) {
      const names = this.phoneStore.list(dirs[d]);
      names.sort();
      for (let i = 0; i < names.length; i++) {
        const text = this.phoneStore.read(`${dirs[d]}/${names[i]}`);
        parts.push(`${dirs[d]}/${names[i]}=${text === null ? '' : text}`);
      }
    }
    return parts.join('\n');
  }

  dispose(): void {
    removeDir(this.watchDir);
    removeDir(this.phoneDir);
  }
}

export default function linkProbeTest() {
  describe('Watch Link tour checks', () => {
    it('without a received day every check says what it needs', 0, async () => {
      const b = new ProbeBench();
      const r = await b.phone.probe('TAMPER');
      expect(r.ran).assertFalse();
      expect(r.reason).assertEqual(PROBE_NEEDS_DAY);
      expect(b.phone.latestReceived() === null).assertTrue();
      b.dispose();
    });

    it('one changed character is refused by the signature and nothing is stored', 0, async () => {
      const b = new ProbeBench();
      await b.pairAndStart();
      expect(await b.closeDay()).assertEqual(1);
      await b.relay();
      const before = b.snapshot();
      const r = await b.phone.probe('TAMPER');
      expect(r.ran).assertTrue();
      expect(r.steps.length).assertEqual(1);
      expect(r.steps[0].status).assertEqual('REJECTED');
      expect(r.steps[0].message).assertEqual(MSG_INVALID_SIGNATURE);
      expect(r.steps[0].note).assertEqual(NOTE_NOT_TAKEN);
      expect(r.steps[0].action).assertEqual('CHANGED');
      expect(r.steps[0].date).assertEqual(D4);
      expect(r.steps[0].fromSlot === r.steps[0].toSlot).assertFalse();
      expect(r.storedUnchanged).assertTrue();
      expect(b.snapshot()).assertEqual(before);
      expect(b.phone.view().chainLine).assertEqual('Chain #1 ✓');
      b.dispose();
    });

    it('the same day again is a duplicate and counts once', 0, async () => {
      const b = new ProbeBench();
      await b.pairAndStart();
      await b.closeDay();
      await b.relay();
      const before = b.snapshot();
      const r = await b.phone.probe('REPLAY');
      expect(r.ran).assertTrue();
      expect(r.steps[0].status).assertEqual('DUPLICATE');
      expect(r.steps[0].message).assertEqual(MSG_DUPLICATE);
      expect(r.steps[0].note).assertEqual(NOTE_COUNTED_ONCE);
      expect(b.snapshot()).assertEqual(before);
      b.dispose();
    });

    it('holding a day back needs two received days in a row', 0, async () => {
      const b = new ProbeBench();
      await b.pairAndStart();
      await b.closeDay();
      await b.relay();
      const r = await b.phone.probe('LATE');
      expect(r.ran).assertFalse();
      expect(r.reason).assertEqual(PROBE_NEEDS_TWO);
      b.dispose();
    });

    it('a held-back day shows as missing, then fills the gap, on a copy of the chain', 0, async () => {
      const b = new ProbeBench();
      await b.pairAndStart();
      await b.closeDay();
      await b.closeDay();
      expect(await b.closeDay()).assertEqual(3);
      await b.relay();
      expect(b.phone.view().chainLine).assertEqual('Chain #3 ✓');
      const before = b.snapshot();
      const r = await b.phone.probe('LATE');
      expect(r.ran).assertTrue();
      expect(r.steps.length).assertEqual(2);
      expect(r.steps[0].status).assertEqual('ACCEPTED');
      expect(r.steps[0].message).assertEqual(MSG_ACCEPTED);
      expect(r.steps[0].note).assertEqual('Missing 1 day(s)');
      expect(r.steps[1].status).assertEqual('ACCEPTED');
      expect(r.steps[1].note).assertEqual(NOTE_FILLS_GAP);
      expect(r.steps[0].action).assertEqual('SENT_AHEAD');
      expect(r.steps[1].action).assertEqual('SENT_LATE');
      expect(r.steps[0].heldDate).assertEqual(r.steps[1].date);
      expect(r.storedUnchanged).assertTrue();
      expect(b.snapshot()).assertEqual(before);
      expect(b.phone.view().chainLine).assertEqual('Chain #3 ✓');
      b.dispose();
    });

    it('the newest received day is described from the stored packet', 0, async () => {
      const b = new ProbeBench();
      await b.pairAndStart();
      await b.closeDay();
      await b.closeDay();
      await b.relay();
      const info = b.phone.latestReceived();
      expect(info !== null).assertTrue();
      const stored = b.phoneStore.read('watchlink/days/2.json');
      if (info !== null && stored !== null) {
        expect(info.seq).assertEqual(2);
        expect(info.bytes).assertEqual(utf8ByteLength(stored));
        expect(info.bytes).assertLess(3800);
        expect(info.slots.length).assertEqual(288);
        expect(info.firstOfChain).assertFalse();
        expect(info.date.length).assertEqual(10);
      }
      b.dispose();
    });

    it('with a day really missing, the checks use the newest received day', 0, async () => {
      const b = new ProbeBench();
      await b.pairAndStart();
      await b.closeDay();
      await b.closeDay();
      await b.closeDay();
      await b.relay(2);
      expect(b.phone.view().chainLine).assertEqual('1 day missing');
      expect(b.phone.latestReceivedSeq()).assertEqual(3);
      const late = await b.phone.probe('LATE');
      expect(late.ran).assertFalse();
      expect(late.reason).assertEqual(PROBE_NEEDS_TWO);
      const tamper = await b.phone.probe('TAMPER');
      expect(tamper.steps[0].message).assertEqual(MSG_INVALID_SIGNATURE);
      expect(b.phone.view().chainLine).assertEqual('1 day missing');
      b.dispose();
    });
  });
}
