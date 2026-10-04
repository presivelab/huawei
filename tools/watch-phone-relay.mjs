#!/usr/bin/env node
// FairWear Watch Link dev relay (emulators only).
//
// The watch and phone emulators cannot pair over Wear Engine, so this script carries, over hdc, the same
// files the real transport would carry:
//
//   watch  pair.json + outbox/<seq>.json  ->  _relay/  ->  phone  inbox/
//   phone  acks/<seq>.json                ->  _relay/  ->  watch  acks/
//
// It never deletes app data: the apps delete their own files after an ACK. It never changes a packet,
// except with the demo-only flag --tamper, which says so loudly.
//
// Usage:  node tools/watch-phone-relay.mjs [once|pull|push] [--watch] [--dry-run] [--tamper] [--drop <seq>]
//
//   once        (default) watch -> phone, then phone ACKs -> watch
//   pull        talk to the watch only: fetch its files, deliver ACKs already in _relay/
//   push        talk to the phone only: deliver the fetched files, fetch its ACKs
//               (pull / push are for when both emulators cannot run at the same time)
//   --watch     repeat every 2 s
//   --dry-run   print the hdc commands, run nothing
//   --tamper    DEMO ONLY: flip one character of `slots` before pushing -> the phone must say "Invalid signature"
//   --drop N    DEMO ONLY: do not push packet N in this run -> the phone shows "Missing 1 day(s)"
//
// Environment:  HDC (path to hdc), WATCH_T / PHONE_T (hdc target keys, when the device type cannot be read)
//
// Requirements: debug-signed builds (DevEco Run or tools/deploy.sh) and the app started on each device;
// `hdc ... -b <bundle>` reaches the sandbox of a debug app only. Node 18 or newer, no dependencies.

import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const BUNDLE = "com.fairwear.app";
// The app's filesDir as hdc sees it with -b. Checked on the API 24 emulators:
// `hdc shell -b com.fairwear.app ls data/storage/el2/base/` lists `files`.
const FILES = "data/storage/el2/base/files";
const POLL_MS = 2000;
const ACK_WAIT_MS = 7000;
const REPUSH_AFTER_MS = 30000;

const repoRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const relayDir = path.join(repoRoot, "_relay");
const stateFile = path.join(relayDir, "state.json");

const argv = process.argv.slice(2);
const flags = { watch: false, dryRun: false, tamper: false, drop: 0 };
let mode = "once";
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === "once" || a === "pull" || a === "push") {
    mode = a;
  } else if (a === "--watch") {
    flags.watch = true;
  } else if (a === "--dry-run") {
    flags.dryRun = true;
  } else if (a === "--tamper") {
    flags.tamper = true;
  } else if (a === "--drop") {
    flags.drop = Number.parseInt(argv[++i] ?? "", 10);
    if (!Number.isInteger(flags.drop) || flags.drop < 1) {
      fail("--drop needs a packet number, e.g. --drop 3");
    }
  } else {
    fail(
      `unknown argument: ${a}\nusage: node tools/watch-phone-relay.mjs [once|pull|push] [--watch] [--dry-run] [--tamper] [--drop <seq>]`,
    );
  }
}

function fail(message) {
  console.error(message);
  process.exit(2);
}

function log(line) {
  console.log(line);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// ---------- hdc ----------

function findHdc() {
  const candidates = [];
  if (process.env.HDC) {
    candidates.push(process.env.HDC);
  }
  candidates.push("hdc");
  const devecoHome =
    process.env.DEVECO_HOME || "C:\\Program Files\\Huawei\\DevEco Studio";
  candidates.push(
    path.join(
      devecoHome,
      "sdk",
      "default",
      "openharmony",
      "toolchains",
      "hdc.exe",
    ),
  );
  for (const candidate of candidates) {
    const probe = spawnSync(candidate, ["-v"], { encoding: "utf8" });
    if (!probe.error && probe.status === 0) {
      return candidate;
    }
  }
  fail(
    "hdc not found. Set HDC to its path, put it on PATH, or install DevEco Studio in the default location.",
  );
  return "";
}

// --dry-run only prints the commands, so it works without hdc installed.
const hdc = flags.dryRun ? "hdc" : findHdc();

// Runs one hdc command, logs it and its result. With --dry-run only prints it.
function run(args, { quiet = false } = {}) {
  const shown = `hdc ${args.map((a) => (/\s/.test(a) ? `"${a}"` : a)).join(" ")}`;
  if (flags.dryRun) {
    log(`[dry-run] ${shown}`);
    return { ok: true, out: "" };
  }
  const result = spawnSync(hdc, args, { encoding: "utf8" });
  const out = `${result.stdout ?? ""}${result.stderr ?? ""}`
    .replace(/\r/g, "")
    .trim();
  const failed =
    Boolean(result.error) ||
    result.status !== 0 ||
    /\[Fail\]|No such file|not found|error:/i.test(out);
  if (!quiet || failed) {
    log(`$ ${shown}`);
    if (out.length > 0) {
      log(
        out
          .split("\n")
          .map((line) => `    ${line}`)
          .join("\n"),
      );
    }
  }
  return { ok: !failed, out };
}

function findTargets() {
  let watchTarget = process.env.WATCH_T || "";
  let phoneTarget = process.env.PHONE_T || "";
  if (flags.dryRun) {
    return {
      watchTarget: watchTarget || "<WATCH_T>",
      phoneTarget: phoneTarget || "<PHONE_T>",
    };
  }
  const listed = run(["list", "targets"]);
  const keys = listed.out
    .split("\n")
    .map((line) => line.trim().split(/\s+/)[0])
    .filter((k) => k && k !== "[Empty]");
  for (const key of keys) {
    const type = run([
      "-t",
      key,
      "shell",
      "param",
      "get",
      "const.product.devicetype",
    ]).out.trim();
    if (type === "wearable" && !watchTarget) {
      watchTarget = key;
    } else if (type === "phone" && !phoneTarget) {
      phoneTarget = key;
    }
  }
  return { watchTarget, phoneTarget };
}

// ---------- sandbox access (debug apps only) ----------

function ls(target, dir) {
  const result = run(["-t", target, "shell", "-b", BUNDLE, "ls", dir], {
    quiet: true,
  });
  if (!result.ok) {
    return [];
  }
  return result.out.split(/\s+/).filter((name) => name.length > 0);
}

function checkSandbox(target, label) {
  if (flags.dryRun) {
    run(["-t", target, "shell", "-b", BUNDLE, "ls", "data/storage/el2/base/"]);
    return true;
  }
  const result = run([
    "-t",
    target,
    "shell",
    "-b",
    BUNDLE,
    "ls",
    "data/storage/el2/base/",
  ]);
  if (!result.ok || !result.out.split(/\s+/).includes("files")) {
    log(
      `! ${label}: cannot read the app sandbox. Is a debug build of ${BUNDLE} installed and started there?`,
    );
    return false;
  }
  return true;
}

function recv(target, remote, local) {
  fs.mkdirSync(path.dirname(local), { recursive: true });
  return run(["-t", target, "file", "recv", "-b", BUNDLE, remote, local]).ok;
}

function send(target, local, remoteDir, name) {
  run(["-t", target, "shell", "-b", BUNDLE, "mkdir", "-p", remoteDir], {
    quiet: true,
  });
  return run([
    "-t",
    target,
    "file",
    "send",
    "-b",
    BUNDLE,
    local,
    `${remoteDir}/${name}`,
  ]).ok;
}

// ---------- relay state: what was already delivered ----------

function readState() {
  try {
    const state = JSON.parse(fs.readFileSync(stateFile, "utf8"));
    return { pushed: state.pushed ?? {}, acked: state.acked ?? {} };
  } catch {
    return { pushed: {}, acked: {} };
  }
}

function writeState(state) {
  if (flags.dryRun) {
    return;
  }
  fs.mkdirSync(relayDir, { recursive: true });
  fs.writeFileSync(stateFile, JSON.stringify(state, null, 2));
}

// Removes the relay's own copy of an ACK (_relay/phone/acks). The phone's file is not touched.
function dropKeptAck(name) {
  fs.rmSync(path.join(relayDir, "phone", "acks", name), { force: true });
}

function hashOf(file) {
  return createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}

function isPacketName(name) {
  return /^\d+\.json$/.test(name);
}

function seqOf(name) {
  return Number.parseInt(name, 10);
}

// ---------- demo-only tampering ----------

function tamperedCopy(local, name) {
  const text = fs.readFileSync(local, "utf8");
  const marker = '"slots":"';
  const at = text.indexOf(marker);
  if (at < 0) {
    return local;
  }
  const pos = at + marker.length;
  const flipped = text[pos] === "W" ? "O" : "W";
  const out = path.join(relayDir, "tampered", name);
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, text.slice(0, pos) + flipped + text.slice(pos + 1));
  log("");
  log("  ####################################################################");
  log(
    `  ##  DEMO TAMPER: packet ${name} is pushed with one slots character changed`,
  );
  log(
    `  ##  (${text[pos]} -> ${flipped}). The phone must answer "Invalid signature".`,
  );
  log("  ####################################################################");
  log("");
  return out;
}

// ---------- the four legs ----------

// watch -> _relay/watch
function pullFromWatch(watchTarget) {
  const fetched = [];
  if (flags.dryRun) {
    run(["-t", watchTarget, "shell", "-b", BUNDLE, "ls", FILES]);
    run(["-t", watchTarget, "shell", "-b", BUNDLE, "ls", `${FILES}/outbox`]);
    run([
      "-t",
      watchTarget,
      "file",
      "recv",
      "-b",
      BUNDLE,
      `${FILES}/pair.json`,
      path.join(relayDir, "watch", "pair.json"),
    ]);
    run([
      "-t",
      watchTarget,
      "file",
      "recv",
      "-b",
      BUNDLE,
      `${FILES}/outbox/<seq>.json`,
      path.join(relayDir, "watch", "outbox", "<seq>.json"),
    ]);
    return fetched;
  }
  // Start from what the watch has now: a packet it already deleted (ACKed) must not be pushed again.
  fs.rmSync(path.join(relayDir, "watch"), { recursive: true, force: true });
  if (ls(watchTarget, FILES).includes("pair.json")) {
    const local = path.join(relayDir, "watch", "pair.json");
    if (recv(watchTarget, `${FILES}/pair.json`, local)) {
      fetched.push("pair.json");
    }
  }
  const names = ls(watchTarget, `${FILES}/outbox`)
    .filter(isPacketName)
    .sort((a, b) => seqOf(a) - seqOf(b));
  for (const name of names) {
    if (
      recv(
        watchTarget,
        `${FILES}/outbox/${name}`,
        path.join(relayDir, "watch", "outbox", name),
      )
    ) {
      fetched.push(name);
    }
  }
  log(
    `watch -> relay: ${fetched.length > 0 ? fetched.join(", ") : "nothing to carry"}`,
  );
  return fetched;
}

// _relay/watch -> phone inbox/
function pushToPhone(phoneTarget, state) {
  if (flags.dryRun) {
    run([
      "-t",
      phoneTarget,
      "shell",
      "-b",
      BUNDLE,
      "mkdir",
      "-p",
      `${FILES}/inbox`,
    ]);
    run([
      "-t",
      phoneTarget,
      "file",
      "send",
      "-b",
      BUNDLE,
      path.join(relayDir, "watch", "outbox", "<seq>.json"),
      `${FILES}/inbox/<seq>.json`,
    ]);
    return 0;
  }
  const now = Date.now();
  let pushed = 0;
  const pairLocal = path.join(relayDir, "watch", "pair.json");
  if (fs.existsSync(pairLocal)) {
    // A pairing request is delivered once; tap "Pair phone" on the watch again for a new one.
    const hash = hashOf(pairLocal);
    if (state.pushed["pair.json"]?.hash !== hash) {
      if (send(phoneTarget, pairLocal, `${FILES}/inbox`, "pair.json")) {
        state.pushed["pair.json"] = { hash, at: now };
        // A new pairing gets a new answer, even when its ACK text is the same as last time. The answer
        // kept from the previous pairing is dropped: the watch must not hear "Paired" before Confirm.
        delete state.acked["0.json"];
        dropKeptAck("0.json");
        pushed++;
      }
    }
  }
  const outboxDir = path.join(relayDir, "watch", "outbox");
  const names = fs.existsSync(outboxDir)
    ? fs.readdirSync(outboxDir).filter(isPacketName)
    : [];
  names.sort((a, b) => seqOf(a) - seqOf(b));
  let tamperedOne = false;
  for (const name of names) {
    if (flags.drop === seqOf(name)) {
      log(`  DEMO DROP: packet ${name} is not pushed in this run.`);
      continue;
    }
    let local = path.join(outboxDir, name);
    const hash = hashOf(local);
    const before = state.pushed[name];
    // In --watch mode an unanswered packet is retried every 30 s, not every 2 s.
    if (
      flags.watch &&
      before?.hash === hash &&
      now - before.at < REPUSH_AFTER_MS
    ) {
      continue;
    }
    if (flags.tamper && !tamperedOne) {
      local = tamperedCopy(local, name);
      tamperedOne = true;
    }
    if (send(phoneTarget, local, `${FILES}/inbox`, name)) {
      if (before?.hash !== hash) {
        // A packet the phone has not seen gets its ACK delivered, even when the ACK text repeats an older
        // run (rehearsal, then the real demo). The answer kept for the older packet is dropped.
        delete state.acked[name];
        dropKeptAck(name);
      }
      state.pushed[name] = { hash, at: now };
      pushed++;
    }
  }
  log(`relay -> phone: ${pushed} file(s) pushed to inbox/`);
  return pushed;
}

// phone acks/ -> _relay/phone/acks (waits until the phone app has emptied its inbox)
async function pullAcksFromPhone(phoneTarget, waitForInbox) {
  if (flags.dryRun) {
    run(["-t", phoneTarget, "shell", "-b", BUNDLE, "ls", `${FILES}/acks`]);
    run([
      "-t",
      phoneTarget,
      "file",
      "recv",
      "-b",
      BUNDLE,
      `${FILES}/acks/<seq>.json`,
      path.join(relayDir, "phone", "acks", "<seq>.json"),
    ]);
    return;
  }
  if (waitForInbox) {
    const deadline = Date.now() + ACK_WAIT_MS;
    while (
      ls(phoneTarget, `${FILES}/inbox`).length > 0 &&
      Date.now() < deadline
    ) {
      await sleep(500);
    }
    if (ls(phoneTarget, `${FILES}/inbox`).length > 0) {
      log(
        '! the phone app has not read its inbox yet. Bring FairWear to the foreground or tap "Sync now", then run the relay again.',
      );
    }
  }
  const names = ls(phoneTarget, `${FILES}/acks`).filter(isPacketName);
  for (const name of names) {
    recv(
      phoneTarget,
      `${FILES}/acks/${name}`,
      path.join(relayDir, "phone", "acks", name),
    );
  }
}

// _relay/phone/acks -> watch acks/ (each distinct ACK once)
function pushAcksToWatch(watchTarget, state) {
  if (flags.dryRun) {
    run([
      "-t",
      watchTarget,
      "shell",
      "-b",
      BUNDLE,
      "mkdir",
      "-p",
      `${FILES}/acks`,
    ]);
    run([
      "-t",
      watchTarget,
      "file",
      "send",
      "-b",
      BUNDLE,
      path.join(relayDir, "phone", "acks", "<seq>.json"),
      `${FILES}/acks/<seq>.json`,
    ]);
    return;
  }
  const dir = path.join(relayDir, "phone", "acks");
  const names = fs.existsSync(dir)
    ? fs.readdirSync(dir).filter(isPacketName)
    : [];
  names.sort((a, b) => seqOf(a) - seqOf(b));
  const delivered = [];
  for (const name of names) {
    const local = path.join(dir, name);
    const hash = hashOf(local);
    if (state.acked[name] === hash) {
      continue;
    }
    if (send(watchTarget, local, `${FILES}/acks`, name)) {
      state.acked[name] = hash;
      try {
        const ack = JSON.parse(fs.readFileSync(local, "utf8"));
        delivered.push(`#${ack.seq} ${ack.status} (${ack.reason})`);
      } catch {
        delivered.push(name);
      }
    }
  }
  log(
    `phone -> watch: ${delivered.length > 0 ? delivered.join("; ") : "no new ACK"}`,
  );
}

// ---------- main ----------

async function runOnce(targets) {
  const state = readState();
  const needWatch = mode !== "push";
  const needPhone = mode !== "pull";
  if (needWatch && !targets.watchTarget) {
    fail("No wearable target found. Start the watch emulator or set WATCH_T.");
  }
  if (needPhone && !targets.phoneTarget) {
    fail("No phone target found. Start the phone emulator or set PHONE_T.");
  }
  if (needWatch) {
    pullFromWatch(targets.watchTarget);
  }
  if (needPhone) {
    const pushed = pushToPhone(targets.phoneTarget, state);
    await pullAcksFromPhone(targets.phoneTarget, pushed > 0);
  }
  if (needWatch) {
    pushAcksToWatch(targets.watchTarget, state);
  }
  writeState(state);
}

async function main() {
  log(
    `FairWear watch-phone relay · mode ${mode}${flags.watch ? " · --watch" : ""}${flags.dryRun ? " · --dry-run" : ""}`,
  );
  if (flags.tamper || flags.drop > 0) {
    log(
      "DEMO flags are on. Packets are deliberately damaged or held back in this run.",
    );
  }
  const targets = findTargets();
  log(
    `watch target: ${targets.watchTarget || "(none)"} · phone target: ${targets.phoneTarget || "(none)"}`,
  );
  if (
    mode !== "push" &&
    targets.watchTarget &&
    !checkSandbox(targets.watchTarget, "watch")
  ) {
    process.exit(3);
  }
  if (
    mode !== "pull" &&
    targets.phoneTarget &&
    !checkSandbox(targets.phoneTarget, "phone")
  ) {
    process.exit(3);
  }
  await runOnce(targets);
  // --tamper and --drop act on one run only, also with --watch.
  while (flags.watch && !flags.dryRun) {
    flags.tamper = false;
    flags.drop = 0;
    await sleep(POLL_MS);
    await runOnce(targets);
  }
}

main().catch((e) => {
  console.error(e?.stack ?? String(e));
  process.exit(1);
});
