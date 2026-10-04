#!/usr/bin/env bash
# Checks the ArkTS score engine against the reference oracle (tools/hes_vnext_oracle.cjs).
#
#   1. the oracle is run and its output is compared with tools/hes_vnext_oracle.golden.json, so the file the
#      test reads is what the oracle prints today;
#   2. the engine is run under Node for the six personas in both profiles and compared with that file:
#      aggregates, component scores, effective weights, observed score, score, tier, coverage, confidence.
#
# Usage (Git Bash, repository root):  tools/check-oracle.sh      exit 0 = the engine agrees with the oracle
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source tools/env.sh
FRESH="$(mktemp)"
node tools/hes_vnext_oracle.cjs --json > "$FRESH"
if ! diff -q --strip-trailing-cr "$FRESH" tools/hes_vnext_oracle.golden.json > /dev/null; then
  echo "tools/hes_vnext_oracle.golden.json is not what the oracle prints. Regenerate it only when the oracle"
  echo "itself was changed on purpose:  node tools/hes_vnext_oracle.cjs --json > tools/hes_vnext_oracle.golden.json"
  diff --strip-trailing-cr "$FRESH" tools/hes_vnext_oracle.golden.json | head -20
  exit 1
fi
node tools/hes_vnext_oracle.cjs
tools/run-logic-tests.sh common common/src/test/HesOracle.test.ets
