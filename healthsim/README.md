# Health Sim

A small HarmonyOS app (ArkTS/ArkUI, stage model, bundle `com.fairwear.healthsim`) that stands in for HUAWEI Health on the DevEco emulators, so FairWear can be shown end to end without Health Service Kit approval.

**It is a simulator.** Every screen carries the banner "SIMULATED DATA · stands in for HUAWEI Health". It is not HUAWEI Health and not a HUAWEI app, it never reads real health data, and it uses no HUAWEI logo, name, brand colours or icons. The arrangement of its screens stays close to HUAWEI Health's (bottom tabs, an activity card with rings, one card per metric), so it is clear at a glance what it stands in for.

## One source of truth

Health Sim carries **no** copy of FairWear's sources and **no** score number of its own. Both modules depend on the built package `libs/common.har` (`"common": "file:../libs/common.har"`), produced from FairWear's `common/` module by `tools/sync-common-har.sh`. The six scripted people, the readiness model, the formatting helpers and the export contract all come from there (`import { ... } from 'common'`). `tools/check-single-engine.sh` (repository root) fails if a weight, a curve point or a copied source turns up in `healthsim/`.

## What the phone module does

- Shows the **same six scripted people** FairWear scores (Ania, Marek, Kasia, Tomek, Ewa, Ola), deterministic, no random numbers. A reading a person does not have is an absent field in the data and "—" on screen, never zero.
- **Health** tab: the running day ("Today") of the demo person. The card "Activity records" has two concentric rings, Steps (goal 10,000) and Exercise (moderate plus vigorous minutes, goal 30 min). Below it one card per metric: Heart rate with the label "Live" (a static demo value near the person's resting rate, not a measurement), Resting heart rate, Sleep (last night, bed to wake as clock times and the total as "7 h 24 min"), Exercise as "moderate / vigorous" minutes, and two tiles for VO₂max and HRV (percentiles; HRV reads "Not measured" for a person whose watch has none). A card opens that metric over the completed days (`pages/MetricPage.ets`, bars per day).
- **History** tab (`ui/HistoryView.ets`): the completed days newest first (28; Ola 16) with steps, intensity minutes (moderate / vigorous), resting heart rate, sleep (bed–wake, total) and HRV percentile; then "VO₂max estimates" (date, percentile) and "Heart-rate recovery tests" (date, protocol, "peak 150 → 118 after 60 s", "HRR1 32 bpm"). A person with none gets a one-line empty state. Ids: `hs_history_days`, `hs_history_crf`, `hs_history_hrr`, `hs_history_day_<date>`.
- **Me** tab: "Demo person" (the six names, a demo-only control; ids `hs_person_<id>`), the **Scenario** developer tool, and "Connected apps" with the FairWear card. The card says what is shared when you allow it, including the wear time per day that FairWear's wear check uses, and that it is a simulated integration point: real HUAWEI Health has no such card.
- **Scenario** (in the Me tab, tagged "Developer tool", `ui/ReadinessView.ets`): the card "FairWear readiness" for the chosen person. Eight component rows (label, valid of minimum / target, Core or Optional, a tick or cross together with the words "Ready" / "Not ready"), then for both weight profiles the evidence coverage and a preview ("75 · Tier B · Confidence High" or "No score yet"), and the caption "Simulator check — FairWear computes the official result". It renders `healthSimReadiness()` from `common` and calculates nothing. Ids: `hs_readiness`, `hs_readiness_row_<componentId>`, `hs_readiness_preview_HEALTH_WELLNESS`, `hs_readiness_preview_LONGEVITY_WELLNESS`, `hs_readiness_note`.
- **Me → Connected apps → FairWear**: "Open FairWear" starts FairWear (`com.fairwear.app`, `EntryAbility`, `fwTarget: 'dashboard'`). The system asks "Allow Health Sim to open FairWear?" first. When FairWear is not installed, the card says so.

## What the watch module does

- Page 1: "Activity records", a Steps ring and an Exercise ring with their values, read from the scripted day (steps per minute times the length of each stretch; a stretch whose scripted heart rate starts at 100 bpm or more counts as exercise). The watch shows nothing of the score.
- Swipe up, page 2: "Wear today · for FairWear", the same day as a 24-hour ring of worn, charging and off-wrist time. The two pages do not loop.
- `WatchExportAbility` hands the scripted day to FairWear on the same watch as one JSON text (`fwhsw1`). The script (`BUILT_IN_SCRIPT`, `encodeWatchScript`) comes from `common`. The day is one fixed script, not a measurement.

## How FairWear gets the data

FairWear starts `AuthAbility` for a result, by bundle and ability name, with the Want parameter `fwScopes` (names of the data types it asks for, the `HealthScope` names). Health Sim shows "FairWear asks for access" with one switch per requested type (`hs_scope_<SCOPE>`, `hs_auth_allow`, `hs_auth_deny`).

- **Allow**: result code `0` and the Want parameter `fwhs1`, a JSON text, **contract version 2** (`schema: "fairwear.health-export"`): all six people with `today`, `days`, `crf`, `hrr` and `wear`. A reading that does not exist is an absent field; a type that was switched off is handed over as not measured (absent). `exportedAt` is the time of the answer, taken from the phone's clock in the consent screen.
- **Don't allow**: result code `1`, no data.

The link `healthsim://authorize` opens the same screen; FairWear uses it only if the explicit start is refused. A request without `fwScopes` lists every type. Nothing goes over the network. Both apps must run on the same phone emulator.

If Health Sim is not installed or does not answer, FairWear keeps working on its built-in demo data.

## Layout

```
libs/common.har       FairWear's common module, built; do not edit (tools/sync-common-har.sh)
entry/src/main/ets/
  data/SimData.ets    the people and their days as text for the screens (reads HesPersonas from common)
  data/SimTexts.ets   UI copy
  ui/SimBanner.ets    the banner and the card style
  ui/SimMetric.ets    name, symbol and accent colour of each metric
  ui/HistoryView.ets  History tab
  ui/ReadinessView.ets  Scenario card
  pages/Index.ets     banner, tabs Health / History / Me
  pages/MetricPage.ets  one metric of the demo person over the completed days
  pages/AuthPage.ets  the consent screen
  authability/        AuthAbility (reads fwScopes)
  entryability/       EntryAbility
```

## Build and run

Order matters: the package first, then the two modules.

```
cd <repository root> && bash tools/sync-common-har.sh        # only when common/ changed
cd healthsim && source ../tools/env.sh && unset ELECTRON_RUN_AS_NODE && ohpm.bat install --all
hvigorw.bat assembleHap --mode module -p module=entry@default -p product=default -p buildMode=debug --no-daemon
hvigorw.bat assembleHap --mode module -p module=watch@default -p product=default -p buildMode=debug --no-daemon
hdc -t <phone> install -r entry/build/default/outputs/default/entry-default-unsigned.hap
hdc -t <phone> shell aa start -b com.fairwear.healthsim -m entry -a EntryAbility
```

`unset ELECTRON_RUN_AS_NODE` is required in a VS Code shell, or hvigor crashes. After the builds run `bash tools/check-single-engine.sh` from the repository root (exit 0 = one engine).

What was run on the emulator is recorded in `docs/test-results.txt` of the repository.
