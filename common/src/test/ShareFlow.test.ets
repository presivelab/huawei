// The Share screen and the partner view as one flow, with real ECDSA P-256 signatures from Node:
// offer -> signed token -> partner verification -> the same code again -> a changed tier.
// Not part of List.test.ets (the ports come from tools/logic-tests/node-ports.ts).
import { describe, it, expect } from '@ohos/hypium';
import { NodeRandom, NodeSigner, NodeSigVerifier } from '@fairwear/node-ports';
import { MAX_TOKEN_CHARS, TIER_NO_SCORE } from '../main/ets/claim/ClaimValidation';
import {
  PartnerVerifier,
  STATUS_ALREADY_USED,
  STATUS_INVALID_SIGNATURE,
  STATUS_VALID,
  VerifyResult
} from '../main/ets/claim/PartnerVerifier';
import {
  CHECK_LABELS,
  checkRows,
  CheckState,
  claimBenefitLabel,
  claimLedgerEntry,
  claimLine,
  claimPeriodText,
  claimTierLine,
  keySourceLabel,
  LEDGER_KIND_CLAIM,
  mintClaimToken,
  shareOffer,
  SHARE_NO_SCORE_REASON,
  SHARE_NO_SCORE_TIER,
  SHARE_REASON_STAYS,
  stoppedAt,
  tamperedTierToken,
  tamperTargetTier,
  tokenClaim,
  tokenLengthLine,
  verdictLine
} from '../main/ets/claim/ShareFlow';
import { TIER_CLAIM_KEYS } from '../main/ets/claim/TierClaimCodec';
import { b64urlDecode } from '../main/ets/platform/Bytes';
import { BENEFIT_FULL_LABEL, BENEFIT_NONE_LABEL, BENEFIT_PARTIAL_LABEL } from '../main/ets/report/Benefit';
import { previewReport } from './fixtures/PreviewReports';
import { Clock } from '../main/ets/watchlink/WatchLinkPorts';

const NOW = 1790000000000;

class FixedClock implements Clock {
  nowMs(): number {
    return NOW;
  }
}

class Desk {
  signer: NodeSigner = new NodeSigner();
  verifier: PartnerVerifier = new PartnerVerifier(new NodeRandom(), new FixedClock(), new NodeSigVerifier());

  constructor() {
    this.verifier.registerKey(this.signer.kid(), b64urlDecode(this.signer.publicKeySpkiB64()), 'HUKS');
  }

  /** What the Share screen does for one persona: a partner nonce, then the signed token. */
  async share(personaId: string): Promise<string> {
    const nonce = await this.verifier.issueNonce();
    return mintClaimToken(this.signer, 'HUKS', shareOffer(previewReport(personaId)), nonce, NOW);
  }
}

function states(result: VerifyResult): string {
  return checkRows(result).map((row) => row.state).join(',');
}

export default function shareFlowTest() {
  describe('Share and partner flow', () => {
    it('Ania: full offer, the partner reads tier A, eligible, full benefit', 0, async () => {
      const desk = new Desk();
      const offer = shareOffer(previewReport('ania'));
      expect(offer.available).assertTrue();
      expect(offer.note).assertEqual('');
      const result = await desk.verifier.verify(await desk.share('ania'));
      expect(result.status).assertEqual(STATUS_VALID);
      expect(claimLine(result.claim!)).assertEqual('Tier A · Eligible: yes · 4 Sep – 3 Oct');
      expect(claimBenefitLabel(result.claim!)).assertEqual(BENEFIT_FULL_LABEL);
      expect(keySourceLabel(result.keySource)).assertEqual('HUKS key');
    });

    it('Tomek: tier B and eligible reads as a partial benefit', 0, async () => {
      const desk = new Desk();
      const result = await desk.verifier.verify(await desk.share('tomek'));
      expect(claimLine(result.claim!)).assertEqual('Tier B · Eligible: yes · 4 Sep – 3 Oct');
      expect(claimBenefitLabel(result.claim!)).assertEqual(BENEFIT_PARTIAL_LABEL);
    });

    it('Marek: the code is made, says not eligible, and never says why', 0, async () => {
      const desk = new Desk();
      const report = previewReport('marek');
      const offer = shareOffer(report);
      expect(offer.available).assertTrue();
      expect(offer.eligible).assertFalse();
      expect(offer.note).assertEqual(`Eligible: no · 3 suspicious breaks. ${SHARE_REASON_STAYS}`);
      const token = await desk.share('marek');
      const result = await desk.verifier.verify(token);
      expect(result.status).assertEqual(STATUS_VALID);
      expect(claimLine(result.claim!)).assertEqual('Tier B · Eligible: no · 4 Sep – 3 Oct');
      expect(claimBenefitLabel(result.claim!)).assertEqual(BENEFIT_NONE_LABEL);
      // The signed text holds the seven claim keys and nothing about breaks, flags or the score.
      const claimText = JSON.stringify(tokenClaim(token));
      expect(Object.keys(tokenClaim(token)!).join(',')).assertEqual(TIER_CLAIM_KEYS.join(','));
      expect(report.wear.flagged).assertTrue();
      expect(claimText.indexOf('suspicious') < 0 && claimText.indexOf('flag') < 0).assertTrue();
    });

    it('Ola: no score, no offer, the reason is told', 0, () => {
      const offer = shareOffer(previewReport('ola'));
      expect(offer.available).assertFalse();
      expect(offer.tier).assertEqual(TIER_NO_SCORE);
      expect(offer.eligible).assertFalse();
      expect(offer.note).assertEqual(SHARE_NO_SCORE_REASON);
      expect(claimTierLine(offer.tier, offer.eligible)).assertEqual(SHARE_NO_SCORE_TIER);
    });

    it('Use again: the same code is refused as already used, at the fifth check', 0, async () => {
      const desk = new Desk();
      const token = await desk.share('tomek');
      const first = await desk.verifier.verify(token);
      expect(states(first)).assertEqual('passed,passed,passed,passed,passed');
      expect(stoppedAt(first)).assertEqual('');
      expect(verdictLine(first)).assertEqual(STATUS_VALID);
      const again = await desk.verifier.verify(token);
      expect(again.status).assertEqual(STATUS_ALREADY_USED);
      expect(states(again)).assertEqual('passed,passed,passed,passed,failed');
      expect(verdictLine(again)).assertEqual('Already used · stopped at: not used before');
    });

    it('Tamper tier: B changed to A under the old signature is an invalid signature', 0, async () => {
      const desk = new Desk();
      const token = await desk.share('marek');
      const forged = tamperedTierToken(token)!;
      expect(tokenClaim(forged)!.tier).assertEqual('A');
      expect(tokenClaim(forged)!.nonce).assertEqual(tokenClaim(token)!.nonce);
      const result = await desk.verifier.verify(forged);
      expect(result.status).assertEqual(STATUS_INVALID_SIGNATURE);
      expect(result.claim === null).assertTrue();
      expect(states(result)).assertEqual('passed,passed,failed,notRun,notRun');
      expect(verdictLine(result)).assertEqual('Invalid signature · stopped at: signature');
      // The forged attempt does not spend the nonce: the honest code still verifies afterwards.
      expect((await desk.verifier.verify(token)).status).assertEqual(STATUS_VALID);
      // After the honest use the forged one is still stopped at the signature, not at the nonce.
      expect((await desk.verifier.verify(forged)).status).assertEqual(STATUS_INVALID_SIGNATURE);
    });

    it('Tamper target: A for B, C and no score; B when the claim already says A', 0, async () => {
      expect(tamperTargetTier('B')).assertEqual('A');
      expect(tamperTargetTier('C')).assertEqual('A');
      expect(tamperTargetTier(TIER_NO_SCORE)).assertEqual('A');
      expect(tamperTargetTier('A')).assertEqual('B');
      expect(tamperedTierToken('not a token') === null).assertTrue();
      const desk = new Desk();
      const result = await desk.verifier.verify(tamperedTierToken(await desk.share('ania'))!);
      expect(result.status).assertEqual(STATUS_INVALID_SIGNATURE);
    });

    it('Ledger entry: the exact token, its size in bytes, the kind and the time', 0, async () => {
      const desk = new Desk();
      const token = await desk.share('ania');
      const entry = claimLedgerEntry(token, NOW);
      expect(entry.payload).assertEqual(token);
      expect(entry.bytes).assertEqual(token.length);
      expect(entry.kind).assertEqual(LEDGER_KIND_CLAIM);
      expect(entry.t).assertEqual(NOW);
      expect(token.length <= MAX_TOKEN_CHARS).assertTrue();
      expect(tokenLengthLine(token)).assertEqual(`${token.length} of 512 characters`);
    });

    it('Texts: period, tier line, key source, five checks', 0, () => {
      expect(claimPeriodText('2026-09-04..2026-10-03')).assertEqual('4 Sep – 3 Oct');
      expect(claimPeriodText('2026-12-25..2027-01-23')).assertEqual('25 Dec – 23 Jan');
      expect(claimPeriodText('last month')).assertEqual('last month');
      expect(claimPeriodText('2026-13-04..2026-10-03')).assertEqual('2026-13-04..2026-10-03');
      expect(claimTierLine('C', true)).assertEqual('Tier C · Eligible: yes');
      expect(keySourceLabel('SOFTWARE')).assertEqual('Software key');
      expect(CHECK_LABELS.length).assertEqual(5);
      const unknown = new VerifyResult();
      unknown.step = 2;
      unknown.status = 'Unknown key';
      expect(states(unknown)).assertEqual('passed,failed,notRun,notRun,notRun');
      expect(checkRows(unknown)[1].state).assertEqual(CheckState.FAILED);
      expect(verdictLine(unknown)).assertEqual('Unknown key · stopped at: known key');
    });
  });
}
