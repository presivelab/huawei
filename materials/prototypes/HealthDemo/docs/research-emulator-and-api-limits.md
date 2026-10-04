# HarmonyOS wearable emulator (DevEco 6.1.1): what a third-party ArkTS app can read and do

**Bottom line:** on this emulator the only live health inputs are `sensor.SensorId.HEART_RATE` and `PEDOMETER` (plus light and motion), set by GUI slider. Huawei documents a CLI for injecting them, but only from emulator version 26.0.0, and the installed binary does not have it. Health Service Kit, Wear Engine, Multimodal Awareness Kit and the vibrator are documented as unsupported on the (wearable) emulator. No continuous-task type covers background heart-rate sampling on a watch.

**Method.** Local SDK and emulator files were read directly (path:line below). Huawei pages are JS-rendered, so I pulled their content from Huawei's own doc backend (`svc-drcn.developer.huawei.com/.../documentPortal/getDocumentById`); the URLs cited are the public pages for the same document ids. Read-only `hdc` commands were run against 127.0.0.1:5555. The emulator was not stopped, reconfigured, installed to or clicked. Temp files I created in the scratchpad were deleted.

**Version discrepancy to be aware of.** `tools\emulator\sdk-pkg.json:9` says 6.1.1.200, but `C:\Users\robac\AppData\Local\Huawei\Emulator\deployed\versionInfo.txt:1` says 6.1.1.280. The image is 6.1.0.125, API 24 (`deployed\Huawei_Wearable\config.ini:8-10`).

---

## 1. Virtual sensor panel and injection

### What the panel can set
- **Documented:** three virtual sensors — pedometer (`PEDOMETER`), ambient light (`AMBIENT_LIGHT`), heart rate (`HEART_RATE`). "Since DevEco Studio 6.1.0 Beta1, wearables support the heart rate sensor." Values are changed by slider or text box. Source: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-emulator-more-features (section "Virtual Sensor", updated 2026-09-16).
- **Ranges** (UI strings in `tools\emulator\translations\emulator_en.qm`, matching the CLI doc):
  - Heart rate (bpm): upper bound 255; the doc gives [0, 255].
  - "Pace taking (steps)": up to 100000.
  - Light (lux): up to 100000.
- **Other strings in the same widget:** accelerometer, gyroscope, magnetic field, humidity, pressure, proximity, ambient temperature, with tabs "Motion Sensors" / "Additional Sensors". Which of these show for deviceType wearable is not confirmed.
- **Per-device gating:** `tools\emulator\sensorList.json` lists `wearable` for accelerometer (l.8), gyroscope (l.19), ambientLight (l.30), magneticField (l.41), orientation (l.83), gravity (l.94), rotationVector (l.105), pedometer (l.136) and heartRate (l.158). It does not list wearable for hall, humidity, ambientTemperature, significantMotion or posture. That is the same nine sensors you measured.
- **Wrist gestures:** the .qm also holds a "Gesture" widget ("Raise wrist" / "Wrist drop", with text about the always-on switch). It is not in Huawei's docs; whether it is exposed in this build is not confirmed.

### Replay or import
- None for sensors. The only replay feature is GPS: GPX import, replay speed, and preset scenarios (outdoor running, cycling, driving), the presets being Chinese-mainland only (same page, "GPS Positioning"). The .qm caps GPX at 1000 records.
- The .qm contains "Macro Playback" strings (`macro.openfile`, `macro.play`). They are undocumented; not confirmed as a usable feature.

### Command line
- **Documented, but for a newer emulator:** `Emulator -instance {name} -sensor {-light/-steps/-heartrate} {value}`. Ranges: light [0.0, 100000.0], steps [0, 100000], heartrate [0, 255]; one sensor per call.
  - The parent section says scenario simulation via CLI is supported "Since version 26.0.0". The same generation adds `-battery`, `-gps`, `-outdoorRunning`, `-shake`, `-screenshot`, `-uiLayout`, click/swipe/input and `-noWindow`.
  - Source: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-emulator-command-line (sections "Scenario-based Simulation" → "Sensor"; the cn page is identical).
- **Not in the installed binary:** the usage text inside `tools\emulator\Emulator.exe` lists only `-start/-hvd`, `-stop`, `-list [-details]`, `-create`, `-delete`, `-config`, `-install`, `-uninstall`, `-imageList`, `-screenProfileList`, `-license`, `-version`, `-bootmode`. The strings `-instance`, `-sensor`, `-heartrate`, `-steps`, `-noWindow` do not occur in ASCII or UTF-16. I did not execute `Emulator.exe`.
- **Weak corroboration:** an npm test package (`@deveco-test/deveco-cli` SKILL.md on jsdelivr) describes `devecocli emulator sensor` (light, humidity, temperature, steps, heartrate) as requiring "Emulator 7.0+". It is not an official doc.
- **No host control channel:** the running process is `Emulator.exe -start Huawei_Wearable` and listens only on 127.0.0.1:5555 (hdc). There is no QMP, telnet or console port. Sensor values travel over an internal virtio device (`express_sensor`, `Log\qemu.log:5`).

### Config file
- `deployed\Huawei_Wearable\huawei-settings.cfg:8-17` has a `[Sensor]` section persisting `pace.level=1000` (steps), `accel.*`, hall and posture.
- The binary also knows the keys `/Sensor/heart.rate.level`, `/Sensor/light.level`, `/Sensor/humidity.level` and `/Sensor/temperature.level`, but `heart.rate.level` is not in the current cfg.
- Whether editing the cfg before a cold start seeds heart rate is not confirmed; testing it needs a restart. It cannot drive a running instance.

### Device side (hdc shell, uid shell)
- No sensor-injection tool exists in `/system/bin`. Input tools only: `uinput` (keyboard, mouse, touchpad, stylus) and `uitest uiInput` (click, swipe, keyEvent, text). Neither has a sensor or crown verb in its help.
- `hidumper -s 3601` (SensorService) returns an empty body for every argument tried (`-h`, `-l`, `-c`, `-o`, `-d`); same for 3602 (MiscDeviceService) and 2902 (DeviceStatusService).
- No sensor or express nodes are visible in `/dev`; `/vendor/etc/sensors` is permission-denied.
- Crown rotation can be scripted from a test HAP: `Driver.crownRotate(d, speed?)`, since 20, `openharmony\ets\api\@ohos.UiTest.d.ts:4905`.

**For the mock:** on this install, heart rate can only be driven through the GUI. For automated tests, put a data-source interface in the app with a fake provider, or upgrade to an emulator ≥ 26.0.0 and use `-sensor -heartrate`.

---

## 2. Health data sources: real watch vs emulator

SDK root: `C:\Program Files\Huawei\DevEco Studio\sdk\default` (API 24, 6.1.1.125). The d.ts files carry no device-type tags, only `@syscap`; device support comes from `hms\ets\api\device-define\wearable.json`, `wearable-hmos.json` and `openharmony\ets\api\device-define\wearable.json`.

| Source | In local SDK | Wearable in SDK device-define | Emulator, per Huawei docs | Emulator, observed |
|---|---|---|---|---|
| **Health Service Kit** `import { healthStore, healthService } from '@kit.HealthServiceKit'` | Yes: `hms\ets\api\@hms.health.store.d.ts`, `@hms.health.service.d.ts` (since 5.0.0(12)) | Yes: `wearable-hmos.json:28-29` | "The Emulator does not support wearable app development", nor workout linkage, real-time Activity rings, manual sync or Huawei Health features (health-service-kit-ability, "Emulator Support") | Syscap params read `true`, but the bundle named in the d.ts header (`com.huawei.hmos.health.kit`) is not installed: `bm dump -n` and `bm dump-shared -n` both fail |
| **Wear Engine** `import { wearEngine } from '@kit.WearEngine'` | Yes: `@hms.health.wearEngine.d.ts` (since 5.0.0(12)) | Yes: `wearable-hmos.json:30-31` | "This kit does not support emulators" (we-business_introduction, "Supported Emulators") | Same missing bundle |
| **Sensor** `import { sensor } from '@kit.SensorServiceKit'` | Yes: `openharmony\ets\api\@ohos.sensor.d.ts` | Yes: `wearable.json:208-209` | Sensor module supported, with differences (sensorservice-kit-intro) | Nine sensors, as you measured |
| **Vibrator** `import { vibrator } from '@kit.SensorServiceKit'` | Yes: `@ohos.vibrator.d.ts` | Yes: `wearable.json:206-207` | "Currently, the Vibrator module is not supported on the Emulator" (same page) | Syscap and MiscDeviceService present; actual behaviour not tested |
| **Multimodal Awareness Kit** `import { motion, deviceStatus, stationary, userStatus, onScreen, metadataBinding } from '@kit.MultimodalAwarenessKit'` | Yes | **No**: none of its syscaps appear in any wearable device-define file | "This Kit does not support the Emulator" (multimodalawareness-kit-intro) | Image declares only `MultimodalAwareness.DistanceMeasurement`, `.OnScreenAwareness`, `.UserStatus` |

Doc URLs are all `https://developer.huawei.com/consumer/en/doc/harmonyos-guides/<id>`.

### Health Service Kit on a real watch
- Wearable-side reads exist from 5.1.1(19): `healthStore.readData` for sample points, workout records and health records, and `healthService.workout.readActivityReport()` for live rings.
- The read requests ignore their time parameters: "Only the latest data record on the watch can be returned" (health-wearable-samplepoint-manage, health-wearable-exercisesequence-manage, health-wearable-healthsequence-manage, health-wearable-three-ring-read).
- Data-type constants in `@hms.health.store.d.ts` (namespace `healthDataTypes`, from l.1588):
  - since 12: `HEART_RATE`, `RESTING_HEART_RATE`, `BLOOD_OXYGEN_SATURATION`, `STRESS`, `BODY_TEMPERATURE`, `SKIN_TEMPERATURE`, `BLOOD_PRESSURE`, `SLEEP_RECORD`, `SLEEP_NAP_RECORD`, `DAILY_ACTIVITIES`, `WORKOUT`;
  - since 18: `HEART_RATE_VARIABILITY`, `EMOTION`;
  - since 24: `MENSTRUAL_CYCLE`.
- So HRV, SpO2, skin temperature and sleep exist only through this kit; there is no raw sensor id for them.
- Access needs an approved application: manual review of about 10 working days, test permission capped at the first 100 users, client ID and signing fingerprint (health-apply). Data timeliness is hourly or minute-level (health-data-overview).
- `healthService.workout` (`config/start/pause/resume/stop/onData`, since 18, `@hms.health.service.d.ts:317-428`): the guide tree only documents it under "Developing Lite Wearable Apps → Managing Workout Linkage". Availability on a standard wearable is not confirmed.

### Wear Engine on a real watch
- Wearable-side apps are supported since 5.1.0(18), but the wearable-side guide covers only querying connected peers and P2P messages/files (watch_query_connected_devices, watch_p2p_communication).
- The health-relevant parts are phone-side and gated:
  - `SensorClient` with `SensorType` ECG=0, PPG=1, ACC=2, GYRO=3, MAG=4, HR=6 (`@hms.health.wearEngine.d.ts:1565`). The human-body sensors are "only for professional research institutions" (device_sensor).
  - `MonitorItem.WEAR_STATUS` (l.913) and `EVENT_HEART_RATE_ALARM` (l.971), open to enterprise developers.

### Sensor ids
- `SensorId` enum is at `@ohos.sensor.d.ts:47-198`. Permissions: `on(HEART_RATE)` l.368 needs `ohos.permission.READ_HEALTH_DATA`; `on(PEDOMETER)` l.464 needs `ACTIVITY_MOTION`; `on(WEAR_DETECTION)` is at l.531.
- In the enum but absent on the emulator: `BAROMETER` 8, `HALL` 10, `PROXIMITY` 12, `HUMIDITY` 13, `LINEAR_ACCELEROMETER` 258, `AMBIENT_TEMPERATURE` 260, the uncalibrated variants, `SIGNIFICANT_MOTION` 264, `PEDOMETER_DETECTION` 265, `WEAR_DETECTION` 280, `FUSION_PRESSURE` 283 (since 22).
- There is no SpO2, HRV, skin-temperature, ECG or PPG id in the enum.
- Which ids a physical Huawei watch reports is not confirmed; the docs only say the device must have the hardware.

### Motion, activity and on-wrist detection
- The kit intro claims activity recognition ("walking, running, driving"), but the API-24 d.ts files expose only:
  - `motion`: `operatingHandChanged`, `holdingHandChanged` (syscap `MultimodalAwareness.Motion`, since 15/20, `@ohos.multimodalAwareness.motion.d.ts:119-185`);
  - `deviceStatus`: `steadyStandingDetect` (since 18, l.62);
  - `stationary`: `'still' | 'relativeStill'` (syscap `Msdp.DeviceStatus.Stationary`, since 9, `@ohos.stationary.d.ts:116`);
  - `userStatus`: `userAgeGroupDetected` (since 20).
- There is no walking/running classifier and no on-wrist API in this kit.
- On-wrist options are therefore: `SensorId.WEAR_DETECTION` (missing on the emulator); the deprecated lite API `Sensor.subscribeOnBodyState` (`@system.sensor.d.ts:913`, syscap `Sensors.Sensor.Lite`, deprecated since 8); or phone-side Wear Engine `WEAR_STATUS`. `@ohos.bluetooth.wearDetection.d.ts` is an empty namespace.

### General emulator limits
From https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-emulator-specification:
- Bluetooth: no scanning, connection or data transfer. The image also declares only `Communication.Bluetooth.Lite`, not `.Core`.
- No NearLink, NFC, TEE or biometrics.
- Unsupported kits crash on static import with `resolveBufferCallback get hsp buffer failed, hsp path:/data/storage/el1/bundle/com.huawei.hmos.{KitName}.kit`; Huawei's advice is "import Kits dynamically".

---

## 3. Wearable ArkUI building blocks in the local SDK

All Arc components carry `@syscap SystemCapability.ArkUI.ArkUI.Circle`. The emulator image declares it, and it is in the SDK wearable define (`hms\...\wearable.json:24`). The `@kit.ArkUI` re-exports are in `openharmony\ets\kits\@kit.ArkUI.d.ts` at lines 24, 83, 84, 85, 95, 96.

| Item | Import | Since | d.ts |
|---|---|---|---|
| ArcSwiper | `import { ArcSwiper, ArcSwiperAttribute, ArcDotIndicator, ArcDirection, ArcSwiperController } from '@kit.ArkUI'` | 18 | `api\@ohos.arkui.ArcSwiper.d.ts` |
| ArcList / ArcListItem | `import { ArcList, ArcListItem, ArcListAttribute, ArcListItemAttribute } from '@kit.ArkUI'` | 18 | `api\@ohos.arkui.ArcList.d.ts:406,424`; `digitalCrownSensitivity` l.136 |
| ArcButton | `import { ArcButton, ArcButtonOptions, ArcButtonPosition, ArcButtonStyleMode, ArcButtonStatus, ArcButtonProgressConfig } from '@kit.ArkUI'` | 18 (`ArcButtonProgressConfig` and progress fields: 23) | `api\@ohos.arkui.advanced.ArcButton.d.ets:578` |
| ArcSlider | `import { ArcSlider, ArcSliderOptions, ArcSliderValueOptions, ArcSliderLayoutOptions, ArcSliderStyleOptions, ArcSliderPosition } from '@kit.ArkUI'` | 18 | `api\@ohos.arkui.advanced.ArcSlider.d.ets:592` |
| ArcAlphabetIndexer | `import { ArcAlphabetIndexer, ArcAlphabetIndexerAttribute } from '@kit.ArkUI'` | 18 | `api\@ohos.arkui.ArcAlphabetIndexer.d.ts:268` |
| ArcScrollBar | `import { ArcScrollBar, ArcScrollBarAttribute } from '@kit.ArkUI'` | 18 | `api\@ohos.arkui.ArcScrollBar.d.ts:101` |
| `.onDigitalCrown(handler)` | none (universal attribute) | 18 | `component\common.d.ts:22787`; `CrownEvent` at l.14878 |
| `CrownAction`, `CrownSensitivity` | none (global enums) | 18 | `component\enums.d.ts:10752`, `:10787` |
| `.digitalCrownSensitivity()` | none | 18 | `common.d.ts:31673` (scrollables); also Slider, DatePicker, TextPicker, TimePicker, ArcList, ArcSwiper, ArcSlider options |
| Round-screen check | `import { display } from '@kit.ArkUI'` | 18 | `api\@ohos.display.d.ts:1407` (`ScreenShape`), `:2128` (`Display.screenShape?`) |
| Haptics | `import { vibrator } from '@kit.SensorServiceKit'` | `startVibration` 9; `HapticFeedback` presets 12; notice presets 18 | `api\@ohos.vibrator.d.ts:190`, `:570` |
| Widgets | `import { FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit'` | FormExtensionAbility 9; `DIMENSION_2_3 = 8`, `DIMENSION_3_3 = 9` since 18 | `api\@ohos.app.form.formInfo.d.ts:1194`, `:1202` |
| Keep screen on | `import { window } from '@kit.ArkUI'` → `setWindowKeepScreenOn(boolean)` | 11 | `api\@ohos.window.d.ts:6998` |

Notes on specific rows:
- **Crown:** `CrownEvent` has `timestamp`, `angularVelocity`, `degree`, `action`, `stopPropagation`. `CrownAction.BEGIN` is deprecated since 24 (`enums.d.ts:10759`). Per the doc, only the focused component receives crown events and only wearables support them; Slider, DatePicker, TextPicker, TimePicker, Scroll, List, Grid, WaterFlow, ArcList, Refresh and Swiper handle the crown by default (https://developer.huawei.com/consumer/en/doc/harmonyos-guides/arkts-common-events-crown-event).
- **Crown on the emulator:** mouse wheel over the screen rotates the crown; click = home/watch face; double-click = multitasking (ide-emulator-more-features, "Crown").
- **Round screen:** use `display.getDefaultDisplaySync().screenShape === display.ScreenShape.ROUND`. `roundScreen?: boolean` at `common.d.ts:7790` is only an `@Preview` parameter.
- **Haptics:** need `ohos.permission.VIBRATE`; not supported on the emulator, so guard every call.
- **Widgets:** the two since-18 dimensions are commented "used for wearable devices". Form Kit lists wearables as supported (formkit-overview).
- **Always-on / ambient:** no third-party AOD or ambient-mode API exists in the SDK. A grep for always-on-display, AOD, ambient and half-bright across `openharmony\ets\api`, `component` and `hms\ets\api` found nothing relevant. The only control is `setWindowKeepScreenOn`, whose lock is released when the window goes to the background (brightness-control).
- **Live View:** `@hms.core.liveview.*` is in the SDK, but the emulator image declares no LiveView syscap. Wearable support is not confirmed.

---

## 4. Background execution for heart-rate sampling

**Lifecycle on a watch.** "On Phone, TV, Wearable, and Car devices: When the window transitions from the foreground state to the background state, it also drives the UIAbility to the background state" (https://developer.huawei.com/consumer/en/doc/harmonyos-guides/window-lifecycle, "Differentiated Behavior of UIAbility Lifecycle on Different Devices").

**Default after backgrounding.** The process is suspended after a while and then "cannot use software resources (such as common events and timers) or hardware resources (such as CPU, network, GPS, and Bluetooth)". Only the constrained task types extend this (background-task-overview). Huawei's docs do not address sensor callbacks in the background specifically; the sensor overview only says Sensor Service "manages foreground and background policies".

**Continuous tasks** (`backgroundTaskManager.startBackgroundRunning`, permission `ohos.permission.KEEP_BACKGROUND_RUNNING`, UIAbility only, shows a notification; syscap is in the wearable define at `hms\...\wearable.json:176`). Types, from the continuous-task guide and `openharmony\ets\api\@ohos.resourceschedule.backgroundTaskManager.d.ts:938` onwards:
- `DATA_TRANSFER`, `AUDIO_PLAYBACK`, `AUDIO_RECORDING`, `LOCATION`, `BLUETOOTH_INTERACTION`, `MULTI_DEVICE_CONNECTION`, `VOIP` (13).
- `TASK_KEEPING`: on non-PC devices only from API 21 and only with the ACL permission `ohos.permission.KEEP_BACKGROUND_RUNNING_SYSTEM`.
- `MODE_AV_PLAYBACK_AND_RECORD` (22).
- `MODE_SPECIAL_SCENARIO_PROCESSING` (22): the guide says "available only for smartphones, tablets, PCs/2-in-1 devices", so not wearables. Its SDK submode `SUBMODE_WORK_OUT_NORMAL_NOTIFICATION = 11` (since 23, d.ts l.1176, "used for workout scenarios") needs `requestAuthFromUser` (since 22).
- `MODE_NEARLINK` (26.0.0).

There is no health, sensor or workout type usable on a watch. The system also checks that the declared type matches actual activity and suspends or kills mismatches; "malicious keep-alive" is a penalised violation (continuous-task "Constraints"; bgtask-design-formula).

My inference, not a doc statement: a workout app that really uses GPS or Bluetooth could hold `LOCATION` or `BLUETOOTH_INTERACTION` and sample heart rate while it runs. Holding one only to sample heart rate would violate the consistency rule.

**Transient task** (`requestSuspendDelay`): at most 3 concurrent, 3 minutes per request (1 minute on low battery), default quota 10 minutes per 24 hours (transient-task). Enough to flush data, not to sample.

**Deferred task** (`workScheduler` + `WorkSchedulerExtensionAbility`): at most 10 tasks; minimum interval 2 h for the "active" app group, up to 48 h for rarely used; 2 minutes per callback (work-scheduler). Not suitable for sampling.

**Realistic route on a real watch:** let the system's health service do the sampling and read the latest record through Health Service Kit (section 2).

**Emulator:** Background Tasks Kit is supported with general differences; agent-powered reminders work from API 20 (background-task-overview, "Emulator Support"). The image declares the ContinuousTask, TransientTask, EfficiencyResourcesApply and WorkScheduler syscaps.

---

## Not confirmed

1. Whether `HEART_RATE` callbacks keep arriving after the app is backgrounded (emulator or real watch): no doc statement, and I ran no test.
2. Whether seeding `heart.rate.level` in `huawei-settings.cfg` works at cold start (needs a restart).
3. What `Emulator.exe -help` actually prints on this install (not executed; conclusion comes from embedded usage text) and whether undocumented options exist.
4. Whether the "Raise wrist / Wrist drop" gesture widget and "Macro Playback" are reachable in this emulator's UI.
5. Which virtual-sensor controls beyond heart rate, steps and light the wearable panel shows; the heart-rate slider's lower bound in the GUI (CLI doc says 0).
6. Runtime behaviour of `@kit.HealthServiceKit` / `@kit.WearEngine` on this emulator (crash vs error code), and what `canIUse('SystemCapability.Health.HealthStore')` returns. The syscap param is `true` while the kit bundle is missing.
7. Whether DevEco rejects `@kit.MultimodalAwarenessKit` APIs at build time for a wearable-only module (inferred from the missing syscaps in device-define; no build run).
8. Which `SensorId`s a physical Huawei watch reports, in particular `WEAR_DETECTION`, `BAROMETER`, `PEDOMETER_DETECTION`.
9. Whether `healthService.workout.*` is callable from a standard wearable app.
10. Whether `MODE_SPECIAL_SCENARIO_PROCESSING` + `SUBMODE_WORK_OUT_NORMAL_NOTIFICATION` is honoured on wearables in any release (docs say no; the SDK comment is device-agnostic).
11. Vibrator behaviour on this emulator (docs say unsupported; the service and syscap are present).
12. Live View Kit and third-party always-on/ambient support on wearables: no API or doc statement found.
13. The public release status of emulator/DevEco "26.0.0" beyond its appearance in Huawei's docs.
14. That `hidumper`'s empty output for SensorService is a shell-uid restriction rather than an unimplemented dump.
