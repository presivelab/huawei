# Puts DevEco Studio's bundled toolchain on PATH. Usage (Git Bash): source tools/env.sh
DEVECO_HOME="${DEVECO_HOME:-/c/Program Files/Huawei/DevEco Studio}"
export DEVECO_SDK_HOME="$(cygpath -w "$DEVECO_HOME/sdk")"
export NODE_HOME="$(cygpath -w "$DEVECO_HOME/tools/node")"
export JAVA_HOME="$(cygpath -w "$DEVECO_HOME/jbr")"
export PATH="$DEVECO_HOME/tools/node:$DEVECO_HOME/tools/ohpm/bin:$DEVECO_HOME/tools/hvigor/bin:$DEVECO_HOME/jbr/bin:$DEVECO_HOME/sdk/default/openharmony/toolchains:$PATH"
