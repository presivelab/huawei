// Minimalna zaślepka @ohos/hypium do uruchamiania testów logiki w Node (bez DevEco Studio).
'use strict';

const results = [];
let currentSuite = '';

function describe(name, fn) {
  const prev = currentSuite;
  currentSuite = name;
  try {
    fn();
  } finally {
    currentSuite = prev;
  }
}

function it(name, _level, fn) {
  const full = `${currentSuite} > ${name}`;
  try {
    fn();
    results.push({ name: full, ok: true });
  } catch (e) {
    results.push({ name: full, ok: false, err: e && e.message ? e.message : String(e) });
  }
}

function fmt(v) {
  try {
    return JSON.stringify(v);
  } catch (e) {
    return String(v);
  }
}

function expect(actual) {
  const fail = (msg) => {
    throw new Error(msg);
  };
  return {
    assertEqual(expected) {
      if (actual !== expected) fail(`expected ${fmt(expected)}, got ${fmt(actual)}`);
    },
    assertTrue() {
      if (actual !== true) fail(`expected true, got ${fmt(actual)}`);
    },
    assertFalse() {
      if (actual !== false) fail(`expected false, got ${fmt(actual)}`);
    },
    assertLarger(n) {
      if (!(actual > n)) fail(`expected > ${n}, got ${fmt(actual)}`);
    },
    assertLess(n) {
      if (!(actual < n)) fail(`expected < ${n}, got ${fmt(actual)}`);
    },
    assertContain(x) {
      if (!String(actual).includes(String(x))) fail(`expected to contain ${fmt(x)}, got ${fmt(actual)}`);
    }
  };
}

function report() {
  let failed = 0;
  for (const r of results) {
    if (r.ok) {
      console.log(`  ✓ ${r.name}`);
    } else {
      failed++;
      console.log(`  ✗ ${r.name}\n      ${r.err}`);
    }
  }
  console.log(`\n${results.length - failed}/${results.length} testów przeszło`);
  return failed === 0 ? 0 : 1;
}

module.exports = { describe, it, expect, report };
