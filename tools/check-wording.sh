#!/usr/bin/env bash
# Text check: wordings FairWear must not use about HUAWEI Health, Huawei or the score.
# Searches entry, watch, common, README* and docs/ (sources and documents, not build output).
# Usage (Git Bash): tools/check-wording.sh     exit 0 = 0 hits, exit 1 = at least one hit (printed).
#
# This file lists the wordings, so it lives in tools/, which is not searched.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

PATTERNS=(
  'official huawei health (plugin|extension)'
  'runs inside (the )?huawei health'
  'approved by huawei'
  'uses real huawei health data'
  'hardware-attested'
  'ai detects cheating'
  'tested on watch 6'
  'hes predicts'
  'clinically validated'
  'certified'
  'certyfikowan'
  'works with huawei health'
  'huawei health plugin'
  'wtyczk[a-zęąćłńóśźż]* (do )?huawei health'
)

TARGETS=()
for t in entry watch common docs README*; do
  if [ -e "$t" ]; then TARGETS+=("$t"); fi
done

HITS=0
for p in "${PATTERNS[@]}"; do
  OUT="$(grep -rIniE \
    --exclude-dir=build --exclude-dir=oh_modules --exclude-dir=node_modules \
    --exclude-dir=.preview --exclude-dir=.hvigor --exclude-dir=.test \
    -e "$p" "${TARGETS[@]}" || true)"
  if [ -n "$OUT" ]; then
    echo "$OUT"
    HITS=$((HITS + $(printf '%s\n' "$OUT" | wc -l)))
  fi
done

echo "Wording check: ${#PATTERNS[@]} patterns over ${TARGETS[*]}: $HITS hit(s)"
if [ "$HITS" -ne 0 ]; then exit 1; fi
