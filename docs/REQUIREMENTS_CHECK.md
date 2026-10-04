# Hackathon requirements: working check

Working notes behind the README table "Hackathon requirements → where to verify".
Source of the requirements: `hackathon_challenge.md` and `FAQ.md` in `onirodeveloper/hackyeah2026-challenge`.
Every row names its evidence. A row without evidence is marked open.

Checked on 2026-10-04. The table below was written on `feature/entry-routing` (base `main`). On
`feature/home-card`, which contains `feature/health-addon`, these rows change: B2 is met for the add-on
screens, the watch live screen, the home-screen card and the shortcut (`docs/screenshots/`); B13 "unknown
`fwTarget`" is also checked on the Phone emulator; B14 lint is 0 errors and 5 warnings of one performance
rule (`docs/test-results.txt`); B4, B5, B8 and B9 have a first version in `README.md`, `docs/ARCHITECTURE.md`
and `docs/DEMO_SCRIPT.md`. The watch permissions are in `docs/ARCHITECTURE.md`.

State on 2026-10-04 04:12, branch `feature/engine-reports` at the G2 merge (`1ec3f81`), from
`docs/test-results.txt`: logic tests `common` 362/362 and `watch` 6/6; `assembleHap` for `entry` and `watch`
BUILD SUCCESSFUL; lint 0 errors (7 warnings in `entry`, 2 in `watch`, all one performance rule, 0 issues in
`common`); wording check 0 hits. B2 is met for the product screens: Report, "Why this tier", Evidence, Share
and the partner view ran on the Phone emulator and the watch recorder on the Wearable emulator (screenshots
in `docs/screenshots/final/` and `docs/screenshots/`). The table below still shows the first check and is
kept as the record of it.

## Status

| Point | Requirement                                 | Status                          | Evidence                                                                                                               |
| ----- | ------------------------------------------- | ------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| B1    | API 20 or later, API 20 declared as minimum | met                             | `build-profile.json5`, see "API levels" below                                                                          |
| B2    | Runs on an emulator, not only the Previewer | partly                          | empty `entry` and `watch` ran on the Phone and Wearable emulators: `docs/screenshots/k0-*.jpeg`. Product screens: open |
| B6    | Public-safe repository                      | open, owner decision            | no signing material, no secrets in any branch; commit metadata carries a private e-mail address, see "History scan"    |
| B11   | AI features in the product                  | none, in code and in documents  | see "AI features"                                                                                                      |
| B13   | Unknown `fwTarget` handled                  | met for the logic               | `common/src/main/ets/nav/EntryTarget.ets`, 5 tests in `common/src/test/EntryTarget.test.ets`                           |
| B13   | Software key instead of HUKS                | code path exists, not exercised | `entry/src/main/ets/platform/ProofSigner.ets`; on the Phone emulator HUKS succeeded, so the fallback never ran         |
| B14   | Permissions justified, none unused          | met today                       | see "Permissions"                                                                                                      |
| B14   | No secrets, no risky dependencies           | met                             | "History scan"; dependencies are `@ohos/hypium` and `@ohos/hamock`, dev only                                           |
| B14   | Lint                                        | met                             | `docs/test-results.txt`, DevEco CLI 1.3.4: 0 issues in `entry`, `watch`, `common`                                      |
| B18   | History shows progress                      | met so far                      | `git log`: no squash, one commit per step                                                                              |

Not started on this branch: B3, B4, B5, B7, B8, B9, B10, B12, B15, B16, B17.

## API levels (B1)

Root `build-profile.json5`, product `default`:

| Setting                | Value        |
| ---------------------- | ------------ |
| `runtimeOS`            | `HarmonyOS`  |
| `compatibleSdkVersion` | `6.0.0(20)`  |
| `targetSdkVersion`     | `6.1.1(24)`  |
| `compileSdkVersion`    | not declared |

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
| `watch` (on `feature/health-addon`, planned) | `ohos.permission.READ_HEALTH_DATA` | live heart rate on the watch face                         | to be filled in after merge    |
| `watch` (on `feature/health-addon`, planned) | `ohos.permission.ACTIVITY_MOTION`  | today's step count on the watch face                      | to be filled in after merge    |

Not requested and not to be copied from sample code: `INTERNET`, `GET_NETWORK_INFO`, `VIBRATE`, `GYROSCOPE`.

## Input validation (B14)

| Input                         | Rule                                                                                                                                              | Evidence               |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------- |
| `want.parameters['fwTarget']` | only `dashboard`, `evidence`, `share`, `source`; anything else, any non-string and any value over 32 characters opens the dashboard; never throws | `EntryTarget.test.ets` |
| Tier claim JSON               | strict decode: exactly seven keys, fixed value types; an extra key, a missing key or malformed JSON is rejected                                   | `Claim.test.ets`       |
