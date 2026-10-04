import { RandomSource } from '../claim/PartnerVerifier';
import { CryptoUtil } from './CryptoUtil';

/** The device's random source for the partner verifier: the system CSPRNG from cryptoFramework. */
export class DeviceRandom implements RandomSource {
  randomBytes(count: number): Promise<Uint8Array> {
    return CryptoUtil.randomBytes(count);
  }
}
