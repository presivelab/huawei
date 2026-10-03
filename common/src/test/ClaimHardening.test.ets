// Hardened claim decode and the token format: pure logic, no crypto. The partner verifier tests that
// need real signatures are in ClaimVerifier.test.ets (Node ports, not in List.test.ets).
import { describe, it, expect } from '@ohos/hypium';
import { SignedClaim } from '../main/ets/model/types';
import { buildTierClaim, encodeTierClaim } from '../main/ets/claim/TierClaimCodec';
import {
  MAX_CLAIM_JSON_CHARS,
  MAX_DER_SIGNATURE_BYTES,
  MAX_FUTURE_SKEW_MS,
  MAX_TOKEN_CHARS,
  TIER_NO_SCORE,
  validateSignedClaim,
  validateTierClaimJson
} from '../main/ets/claim/ClaimValidation';
import { decodeSignedClaimToken, encodeSignedClaimToken } from '../main/ets/claim/SignedClaimToken';
import { b64urlEncode } from '../main/ets/platform/Bytes';

const NOW = 1790000000000;
const NONCE = 'q3J0aW5nLW5vbmNlLTE2Yg';
const KID = '762fa82f';
const PERIOD = '2026-09-03..2026-10-02';

function derOfLength(bytes: number): string {
  const body: number[] = [0x30, bytes - 2];
  while (body.length < bytes) {
    body.push(0x02);
  }
  return b64urlEncode(new Uint8Array(body));
}

function goodJson(): string {
  return encodeTierClaim(buildTierClaim(PERIOD, 'B', true, NONCE, NOW, KID));
}

function signedOf(claimJson: string): SignedClaim {
  const signed: SignedClaim = { claimJson: claimJson, sigB64: derOfLength(70), kid: KID, keySource: 'SOFTWARE' };
  return signed;
}

export default function claimHardeningTest() {
  describe('ClaimHardening', () => {
    it('a canonical claim passes and the claim comes back unchanged', 0, () => {
      const claim = validateTierClaimJson(goodJson(), NOW);
      expect(claim !== null).assertTrue();
      if (claim !== null) {
        expect(claim.tier).assertEqual('B');
        expect(claim.nonce).assertEqual(NONCE);
      }
    });

    it('rejects each malformed field', 0, () => {
      const cases: string[] = [
        encodeTierClaim(buildTierClaim(PERIOD, 'S', true, NONCE, NOW, KID)),
        encodeTierClaim(buildTierClaim(PERIOD, 'B', true, NONCE + 'x', NOW, KID)),
        encodeTierClaim(buildTierClaim(PERIOD, 'B', true, 'short', NOW, KID)),
        encodeTierClaim(buildTierClaim(PERIOD, 'B', true, NONCE.replace('q', '+'), NOW, KID)),
        encodeTierClaim(buildTierClaim(PERIOD, 'B', true, NONCE, NOW, '762FA82F')),
        encodeTierClaim(buildTierClaim(PERIOD, 'B', true, NONCE, NOW, '762fa82')),
        encodeTierClaim(buildTierClaim('2026-09-03', 'B', true, NONCE, NOW, KID)),
        encodeTierClaim(buildTierClaim('2026-09-03..2026-10-02 ', 'B', true, NONCE, NOW, KID)),
        encodeTierClaim(buildTierClaim(PERIOD, 'B', true, NONCE, 0, KID)),
        encodeTierClaim(buildTierClaim(PERIOD, 'B', true, NONCE, -5, KID)),
        encodeTierClaim(buildTierClaim(PERIOD, 'B', true, NONCE, NOW + 0.5, KID)),
        encodeTierClaim(buildTierClaim(PERIOD, 'B', true, NONCE, NOW + MAX_FUTURE_SKEW_MS + 1, KID)),
        encodeTierClaim(buildTierClaim(PERIOD, TIER_NO_SCORE, true, NONCE, NOW, KID)),
        goodJson().replace('"v":1', '"v":2')
      ];
      for (let i = 0; i < cases.length; i++) {
        expect(validateTierClaimJson(cases[i], NOW) === null).assertTrue();
      }
    });

    it('the five-minute future limit is inclusive; a past stamp of any age passes', 0, () => {
      const edge = encodeTierClaim(buildTierClaim(PERIOD, 'B', true, NONCE, NOW + MAX_FUTURE_SKEW_MS, KID));
      expect(validateTierClaimJson(edge, NOW) !== null).assertTrue();
      const old = encodeTierClaim(buildTierClaim(PERIOD, 'B', true, NONCE, 1, KID));
      expect(validateTierClaimJson(old, NOW) !== null).assertTrue();
    });

    it('the no-score tier is valid only with eligible false', 0, () => {
      const no = encodeTierClaim(buildTierClaim(PERIOD, TIER_NO_SCORE, false, NONCE, NOW, KID));
      expect(validateTierClaimJson(no, NOW) !== null).assertTrue();
    });

    it('rejects non-canonical text and text over the length limit', 0, () => {
      const good = goodJson();
      expect(validateTierClaimJson(good.replace(',"period"', ', "period"'), NOW) === null).assertTrue();
      expect(validateTierClaimJson(' ' + good, NOW) === null).assertTrue();
      expect(validateTierClaimJson(good.replace('"tier":"B",', '"tier":"B","tier":"B",'), NOW) === null).assertTrue();
      const padded = good.substring(0, good.length - 1) + ',"x":"' + 'y'.repeat(MAX_CLAIM_JSON_CHARS) + '"}';
      expect(padded.length > MAX_CLAIM_JSON_CHARS).assertTrue();
      expect(validateTierClaimJson(padded, NOW) === null).assertTrue();
      expect(validateTierClaimJson('', NOW) === null).assertTrue();
    });

    it('envelope: kid must match the claim, signature must be short strict DER', 0, () => {
      expect(validateSignedClaim(signedOf(goodJson()), NOW) !== null).assertTrue();
      const other = signedOf(goodJson());
      other.kid = '00000000';
      expect(validateSignedClaim(other, NOW) === null).assertTrue();
      const long = signedOf(goodJson());
      long.sigB64 = derOfLength(MAX_DER_SIGNATURE_BYTES + 1);
      expect(validateSignedClaim(long, NOW) === null).assertTrue();
      const maxed = signedOf(goodJson());
      maxed.sigB64 = derOfLength(MAX_DER_SIGNATURE_BYTES);
      expect(validateSignedClaim(maxed, NOW) !== null).assertTrue();
      const padding = signedOf(goodJson());
      padding.sigB64 = derOfLength(70) + '=';
      expect(validateSignedClaim(padding, NOW) === null).assertTrue();
      const source = signedOf(goodJson());
      source.keySource = 'huks';
      expect(validateSignedClaim(source, NOW) === null).assertTrue();
    });

    it('token: round trip, strict decode, worst case under the limit', 0, () => {
      const signed = signedOf(goodJson());
      const token = encodeSignedClaimToken(signed);
      expect(token.startsWith('fw1.')).assertTrue();
      const back = decodeSignedClaimToken(token);
      expect(back !== null).assertTrue();
      if (back !== null) {
        expect(back.claimJson).assertEqual(signed.claimJson);
        expect(back.sigB64).assertEqual(signed.sigB64);
        expect(back.kid).assertEqual(KID);
        expect(back.keySource).assertEqual('SOFTWARE');
      }
      const parts = token.split('.');
      expect(decodeSignedClaimToken(token + '.x') === null).assertTrue();
      expect(decodeSignedClaimToken(parts.slice(0, 4).join('.')) === null).assertTrue();
      expect(decodeSignedClaimToken('fw2.' + parts.slice(1).join('.')) === null).assertTrue();
      expect(decodeSignedClaimToken(token.replace(parts[1], parts[1] + '=')) === null).assertTrue();
      expect(decodeSignedClaimToken(token.replace(parts[1], parts[1].substring(0, 5) + '+' +
        parts[1].substring(6))) === null).assertTrue();
      expect(decodeSignedClaimToken('') === null).assertTrue();
      expect(decodeSignedClaimToken('x'.repeat(MAX_TOKEN_CHARS + 1)) === null).assertTrue();
      const worst: SignedClaim = { claimJson: 'a'.repeat(MAX_CLAIM_JSON_CHARS),
        sigB64: derOfLength(MAX_DER_SIGNATURE_BYTES), kid: KID, keySource: 'SOFTWARE' };
      const worstToken = encodeSignedClaimToken(worst);
      expect(worstToken.length).assertEqual(461);
      expect(worstToken.length <= MAX_TOKEN_CHARS).assertTrue();
      expect(decodeSignedClaimToken(worstToken) !== null).assertTrue();
    });
  });
}
