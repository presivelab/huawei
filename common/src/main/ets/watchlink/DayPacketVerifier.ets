// Phone side: decides whether a packet from the watch is taken in. Fixed order, fixed messages,
// in the style of the claim verifier: format, version, key, signature, chain, date.
// This checks where a packet comes from and that it is intact. It says nothing about the day itself.
import { ChainLedger, MAX_GAP } from './ChainLedger';
import { DayPacketCodec, PairPacketCodec } from './DayPacketCodec';
import { Clock, Hasher, SigVerifier } from './WatchLinkPorts';
import { ackSigningString, daySigningString, pairSigningString } from './WatchLinkSigning';
import {
  AckPacket,
  AckStatus,
  CLOCK_REAL,
  dateOfDayNumber,
  DayPacket,
  localDayNumber,
  PairPacket
} from './WatchLinkTypes';

export const MSG_INVALID_FORMAT: string = 'Invalid format';
export const MSG_UNSUPPORTED_VERSION: string = 'Unsupported version';
export const MSG_UNKNOWN_KEY: string = 'Unknown watch key';
export const MSG_INVALID_SIGNATURE: string = 'Invalid signature';
export const MSG_DUPLICATE: string = 'Duplicate day';
export const MSG_CHAIN_CONFLICT: string = 'Chain conflict';
export const MSG_DATE_FUTURE: string = 'Date in the future';
export const MSG_DATE_ORDER: string = 'Date out of order';
export const MSG_DEMO_CLOCK: string = 'Demo clock not accepted';
export const MSG_ACCEPTED: string = 'Accepted';
export const MSG_KEY_ID_MISMATCH: string = 'Key id mismatch';
export const MSG_PAIR_VALID: string = 'Pairing request valid';
export const MSG_SEQ_JUMP: string = `Sequence jump over ${MAX_GAP}`;

export function missingDaysNote(count: number): string {
  return `Missing ${count} day(s)`;
}

export class VerifyOutcome {
  status: AckStatus = 'REJECTED';
  message: string = MSG_INVALID_FORMAT;
  detail: string = '';
  // Set as soon as the packet decoded, also when it is rejected later (the ACK needs its seq).
  packet: DayPacket | null = null;
  hash: string = '';
  // Sequence numbers this packet skipped; 'Missing N day(s)' is in `note` then.
  newlyMissing: number[] = [];
  // True when the packet is a day that had been recorded as missing.
  filledMissing: boolean = false;
  note: string = '';
}

export class PairOutcome {
  ok: boolean = false;
  message: string = MSG_INVALID_FORMAT;
  packet: PairPacket | null = null;
}

export class DayPacketVerifier {
  private verifier: SigVerifier;
  private hasher: Hasher;
  private clock: Clock;
  private allowDemoClock: boolean;

  // allowDemoClock: packets recorded on the watch's demo clock carry simulated dates, so the "not in the
  // future" check cannot apply to them. Refused by default; only a demo build passes true (and labels them).
  constructor(verifier: SigVerifier, hasher: Hasher, clock: Clock, allowDemoClock: boolean = false) {
    this.verifier = verifier;
    this.hasher = hasher;
    this.clock = clock;
    this.allowDemoClock = allowDemoClock;
  }

  // `ledger` is the pinned watch, or null when no watch is paired. With `commit` an accepted packet is
  // committed to the ledger at once; without it the caller commits (PhoneLinkEngine does, after the day
  // file is written, so a failed write never leaves a day the chain counts but the phone does not have).
  async verify(json: string, ledger: ChainLedger | null, commit: boolean = true): Promise<VerifyOutcome> {
    const out = new VerifyOutcome();

    // 1, 2: format and version
    const decoded = DayPacketCodec.fromJson(json);
    const p = decoded.packet;
    if (decoded.code !== 'OK' || p === null) {
      out.message = decoded.code === 'VERSION' ? MSG_UNSUPPORTED_VERSION : MSG_INVALID_FORMAT;
      out.detail = decoded.reason;
      return out;
    }
    out.packet = p;

    // 3: the key has to be the pinned one
    if (ledger === null || ledger.kid !== p.kid) {
      out.message = MSG_UNKNOWN_KEY;
      return out;
    }

    // 4: signature over the signing string
    const signed = daySigningString(p);
    const sigOk = await this.verifier.verify(ledger.pubB64, signed, p.sig);
    if (!sigOk) {
      out.message = MSG_INVALID_SIGNATURE;
      return out;
    }
    const hash = await this.hasher.sha256B64url(signed);
    out.hash = hash;

    // 5: chain
    const chain = ledger.check(p.seq, p.prev, hash);
    if (chain.kind === 'DUPLICATE') {
      out.status = 'DUPLICATE';
      out.message = MSG_DUPLICATE;
      return out;
    }
    if (chain.kind === 'CONFLICT') {
      out.message = MSG_CHAIN_CONFLICT;
      return out;
    }
    if (chain.kind === 'TOO_FAR') {
      out.message = MSG_SEQ_JUMP;
      return out;
    }

    // 6: date
    if (p.clock !== CLOCK_REAL) {
      if (!this.allowDemoClock) {
        out.message = MSG_DEMO_CLOCK;
        return out;
      }
    } else {
      const today = dateOfDayNumber(localDayNumber(this.clock.nowMs(), p.tzOffsetMin));
      if (p.date > today) {
        out.message = MSG_DATE_FUTURE;
        return out;
      }
    }
    // One packet per day: a date equal to a neighbour's is out of order too.
    if ((chain.notBefore.length > 0 && p.date <= chain.notBefore) ||
      (chain.notAfter.length > 0 && p.date >= chain.notAfter)) {
      out.message = MSG_DATE_ORDER;
      return out;
    }

    // 7: accepted
    if (commit) {
      ledger.commit(p.seq, p.prev, hash, p.date);
    }
    out.status = 'ACCEPTED';
    out.message = MSG_ACCEPTED;
    if (chain.kind === 'GAP') {
      out.newlyMissing = chain.missing;
      out.note = missingDaysNote(chain.missing.length);
    } else if (chain.kind === 'FILL') {
      out.filledMissing = true;
    }
    return out;
  }
}

export class PairVerifier {
  // Checks a pairing request: format, self-signature, and that kid follows the key-id rule
  // (first 4 bytes of SHA-256 over the public key, the same rule as the phone's kid).
  // A valid request is NOT pinned here: the user confirms the code first.
  static async verify(json: string, verifier: SigVerifier, hasher: Hasher): Promise<PairOutcome> {
    const out = new PairOutcome();
    const decoded = PairPacketCodec.fromJson(json);
    const p = decoded.packet;
    if (decoded.code !== 'OK' || p === null) {
      out.message = decoded.code === 'VERSION' ? MSG_UNSUPPORTED_VERSION : MSG_INVALID_FORMAT;
      return out;
    }
    out.packet = p;
    const sigOk = await verifier.verify(p.pub, pairSigningString(p), p.sig);
    if (!sigOk) {
      out.message = MSG_INVALID_SIGNATURE;
      return out;
    }
    let derived = '';
    try {
      derived = await hasher.keyId(p.pub);
    } catch (e) {
      out.message = MSG_INVALID_FORMAT;
      return out;
    }
    if (derived !== p.kid) {
      out.message = MSG_KEY_ID_MISMATCH;
      return out;
    }
    out.ok = true;
    out.message = MSG_PAIR_VALID;
    return out;
  }
}

export class AckVerifier {
  // Watch side: true when the ACK is signed by the key it names and that key follows the key-id rule.
  // Whether that key is the pinned phone, and whether `ref` matches the packet, is checked by the caller.
  static async verify(ack: AckPacket, verifier: SigVerifier, hasher: Hasher): Promise<boolean> {
    let derived = '';
    try {
      derived = await hasher.keyId(ack.phonePub);
    } catch (e) {
      return false;
    }
    if (derived !== ack.phoneKid) {
      return false;
    }
    return verifier.verify(ack.phonePub, ackSigningString(ack), ack.sig);
  }
}
