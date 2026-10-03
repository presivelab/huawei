#!/usr/bin/env bash
# Saves a screenshot of the phone or watch emulator. Usage: tools/shot.sh phone|wearable docs/screenshots/name.jpeg
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source tools/env.sh
DEVTYPE="$1"; OUT="$2"
export MSYS_NO_PATHCONV=1
TARGET=""
for t in $(hdc list targets | tr -d '\r' | grep -E '^[0-9.]+:[0-9]+$' || true); do
  if [ "$(hdc -t "$t" shell param get const.product.devicetype | tr -d '\r ')" = "$DEVTYPE" ]; then TARGET="$t"; fi
done
if [ -z "$TARGET" ]; then echo "No running $DEVTYPE emulator found."; exit 3; fi
mkdir -p "$(dirname "$OUT")"
hdc -t "$TARGET" shell snapshot_display -f /data/local/tmp/shot.jpeg > /dev/null
hdc -t "$TARGET" file recv /data/local/tmp/shot.jpeg "$(cygpath -w "$PWD/$OUT")" > /dev/null
echo "$OUT"
