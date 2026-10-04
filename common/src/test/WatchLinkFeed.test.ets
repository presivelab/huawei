// The demo feed through the watch engine under Node. Not part of List.test.ets (the ports come from
// tools/logic-tests/node-ports.ts).
import { describe, it, expect } from '@ohos/hypium';
import { FsTextStore, makeTempDir, NodeHasher, NodeSigner, removeDir } from '@fairwear/node-ports';
import { DEFAULT_THRESHOLDS } from '../main/ets/model/defaults';
import { DayPacketCodec } from '../main/ets/watchlink/DayPacketCodec';
import { WatchLinkEngine } from '../main/ets/watchlink/WatchLinkEngine';
import { Clock } from '../main/ets/watchlink/WatchLinkPorts';
import { DayPacket, dayNumberOfDate, slotStartMs } from '../main/ets/watchlink/WatchLinkTypes';

const TZ = 120;
const D4 = '2026-10-04';
// One recorder day at x300 is 288 real seconds.
const DAY_REAL_SECONDS = 288;

class StepClock implements Clock {
  ms: number;

  constructor(ms: number) {
    this.ms = ms;
  }

  nowMs(): number {
    return this.ms;
  }
}

class FeedBench {
  dir: string = makeTempDir();
  store: FsTextStore;
  clock: StepClock = new StepClock(slotStartMs(dayNumberOfDate(D4), 0, TZ));
  watch: WatchLinkEngine;

  constructor() {
    this.store = new FsTextStore(this.dir);
    this.watch = new WatchLinkEngine(this.store, new NodeSigner(), new NodeHasher(), this.clock, TZ);
  }

  // `seconds` real seconds of the watch app running. `sensorBpm` > 0 also sends a sensor reading each second.
  async run(seconds: number, sensorBpm: number): Promise<void> {
    for (let i = 0; i < seconds; i++) {
      this.clock.ms += 1000;
      if (sensorBpm > 0) {
        this.watch.onHr(sensorBpm);
      }
      await this.watch.tick(0);
    }
  }

  packet(seq: number): DayPacket | null {
    const text = this.store.read(`outbox/${seq}.json`);
    return text === null ? null : DayPacketCodec.fromJson(text).packet;
  }

  dispose(): void {
    removeDir(this.dir);
  }
}

function count(slots: string, state: string): number {
  let n = 0;
  for (let i = 0; i < slots.length; i++) {
    if (slots.charAt(i) === state) {
      n++;
    }
  }
  return n;
}

export default function watchLinkFeedTest() {
  describe('WatchLink demo feed', () => {
    it('the feed cannot be switched on without the demo clock', 0, async () => {
      const b = new FeedBench();
      await b.watch.start();
      expect(b.watch.setDemoFeed(true)).assertFalse();
      expect(b.watch.isDemoFeed()).assertFalse();
      expect(b.watch.view().clockLabel).assertEqual('REAL');
      b.dispose();
    });

    it('a fed day has night charging, worn hours, one break and steps, and its packet says FEED', 0,
      async () => {
        const b = new FeedBench();
        await b.watch.start();
        b.watch.setDemoClock(true);
        expect(b.watch.setDemoFeed(true)).assertTrue();
        expect(b.watch.view().clockLabel).assertEqual('DEMO_X300_FEED');

        await b.run(DAY_REAL_SECONDS - 2, 0);
        const view = b.watch.view();
        expect(view.demoFeed).assertTrue();
        expect(view.stepsToday > 3000).assertTrue();
        expect(count(view.slots, 'C') > 60).assertTrue();
        expect(count(view.slots, 'W') > 150).assertTrue();
        const off = count(view.slots, 'O');
        expect(off >= 28 && off <= 38).assertTrue();

        const seq = await b.watch.closeDayNow();
        expect(seq).assertEqual(1);
        const packet = b.packet(1);
        expect(packet !== null).assertTrue();
        if (packet !== null) {
          expect(packet.clock).assertEqual('DEMO_X300_FEED');
          expect(packet.date).assertEqual(D4);
          expect(count(packet.slots, 'W') > 150).assertTrue();
          // The 3 h break is long enough to be reported, with the context the phone's break rule needs.
          expect(packet.breaks.length).assertEqual(1);
          expect(packet.breaks[0].startMin).assertLargerOrEqual(720);
          expect(packet.breaks[0].startMin).assertLessOrEqual(750);
          expect(packet.breaks[0].endMin).assertLargerOrEqual(885);
          expect(packet.breaks[0].endMin).assertLessOrEqual(905);
          expect(packet.breaks[0].hrSlots24hBefore).assertLargerOrEqual(DEFAULT_THRESHOLDS.minHrReadingsBeforeGap);
        }
        b.dispose();
      });

    it('sensor readings are not mixed in while the feed runs', 0, async () => {
      const b = new FeedBench();
      await b.watch.start();
      b.watch.setDemoClock(true);
      b.watch.setDemoFeed(true);
      // The script says "on the charger" at night; a sensor heart rate of 150 must not turn that into worn.
      await b.run(20, 150);
      const view = b.watch.view();
      expect(view.state).assertEqual('C');
      expect(view.feedHr).assertEqual(0);
      expect(count(view.slots, 'W')).assertEqual(0);
      b.dispose();
    });

    it('a day that received any scripted readings keeps the FEED label after the feed is switched off', 0,
      async () => {
        const b = new FeedBench();
        await b.watch.start();
        b.watch.setDemoClock(true);
        b.watch.setDemoFeed(true);
        await b.run(30, 0);
        expect(b.watch.setDemoFeed(false)).assertFalse();
        expect(b.watch.view().clockLabel).assertEqual('DEMO_X300');
        await b.run(30, 70);
        await b.watch.closeDayNow();
        const packet = b.packet(1);
        expect(packet !== null).assertTrue();
        if (packet !== null) {
          expect(packet.clock).assertEqual('DEMO_X300_FEED');
        }
        b.dispose();
      });

    it('switching the demo clock off switches the feed off', 0, async () => {
      const b = new FeedBench();
      await b.watch.start();
      b.watch.setDemoClock(true);
      b.watch.setDemoFeed(true);
      b.watch.setDemoClock(false);
      expect(b.watch.isDemoFeed()).assertFalse();
      expect(b.watch.view().demoFeed).assertFalse();
      b.dispose();
    });

    it('without the feed the demo clock label is unchanged', 0, async () => {
      const b = new FeedBench();
      await b.watch.start();
      b.watch.setDemoClock(true);
      await b.run(10, 70);
      await b.watch.closeDayNow();
      const packet = b.packet(1);
      expect(packet !== null).assertTrue();
      if (packet !== null) {
        expect(packet.clock).assertEqual('DEMO_X300');
      }
      b.dispose();
    });
  });
}
