import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { toHex } from './Bytes';

/*
 * Verifier-side cryptography and helpers.
 * The partner verifies a plain ECDSA P-256 / SHA-256 signature and needs no access to the device keystore.
 */
export class CryptoUtil {
  static async sha256(data: Uint8Array): Promise<Uint8Array> {
    const md = cryptoFramework.createMd('SHA256');
    await md.update({ data: data });
    const out = await md.digest();
    return out.data;
  }

  /** Key id: 8 hex characters, the first 4 bytes of SHA-256 over the public key (DER / X.509). */
  static async keyId(publicKeyDer: Uint8Array): Promise<string> {
    const hash = await CryptoUtil.sha256(publicKeyDer);
    return toHex(hash).substring(0, 8);
  }

  /** Random bytes from the system CSPRNG. */
  static async randomBytes(byteCount: number): Promise<Uint8Array> {
    const rand = cryptoFramework.createRandom();
    const blob = await rand.generateRandom(byteCount);
    return blob.data;
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
