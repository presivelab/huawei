import { MAX_OUTSTANDING_NONCES, NONCE_BYTES, NONCE_TTL_MS, PartnerKey, RandomSource } from '../claim/PartnerVerifier';
import { CheckRow, CheckState } from '../claim/ShareFlow';
import { decodeSignedClaimToken } from '../claim/SignedClaimToken';
import { b64urlEncode } from '../platform/Bytes';
import { Clock, SigVerifier } from '../watchlink/WatchLinkPorts';
import { decodeVisitToken, validateVisitClaimJson, VisitClaim } from './VisitClaim';

/*
 * The partner side for visit claims. A class of its own, next to PartnerVerifier and built the same way:
 * randomness, time and the signature check come in through the same ports, the key is looked up by kid in
 * the partner's own registry, and nothing is logged. PartnerVerifier and the tier claim are not touched.
 *
 * Two things are added to the checks of a tier claim: the token must be a visit token (a tier token is
 * refused by name), and one receipt is accepted once, however many tokens are made from it.
 */

export const VISIT_STATUS_INVALID_FORMAT: string = 'Invalid format';
export const VISIT_STATUS_WRONG_TYPE: string = 'Wrong claim type';
export const VISIT_STATUS_UNKNOWN_KEY: string = 'Unknown key';
export const VISIT_STATUS_INVALID_SIGNATURE: string = 'Invalid signature';
export const VISIT_STATUS_NONCE_MISMATCH: string = 'Nonce mismatch';
export const VISIT_STATUS_ALREADY_USED: string = 'Already used';
export const VISIT_STATUS_RECEIPT_CLAIMED: string = 'Receipt already claimed';
export const VISIT_STATUS_VALID: string = 'Signature valid';

/** The fixed order of the checks; the index plus one is the step a result stops at. */
export const VISIT_VERIFY_STEPS: string[] = [
  VISIT_STATUS_INVALID_FORMAT,
  VISIT_STATUS_WRONG_TYPE,
  VISIT_STATUS_UNKNOWN_KEY,
  VISIT_STATUS_INVALID_SIGNATURE,
  VISIT_STATUS_NONCE_MISMATCH,
  VISIT_STATUS_ALREADY_USED,
  VISIT_STATUS_RECEIPT_CLAIMED,
  VISIT_STATUS_VALID
];

export class VisitVerifyResult {
  /** One of VISIT_VERIFY_STEPS. */
  status: string = VISIT_STATUS_INVALID_FORMAT;
  /** 1 to 8: the check where the run stopped. 8 means every check passed. */
  step: number = 1;
  ok: boolean = false;
  /** The key source from the registry; empty while the key is unknown. Never taken from the token. */
  keySource: string = '';
  /** The claim, set only once its signature has verified (steps 5 to 8). */
  claim: VisitClaim | null = null;
}

class IssuedVisitNonce {
  issuedAtMs: number;
  used: boolean = false;

  constructor(issuedAtMs: number) {
    this.issuedAtMs = issuedAtMs;
  }
}

export class VisitVerifier {
  private random: RandomSource;
  private clock: Clock;
  private sigVerifier: SigVerifier;
  private keys: Map<string, PartnerKey> = new Map<string, PartnerKey>();
  private nonces: Map<string, IssuedVisitNonce> = new Map<string, IssuedVisitNonce>();
  private claimedReceipts: Set<string> = new Set<string>();

  constructor(random: RandomSource, clock: Clock, sigVerifier: SigVerifier) {
    this.random = random;
    this.clock = clock;
    this.sigVerifier = sigVerifier;
  }

  /** Registers a key (or replaces the key with the same kid). Call it when the user agrees to share. */
  registerKey(kid: string, publicKeyDer: Uint8Array, source: string): void {
    this.keys.set(kid, new PartnerKey(kid, publicKeyDer, source));
  }

  clearKeys(): void {
    this.keys.clear();
  }

  /** Forgets every issued nonce and every accepted receipt: the demo starts again. Keys stay. */
  reset(): void {
    this.nonces.clear();
    this.claimedReceipts.clear();
  }

  /** True once a claim made from this receipt has been accepted. */
  isReceiptClaimed(receiptRef: string): boolean {
    return this.claimedReceipts.has(receiptRef);
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
    this.nonces.set(nonce, new IssuedVisitNonce(now));
    return nonce;
  }

  async verify(token: string): Promise<VisitVerifyResult> {
    const result = new VisitVerifyResult();
    const now = this.clock.nowMs();

    // Steps 1 and 2: the shape of the token, then its kind. A well-formed tier token is the wrong kind;
    // everything else that is not a well-formed visit token is the wrong format.
    const signed = decodeVisitToken(token);
    if (signed === null) {
      return this.stop(result, decodeSignedClaimToken(token) === null ? 1 : 2);
    }
    const claim = validateVisitClaimJson(signed.claimJson, now);
    if (claim === null || claim.kid !== signed.kid) {
      return this.stop(result, 1);
    }

    // Step 3: the key comes from the registry, by kid.
    const key = this.keys.get(signed.kid);
    if (key === undefined) {
      return this.stop(result, 3);
    }
    result.keySource = key.source;

    // Step 4: the signature over the exact claim text.
    const good = await this.sigVerifier.verify(b64urlEncode(key.publicKeyDer), signed.claimJson, signed.sigB64);
    if (!good) {
      return this.stop(result, 4);
    }
    result.claim = claim;

    // Step 5: the nonce must be one this partner issued, and still inside its time limit unless it has
    // been used already (a used nonce stays on record so that a replay reports "Already used").
    const issued = this.nonces.get(claim.nonce);
    if (issued === undefined || (!issued.used && now - issued.issuedAtMs > NONCE_TTL_MS)) {
      return this.stop(result, 5);
    }

    // Step 6: replays are recognised by nonce, never by signature bytes.
    if (issued.used) {
      return this.stop(result, 6);
    }

    // Step 7: one receipt is accepted once. A fresh token from a receipt that was already accepted has
    // a new nonce and a good signature, and is still refused here.
    if (this.claimedReceipts.has(claim.receiptRef)) {
      return this.stop(result, 7);
    }

    issued.used = true;
    this.claimedReceipts.add(claim.receiptRef);
    return this.stop(result, 8);
  }

  private stop(result: VisitVerifyResult, step: number): VisitVerifyResult {
    result.step = step;
    result.status = VISIT_VERIFY_STEPS[step - 1];
    result.ok = step === VISIT_VERIFY_STEPS.length;
    return result;
  }

  private dropExpired(now: number): void {
    const stale: string[] = [];
    this.nonces.forEach((value: IssuedVisitNonce, key: string) => {
      if (!value.used && now - value.issuedAtMs > NONCE_TTL_MS) {
        stale.push(key);
      }
    });
    for (let i = 0; i < stale.length; i++) {
      this.nonces.delete(stale[i]);
    }
  }
}

/** The seven checks of the partner, in the order VisitVerifier runs them. */
export const VISIT_CHECK_LABELS: string[] = [
  'Format',
  'Claim type: visit',
  'Known key',
  'Signature over the exact claim',
  'Nonce issued by this partner, not expired',
  'Not used before',
  'Receipt not claimed before'
];

const VISIT_STOP_NAMES: string[] =
  ['format', 'claim type', 'known key', 'signature', 'nonce', 'not used before', 'receipt not claimed before'];

/** One row per check: passed before the stop, failed at the stop, not run after it. */
export function visitCheckRows(result: VisitVerifyResult): CheckRow[] {
  const rows: CheckRow[] = [];
  for (let i = 0; i < VISIT_CHECK_LABELS.length; i++) {
    const step = i + 1;
    let state = CheckState.NOT_RUN;
    if (result.ok || step < result.step) {
      state = CheckState.PASSED;
    } else if (step === result.step) {
      state = CheckState.FAILED;
    }
    const row: CheckRow = { label: VISIT_CHECK_LABELS[i], state: state };
    rows.push(row);
  }
  return rows;
}

/** "Invalid signature · stopped at: signature", or the status alone for a valid result. */
export function visitVerdictLine(result: VisitVerifyResult): string {
  if (result.ok || result.step < 1 || result.step >= VISIT_VERIFY_STEPS.length) {
    return result.status;
  }
  return `${result.status} · stopped at: ${VISIT_STOP_NAMES[result.step - 1]}`;
}
