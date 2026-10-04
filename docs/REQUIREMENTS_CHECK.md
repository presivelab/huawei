# Hackathon requirements: working check

Working notes behind the README section "For the jury" (judging criteria → where to see them).
Source of the requirements: `hackathon_challenge.md` and `FAQ.md` in `onirodeveloper/hackyeah2026-challenge`.
Every row names its evidence. A row without evidence is marked open.

State on 2026-10-04, branch `feature/hes-vnext` (base `merge/final-into-main` 6d77065), from `docs/test-results.txt`: the score model is HES vNext, the Health Engagement Score (`docs/HES.md`); logic tests `common` 467/467, `watch` 6/6; `assembleHar` for `common` and `assembleHap` for `entry` and `watch` of FairWear and of Health Sim BUILD SUCCESSFUL (unsigned debug); lint 0 errors (7 warnings in `entry`, 2 in `watch`, 0 issues in `common`; Health Sim: 2 warnings in `entry`, 1 in `watch`); wording check 0 hits; `tools/check-single-engine.sh` and `tools/check-oracle.sh` pass. B2 is met for every
product screen: the Health Sim connect path, Report, "Why this tier", Evidence, Share, the partner view and
"What left this phone" on the Phone emulator; the dial, the recorder and "Get today from Health Sim" on the
Wearable emulator (`docs/screenshots/final/`, `docs/screenshots/`). Earlier versions of this file, written on
`feature/entry-routing` and `feature/home-card`, are in the git history. The screenshots in `docs/screenshots/final/` were taken before HES vNext; for HES vNext only the watch label was checked on an emulator (`docs/screenshots/vnext/`); the phone and Health Sim screens of this build were built and not walked, as the block in `docs/test-results.txt` says. The table below is the current state.

## Status

| Point | Requirement                                 | Status                          | Evidence                                                                                                               |
| ----- | ------------------------------------------- | ------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| B1    | API 20 or later, API 20 declared as minimum | met                             | `build-profile.json5`, see "API levels" below                                                                          |
| B2    | Runs on an emulator, not only the Previewer | met                             | product screens on the Phone emulator, recorder and dial on the Wearable emulator: `docs/screenshots/final/`, `docs/screenshots/watchlink-*`, `docs/test-results.txt` |
| B6    | Public-safe repository                      | open, owner decision            | no signing material, no secrets in any branch; commit metadata carries a private e-mail address, see "History scan"    |
| B11   | AI features in the product                  | none, in code and in documents  | see "AI features"                                                                                                      |
| B13   | Unknown `fwTarget` handled                  | met                             | `common/src/main/ets/nav/EntryTarget.ets`, 12 tests in `common/src/test/EntryTarget.test.ets`; checked on the Phone emulator |
| B13   | Software key instead of HUKS                | code path exists, not exercised | `common/src/main/ets/platform/ProofSigner.ets`; on both emulators HUKS succeeded, so the fallback never ran            |
| B14   | Permissions justified, none unused          | met today                       | see "Permissions"                                                                                                      |
| B14   | No secrets, no risky dependencies           | met                             | "History scan"; dependencies are `@ohos/hypium` and `@ohos/hamock`, dev only                                           |
| B14   | Lint                                        | met                             | `docs/test-results.txt`, DevEco CLI 1.3.4: 0 errors; warnings of one performance rule only                              |
| B18   | History shows progress                      | met so far                      | `git log`: no squash, one commit per step                                                                              |

Deliverables (challenge statement, "Required Deliverables"):

| Deliverable | State | Evidence |
| --- | --- | --- |
| Public source code repository | open, owner decision (the repository is private for now) | before it is shown: drop the working branches (`materials`, `merge/all-into-main`, `feature/health-sim-audit`, session-report commits), decide on the commit e-mail addresses |
| Setup, build, installation and launch instructions | met | `README.md`, "How to install" (versions, emulators, commands) |
| Working `.hap` | built, unsigned debug | `entry/build/default/outputs/default/entry-default-unsigned.hap`, same path under `watch/`; a signed build needs the owner's Huawei account (FAQ) |
| Brief recorded demonstration | open | script: `docs/DEMO_SCRIPT.md` |
| Architecture and implementation description | met | `docs/ARCHITECTURE.md`, `docs/HES.md`, `docs/WATCH_LINK.md` |
| `AI_WORKFLOW.md` | met | `AI_WORKFLOW.md` |
| AI integration documentation | not applicable | no AI feature in the product (B11) |

## API levels (B1)

Root `build-profile.json5`, product `default`:

| Setting                | Value        |
| ---------------------- | ------------ |
| `runtimeOS`            | `HarmonyOS`  |
| `compatibleSdkVersion` | `6.0.0(20)`  |
| `targetSdkVersion`     | `6.1.1(24)`  |
| `compileSdkVersion`    | not declared: the build uses the SDK bundled with DevEco Studio 6.1.1.280, HarmonyOS 6.1.1 (API 24) |

The module files (`entry/`, `watch/`, `common/build-profile.json5`) declare no SDK versions.
The build was compiled with DevEco Studio 6.1.1.280 and its bundled SDK, HarmonyOS 6.1.1 (API 24).
The minimum is API 20, as the challenge asks. No API newer than 20 is used so far.

The FAQ example for a HarmonyOS product also writes `compileSdkVersion: "6.1.1(24)"`. Adding that line is an
owner decision; nothing was changed.

## History scan (B6)

Scanned every commit reachable from every branch (`git rev-list --all`), 79 distinct paths.

- File names: no `.p12`, `.cer`, `.p7b`, `.csr`, `.jks`, `.pem`, `.key`, `.pfx`, `.env`, `.hap`, `.zip`, no `local.properties`.
- Content: no password, key password, API key, token, private key block or client id. The only matches are the
  words "secret" and "token" in `AGENTS.md` and `AI_WORKFLOW.md` guidance text.
- Content: no e-mail address and no path containing a user name.
- Commit metadata: every commit has a private e-mail address as author and committer. It becomes public with the
  first push. Changing it means rewriting history, which is the owner's call.

`.gitignore` covers `*.p12`, `*.cer`, `*.p7b`, `*.csr`, and now also `*.jks`, `*.pem`, `*.pfx`, `*.keystore`, `*.hap`, `*.app`.

Signing trap: when automatic signing is switched on in DevEco Studio, it writes keystore paths (with the user
name) and encrypted passwords into the root `build-profile.json5`, which is a tracked file. Do not commit that
file after enabling signing; keep the signed build configuration local.

## AI features (B11)

The code has no AI feature: no network call, no model call, no `INTERNET` permission. The tier comes from
deterministic rules and curves.

Until 2026-10-04 two files described an AI feature that does not exist. By the owner's decision the lines
were removed, not the feature built:

- `HACKATHON_BRIEF.md`: the secondary theme "Intelligent Experiences (AI-written explanations of the
  result)", the row "AI summary", the acceptance check about model output, and "explanation service" in the
  scope list.
- `common/src/main/ets/model/types.ets`: `LedgerEntry.kind` no longer lists `'LLM'`.

`AI_WORKFLOW.md`, "AI feature disclosure", says "Not applicable". AI was used to develop the project, which
that document records; it is not part of the product.

## Permissions (B14)

| Module                                       | Permission                         | Why the user needs it                                     | Where it is used               |
| -------------------------------------------- | ---------------------------------- | --------------------------------------------------------- | ------------------------------ |
| `entry`                                      | none                               | signing with HUKS and CryptoFramework needs no permission | `entry/src/main/ets/platform/` |
| `watch` (on `main`)                          | none                               | template page only                                        |                                |
| `watch`                                      | `ohos.permission.READ_HEALTH_DATA` | live heart rate on the watch face, wear state            | `watch/src/main/ets/sensors/LiveSensors.ets` |
| `watch`                                      | `ohos.permission.ACTIVITY_MOTION`  | today's step count on the watch face, day summary         | `watch/src/main/ets/sensors/LiveSensors.ets` |

Not requested and not to be copied from sample code: `INTERNET`, `GET_NETWORK_INFO`, `VIBRATE`, `GYROSCOPE`.

## Input validation (B14)

| Input                         | Rule                                                                                                                                              | Evidence               |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------- |
| `want.parameters['fwTarget']` | only `dashboard`, `evidence`, `share`, `source`, `tour`; anything else, any non-string and any value over 32 characters opens the dashboard; never throws | `EntryTarget.test.ets` |
| Tier claim JSON               | strict decode: exactly seven keys, fixed value types; an extra key, a missing key or malformed JSON is rejected                                   | `Claim.test.ets`       |
