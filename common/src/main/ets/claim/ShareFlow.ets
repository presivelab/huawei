import { LedgerEntry, SignedClaim, TierClaim } from '../model/types';
import { utf8Encode } from '../platform/Bytes';
import { benefitLabel, benefitLevel } from '../report/Benefit';
import { hasScore, PersonaReport } from '../report/ReportModels';
import { Signer } from '../watchlink/WatchLinkPorts';
import { KEY_SOURCE_HUKS, MAX_TOKEN_CHARS, TIER_A, TIER_B, TIER_NO_SCORE } from './ClaimValidation';
import { VerifyResult, VERIFY_STEPS } from './PartnerVerifier';
import { decodeSignedClaimToken, encodeSignedClaimToken } from './SignedClaimToken';
import { buildTierClaim, decodeTierClaim, encodeTierClaim } from './TierClaimCodec';

/*
 * The Share screen and the partner view of the demo, as pure logic: what a report lets the user share,
 * how the signed token is made, what the partner reads from a verification result, and the forged token
 * of the "try to cheat" step. The screens only draw what these functions return.
 */

export const LEDGER_KIND_CLAIM: string = 'CLAIM';
export const LEDGER_DESTINATION_PARTNER: string = 'Partner · code shown on this screen';

export const SHARE_NO_SCORE_TIER: string = 'Tier: not available';
export const SHARE_NO_SCORE_REASON: string = 'Not enough data yet';
export const SHARE_REASON_STAYS: string = 'The reason stays on this phone.';

const MONTHS_SHORT: string[] = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/** What one report lets the user share. */
export interface ShareOffer {
  available: boolean;    // false when there is no score: no code is made and nothing leaves the phone
  tier: string;          // as the claim writes it: A, B, C or NONE
  eligible: boolean;
  periodIso: string;     // "2026-09-04..2026-10-03"
  note: string;          // one sentence for the user about this offer; empty when there is nothing to add
}

/*
 * No score (Ola): nothing to share. A score without eligibility (Marek): the code is made and says
 * "Eligible: no"; the reason is told to the user here and is never part of the code.
 */
export function shareOffer(report: PersonaReport): ShareOffer {
  if (!hasScore(report)) {
    const none: ShareOffer = {
      available: false,
      tier: TIER_NO_SCORE,
      eligible: false,
      periodIso: report.periodIso,
      note: SHARE_NO_SCORE_REASON
    };
    return none;
  }
  const offer: ShareOffer = {
    available: true,
    tier: report.tier,
    eligible: report.eligible,
    periodIso: report.periodIso,
    note: report.eligible ? '' : `Eligible: no · ${report.benefitReason}. ${SHARE_REASON_STAYS}`
  };
  return offer;
}

/** The token for the QR code: the claim of this offer, signed with the device key. */
export async function mintClaimToken(signer: Signer, keySource: string, offer: ShareOffer, nonce: string,
  issuedAt: number): Promise<string> {
  const claimJson = encodeTierClaim(buildTierClaim(offer.periodIso, offer.tier, offer.eligible, nonce, issuedAt,
    signer.kid()));
  const sigB64 = await signer.sign(claimJson);
  const signed: SignedClaim = { claimJson: claimJson, sigB64: sigB64, kid: signer.kid(), keySource: keySource };
  return encodeSignedClaimToken(signed);
}

/** The claim a token carries, unverified: for showing the user what their own code says. */
export function tokenClaim(token: string): TierClaim | null {
  const signed = decodeSignedClaimToken(token);
  return signed === null ? null : decodeTierClaim(signed.claimJson);
}

/** The tier the "try to cheat" step writes into the claim: A, or B when the claim already says A. */
export function tamperTargetTier(tier: string): string {
  return tier === TIER_A ? TIER_B : TIER_A;
}

/** The same token with another tier in the claim and the old signature. Null when the token does not decode. */
export function tamperedTierToken(token: string): string | null {
  const signed = decodeSignedClaimToken(token);
  if (signed === null) {
    return null;
  }
  const claim = decodeTierClaim(signed.claimJson);
  if (claim === null) {
    return null;
  }
  const forged = buildTierClaim(claim.period, tamperTargetTier(claim.tier), claim.eligible, claim.nonce,
    claim.issuedAt, claim.kid);
  const out: SignedClaim = {
    claimJson: encodeTierClaim(forged),
    sigB64: signed.sigB64,
    kid: signed.kid,
    keySource: signed.keySource
  };
  return encodeSignedClaimToken(out);
}

function shortDate(iso: string): string {
  const month = Number(iso.substring(5, 7));
  const day = Number(iso.substring(8, 10));
  if (isNaN(month) || isNaN(day) || month < 1 || month > 12 || day < 1 || day > 31) {
    return '';
  }
  return `${day} ${MONTHS_SHORT[month - 1]}`;
}

/** "2026-09-04..2026-10-03" as "4 Sep – 3 Oct". Anything else is returned unchanged. */
export function claimPeriodText(periodIso: string): string {
  if (periodIso.length !== 22 || periodIso.substring(10, 12) !== '..') {
    return periodIso;
  }
  const from = shortDate(periodIso.substring(0, 10));
  const to = shortDate(periodIso.substring(12, 22));
  return from.length === 0 || to.length === 0 ? periodIso : `${from} – ${to}`;
}

/** "Tier B · Eligible: no", or "Tier: not available" without a score. */
export function claimTierLine(tier: string, eligible: boolean): string {
  if (tier === TIER_NO_SCORE) {
    return SHARE_NO_SCORE_TIER;
  }
  return `Tier ${tier} · Eligible: ${eligible ? 'yes' : 'no'}`;
}

/** Everything the partner learns, on one line: "Tier B · Eligible: no · 4 Sep – 3 Oct". */
export function claimLine(claim: TierClaim): string {
  return `${claimTierLine(claim.tier, claim.eligible)} · ${claimPeriodText(claim.period)}`;
}

/** What the partner grants on this claim: the same rule the report uses, from the claim's two facts. */
export function claimBenefitLabel(claim: TierClaim): string {
  return benefitLabel(benefitLevel(claim.eligible, claim.tier, claim.tier !== TIER_NO_SCORE));
}

export function keySourceLabel(source: string): string {
  return source === KEY_SOURCE_HUKS ? 'HUKS key' : 'Software key';
}

export function tokenLengthLine(token: string): string {
  return `${token.length} of ${MAX_TOKEN_CHARS} characters`;
}

/** The ledger line of one shown code: the exact text that left the phone and its size. */
export function claimLedgerEntry(token: string, nowMs: number): LedgerEntry {
  const entry: LedgerEntry = {
    t: nowMs,
    kind: LEDGER_KIND_CLAIM,
    destination: LEDGER_DESTINATION_PARTNER,
    payload: token,
    bytes: utf8Encode(token).length
  };
  return entry;
}

export class CheckState {
  static readonly PASSED: string = 'passed';
  static readonly FAILED: string = 'failed';
  static readonly NOT_RUN: string = 'notRun';
}

export interface CheckRow {
  label: string;
  state: string;         // CheckState
}

/** The five checks of the partner, in the order PartnerVerifier runs them. */
export const CHECK_LABELS: string[] = [
  'Format',
  'Known key',
  'Signature over the exact claim',
  'Nonce issued by this partner, not expired',
  'Not used before'
];

const STOP_NAMES: string[] = ['format', 'known key', 'signature', 'nonce', 'not used before'];

/** One row per check: passed before the stop, failed at the stop, not run after it. */
export function checkRows(result: VerifyResult): CheckRow[] {
  const rows: CheckRow[] = [];
  for (let i = 0; i < CHECK_LABELS.length; i++) {
    const step = i + 1;
    let state = CheckState.NOT_RUN;
    if (result.ok || step < result.step) {
      state = CheckState.PASSED;
    } else if (step === result.step) {
      state = CheckState.FAILED;
    }
    const row: CheckRow = { label: CHECK_LABELS[i], state: state };
    rows.push(row);
  }
  return rows;
}

/** The check a failed run stopped at ("signature"); empty for a valid result. */
export function stoppedAt(result: VerifyResult): string {
  if (result.ok || result.step < 1 || result.step >= VERIFY_STEPS.length) {
    return '';
  }
  return STOP_NAMES[result.step - 1];
}

/** "Invalid signature · stopped at: signature", or the status alone for a valid result. */
export function verdictLine(result: VerifyResult): string {
  const stop = stoppedAt(result);
  return stop.length === 0 ? result.status : `${result.status} · stopped at: ${stop}`;
}
