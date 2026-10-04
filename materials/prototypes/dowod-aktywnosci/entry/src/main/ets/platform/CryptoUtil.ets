import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { toHex } from '../logic/Codec';

/*
 * Kryptografia po stronie weryfikatora i pomocnicze funkcje.
 * Ubezpieczyciel weryfikuje podpis zwykłym ECDSA P-256 / SHA-256, bez dostępu do HUKS urządzenia.
 */
export class CryptoUtil {
  static async sha256(data: Uint8Array): Promise<Uint8Array> {
    const md = cryptoFramework.createMd('SHA256');
    await md.update({ data: data });
    const out = await md.digest();
    return out.data;
  }

  /** Identyfikator klucza: pierwsze 4 bajty SHA-256 z klucza publicznego (DER/X.509). */
  static async keyId(publicKeyDer: Uint8Array): Promise<string> {
    const hash = await CryptoUtil.sha256(publicKeyDer);
    return toHex(hash).substring(0, 8);
  }

  /** Nonce z kryptograficznego generatora; awaryjnie Math.random (tylko gdy CSPRNG zawiedzie). */
  static async randomHex(byteCount: number): Promise<string> {
    try {
      const rand = cryptoFramework.createRandom();
      const blob = await rand.generateRandom(byteCount);
      return toHex(blob.data);
    } catch (e) {
      let out = '';
      for (let i = 0; i < byteCount * 2; i++) {
        out += Math.floor(Math.random() * 16).toString(16);
      }
      return out;
    }
  }

  static async verifyEcdsaP256(publicKeyDer: Uint8Array, data: Uint8Array, signature: Uint8Array): Promise<boolean> {
    try {
      const generator = cryptoFramework.createAsyKeyGenerator('ECC256');
      const keyPair = await generator.convertKey({ data: publicKeyDer }, null);
      const verifier = cryptoFramework.createVerify('ECC256|SHA256');
      await verifier.init(keyPair.pubKey);
      return await verifier.verify({ data: data }, { data: signature });
    } catch (e) {
      return false;
    }
  }
}
