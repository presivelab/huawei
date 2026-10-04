import { SignedClaim } from '../model/types';
import { b64urlDecode, b64urlEncode, utf8Decode, utf8Encode } from '../platform/Bytes';
import {
  isValidKeySource,
  isValidKidText,
  isValidSignatureText,
  MAX_CLAIM_JSON_CHARS,
  MAX_TOKEN_CHARS
} from './ClaimValidation';

/*
 * Token format: the text that goes into the QR code.
 *
 *   fw1.<claim>.<sig>.<kid>.<source>
 *
 *   fw1       format marker and version
 *   claim     the canonical claim JSON (the exact signed bytes), UTF-8, base64url without padding
 *   sig       ECDSA P-256 / SHA-256 signature, ASN.1 DER, base64url without padding (at most 72 bytes)
 *   kid       key id, 8 lower-case hex characters
 *   source    HUKS or SOFTWARE (informational: the partner shows the registry's value, not this one)
 *
 * Five fields, four dots, one allowed alphabet per field. The worst case is 461 characters
 * (claim JSON at its 256-character limit gives 342 characters of base64url), under the 512 limit.
 * Decoding is strict: any deviation returns null and nothing is repaired.
 */

export const TOKEN_MARKER: string = 'fw1';
const TOKEN_SEPARATOR: string = '.';
const TOKEN_FIELD_COUNT: number = 5;

export function encodeSignedClaimToken(signed: SignedClaim): string {
  return TOKEN_MARKER + TOKEN_SEPARATOR + b64urlEncode(utf8Encode(signed.claimJson)) + TOKEN_SEPARATOR +
    signed.sigB64 + TOKEN_SEPARATOR + signed.kid + TOKEN_SEPARATOR + signed.keySource;
}

/** The structure of a token, or null. Syntax only: the claim itself is validated by validateSignedClaim. */
export function decodeSignedClaimToken(token: string): SignedClaim | null {
  if (token.length === 0 || token.length > MAX_TOKEN_CHARS) {
    return null;
  }
  const parts = token.split(TOKEN_SEPARATOR);
  if (parts.length !== TOKEN_FIELD_COUNT || parts[0] !== TOKEN_MARKER) {
    return null;
  }
  const claimB64 = parts[1];
  const sigB64 = parts[2];
  const kid = parts[3];
  const source = parts[4];
  if (claimB64.length === 0 || claimB64.length > 342 || !isValidKidText(kid) || !isValidKeySource(source) ||
    !isValidSignatureText(sigB64)) {
    return null;
  }
  let claimJson: string;
  try {
    const bytes = b64urlDecode(claimB64);
    if (b64urlEncode(bytes) !== claimB64) {
      return null;
    }
    claimJson = utf8Decode(bytes);
    // The text must encode back to the same bytes: an overlong or broken UTF-8 sequence that decodes
    // to the same characters is a second spelling of one claim and is refused.
    if (b64urlEncode(utf8Encode(claimJson)) !== claimB64) {
      return null;
    }
  } catch (e) {
    return null;
  }
  if (claimJson.length > MAX_CLAIM_JSON_CHARS) {
    return null;
  }
  const signed: SignedClaim = { claimJson: claimJson, sigB64: sigB64, kid: kid, keySource: source };
  return signed;
}
