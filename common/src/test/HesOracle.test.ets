import { describe, it, expect } from '@ohos/hypium';
import { readRepoText } from '@fairwear/node-ports';
import { HES_COMPONENTS, HES_PROFILES } from '../main/ets/hes/HesModel';
import { HesPersonas } from '../main/ets/hes/HesPersonas';
import { HesResult, HesStatus } from '../main/ets/hes/HesTypes';

// The engine against the reference oracle (tools/hes_vnext_oracle.cjs): six personas in two profiles.
// The oracle's output is kept in tools/hes_vnext_oracle.golden.json; tools/check-oracle.sh checks that the
// file still is what the oracle prints, and then runs this test. Node only: it reads a file of the
// repository, so it is not in List.test.ets.

const GOLDEN = 'tools/hes_vnext_oracle.golden.json';
const EPS = 1e-9;

class OracleComponent {
  raw: number | null = null;
  valid: number = 0;
  score: number | null = null;
  effectiveWeight: number | null = null;
}

class OracleResult {
  status: string = '';
  hes: number | null = null;
  observed: number | null = null;
  tier: string = '';
  coveragePm: number = 0;
  confidence: string = '';
  ci: number | null = null;
  components: Record<string, OracleComponent> = {};
}

function oracle(): Record<string, Record<string, OracleResult>> {
  const text = readRepoText(GOLDEN);
  if (text === null) {
    throw new Error(GOLDEN + ' is missing: run node tools/hes_vnext_oracle.cjs --json > ' + GOLDEN);
  }
  return JSON.parse(text) as Record<string, Record<string, OracleResult>>;
}

function same(actual: number | undefined, expected: number | null): void {
  if (expected === null) {
    expect(actual).assertUndefined();
  } else {
    expect(actual).assertClose(expected, EPS);
  }
}

function compare(result: HesResult, expected: OracleResult): void {
  expect(result.status === HesStatus.OK ? 'OK' : 'INSUFFICIENT_DATA').assertEqual(expected.status);
  same(result.score, expected.hes);
  same(result.observed, expected.observed);
  same(result.confidenceIndex, expected.ci);
  expect(result.tier as string).assertEqual(expected.tier);
  expect(result.coveragePermille).assertEqual(expected.coveragePm);
  expect(result.confidence as string).assertEqual(expected.confidence);
  for (let i = 0; i < result.components.length; i++) {
    const c = result.components[i];
    const e = expected.components[c.id as string];
    expect(c.validCount).assertEqual(e.valid);
    same(c.rawValue, e.raw);
    same(c.score, e.score);
    same(c.effectiveWeight, e.effectiveWeight);
  }
}

export default function hesOracleTest() {
  describe('HES engine against the reference oracle', () => {
    it('six personas in two profiles: every aggregate, component score, weight and result', 0, () => {
      const all = oracle();
      let compared = 0;
      for (let i = 0; i < HesPersonas.IDS.length; i++) {
        const id = HesPersonas.IDS[i];
        for (let p = 0; p < HES_PROFILES.length; p++) {
          const profile = HES_PROFILES[p];
          compare(HesPersonas.result(id, profile), all[id][profile as string]);
          compared++;
        }
      }
      expect(compared).assertEqual(12);
      expect(HES_COMPONENTS.length).assertEqual(8);
    });

    it('the oracle file holds the six personas and nothing else', 0, () => {
      expect(Object.keys(oracle()).sort()).assertDeepEquals(HesPersonas.IDS.slice().sort());
    });
  });
}
