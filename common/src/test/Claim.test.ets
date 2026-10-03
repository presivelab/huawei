import { describe, it, expect } from '@ohos/hypium';
import { TierClaim, Thresholds } from '../main/ets/model/types';
import { DEFAULT_THRESHOLDS } from '../main/ets/model/defaults';
import {
  buildTierClaim,
  decodeTierClaim,
  encodeTierClaim,
  TIER_CLAIM_KEYS
} from '../main/ets/claim/TierClaimCodec';
import { isSelectiveNonWear } from '../main/ets/rules/SelectiveNonWear';

function sampleClaim(): TierClaim {
  return buildTierClaim('2026-09-03..2026-10-02', 'B', true, 'q3J0aW5nLW5vbmNlLTE2Yg', 1790000000000, '762fa82f');
}

export default function claimTest() {
  describe('TierClaim', () => {
    it('encoded claim has exactly the seven agreed keys', 0, () => {
      const parsed = JSON.parse(encodeTierClaim(sampleClaim())) as Record<string, Object>;
      const keys = Object.keys(parsed).sort();
      const expected = ['eligible', 'issuedAt', 'kid', 'nonce', 'period', 'tier', 'v'];
      expect(keys.length).assertEqual(expected.length);
      for (let i = 0; i < expected.length; i++) {
        expect(keys[i]).assertEqual(expected[i]);
      }
      expect(TIER_CLAIM_KEYS.length).assertEqual(7);
    });

    it('encoded claim never names the reason or the score', 0, () => {
      const json = encodeTierClaim(sampleClaim()).toLowerCase();
      const banned = ['flag', 'susp', 'reason', 'hes', 'coverage', 'compliance', 'pseudonym', 'pubkey'];
      for (let i = 0; i < banned.length; i++) {
        expect(json.indexOf(banned[i])).assertEqual(-1);
      }
    });

    it('decode round-trips an encoded claim', 0, () => {
      const back = decodeTierClaim(encodeTierClaim(sampleClaim()));
      expect(back !== null).assertTrue();
      if (back !== null) {
        expect(back.tier).assertEqual('B');
        expect(back.eligible).assertTrue();
        expect(back.kid).assertEqual('762fa82f');
        expect(back.issuedAt).assertEqual(1790000000000);
      }
    });

    it('decode rejects an extra key, a missing key and malformed JSON', 0, () => {
      const good = encodeTierClaim(sampleClaim());
      const extra = good.substring(0, good.length - 1) + ',"compliancePct":87}';
      expect(decodeTierClaim(extra) === null).assertTrue();
      const missing = good.replace(',"kid":"762fa82f"', '');
      expect(decodeTierClaim(missing) === null).assertTrue();
      expect(decodeTierClaim('{not json') === null).assertTrue();
      expect(decodeTierClaim('null') === null).assertTrue();
    });
  });

  describe('SelectiveNonWear', () => {
    const th: Thresholds = DEFAULT_THRESHOLDS;

    it('one suspicious gap never flags, even when it is the only gap', 0, () => {
      expect(isSelectiveNonWear(1, 1, th)).assertFalse();
      expect(isSelectiveNonWear(1, 3, th)).assertFalse();
      expect(isSelectiveNonWear(0, 5, th)).assertFalse();
    });

    it('honest person: 3 gaps in 30 days, 1 after a cold, no flag', 0, () => {
      expect(isSelectiveNonWear(1, 3, th)).assertFalse();
    });

    it('two suspicious gaps flag only above a 30% share', 0, () => {
      expect(isSelectiveNonWear(2, 4, th)).assertTrue();
      expect(isSelectiveNonWear(2, 6, th)).assertTrue();
      expect(isSelectiveNonWear(2, 7, th)).assertFalse();
      expect(isSelectiveNonWear(2, 10, th)).assertFalse();
    });

    it('three or more suspicious gaps always flag', 0, () => {
      expect(isSelectiveNonWear(3, 20, th)).assertTrue();
      expect(isSelectiveNonWear(4, 4, th)).assertTrue();
    });
  });
}
