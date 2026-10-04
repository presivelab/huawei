#!/usr/bin/env bash
# Text check: wordings FairWear must not use about HUAWEI Health, Huawei or the score.
# Searches entry, watch, common, README* and docs/ (sources and documents, not build output).
# Usage (Git Bash): tools/check-wording.sh     exit 0 = 0 hits, exit 1 = at least one hit (printed).
#
# This file lists the wordings, so it lives in tools/, which is not searched.
# docs/prompts/ is not searched either: the team's briefs there quote these wordings in their "never say" lists.
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
    --exclude-dir=prompts \
    -e "$p" "${TARGETS[@]}" || true)"
  if [ -n "$OUT" ]; then
    echo "$OUT"
    HITS=$((HITS + $(printf '%s\n' "$OUT" | wc -l)))
  fi
done

echo "Wording check: ${#PATTERNS[@]} patterns over ${TARGETS[*]}: $HITS hit(s)"

# Status enum names (NOT_AUTHORIZED, DEMO, UNAVAILABLE, CONNECTED) are for logs and tests. On screen the
# user reads "Not connected", "Demo data", "Unavailable in this build", "Connected".
# This looks for an enum name inside a string literal in the UI sources and resource strings.
# Skipped: comment lines, log calls, and the demo-clock labels "DEMO ×300" / "DEMO TIME", which the
# Watch Link brief asks for by that exact text and which are not the status enum.
UI_TARGETS=()
for t in entry/src/main/ets watch/src/main/ets entry/src/main/resources watch/src/main/resources \
  common/src/main/ets/card common/src/main/ets/health/HealthStatusLabel.ets; do
  if [ -e "$t" ]; then UI_TARGETS+=("$t"); fi
done
QUOTE="['\"\`]"
NOTQUOTE="[^'\"\`]"
ENUM_OUT="$(grep -rInE --include='*.ets' --include='*.json' \
  -e "${QUOTE}${NOTQUOTE}*\b(NOT_AUTHORIZED|UNAVAILABLE|CONNECTED|DEMO)\b${NOTQUOTE}*${QUOTE}" "${UI_TARGETS[@]}" \
  | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(//|\*|/\*)' \
  | grep -vE 'hilog\.|DEMO ×300|DEMO TIME' || true)"
ENUM_HITS=0
if [ -n "$ENUM_OUT" ]; then
  echo "$ENUM_OUT"
  ENUM_HITS=$(printf '%s\n' "$ENUM_OUT" | wc -l)
fi
echo "Enum-in-UI check: 4 status names over ${UI_TARGETS[*]}: $ENUM_HITS hit(s)"

if [ "$HITS" -ne 0 ] || [ "$ENUM_HITS" -ne 0 ]; then exit 1; fi
