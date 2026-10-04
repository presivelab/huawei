#!/usr/bin/env bash
# Uruchamia testy logiki (entry/src/test/Logic.test.ets) w Node, bez DevEco Studio i bez emulatora.
# Wymaga: Node 18+ i dostępu do npm (pobiera TypeScript przez npx).
# Pliki .ets z model/ i logic/ to podzbiór TypeScriptu (bez UI i kitów), więc kompilują się zwykłym tsc --strict.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/src/main/ets" "$WORK/src/test" "$WORK/node_modules/@ohos/hypium"
cp -r "$ROOT/entry/src/main/ets/model" "$ROOT/entry/src/main/ets/logic" "$WORK/src/main/ets/"
cp "$ROOT/entry/src/test/Logic.test.ets" "$WORK/src/test/"
find "$WORK/src" -name '*.ets' | while read -r f; do mv "$f" "${f%.ets}.ts"; done
cp "$ROOT/tools/hypium-shim.js" "$WORK/node_modules/@ohos/hypium/index.js"
cp "$ROOT/tools/hypium-shim.d.ts" "$WORK/node_modules/@ohos/hypium/index.d.ts"

cd "$WORK"
npx --yes -p typescript@5 tsc --strict --noImplicitAny --noUnusedLocals --target es2020 --lib es2020 \
  --module commonjs --rootDir . --outDir out src/test/Logic.test.ts

cat > run.js <<'EOF'
const hypium = require('@ohos/hypium');
require('./out/src/test/Logic.test.js').default();
process.exitCode = hypium.report();
EOF
node run.js
