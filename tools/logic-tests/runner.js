// Runs the pure-logic tests of one module under Node, without an emulator.
//
// The .ets logic and test files are copied to a temporary directory as .ts, type-checked as strict
// TypeScript, compiled to CommonJS and executed against tools/logic-tests/hypium-shim.ts.
// This is a TypeScript check, not an ArkTS check: the ArkTS compiler (hvigorw assembleHar) is stricter
// and still has to be run separately. Nothing here touches the device APIs, so only files without
// @kit / @ohos imports (other than @ohos/hypium) can be tested this way.
//
// Called by tools/run-logic-tests.sh:  node runner.js <typescript dir> <repo root> <module> [test file] [dirs...]
"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");

const tsDir = process.argv[2];
const repoRoot = process.argv[3];
const moduleName = process.argv[4];
const rest = process.argv.slice(5);

if (!tsDir || !repoRoot || !moduleName) {
  console.error(
    "usage: node runner.js <typescript dir> <repo root> <module> [test file] [dirs...]",
  );
  process.exit(2);
}

const ts = require(path.join(tsDir, "lib", "typescript.js"));
const moduleRoot = path.join(repoRoot, moduleName);
if (!fs.existsSync(moduleRoot)) {
  console.error("No such module directory: " + moduleRoot);
  process.exit(2);
}

// First optional argument: a test file (path relative to the repo root, or absolute). The remaining ones are
// directories under <module>/src/main/ets whose files are all type-checked, imported by the test or not.
let testFiles = [];
let extraDirs = rest;
if (rest.length > 0 && /\.ets$/.test(rest[0])) {
  testFiles = [path.resolve(repoRoot, rest[0])];
  extraDirs = rest.slice(1);
} else {
  const testDir = path.join(moduleRoot, "src", "test");
  testFiles = fs
    .readdirSync(testDir)
    .filter(function (name) {
      return /\.test\.ets$/.test(name) && name !== "List.test.ets";
    })
    .sort()
    .map(function (name) {
      return path.join(testDir, name);
    });
}
for (const file of testFiles) {
  if (!fs.existsSync(file)) {
    console.error("No such test file: " + file);
    process.exit(2);
  }
}
if (testFiles.length === 0) {
  console.error(
    "No *.test.ets files in " + path.join(moduleRoot, "src", "test"),
  );
  process.exit(2);
}

function listEts(dir, out) {
  if (!fs.existsSync(dir)) {
    return out;
  }
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (
        entry.name !== "node_modules" &&
        entry.name !== "oh_modules" &&
        entry.name !== "build"
      ) {
        listEts(full, out);
      }
    } else if (/\.ets$/.test(entry.name)) {
      out.push(full);
    }
  }
  return out;
}

const work = fs.mkdtempSync(path.join(os.tmpdir(), "fairwear-logic-tests-"));
const srcOut = path.join(work, "src");
const jsOut = path.join(work, "js");

function toWork(file) {
  return path
    .join(srcOut, path.relative(repoRoot, file))
    .replace(/\.ets$/, ".ts");
}

function cleanUp() {
  try {
    fs.rmSync(work, { recursive: true, force: true });
  } catch (e) {
    // A leftover temporary directory is harmless.
  }
}

// Copy every .ets file of the module; only the files reachable from the roots are compiled.
const sources = listEts(path.join(moduleRoot, "src"), []);
const indexFile = path.join(moduleRoot, "Index.ets");
if (fs.existsSync(indexFile)) {
  sources.push(indexFile);
}
for (const file of sources) {
  const target = toWork(file);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.copyFileSync(file, target);
}
const shimSrc = path.join(__dirname, "hypium-shim.ts");
const shimWork = path.join(srcOut, "__shim__", "hypium.ts");
fs.mkdirSync(path.dirname(shimWork), { recursive: true });
fs.copyFileSync(shimSrc, shimWork);
// Node-backed ports (crypto, fs) for tests of logic that takes its platform through interfaces.
const portsWork = path.join(srcOut, "__shim__", "node-ports.ts");
fs.copyFileSync(path.join(__dirname, "node-ports.ts"), portsWork);

const roots = testFiles.map(toWork);
roots.push(shimWork);
roots.push(portsWork);
for (const dir of extraDirs) {
  const full = path.join(moduleRoot, "src", "main", "ets", dir);
  if (!fs.existsSync(full)) {
    console.error(
      "No such directory: " + path.relative(repoRoot, full) + " (skipped)",
    );
    continue;
  }
  for (const file of listEts(full, [])) {
    roots.push(toWork(file));
  }
}

const options = {
  target: ts.ScriptTarget.ES2021,
  module: ts.ModuleKind.CommonJS,
  moduleResolution: ts.ModuleResolutionKind.NodeJs,
  lib: ["lib.es2021.d.ts"],
  types: [],
  strict: true,
  noImplicitReturns: true,
  noFallthroughCasesInSwitch: true,
  esModuleInterop: false,
  skipLibCheck: true,
  rootDir: srcOut,
  outDir: jsOut,
  baseUrl: srcOut,
  paths: {
    "@ohos/hypium": ["__shim__/hypium.ts"],
    "@fairwear/node-ports": ["__shim__/node-ports.ts"],
  },
};

const program = ts.createProgram(roots, options);
const emitResult = program.emit();
const diagnostics = ts
  .getPreEmitDiagnostics(program)
  .concat(emitResult.diagnostics);
if (diagnostics.length > 0) {
  for (const d of diagnostics) {
    const text = ts.flattenDiagnosticMessageText(d.messageText, "\n");
    if (d.file && d.start !== undefined) {
      const pos = d.file.getLineAndCharacterOfPosition(d.start);
      const original = path
        .relative(srcOut, d.file.fileName)
        .replace(/\.ts$/, ".ets");
      console.error(
        original +
          ":" +
          (pos.line + 1) +
          ":" +
          (pos.character + 1) +
          " TS" +
          d.code +
          " " +
          text,
      );
    } else {
      console.error("TS" + d.code + " " + text);
    }
  }
  console.error(
    "\n  TypeScript check failed: " +
      diagnostics.length +
      " error(s). No tests were run.",
  );
  cleanUp();
  process.exit(1);
}

// The compiled files import '@ohos/hypium'; point that at the compiled shim.
const hypiumPackage = path.join(jsOut, "node_modules", "@ohos", "hypium");
fs.mkdirSync(hypiumPackage, { recursive: true });
fs.writeFileSync(
  path.join(hypiumPackage, "index.js"),
  "module.exports = require('../../../__shim__/hypium.js');\n",
);
const portsPackage = path.join(
  jsOut,
  "node_modules",
  "@fairwear",
  "node-ports",
);
fs.mkdirSync(portsPackage, { recursive: true });
fs.writeFileSync(
  path.join(portsPackage, "index.js"),
  "module.exports = require('../../../__shim__/node-ports.js');\n",
);

function toJs(file) {
  return path
    .join(jsOut, path.relative(srcOut, toWork(file)))
    .replace(/\.ts$/, ".js");
}

async function main() {
  const shim = require(path.join(jsOut, "__shim__", "hypium.js"));
  for (const file of testFiles) {
    const loaded = require(toJs(file));
    if (typeof loaded.default !== "function") {
      throw new Error(
        path.relative(repoRoot, file) + " has no default export function",
      );
    }
    loaded.default();
  }
  const outcomes = await shim.runRegisteredSuites();
  let passed = 0;
  console.log(
    "Node run (TypeScript " +
      ts.version +
      " strict, hypium shim), " +
      testFiles
        .map(function (f) {
          return path.relative(repoRoot, f).split(path.sep).join("/");
        })
        .join(", ") +
      ":",
  );
  console.log("");
  for (const o of outcomes) {
    if (o.passed) {
      passed++;
      console.log("  ✓ " + o.suite + " > " + o.name);
    } else {
      console.log("  ✗ " + o.suite + " > " + o.name);
      console.log("      " + o.message);
    }
  }
  console.log("");
  console.log("  " + passed + "/" + outcomes.length + " passed");
  return outcomes.length > 0 && passed === outcomes.length ? 0 : 1;
}

main()
  .then(function (code) {
    cleanUp();
    process.exit(code);
  })
  .catch(function (e) {
    console.error(e && e.stack ? e.stack : String(e));
    cleanUp();
    process.exit(1);
  });
