# Health Sim

A small HarmonyOS app (ArkTS/ArkUI, stage model, bundle `com.fairwear.healthsim`) that stands in for HUAWEI Health on the DevEco emulators, so FairWear can be shown end to end without Health Service Kit approval.

**It is a simulator.** Every screen carries the banner "SIMULATED DATA · stands in for HUAWEI Health". It is not HUAWEI Health and not a HUAWEI app, it never reads real health data, and it uses no HUAWEI logo, colours or layouts.

## What the phone module does

- Holds the data of the **same six scripted people** FairWear scores (Ania, Marek, Kasia, Tomek, Ewa, Ola). The data comes from FairWear's own persona generator: the files under `entry/src/main/ets/fw/` are byte-for-byte copies of files in FairWear's `common/` (a test in `common` checks this). Fix such a file in `common` and copy it again; never edit the copy.
- **Today**: the newest completed day of the chosen person (steps, resting heart rate, sleep, activity minutes, time the watch was worn).
- **History**: the last 30 days, steps and sleep. A value that was not measured is shown as "—", never as zero.
- **Apps → FairWear**: "Open FairWear" starts FairWear (`com.fairwear.app`, `EntryAbility`, `fwTarget: 'dashboard'`). The system asks "Allow Health Sim to open FairWear?" first. When FairWear is not installed, the card says so.

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
  pages/Index.ets     banner, person picker, tabs Today / History / Apps
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
