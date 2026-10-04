export declare function describe(name: string, fn: () => void): void;
export declare function it(name: string, level: number, fn: () => void): void;
export interface Assert {
  assertEqual(expected: unknown): void;
  assertTrue(): void;
  assertFalse(): void;
  assertLarger(n: number): void;
  assertLess(n: number): void;
  assertContain(x: unknown): void;
}
export declare function expect(actual: unknown): Assert;
export declare function report(): number;
