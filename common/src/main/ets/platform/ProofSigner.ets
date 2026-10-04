import { huks } from '@kit.UniversalKeystoreKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { utf8Encode } from './Bytes';
import { CryptoUtil } from './CryptoUtil';

/*
 * The device key that signs tier claims.
 *
 * The key is chosen once per app session, in ensureKey():
 *  1. ECDSA P-256 key generated in HUKS (Universal Keystore); the private key never leaves the keystore.
 *     Self-test: a HUKS signature over a probe must verify with plain ECDSA, exactly as the partner verifies it.
 *  2. If any HUKS step fails (for example on an emulator), a software key from cryptoFramework held in app memory.
 * Whichever key passed is the only key used until the app restarts. There is no switching while signing.
 *
 * One instance per key alias: the phone signs tier claims with ALIAS, the watch signs day packets with
 * WATCH_DAY_ALIAS. The two keys are separate and never leave their device.
 */

export enum KeySource {
  HUKS = 'HUKS',
  SOFTWARE = 'SOFTWARE'
}

export class DeviceKey {
  kid: string;
  publicKeyDer: Uint8Array;
  source: KeySource;
  note: string;

  constructor(kid: string, publicKeyDer: Uint8Array, source: KeySource, note: string) {
    this.kid = kid;
    this.publicKeyDer = publicKeyDer;
    this.source = source;
    this.note = note;
  }
}

export class ProofSigner {
  static readonly ALIAS: string = 'fairwear_claim_ecc_p256_v1';
  static readonly WATCH_DAY_ALIAS: string = 'fairwear.watch.day.v1';
  // The phone's Watch Link key: signs the ACKs the watch pins at pairing. Separate from the claim key.
  static readonly PHONE_LINK_ALIAS: string = 'fairwear.phone.link.v1';
  private static instances: Map<string, ProofSigner> = new Map<string, ProofSigner>();

  private alias: string;

  private softKeyPair: cryptoFramework.KeyPair | null = null;
  private key: DeviceKey | null = null;
  private pending: Promise<DeviceKey> | null = null;
  huksError: string = '';

  private constructor(alias: string) {
    this.alias = alias;
  }

  /** The phone's claim-signing key. */
  static shared(): ProofSigner {
    return ProofSigner.forAlias(ProofSigner.ALIAS);
  }

  static forAlias(alias: string): ProofSigner {
    let signer = ProofSigner.instances.get(alias);
    if (signer === undefined) {
      signer = new ProofSigner(alias);
      ProofSigner.instances.set(alias, signer);
    }
    return signer;
  }

  currentKey(): DeviceKey | null {
    return this.key;
  }

  /** Probes HUKS once and fixes the signing key for the whole session. Safe to call repeatedly. */
  ensureKey(): Promise<DeviceKey> {
    const have: Promise<DeviceKey> | null = this.pending;
    if (have !== null) {
      return have;
    }
    const attempt: Promise<DeviceKey> = this.chooseKey();
    this.pending = attempt;
    // A failed attempt is not kept: the next call tries again instead of failing until the app restarts.
    attempt.catch((): void => {
      if (this.pending === attempt) {
        this.pending = null;
      }
    });
    return attempt;
  }

  async sign(data: Uint8Array): Promise<Uint8Array> {
    const key = await this.ensureKey();
    if (key.source === KeySource.HUKS) {
      return await ProofSigner.huksSign(this.alias, data);
    }
    const pair = this.softKeyPair;
    if (pair === null) {
      throw new Error('Software key is missing');
    }
    const signer = cryptoFramework.createSign('ECC256|SHA256');
    await signer.init(pair.priKey);
    const out = await signer.sign({ data: data });
    return out.data;
  }

  static errText(err: BusinessError): string {
    if (err === undefined || err === null) {
      return 'unknown error';
    }
    return err.code !== undefined ? `${err.code}: ${err.message}` : `${err.message}`;
  }

  private async chooseKey(): Promise<DeviceKey> {
    let chosen: DeviceKey;
    try {
      chosen = await this.setupHuksKey();
    } catch (e) {
      this.huksError = ProofSigner.errText(e as BusinessError);
      chosen = await this.setupSoftwareKey();
    }
    this.key = chosen;
    return chosen;
  }

  private async setupHuksKey(): Promise<DeviceKey> {
    const exists = await ProofSigner.huksKeyExists(this.alias);
    if (!exists) {
      await huks.generateKeyItem(this.alias, { properties: ProofSigner.keyProps(true) });
    }
    const exported = await huks.exportKeyItem(this.alias, { properties: [] });
    const pub = exported.outData;
    if (pub === undefined || pub.length === 0) {
      throw new Error('HUKS returned no public key');
    }
    const probe = utf8Encode('fairwear-signing-self-test');
    const sig = await ProofSigner.huksSign(this.alias, probe);
    const ok = await CryptoUtil.verifyEcdsaP256(pub, probe, sig);
    if (!ok) {
      throw new Error('HUKS signature failed the verification self-test');
    }
    const kid = await CryptoUtil.keyId(pub);
    return new DeviceKey(kid, pub, KeySource.HUKS, 'Key held in HUKS');
  }

  private async setupSoftwareKey(): Promise<DeviceKey> {
    const generator = cryptoFramework.createAsyKeyGenerator('ECC256');
    const pair = await generator.generateKeyPair();
    this.softKeyPair = pair;
    const pub = pair.pubKey.getEncoded().data;
    const kid = await CryptoUtil.keyId(pub);
    return new DeviceKey(kid, pub, KeySource.SOFTWARE,
      `Software key in app memory, HUKS unavailable (${this.huksError})`);
  }

  private static keyProps(forGenerate: boolean): Array<huks.HuksParam> {
    const purpose = forGenerate ?
      (huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_SIGN | huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_VERIFY) :
      huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_SIGN;
    const props: Array<huks.HuksParam> = [
      { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_ECC },
      { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_ECC_KEY_SIZE_256 },
      { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: purpose },
      { tag: huks.HuksTag.HUKS_TAG_DIGEST, value: huks.HuksKeyDigest.HUKS_DIGEST_SHA256 }
    ];
    return props;
  }

  private static async huksKeyExists(alias: string): Promise<boolean> {
    try {
      return await huks.isKeyItemExist(alias, { properties: [] });
    } catch (e) {
      // 12000011 = the key does not exist
      return false;
    }
  }

  private static async huksSign(alias: string, data: Uint8Array): Promise<Uint8Array> {
    const props = ProofSigner.keyProps(false);
    const session = await huks.initSession(alias, { properties: props });
    const result = await huks.finishSession(session.handle, { properties: props, inData: data });
    const out = result.outData;
    if (out === undefined || out.length === 0) {
      throw new Error('HUKS returned no signature');
    }
    return out;
  }
}
