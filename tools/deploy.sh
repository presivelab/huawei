#!/usr/bin/env bash
# Builds one app module, installs the unsigned debug HAP on the matching emulator and starts it.
# Usage (Git Bash): tools/deploy.sh entry | tools/deploy.sh watch
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source tools/env.sh
MODULE="${1:-entry}"
case "$MODULE" in
  entry) DEVTYPE=phone; ABILITY=EntryAbility ;;
  watch) DEVTYPE=wearable; ABILITY=WatchAbility ;;
  *) echo "usage: tools/deploy.sh entry|watch"; exit 2 ;;
esac
export MSYS_NO_PATHCONV=1
TARGET=""
for t in $(hdc list targets | tr -d '\r' | grep -E '^[0-9.]+:[0-9]+$' || true); do
  if [ "$(hdc -t "$t" shell param get const.product.devicetype | tr -d '\r ')" = "$DEVTYPE" ]; then TARGET="$t"; fi
done
if [ -z "$TARGET" ]; then echo "No running $DEVTYPE emulator found (hdc list targets)."; exit 3; fi
LOG="$(mktemp)"
hvigorw.bat assembleHap --mode module -p module="$MODULE@default" -p product=default -p buildMode=debug --no-daemon \
  > "$LOG" 2>&1 || true
sed 's/\x1b\[[0-9;]*m//g' "$LOG" | grep -E "ERROR|WARN: ArkTS|BUILD|error" | grep -v "skip sign" || true
# A failed build must not install the previous HAP.
if ! sed 's/\x1b\[[0-9;]*m//g' "$LOG" | grep -q "BUILD SUCCESSFUL"; then
  echo "Build failed: nothing installed. Full log: $LOG"
  exit 4
fi
HAP="$MODULE/build/default/outputs/default/$MODULE-default-unsigned.hap"
hdc -t "$TARGET" install -r "$(cygpath -w "$PWD/$HAP")"
hdc -t "$TARGET" shell aa force-stop com.fairwear.app > /dev/null || true
hdc -t "$TARGET" shell aa start -b com.fairwear.app -m "$MODULE" -a "$ABILITY"
echo "target=$TARGET ($DEVTYPE)"
