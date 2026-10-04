// Watch Link end to end under Node: the watch engine and the phone engine, each with its own
// directory, and a relay that carries the same files tools/watch-phone-relay.mjs carries over hdc.
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
import {
  MSG_ACCEPTED,
  MSG_DUPLICATE,
  MSG_INVALID_SIGNATURE,
  MSG_UNKNOWN_KEY
} from '../main/ets/watchlink/DayPacketVerifier';
import {
  missingDayReason,
  MSG_OTHER_WATCH,
  PhoneLinkEngine,
  sourceLine
} from '../main/ets/watchlink/PhoneLinkEngine';
import { RecorderClock } from '../main/ets/watchlink/RecorderClock';
import { STATUS_NOT_PAIRED, STATUS_SYNCED, WatchLinkEngine } from '../main/ets/watchlink/WatchLinkEngine';
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

class RelayOptions {
  tamper: boolean = false;
  drop: number = 0;
}

class Bench {
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

  // `seconds` real seconds of the watch app running; heart rate once a second when `bpm` > 0.
  async run(seconds: number, bpm: number): Promise<void> {
    for (let i = 0; i < seconds; i++) {
      this.clock.ms += 1000;
      if (bpm > 0) {
        this.watch.onHr(bpm);
      }
      await this.watch.tick(0);
    }
  }

  // What the hdc relay does: watch pair.json + outbox/* -> phone inbox/, the phone processes them,
  // phone acks/* -> watch acks/. The relay never deletes app data.
  async relay(options: RelayOptions = new RelayOptions()): Promise<void> {
    const pair = this.watchStore.read('pair.json');
    if (pair !== null) {
      this.phoneStore.writeAtomic('inbox/pair.json', pair);
    }
    const names = this.watchStore.list('outbox');
    for (let i = 0; i < names.length; i++) {
      if (options.drop > 0 && names[i] === `${options.drop}.json`) {
        continue;
      }
      let text = this.watchStore.read(`outbox/${names[i]}`);
      if (text === null) {
        continue;
      }
      if (options.tamper) {
        const at = text.indexOf('"slots":"') + 9;
        const flipped = text.charAt(at) === 'W' ? 'O' : 'W';
        text = text.substring(0, at) + flipped + text.substring(at + 1);
      }
      this.phoneStore.writeAtomic(`inbox/${names[i]}`, text);
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

  dispose(): void {
    removeDir(this.watchDir);
    removeDir(this.phoneDir);
  }
}

export default function watchLinkFlowTest() {
  describe('WatchLink RecorderClock', () => {
    it('real clock, demo speed, and the offset that stays', 0, () => {
      const c = new RecorderClock(0);
      expect(c.now(1000)).assertEqual(1000);
      expect(c.label(1000)).assertEqual('REAL');
      c.setSpeed(1000, 300);
      expect(c.label(1000)).assertEqual('DEMO_X300');
      expect(c.now(2000)).assertEqual(1000 + 300 * 1000);
      c.setSpeed(2000, 1);
      expect(c.now(2000)).assertEqual(301000);
      expect(c.now(3000)).assertEqual(302000);
      expect(c.label(3000)).assertEqual('DEMO_OFFSET');
      expect(c.offsetAt(3000)).assertEqual(299000);
      // Restored from the stored offset.
      const again = new RecorderClock(299000);
      expect(again.now(3000)).assertEqual(302000);
      // Jumps only forward.
      again.jumpTo(3000, 1000000);
      expect(again.now(3000)).assertEqual(1000000);
      again.jumpTo(3000, 5);
      expect(again.now(3000)).assertEqual(1000000);
    });
  });

  describe('WatchLink flow: watch -> relay -> phone', () => {
    it('pairing: the same code on both sides, pinned only after the user confirms', 0, async () => {
      const b = new Bench();
      await b.watch.start();
      expect(b.watch.view().statusLine).assertEqual(STATUS_NOT_PAIRED);
      const code = await b.watch.pair();
      expect(code).assertEqual(b.signer.kid());
      await b.relay();
      expect(b.phone.view().pendingPairKid).assertEqual(code);
      expect(b.phone.isPaired()).assertFalse();
      expect(b.watch.view().paired).assertFalse();
      expect(b.phone.confirmPair()).assertTrue();
      expect(b.phone.view().pairLine).assertEqual(`Paired · ${code}`);
      await b.relay();
      expect(b.watch.view().paired).assertTrue();
      expect(b.watch.view().statusLine).assertEqual(STATUS_SYNCED);
      // Pinned state survives a restart of the phone app.
      const reopened = new PhoneLinkEngine(b.phoneStore, new NodeSigVerifier(), new NodeHasher(), b.clock);
      reopened.load();
      expect(reopened.view().kid).assertEqual(code);
      b.dispose();
    });

    it('a second watch cannot replace the pinned one', 0, async () => {
      const b = new Bench();
      await b.watch.start();
      await b.watch.pair();
      await b.relay();
      b.phone.confirmPair();
      const intruder = new Bench();
      await intruder.watch.start();
      await intruder.watch.pair();
      const request = intruder.watchStore.read('pair.json');
      expect(request !== null).assertTrue();
      if (request !== null) {
        expect(await b.phone.receivePair(request, 'test')).assertFalse();
      }
      expect(b.phone.view().kid).assertEqual(b.signer.kid());
      expect(b.phone.view().log[0].message).assertEqual(MSG_OTHER_WATCH);
      intruder.dispose();
      b.dispose();
    });

    it('the demo: off-wrist stretch, close day, import, tamper, drop', 0, async () => {
      const b = new Bench();
      await b.watch.start();
      await b.watch.pair();
      await b.relay();
      b.phone.confirmPair();
      await b.relay();

      // Demo clock x300: 20 s worn, 40 s without heart rate (about 3 h of recorder time), 10 s worn.
      b.watch.setDemoClock(true);
      await b.run(20, 70);
      expect(b.watch.view().state).assertEqual('W');
      await b.run(40, 0);
      expect(b.watch.view().state).assertEqual('O');
      await b.run(10, 70);
      expect(b.watch.view().state).assertEqual('W');
      expect(await b.watch.closeDayNow()).assertEqual(1);
      expect(b.watchStore.list('outbox').join(',')).assertEqual('1.json');
      expect(b.watch.view().statusLine).assertEqual('1 to sync');

      await b.relay();
      let days = b.phone.timeline();
      expect(days.length).assertEqual(1);
      expect(days[0].received).assertTrue();
      expect(days[0].date).assertEqual(D4);
      expect(days[0].clock).assertEqual('DEMO_X300');
      expect(days[0].sourceLine).assertEqual(sourceLine(1));
      expect(days[0].breaks.length).assertEqual(1);
      expect(days[0].breaks[0].endMin - days[0].breaks[0].startMin).assertLargerOrEqual(175);
      expect(days[0].breaks[0].hrSlots24hBefore).assertLargerOrEqual(18);
      expect(days[0].breaks[0].rhr24hBefore).assertEqual(70);
      expect(days[0].wornMin).assertLargerOrEqual(125);
      // The hours before the app started and after the close were not observed: never off-wrist.
      expect(days[0].notObservedMin).assertLarger(600);
      expect(days[0].offMin).assertLess(200);
      expect(b.phone.view().chainLine).assertEqual('Chain #1 ✓');
      expect(b.watchStore.list('outbox').length).assertEqual(0);
      expect(b.watch.view().statusLine).assertEqual(STATUS_SYNCED);

      // Day 2, damaged on the way: rejected, not imported, and the watch keeps its packet.
      await b.run(15, 66);
      expect(await b.watch.closeDayNow()).assertEqual(2);
      const tamper = new RelayOptions();
      tamper.tamper = true;
      await b.relay(tamper);
      expect(b.phone.view().log[0].message).assertEqual(MSG_INVALID_SIGNATURE);
      expect(b.phone.timeline().length).assertEqual(1);
      expect(b.watch.view().statusLine).assertEqual('1 to sync');
      expect(b.watch.view().lastAck).assertEqual(`#2: ${MSG_INVALID_SIGNATURE}`);
      await b.relay();
      expect(b.phone.view().log[0].message).assertEqual(MSG_ACCEPTED);
      expect(b.phone.timeline().length).assertEqual(2);
      expect(b.watch.view().statusLine).assertEqual(STATUS_SYNCED);

      // Days 3 and 4, with 3 held back: 4 is accepted, 3 shows as not received.
      await b.run(15, 64);
      expect(await b.watch.closeDayNow()).assertEqual(3);
      await b.run(15, 64);
      expect(await b.watch.closeDayNow()).assertEqual(4);
      const drop = new RelayOptions();
      drop.drop = 3;
      await b.relay(drop);
      expect(b.phone.view().chainLine).assertEqual('1 day missing');
      days = b.phone.timeline();
      expect(days.length).assertEqual(4);
      expect(days[2].received).assertFalse();
      expect(days[2].reason).assertEqual(missingDayReason(3));
      expect(days[2].wornMin).assertEqual(0);
      expect(days[2].breaks.length).assertEqual(0);
      expect(days[3].received).assertTrue();
      expect(b.watch.view().statusLine).assertEqual('1 to sync');

      // The held-back day arrives later and fills the gap; a further relay only finds duplicates.
      await b.relay();
      expect(b.phone.view().chainLine).assertEqual('Chain #4 ✓');
      expect(b.phone.timeline()[2].received).assertTrue();
      expect(b.watch.view().statusLine).assertEqual(STATUS_SYNCED);
      const replay = b.phone.packet(2);
      expect(replay !== null).assertTrue();
      if (replay !== null) {
        const out = await b.phone.receiveDay(JSON.stringify(replay), 2, 'test');
        expect(out.message).assertEqual(MSG_DUPLICATE);
      }

      // Dates advance one per closed day and stay in order.
      expect(b.phone.timeline()[3].date).assertEqual('2026-10-07');

      // Forget watch: the ledger and its days are gone; a packet from the old watch is unknown.
      b.phone.forget();
      expect(b.phone.isPaired()).assertFalse();
      expect(b.phone.timeline().length).assertEqual(0);
      await b.run(15, 64);
      await b.watch.closeDayNow();
      await b.relay();
      expect(b.phone.view().log[0].message).assertEqual(MSG_UNKNOWN_KEY);
      expect(b.watch.view().statusLine).assertEqual(STATUS_NOT_PAIRED);
      b.dispose();
    });

    it('the watch continues its chain and clock after a restart', 0, async () => {
      const b = new Bench();
      await b.watch.start();
      b.watch.setDemoClock(true);
      await b.run(12, 70);
      expect(await b.watch.closeDayNow()).assertEqual(1);
      b.watch.setDemoClock(false);
      b.watch.pause();
      const dateBefore = b.watch.view().recorderDate;
      const restarted = new WatchLinkEngine(b.watchStore, b.signer, new NodeHasher(), b.clock, TZ);
      await restarted.start();
      expect(restarted.view().recorderDate).assertEqual(dateBefore);
      expect(restarted.view().clockLabel).assertEqual('DEMO_OFFSET');
      expect(restarted.pendingCount()).assertEqual(1);
      b.watch = restarted;
      b.watch.setDemoClock(true);
      await b.run(12, 70);
      expect(await b.watch.closeDayNow()).assertEqual(2);
      // Reset: a fresh chain on the real clock.
      b.watch.reset();
      expect(b.watch.pendingCount()).assertEqual(0);
      expect(b.watch.view().clockLabel).assertEqual('REAL');
      expect(b.watchStore.list('days').length).assertEqual(0);
      b.dispose();
    });

    it('after a pause the old readings do not count: the state is unknown until a new reading', 0, async () => {
      const b = new Bench();
      await b.watch.start();
      b.watch.setDemoClock(true);
      await b.run(10, 70);
      expect(b.watch.view().state).assertEqual('W');
      b.watch.pause();
      b.clock.ms += 2000;                 // the page was hidden
      await b.run(8, 0);                  // back, but no sensor event yet
      expect(b.watch.view().state).assertEqual('U');
      await b.run(3, 70);                 // the first new reading
      expect(b.watch.view().state).assertEqual('W');
      b.dispose();
    });

    it('forget watch also removes the old ACKs, so a new pairing is not answered by them', 0, async () => {
      const b = new Bench();
      await b.watch.start();
      await b.watch.pair();
      await b.relay();
      b.phone.confirmPair();
      await b.relay();
      expect(b.phoneStore.list('acks').length > 0).assertTrue();
      b.phone.forget();
      expect(b.phoneStore.list('acks').length).assertEqual(0);
      b.dispose();
    });

    it('without any sensor signal nothing is recorded as off-wrist', 0, async () => {
      const b = new Bench();
      await b.watch.start();
      b.watch.setDemoClock(true);
      await b.run(30, 0);                 // no heart-rate events at all: permission denied, no sensor
      expect(b.watch.view().state).assertEqual('U');
      expect(b.watch.view().slots.indexOf('O')).assertEqual(-1);
      expect(await b.watch.closeDayNow()).assertEqual(0);
      b.dispose();
    });
  });
}
