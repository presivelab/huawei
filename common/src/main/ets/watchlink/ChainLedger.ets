// The phone's record of one pinned watch: its key and the chain of day packets accepted from it.
// Each packet carries seq and the hash of the packet before it, so a deleted or edited day shows up
// as a gap or a conflict. Pure logic; the caller stores toJson() and restores with fromJson().
import { asObject, parseJsonObject, readArray, readInt, readIntArray, readString } from './JsonRead';
import { dayNumberOfDate, GENESIS } from './WatchLinkTypes';

export type ChainKind = 'NEXT' | 'GAP' | 'FILL' | 'DUPLICATE' | 'CONFLICT' | 'TOO_FAR';

const LEDGER_VERSION: number = 1;
// Accepted packets remembered for duplicate and conflict checks.
const MAX_ENTRIES: number = 400;
const MAX_SEQ: number = 2147483647;
// The most packets one packet may skip. The watch keeps at most 30 packets, so a real gap is the days the
// phone did not hear from it; more than this is not a gap but a broken or hostile seq, and is refused
// before a list of missing days is built for it.
export const MAX_GAP: number = 400;

export interface ChainEntry {
  seq: number;
  hash: string;
  prev: string;
  date: string;
}

export class ChainCheck {
  kind: ChainKind = 'CONFLICT';
  // For GAP: the sequence numbers skipped by this packet.
  missing: number[] = [];
  // Dates this packet has to lie strictly between (one packet per day); '' when there is no bound on that side.
  notBefore: string = '';
  notAfter: string = '';
}

class LedgerFile {
  v: number = LEDGER_VERSION;
  kid: string = '';
  pubB64: string = '';
  lastSeq: number = 0;
  lastHash: string = GENESIS;
  lastDate: string = '';
  missingSeqs: number[] = [];
  entries: ChainEntry[] = [];
}

export class ChainLedger {
  kid: string;
  pubB64: string;
  lastSeq: number = 0;
  lastHash: string = GENESIS;
  lastDate: string = '';
  missingSeqs: number[] = [];
  private entries: ChainEntry[] = [];   // ascending seq

  constructor(kid: string, pubB64: string) {
    this.kid = kid;
    this.pubB64 = pubB64;
  }

  entry(seq: number): ChainEntry | null {
    for (let i = 0; i < this.entries.length; i++) {
      if (this.entries[i].seq === seq) {
        return this.entries[i];
      }
    }
    return null;
  }

  isMissing(seq: number): boolean {
    return this.missingSeqs.indexOf(seq) >= 0;
  }

  acceptedCount(): number {
    return this.entries.length;
  }

  // Where a packet with this seq / prev / hash fits. Nothing is changed.
  check(seq: number, prev: string, hash: string): ChainCheck {
    const out = new ChainCheck();
    if (seq > this.lastSeq) {
      out.notBefore = this.lastDate;
      if (seq === this.lastSeq + 1) {
        // The very first packet of a chain has to say GENESIS; every other one the hash before it.
        out.kind = prev === this.lastHash ? 'NEXT' : 'CONFLICT';
        return out;
      }
      if (seq - this.lastSeq - 1 > MAX_GAP) {
        out.kind = 'TOO_FAR';
        return out;
      }
      for (let s = this.lastSeq + 1; s < seq; s++) {
        out.missing.push(s);
      }
      out.kind = 'GAP';
      return out;
    }
    const known = this.entry(seq);
    if (known !== null) {
      out.kind = known.hash === hash ? 'DUPLICATE' : 'CONFLICT';
      return out;
    }
    if (!this.isMissing(seq)) {
      return out;
    }
    // A day recorded as missing arrives late. It has to link to both neighbours we know.
    const before = this.entry(seq - 1);
    const after = this.entry(seq + 1);
    if (seq === 1 && prev !== GENESIS) {
      return out;
    }
    if (before !== null && prev !== before.hash) {
      return out;
    }
    if (after !== null && after.prev !== hash) {
      return out;
    }
    for (let i = 0; i < this.entries.length; i++) {
      const e = this.entries[i];
      if (e.seq < seq) {
        out.notBefore = e.date;
      } else if (out.notAfter.length === 0) {
        out.notAfter = e.date;
      }
    }
    out.kind = 'FILL';
    return out;
  }

  // Records an accepted packet. Call only after check() said NEXT, GAP or FILL (never TOO_FAR).
  commit(seq: number, prev: string, hash: string, date: string): void {
    const added: ChainEntry = { seq: seq, hash: hash, prev: prev, date: date };
    if (seq > this.lastSeq) {
      for (let s = this.lastSeq + 1; s < seq; s++) {
        this.missingSeqs.push(s);
      }
      this.lastSeq = seq;
      this.lastHash = hash;
      this.lastDate = date;
      this.entries.push(added);
    } else {
      const at = this.missingSeqs.indexOf(seq);
      if (at >= 0) {
        this.missingSeqs.splice(at, 1);
      }
      let insertAt = this.entries.length;
      for (let i = 0; i < this.entries.length; i++) {
        if (this.entries[i].seq > seq) {
          insertAt = i;
          break;
        }
      }
      this.entries.splice(insertAt, 0, added);
    }
    while (this.entries.length > MAX_ENTRIES) {
      this.entries.shift();
    }
  }

  toJson(): string {
    const file = new LedgerFile();
    file.kid = this.kid;
    file.pubB64 = this.pubB64;
    file.lastSeq = this.lastSeq;
    file.lastHash = this.lastHash;
    file.lastDate = this.lastDate;
    file.missingSeqs = this.missingSeqs;
    file.entries = this.entries;
    return JSON.stringify(file);
  }

  // Null for anything that is not a complete ledger: a damaged ledger is not half-trusted.
  static fromJson(text: string): ChainLedger | null {
    const o = parseJsonObject(text);
    if (o === null) {
      return null;
    }
    const v = readInt(o, 'v');
    const kid = readString(o, 'kid');
    const pubB64 = readString(o, 'pubB64');
    const lastSeq = readInt(o, 'lastSeq');
    const lastHash = readString(o, 'lastHash');
    const lastDate = readString(o, 'lastDate');
    const missingSeqs = readIntArray(o, 'missingSeqs', 1, MAX_SEQ);
    const rawEntries = readArray(o, 'entries');
    if (v !== LEDGER_VERSION || kid === null || pubB64 === null || lastSeq === null || lastHash === null ||
      lastDate === null || missingSeqs === null || rawEntries === null || lastSeq < 0) {
      return null;
    }
    const ledger = new ChainLedger(kid, pubB64);
    ledger.lastSeq = lastSeq;
    ledger.lastHash = lastHash;
    ledger.lastDate = lastDate;
    ledger.missingSeqs = missingSeqs;
    for (let i = 0; i < rawEntries.length; i++) {
      const e = asObject(rawEntries[i]);
      if (e === null) {
        return null;
      }
      const seq = readInt(e, 'seq');
      const hash = readString(e, 'hash');
      const prev = readString(e, 'prev');
      const date = readString(e, 'date');
      if (seq === null || hash === null || prev === null || date === null || dayNumberOfDate(date) < 0) {
        return null;
      }
      const entry: ChainEntry = { seq: seq, hash: hash, prev: prev, date: date };
      ledger.entries.push(entry);
    }
    return ledger;
  }
}
