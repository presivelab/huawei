# Build the debug HAP with DevEco's own toolchain, install it on the watch target and restart the app.
# Usage: source tools/build-deploy.sh   (WATCH_TARGET=<ip:port> for a real watch)
D="/c/Program Files/Huawei/DevEco Studio"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/watch.sh"
export DEVECO_SDK_HOME="C:\Program Files\Huawei\DevEco Studio\sdk" NODE_HOME="C:\Program Files\Huawei\DevEco Studio\tools\node" JAVA_HOME="C:\Program Files\Huawei\DevEco Studio\jbr"
export PATH="$D/tools/node:$D/tools/ohpm/bin:$D/tools/hvigor/bin:$D/jbr/bin:$PATH"
( cd "$PROJECT_DIR" && MSYS_NO_PATHCONV= hvigorw.bat assembleHap --mode module -p product=default -p buildMode=debug --no-daemon 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -v -E "Finished :entry|UP-TO-DATE|npm audit|Pnpm|skip sign|configure the signingConfigs" | tail -n 40 )
# A real watch only accepts the signed HAP; the emulator takes either.
OUT_DIR="$PROJECT_DIR/entry/build/default/outputs/default"
HAP="$(ls -t "$OUT_DIR"/*-signed.hap 2>/dev/null | head -n 1)"
[ -z "$HAP" ] && HAP="$(ls -t "$OUT_DIR"/*.hap 2>/dev/null | head -n 1)"
echo "installing $(basename "$HAP") on $WATCH_TARGET"
w install -r "$(cygpath -w "$HAP")" | head -n 1 | grep -o "msg:.*"
w shell aa force-stop "$BUNDLE" > /dev/null
w shell aa start -b "$BUNDLE" -a EntryAbility | tail -n 1
