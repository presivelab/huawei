# Health Sim

A small HarmonyOS app (ArkTS/ArkUI, stage model, bundle `com.fairwear.healthsim`) that stands in for HUAWEI Health on the DevEco emulators, so FairWear can be shown end to end without Health Service Kit approval.

**It is a simulator.** Every screen carries the banner "SIMULATED DATA · stands in for HUAWEI Health". It is not HUAWEI Health and not a HUAWEI app, it never reads real health data, and it uses no HUAWEI logo, name, brand colours or icons. The arrangement of its screens stays close to HUAWEI Health's (two bottom tabs, an activity card with rings, one card per metric), so it is clear at a glance what it stands in for.

## What the phone module does

- Holds the data of the **same six scripted people** FairWear scores (Ania, Marek, Kasia, Tomek, Ewa, Ola). The data comes from FairWear's own persona generator: the files under `entry/src/main/ets/fw/` are byte-for-byte copies of files in FairWear's `common/` (a test in `common` checks this). Fix such a file in `common` and copy it again; never edit the copy.
- **Health** tab: the newest completed day of the demo person. On top the card "Activity records" with two concentric rings: Steps (goal 10,000) and Exercise (moderate plus vigorous minutes, goal 30 min). There is no third ring: Health Sim has no data for one. Below it one card per metric, each with its own accent colour: Heart rate (resting, bpm), Sleep, Steps, and two tiles for VO₂max and HRV (percentiles). A value that was not measured is shown as "—", never as zero.
- **Metric detail**: tapping a card opens that metric over the last 30 days, one bar per day.
- **Me** tab: "Demo person" (the six names; a demo-only control, labelled as such) and "Connected apps" with the FairWear card. The card says what is shared when you allow it, including the wear time per day that FairWear's wear check uses, and that it is a simulated integration point: real HUAWEI Health has no such card; sharing with other apps is in its privacy settings.
- **Me → Connected apps → FairWear**: "Open FairWear" starts FairWear (`com.fairwear.app`, `EntryAbility`, `fwTarget: 'dashboard'`). The system asks "Allow Health Sim to open FairWear?" first. When FairWear is not installed, the card says so.

## What the watch module does

- Page 1: "Activity records", a Steps ring and an Exercise ring with their values, read from the scripted day (steps per minute times the length of each stretch; a stretch whose scripted heart rate starts at 100 bpm or more counts as exercise).
- Swipe up, page 2: "Wear today · for FairWear", the same day as a 24-hour ring of worn, charging and off-wrist time. The two pages do not loop.
- `WatchExportAbility` hands the scripted day to FairWear on the same watch as one JSON text (`fwhsw1`). The day is one fixed script, not a measurement.

## How FairWear gets the data

FairWear starts `AuthAbility` for a result, by bundle and ability name, with the Want parameter `fwScopes` (names of the data types it asks for, the `HealthScope` names). Health Sim shows "FairWear asks for access" with one switch per requested type.

- **Allow**: result code `0` and the Want parameter `fwhs1`, a JSON text with the history and the wear month of all six people (about 29.6 KB). A type that was switched off is handed over as not measured (`-1`).
- **Don't allow**: result code `1`, no data.

The link `healthsim://authorize` opens the same screen; FairWear uses it only if the explicit start is refused. A request without `fwScopes` lists every type. Nothing goes over the network. Both apps must run on the same phone emulator.

If Health Sim is not installed or does not answer, FairWear keeps working on its built-in demo data.

## Layout

```
entry/src/main/ets/
  fw/                 copies of FairWear's common/ (personas, wear month, payload); do not edit
  data/SimData.ets    the people and their days as text for the screens
  data/SimTexts.ets   UI copy
  ui/SimBanner.ets    the banner and the card style
  ui/SimMetric.ets    name, symbol and accent colour of each metric
  pages/Index.ets     banner, tabs Health / Me
  pages/MetricPage.ets  one metric of the demo person over the last 30 days
  pages/AuthPage.ets  the consent screen
  authability/        AuthAbility (reads fwScopes)
  entryability/       EntryAbility
```

## Build and run

```
cd healthsim && source ../tools/env.sh && ohpm.bat install --all
hvigorw.bat assembleHap --mode module -p module=entry@default -p product=default -p buildMode=debug --no-daemon
hdc -t <phone> install -r entry/build/default/outputs/default/entry-default-unsigned.hap
hdc -t <phone> shell aa start -b com.fairwear.healthsim -m entry -a EntryAbility
```

What was run on the emulator is recorded in `docs/test-results.txt` of the repository.
