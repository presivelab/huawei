// Watch side: gives an unsigned day packet its place in the chain and signs it with the watch key.
// Pure logic; the key, the hash and the clock come in through the ports.
import { DayPacketCodec, PairPacketCodec } from './DayPacketCodec';
import { parseJsonObject, readBoolean, readInt, readString } from './JsonRead';
import { Clock, Hasher, Signer } from './WatchLinkPorts';
import { ackSigningString, daySigningString, pairSigningString } from './WatchLinkSigning';
import { AckPacket, DayPacket, GENESIS, PACKET_VERSION, PAIR_ALG, PairPacket, TYPE_PAIR } from './WatchLinkTypes';

// state.json on the watch.
export interface WatchChainState {
  kid: string;
  seq: number;        // seq of the last packet put in the outbox; 0 before the first
  lastHash: string;   // hash of that packet; 'GENESIS' before the first
  paired: boolean;
  pairRef: string;    // hash of the last pairing request sent; '' before the first
  phoneKid: string;   // the phone key pinned when the pairing was accepted; '' while not paired
  phonePub: string;
}

export class SealedPair {
  json: string;
  hash: string;

  constructor(json: string, hash: string) {
    this.json = json;
    this.hash = hash;
  }
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
  const state: WatchChainState = {
    kid: kid,
    seq: 0,
    lastHash: GENESIS,
    paired: false,
    pairRef: '',
    phoneKid: '',
    phonePub: ''
  };
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
  // Written before ACKs were signed: no phone key is pinned, so the watch counts as not paired and pairs
  // again. The chain (seq, lastHash) and the outbox stay.
  const pairRef = readString(o, 'pairRef');
  const phoneKid = readString(o, 'phoneKid');
  const phonePub = readString(o, 'phonePub');
  const hasPhone = phoneKid !== null && phonePub !== null && phoneKid.length > 0 && phonePub.length > 0;
  const state: WatchChainState = {
    kid: storedKid,
    seq: seq,
    lastHash: lastHash,
    paired: paired && hasPhone,
    pairRef: pairRef === null ? '' : pairRef,
    phoneKid: hasPhone && phoneKid !== null ? phoneKid : '',
    phonePub: hasPhone && phonePub !== null ? phonePub : ''
  };
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
    const p = await PacketSealer.signedPair(signer, clock);
    return PairPacketCodec.toJson(p);
  }

  // The pairing request and its hash: the phone's answer has to carry this hash as `ref`.
  static async sealPair(signer: Signer, hasher: Hasher, clock: Clock): Promise<SealedPair> {
    const p = await PacketSealer.signedPair(signer, clock);
    const hash = await hasher.sha256B64url(pairSigningString(p));
    return new SealedPair(PairPacketCodec.toJson(p), hash);
  }

  // Phone side: signs an ACK with the phone's Watch Link key. kid and public key come from the signer.
  static async sealAck(ack: AckPacket, signer: Signer): Promise<AckPacket> {
    ack.phoneKid = signer.kid();
    ack.phonePub = signer.publicKeySpkiB64();
    ack.sig = '';
    ack.sig = await signer.sign(ackSigningString(ack));
    return ack;
  }

  private static async signedPair(signer: Signer, clock: Clock): Promise<PairPacket> {
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
    return p;
  }
}
