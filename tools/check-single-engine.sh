#!/usr/bin/env bash
# Checks that the score model exists in one place only: common/src/main/ets/hes.
#
# FairWear (entry, watch) and Health Sim take the engine from the common module. This script fails when
# a weight table, a curve point or a piecewise function of the model turns up anywhere else in the sources,
# or when Health Sim carries copied sources of common again.
#
# Usage (Git Bash, repository root):  tools/check-single-engine.sh      exit 0 = one engine
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
status=0
PATTERNS=(
  '125, *125, *200, *150'            # Health & wellness weights
  '225, *150, *150, *175'            # Longevity weights
  'x: *8000, *y: *95'                # steps curve
  'x: *150, *y: *80'                 # MVPA curve
  'x: *110, *y: *5[^0-9]'            # resting heart rate curve
  '\[8000, *95\]'
  '\[150, *80\]'
  'function +piecewise'
  'function +computeHes'
  'function +hesRound'
)
for pattern in "${PATTERNS[@]}"; do
  hits=$(grep -rnE --include='*.ets' --include='*.ts' --include='*.js' "$pattern" entry watch common healthsim 2>/dev/null \
    | grep -v '/build/' | grep -v '/oh_modules/' | grep -v '^common/src/main/ets/hes/' | grep -v '^common/src/test/' || true)
  if [ -n "$hits" ]; then
    echo "The score model outside common/src/main/ets/hes ($pattern):"
    echo "$hits"
    status=1
  fi
done
if [ -d healthsim/entry/src/main/ets/fw ] || [ -d healthsim/watch/src/main/ets/fw ]; then
  echo "Health Sim carries copied sources of common (healthsim/*/src/main/ets/fw). It must use healthsim/libs/common.har."
  status=1
fi
for module in entry watch; do
  if ! grep -q '"common": *"file:../libs/common.har"' "healthsim/$module/oh-package.json5"; then
    echo "healthsim/$module does not depend on healthsim/libs/common.har."
    status=1
  fi
done
if [ $status -eq 0 ]; then
  echo "One engine: the score model is only in common/src/main/ets/hes."
fi
exit $status
