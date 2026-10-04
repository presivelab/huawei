# Health Sim

A small HarmonyOS phone app (ArkTS/ArkUI, stage model) that stands in for Huawei Health on the DevEco emulator, so FairWear can be demonstrated end to end without Health Service Kit approval.

**It is a simulator.** Every screen carries a "SIMULATED DATA" banner. It is not Huawei Health, not a Huawei app, and it never reads real health data. It uses no Huawei logo, colors or layouts.

## What it does

- Generates 30 days of wearable data for one persona (Ania, Kasia, Marek, Wei), deterministically: the same persona, seed and demo time always give the same bytes, shown as a **Data ID**.
- Shapes the data like Health Service Kit sample points: steps per 5-minute interval, heart-rate instants, resting heart rate, sleep fragments, SpO₂, skin temperature, stress, VO₂max. Data type names are provisional (`HsDataType`).
- Wear is never a data type (Huawei Health has none). It shows only as gaps in heart-rate samples.
- Heart rate rises with steps; illness lasts at least 2 days with raised resting heart rate; Marek takes the watch off after 2 such days; Wei has step padding (high steps, no heart-rate rise).
- Optional sync delay: the newest samples arrive 15–60 minutes late.
- UI follows the system language: English and Simplified Chinese.

## How FairWear gets the data

FairWear calls `HealthSimClient.connect(...)`, which opens `healthsim://authorize` with `openLink` and waits for a result. Health Sim shows a consent screen; the user picks data types. Health Sim returns a compact payload (base64-packed slots, about 65–71 KB for 30 days with every type) in Want parameters, under the 100 KB WantParams limit. FairWear decodes it into `HsSimStore`, whose `readData` has the `healthStore.readData` shape. Nothing goes over the network.

If the link does not resolve, the client falls back to an explicit `startAbilityForResult`. If Health Sim is not installed, `connectLocal` generates the same data inside FairWear (same Data ID in demo mode) and must be labeled as local.

Both apps must run on the **same** phone emulator: the DevEco emulator does not support distributed features or pairing.

## Layout

```
entry/src/main/ets/
  healthsim/        shared, pure logic (copy unchanged into FairWear common/)
    HsTypes, HsRandom, HsPersonas, HsGenerator, HsCodec, HsStore, HsSummary
    HealthSimClient  (FairWear side; uses @kit.AbilityKit)
  pages/Index.ets    Today / History / Scenario tabs
  pages/AuthPage.ets consent screen
  authability/       AuthAbility (deep link healthsim://authorize)
  components/        views and canvas charts
  model/             scenario persistence (Preferences), request parsing
tools/logic-tests/   Node tests for the logic layer (npm test)
```

## Verified

- ArkTS checker (`linter-cli` from the challenge repo, against OpenHarmony API declarations): no diagnostics in project files.
- Logic tests: 69/69 pass (`cd tools/logic-tests && npm install && npm test`).
- Not verified here: a DevEco build and a run on the emulator.
