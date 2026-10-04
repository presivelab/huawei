// Security tests S-1 to S-20 (plan, appendix D) through the partner verifier, with real ECDSA P-256
// signatures from Node. Not part of List.test.ets (the ports come from tools/logic-tests/node-ports.ts).
// S-19 (setLive does not change the score) is not here: the scoring module is not in this repository.
import { describe, it, expect } from '@ohos/hypium';
import { NodeHasher, NodeRandom, NodeSigner, NodeSigVerifier } from '@fairwear/node-ports';
import { SignedClaim } from '../main/ets/model/types';
import { buildTierClaim, encodeTierClaim, TIER_CLAIM_KEYS } from '../main/ets/claim/TierClaimCodec';
import { MAX_DER_SIGNATURE_BYTES, MAX_FUTURE_SKEW_MS, TIER_NO_SCORE } from '../main/ets/claim/ClaimValidation';
import { decodeSignedClaimToken, encodeSignedClaimToken } from '../main/ets/claim/SignedClaimToken';
import {
  NONCE_TTL_MS,
  PartnerVerifier,
  RandomSource,
  STATUS_ALREADY_USED,
  STATUS_INVALID_FORMAT,
  STATUS_INVALID_SIGNATURE,
  STATUS_NONCE_MISMATCH,
  STATUS_UNKNOWN_KEY,
  STATUS_VALID,
  VERIFY_STEPS,
  VerifyResult
} from '../main/ets/claim/PartnerVerifier';
import { b64urlDecode, b64urlEncode } from '../main/ets/platform/Bytes';
import { Clock } from '../main/ets/watchlink/WatchLinkPorts';

const NOW = 1790000000000;
const PERIOD = '2026-09-03..2026-10-02';
// The order of the P-256 group.
const P256_N = BigInt('0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551');

class StepClock implements Clock {
  ms: number = NOW;

  nowMs(): number {
    return this.ms;
  }
}

class CountingRandom implements RandomSource {
  inner: NodeRandom = new NodeRandom();
  calls: number = 0;

  randomBytes(count: number): Promise<Uint8Array> {
    this.calls++;
    return this.inner.randomBytes(count);
  }
}

class Bench {
  clock: StepClock = new StepClock();
  random: CountingRandom = new CountingRandom();
  signer: NodeSigner = new NodeSigner();
  verifier: PartnerVerifier;

  constructor(source: string = 'SOFTWARE') {
    this.verifier = new PartnerVerifier(this.random, this.clock, new NodeSigVerifier());
    this.verifier.registerKey(this.signer.kid(), b64urlDecode(this.signer.publicKeySpkiB64()), source);
  }

  claimJson(nonce: string, tier: string = 'B', eligible: boolean = true, issuedAt: number = NOW,
    kid: string = this.signer.kid()): string {
    return encodeTierClaim(buildTierClaim(PERIOD, tier, eligible, nonce, issuedAt, kid));
  }

  /** A token whose signature is real over exactly this claim text. */
  async mint(claimJson: string, envelopeKid: string = this.signer.kid(),
    keySource: string = 'SOFTWARE'): Promise<string> {
    const sig = await this.signer.sign(claimJson);
    const signed: SignedClaim = { claimJson: claimJson, sigB64: sig, kid: envelopeKid, keySource: keySource };
    return encodeSignedClaimToken(signed);
  }

  async issueAndMint(): Promise<string> {
    const nonce = await this.verifier.issueNonce();
    return this.mint(this.claimJson(nonce));
  }

  async status(token: string): Promise<string> {
    const r = await this.verifier.verify(token);
    return r.status;
  }
}

function tokenWith(token: string, claimJson: string): string {
  const signed = decodeSignedClaimToken(token);
  if (signed === null) {
    throw new Error('test token does not decode');
  }
  signed.claimJson = claimJson;
  return encodeSignedClaimToken(signed);
}

function bigToBytes(value: bigint): number[] {
  let hex = value.toString(16);
  if (hex.length % 2 === 1) {
    hex = '0' + hex;
  }
  const out: number[] = [];
  for (let i = 0; i < hex.length; i += 2) {
    out.push(parseInt(hex.substring(i, i + 2), 16));
  }
  return out;
}

function derInteger(value: bigint): number[] {
  const bytes = bigToBytes(value);
  if (bytes[0] >= 0x80) {
    bytes.unshift(0);
  }
  return [0x02, bytes.length].concat(bytes);
}

/** The same signature with s replaced by n - s: still valid ECDSA, different bytes. */
function malleate(sigB64: string): string {
  const der = b64urlDecode(sigB64);
  const rLen = der[3];
  const r = der.slice(4, 4 + rLen);
  const sLen = der[5 + rLen];
  const s = der.slice(6 + rLen, 6 + rLen + sLen);
  let sValue = BigInt(0);
  for (let i = 0; i < s.length; i++) {
    sValue = sValue * BigInt(256) + BigInt(s[i]);
  }
  let rValue = BigInt(0);
  for (let i = 0; i < r.length; i++) {
    rValue = rValue * BigInt(256) + BigInt(r[i]);
  }
  const body = derInteger(rValue).concat(derInteger(P256_N - sValue));
  return b64urlEncode(new Uint8Array([0x30, body.length].concat(body)));
}

export default function claimVerifierTest() {
  describe('PartnerVerifier S-1 to S-20', () => {
    it('S-0 happy path: signature valid, the claim is returned, the nonce is single use', 0, async () => {
      const b = new Bench();
      const token = await b.issueAndMint();
      const r = await b.verifier.verify(token);
      expect(r.status).assertEqual(STATUS_VALID);
      expect(r.ok).assertTrue();
      expect(r.step).assertEqual(6);
      expect(r.claim !== null).assertTrue();
      expect(VERIFY_STEPS.length).assertEqual(6);
    });

    it('S-1 empty string', 0, async () => {
      const b = new Bench();
      const r = await b.verifier.verify('');
      expect(r.status).assertEqual(STATUS_INVALID_FORMAT);
      expect(r.step).assertEqual(1);
    });

    it('S-2 token of 513 characters is refused without JSON.parse', 0, async () => {
      const b = new Bench();
      const token = await b.issueAndMint();
      const long = token + 'A'.repeat(513 - token.length);
      expect(long.length).assertEqual(513);
      const original = JSON.parse;
      let parseCalls = 0;
      JSON.parse = (): never => {
        parseCalls++;
        throw new Error('JSON.parse must not run');
      };
      let status = '';
      try {
        status = await b.status(long);
      } finally {
        JSON.parse = original;
      }
      expect(status).assertEqual(STATUS_INVALID_FORMAT);
      expect(parseCalls).assertEqual(0);
    });

    it('S-3 not JSON, emoji', 0, async () => {
      const b = new Bench();
      const texts: string[] = ['not json', '{not json', '\u{1F600}\u{1F600}', 'fw1.\u{1F600}.AAAA.762fa82f.SOFTWARE'];
      for (let i = 0; i < texts.length; i++) {
        expect(await b.status(texts[i])).assertEqual(STATUS_INVALID_FORMAT);
      }
      // A well-formed envelope around text that is not JSON, and around an emoji.
      const notJson = await b.mint('this is not json');
      expect(await b.status(notJson)).assertEqual(STATUS_INVALID_FORMAT);
      const emoji = await b.mint('{"v":1,"period":"\u{1F600}"}');
      expect(await b.status(emoji)).assertEqual(STATUS_INVALID_FORMAT);
    });

    it('S-4 each of the seven keys missing', 0, async () => {
      const b = new Bench();
      const nonce = await b.verifier.issueNonce();
      const good = b.claimJson(nonce);
      const parsed = JSON.parse(good) as Record<string, Object>;
      for (let i = 0; i < TIER_CLAIM_KEYS.length; i++) {
        const copy: Record<string, Object> = {};
        for (let k = 0; k < TIER_CLAIM_KEYS.length; k++) {
          if (k !== i) {
            copy[TIER_CLAIM_KEYS[k]] = parsed[TIER_CLAIM_KEYS[k]];
          }
        }
        const token = await b.mint(JSON.stringify(copy));
        expect(await b.status(token)).assertEqual(STATUS_INVALID_FORMAT);
      }
    });

    it('S-5 an extra key', 0, async () => {
      const b = new Bench();
      const nonce = await b.verifier.issueNonce();
      const good = b.claimJson(nonce);
      const token = await b.mint(good.substring(0, good.length - 1) + ',"score":87}');
      expect(await b.status(token)).assertEqual(STATUS_INVALID_FORMAT);
    });

    it('S-6 a repeated tier key', 0, async () => {
      const b = new Bench();
      const nonce = await b.verifier.issueNonce();
      const good = b.claimJson(nonce);
      const token = await b.mint(good.replace('"tier":"B",', '"tier":"B","tier":"B",'));
      expect(await b.status(token)).assertEqual(STATUS_INVALID_FORMAT);
      const swapped = await b.mint(good.replace('"tier":"B",', '"tier":"A","tier":"B",'));
      expect(await b.status(swapped)).assertEqual(STATUS_INVALID_FORMAT);
    });

    it('S-7 non-canonical spaces and key order', 0, async () => {
      const b = new Bench();
      const nonce = await b.verifier.issueNonce();
      const good = b.claimJson(nonce);
      const spaced = await b.mint(good.replace(',"tier"', ', "tier"'));
      expect(await b.status(spaced)).assertEqual(STATUS_INVALID_FORMAT);
      const parsed = JSON.parse(good) as Record<string, Object>;
      const reversed: Record<string, Object> = {};
      for (let i = TIER_CLAIM_KEYS.length - 1; i >= 0; i--) {
        reversed[TIER_CLAIM_KEYS[i]] = parsed[TIER_CLAIM_KEYS[i]];
      }
      const reordered = await b.mint(JSON.stringify(reversed));
      expect(await b.status(reordered)).assertEqual(STATUS_INVALID_FORMAT);
    });

    it('S-8 tier S, bad nonce, bad kid, issuedAt in the future (and the other format rules)', 0, async () => {
      const b = new Bench();
      const nonce = await b.verifier.issueNonce();
      const badTier = await b.mint(b.claimJson(nonce, 'S'));
      const badNonce = await b.mint(b.claimJson(nonce + 'x'));
      const badKid = await b.mint(b.claimJson(nonce, 'B', true, NOW, '762FA82F'), '762FA82F');
      const future = await b.mint(b.claimJson(nonce, 'B', true, NOW + MAX_FUTURE_SKEW_MS + 1));
      const zero = await b.mint(b.claimJson(nonce, 'B', true, 0));
      const fraction = await b.mint(b.claimJson(nonce, 'B', true, NOW + 0.5));
      const noScoreEligible = await b.mint(b.claimJson(nonce, TIER_NO_SCORE, true));
      const wrongVersion = await b.mint(b.claimJson(nonce).replace('"v":1', '"v":2'));
      const badPeriod = await b.mint(b.claimJson(nonce).replace(PERIOD, '2026-09-03'));
      const all: string[] = [badTier, badNonce, badKid, future, zero, fraction, noScoreEligible, wrongVersion,
        badPeriod];
      for (let i = 0; i < all.length; i++) {
        expect(await b.status(all[i])).assertEqual(STATUS_INVALID_FORMAT);
      }
      // The same checks leave a good claim alone: five minutes ahead is still accepted.
      const edge = await b.mint(b.claimJson(nonce, 'B', true, NOW + MAX_FUTURE_SKEW_MS));
      expect(await b.status(edge)).assertEqual(STATUS_VALID);
    });

    it('S-8b a DER signature longer than 72 bytes is refused before the key lookup', 0, async () => {
      const b = new Bench();
      const nonce = await b.verifier.issueNonce();
      const claimJson = b.claimJson(nonce);
      const body: number[] = [];
      while (body.length < MAX_DER_SIGNATURE_BYTES - 1) {
        body.push(0x01);
      }
      const longSig = b64urlEncode(new Uint8Array([0x30, body.length].concat(body)));
      expect(b64urlDecode(longSig).length).assertEqual(MAX_DER_SIGNATURE_BYTES + 1);
      const signed: SignedClaim = { claimJson: claimJson, sigB64: longSig, kid: b.signer.kid(),
        keySource: 'SOFTWARE' };
      const token = encodeSignedClaimToken(signed);
      const r = await b.verifier.verify(token);
      expect(r.status).assertEqual(STATUS_INVALID_FORMAT);
      expect(r.keySource).assertEqual('');
    });

    it('S-9 kid in the envelope differs from the kid in the claim', 0, async () => {
      const b = new Bench();
      b.verifier.registerKey('deadbeef', b64urlDecode(b.signer.publicKeySpkiB64()), 'SOFTWARE');
      const nonce = await b.verifier.issueNonce();
      const token = await b.mint(b.claimJson(nonce), 'deadbeef');
      expect(await b.status(token)).assertEqual(STATUS_INVALID_FORMAT);
    });

    it('S-10 unknown kid', 0, async () => {
      const b = new Bench();
      const nonce = await b.verifier.issueNonce();
      const token = await b.mint(b.claimJson(nonce, 'B', true, NOW, 'deadbeef'), 'deadbeef');
      const r = await b.verifier.verify(token);
      expect(r.status).assertEqual(STATUS_UNKNOWN_KEY);
      expect(r.step).assertEqual(2);
      expect(r.claim === null).assertTrue();
    });

    it('S-11 changed tier', 0, async () => {
      const b = new Bench();
      const token = await b.issueAndMint();
      const decoded = decodeSignedClaimToken(token);
      expect(decoded !== null).assertTrue();
      if (decoded !== null) {
        const forged = tokenWith(token, decoded.claimJson.replace('"tier":"B"', '"tier":"A"'));
        const r = await b.verifier.verify(forged);
        expect(r.status).assertEqual(STATUS_INVALID_SIGNATURE);
        expect(r.step).assertEqual(3);
        expect(r.claim === null).assertTrue();
      }
    });

    it('S-12 changed nonce', 0, async () => {
      const b = new Bench();
      const nonce = await b.verifier.issueNonce();
      const other = await b.verifier.issueNonce();
      const token = await b.mint(b.claimJson(nonce));
      const forged = tokenWith(token, b.claimJson(other));
      expect(await b.status(forged)).assertEqual(STATUS_INVALID_SIGNATURE);
    });

    it('S-13 nonce the partner never issued', 0, async () => {
      const b = new Bench();
      const token = await b.mint(b.claimJson('AAAAAAAAAAAAAAAAAAAAAA'));
      const r = await b.verifier.verify(token);
      expect(r.status).assertEqual(STATUS_NONCE_MISMATCH);
      expect(r.step).assertEqual(4);
    });

    it('S-14 nonce older than the time limit', 0, async () => {
      const b = new Bench();
      const nonce = await b.verifier.issueNonce();
      b.clock.ms = NOW + NONCE_TTL_MS + 1000;
      const token = await b.mint(b.claimJson(nonce, 'B', true, b.clock.ms));
      expect(await b.status(token)).assertEqual(STATUS_NONCE_MISMATCH);
    });

    it('S-14b a nonce just inside the time limit still works', 0, async () => {
      const b = new Bench();
      const nonce = await b.verifier.issueNonce();
      b.clock.ms = NOW + NONCE_TTL_MS;
      const token = await b.mint(b.claimJson(nonce, 'B', true, b.clock.ms));
      expect(await b.status(token)).assertEqual(STATUS_VALID);
    });

    it('S-15 the same token a second time', 0, async () => {
      const b = new Bench();
      const token = await b.issueAndMint();
      expect(await b.status(token)).assertEqual(STATUS_VALID);
      const again = await b.verifier.verify(token);
      expect(again.status).assertEqual(STATUS_ALREADY_USED);
      expect(again.step).assertEqual(5);
      // Also after the time limit: a used nonce reports "Already used", not "Nonce mismatch".
      b.clock.ms = NOW + NONCE_TTL_MS * 3;
      expect(await b.status(token)).assertEqual(STATUS_ALREADY_USED);
    });

    it('S-16 replay with the signature (r, n - s) is recognised by nonce', 0, async () => {
      const b = new Bench();
      const nonce = await b.verifier.issueNonce();
      const claimJson = b.claimJson(nonce);
      const token = await b.mint(claimJson);
      const signed = decodeSignedClaimToken(token);
      expect(signed !== null).assertTrue();
      if (signed === null) {
        return;
      }
      const twin = malleate(signed.sigB64);
      expect(twin === signed.sigB64).assertFalse();
      // The second signature is genuinely valid for the same claim, so only the nonce can catch the replay.
      expect(await new NodeSigVerifier().verify(b.signer.publicKeySpkiB64(), claimJson, twin)).assertTrue();
      const twinToken = encodeSignedClaimToken({ claimJson: claimJson, sigB64: twin, kid: signed.kid,
        keySource: signed.keySource });
      expect(await b.status(token)).assertEqual(STATUS_VALID);
      const replay = await b.verifier.verify(twinToken);
      expect(replay.status).assertEqual(STATUS_ALREADY_USED);
      expect(replay.step).assertEqual(5);
    });

    it('S-17 the token carries no score, coverage, flag or health value', 0, async () => {
      const b = new Bench();
      const token = await b.issueAndMint();
      const signed = decodeSignedClaimToken(token);
      expect(signed !== null).assertTrue();
      if (signed === null) {
        return;
      }
      const parsed = JSON.parse(signed.claimJson) as Record<string, Object>;
      expect(Object.keys(parsed).length).assertEqual(7);
      const text = (signed.claimJson + token).toLowerCase();
      const banned = ['hes', 'coverage', 'flag', 'susp', 'reason', 'score', 'heart', 'steps', 'hrv', 'vo2',
        'compliance', 'pseudonym', 'persona'];
      for (let i = 0; i < banned.length; i++) {
        expect(text.indexOf(banned[i])).assertEqual(-1);
      }
      expect(await b.status(token)).assertEqual(STATUS_VALID);
      expect(token.length <= 512).assertTrue();
    });

    it('S-18 1000 nonces: unique, 22 characters, base64url, no Math.random', 0, async () => {
      const b = new Bench();
      const seen = new Set<string>();
      const original = Math.random;
      Math.random = (): number => {
        throw new Error('Math.random must not be used for nonces');
      };
      try {
        for (let i = 0; i < 1000; i++) {
          const nonce = await b.verifier.issueNonce();
          expect(nonce.length).assertEqual(22);
          expect(new RegExp('^[A-Za-z0-9_-]{22}$').test(nonce)).assertTrue();
          seen.add(nonce);
        }
      } finally {
        Math.random = original;
      }
      expect(seen.size).assertEqual(1000);
      expect(b.random.calls).assertEqual(1000);
    });

    // S-19 (setLive(200, 99999) leaves the score unchanged) is skipped: the scoring module (HES-Lite) is not
    // in this repository, so there is no score to compare.

    it('S-20 the key source comes from the registry, not from the token', 0, async () => {
      const b = new Bench('SOFTWARE');
      const nonce = await b.verifier.issueNonce();
      const token = await b.mint(b.claimJson(nonce), b.signer.kid(), 'HUKS');
      const signed = decodeSignedClaimToken(token);
      expect(signed !== null && signed.keySource === 'HUKS').assertTrue();
      const r = await b.verifier.verify(token);
      expect(r.status).assertEqual(STATUS_VALID);
      expect(r.keySource).assertEqual('SOFTWARE');
    });

    it('the result names the key source of the registry also when the signature fails', 0, async () => {
      const b = new Bench('HUKS');
      const token = await b.issueAndMint();
      const decoded = decodeSignedClaimToken(token);
      if (decoded !== null) {
        const r: VerifyResult = await b.verifier.verify(tokenWith(token, decoded.claimJson.replace('"B"', '"C"')));
        expect(r.status).assertEqual(STATUS_INVALID_SIGNATURE);
        expect(r.keySource).assertEqual('HUKS');
      }
    });

    it('a cleared registry knows no key', 0, async () => {
      const b = new Bench();
      const token = await b.issueAndMint();
      b.verifier.clearKeys();
      expect(await b.status(token)).assertEqual(STATUS_UNKNOWN_KEY);
    });
  });
  describe('PartnerVerifier key registry', () => {
    it('another key under a kid already enrolled is refused; the first key keeps working', 0, async () => {
      const b = new Bench();
      const intruder = new NodeSigner();
      // Registered under the victim's kid: refused, the registry is unchanged.
      expect(b.verifier.registerKey(b.signer.kid(), b64urlDecode(intruder.publicKeySpkiB64()), 'HUKS'))
        .assertFalse();
      const nonce = await b.verifier.issueNonce();
      expect(await b.status(await b.mint(b.claimJson(nonce)))).assertEqual(STATUS_VALID);
      // The same key again is fine.
      expect(b.verifier.registerKey(b.signer.kid(), b64urlDecode(b.signer.publicKeySpkiB64()), 'SOFTWARE'))
        .assertTrue();
    });

    it('enrolment works the kid out from the key, never from the device', 0, async () => {
      const b = new Bench();
      const other = new NodeSigner();
      const kid = await b.verifier.enrolKey(b64urlDecode(other.publicKeySpkiB64()), 'SOFTWARE', new NodeHasher());
      expect(kid).assertEqual(other.kid());
      // Enrolling the already registered key again gives its kid back.
      expect(await b.verifier.enrolKey(b64urlDecode(b.signer.publicKeySpkiB64()), 'SOFTWARE', new NodeHasher()))
        .assertEqual(b.signer.kid());
    });
  });
}
