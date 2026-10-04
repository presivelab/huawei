#!/usr/bin/env bash
# UI text check: no screen text written as a literal in the UI sources. Every text the user sees or hears
# comes from a string resource: Text($r('app.string.…')), or str($r('app.string.…'), value) for a text
# with a value (entry/src/main/ets/ui/Strings.ets, watch/src/main/ets/ui/Strings.ets).
# Usage (Git Bash): tools/check-ui-literals.sh     exit 0 = 0 hits, exit 1 = at least one hit (printed).
#
# Looks for a literal handed straight to Text, Button, accessibilityText, accessibilityDescription or a
# toast / dialog message. It does not look into common: its sentences are phase 2 (docs/ARCHITECTURE.md).
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

PATTERNS=(
  "Text('"
  'Text("'
  'Text(`'
  "Button('"
  'Button("'
  'Button(`'
  "accessibilityText('"
  'accessibilityText("'
  'accessibilityText(`'
  "accessibilityDescription('"
  'accessibilityDescription("'
  'accessibilityDescription(`'
  "message: '"
  'message: "'
  'message: `'
)

TARGETS=()
for t in entry/src/main/ets/view entry/src/main/ets/ui entry/src/main/ets/widget entry/src/main/ets/pages \
  watch/src/main/ets/pages watch/src/main/ets/ui; do
  if [ -e "$t" ]; then TARGETS+=("$t"); fi
done

ARGS=()
for p in "${PATTERNS[@]}"; do ARGS+=(-e "$p"); done

OUT="$(grep -rInF --include='*.ets' "${ARGS[@]}" "${TARGETS[@]}" \
  | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(//|\*|/\*)' || true)"
HITS=0
if [ -n "$OUT" ]; then
  echo "$OUT"
  HITS=$(printf '%s\n' "$OUT" | wc -l)
fi
echo "UI literal check: ${#PATTERNS[@]} patterns over ${TARGETS[*]}: $HITS hit(s)"

if [ "$HITS" -ne 0 ]; then exit 1; fi
