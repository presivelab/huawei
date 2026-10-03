#!/usr/bin/env bash
# Runs the DevEco Code Linter on every module through DevEco CLI.
# Needs: Node.js 22 or later on PATH and `npm install -g @deveco/deveco-cli@1.3.4`.
# Do NOT source tools/env.sh first: it puts DevEco Studio's bundled Node 18 on PATH and DevEco CLI fails on it.
# Usage (Git Bash): tools/lint.sh
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
status=0
for module in entry watch common; do
  echo "===== lint $module ====="
  devecocli.cmd check lint "$module" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' || status=1
done
exit $status
