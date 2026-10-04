import { TierClaim } from '../model/types';

/*
 * The tier claim is the only payload a partner ever receives.
 * It carries a tier and a yes/no eligibility, never the reason: no score, no coverage,
 * no wear percentage, no flag and no pseudonym.
 */

export const TIER_CLAIM_VERSION: number = 1;

/** The exact key set of an encoded claim, in encoding order. */
export const TIER_CLAIM_KEYS: string[] = ['v', 'period', 'tier', 'eligible', 'nonce', 'issuedAt', 'kid'];

export function buildTierClaim(period: string, tier: string, eligible: boolean, nonce: string, issuedAt: number,
  kid: string): TierClaim {
  const claim: TierClaim = {
    v: TIER_CLAIM_VERSION,
    period: period,
    tier: tier,
    eligible: eligible,
    nonce: nonce,
    issuedAt: issuedAt,
    kid: kid
  };
  return claim;
}

/** Canonical JSON: the bytes that get signed. Key order is fixed by TIER_CLAIM_KEYS. */
export function encodeTierClaim(claim: TierClaim): string {
  return '{"v":' + claim.v.toString() +
    ',"period":' + JSON.stringify(claim.period) +
    ',"tier":' + JSON.stringify(claim.tier) +
    ',"eligible":' + (claim.eligible ? 'true' : 'false') +
    ',"nonce":' + JSON.stringify(claim.nonce) +
    ',"issuedAt":' + claim.issuedAt.toString() +
    ',"kid":' + JSON.stringify(claim.kid) + '}';
}

/** Strict decode: returns null for malformed JSON, a missing key, an extra key or a wrong value type. */
export function decodeTierClaim(json: string): TierClaim | null {
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
  if (keys.length !== TIER_CLAIM_KEYS.length) {
    return null;
  }
  for (let i = 0; i < TIER_CLAIM_KEYS.length; i++) {
    if (keys.indexOf(TIER_CLAIM_KEYS[i]) < 0) {
      return null;
    }
  }
  const v = parsed['v'];
  const period = parsed['period'];
  const tier = parsed['tier'];
  const eligible = parsed['eligible'];
  const nonce = parsed['nonce'];
  const issuedAt = parsed['issuedAt'];
  const kid = parsed['kid'];
  if (typeof v !== 'number' || typeof period !== 'string' || typeof tier !== 'string' ||
    typeof eligible !== 'boolean' || typeof nonce !== 'string' || typeof issuedAt !== 'number' ||
    typeof kid !== 'string') {
    return null;
  }
  const claim: TierClaim = {
    v: v as number,
    period: period as string,
    tier: tier as string,
    eligible: eligible as boolean,
    nonce: nonce as string,
    issuedAt: issuedAt as number,
    kid: kid as string
  };
  return claim;
}
