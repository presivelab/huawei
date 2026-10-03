// Minimal stand-in for '@ohos/hypium' so the pure-logic tests of a HAR can run under Node.
// Only what the tests in this repository use: describe / it / expect and the before/after hooks.
// It is NOT hypium: results from this shim say nothing about how the code behaves on a device.

type TestBody = () => void | Promise<void>;

interface TestCase {
  name: string;
  body: TestBody;
}

interface Suite {
  name: string;
  tests: TestCase[];
  beforeAll: TestBody[];
  afterAll: TestBody[];
  beforeEach: TestBody[];
  afterEach: TestBody[];
}

export interface TestOutcome {
  suite: string;
  name: string;
  passed: boolean;
  message: string;
}

const suites: Suite[] = [];
let current: Suite | null = null;

function suiteInScope(what: string): Suite {
  if (current === null) {
    throw new Error(what + " must be called inside describe()");
  }
  return current;
}

export function describe(name: string, body: () => void): void {
  const parent: Suite | null = current;
  const suite: Suite = {
    name: parent === null ? name : parent.name + " > " + name,
    tests: [],
    beforeAll: [],
    afterAll: [],
    beforeEach: [],
    afterEach: [],
  };
  suites.push(suite);
  current = suite;
  try {
    body();
  } finally {
    current = parent;
  }
}

export function it(name: string, filter: number, body: TestBody): void {
  suiteInScope("it()").tests.push({ name: name, body: body });
}

export function beforeAll(body: TestBody): void {
  suiteInScope("beforeAll()").beforeAll.push(body);
}

export function afterAll(body: TestBody): void {
  suiteInScope("afterAll()").afterAll.push(body);
}

export function beforeEach(body: TestBody): void {
  suiteInScope("beforeEach()").beforeEach.push(body);
}

export function afterEach(body: TestBody): void {
  suiteInScope("afterEach()").afterEach.push(body);
}

function show(value: unknown): string {
  if (typeof value === "string") {
    return JSON.stringify(value);
  }
  try {
    const json: string | undefined = JSON.stringify(value);
    return json === undefined ? String(value) : json;
  } catch (e) {
    return String(value);
  }
}

function deepEqual(a: unknown, b: unknown): boolean {
  if (Object.is(a, b)) {
    return true;
  }
  if (
    typeof a !== "object" ||
    typeof b !== "object" ||
    a === null ||
    b === null
  ) {
    return false;
  }
  if (Array.isArray(a) !== Array.isArray(b)) {
    return false;
  }
  const ka: string[] = Object.keys(a as Record<string, unknown>).sort();
  const kb: string[] = Object.keys(b as Record<string, unknown>).sort();
  if (ka.length !== kb.length) {
    return false;
  }
  for (let i = 0; i < ka.length; i++) {
    if (ka[i] !== kb[i]) {
      return false;
    }
    if (
      !deepEqual(
        (a as Record<string, unknown>)[ka[i]],
        (b as Record<string, unknown>)[kb[i]],
      )
    ) {
      return false;
    }
  }
  return true;
}

export class Assertion {
  private actual: unknown;
  private negated: boolean;

  constructor(actual: unknown, negated: boolean) {
    this.actual = actual;
    this.negated = negated;
  }

  not(): Assertion {
    return new Assertion(this.actual, !this.negated);
  }

  private check(ok: boolean, expectation: string): void {
    if (ok === this.negated) {
      throw new Error(
        "expected " +
          show(this.actual) +
          (this.negated ? " not " : " ") +
          expectation,
      );
    }
  }

  assertEqual(expected: unknown): void {
    this.check(Object.is(this.actual, expected), "to equal " + show(expected));
  }

  assertDeepEquals(expected: unknown): void {
    this.check(
      deepEqual(this.actual, expected),
      "to deep-equal " + show(expected),
    );
  }

  assertTrue(): void {
    this.check(this.actual === true, "to be true");
  }

  assertFalse(): void {
    this.check(this.actual === false, "to be false");
  }

  assertNull(): void {
    this.check(this.actual === null, "to be null");
  }

  assertUndefined(): void {
    this.check(this.actual === undefined, "to be undefined");
  }

  assertLarger(expected: number): void {
    this.check(
      typeof this.actual === "number" && this.actual > expected,
      "to be larger than " + show(expected),
    );
  }

  assertLess(expected: number): void {
    this.check(
      typeof this.actual === "number" && this.actual < expected,
      "to be less than " + show(expected),
    );
  }

  assertLargerOrEqual(expected: number): void {
    this.check(
      typeof this.actual === "number" && this.actual >= expected,
      "to be at least " + show(expected),
    );
  }

  assertLessOrEqual(expected: number): void {
    this.check(
      typeof this.actual === "number" && this.actual <= expected,
      "to be at most " + show(expected),
    );
  }

  assertContain(expected: unknown): void {
    let ok: boolean = false;
    if (typeof this.actual === "string" && typeof expected === "string") {
      ok = this.actual.indexOf(expected) >= 0;
    } else if (Array.isArray(this.actual)) {
      ok = this.actual.indexOf(expected) >= 0;
    }
    this.check(ok, "to contain " + show(expected));
  }

  assertClose(expected: number, precision: number): void {
    this.check(
      typeof this.actual === "number" &&
        Math.abs(this.actual - expected) <= precision,
      "to be within " + show(precision) + " of " + show(expected),
    );
  }
}

export function expect(actual?: unknown): Assertion {
  return new Assertion(actual, false);
}

function messageOf(e: unknown): string {
  return e instanceof Error ? e.message : String(e);
}

async function runAll(hooks: TestBody[]): Promise<void> {
  for (let i = 0; i < hooks.length; i++) {
    await hooks[i]();
  }
}

// Runs every registered suite in registration order. Called by tools/logic-tests/runner.js.
export async function runRegisteredSuites(): Promise<TestOutcome[]> {
  const outcomes: TestOutcome[] = [];
  for (let s = 0; s < suites.length; s++) {
    const suite: Suite = suites[s];
    let suiteError: string = "";
    try {
      await runAll(suite.beforeAll);
    } catch (e) {
      suiteError = "beforeAll failed: " + messageOf(e);
    }
    for (let t = 0; t < suite.tests.length; t++) {
      const test: TestCase = suite.tests[t];
      const outcome: TestOutcome = {
        suite: suite.name,
        name: test.name,
        passed: true,
        message: "",
      };
      if (suiteError.length > 0) {
        outcome.passed = false;
        outcome.message = suiteError;
      } else {
        try {
          await runAll(suite.beforeEach);
          await test.body();
          await runAll(suite.afterEach);
        } catch (e) {
          outcome.passed = false;
          outcome.message = messageOf(e);
        }
      }
      outcomes.push(outcome);
    }
    try {
      await runAll(suite.afterAll);
    } catch (e) {
      outcomes.push({
        suite: suite.name,
        name: "afterAll",
        passed: false,
        message: messageOf(e),
      });
    }
  }
  return outcomes;
}
