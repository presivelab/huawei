import { SignedClaim, TierClaim } from '../model/types';
import { b64urlDecode } from '../platform/Bytes';
import { decodeTierClaim, encodeTierClaim, TIER_CLAIM_VERSION } from './TierClaimCodec';

/*
 * Hardened decode (S3). Everything a partner receives is untrusted, so every check here runs before the
 * key lookup and before any signature work. One failure of any kind means "Invalid format".
 * The claim bytes are never trusted as parsed: the decoded claim is encoded again and must equal the
 * received text exactly, which also rejects repeated keys, white space and a different key order.
 */

export const MAX_CLAIM_JSON_CHARS: number = 256;
export const MAX_TOKEN_CHARS: number = 512;
/** A DER ECDSA P-256 signature is at most 72 bytes (two 33-byte integers plus the headers). */
export const MAX_DER_SIGNATURE_BYTES: number = 72;
/** A claim stamped further ahead than this is refused (clock skew between phone and partner). */
export const MAX_FUTURE_SKEW_MS: number = 5 * 60 * 1000;

export const KEY_SOURCE_HUKS: string = 'HUKS';
export const KEY_SOURCE_SOFTWARE: string = 'SOFTWARE';

export const TIER_A: string = 'A';
export const TIER_B: string = 'B';
export const TIER_C: string = 'C';
/*
 * The value of `tier` when the scoring module has no score ("No score yet"). The repository has no
 * scoring module yet, so this value is not defined anywhere else: it is a placeholder that must be
 * aligned with HES-Lite when that module arrives. A claim with this tier can never be eligible.
 */
export const TIER_NO_SCORE: string = 'NONE';
export const CLAIM_TIERS: string[] = [TIER_A, TIER_B, TIER_C, TIER_NO_SCORE];

// Period as the repo writes it: first and last day of the window, e.g. 2026-09-03..2026-10-02.
const PERIOD_PATTERN: RegExp = new RegExp('^\\d{4}-\\d{2}-\\d{2}\\.\\.\\d{4}-\\d{2}-\\d{2}$');
const NONCE_PATTERN: RegExp = new RegExp('^[A-Za-z0-9_-]{22}$');
const KID_PATTERN: RegExp = new RegExp('^[0-9a-f]{8}$');
const B64URL_PATTERN: RegExp = new RegExp('^[A-Za-z0-9_-]+$');

export function isValidNonceText(nonce: string): boolean {
  return NONCE_PATTERN.test(nonce);
}

export function isValidKidText(kid: string): boolean {
  return KID_PATTERN.test(kid);
}

export function isValidKeySource(source: string): boolean {
  return source === KEY_SOURCE_HUKS || source === KEY_SOURCE_SOFTWARE;
}

/** True for strict base64url (no padding, no '+' or '/'); the DER length limit is checked as well. */
export function isValidSignatureText(sigB64: string): boolean {
  if (sigB64.length === 0 || sigB64.length > 100 || !B64URL_PATTERN.test(sigB64)) {
    return false;
  }
  if (sigB64.length % 4 === 1) {
    return false;
  }
  try {
    const der = b64urlDecode(sigB64);
    return der.length >= 8 && der.length <= MAX_DER_SIGNATURE_BYTES && der[0] === 0x30;
  } catch (e) {
    return false;
  }
}

/**
 * The claim inside `claimJson`, or null when anything is off. `nowMs` is the verifier's clock.
 * Never throws.
 */
export function validateTierClaimJson(claimJson: string, nowMs: number): TierClaim | null {
  if (claimJson.length === 0 || claimJson.length > MAX_CLAIM_JSON_CHARS) {
    return null;
  }
  const claim = decodeTierClaim(claimJson);
  if (claim === null) {
    return null;
  }
  if (encodeTierClaim(claim) !== claimJson) {
    return null;
  }
  if (claim.v !== TIER_CLAIM_VERSION) {
    return null;
  }
  if (CLAIM_TIERS.indexOf(claim.tier) < 0) {
    return null;
  }
  if (!PERIOD_PATTERN.test(claim.period)) {
    return null;
  }
  if (!NONCE_PATTERN.test(claim.nonce) || !KID_PATTERN.test(claim.kid)) {
    return null;
  }
  if (!Number.isSafeInteger(claim.issuedAt) || claim.issuedAt <= 0 || claim.issuedAt > nowMs + MAX_FUTURE_SKEW_MS) {
    return null;
  }
  if (claim.eligible && claim.tier === TIER_NO_SCORE) {
    return null;
  }
  return claim;
}

/** The claim of a received SignedClaim, or null. Checks the envelope and then the claim itself. */
export function validateSignedClaim(signed: SignedClaim, nowMs: number): TierClaim | null {
  if (!isValidKidText(signed.kid) || !isValidKeySource(signed.keySource) || !isValidSignatureText(signed.sigB64)) {
    return null;
  }
  const claim = validateTierClaimJson(signed.claimJson, nowMs);
  if (claim === null || claim.kid !== signed.kid) {
    return null;
  }
  return claim;
}
