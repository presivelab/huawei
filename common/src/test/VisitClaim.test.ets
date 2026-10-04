// The visit claim and its verifier, with real ECDSA P-256 signatures from Node. Not part of
// List.test.ets (the ports come from tools/logic-tests/node-ports.ts), like ClaimVerifier.test.ets.
import { describe, it, expect } from '@ohos/hypium';
import { NodeHasher, NodeRandom, NodeSigner, NodeSigVerifier } from '@fairwear/node-ports';
import { MAX_TOKEN_CHARS } from '../main/ets/claim/ClaimValidation';
import { PartnerVerifier, STATUS_INVALID_FORMAT } from '../main/ets/claim/PartnerVerifier';
import { encodeSignedClaimToken } from '../main/ets/claim/SignedClaimToken';
import { buildTierClaim, encodeTierClaim, TIER_CLAIM_KEYS } from '../main/ets/claim/TierClaimCodec';
import { SignedClaim } from '../main/ets/model/types';
import { b64urlDecode } from '../main/ets/platform/Bytes';
import {
  DEMO_ISSUER_ID,
  DEMO_ISSUER_NAME,
  DEMO_R1,
  DEMO_R2,
  DEMO_R4,
  DEMO_R5,
  demoTranscriptT1,
  DemoVisits,
  VISITS_PERSONA_ID
} from '../main/ets/visits/DemoVisits';
import { RuleBasedNotesExtractor } from '../main/ets/visits/NotesExtractor';
import { MockReceiptVerifier } from '../main/ets/visits/ReceiptVerifier';
import { VisitBook } from '../main/ets/visits/VisitBook';
import {
  buildVisitClaim,
  decodeVisitClaim,
  decodeVisitToken,
  encodeVisitClaim,
  encodeVisitToken,
  mintVisitToken,
  receiptRef,
  tamperedVisitDateToken,
  VISIT_CLAIM_KEYS,
  VISIT_NOT_VERIFIED,
  VISIT_TOKEN_MARKER,
  VISIT_TYPE_NEVER_SHARED,
  VisitClaim,
  visitClaimLine,
  visitShareBlock,
  visitTokenClaim
} from '../main/ets/visits/VisitClaim';
import { Visit } from '../main/ets/visits/VisitTypes';
import {
  VISIT_STATUS_ALREADY_USED,
  VISIT_STATUS_INVALID_FORMAT,
  VISIT_STATUS_INVALID_SIGNATURE,
  VISIT_STATUS_NONCE_MISMATCH,
  VISIT_STATUS_RECEIPT_CLAIMED,
  VISIT_STATUS_UNKNOWN_KEY,
  VISIT_STATUS_VALID,
  VISIT_STATUS_WRONG_TYPE,
  VISIT_VERIFY_STEPS,
  visitCheckRows,
  visitVerdictLine,
  VisitVerifier
} from '../main/ets/visits/VisitVerifier';
import { Clock } from '../main/ets/watchlink/WatchLinkPorts';

const TODAY = '2026-10-03';
const NOW = 1790000000000;

class StepClock implements Clock {
  ms: number = NOW;

  nowMs(): number {
    return this.ms;
  }
}

class Bench {
  clock: StepClock = new StepClock();
  signer: NodeSigner = new NodeSigner();
  hasher: NodeHasher = new NodeHasher();
  verifier: VisitVerifier = new VisitVerifier(new NodeRandom(), this.clock, new NodeSigVerifier());
  book: VisitBook;

  constructor() {
    const demo = new DemoVisits(TODAY);
    this.book = new VisitBook(demo, new MockReceiptVerifier(demo.register()), new RuleBasedNotesExtractor());
    this.verifier.registerKey(this.signer.kid(), b64urlDecode(this.signer.publicKeySpkiB64()), 'SOFTWARE');
  }

  async load(): Promise<void> {
    await this.book.addDemoReceipt(VISITS_PERSONA_ID, DEMO_R1);
    await this.book.addDemoReceipt(VISITS_PERSONA_ID, DEMO_R2);
  }

  visits(): Visit[] {
    return this.book.visits(VISITS_PERSONA_ID);
  }

  visitOf(demoId: string): Visit {
    const record = new DemoVisits(TODAY).record(demoId);
    const all = this.visits();
    for (let i = 0; i < all.length; i++) {
      const r = all[i].receipt;
      if (record !== null && r !== undefined && r.billNo === record.billNo) {
        return all[i];
      }
    }
    throw new Error(`no visit for ${demoId}`);
  }

  claim(demoId: string, nonce: string): Promise<VisitClaim> {
    return buildVisitClaim(this.visitOf(demoId), this.visits(), nonce, NOW, this.signer.kid(), this.hasher);
  }

  /** A token of this visit with a nonce the verifier issued. */
  async token(demoId: string): Promise<string> {
    const nonce = await this.verifier.issueNonce();
    return mintVisitToken(this.signer, 'SOFTWARE', await this.claim(demoId, nonce));
  }

  async status(token: string): Promise<string> {
    const r = await this.verifier.verify(token);
    return r.status;
  }
}

/** The token with another claim text and the old signature. */
function withClaim(token: string, claim: VisitClaim): string {
  const signed = decodeVisitToken(token);
  if (signed === null) {
    throw new Error('test token does not decode');
  }
  signed.claimJson = encodeVisitClaim(claim);
  return encodeVisitToken(signed);
}

function claimOf(token: string): VisitClaim {
  const claim = visitTokenClaim(token);
  if (claim === null) {
    throw new Error('test token carries no claim');
  }
  return claim;
}

async function errorOf(run: () => Promise<VisitClaim>): Promise<string> {
  try {
    await run();
  } catch (e) {
    return (e as Error).message;
  }
  return '';
}

export default function visitClaimTest() {
  describe('Visits: the claim', () => {
    it('has exactly the nine keys, in order, and none of the tier claim', 0, async () => {
      const b = new Bench();
      await b.load();
      const json = encodeVisitClaim(await b.claim(DEMO_R2, await b.verifier.issueNonce()));
      const keys = Object.keys(JSON.parse(json) as Record<string, Object>);
      expect(keys.join(',')).assertEqual('v,type,visitDate,visitType,receiptRef,adherence,nonce,issuedAt,kid');
      expect(keys.join(',')).assertEqual(VISIT_CLAIM_KEYS.join(','));
      expect(VISIT_CLAIM_KEYS.length).assertEqual(9);
      expect(TIER_CLAIM_KEYS.length).assertEqual(7);
    });

    it('R2 states an outpatient visit, its date and a follow-up on time', 0, async () => {
      const b = new Bench();
      await b.load();
      const claim = await b.claim(DEMO_R2, await b.verifier.issueNonce());
      expect(claim.v).assertEqual(1);
      expect(claim.type).assertEqual('visit');
      expect(claim.visitType).assertEqual('OUTPATIENT');
      expect(claim.visitDate).assertEqual('2026-09-30');
      expect(claim.adherence).assertEqual('FOLLOW_UP_ON_TIME');
      expect(visitClaimLine(claim)).assertEqual('Outpatient visit · 30 Sep 2026 · Follow-up on time');
      const r1 = await b.claim(DEMO_R1, await b.verifier.issueNonce());
      expect(r1.visitType).assertEqual('CHECKUP');
      expect(r1.adherence).assertEqual('NONE');
    });

    it('carries no amount, no clinic, no issuer id, no bill number and no word of the transcript', 0, async () => {
      const b = new Bench();
      await b.load();
      const json = encodeVisitClaim(await b.claim(DEMO_R1, await b.verifier.issueNonce()));
      const receipt = b.visitOf(DEMO_R1).receipt;
      expect(receipt === undefined).assertFalse();
      if (receipt !== undefined) {
        expect(json.indexOf(receipt.amount)).assertEqual(-1);
        expect(json.indexOf(receipt.billNo)).assertEqual(-1);
        expect(json.indexOf(receipt.billCode)).assertEqual(-1);
        expect(json.indexOf(receipt.checkCode)).assertEqual(-1);
        expect(json.indexOf(receipt.payerNameMasked)).assertEqual(-1);
      }
      expect(json.indexOf(DEMO_ISSUER_NAME)).assertEqual(-1);
      expect(json.indexOf('Hangzhou')).assertEqual(-1);
      expect(json.indexOf(DEMO_ISSUER_ID)).assertEqual(-1);
      const t = demoTranscriptT1();
      for (let i = 0; i < t.length; i++) {
        expect(json.indexOf(t[i].text)).assertEqual(-1);
      }
      expect(json.toLowerCase().indexOf('vitamin')).assertEqual(-1);
      expect(json.toLowerCase().indexOf('lipid')).assertEqual(-1);
      const notes = b.visitOf(DEMO_R1).notes;
      expect(notes !== undefined && notes.length > 0).assertTrue();
    });

    it('the receipt reference is 16 hex characters, the same every time, different per receipt', 0, async () => {
      const b = new Bench();
      await b.load();
      const r1 = b.visitOf(DEMO_R1).receipt;
      const r2 = b.visitOf(DEMO_R2).receipt;
      if (r1 === undefined || r2 === undefined) {
        throw new Error('receipts missing');
      }
      const a = await receiptRef(r1, b.hasher);
      const again = await receiptRef(r1, new NodeHasher());
      const other = await receiptRef(r2, b.hasher);
      expect(new RegExp('^[0-9a-f]{16}$').test(a)).assertTrue();
      expect(again).assertEqual(a);
      expect(other === a).assertFalse();
      const first = await b.claim(DEMO_R1, await b.verifier.issueNonce());
      const second = await b.claim(DEMO_R1, await b.verifier.issueNonce());
      expect(first.receiptRef).assertEqual(a);
      expect(second.receiptRef).assertEqual(a);
    });

    it('an emergency visit verifies and is never shared', 0, async () => {
      const b = new Bench();
      await b.load();
      const added = await b.book.addDemoReceipt(VISITS_PERSONA_ID, DEMO_R5);
      expect(added.status).assertEqual('VERIFIED');
      expect(visitShareBlock(b.visitOf(DEMO_R5))).assertEqual(VISIT_TYPE_NEVER_SHARED);
      const message = await errorOf(() => b.claim(DEMO_R5, 'AAAAAAAAAAAAAAAAAAAAAA'));
      expect(message).assertEqual('This visit type is never shared with partners');
    });

    it('a visit whose receipt did not verify cannot be shared', 0, async () => {
      const b = new Bench();
      await b.load();
      await b.book.addDemoReceipt(VISITS_PERSONA_ID, DEMO_R4);
      expect(b.visitOf(DEMO_R4).receiptStatus).assertEqual('EXPIRED');
      const message = await errorOf(() => b.claim(DEMO_R4, 'AAAAAAAAAAAAAAAAAAAAAA'));
      expect(message).assertEqual(VISIT_NOT_VERIFIED);
      const bare: Visit = { id: 'x', personaId: VISITS_PERSONA_ID, claimed: false };
      expect(visitShareBlock(bare)).assertEqual(VISIT_NOT_VERIFIED);
    });

    it('the token starts with fv1, fits in 512 characters and decodes to the same claim', 0, async () => {
      const b = new Bench();
      await b.load();
      const token = await b.token(DEMO_R2);
      expect(token.substring(0, 4)).assertEqual('fv1.');
      expect(VISIT_TOKEN_MARKER).assertEqual('fv1');
      expect(token.length <= MAX_TOKEN_CHARS).assertTrue();
      expect(token.length <= 512).assertTrue();
      const signed = decodeVisitToken(token);
      expect(signed === null).assertFalse();
      if (signed !== null) {
        const claim = decodeVisitClaim(signed.claimJson);
        expect(claim === null).assertFalse();
        if (claim !== null) {
          expect(encodeVisitClaim(claim)).assertEqual(signed.claimJson);
        }
      }
    });
  });

  describe('Visits: the partner check', () => {
    it('a good token: signature valid, the claim is returned', 0, async () => {
      const b = new Bench();
      await b.load();
      const r = await b.verifier.verify(await b.token(DEMO_R2));
      expect(r.status).assertEqual(VISIT_STATUS_VALID);
      expect(r.status).assertEqual('Signature valid');
      expect(r.ok).assertTrue();
      expect(r.step).assertEqual(8);
      expect(r.keySource).assertEqual('SOFTWARE');
      const claim = r.claim;
      expect(claim === null).assertFalse();
      if (claim !== null) {
        expect(claim.adherence).assertEqual('FOLLOW_UP_ON_TIME');
      }
      expect(visitCheckRows(r).length).assertEqual(7);
      expect(visitVerdictLine(r)).assertEqual('Signature valid');
    });

    it('the order of the checks is fixed', 0, () => {
      expect(VISIT_VERIFY_STEPS.join(' > ')).assertEqual('Invalid format > Wrong claim type > Unknown key > ' +
        'Invalid signature > Nonce mismatch > Already used > Receipt already claimed > Signature valid');
    });

    it('a changed visit type breaks the signature', 0, async () => {
      const b = new Bench();
      await b.load();
      const token = await b.token(DEMO_R2);
      const claim = claimOf(token);
      claim.visitType = 'CHECKUP';
      const r = await b.verifier.verify(withClaim(token, claim));
      expect(r.status).assertEqual(VISIT_STATUS_INVALID_SIGNATURE);
      expect(r.step).assertEqual(4);
      expect(r.claim).assertNull();
      expect(visitVerdictLine(r)).assertEqual('Invalid signature · stopped at: signature');
    });

    it('a changed visit date breaks the signature (the demo step)', 0, async () => {
      const b = new Bench();
      await b.load();
      const token = await b.token(DEMO_R2);
      const forged = tamperedVisitDateToken(token);
      expect(forged === null).assertFalse();
      if (forged !== null) {
        expect(claimOf(forged).visitDate).assertEqual('2026-10-01');
        expect(await b.status(forged)).assertEqual(VISIT_STATUS_INVALID_SIGNATURE);
      }
      // The untouched token is still good afterwards.
      expect(await b.status(token)).assertEqual(VISIT_STATUS_VALID);
    });

    it('a changed nonce inside the token breaks the signature', 0, async () => {
      const b = new Bench();
      await b.load();
      const token = await b.token(DEMO_R2);
      const claim = claimOf(token);
      claim.nonce = await b.verifier.issueNonce();
      expect(await b.status(withClaim(token, claim))).assertEqual(VISIT_STATUS_INVALID_SIGNATURE);
    });

    it('a nonce this partner did not issue is a nonce mismatch', 0, async () => {
      const b = new Bench();
      await b.load();
      const other = new VisitVerifier(new NodeRandom(), b.clock, new NodeSigVerifier());
      const foreign = await other.issueNonce();
      const token = await mintVisitToken(b.signer, 'SOFTWARE', await b.claim(DEMO_R2, foreign));
      const r = await b.verifier.verify(token);
      expect(r.status).assertEqual(VISIT_STATUS_NONCE_MISMATCH);
      expect(r.step).assertEqual(5);
    });

    it('the same token twice is already used', 0, async () => {
      const b = new Bench();
      await b.load();
      const token = await b.token(DEMO_R2);
      expect(await b.status(token)).assertEqual(VISIT_STATUS_VALID);
      const again = await b.verifier.verify(token);
      expect(again.status).assertEqual(VISIT_STATUS_ALREADY_USED);
      expect(again.step).assertEqual(6);
    });

    it('a new token from the same receipt is refused: receipt already claimed', 0, async () => {
      const b = new Bench();
      await b.load();
      const first = await b.token(DEMO_R2);
      expect(await b.status(first)).assertEqual(VISIT_STATUS_VALID);
      expect(b.verifier.isReceiptClaimed(claimOf(first).receiptRef)).assertTrue();
      const second = await b.token(DEMO_R2);
      expect(second === first).assertFalse();
      const r = await b.verifier.verify(second);
      expect(r.status).assertEqual(VISIT_STATUS_RECEIPT_CLAIMED);
      expect(r.step).assertEqual(7);
      // Another receipt is still accepted.
      expect(await b.status(await b.token(DEMO_R1))).assertEqual(VISIT_STATUS_VALID);
    });

    it('a failed check does not claim the receipt', 0, async () => {
      const b = new Bench();
      await b.load();
      const token = await b.token(DEMO_R2);
      const forged = tamperedVisitDateToken(token);
      if (forged !== null) {
        expect(await b.status(forged)).assertEqual(VISIT_STATUS_INVALID_SIGNATURE);
      }
      expect(b.verifier.isReceiptClaimed(claimOf(token).receiptRef)).assertFalse();
      expect(await b.status(token)).assertEqual(VISIT_STATUS_VALID);
    });

    it('a tier token (fw1) is the wrong claim type', 0, async () => {
      const b = new Bench();
      await b.load();
      const nonce = await b.verifier.issueNonce();
      const claimJson = encodeTierClaim(buildTierClaim('2026-09-04..2026-10-03', 'C', false, nonce, NOW, b.signer.kid()));
      const signed: SignedClaim = {
        claimJson: claimJson,
        sigB64: await b.signer.sign(claimJson),
        kid: b.signer.kid(),
        keySource: 'SOFTWARE'
      };
      const r = await b.verifier.verify(encodeSignedClaimToken(signed));
      expect(r.status).assertEqual(VISIT_STATUS_WRONG_TYPE);
      expect(r.status).assertEqual('Wrong claim type');
      expect(r.step).assertEqual(2);
    });

    it('a visit token is not a tier token: the tier partner refuses it', 0, async () => {
      const b = new Bench();
      await b.load();
      const partner = new PartnerVerifier(new NodeRandom(), b.clock, new NodeSigVerifier());
      partner.registerKey(b.signer.kid(), b64urlDecode(b.signer.publicKeySpkiB64()), 'SOFTWARE');
      const r = await partner.verify(await b.token(DEMO_R2));
      expect(r.status).assertEqual(STATUS_INVALID_FORMAT);
    });

    it('rubbish is an invalid format', 0, async () => {
      const b = new Bench();
      await b.load();
      expect(await b.status('')).assertEqual(VISIT_STATUS_INVALID_FORMAT);
      expect(await b.status('hello')).assertEqual(VISIT_STATUS_INVALID_FORMAT);
      expect(await b.status('fv1.a.b.c.d')).assertEqual(VISIT_STATUS_INVALID_FORMAT);
      const token = await b.token(DEMO_R2);
      expect(await b.status(token + '.x')).assertEqual(VISIT_STATUS_INVALID_FORMAT);
      // A claim of a kind that is never shared is not a valid claim, whoever signed it.
      const claim = claimOf(token);
      claim.visitType = 'EMERGENCY';
      expect(await b.status(withClaim(token, claim))).assertEqual(VISIT_STATUS_INVALID_FORMAT);
    });

    it('a key the partner does not know is an unknown key', 0, async () => {
      const b = new Bench();
      await b.load();
      const token = await b.token(DEMO_R2);
      b.verifier.clearKeys();
      const r = await b.verifier.verify(token);
      expect(r.status).assertEqual(VISIT_STATUS_UNKNOWN_KEY);
      expect(r.step).assertEqual(3);
    });

    it('reset forgets the accepted receipts and the nonces', 0, async () => {
      const b = new Bench();
      await b.load();
      const first = await b.token(DEMO_R2);
      expect(await b.status(first)).assertEqual(VISIT_STATUS_VALID);
      b.verifier.reset();
      expect(await b.status(first)).assertEqual(VISIT_STATUS_NONCE_MISMATCH);
      expect(await b.status(await b.token(DEMO_R2))).assertEqual(VISIT_STATUS_VALID);
    });
  });
}
