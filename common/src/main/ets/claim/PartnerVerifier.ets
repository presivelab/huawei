import { TierClaim } from '../model/types';
import { b64urlEncode } from '../platform/Bytes';
import { Clock, SigVerifier } from '../watchlink/WatchLinkPorts';
import { validateSignedClaim } from './ClaimValidation';
import { decodeSignedClaimToken } from './SignedClaimToken';

/*
 * The partner side (S4): issues nonces, keeps the key registry and verifies a received token.
 * Pure logic: randomness, time and the signature check come in through ports, so the same code runs
 * on the device and under Node. Nothing is logged here: nonces, tokens and keys stay out of the log.
 */

/** Random bytes from a cryptographically secure source. Math.random must never stand behind this. */
export interface RandomSource {
  randomBytes(count: number): Promise<Uint8Array>;
}

export const STATUS_INVALID_FORMAT: string = 'Invalid format';
export const STATUS_UNKNOWN_KEY: string = 'Unknown key';
export const STATUS_INVALID_SIGNATURE: string = 'Invalid signature';
export const STATUS_NONCE_MISMATCH: string = 'Nonce mismatch';
export const STATUS_ALREADY_USED: string = 'Already used';
export const STATUS_VALID: string = 'Signature valid';

/** The fixed order of the checks; the index plus one is the step a result stops at. */
export const VERIFY_STEPS: string[] = [
  STATUS_INVALID_FORMAT,
  STATUS_UNKNOWN_KEY,
  STATUS_INVALID_SIGNATURE,
  STATUS_NONCE_MISMATCH,
  STATUS_ALREADY_USED,
  STATUS_VALID
];

export const NONCE_BYTES: number = 16;
export const NONCE_TTL_MS: number = 10 * 60 * 1000;
/** Upper bound on nonces waiting for a token; the oldest unused one is dropped first. */
export const MAX_OUTSTANDING_NONCES: number = 512;
/**
 * Used nonces are kept apart from the waiting ones, so issuing new nonces never removes one. Above this
 * count the used nonces whose time limit has passed are dropped, oldest first; one still inside its time
 * limit is never dropped, so a replay within the limit always reads "Already used".
 */
export const MAX_USED_NONCES: number = 512;

export class PartnerKey {
  kid: string;
  publicKeyDer: Uint8Array;
  /** 'HUKS' or 'SOFTWARE', recorded when the user agreed to share. This is what the partner shows. */
  source: string;

  constructor(kid: string, publicKeyDer: Uint8Array, source: string) {
    this.kid = kid;
    this.publicKeyDer = publicKeyDer;
    this.source = source;
  }
}

export class VerifyResult {
  /** One of VERIFY_STEPS. */
  status: string = STATUS_INVALID_FORMAT;
  /** 1 to 6: the check where the run stopped, in the order of VERIFY_STEPS. 6 means every check passed. */
  step: number = 1;
  ok: boolean = false;
  /** The key source from the registry; empty while the key is unknown. Never taken from the token. */
  keySource: string = '';
  /** The claim, set only once its signature has verified (steps 4 to 6). */
  claim: TierClaim | null = null;
}

function sameBytes(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) {
    return false;
  }
  for (let i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) {
      return false;
    }
  }
  return true;
}

export class PartnerVerifier {
  private random: RandomSource;
  private clock: Clock;
  private sigVerifier: SigVerifier;
  private keys: Map<string, PartnerKey> = new Map<string, PartnerKey>();
  // Nonces waiting for a token and nonces a token has used, each with the time it was issued.
  private nonces: Map<string, number> = new Map<string, number>();
  private used: Map<string, number> = new Map<string, number>();

  constructor(random: RandomSource, clock: Clock, sigVerifier: SigVerifier) {
    this.random = random;
    this.clock = clock;
    this.sigVerifier = sigVerifier;
  }

  /**
   * Registers a key. Call it when the user agrees to share. The same key under the same kid may be
   * registered again. A different key under a kid that is already taken is refused and the registered key
   * stays: a key is never replaced silently. Returns whether the key is now the registered one.
   */
  registerKey(kid: string, publicKeyDer: Uint8Array, source: string): boolean {
    const have = this.keys.get(kid);
    if (have !== undefined && !sameBytes(have.publicKeyDer, publicKeyDer)) {
      return false;
    }
    this.keys.set(kid, new PartnerKey(kid, publicKeyDer, source));
    return true;
  }

  /** Empties the registry; the software key changes on every app start, so it is rebuilt each session. */
  clearKeys(): void {
    this.keys.clear();
  }

  /** The partner's own nonce: 16 random bytes as 22 base64url characters, valid for 10 minutes. */
  async issueNonce(): Promise<string> {
    const bytes = await this.random.randomBytes(NONCE_BYTES);
    const nonce = b64urlEncode(bytes);
    const now = this.clock.nowMs();
    this.dropExpired(now);
    while (this.nonces.size >= MAX_OUTSTANDING_NONCES) {
      const oldest = this.nonces.keys().next();
      if (oldest.done === true) {
        break;
      }
      this.nonces.delete(oldest.value);
    }
    this.nonces.set(nonce, now);
    return nonce;
  }

  async verify(token: string): Promise<VerifyResult> {
    const result = new VerifyResult();
    const now = this.clock.nowMs();

    // Step 1: format. Everything is checked before any key lookup.
    const signed = decodeSignedClaimToken(token);
    const claim = signed === null ? null : validateSignedClaim(signed, now);
    if (signed === null || claim === null) {
      return this.stop(result, 1);
    }

    // Step 2: the key comes from the registry, by kid.
    const key = this.keys.get(signed.kid);
    if (key === undefined) {
      return this.stop(result, 2);
    }
    result.keySource = key.source;

    // Step 3: the signature over the exact claim text.
    const good = await this.sigVerifier.verify(b64urlEncode(key.publicKeyDer), signed.claimJson, signed.sigB64);
    if (!good) {
      return this.stop(result, 3);
    }
    result.claim = claim;

    // Step 4: the nonce must be one this partner issued, and still inside its time limit unless it has
    // been used already (a used nonce stays on record so that a replay reports "Already used").
    const wasUsed = this.used.has(claim.nonce);
    const issuedAtMs = this.nonces.get(claim.nonce);
    if (!wasUsed && (issuedAtMs === undefined || now - issuedAtMs > NONCE_TTL_MS)) {
      return this.stop(result, 4);
    }

    // Step 5: replays are recognised by nonce, never by signature bytes.
    if (wasUsed || issuedAtMs === undefined) {
      return this.stop(result, 5);
    }
    this.nonces.delete(claim.nonce);
    this.rememberUsed(claim.nonce, issuedAtMs, now);
    return this.stop(result, 6);
  }

  // Moves a nonce to the used ones. Over the limit, used nonces past their time limit go, oldest first.
  private rememberUsed(nonce: string, issuedAtMs: number, now: number): void {
    if (this.used.size >= MAX_USED_NONCES) {
      const stale: string[] = [];
      this.used.forEach((issued: number, key: string) => {
        if (now - issued > NONCE_TTL_MS) {
          stale.push(key);
        }
      });
      for (let i = 0; i < stale.length && this.used.size >= MAX_USED_NONCES; i++) {
        this.used.delete(stale[i]);
      }
    }
    this.used.set(nonce, issuedAtMs);
  }

  private stop(result: VerifyResult, step: number): VerifyResult {
    result.step = step;
    result.status = VERIFY_STEPS[step - 1];
    result.ok = step === VERIFY_STEPS.length;
    return result;
  }

  private dropExpired(now: number): void {
    const stale: string[] = [];
    this.nonces.forEach((issuedAtMs: number, key: string) => {
      if (now - issuedAtMs > NONCE_TTL_MS) {
        stale.push(key);
      }
    });
    for (let i = 0; i < stale.length; i++) {
      this.nonces.delete(stale[i]);
    }
  }
}
