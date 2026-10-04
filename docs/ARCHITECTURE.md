# FairWear architecture notes

## Data flow

```
WATCH 5 → HUAWEI Health (phone) → [Health Service Kit + user authorization]
        → FairWear on the phone (HES-Lite + wear rules) → signed tier → QR → partner

FairWear watch app → live heart rate + wear state (not part of HES)
```

On the emulators HUAWEI Health is not available to the app, so its place is taken by **Health Sim**
(`healthsim/`, bundle `com.fairwear.healthsim`): our own simulator app with the same six people. It is not
HUAWEI Health and does not look like it; every screen says "SIMULATED DATA".

```
Phone:  FairWear ── startAbilityForResult(AuthAbility, fwScopes) ──▶ Health Sim: its own consent screen
        FairWear ◀── resultCode 0 + parameters['fwhs1'] (histories and wear months, JSON) ── "Allow"
        FairWear: its own consent (GDPR Art. 9) → strict decode → HES-Lite and wear rules → report
        Health Sim card "FairWear" ── startAbility ──▶ FairWear (opens it the way an add-on is opened)

Watch:  FairWear watch ── startAbilityForResult(WatchExportAbility) ──▶ Health Sim watch
        FairWear watch ◀── resultCode 0 + parameters['fwhsw1'] (the script of the demo day, JSON)
        FairWear watch: strict decode → the demo feed plays that script → recorder → signed day packet
```

- The platform capability used here is **Ability Kit**: one app starts an ability of another and gets a
  result back (`UIAbilityContext.startAbilityForResult`, `terminateSelfWithResult`). It is the same call
  a real integration with a host app would use; no permission is needed for it.
- What crosses: on the phone, completed days of the six people and their wear months, only the data types
  the user allowed in Health Sim (a type that was not allowed arrives as "no value"); on the watch, the
  script of one demo day. Nothing else is shared between the two apps: no shared files, no network.
- Both texts are decoded strictly (`common/src/main/ets/health/HealthSimPayload.ets`,
  `common/src/main/ets/watchlink/DemoFeed.ets`): a wrong version, an unknown person, a wrong row length, a
  value that is not a number or a text over the size limit gives nothing, never an exception.
- **Fallback.** When Health Sim is not installed, refuses or sends something that does not decode, FairWear
  works as before: the built-in demo histories with the source line "HUAWEI Health · Demo data" on the
  phone, and the built-in day script on the watch ("Health Sim not on this watch · built-in script").
- The report built from Health Sim data equals the built-in one for all six people
  (`common/src/test/HealthSimPayload.test.ets`); the source line then reads "Health Sim · Simulated data".
- Health Sim carries unchanged copies of the shared logic it needs (`healthsim/*/src/main/ets/fw/`); a Node
  test keeps them identical to `common` (`common/src/test/HealthSimCopies.test.ets`).

FairWear is an add-on for HUAWEI Health users: with their permission it reads what HUAWEI Health already
measures, scores it on the phone, and shares only a signed tier.

## Modules

| Module   | Device                    | What is in it                                                                                                                                                                                                                                                               |
| -------- | ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `common` | none (HAR, no UI imports) | Model types, tier claim codec and verifier (`claim/`), the score (`hes/`), wear month and selective non-wear rule (`wear/`, `rules/`), the report view models (`report/`), Watch Link logic (`watchlink/`), the health source layer (`health/`), live wear state (`live/`). |
| `entry`  | phone                     | The add-on flow (welcome, two-step consent, Settings), the tabs Report / Evidence / Share, Why this tier, the partner view (demo), "What left this phone", the Watch link cards and tour, the home-screen card and shortcuts, the HUAWEI Health adapter stub. |
| `watch`  | wearable                  | Live heart rate, steps today and wear state; the Watch Link recorder (288 slots a day), day signing with the watch key, the slot-ring dial, the demo clock and demo feed, the Wear Engine send path (not run). |

## Health source layer (`common/src/main/ets/health/`)

- `HealthRecords.ets`: records in the native units HUAWEI Health reports, and `HealthStatus`
  (`CONNECTED`, `NOT_AUTHORIZED`, `UNAVAILABLE`, `DEMO`). A missing value is `-1`, never zero.
- `HealthSource.ets`: the `HealthSource` interface (synchronous reads over records already in memory) and
  `EmptyHealthSource`, a source with no records.
- `HealthConnection.ets`: wraps a `HealthSource` and puts the user's consent in front of it. Two steps are
  required: the platform's authorization and FairWear's own consent (GDPR art. 9) with a switch per data type.
  Not connected: every method returns an empty list. A data type switched off: an empty list, or `-1` in the
  fields of a daily record.
- `entry/src/main/ets/platform/HuaweiHealthSource.ets`: the adapter for Health Service Kit. In this build it
  is a stub (`UNAVAILABLE`, empty lists) and calls nothing.

## What is real and what is simulated

| Part                                                                  | State                                                                                                                                                                                                                                                                                                                                                                                                                |
| --------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| HUAWEI Health connection                                              | Stub for the real kit: access to sensitive data through Health Service Kit needs Huawei's approval for the app; it was not granted during the hackathon. On the emulators Health Sim, our own simulator app, stands in for HUAWEI Health and hands FairWear the data after its own consent (Data flow above); without it, built-in demo data.                                                                                                                                                                                                                                                                              |
| HUAWEI Health authorization screen                                    | Not shown. A DEMO placeholder stands in its place; FairWear does not copy Huawei's screen.                                                                                                                                                                                                                                                                                                                           |
| Consent logic, status transitions, per-data-type switches             | Real, covered by tests (`common/src/test/Health.test.ets`).                                                                                                                                                                                                                                                                                                                                                          |
| Demo history in HUAWEI Health record format (`SyntheticHealthSource`) | Not built. The demo personas are generated as completed days for the score (`hes/HesPersonas.ets`) and do not pass through the health source layer, whose demo source is empty.                                                                                                                                                                                                                                      |
| Scoring (HES-Lite), tier, coverage                                    | Real engine, calculated on the phone (`common/src/main/ets/hes/`, `docs/HES.md`), on the synthetic histories of six demo personas. It does not read HUAWEI Health and is not fed by the watch.                                                                                                                                                                                                                       |
| Wear compliance, breaks, the selective non-wear flag                  | Real rules (`common/src/main/ets/wear/`, `rules/SelectiveNonWear.ets`) on a synthetic 30-day wear record per persona.                                                                                                                                                                                                                                                                                                |
| Live heart rate and today's steps on the phone                        | Demo values set on the Report screen. Shown, never scored; today's steps enter the history when the day is closed.                                                                                                                                                                                                                                                                                                   |
| VO₂max and HRV                                                        | Watch measurements HES-Lite uses when present, as percentiles; synthetic in the personas. A missing one lowers coverage, never the score.                                                                                                                                                                                                                                                                            |
| Watch demo feed                                                       | Simulated. A fixed script of heart rate, steps and charging (night on the charger, worn hours, one break, a walk, a workout) replaces the sensor readings. It runs only on the demo clock, the dial reads "DEMO ×300 · FEED", and the signed day packet carries the clock label `DEMO_X300_FEED`. It goes through the same wear rule and recorder as sensor readings (`common/src/main/ets/watchlink/DemoFeed.ets`). |

## Permissions

| Module  | Permission                         | Reason shown to the user                                                                          |
| ------- | ---------------------------------- | ------------------------------------------------------------------------------------------------- |
| `entry` | none                               | The add-on screens need no permission in this build; the HUAWEI Health adapter is a stub.         |
| `watch` | `ohos.permission.READ_HEALTH_DATA` | "FairWear shows your live heart rate on the watch and uses it to tell whether the watch is worn." |
| `watch` | `ohos.permission.ACTIVITY_MOTION`  | "FairWear shows the steps counted today on the watch and adds them to the day summary it records." |

## One entry point

FairWear on the phone has one way in: the ability `EntryAbility` of module `entry` (bundle
`com.fairwear.app`), which loads the single start page `pages/Index`. That page hosts one `Navigation`; the
consent steps and settings are destinations inside it, not separate pages or abilities.

Because there is one exported ability, a host app can open FairWear the way the HMOS Code Workshop sample
opens its modules: `startAbility` with a `Want` that names the bundle and the ability
(`bundleName: 'com.fairwear.app'`, `moduleName: 'entry'`, `abilityName: 'EntryAbility'`).

This is the route by which FairWear could be opened from HUAWEI Health. Doing that needs an agreement with
Huawei; nothing in this repository does it, and FairWear is a separate app.

Checked: the ability starts from the command line with
`aa start -b com.fairwear.app -m entry -a EntryAbility` (this is what `tools/deploy.sh entry` runs).
Not checked: `startAbility` from another app.

### One parameter chooses the screen: `fwTarget`

Everything that opens FairWear uses that same ability and one optional parameter, `fwTarget`:

| Who opens FairWear             | How                                                | Opens                              |
| ------------------------------ | -------------------------------------------------- | ---------------------------------- |
| Home-screen card (2x2)         | tap, `postCardAction` with `fwTarget: 'dashboard'` | start page                         |
| Icon shortcut "Data source"    | `shortcuts_config.json`, `fwTarget: 'source'`      | Settings with the data-source card |
| Icon shortcut "How Watch Link works" | `shortcuts_config.json`, `fwTarget: 'tour'`  | the Watch Link tour                |
| A host app or the command line | `Want` parameter `fwTarget`                        | the named screen                   |

`EntryAbility` passes the want to `routeFromWant` (`entry/src/main/ets/nav/EntryRouter.ets`) in `onCreate`
and `onNewWant`; the start page opens the screen. The value is untrusted input. `resolveFwTargetFromWant`
(`common/src/main/ets/nav/EntryTarget.ets`) accepts `dashboard`, `evidence`, `share`, `source` and `tour`; a missing value, an
unknown value, a non-string, an oversized string or malformed card parameters open the start page and never
throw (12 tests in `common/src/test/EntryTarget.test.ets`). After consent the start page is three tabs:
`dashboard` selects Report, `evidence` Evidence and `share` Share (`fwTargetTab`); `source` opens Settings
above the Report tab. There is no shortcut for the Share tab yet.

The Share tab signs the claim when it is on screen, never before: `ShareService`
(`entry/src/main/ets/share/ShareService.ets`) asks the demo partner (`PartnerVerifier`, in the same app) for
a nonce, signs the seven-key claim with `ProofSigner` and writes the exact token to the ledger
(`share/ledger.json` in the app sandbox) before the QR code is drawn. A report without a score gets no code
and no ledger entry. The partner view takes the token inside the app (the emulator has no camera) and shows
the verifier's own result: the status, the check the run stopped at, the claim only when its signature
verified. "Use the code from this phone" replaces a code that was already checked or whose nonce is about to
expire, so a rehearsal never leaves the partner holding a dead code. "What left this phone" (route `ledger`,
linked from the Share tab) lists the ledger newest first with each token's exact text and size. What each
screen shows is decided in `common/src/main/ets/claim/ShareFlow.ets` (9 tests in
`common/src/test/ShareFlow.test.ets`).

Checked on the Phone emulator (API 24): cold start and a second start of the running app with
`--ps fwTarget source`, with an unknown value and with no parameter; the shortcut; the card tap.

## Home-screen card

`EntryFormAbility` (Form Kit, `exported: false`) provides one 2x2 card. The card shows the data source,
the coverage and whether a score is ready. It never shows the tier or the score, because other people see
the home screen, and there is no lock-screen card for the same reason. `common/src/main/ets/card/CardDigest.ets`
defines what the card may show (7 tests). The app stores that digest in Preferences and pushes it to the
placed cards with `formProvider.updateForm` (`entry/src/main/ets/platform/CardStore.ets`) whenever the
session changes.

Checked on the Phone emulator: the card is offered under the icon's "Widgets" menu, can be added to the
home screen, and changes from "HUAWEI Health · Not connected" to "HUAWEI Health · Demo data" after consent
(`docs/screenshots/ta1-home-card-phone.jpeg`, `ta1-home-card-after-consent-phone.jpeg`, taken before the
scoring engine was in the build). Coverage and "Score ready" now come from the report of the selected persona
(`Report.test.ets`, `CardDigest.test.ets`); the card with the engine digest was not photographed.
The card and Preferences need no permission.

## Watch Link

```
WATCH (wearable .hap)                                         PHONE (entry .hap)
LiveSensors (HR, steps, wear, charging)                       Receivers
  → WearStateMachine (real-time freshness)                      ├─ WearEngineReceiver (paired devices only)
  → SlotRecorder (288 × 5-min slots/day, files)                 └─ inbox/ scan (emulator relay)
  → DayBuilder (measurements, no verdicts)                    → DayPacketVerifier (format → key → sig → chain → date)
  → DayPacket signed with the WATCH key, hash-chained         → ChainLedger (seq/prev, gaps, duplicates)
  → outbox/ ─┬─ WearEngineTransport (paired devices only)     → WatchDayFacts → shown, not scored (by decision)
             └─ files for the dev relay (emulator)            → Watch link card, Days from the watch
                         tools/watch-phone-relay.mjs (hdc) ────┘   ACK → back to the watch → the watch deletes the packet
```

- `common/src/main/ets/watchlink/`: the data contract and all logic of both sides (`WatchLinkEngine`,
  `PhoneLinkEngine`), with the platform passed in through `WatchLinkPorts`. No system-kit imports; tested
  under Node (`WatchLink.test.ets`, `WatchLinkFlow.test.ets`).
- `common/src/main/ets/platform/`: device implementations of the ports (`FileTextStore`, `KeySigner`,
  `DeviceSigVerifier`, `DeviceHasher`) and the signing helpers moved from `entry` (`ProofSigner`,
  `CryptoUtil`, `Bytes`). The claim key of the phone is unchanged; the watch has its own key alias.
- `watch/src/main/ets/watchlink/`: `WatchLinkRuntime` (key, files, sensor feed), `SlotRing` (the dial ring),
  `WearEngineTransport` (send path only: the receiver for ACKs is not started and the outbox is not resent;
  on emulators the relay carries both directions).
- `entry/src/main/ets/watchlink/`: `WatchLinkService`, `WearEngineReceiver`; `view/WatchLinkCard.ets`.
- What leaves the watch: one signed summary per day, under 3800 bytes; no per-sample heart rate.
  What leaves the phone: unchanged, only the signed tier claim.

Packet format, signing string, verify order, limitations and deviations: `docs/WATCH_LINK.md`.

## UI texts and string resources

Every text the user sees or hears in the UI layer of the phone, the watch and the home-screen card is a
string resource. `base` is English; no other language folder exists yet (a `zh_CN` folder waits for the team's
decision and for a reviewer who knows the language).

- Phone: `entry/src/main/resources/base/element/string.json` (keys `screen_element`, for example
  `report_view_coverage_chip`, `partner_tamper_label`), the card's texts in `card_string.json`.
  Watch: `watch/src/main/resources/base/element/string.json` (`watch_*`).
- A text without a value goes to the component as the resource: `Text($r('app.string.settings_title'))`.
- A text with a value is one pattern in the resource (`Coverage %d%%`, `%s · last sync %s`) and is read with
  `str($r('app.string.…'), value)` from `entry/src/main/ets/ui/Strings.ets` (the watch has the same file).
  `str` uses the ability's resource manager, `getStringSync(resId, ...args)`. Three facts measured on the
  emulator decide the rule: `Text($r('…', value))` leaves `%%` as two signs, `%s` fails on a number, and `%d`
  cuts a fraction. So a value never goes into `$r`, `%d` is for whole numbers only, and anything else is
  passed as text to `%s`.
- `AddonTexts.ets`, `ReportTexts.ets` and `ShareTexts.ets` keep their names: a constant is the resource, a
  function returns the text. `str` must not run at module load, so no constant holds a resolved text.
- `tools/check-ui-literals.sh` fails when a literal is handed to `Text`, `Button`, `accessibilityText`,
  `accessibilityDescription` or a toast message in the UI folders.

### Phase 2: texts built in `common`

`common` is pure logic that also runs under Node in the tests, where `$r` does not exist. Its sentences are
still English literals and reach the screen as arguments of the patterns above. They were not changed in
this step. Phase 2 turns each of them into a message identifier plus arguments, resolved in the UI layer:
the function returns `{ id, args }`, the screen maps the id to a resource and formats it with `str`; the
tests then compare ids and arguments instead of English sentences.

| File in `common/src/main/ets/` | What it writes |
| --- | --- |
| `report/EngineReports.ets` | Day reasons of the wear month ("Off the wrist 13:05 for 5 h 35 min after …"), the what-if sentence of "Why this tier", `HEALTH_SIM_LABEL`, period lines |
| `report/WhySections.ets` | `weightText` ("17%") |
| `report/EvidenceCalendar.ets` | `minutesText`, `clockText`, `flagRuleText` |
| `report/Benefit.ets` | Benefit labels and reasons ("Full benefit · Eligible", …) |
| `report/ReportSpeech.ets`, `report/ReportDates.ets` | Day state labels, units in words for screen readers ("beats per minute"), "Day 17, …", period texts |
| `health/HealthStatusLabel.ets` | "Not connected", "Demo data", "Unavailable in this build", "Connected", the source line |
| `hes/HesTier.ets`, `hes/HesCurves.ets`, `hes/HesTypes.ets` | Tier headlines ("Strong overall profile"), component names ("Resting heart rate"), "Insufficient data" |
| `claim/ShareFlow.ets`, `claim/PartnerVerifier.ets` | Claim lines ("Tier B", "Eligible: no · …"), check names, verdicts ("Signature valid", "Invalid signature", "Already used"), key source labels |
| `watchlink/LinkProbe.ets`, `DayPacketVerifier.ets`, `DayPacketCodec.ets`, `PhoneLinkEngine.ets`, `WatchLinkEngine.ets`, `DemoFeed.ets` | Verifier and codec messages ("Invalid signature", "Accepted", "Duplicate day", "Missing 1 day(s)", the format reasons of a refused packet), sync status lines of the watch and the phone, probe titles, feed clock labels |
| `present/WatchDayPresent.ets` | Wear labels, `durationText`, `dayTitle`, `breakText`, sync and log lines, `transportLabel` |
| `present/TourContent.ets` | The six steps of "How Watch Link works" (titles, sentences, test names), probe lines; the code panels stay code |
| `card/CardDigest.ets` | The three lines of the home-screen card |
| `platform/ProofSigner.ets` | Key notes ("Key held in HUKS", the software-key note) |

Outside `common`, and outside the folders this step covered, a few texts written in `entry` and `watch`
services also reach the screen and belong to the same phase: the four Health Sim notes in
`entry/src/main/ets/platform/HealthSimClient.ets`, and the Wear Engine status texts in
`entry/src/main/ets/watchlink/WearEngineReceiver.ets` and `watch/src/main/ets/watchlink/WearEngineTransport.ets`.
Number formatting (`grouped`, thousands with a comma) and the list separators are not locale-aware yet.
