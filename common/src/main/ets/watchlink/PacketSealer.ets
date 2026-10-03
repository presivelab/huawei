// Watch side: gives an unsigned day packet its place in the chain and signs it with the watch key.
// Pure logic; the key, the hash and the clock come in through the ports.
import { DayPacketCodec, PairPacketCodec } from './DayPacketCodec';
import { parseJsonObject, readBoolean, readInt, readString } from './JsonRead';
import { Clock, Hasher, Signer } from './WatchLinkPorts';
import { daySigningString, pairSigningString } from './WatchLinkSigning';
import { DayPacket, GENESIS, PACKET_VERSION, PAIR_ALG, PairPacket, TYPE_PAIR } from './WatchLinkTypes';

// state.json on the watch.
export interface WatchChainState {
  kid: string;
  seq: number;        // seq of the last packet put in the outbox; 0 before the first
  lastHash: string;   // hash of that packet; 'GENESIS' before the first
  paired: boolean;
}

export class SealedDay {
  packet: DayPacket;
  hash: string;
  json: string;

  constructor(packet: DayPacket, hash: string, json: string) {
    this.packet = packet;
    this.hash = hash;
    this.json = json;
  }
}

export function newChainState(kid: string): WatchChainState {
  const state: WatchChainState = { kid: kid, seq: 0, lastHash: GENESIS, paired: false };
  return state;
}

export function chainStateToJson(state: WatchChainState): string {
  return JSON.stringify(state);
}

// The stored state, or a fresh chain when there is none, it is damaged, or it belongs to another key.
// A new key means a new chain: packets signed by the old key cannot be continued.
export function chainStateFromJson(text: string | null, kid: string): WatchChainState {
  if (text === null) {
    return newChainState(kid);
  }
  const o = parseJsonObject(text);
  if (o === null) {
    return newChainState(kid);
  }
  const storedKid = readString(o, 'kid');
  const seq = readInt(o, 'seq');
  const lastHash = readString(o, 'lastHash');
  const paired = readBoolean(o, 'paired');
  if (storedKid === null || seq === null || lastHash === null || paired === null || seq < 0 || storedKid !== kid) {
    return newChainState(kid);
  }
  const state: WatchChainState = { kid: storedKid, seq: seq, lastHash: lastHash, paired: paired };
  return state;
}

export class PacketSealer {
  // Returns the signed packet with seq = state.seq + 1 and prev = state.lastHash. The state is not
  // changed here: the caller advances it (seq, lastHash) once the packet is safely in the outbox.
  static async sealDay(unsigned: DayPacket, state: WatchChainState, signer: Signer, hasher: Hasher,
    clock: Clock): Promise<SealedDay> {
    const p: DayPacket = {
      v: unsigned.v,
      type: unsigned.type,
      kid: signer.kid(),
      seq: state.seq + 1,
      prev: state.lastHash,
      date: unsigned.date,
      tzOffsetMin: unsigned.tzOffsetMin,
      slots: unsigned.slots,
      stepsByHour: unsigned.stepsByHour,
      hrRestEst: unsigned.hrRestEst,
      hrSlotCount: unsigned.hrSlotCount,
      nightWornMin: unsigned.nightWornMin,
      nightChargingMin: unsigned.nightChargingMin,
      breaks: unsigned.breaks,
      wearSource: unsigned.wearSource,
      clock: unsigned.clock,
      iat: Math.floor(clock.nowMs() / 1000),
      sig: ''
    };
    const signed = daySigningString(p);
    p.sig = await signer.sign(signed);
    const hash = await hasher.sha256B64url(signed);
    return new SealedDay(p, hash, DayPacketCodec.toJson(p));
  }

  // The self-signed pairing request: the watch's public key and its key id.
  static async makePair(signer: Signer, clock: Clock): Promise<string> {
    const p: PairPacket = {
      v: PACKET_VERSION,
      type: TYPE_PAIR,
      kid: signer.kid(),
      pub: signer.publicKeySpkiB64(),
      alg: PAIR_ALG,
      iat: Math.floor(clock.nowMs() / 1000),
      sig: ''
    };
    p.sig = await signer.sign(pairSigningString(p));
    return PairPacketCodec.toJson(p);
  }
}
