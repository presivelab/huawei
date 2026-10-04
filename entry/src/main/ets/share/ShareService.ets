import {
  claimLedgerEntry,
  DeviceHasher,
  DeviceRandom,
  DeviceSigVerifier,
  FileTextStore,
  KEY_SOURCE_HUKS,
  KEY_SOURCE_SOFTWARE,
  KeySigner,
  KeySource,
  LedgerEntry,
  mintClaimToken,
  NONCE_TTL_MS,
  PartnerVerifier,
  PersonaReport,
  ProofSigner,
  shareOffer,
  SystemClock,
  TierClaim,
  tokenClaim,
  VerifyResult
} from 'common';

/*
 * The code for the partner, and the partner of the demo.
 *
 * The phone side signs a tier claim with the device key (ProofSigner). The partner side is a
 * PartnerVerifier that lives in the same app for the demo: it hands out the nonce, keeps the key registry
 * and checks the token. The two sides share nothing but the token text and the registered public key.
 *
 * Every code that is shown is written to the ledger first ("What left this phone").
 */

export const KEY_SHARE_REVISION: string = 'fwShareRevision';    // bumped when the code or the ledger changes

const LEDGER_FILE: string = 'share/ledger.json';
// A code this close to the end of its nonce's life is replaced when the Share tab opens.
const EXPIRY_MARGIN_MS: number = 60 * 1000;

/** One shown code. Never changed after it is made: a used code is a new object. */
export class ShareCode {
  personaId: string;
  token: string;
  claim: TierClaim;
  keySource: string;      // KEY_SOURCE_HUKS or KEY_SOURCE_SOFTWARE
  issuedAtMs: number;
  used: boolean;

  constructor(personaId: string, token: string, claim: TierClaim, keySource: string, issuedAtMs: number,
    used: boolean) {
    this.personaId = personaId;
    this.token = token;
    this.claim = claim;
    this.keySource = keySource;
    this.issuedAtMs = issuedAtMs;
    this.used = used;
  }
}

export class ShareService {
  private static instance: ShareService | null = null;

  private clock: SystemClock = new SystemClock();
  private partner: PartnerVerifier = new PartnerVerifier(new DeviceRandom(), this.clock, new DeviceSigVerifier());
  private code: ShareCode | null = null;
  private ledger: LedgerEntry[] = [];
  private store: FileTextStore | null = null;
  private tail: Promise<void> = Promise.resolve();
  private revision: number = 0;

  static shared(): ShareService {
    if (ShareService.instance === null) {
      ShareService.instance = new ShareService();
    }
    return ShareService.instance;
  }

  /** Gives the ledger its file in the app sandbox and loads what earlier sessions wrote. Call once. */
  attach(filesDir: string): void {
    if (this.store !== null || filesDir.length === 0) {
      return;
    }
    this.store = new FileTextStore(filesDir);
    const text = this.store.read(LEDGER_FILE);
    if (text === null) {
      return;
    }
    try {
      const saved = JSON.parse(text) as LedgerEntry[];
      this.ledger = saved.concat(this.ledger);
    } catch (e) {
      // An unreadable file is left alone; new entries are still kept in memory.
    }
  }

  /** The code on screen, or null before the first one. */
  current(): ShareCode | null {
    return this.code;
  }

  /** Everything that has left this phone, oldest first. */
  ledgerEntries(): LedgerEntry[] {
    return this.ledger.slice();
  }

  /*
   * The code for this report. Null when the report has no score: then nothing is signed and nothing is
   * written to the ledger. An unused code of the same persona and claim is kept while its nonce is alive,
   * and a used one is kept until the user asks for a new one (`fresh`), so one visit is one ledger line.
   */
  codeFor(report: PersonaReport, fresh: boolean): Promise<ShareCode | null> {
    const run = this.tail.then((): Promise<ShareCode | null> => this.make(report, fresh));
    this.tail = run.then((): void => {
    }, (): void => {
    });
    return run;
  }

  /** The partner checks a token. A valid check of the code on screen marks that code as used. */
  async verify(token: string): Promise<VerifyResult> {
    const result = await this.partner.verify(token);
    const have = this.code;
    if (result.ok && have !== null && have.token === token) {
      this.code = new ShareCode(have.personaId, have.token, have.claim, have.keySource, have.issuedAtMs, true);
      this.bump();
    }
    return result;
  }

  private async make(report: PersonaReport, fresh: boolean): Promise<ShareCode | null> {
    const offer = shareOffer(report);
    if (!offer.available) {
      return null;
    }
    const now = this.clock.nowMs();
    const have = this.code;
    if (!fresh && have !== null && have.personaId === report.id && have.claim.tier === offer.tier &&
      have.claim.eligible === offer.eligible && have.claim.period === offer.periodIso &&
      (have.used || now - have.issuedAtMs < NONCE_TTL_MS - EXPIRY_MARGIN_MS)) {
      return have;
    }
    const key = await ProofSigner.shared().ensureKey();
    const keySource = key.source === KeySource.HUKS ? KEY_SOURCE_HUKS : KEY_SOURCE_SOFTWARE;
    // The demo partner learns the public key here; a real partner gets it once, when the user enrols. The
    // partner works the kid out from the key and refuses a kid that already belongs to another key: the
    // code is not made, the screen offers "Try again".
    const enrolled = await this.partner.enrolKey(key.publicKeyDer, keySource, new DeviceHasher());
    if (enrolled !== key.kid) {
      throw new Error('The partner already has another key with this key id');
    }
    const signer = await KeySigner.create(ProofSigner.ALIAS);
    const nonce = await this.partner.issueNonce();
    const token = await mintClaimToken(signer, keySource, offer, nonce, now);
    const claim = tokenClaim(token);
    if (claim === null) {
      throw new Error('The signed code could not be read back');
    }
    const made = new ShareCode(report.id, token, claim, keySource, now, false);
    this.ledger.push(claimLedgerEntry(token, now));
    this.saveLedger();
    this.code = made;
    this.bump();
    return made;
  }

  private saveLedger(): void {
    if (this.store === null) {
      return;
    }
    try {
      this.store.writeAtomic(LEDGER_FILE, JSON.stringify(this.ledger));
    } catch (e) {
      // The entry stays in memory and is written with the next one.
    }
  }

  private bump(): void {
    this.revision += 1;
    AppStorage.setOrCreate<number>(KEY_SHARE_REVISION, this.revision);
  }
}
