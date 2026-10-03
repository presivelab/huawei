# FairWear

FairWear is an add-on for HUAWEI Health users: with their permission it reads what HUAWEI Health already
measures, scores it on the phone, and shares only a signed tier.

HackYeah 2026, Huawei task. Native ArkTS/ArkUI, minimum API 20. Modules: `entry` (phone), `watch`
(wearable), `common` (shared logic, no UI).

## FairWear as a component

**What it does.** FairWear takes the health history a person already has, turns it into an A/B/C tier on
the phone, and hands a partner only that tier, signed. Raw health data stays on the phone.

**How it integrates with the platform.** FairWear reads from HUAWEI Health through Health Service Kit,
after the user authorizes it in HUAWEI Health and gives FairWear a separate consent to process health data.
Today this is DEMO: access to health data through Health Service Kit has to be granted to the app by
Huawei, and FairWear does not have it. The adapter is a stub, the authorization step is a neutral
placeholder, and the status on every screen says `DEMO`, `NOT_AUTHORIZED` or `UNAVAILABLE`. The connection
can be ended in FairWear ("Disconnect HUAWEI Health") or in HUAWEI Health privacy settings.

**How to install.** Two HAPs, one per device, built from this repository with DevEco Studio's bundled
toolchain (Git Bash on Windows):

```
source tools/env.sh && ohpm.bat install --all    # once after cloning: links the local common module
tools/deploy.sh entry    # builds entry, installs it on the running phone emulator and starts it
tools/deploy.sh watch    # the same for the wearable emulator
```

The HAPs are written to `entry/build/default/outputs/default/entry-default-unsigned.hap` and
`watch/build/default/outputs/default/watch-default-unsigned.hap`; they can also be installed by hand with
`hdc -t <target> install -r <hap>`. They are unsigned debug builds, which the emulators accept.

**How to check it.** Follow `docs/DEMO_SCRIPT.md`: connect, both consent steps, result, disconnect, consent
again, result. That is the path Huawei asks to see when it verifies an integration, here with DEMO data.

**Watch: live heart rate and wear state (emulator).** The watch module subscribes to the heart-rate and step-counter sensors and shows three live values: heart rate, steps today and wear state. These values stay on the watch and are not part of the score. The wearable emulator has a heart-rate sensor and a step counter but no wear-detection sensor, so the wear state is derived from heart rate: any reading ≤ 0 counts as no reading, and the watch counts as removed after 10 s without a valid reading.

What we observed on the emulator with nothing set in the Virtual sensor panel: heart-rate events arrive about 6 times a second with the value 0 (not silence) and the step counter stays at 1000. The screen shows "—" for heart rate, 0 steps today and the wear state "no data". No real heart rate was read on the emulator.

**Manual check, not yet done:** in the emulator window open the menu → Virtual sensor and set heart rate to 70, then 0, then 70 again. Expected: 70 shows "70 bpm" and "worn"; after 0 the heart rate changes to "—" at once and the wear state changes to "removed" 10 s later; 70 brings back "70 bpm" and "worn". This sequence is covered by the Node test (`tools/run-logic-tests.sh common common/src/test/LiveWear.test.ets live`), but it has not been run in the emulator panel. Write the observed result here after running it.

**Phone: home-screen card and icon shortcut (emulator).** The DevEco phone emulator shows service widgets. Long-press the FairWear icon → Widgets → Add to home screen: the 2x2 card shows the data source, the coverage and whether a score is ready, never the tier. Long-press the icon again: the shortcut "Data source" opens Settings with the data-source card. Both open the app through the same parameter, `fwTarget` (`docs/ARCHITECTURE.md`, "One entry point"). Screenshots: `docs/screenshots/ta1-home-card-phone.jpeg`, `ta1-home-card-after-consent-phone.jpeg`, `ta2-icon-shortcut-phone.jpeg`.

## State of this branch

- Health source layer, consent logic and the phone add-on screens are in place (`docs/ARCHITECTURE.md`).
- The scoring module (HES-Lite) and the demo data set are not in this branch yet. The tier, score, coverage
  and last sync are shown as "—"; no number on the screens is invented.
- What is real and what is simulated: the table in `docs/ARCHITECTURE.md`.

## Tests

```
tools/run-logic-tests.sh common                                          # all pure-logic tests, under Node
tools/run-logic-tests.sh common common/src/test/Health.test.ets health   # one test file
tools/check-wording.sh                                                   # text check over sources and docs
```

Results are recorded in `docs/test-results.txt`. The Node run compiles the `.ets` files as strict TypeScript
with the compiler bundled in DevEco Studio; it does not replace the ArkTS compiler or a run on a device.

## Security & privacy

- **Dependencies.** `entry` and `watch` depend only on the local `common` module. The two external packages,
  `@ohos/hypium` 1.0.24 and `@ohos/hamock` 1.0.0, are OpenHarmony's test libraries, declared as
  devDependencies for the test sources. The `oh-package-lock.json5` files are committed, so an install
  resolves the same versions by hash.
- **Signing.** The committed `build-profile.json5` has an empty `signingConfigs` list. For a signed HAP let
  DevEco Studio fill it locally (File → Project Structure → Signing Configs → Automatically generate
  signature) and do not commit the changed file.
- **Commit hook.** `tools/hooks/pre-commit` blocks a commit that stages signing material, a local Wear Engine
  config or a password line. Install it once per clone: `cp tools/hooks/pre-commit .git/hooks/pre-commit`.

## Watch Link: signed day packets from the watch

The watch app records the day in 288 five-minute slots (worn, charging, off-wrist, not observed), signs one
summary per day with its own key and chains the summaries by hash. The phone checks the signature and the
chain before it takes a day in, so a day cannot be removed or edited on the way without it showing. The
watch measures; every verdict stays in the rule code on the phone. Specification, demo script and what was
checked: `docs/WATCH_LINK.md`.

```
tools/deploy.sh watch && tools/deploy.sh entry   # debug builds on both emulators
node tools/watch-phone-relay.mjs                 # carries pair.json, day packets and ACKs over hdc
node tools/watch-phone-relay.mjs once --tamper   # demo: the phone answers "Invalid signature"
node tools/watch-phone-relay.mjs once --drop 3   # demo: the phone shows "1 day missing"
```

| Part                      | Real or simulated                                                                                                                                                                                                  |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Watch recorder            | **Real** sensor code (heart rate, steps, wear sensor when present; heart-rate signal on the emulator). Records **while the app is open**.                                                                          |
| Day packets               | **Real** ECDSA P-256 signing on the watch (HUKS on the wearable emulator, software fallback otherwise) and a hash chain.                                                                                           |
| Watch → phone transport   | **Real** Wear Engine code path, **not demonstrable** on emulators (needs paired devices and Wear Engine approval) and not run. The demo uses `tools/watch-phone-relay.mjs` over hdc, carrying the identical files. |
| Demo clock ×300           | **Simulated time**, labelled on the watch and in every packet recorded with it.                                                                                                                                    |
| 24 h background recording | **Not implemented.** No continuous-task type fits health logging. In the product the full-day history comes from HUAWEI Health; the watch app adds signed wear evidence while it runs.                             |
| Watch days in the score   | **Not connected in this branch**: the scoring module is not in this checkout. The phone shows the received days and their source.                                                                                  |
