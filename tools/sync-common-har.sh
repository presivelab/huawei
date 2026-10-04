#!/usr/bin/env bash
# Builds the shared logic module (common) as a HAR and hands it to Health Sim.
#
# Health Sim is a DevEco project of its own (healthsim/). It takes the score engine, the persona generator
# and the export contract from the very same common module FairWear uses, as the package
# healthsim/libs/common.har. There is no copy of any formula in healthsim/: run this script after every change
# in common, before building Health Sim.
#
# Usage (Git Bash, repository root):  tools/sync-common-har.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source tools/env.sh
# Inside a VS Code terminal this variable makes hvigor fail; outside it is not set.
unset ELECTRON_RUN_AS_NODE || true
LOG="$(mktemp)"
hvigorw.bat assembleHar --mode module -p module=common@default -p product=default --no-daemon > "$LOG" 2>&1 || true
if ! grep -q "BUILD SUCCESSFUL" "$LOG"; then
  tail -40 "$LOG"
  echo "common did not build; healthsim/libs/common.har was not changed."
  exit 4
fi
mkdir -p healthsim/libs
cp common/build/default/outputs/default/common.har healthsim/libs/common.har
(cd healthsim && ohpm.bat install --all > /dev/null)
echo "healthsim/libs/common.har updated ($(wc -c < healthsim/libs/common.har) bytes)."
