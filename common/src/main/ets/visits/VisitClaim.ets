import {
  isValidKeySource,
  isValidKidText,
  isValidNonceText,
  isValidSignatureText,
  MAX_CLAIM_JSON_CHARS,
  MAX_FUTURE_SKEW_MS,
  MAX_TOKEN_CHARS
} from '../claim/ClaimValidation';
import { SignedClaim } from '../model/types';
import { b64urlDecode, b64urlEncode, toHex, utf8Decode, utf8Encode } from '../platform/Bytes';
import { Hasher, Signer } from '../watchlink/WatchLinkPorts';
import { visitAdherence } from './FollowUp';
import {
  ADHERENCE_ON_TIME,
  ADHERENCE_VALUES,
  addDays,
  isIsoDate,
  isShareableServiceType,
  MedicalReceipt,
  serviceTypeLabel,
  Visit,
  visitDateText
} from './VisitTypes';

/*
 * The visit claim: the only thing about a visit a partner ever receives.
 *
 * Exactly nine keys, in the style of the tier claim: that a visit of a shareable kind took place, on
 * which day, and whether it was a follow-up kept on time. No amount, no clinic, no issuer id, no
 * transcript and no notes. The receipt is named by a reference, a hash of its three codes, so the
 * partner can tell two claims of one receipt apart without learning which receipt it is.
 *
 * It is signed with the same device key and through the same Signer port as the tier claim; nothing
 * about the cryptography is new here. The token has its own marker, fv1, so a visit token can never be
 * taken for a tier token or the other way round.
 */

export const VISIT_CLAIM_VERSION: number = 1;
export const VISIT_CLAIM_TYPE: string = 'visit';

/** The exact key set of an encoded visit claim, in encoding order. */
export const VISIT_CLAIM_KEYS: string[] =
  ['v', 'type', 'visitDate', 'visitType', 'receiptRef', 'adherence', 'nonce', 'issuedAt', 'kid'];

export interface VisitClaim {
  v: number;
  type: string;           // always 'visit'
  visitDate: string;      // YYYY-MM-DD
  visitType: string;      // CHECKUP or OUTPATIENT, never anything else
  receiptRef: string;     // 16 hex characters: the first 8 bytes of SHA-256 over billCode|billNo|checkCode
  adherence: string;      // FOLLOW_UP_ON_TIME or NONE
  nonce: string;
  issuedAt: number;
  kid: string;
}

export const VISIT_NOT_VERIFIED: string = 'Only a visit with a verified receipt can be shared';
export const VISIT_TYPE_NEVER_SHARED: string = 'This visit type is never shared with partners';

export const VISIT_TOKEN_MARKER: string = 'fv1';
const TOKEN_SEPARATOR: string = '.';
const TOKEN_FIELD_COUNT: number = 5;
const MAX_CLAIM_B64_CHARS: number = 342;
const RECEIPT_REF_BYTES: number = 8;
const RECEIPT_REF_PATTERN: RegExp = new RegExp('^[0-9a-f]{16}$');

/**
 * The reference of a receipt: hex of the first 8 bytes of SHA-256 over "billCode|billNo|checkCode".
 * The hash comes through the Hasher port, the same SHA-256 the key id is made with.
 */
export async function receiptRef(receipt: MedicalReceipt, hasher: Hasher): Promise<string> {
  const digest = await hasher.sha256B64url(`${receipt.billCode}|${receipt.billNo}|${receipt.checkCode}`);
  return toHex(b64urlDecode(digest)).substring(0, RECEIPT_REF_BYTES * 2);
}

/** Why this visit cannot be shared; empty when it can. The kind of visit is checked first. */
export function visitShareBlock(visit: Visit): string {
  const receipt = visit.receipt;
  if (receipt !== undefined && !isShareableServiceType(receipt.serviceType)) {
    return VISIT_TYPE_NEVER_SHARED;
  }
  if (receipt === undefined || visit.receiptStatus !== 'VERIFIED') {
    return VISIT_NOT_VERIFIED;
  }
  return '';
}

/**
 * The claim of one visit. Throws when the visit may not be shared: the receipt is not verified, or the
 * visit is emergency or inpatient care. `visits` are the user's visits, for the follow-up link.
 */
export async function buildVisitClaim(visit: Visit, visits: Visit[], nonce: string, issuedAt: number, kid: string,
  hasher: Hasher): Promise<VisitClaim> {
  const block = visitShareBlock(visit);
  const receipt = visit.receipt;
  if (block.length > 0 || receipt === undefined) {
    throw new Error(block.length > 0 ? block : VISIT_NOT_VERIFIED);
  }
  const claim: VisitClaim = {
    v: VISIT_CLAIM_VERSION,
    type: VISIT_CLAIM_TYPE,
    visitDate: receipt.issueDate,
    visitType: receipt.serviceType,
    receiptRef: await receiptRef(receipt, hasher),
    adherence: visitAdherence(visit, visits),
    nonce: nonce,
    issuedAt: issuedAt,
    kid: kid
  };
  return claim;
}

/** Canonical JSON: the bytes that get signed. Key order is fixed by VISIT_CLAIM_KEYS. */
export function encodeVisitClaim(claim: VisitClaim): string {
  return '{"v":' + claim.v.toString() +
    ',"type":' + JSON.stringify(claim.type) +
    ',"visitDate":' + JSON.stringify(claim.visitDate) +
    ',"visitType":' + JSON.stringify(claim.visitType) +
    ',"receiptRef":' + JSON.stringify(claim.receiptRef) +
    ',"adherence":' + JSON.stringify(claim.adherence) +
    ',"nonce":' + JSON.stringify(claim.nonce) +
    ',"issuedAt":' + claim.issuedAt.toString() +
    ',"kid":' + JSON.stringify(claim.kid) + '}';
}

/** Strict decode: null for malformed JSON, a missing key, an extra key or a wrong value type. */
export function decodeVisitClaim(json: string): VisitClaim | null {
  let parsed: Record<string, Object>;
  try {
    parsed = JSON.parse(json) as Record<string, Object>;
  } catch (e) {
    return null;
  }
  if (parsed === null || typeof parsed !== 'object') {
    return null;
  }
  const keys = Object.keys(parsed);
  if (keys.length !== VISIT_CLAIM_KEYS.length) {
    return null;
  }
  for (let i = 0; i < VISIT_CLAIM_KEYS.length; i++) {
    if (keys.indexOf(VISIT_CLAIM_KEYS[i]) < 0) {
      return null;
    }
  }
  const v = parsed['v'];
  const type = parsed['type'];
  const visitDate = parsed['visitDate'];
  const visitType = parsed['visitType'];
  const ref = parsed['receiptRef'];
  const adherence = parsed['adherence'];
  const nonce = parsed['nonce'];
  const issuedAt = parsed['issuedAt'];
  const kid = parsed['kid'];
  if (typeof v !== 'number' || typeof type !== 'string' || typeof visitDate !== 'string' ||
    typeof visitType !== 'string' || typeof ref !== 'string' || typeof adherence !== 'string' ||
    typeof nonce !== 'string' || typeof issuedAt !== 'number' || typeof kid !== 'string') {
    return null;
  }
  const claim: VisitClaim = {
    v: v as number,
    type: type as string,
    visitDate: visitDate as string,
    visitType: visitType as string,
    receiptRef: ref as string,
    adherence: adherence as string,
    nonce: nonce as string,
    issuedAt: issuedAt as number,
    kid: kid as string
  };
  return claim;
}

/**
 * The claim inside `claimJson`, or null when anything is off. The decoded claim is encoded again and
 * must equal the received text exactly. `nowMs` is the verifier's clock. Never throws.
 */
export function validateVisitClaimJson(claimJson: string, nowMs: number): VisitClaim | null {
  if (claimJson.length === 0 || claimJson.length > MAX_CLAIM_JSON_CHARS) {
    return null;
  }
  const claim = decodeVisitClaim(claimJson);
  if (claim === null || encodeVisitClaim(claim) !== claimJson) {
    return null;
  }
  if (claim.v !== VISIT_CLAIM_VERSION || claim.type !== VISIT_CLAIM_TYPE) {
    return null;
  }
  if (!isIsoDate(claim.visitDate) || !isShareableServiceType(claim.visitType)) {
    return null;
  }
  if (!RECEIPT_REF_PATTERN.test(claim.receiptRef) || ADHERENCE_VALUES.indexOf(claim.adherence) < 0) {
    return null;
  }
  if (!isValidNonceText(claim.nonce) || !isValidKidText(claim.kid)) {
    return null;
  }
  if (!Number.isSafeInteger(claim.issuedAt) || claim.issuedAt <= 0 || claim.issuedAt > nowMs + MAX_FUTURE_SKEW_MS) {
    return null;
  }
  return claim;
}

/*
 * Token format: fv1.<claim>.<sig>.<kid>.<source>, the layout of the tier token with another marker.
 *   claim     the canonical claim JSON (the exact signed bytes), UTF-8, base64url without padding
 *   sig       ECDSA P-256 / SHA-256 signature, ASN.1 DER, base64url without padding
 *   kid       key id, 8 lower-case hex characters
 *   source    HUKS or SOFTWARE
 * At most 512 characters.
 */
export function encodeVisitToken(signed: SignedClaim): string {
  return VISIT_TOKEN_MARKER + TOKEN_SEPARATOR + b64urlEncode(utf8Encode(signed.claimJson)) + TOKEN_SEPARATOR +
    signed.sigB64 + TOKEN_SEPARATOR + signed.kid + TOKEN_SEPARATOR + signed.keySource;
}

/** The structure of a visit token, or null. Syntax only: the claim itself is checked by validateVisitClaimJson. */
export function decodeVisitToken(token: string): SignedClaim | null {
  if (token.length === 0 || token.length > MAX_TOKEN_CHARS) {
    return null;
  }
  const parts = token.split(TOKEN_SEPARATOR);
  if (parts.length !== TOKEN_FIELD_COUNT || parts[0] !== VISIT_TOKEN_MARKER) {
    return null;
  }
  const claimB64 = parts[1];
  const sigB64 = parts[2];
  const kid = parts[3];
  const source = parts[4];
  if (claimB64.length === 0 || claimB64.length > MAX_CLAIM_B64_CHARS || !isValidKidText(kid) ||
    !isValidKeySource(source) || !isValidSignatureText(sigB64)) {
    return null;
  }
  let claimJson: string;
  try {
    const bytes = b64urlDecode(claimB64);
    if (b64urlEncode(bytes) !== claimB64) {
      return null;
    }
    claimJson = utf8Decode(bytes);
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

/** The token for the QR code: the claim signed with the device key, through the same Signer as a tier claim. */
export async function mintVisitToken(signer: Signer, keySource: string, claim: VisitClaim): Promise<string> {
  const claimJson = encodeVisitClaim(claim);
  const sigB64 = await signer.sign(claimJson);
  const signed: SignedClaim = { claimJson: claimJson, sigB64: sigB64, kid: signer.kid(), keySource: keySource };
  return encodeVisitToken(signed);
}

/** The claim a visit token carries, unverified: for showing the user what their own code says. */
export function visitTokenClaim(token: string): VisitClaim | null {
  const signed = decodeVisitToken(token);
  return signed === null ? null : decodeVisitClaim(signed.claimJson);
}

/** The same token with the visit date moved one day and the old signature: the "try to cheat" step. */
export function tamperedVisitDateToken(token: string): string | null {
  const signed = decodeVisitToken(token);
  if (signed === null) {
    return null;
  }
  const claim = decodeVisitClaim(signed.claimJson);
  if (claim === null) {
    return null;
  }
  const moved = addDays(claim.visitDate, 1);
  claim.visitDate = moved.length > 0 ? moved : claim.visitDate;
  const out: SignedClaim = {
    claimJson: encodeVisitClaim(claim),
    sigB64: signed.sigB64,
    kid: signed.kid,
    keySource: signed.keySource
  };
  return encodeVisitToken(out);
}

/** How a claim states the follow-up, as the user and the partner read it. */
export function adherenceLabel(adherence: string): string {
  return adherence === ADHERENCE_ON_TIME ? 'Follow-up on time' : 'No follow-up stated';
}

export interface ClaimLine {
  label: string;
  value: string;
}

/** The claim in plain words: everything the partner learns, and nothing else. */
export function visitClaimLines(claim: VisitClaim): ClaimLine[] {
  const lines: ClaimLine[] = [
    { label: 'Visit type', value: serviceTypeLabel(claim.visitType) },
    { label: 'Visit date', value: visitDateText(claim.visitDate) },
    { label: 'Follow-up', value: adherenceLabel(claim.adherence) },
    { label: 'Receipt', value: 'A reference that does not reveal the receipt number' },
    { label: 'Signature', value: 'This phone\'s key and a one-time number from the partner' }
  ];
  return lines;
}

/** What never leaves the phone with a visit claim. */
export const VISIT_NEVER_SHARED: string = 'Never shared: amount, clinic name, transcript, notes';

/** Everything the partner learns, on one line: "Outpatient visit · 30 Sep 2026 · Follow-up on time". */
export function visitClaimLine(claim: VisitClaim): string {
  return `${serviceTypeLabel(claim.visitType)} · ${visitDateText(claim.visitDate)} · ${adherenceLabel(claim.adherence)}`;
}
