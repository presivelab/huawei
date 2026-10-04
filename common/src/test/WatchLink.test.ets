// Watch Link logic tests. Run under Node by tools/run-logic-tests.sh (the ports come from
// tools/logic-tests/node-ports.ts), so this file is not part of List.test.ets.
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
import { ChainLedger } from '../main/ets/watchlink/ChainLedger';
import { DayBuilder } from '../main/ets/watchlink/DayBuilder';
import { AckPacketCodec, DayPacketCodec, PairPacketCodec } from '../main/ets/watchlink/DayPacketCodec';
import {
  AckVerifier,
  DayPacketVerifier,
  MSG_ACCEPTED,
  MSG_CHAIN_CONFLICT,
  MSG_DATE_FUTURE,
  MSG_DATE_ORDER,
  MSG_DEMO_CLOCK,
  MSG_DUPLICATE,
  MSG_INVALID_FORMAT,
  MSG_INVALID_SIGNATURE,
  MSG_KEY_ID_MISMATCH,
  MSG_PAIR_VALID,
  MSG_UNKNOWN_KEY,
  MSG_UNSUPPORTED_VERSION,
  PairVerifier
} from '../main/ets/watchlink/DayPacketVerifier';
import {
  chainStateFromJson,
  chainStateToJson,
  newChainState,
  PacketSealer,
  SealedDay,
  WatchChainState
} from '../main/ets/watchlink/PacketSealer';
import { SlotRecorder } from '../main/ets/watchlink/SlotRecorder';
import { Clock } from '../main/ets/watchlink/WatchLinkPorts';
import { daySigningString } from '../main/ets/watchlink/WatchLinkSigning';
import {
  BreakContext,
  classifySlot,
  dayNumberOfDate,
  DayPacket,
  DayRecord,
  emptyDay,
  emptySlot,
  GENESIS,
  MAX_PACKET_BYTES,
  SlotRecord,
  SlotState,
  slotStartMs
} from '../main/ets/watchlink/WatchLinkTypes';
import {
  FRESHNESS_DEMO_CLOCK_MS,
  FRESHNESS_REAL_CLOCK_MS,
  WearStateMachine
} from '../main/ets/watchlink/WearStateMachine';

const TZ = 120;                       // minutes east of UTC
const D1 = '2026-10-01';
const D2 = '2026-10-02';
const D3 = '2026-10-03';
const D4 = '2026-10-04';
const DEMO_LABEL = 'DEMO_X300';

class FixedClock implements Clock {
  ms: number;

  constructor(ms: number) {
    this.ms = ms;
  }

  nowMs(): number {
    return this.ms;
  }
}

// Epoch ms of a local time on a date.
function at(date: string, hour: number, minute: number, second: number = 0): number {
  return slotStartMs(dayNumberOfDate(date), 0, TZ) + ((hour * 60 + minute) * 60 + second) * 1000;
}

// Fills slots [from, to) of a day record as fully observed in one state.
function fill(day: DayRecord, from: number, to: number, state: SlotState, hr: number = 0, steps: number = 0): void {
  for (let i = from; i < to; i++) {
    const slot: SlotRecord = day.slots[i];
    slot.observedSec = 300;
    slot.wornSec = state === 'W' ? 300 : 0;
    slot.chargingSec = state === 'C' ? 300 : 0;
    slot.offSec = state === 'O' ? 300 : 0;
    slot.hrSampleCount = hr > 0 ? 5 : 0;
    slot.hrSum = hr > 0 ? hr * 5 : 0;
    slot.steps = steps;
  }
}

function fullDay(date: string, state: SlotState, hr: number = 0): DayRecord {
  const day = emptyDay(date, TZ);
  fill(day, 0, 288, state, hr);
  day.closedCount = 288;
  day.sealed = true;
  return day;
}

// Feeds the recorder once per real second in one state, from `fromMs` up to and including `toMs`.
function feed(rec: SlotRecorder, fromMs: number, toMs: number, state: SlotState, hr: number): void {
  for (let t = fromMs; t <= toMs; t += 1000) {
    rec.tick(t, t, state, hr > 0 ? hr : null, 0);
  }
}

class Rig {
  signer: NodeSigner = new NodeSigner();
  verifier: NodeSigVerifier = new NodeSigVerifier();
  hasher: NodeHasher = new NodeHasher();
  watchClock: FixedClock = new FixedClock(at(D4, 12, 0));
  phoneClock: FixedClock = new FixedClock(at(D4, 12, 0));
  state: WatchChainState;
  ledger: ChainLedger;
  check: DayPacketVerifier;

  constructor() {
    this.state = newChainState(this.signer.kid());
    this.ledger = new ChainLedger(this.signer.kid(), this.signer.publicKeySpkiB64());
    // The demo build's setting: demo-clock packets are taken in (the default refuses them).
    this.check = new DayPacketVerifier(this.verifier, this.hasher, this.phoneClock, true);
  }

  // Signs the next packet of the chain for a worn day and advances the watch's chain state.
  async next(date: string): Promise<SealedDay> {
    const sealed = await PacketSealer.sealDay(DayBuilder.build(fullDay(date, 'W', 62), null), this.state,
      this.signer, this.hasher, this.watchClock);
    this.state.seq = sealed.packet.seq;
    this.state.lastHash = sealed.hash;
    return sealed;
  }
}

function worstCaseBreaks(): BreakContext[] {
  const out: BreakContext[] = [];
  for (let i = 0; i < 12; i++) {
    const b: BreakContext = {
      startMin: -1440,
      endMin: 1435,
      hrSlots24hBefore: 288,
      rhr24hBefore: 230,
      steps24hBefore: 2147483647
    };
    out.push(b);
  }
  return out;
}

export default function watchLinkTest() {
  describe('WatchLink 1.4 WearStateMachine', () => {
    it('1a. heart-rate gap of 59 s is worn, 61 s is off-wrist', 0, () => {
      const m = new WearStateMachine(FRESHNESS_REAL_CLOCK_MS);
      expect(m.hasSignal()).assertFalse();
      m.onHr(0, 70);
      expect(m.hasSignal()).assertTrue();
      expect(m.state(59000)).assertEqual('W');
      expect(m.state(60000)).assertEqual('W');
      expect(m.state(61000)).assertEqual('O');
      expect(m.source()).assertEqual('HR_SIGNAL');
    });

    it('1b. charging overrides everything', 0, () => {
      const m = new WearStateMachine();
      m.onHr(0, 70);
      m.onWear(0, 1);
      m.onCharging(500, true);
      expect(m.state(1000)).assertEqual('C');
      m.onCharging(2000, false);
      expect(m.state(2500)).assertEqual('W');
    });

    it('1c. the wear sensor wins over the heart-rate signal', 0, () => {
      const m = new WearStateMachine();
      m.onHr(0, 70);
      m.onWear(1000, 0);
      expect(m.state(2000)).assertEqual('O');       // fresh heart rate, sensor says off
      m.onWear(200000, 1);
      expect(m.state(300000)).assertEqual('W');     // stale heart rate, sensor says on
      expect(m.source()).assertEqual('SENSOR');
    });

    it('1d. 0 bpm and out-of-range values are not readings', 0, () => {
      const m = new WearStateMachine();
      m.onHr(0, 0);
      m.onHr(1000, 24);
      m.onHr(2000, 231);
      expect(m.hasSignal()).assertTrue();
      expect(m.state(2000)).assertEqual('O');
      m.onHr(3000, 25);
      expect(m.state(3000)).assertEqual('W');
    });

    it('2. demo clock x300 with 1 Hz heart rate stays worn; 4 s real without it is off-wrist', 0, () => {
      const dir = makeTempDir();
      const rec = new SlotRecorder(new FsTextStore(dir), TZ);
      rec.setClock(300, DEMO_LABEL);
      const m = new WearStateMachine(FRESHNESS_DEMO_CLOCK_MS);
      const realStart = at(D1, 8, 0);
      const recStart = at(D1, 8, 0);
      // 30 real seconds = 150 recorder minutes = 30 slots.
      for (let i = 0; i <= 30; i++) {
        const realMs = realStart + i * 1000;
        m.onHr(realMs, 70);
        expect(m.state(realMs)).assertEqual('W');
        rec.tick(realMs, recStart + i * 300 * 1000, m.state(realMs), 70, 0);
      }
      const slots = rec.slotString();
      expect(slots.substring(96, 126)).assertEqual('W'.repeat(30));
      expect(slots.indexOf('O')).assertEqual(-1);
      const last = realStart + 30 * 1000;
      expect(m.state(last + 3000)).assertEqual('W');
      expect(m.state(last + 4000)).assertEqual('O');
      const day = rec.currentDay();
      expect(day !== null && day.clock === DEMO_LABEL).assertTrue();
      removeDir(dir);
    });
  });

  describe('WatchLink 1.5 SlotRecorder', () => {
    it('3a. 100 s observed is U; 200 s worn + 100 s off is W; a charging tie is C', 0, () => {
      const a = emptySlot(0);
      a.observedSec = 100;
      a.wornSec = 100;
      expect(classifySlot(a)).assertEqual('U');
      const b = emptySlot(1);
      b.observedSec = 300;
      b.wornSec = 200;
      b.offSec = 100;
      expect(classifySlot(b)).assertEqual('W');
      const c = emptySlot(2);
      c.observedSec = 300;
      c.chargingSec = 150;
      c.wornSec = 150;
      expect(classifySlot(c)).assertEqual('C');
      const d = emptySlot(3);
      d.observedSec = 300;
      d.wornSec = 150;
      d.offSec = 150;
      expect(classifySlot(d)).assertEqual('W');
      const e = emptySlot(4);
      e.observedSec = 300;
      e.wornSec = 100;
      e.offSec = 200;
      expect(classifySlot(e)).assertEqual('O');
    });

    it('3b. the recorder puts seconds into the right slot and bucket', 0, () => {
      const dir = makeTempDir();
      const rec = new SlotRecorder(new FsTextStore(dir), TZ);
      // 08:00:00-08:01:40 worn (100 s), then nothing: slot 96 stays U.
      feed(rec, at(D1, 8, 0), at(D1, 8, 1, 40), 'W', 70);
      rec.pause();
      // 08:05:00-08:08:20 worn (200 s), 08:08:20-08:10:00 off (100 s): slot 97 is W.
      feed(rec, at(D1, 8, 5), at(D1, 8, 8, 20), 'W', 70);
      feed(rec, at(D1, 8, 8, 21), at(D1, 8, 10), 'O', 0);
      const day = rec.currentDay();
      expect(day !== null).assertTrue();
      if (day !== null) {
        expect(day.slots[96].observedSec).assertEqual(100);
        expect(day.slots[97].observedSec).assertEqual(300);
        expect(day.slots[97].wornSec).assertEqual(200);
        expect(day.slots[97].offSec).assertEqual(100);
        expect(day.slots[97].hrSampleCount).assertEqual(201);
      }
      const slots = rec.slotString();
      expect(slots.charAt(96)).assertEqual('U');
      expect(slots.charAt(97)).assertEqual('W');
      removeDir(dir);
    });

    it('4. a suspension gap of 3 h is not observed (U) and creates no break', 0, () => {
      const dir = makeTempDir();
      const rec = new SlotRecorder(new FsTextStore(dir), TZ);
      feed(rec, at(D1, 9, 0), at(D1, 9, 10), 'W', 70);
      // No pause() call: the process was simply not running for three hours.
      feed(rec, at(D1, 12, 10), at(D1, 12, 20), 'O', 0);
      const day = rec.closeDayNow();
      expect(day !== null).assertTrue();
      if (day !== null) {
        const p = DayBuilder.build(day, null);
        expect(p.slots.substring(108, 110)).assertEqual('WW');
        expect(p.slots.substring(110, 146)).assertEqual('U'.repeat(36));
        expect(p.slots.substring(146, 148)).assertEqual('OO');
        expect(p.breaks.length).assertEqual(0);
        // Not a single second of the gap was counted as anything.
        expect(day.slots[120].observedSec).assertEqual(0);
      }
      removeDir(dir);
    });

    it('5a. midnight rollover: slot 287 closes the day, a new day file starts', 0, () => {
      const dir = makeTempDir();
      const store = new FsTextStore(dir);
      const rec = new SlotRecorder(store, TZ);
      feed(rec, at(D1, 23, 50), at(D2, 0, 10), 'W', 60);
      const finished = rec.takeFinishedDays();
      expect(finished.length).assertEqual(1);
      expect(finished[0].date).assertEqual(D1);
      expect(finished[0].sealed).assertTrue();
      expect(finished[0].slots[287].observedSec).assertEqual(300);
      expect(classifySlot(finished[0].slots[287])).assertEqual('W');
      expect(store.list('days').sort().join(',')).assertEqual(`${D1}.json,${D2}.json`);
      const today = rec.currentDay();
      expect(today !== null && today.date === D2).assertTrue();
      expect(rec.slotString().substring(0, 2)).assertEqual('WW');
      // Until the packet is in the outbox the day is offered again after a restart.
      const again = new SlotRecorder(store, TZ);
      feed(again, at(D2, 0, 11), at(D2, 0, 12), 'W', 60);
      expect(again.takeFinishedDays().length).assertEqual(1);
      again.markPacked(D1);
      const third = new SlotRecorder(store, TZ);
      feed(third, at(D2, 0, 13), at(D2, 0, 14), 'W', 60);
      expect(third.takeFinishedDays().length).assertEqual(0);
      removeDir(dir);
    });

    it('5b. the current day is restored after a restart', 0, () => {
      const dir = makeTempDir();
      const store = new FsTextStore(dir);
      const first = new SlotRecorder(store, TZ);
      feed(first, at(D1, 10, 0), at(D1, 10, 10), 'W', 64);
      first.pause();
      const second = new SlotRecorder(store, TZ);
      feed(second, at(D1, 10, 30), at(D1, 10, 40), 'W', 64);
      const slots = second.slotString();
      expect(slots.substring(120, 122)).assertEqual('WW');
      expect(slots.substring(122, 126)).assertEqual('UUUU');
      expect(slots.substring(126, 128)).assertEqual('WW');
      removeDir(dir);
    });

    it('5c. the night window counts slots 0-71 only', 0, () => {
      const day = emptyDay(D1, TZ);
      fill(day, 60, 80, 'W', 55);       // 05:00-06:40
      fill(day, 0, 6, 'C');             // 00:00-00:30
      const p = DayBuilder.build(day, null);
      expect(p.nightWornMin).assertEqual(60);
      expect(p.nightChargingMin).assertEqual(30);
      const all = DayBuilder.build(fullDay(D1, 'W', 55), null);
      expect(all.nightWornMin).assertEqual(360);
    });

    it('close day (demo): the rest of the day stays U and the sealed day takes no more time', 0, () => {
      const dir = makeTempDir();
      const rec = new SlotRecorder(new FsTextStore(dir), TZ);
      feed(rec, at(D1, 6, 0), at(D1, 6, 30), 'W', 60);
      const day = rec.closeDayNow();
      expect(day !== null && day.sealed).assertTrue();
      expect(rec.takeFinishedDays().length).assertEqual(1);
      feed(rec, at(D1, 6, 31), at(D1, 6, 45), 'O', 0);       // clock not moved on yet: ignored
      expect(rec.slotString().indexOf('O')).assertEqual(-1);
      feed(rec, at(D2, 0, 0), at(D2, 0, 10), 'W', 60);       // next day records normally
      expect(rec.slotString().substring(0, 2)).assertEqual('WW');
      expect(rec.takeFinishedDays().length).assertEqual(0);
      removeDir(dir);
    });
  });

  describe('WatchLink 1.6 DayBuilder', () => {
    it('6. 24 O slots (exactly 2 h) is one break, as on the phone; 23 is none; 30 C is none; 40 U is none', 0, () => {
      const a = fullDay(D1, 'W', 60);
      fill(a, 100, 125, 'O');
      const pa = DayBuilder.build(a, null);
      expect(pa.breaks.length).assertEqual(1);
      expect(pa.breaks[0].startMin).assertEqual(500);
      expect(pa.breaks[0].endMin).assertEqual(625);

      const exact = fullDay(D1, 'W', 60);
      fill(exact, 100, 124, 'O');
      const pe = DayBuilder.build(exact, null);
      expect(pe.breaks.length).assertEqual(1);
      expect(pe.breaks[0].endMin - pe.breaks[0].startMin).assertEqual(120);

      const b = fullDay(D1, 'W', 60);
      fill(b, 100, 123, 'O');
      expect(DayBuilder.build(b, null).breaks.length).assertEqual(0);

      const c = fullDay(D1, 'W', 60);
      fill(c, 100, 130, 'C');
      expect(DayBuilder.build(c, null).breaks.length).assertEqual(0);

      const d = fullDay(D1, 'W', 60);
      for (let i = 100; i < 140; i++) {
        d.slots[i] = emptySlot(i);
      }
      const pd = DayBuilder.build(d, null);
      expect(pd.slots.substring(100, 140)).assertEqual('U'.repeat(40));
      expect(pd.breaks.length).assertEqual(0);
    });

    it('6b. U never joins a break: O U O does not add up', 0, () => {
      const day = fullDay(D1, 'W', 60);
      fill(day, 100, 115, 'O');
      day.slots[115] = emptySlot(115);
      fill(day, 116, 131, 'O');
      expect(DayBuilder.build(day, null).breaks.length).assertEqual(0);
    });

    it('7. a break across midnight is reported on the day it ends, with a negative start', 0, () => {
      const yesterday = fullDay(D1, 'W', 60);
      fill(yesterday, 276, 288, 'O');                // from 23:00
      const today = fullDay(D2, 'W', 60);
      fill(today, 0, 23, 'O');                       // until 01:55: under 2 h on its own
      expect(DayBuilder.build(yesterday, null).breaks.length).assertEqual(0);
      const p = DayBuilder.build(today, yesterday);
      expect(p.breaks.length).assertEqual(1);
      expect(p.breaks[0].startMin).assertEqual(-60);
      expect(p.breaks[0].endMin).assertEqual(115);
      // A record that is not the day before is ignored.
      const other = fullDay(D4, 'W', 60);
      fill(other, 276, 288, 'O');
      expect(DayBuilder.build(today, other).breaks.length).assertEqual(0);
    });

    it('8. break context is taken from the 24 h before the start, across the previous day', 0, () => {
      const yesterday = emptyDay(D1, TZ);
      fill(yesterday, 100, 190, 'W', 60, 0);         // 90 resting slots at 60 bpm
      fill(yesterday, 190, 200, 'W', 90, 50);        // 10 walking slots, 500 steps
      fill(yesterday, 200, 210, 'C');
      const today = emptyDay(D2, TZ);
      fill(today, 0, 12, 'W', 58, 0);                // 12 resting slots at 58 bpm
      fill(today, 12, 48, 'O');                      // break 01:00-04:00
      fill(today, 48, 60, 'W', 70, 20);
      const p = DayBuilder.build(today, yesterday);
      expect(p.breaks.length).assertEqual(1);
      const b = p.breaks[0];
      expect(b.startMin).assertEqual(60);
      expect(b.endMin).assertEqual(240);
      expect(b.hrSlots24hBefore).assertEqual(112);
      expect(b.rhr24hBefore).assertEqual(60);
      expect(b.steps24hBefore).assertEqual(500);
      // The resting estimate needs six resting slots between 07:00 and 23:00; this day has none there.
      expect(p.hrRestEst).assertEqual(-1);
      const rested = fullDay(D3, 'W', 61);
      expect(DayBuilder.build(rested, null).hrRestEst).assertEqual(61);
    });

    it('a packet holds measurements only', 0, () => {
      const json = DayPacketCodec.toJson(DayBuilder.build(fullDay(D1, 'W', 60), null)).toLowerCase();
      const banned: string[] = ['suspicious', 'compliant', 'tier', 'flag', 'eligible', 'score'];
      for (let i = 0; i < banned.length; i++) {
        expect(json.indexOf(banned[i])).assertEqual(-1);
      }
    });
  });

  describe('WatchLink 1.2 and 1.7 packet, signing string, codec', () => {
    it('9. the worst-case packet stays under 3800 bytes', 0, async () => {
      const rig = new Rig();
      const p = DayBuilder.build(fullDay(D1, 'W', 60), null);
      let slots = '';
      for (let i = 0; i < 288; i++) {
        slots += 'WCOU'.charAt(i % 4);
      }
      p.slots = slots;
      for (let h = 0; h < 24; h++) {
        p.stepsByHour[h] = 99999;
      }
      p.hrRestEst = 230;
      p.hrSlotCount = 288;
      p.breaks = worstCaseBreaks();
      p.tzOffsetMin = -720;
      rig.state.seq = 2147483646;
      const sealed = await PacketSealer.sealDay(p, rig.state, rig.signer, rig.hasher, rig.watchClock);
      const bytes = utf8ByteLength(sealed.json);
      expect(bytes).assertLessOrEqual(MAX_PACKET_BYTES);
      expect(DayPacketCodec.fromJson(sealed.json).code).assertEqual('OK');
    });

    it('10a. the signing string is the fixed list of lines', 0, () => {
      const p = DayBuilder.build(fullDay(D1, 'W', 60), null);
      p.kid = '3fa9c1d2';
      p.seq = 7;
      p.prev = 'PREVHASH';
      p.iat = 1790000000;
      const one: BreakContext = { startMin: -60, endMin: 120, hrSlots24hBefore: 40, rhr24hBefore: 58,
        steps24hBefore: 4200 };
      const two: BreakContext = { startMin: 600, endMin: 800, hrSlots24hBefore: 12, rhr24hBefore: -1,
        steps24hBefore: 0 };
      p.breaks = [one, two];
      const zeros: string[] = [];
      for (let i = 0; i < 24; i++) {
        zeros.push('0');
      }
      const expected: string[] = ['FWDAY1', '3fa9c1d2', '7', 'PREVHASH', D1, '120', 'W'.repeat(288),
        zeros.join(','), '60', '288', '360', '0', '-60:120:40:58:4200;600:800:12:-1:0', 'HR_SIGNAL', 'REAL',
        '1790000000'];
      expect(daySigningString(p)).assertEqual(expected.join('\n'));
      expect(daySigningString(p)).assertEqual(daySigningString(p));
    });

    it('10b. sign then verify: the first packet of a chain is accepted', 0, async () => {
      const rig = new Rig();
      const sealed = await rig.next(D1);
      expect(sealed.packet.seq).assertEqual(1);
      expect(sealed.packet.prev).assertEqual(GENESIS);
      expect(sealed.packet.kid).assertEqual(rig.signer.kid());
      const out = await rig.check.verify(sealed.json, rig.ledger);
      expect(out.message).assertEqual(MSG_ACCEPTED);
      expect(out.status).assertEqual('ACCEPTED');
      expect(out.hash).assertEqual(sealed.hash);
      expect(rig.ledger.lastSeq).assertEqual(1);
      expect(rig.ledger.lastHash).assertEqual(sealed.hash);
      const second = await rig.next(D2);
      expect(second.packet.prev).assertEqual(sealed.hash);
      expect((await rig.check.verify(second.json, rig.ledger)).message).assertEqual(MSG_ACCEPTED);
    });

    it('the codec rejects malformed packets with a reason', 0, async () => {
      const rig = new Rig();
      const good = (await rig.next(D1)).json;
      expect(DayPacketCodec.fromJson(good).code).assertEqual('OK');
      const cases: string[] = [
        good.replace('"slots":"W', '"slots":"X'),
        good.replace('"slots":"W', '"slots":"'),
        good.replace('"stepsByHour":[0,', '"stepsByHour":['),
        good.replace('"stepsByHour":[0,', '"stepsByHour":[-1,'),
        good.replace('"stepsByHour":[0,', '"stepsByHour":[1.5,'),
        good.replace(`"date":"${D1}"`, '"date":"2026-13-01"'),
        good.replace(`"date":"${D1}"`, '"date":"1.10.2026"'),
        good.replace('"seq":1', '"seq":0'),
        good.replace('"seq":1', '"seq":"1"'),
        good.replace('"wearSource":"HR_SIGNAL"', '"wearSource":"GUESS"'),
        good.replace('"breaks":[]', '"breaks":[{"startMin":10,"endMin":5,"hrSlots24hBefore":1,' +
          '"rhr24hBefore":1,"steps24hBefore":1}]'),
        good.replace('"clock":"REAL"', '"clock":"RE\\nAL"'),
        '[1,2,3]',
        'null',
        ''
      ];
      for (let i = 0; i < cases.length; i++) {
        const r = DayPacketCodec.fromJson(cases[i]);
        expect(r.code).assertEqual('FORMAT');
        expect(r.packet).assertNull();
      }
      const thirteen: string[] = [];
      for (let i = 0; i < 13; i++) {
        thirteen.push('{"startMin":0,"endMin":200,"hrSlots24hBefore":1,"rhr24hBefore":60,"steps24hBefore":1}');
      }
      expect(DayPacketCodec.fromJson(good.replace('"breaks":[]', `"breaks":[${thirteen.join(',')}]`)).code)
        .assertEqual('FORMAT');
      expect(DayPacketCodec.fromJson(good.replace('"v":1', '"v":2')).code).assertEqual('VERSION');
    });

    it('ACK packets round-trip, signed by the phone', 0, async () => {
      const phone = new NodeSigner();
      const watchKid = new NodeSigner().kid();
      const ack = await PacketSealer.sealAck(AckPacketCodec.make(7, 'REJECTED', MSG_INVALID_SIGNATURE, watchKid,
        'ref_hash', '', '', 1700000000), phone);
      const json = AckPacketCodec.toJson(ack);
      const back = AckPacketCodec.fromJson(json);
      expect(back.code).assertEqual('OK');
      const p = back.packet;
      expect(p !== null && p.seq === 7 && p.status === 'REJECTED' && p.reason === MSG_INVALID_SIGNATURE &&
        p.watchKid === watchKid && p.ref === 'ref_hash' && p.phoneKid === phone.kid()).assertTrue();
      if (p !== null) {
        expect(await AckVerifier.verify(p, new NodeSigVerifier(), new NodeHasher())).assertTrue();
      }
      expect(AckPacketCodec.fromJson(json.replace('REJECTED', 'MAYBE')).code).assertEqual('FORMAT');
      // A line break in the reason would add a line to the signing string.
      expect(AckPacketCodec.fromJson(json.replace(MSG_INVALID_SIGNATURE, 'a\\nb')).code).assertEqual('FORMAT');
      // The unsigned version-1 ACK is not taken.
      expect(AckPacketCodec.fromJson('{"v":1,"type":"ACK","seq":7,"status":"ACCEPTED","reason":"Accepted"}').code)
        .assertEqual('VERSION');
    });
  });

  describe('WatchLink 1.8 ChainLedger and DayPacketVerifier', () => {
    it('11. one changed slots character is an invalid signature', 0, async () => {
      const rig = new Rig();
      const sealed = await rig.next(D1);
      const tampered = sealed.json.replace('"slots":"W', '"slots":"O');
      expect(tampered === sealed.json).assertFalse();
      const out = await rig.check.verify(tampered, rig.ledger);
      expect(out.status).assertEqual('REJECTED');
      expect(out.message).assertEqual(MSG_INVALID_SIGNATURE);
      expect(rig.ledger.lastSeq).assertEqual(0);
    });

    it('12. a replay is a duplicate; the same seq with other content is a chain conflict', 0, async () => {
      const rig = new Rig();
      const first = await rig.next(D1);
      expect((await rig.check.verify(first.json, rig.ledger)).message).assertEqual(MSG_ACCEPTED);
      const replay = await rig.check.verify(first.json, rig.ledger);
      expect(replay.status).assertEqual('DUPLICATE');
      expect(replay.message).assertEqual(MSG_DUPLICATE);
      expect(rig.ledger.acceptedCount()).assertEqual(1);

      // The watch signs a different day under the same seq (state rolled back).
      rig.state.seq = 0;
      rig.state.lastHash = GENESIS;
      const other = await PacketSealer.sealDay(DayBuilder.build(fullDay(D1, 'O'), null), rig.state, rig.signer,
        rig.hasher, rig.watchClock);
      const conflict = await rig.check.verify(other.json, rig.ledger);
      expect(conflict.status).assertEqual('REJECTED');
      expect(conflict.message).assertEqual(MSG_CHAIN_CONFLICT);
    });

    it('12b. the next seq with the wrong prev is a chain conflict', 0, async () => {
      const rig = new Rig();
      const first = await rig.next(D1);
      await rig.check.verify(first.json, rig.ledger);
      rig.state.lastHash = 'not-the-hash-of-packet-1';
      const second = await rig.next(D2);
      const out = await rig.check.verify(second.json, rig.ledger);
      expect(out.message).assertEqual(MSG_CHAIN_CONFLICT);
      expect(rig.ledger.lastSeq).assertEqual(1);
    });

    it('13. seq 3 after 1 is accepted with "Missing 1 day(s)"; the late day then fills the gap', 0, async () => {
      const rig = new Rig();
      const p1 = await rig.next(D1);
      const p2 = await rig.next(D2);
      const p3 = await rig.next(D3);
      expect((await rig.check.verify(p1.json, rig.ledger)).message).assertEqual(MSG_ACCEPTED);
      const out = await rig.check.verify(p3.json, rig.ledger);
      expect(out.status).assertEqual('ACCEPTED');
      expect(out.message).assertEqual(MSG_ACCEPTED);
      expect(out.note).assertEqual('Missing 1 day(s)');
      expect(out.newlyMissing.length).assertEqual(1);
      expect(out.newlyMissing[0]).assertEqual(2);
      expect(rig.ledger.missingSeqs.length).assertEqual(1);

      // The ledger survives being stored and restored.
      const restored = ChainLedger.fromJson(rig.ledger.toJson());
      expect(restored !== null).assertTrue();
      if (restored !== null) {
        const late = await rig.check.verify(p2.json, restored);
        expect(late.status).assertEqual('ACCEPTED');
        expect(late.filledMissing).assertTrue();
        expect(restored.missingSeqs.length).assertEqual(0);
        expect(restored.lastSeq).assertEqual(3);
        expect((await rig.check.verify(p2.json, restored)).message).assertEqual(MSG_DUPLICATE);
      }
    });

    it('13b. a late day that does not link to its neighbours is a chain conflict', 0, async () => {
      const rig = new Rig();
      const p1 = await rig.next(D1);
      await rig.next(D2);
      const p3 = await rig.next(D3);
      await rig.check.verify(p1.json, rig.ledger);
      await rig.check.verify(p3.json, rig.ledger);
      // A different packet 2: it links back to packet 1, but packet 3 does not link to it.
      rig.state.seq = 1;
      rig.state.lastHash = p1.hash;
      const forged = await PacketSealer.sealDay(DayBuilder.build(fullDay(D2, 'O'), null), rig.state, rig.signer,
        rig.hasher, rig.watchClock);
      expect((await rig.check.verify(forged.json, rig.ledger)).message).assertEqual(MSG_CHAIN_CONFLICT);
      expect(rig.ledger.missingSeqs.length).assertEqual(1);
    });

    it('14. unknown key, bad JSON, unsupported version', 0, async () => {
      const rig = new Rig();
      const stranger = new Rig();
      const foreign = await stranger.next(D1);
      expect((await rig.check.verify(foreign.json, rig.ledger)).message).assertEqual(MSG_UNKNOWN_KEY);
      expect((await rig.check.verify(foreign.json, null)).message).assertEqual(MSG_UNKNOWN_KEY);
      expect((await rig.check.verify('{"v":1,', rig.ledger)).message).assertEqual(MSG_INVALID_FORMAT);
      expect((await rig.check.verify('hello', rig.ledger)).message).assertEqual(MSG_INVALID_FORMAT);
      const own = await rig.next(D1);
      expect((await rig.check.verify(own.json.replace('"v":1', '"v":2'), rig.ledger)).message)
        .assertEqual(MSG_UNSUPPORTED_VERSION);
      // A packet signed by another key under the pinned kid fails on the signature.
      const disguised = foreign.json.replace(stranger.signer.kid(), rig.signer.kid());
      expect((await rig.check.verify(disguised, rig.ledger)).message).assertEqual(MSG_INVALID_SIGNATURE);
    });

    it('dates: the future and going backwards are rejected', 0, async () => {
      const rig = new Rig();
      rig.phoneClock.ms = at(D2, 12, 0);
      const p1 = await rig.next(D3);
      expect((await rig.check.verify(p1.json, rig.ledger)).message).assertEqual(MSG_DATE_FUTURE);
      expect(rig.ledger.lastSeq).assertEqual(0);

      const b = new Rig();
      const first = await b.next(D3);
      const second = await b.next(D1);
      expect((await b.check.verify(first.json, b.ledger)).message).assertEqual(MSG_ACCEPTED);
      expect((await b.check.verify(second.json, b.ledger)).message).assertEqual(MSG_DATE_ORDER);
      expect(b.ledger.lastSeq).assertEqual(1);
    });

    it('demo-clock packets carry simulated dates: taken in by a demo build, refused otherwise', 0, async () => {
      const rig = new Rig();
      rig.phoneClock.ms = at(D1, 12, 0);
      const day = fullDay(D3, 'W', 60);
      day.clock = DEMO_LABEL;
      const sealed = await PacketSealer.sealDay(DayBuilder.build(day, null), rig.state, rig.signer, rig.hasher,
        rig.watchClock);
      const strict = new DayPacketVerifier(rig.verifier, rig.hasher, rig.phoneClock, false);
      expect((await strict.verify(sealed.json, rig.ledger)).message).assertEqual(MSG_DEMO_CLOCK);
      const out = await rig.check.verify(sealed.json, rig.ledger);
      expect(out.message).assertEqual(MSG_ACCEPTED);
      expect(out.packet !== null && out.packet.clock === DEMO_LABEL).assertTrue();
    });

    it('15. pair packet: a wrong self-signature is rejected; kid follows the key-id rule', 0, async () => {
      const rig = new Rig();
      const json = await PacketSealer.makePair(rig.signer, rig.watchClock);
      const ok = await PairVerifier.verify(json, rig.verifier, rig.hasher);
      expect(ok.ok).assertTrue();
      expect(ok.message).assertEqual(MSG_PAIR_VALID);
      const decoded = PairPacketCodec.fromJson(json).packet;
      expect(decoded !== null).assertTrue();
      if (decoded !== null) {
        expect(decoded.kid.length).assertEqual(8);
        expect(decoded.kid).assertEqual(await rig.hasher.keyId(decoded.pub));
        expect(decoded.alg).assertEqual('ECDSA_P256_SHA256');
      }

      // Another key's public key under this signature.
      const other = new NodeSigner();
      const swapped = json.replace(rig.signer.publicKeySpkiB64(), other.publicKeySpkiB64());
      const bad = await PairVerifier.verify(swapped, rig.verifier, rig.hasher);
      expect(bad.ok).assertFalse();
      expect(bad.message).assertEqual(MSG_INVALID_SIGNATURE);

      // A correctly self-signed packet that claims a kid not derived from its key.
      const liar = new LyingSigner(other);
      const lied = await PairVerifier.verify(await PacketSealer.makePair(liar, rig.watchClock), rig.verifier,
        rig.hasher);
      expect(lied.ok).assertFalse();
      expect(lied.message).assertEqual(MSG_KEY_ID_MISMATCH);

      expect((await PairVerifier.verify('{}', rig.verifier, rig.hasher)).message).assertEqual(MSG_INVALID_FORMAT);
    });

    it('the watch chain state is stored per key', 0, () => {
      const state = newChainState('3fa9c1d2');
      state.seq = 4;
      state.lastHash = 'HASH4';
      state.paired = true;
      state.phoneKid = '0badc0de';
      state.phonePub = 'PHONEPUB';
      const back = chainStateFromJson(chainStateToJson(state), '3fa9c1d2');
      expect(back.seq).assertEqual(4);
      expect(back.lastHash).assertEqual('HASH4');
      expect(back.paired).assertTrue();
      expect(back.phoneKid).assertEqual('0badc0de');
      // A state from before signed ACKs (no phone key): not paired, the chain itself stays.
      const old = chainStateFromJson('{"kid":"3fa9c1d2","seq":4,"lastHash":"HASH4","paired":true}', '3fa9c1d2');
      expect(old.paired).assertFalse();
      expect(old.seq).assertEqual(4);
      expect(old.lastHash).assertEqual('HASH4');
      // Another key, a damaged file or no file: a fresh chain.
      expect(chainStateFromJson(chainStateToJson(state), 'aaaaaaaa').seq).assertEqual(0);
      expect(chainStateFromJson('{"seq":', '3fa9c1d2').lastHash).assertEqual(GENESIS);
      expect(chainStateFromJson(null, '3fa9c1d2').paired).assertFalse();
    });
  });
}

class LyingSigner {
  private inner: NodeSigner;

  constructor(inner: NodeSigner) {
    this.inner = inner;
  }

  kid(): string {
    return '00000000';
  }

  publicKeySpkiB64(): string {
    return this.inner.publicKeySpkiB64();
  }

  sign(msg: string): Promise<string> {
    return this.inner.sign(msg);
  }
}
