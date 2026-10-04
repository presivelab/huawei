// A small seeded generator for the demo personas (mulberry32). The same seed gives the same numbers on
// every engine: only 32-bit integer arithmetic and one division. It is for demo data only and is never
// used for nonces, keys or signatures.

const UINT32_RANGE: number = 4294967296;
const INCREMENT: number = 0x6D2B79F5;
const MIX_A: number = 0x9E3779B1;
const MIX_B: number = 0x85EBCA6B;
const GAUSS_TERMS: number = 12;
const GAUSS_SHIFT: number = 6;

export class HesPrng {
  private state: number;

  constructor(seed: number) {
    this.state = seed | 0;
  }

  /** A generator for one (seed, index, stream) triple; neighbouring triples give unrelated sequences. */
  static forStream(seed: number, index: number, stream: number): HesPrng {
    const mixed = (seed | 0) ^ Math.imul(index | 0, MIX_A) ^ Math.imul((stream + 1) | 0, MIX_B);
    const prng = new HesPrng(mixed);
    prng.next();
    prng.next();
    return prng;
  }

  /** Uniform in [0, 1). */
  next(): number {
    this.state = (this.state + INCREMENT) | 0;
    let t = Math.imul(this.state ^ (this.state >>> 15), 1 | this.state);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / UINT32_RANGE;
  }

  /**
   * Roughly normal with mean 0 and standard deviation 1: the sum of twelve uniform numbers minus six.
   * No logarithm or cosine, so the result does not depend on the engine's math library.
   */
  gauss(): number {
    let sum = 0;
    for (let i = 0; i < GAUSS_TERMS; i++) {
      sum += this.next();
    }
    return sum - GAUSS_SHIFT;
  }
}
