import { huks } from '@kit.UniversalKeystoreKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { b64urlEncode, utf8Encode } from '../logic/Codec';
import { CryptoUtil } from './CryptoUtil';

/*
 * Klucz urządzenia do podpisywania raportów.
 *  1. Klucz ECC P-256 generowany w HUKS (Universal Keystore) - klucz prywatny nigdy nie opuszcza keystore.
 *  2. Autotest: podpis z HUKS musi się zweryfikować zwykłym ECDSA (tak jak u ubezpieczyciela).
 *  3. Próba anonimowej atestacji klucza (anonAttestKeyItem) - wymaga sieci i wsparcia urządzenia.
 *  4. Gdy HUKS jest niedostępny (np. emulator), klucz programowy z cryptoFramework, wyraźnie oznaczony w UI.
 */

export enum KeySource {
  HUKS = 'HUKS',
  SOFTWARE = 'SOFTWARE'
}

export class DeviceKey {
  kid: string;
  publicKeyB64: string;
  source: KeySource;
  attested: boolean;
  note: string;
  certCount: number;

  constructor(kid: string, publicKeyB64: string, source: KeySource, attested: boolean, note: string,
    certCount: number) {
    this.kid = kid;
    this.publicKeyB64 = publicKeyB64;
    this.source = source;
    this.attested = attested;
    this.note = note;
    this.certCount = certCount;
  }
}

class AttestResult {
  ok: boolean;
  note: string;
  certCount: number;

  constructor(ok: boolean, note: string, certCount: number) {
    this.ok = ok;
    this.note = note;
    this.certCount = certCount;
  }
}

export class ProofSigner {
  static readonly ALIAS: string = 'dowod_aktywnosci_ecc_p256_v1';
  static readonly ATTEST_TIMEOUT_MS: number = 8000;

  private softKeyPair: cryptoFramework.KeyPair | null = null;
  private key: DeviceKey | null = null;
  huksError: string = '';

  currentKey(): DeviceKey | null {
    return this.key;
  }

  /** challenge = nonce ubezpieczyciela przy rejestracji; trafia do atestacji klucza. */
  async ensureKey(challenge: string): Promise<DeviceKey> {
    if (this.key !== null) {
      return this.key;
    }
    try {
      this.key = await this.setupHuksKey(challenge);
    } catch (e) {
      this.huksError = ProofSigner.errText(e as BusinessError);
      this.key = await this.setupSoftwareKey();
    }
    return this.key;
  }

  async sign(data: Uint8Array): Promise<Uint8Array> {
    const key = this.key;
    if (key === null) {
      throw new Error('Brak klucza — najpierw zarejestruj urządzenie');
    }
    if (key.source === KeySource.HUKS) {
      return await ProofSigner.huksSign(data);
    }
    const pair = this.softKeyPair;
    if (pair === null) {
      throw new Error('Brak klucza programowego');
    }
    const signer = cryptoFramework.createSign('ECC256|SHA256');
    await signer.init(pair.priKey);
    const out = await signer.sign({ data: data });
    return out.data;
  }

  static errText(err: BusinessError): string {
    if (err === undefined || err === null) {
      return 'nieznany błąd';
    }
    return err.code !== undefined ? `${err.code}: ${err.message}` : `${err.message}`;
  }

  private async setupHuksKey(challenge: string): Promise<DeviceKey> {
    const exists = await ProofSigner.huksKeyExists();
    if (!exists) {
      await huks.generateKeyItem(ProofSigner.ALIAS, { properties: ProofSigner.keyProps(true) });
    }
    const exported = await huks.exportKeyItem(ProofSigner.ALIAS, { properties: [] });
    const pub = exported.outData;
    if (pub === undefined || pub.length === 0) {
      throw new Error('HUKS nie zwrócił klucza publicznego');
    }
    const probe = utf8Encode('autotest-podpisu');
    const sig = await ProofSigner.huksSign(probe);
    const ok = await CryptoUtil.verifyEcdsaP256(pub, probe, sig);
    if (!ok) {
      throw new Error('Podpis z HUKS nie przeszedł autotestu weryfikacji');
    }
    const kid = await CryptoUtil.keyId(pub);
    const att = await ProofSigner.tryAttest(challenge);
    return new DeviceKey(kid, b64urlEncode(pub), KeySource.HUKS, att.ok, att.note, att.certCount);
  }

  private async setupSoftwareKey(): Promise<DeviceKey> {
    const generator = cryptoFramework.createAsyKeyGenerator('ECC256');
    const pair = await generator.generateKeyPair();
    this.softKeyPair = pair;
    const pub = pair.pubKey.getEncoded().data;
    const kid = await CryptoUtil.keyId(pub);
    return new DeviceKey(kid, b64urlEncode(pub), KeySource.SOFTWARE, false,
      `Klucz programowy w pamięci aplikacji — HUKS niedostępny (${this.huksError})`, 0);
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

  private static async huksKeyExists(): Promise<boolean> {
    try {
      return await huks.isKeyItemExist(ProofSigner.ALIAS, { properties: [] });
    } catch (e) {
      // 12000011 = klucz nie istnieje
      return false;
    }
  }

  private static async huksSign(data: Uint8Array): Promise<Uint8Array> {
    const props = ProofSigner.keyProps(false);
    const session = await huks.initSession(ProofSigner.ALIAS, { properties: props });
    const result = await huks.finishSession(session.handle, { properties: props, inData: data });
    const out = result.outData;
    if (out === undefined || out.length === 0) {
      throw new Error('HUKS nie zwrócił podpisu');
    }
    return out;
  }

  private static async tryAttest(challenge: string): Promise<AttestResult> {
    const props: Array<huks.HuksParam> = [
      { tag: huks.HuksTag.HUKS_TAG_ATTESTATION_ID_SEC_LEVEL_INFO, value: utf8Encode('sec_level') },
      { tag: huks.HuksTag.HUKS_TAG_ATTESTATION_CHALLENGE, value: utf8Encode(challenge) },
      { tag: huks.HuksTag.HUKS_TAG_ATTESTATION_ID_VERSION_INFO, value: utf8Encode('version_info') },
      { tag: huks.HuksTag.HUKS_TAG_ATTESTATION_ID_ALIAS, value: utf8Encode(ProofSigner.ALIAS) }
    ];
    try {
      const res = await ProofSigner.withTimeout(huks.anonAttestKeyItem(ProofSigner.ALIAS, { properties: props }),
        ProofSigner.ATTEST_TIMEOUT_MS);
      const chain = res.certChains;
      const n = chain !== undefined ? chain.length : 0;
      return new AttestResult(n > 0,
        n > 0 ? `Anonimowa atestacja klucza: łańcuch ${n} certyfikatów` : 'Atestacja zwróciła pusty łańcuch', n);
    } catch (e) {
      return new AttestResult(false,
        `Atestacja niedostępna (${ProofSigner.errText(e as BusinessError)}) — wymaga sieci i obsługi na urządzeniu`, 0);
    }
  }

  private static withTimeout(p: Promise<huks.HuksReturnResult>, ms: number): Promise<huks.HuksReturnResult> {
    const timeout = new Promise<huks.HuksReturnResult>(
      (resolve: (v: huks.HuksReturnResult) => void, reject: (e: Error) => void) => {
        setTimeout(() => {
          reject(new Error(`przekroczono ${ms} ms`));
        }, ms);
      });
    return Promise.race<huks.HuksReturnResult>([p, timeout]);
  }
}
