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

**Watch: live heart rate and wear state (emulator).** The watch module subscribes to the heart-rate and step-counter sensors and shows three live values: heart rate, steps today and wear state. These values stay on the watch and are not part of the score. The wearable emulator has a heart-rate sensor and a step counter but no wear-detection sensor, so the wear state is derived from heart rate. There is one wear rule on the watch, `WearStateMachine` in `common`, used by the screen and by the Watch Link recorder: charging (from `batteryInfo.pluggedType`) comes first, then the wear-detection sensor when the watch has one, then heart rate. Any reading of 0 or outside 25–230 bpm counts as no reading, and the watch counts as not on wrist after more than 60 s without a valid reading. Only the demo clock shortens that limit (to 3 s), and the dial then shows a `DEMO ×300` label.

What we observed on the emulator with nothing set in the Virtual sensor panel: heart-rate events arrive about 6 times a second with the value 0 (not silence) and the step counter stays at 1000. The screen shows "—" for heart rate, 0 steps today and the wear state "not on wrist" (`docs/screenshots/i3-watch-wear-state.jpeg`). No real heart rate was read on the emulator, and the charging state was not reached there.

**Manual check, not yet done:** in the emulator window open the menu → Virtual sensor and set heart rate to 70, then 0, then 70 again. Expected: 70 shows "70 bpm" and "worn"; after 0 the heart rate changes to "—" at once and the wear state changes to "not on wrist" a little more than 60 s later; 70 brings back "70 bpm" and "worn". This sequence is covered by the Node test (`tools/run-logic-tests.sh common common/src/test/LiveWear.test.ets live`), but it has not been run in the emulator panel. Write the observed result here after running it.

**Phone: home-screen card and icon shortcut (emulator).** The DevEco phone emulator shows service widgets. Long-press the FairWear icon → Widgets → Add to home screen: the 2x2 card shows the data source, the coverage and whether a score is ready, never the tier. Long-press the icon again: the shortcut "Data source" opens Settings with the data-source card. Both open the app through the same parameter, `fwTarget` (`docs/ARCHITECTURE.md`, "One entry point"). Screenshots: `docs/screenshots/ta1-home-card-phone.jpeg`, `ta1-home-card-after-consent-phone.jpeg`, `ta2-icon-shortcut-phone.jpeg`.

**Watch: demo feed (simulated).** The wearable emulator sends heart rate 0, so a recorded day would be empty. On the watch, page "Watch link": switch on "Demo clock ×300", then "Demo feed". A fixed script of heart rate, steps and charging then replaces the sensor readings: night on the charger, worn hours, one break from 12:30 to 14:00, a walk and a workout. The dial reads "DEMO ×300 · FEED" and every value is labelled "demo feed"; the signed day packet carries the clock label `DEMO_X300_FEED`. The script goes through the same wear rule and recorder as real sensor readings. The real sensors still work when the feed is off: set the heart rate in the emulator's Virtual sensor panel. Screenshots: `docs/screenshots/design/after-watch-dial-feed-later.jpeg`, `before-watch-dial.jpeg`.

## State of this branch

- Health source layer, consent logic and the phone add-on screens are in place (`docs/ARCHITECTURE.md`).
- The score is calculated on the phone by HES-Lite v1.0 (`common/src/main/ets/hes/`): deterministic rules and
  curves, no learned model and no network. It runs on the histories of six demo personas, which are synthetic
  and generated from a seed; the source pill on the Report tab reads "HUAWEI Health · Demo data". All weights,
  curves, thresholds and minimum counts are prototype product assumptions, not clinically tested. Description,
  persona results and decisions: `docs/HES.md`.
- Wear rules run next to the score (`common/src/main/ets/wear/`): compliant days, nights, breaks, and the
  selective non-wear flag. One suspicious break never raises the flag, three always do, two only when they
  are more than 30% of all breaks.
- After consent the phone shows three tabs: Report, Evidence and Share. Benefit level: eligible and tier A is
  a full benefit, eligible and tier B a partial benefit, anything else no benefit this month, always shown
  with its reason.
- Report: the month of the selected demo persona, and "Why this tier": the components behind the tier as
  Strongest, To improve and Missing data (a missing component is never listed as weak), the one change that
  reaches the next tier, and how the score is calculated. A persona without a score gets "Measured so far"
  and "Needed for a score" with day and night counts instead.
- Demo controls on the Report tab: the Live card shows heart rate and steps labelled "Demo values"; two
  sliders set them and the score does not move. "Close the day" turns the running day into a completed day
  and the score is calculated again; "Reset demo" returns the persona to its starting history.
- Evidence: the wear month as a calendar (compliant, short, suspicious break, no data), with the month's
  figures and the flag rule above it. A tap on a day opens what the watch recorded and the reason the day
  counts as it does. A short or suspicious day can be appealed: "Appeal this day" becomes "Appeal sent". The
  appeal is kept on the phone until the app restarts, is sent nowhere and changes neither the day nor the
  score. The tab also holds the days received from the watch and "How Watch Link works", a six-step tour of
  the newest day the watch sent, with three checks (a changed day, a repeated day, a held-back day) run on a
  copy of the chain.
- Share: the signed tier claim (seven keys) as a QR code, and a demo partner view that verifies it, refuses
  the same code a second time and refuses a code whose tier was changed. The single-use nonce comes from the
  partner verifier, which in the demo runs inside the same app. Each code shown is written to a ledger in
  the app sandbox with its exact text. A persona without a score gets no code.
- Not built: the screen "What left this phone" that lists the ledger (the route shows a placeholder), export
  and deletion of the data, a camera scan of the QR code (the partner view takes the code from the same
  phone).
- The screens get their data in one place, `entry/src/main/ets/report/ServiceLocator.ets`, from the engine
  (`EngineReportService`): the report of a persona, the details of each day of the wear month with the reason
  as text, the live readings, "Close the day" and reset.

## What is real and what is simulated

| Part                              | State                                                                                                                                                                                                        |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Score (HES-Lite), tier, coverage  | **Real** engine, calculated on the phone. The history it runs on is **synthetic**: six demo personas generated from a seed.                                                                                  |
| Wear compliance and the flag      | **Real** rules, on a **synthetic** 30-day wear record per persona.                                                                                                                                           |
| Live heart rate and today's steps | Shown, **never scored**. The score uses completed days only; today's steps enter the history when the day is closed, the live heart rate is never stored.                                                    |
| VO₂max and HRV                    | Watch measurements that HES-Lite uses when they are present, as percentiles. In the personas they are **synthetic**. A missing one lowers coverage and never the score.                                      |
| HUAWEI Health connection          | **Stub** until Huawei grants the app access to health data through Health Service Kit. The authorization step is a labelled demo placeholder; FairWear does not copy Huawei's screen.                        |
| Watch to phone                    | Signed day packets carried by a development relay over `hdc` (`tools/watch-phone-relay.mjs`). The Wear Engine code path exists and was not run: it needs paired devices and Wear Engine approval.            |
| Watch days                        | **Real** recording and signing on the watch while the app is open; on the emulator the readings come from the Virtual sensor panel or the labelled demo feed. Verified watch days are shown, **not scored**. |
| Claim signature                   | **Real** ECDSA P-256; the key is in HUKS, or a software key when HUKS is not available, labelled in the UI.                                                                                                  |
| Partner                           | A screen in the same app, not a separate system.                                                                                                                                                             |

More detail per part: `docs/ARCHITECTURE.md`, `docs/HES.md`, `docs/WATCH_LINK.md`.

## Tests

```
tools/run-logic-tests.sh common                                          # all pure-logic tests, under Node
tools/run-logic-tests.sh common common/src/test/Health.test.ets health   # one test file
tools/check-wording.sh                                                   # text check over sources and docs
```

Results are recorded in `docs/test-results.txt`. The Node run compiles the `.ets` files as strict TypeScript
with the compiler bundled in DevEco Studio; it does not replace the ArkTS compiler or a run on a device.

## Security & privacy

- **Phone.** The phone app declares no permissions and has no network code: health history and the score
  never leave the phone. The only output meant for a partner is the signed tier claim. The Watch Link code
  also answers the paired watch with ACK packets (sequence number, status, reason; no health values).
- **Watch.** Two permissions, `READ_HEALTH_DATA` (heart rate) and `ACTIVITY_MOTION` (steps), each with a
  stated reason and used only while the app is open. A refused permission shows "—" and "unavailable"
  (`docs/screenshots/watch-04-heart-rate-permission-denied.jpeg`), never a made-up value. The sensors are
  switched off when the page is hidden.
- **Entry points.** Only the two start abilities are exported; the home-screen card ability is not.
- **Logs.** `%{public}` log fields carry screen names, error texts, counters, key ids and sandbox paths. No
  heart rate, step count or other health value is logged. Check: `git grep -n "%{public}" -- common entry watch`.
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
| Watch days in the score   | **Shown, not scored.** The score runs on the persona histories; the phone shows the received days and their source next to it.                                                                                     |
