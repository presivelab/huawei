import {
  AddReceiptResult,
  buildVisitClaim,
  DEMO_R1,
  DEMO_R2,
  DemoVisits,
  DeviceHasher,
  DeviceRandom,
  DeviceSigVerifier,
  isIsoDate,
  KEY_SOURCE_HUKS,
  KEY_SOURCE_SOFTWARE,
  KeySigner,
  KeySource,
  mintVisitToken,
  MockReceiptVerifier,
  NONCE_TTL_MS,
  ProofSigner,
  RuleBasedNotesExtractor,
  SystemClock,
  Visit,
  VisitBook,
  VisitClaim,
  VISITS_PERSONA_ID,
  VisitVerifier,
  VisitVerifyResult
} from 'common';
import { reportService } from '../report/ServiceLocator';

/*
 * Visits on the phone: the user's visits, the code of one visit for a partner, and the partner of the demo.
 *
 * State lives in memory, like the report sessions: a restart or "Reset demo" goes back to Ewa's two
 * visits (the check-up and its follow-up, added and linked). The receipt register is the demo's stand-in
 * for the issuer's platform; the notes come from fixed rules; the code is signed with the same device
 * key as a tier claim (ProofSigner). The partner side is a VisitVerifier that lives in the same app for
 * the demo and shares nothing with the phone side but the token text and the registered public key.
 */

export const KEY_VISITS_REVISION: string = 'fwVisitsRevision';   // bumped when a visit or the code changes

// A code this close to the end of its nonce's life is replaced when the share screen opens.
const EXPIRY_MARGIN_MS: number = 60 * 1000;
const PERIOD_ISO_CHARS: number = 22;

/** One shown visit code. Never changed after it is made: a used code is a new object. */
export class VisitCode {
  visitId: string;
  token: string;
  claim: VisitClaim;
  keySource: string;      // KEY_SOURCE_HUKS or KEY_SOURCE_SOFTWARE
  issuedAtMs: number;
  used: boolean;

  constructor(visitId: string, token: string, claim: VisitClaim, keySource: string, issuedAtMs: number,
    used: boolean) {
    this.visitId = visitId;
    this.token = token;
    this.claim = claim;
    this.keySource = keySource;
    this.issuedAtMs = issuedAtMs;
    this.used = used;
  }
}

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

// The demo date: the last day of the report period ("2026-09-04..2026-10-03"), so the visits sit in the
// same month as the report. The device's date when the report has no period.
function demoToday(): string {
  const period = reportService().report(VISITS_PERSONA_ID).periodIso;
  const last = period.length === PERIOD_ISO_CHARS ? period.substring(12, PERIOD_ISO_CHARS) : '';
  if (isIsoDate(last)) {
    return last;
  }
  const d = new Date();
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
}

function newBook(): VisitBook {
  const demo = new DemoVisits(demoToday());
  return new VisitBook(demo, new MockReceiptVerifier(demo.register()), new RuleBasedNotesExtractor());
}

export class VisitService {
  private static instance: VisitService | null = null;

  private clock: SystemClock = new SystemClock();
  private hasher: DeviceHasher = new DeviceHasher();
  private partner: VisitVerifier = new VisitVerifier(new DeviceRandom(), this.clock, new DeviceSigVerifier());
  private book: VisitBook = newBook();
  private seeded: Promise<void> | null = null;
  private code: VisitCode | null = null;
  private revision: number = 0;

  static shared(): VisitService {
    if (VisitService.instance === null) {
      VisitService.instance = new VisitService();
    }
    return VisitService.instance;
  }

  /** Loads Ewa's two visits the first time it is called. Screens wait for it before they read. */
  ready(): Promise<void> {
    let seeded = this.seeded;
    if (seeded === null) {
      seeded = this.seed(this.book);
      this.seeded = seeded;
    }
    return seeded;
  }

  /** The demo date the receipts are counted from; fixed until the next reset. */
  today(): string {
    return this.book.today();
  }

  /** The visits of one persona, newest first. Empty for everyone but Ewa until a receipt is added. */
  visits(personaId: string): Visit[] {
    return this.book.visits(personaId);
  }

  visit(id: string): Visit | null {
    return this.book.visit(id);
  }

  async addReceiptFromQr(personaId: string, text: string): Promise<AddReceiptResult> {
    await this.ready();
    const result = await this.book.addReceiptFromQr(personaId, text);
    this.bump();
    return result;
  }

  /** One of the demo receipts; a receipt that is already in the list is not added twice. */
  async addDemoReceipt(personaId: string, demoId: string): Promise<AddReceiptResult> {
    await this.ready();
    const result = await this.book.addDemoReceipt(personaId, demoId);
    this.bump();
    return result;
  }

  /** The claim of one visit for this nonce. Throws for a visit that may not be shared. */
  async buildVisitClaim(visitId: string, nonce: string): Promise<VisitClaim> {
    const visit = this.book.visit(visitId);
    if (visit === null) {
      throw new Error('No such visit');
    }
    const key = await ProofSigner.shared().ensureKey();
    return buildVisitClaim(visit, this.book.visits(visit.personaId), nonce, this.clock.nowMs(), key.kid, this.hasher);
  }

  /** The code on screen, or null before the first one. */
  current(): VisitCode | null {
    return this.code;
  }

  /*
   * The code of one visit for the partner: the nonce comes from the demo partner, the claim is signed
   * with the device key. An unused code of the same visit is kept while its nonce is alive, and a used
   * one until the user asks for a new one (`fresh`). Throws for a visit that may not be shared.
   */
  async codeFor(visitId: string, fresh: boolean): Promise<VisitCode> {
    const now = this.clock.nowMs();
    const have = this.code;
    if (!fresh && have !== null && have.visitId === visitId &&
      (have.used || now - have.issuedAtMs < NONCE_TTL_MS - EXPIRY_MARGIN_MS)) {
      return have;
    }
    const key = await ProofSigner.shared().ensureKey();
    const keySource = key.source === KeySource.HUKS ? KEY_SOURCE_HUKS : KEY_SOURCE_SOFTWARE;
    // The demo partner learns the public key here; a real partner gets it once, when the user enrols.
    this.partner.registerKey(key.kid, key.publicKeyDer, keySource);
    const signer = await KeySigner.create(ProofSigner.ALIAS);
    const nonce = await this.partner.issueNonce();
    const claim = await this.buildVisitClaim(visitId, nonce);
    const token = await mintVisitToken(signer, keySource, claim);
    const made = new VisitCode(visitId, token, claim, keySource, now, false);
    this.code = made;
    this.bump();
    return made;
  }

  /** The partner checks a token. A valid check of the code on screen marks the code used and the visit claimed. */
  async verifyVisitClaim(token: string): Promise<VisitVerifyResult> {
    const result = await this.partner.verify(token);
    const have = this.code;
    if (result.ok && have !== null && have.token === token) {
      this.code = new VisitCode(have.visitId, have.token, have.claim, have.keySource, have.issuedAtMs, true);
      this.book.markClaimed(have.visitId);
      this.bump();
    }
    return result;
  }

  /** Deletes the recording of a visit: transcript and notes. The receipt and the follow-up date stay. */
  deleteTranscript(visitId: string): boolean {
    const done = this.book.deleteTranscript(visitId);
    if (done) {
      this.bump();
    }
    return done;
  }

  /** "Reset demo": Ewa's two visits again, no code, and the partner forgets every nonce and receipt. */
  resetVisits(): void {
    this.book = newBook();
    this.code = null;
    this.partner.reset();
    this.seeded = this.seed(this.book);
    this.bump();
  }

  private async seed(book: VisitBook): Promise<void> {
    try {
      await book.addDemoReceipt(VISITS_PERSONA_ID, DEMO_R1);
      await book.addDemoReceipt(VISITS_PERSONA_ID, DEMO_R2);
    } catch (e) {
      // The list stays empty; the screens show "No visits yet".
    }
    this.bump();
  }

  private bump(): void {
    this.revision += 1;
    AppStorage.setOrCreate<number>(KEY_VISITS_REVISION, this.revision);
  }
}
