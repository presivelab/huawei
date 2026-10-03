#!/usr/bin/env bash
# Runs the pure-logic tests of a module under Node, without an emulator.
#
# Usage (Git Bash):
#   tools/run-logic-tests.sh common                                         every *.test.ets in common/src/test
#   tools/run-logic-tests.sh common common/src/test/Claim.test.ets          one test file
#   tools/run-logic-tests.sh common common/src/test/Health.test.ets health  one test file, and type-check
#                                                                           every file in src/main/ets/health
#
# How: the .ets files are compiled as strict TypeScript with the compiler bundled in DevEco Studio and run
# against a small hypium stand-in (tools/logic-tests/). Nothing is downloaded. This checks the logic, not the
# ArkTS rules: run `hvigorw assembleHar` (or tools/deploy.sh) for the ArkTS compiler.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source tools/env.sh
MODULE="${1:-common}"
shift || true
TS_DIR=""
for candidate in \
  "$DEVECO_HOME/tools/hvigor/hvigor/node_modules/typescript" \
  "$DEVECO_HOME/tools/hvigor/hvigor-ohos-plugin/node_modules/typescript" \
  "$DEVECO_HOME/tools/ohpm/node_modules/typescript"; do
  if [ -f "$candidate/lib/typescript.js" ]; then TS_DIR="$candidate"; break; fi
done
if [ -z "$TS_DIR" ]; then
  echo "TypeScript not found in DevEco Studio ($DEVECO_HOME). Set DEVECO_HOME."; exit 3
fi
node tools/logic-tests/runner.js "$(cygpath -w "$TS_DIR")" "$(cygpath -w "$PWD")" "$MODULE" "$@"
