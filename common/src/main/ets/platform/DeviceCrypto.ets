import { Clock, Hasher, Signer, SigVerifier } from '../watchlink/WatchLinkPorts';
import { b64urlDecode, b64urlEncode, utf8Encode } from './Bytes';
import { CryptoUtil } from './CryptoUtil';
import { DeviceKey, KeySource, ProofSigner } from './ProofSigner';

/*
 * Device implementations of the Watch Link ports, on top of ProofSigner and CryptoUtil.
 * Signatures are ECDSA P-256 / SHA-256, ASN.1 DER, base64url: the encoding of the phone's claim signature.
 */

/** Signs with the device key stored under one alias (HUKS, or the software fallback ProofSigner reports). */
export class KeySigner implements Signer {
  private signer: ProofSigner;
  private key: DeviceKey;

  private constructor(signer: ProofSigner, key: DeviceKey) {
    this.signer = signer;
    this.key = key;
  }

  static async create(alias: string): Promise<KeySigner> {
    const signer = ProofSigner.forAlias(alias);
    const key = await signer.ensureKey();
    return new KeySigner(signer, key);
  }

  kid(): string {
    return this.key.kid;
  }

  publicKeySpkiB64(): string {
    return b64urlEncode(this.key.publicKeyDer);
  }

  async sign(msg: string): Promise<string> {
    return b64urlEncode(await this.signer.sign(utf8Encode(msg)));
  }

  keySource(): KeySource {
    return this.key.source;
  }

  /** The badge text: where the key is held. */
  note(): string {
    return this.key.note;
  }
}

export class DeviceSigVerifier implements SigVerifier {
  async verify(pubB64: string, msg: string, sigB64: string): Promise<boolean> {
    try {
      return await CryptoUtil.verifyEcdsaP256(b64urlDecode(pubB64), utf8Encode(msg), b64urlDecode(sigB64));
    } catch (e) {
      return false;
    }
  }
}

export class DeviceHasher implements Hasher {
  async sha256B64url(msg: string): Promise<string> {
    return b64urlEncode(await CryptoUtil.sha256(utf8Encode(msg)));
  }

  keyId(pubB64: string): Promise<string> {
    return CryptoUtil.keyId(b64urlDecode(pubB64));
  }
}

export class SystemClock implements Clock {
  nowMs(): number {
    return Date.now();
  }
}

/** Minutes east of UTC for the device's current time zone. */
export function deviceTzOffsetMin(): number {
  return -new Date().getTimezoneOffset();
}
