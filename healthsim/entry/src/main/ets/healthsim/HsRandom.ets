/**
 * Deterministic PRNG (mulberry32) and hashing helpers.
 * The same seed, persona and local day always give the same numbers on every device.
 */

export function hash32(text: string): number {
  // FNV-1a, 32-bit
  let h: number = 0x811c9dc5;
  for (let i = 0; i < text.length; i++) {
    h = h ^ text.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h >>> 0;
}

export function hashBytes(bytes: Uint8Array): number {
  let h: number = 0x811c9dc5;
  for (let i = 0; i < bytes.length; i++) {
    h = h ^ bytes[i];
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h >>> 0;
}

export function toHex8(value: number): string {
  let s: string = (value >>> 0).toString(16);
  while (s.length < 8) {
    s = '0' + s;
  }
  return s;
}

export class HsRandom {
  private state: number = 0;
  private spareGauss: number = 0;
  private hasSpare: boolean = false;

  constructor(seed: number) {
    this.state = seed >>> 0;
  }

  /** Uniform in [0, 1). */
  next(): number {
    this.state = (this.state + 0x6d2b79f5) >>> 0;
    let t: number = this.state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t = t ^ (t + Math.imul(t ^ (t >>> 7), t | 61));
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }

  /** Uniform in [min, max). */
  range(min: number, max: number): number {
    return min + (max - min) * this.next();
  }

  /** Integer in [min, max] inclusive. */
  int(min: number, max: number): number {
    return min + Math.floor(this.next() * (max - min + 1));
  }

  chance(p: number): boolean {
    return this.next() < p;
  }

  /** Normal distribution (Box-Muller). */
  gauss(mean: number, sd: number): number {
    if (this.hasSpare) {
      this.hasSpare = false;
      return mean + sd * this.spareGauss;
    }
    let u: number = 0;
    while (u <= 1e-12) {
      u = this.next();
    }
    const v: number = this.next();
    const r: number = Math.sqrt(-2 * Math.log(u));
    this.spareGauss = r * Math.sin(2 * Math.PI * v);
    this.hasSpare = true;
    return mean + sd * r * Math.cos(2 * Math.PI * v);
  }
}

export function clamp(value: number, min: number, max: number): number {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}
