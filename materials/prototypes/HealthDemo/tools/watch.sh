# Helpers for a HarmonyOS watch target (emulator by default). Usage: source tools/watch.sh
# Override the target with WATCH_TARGET=<ip:port> for a real watch connected over Wi-Fi.
export MSYS_NO_PATHCONV=1
HDC="/c/Program Files/Huawei/DevEco Studio/sdk/default/openharmony/toolchains/hdc.exe"
WATCH_TARGET="${WATCH_TARGET:-127.0.0.1:5555}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHOTS_DIR="$PROJECT_DIR/docs/shots"
BUNDLE="com.fairwear.healthdemo"
w() { "$HDC" -t "$WATCH_TARGET" "$@" 2>&1 | tr -d '\r'; }
shot() { w shell snapshot_display -f /data/local/tmp/$1.jpeg > /dev/null; w file recv /data/local/tmp/$1.jpeg "$(cygpath -w "$SHOTS_DIR/$1.jpeg")" | tail -n 1; }
tap() { w shell uitest uiInput click $1 $2 | tail -n 1; }
# Page turns need a long, fast swipe (a 200 px one at 600 px/s springs back); scroll_* drags a list slowly.
swipe_up() { w shell uitest uiInput swipe 233 400 233 60 1500 | tail -n 1; }
swipe_down() { w shell uitest uiInput swipe 233 60 233 400 1500 | tail -n 1; }
scroll_up() { w shell uitest uiInput swipe 233 330 233 150 500 | tail -n 1; }
scroll_down() { w shell uitest uiInput swipe 233 150 233 330 500 | tail -n 1; }
nap() { ping -n $(( $1 + 1 )) 127.0.0.1 > /dev/null; }
applog() { w shell "hilog -x -T HealthDemo" | tail -n "${1:-20}"; }
