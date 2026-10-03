# FairWear architecture notes

## Data flow

```
WATCH 5 → HUAWEI Health (phone) → [Health Service Kit + user authorization]
        → FairWear on the phone (HES-Lite + wear rules) → signed tier → QR → partner

FairWear watch app → live heart rate + wear state (not part of HES)
```

FairWear is an add-on for HUAWEI Health users: with their permission it reads what HUAWEI Health already
measures, scores it on the phone, and shares only a signed tier.

## Modules

| Module   | Device                    | What is in it                                                                                                           |
| -------- | ------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `common` | none (HAR, no UI imports) | Model types, tier claim codec, selective non-wear rule, the health source layer (`health/`), live wear state (`live/`). |
| `entry`  | phone                     | The add-on screens, the HUAWEI Health adapter stub, device signing (`platform/`).                                       |
| `watch`  | wearable                  | Live heart rate, steps today and wear state.                                                                            |

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

| Part                                                                  | State                                                                                                                                   |
| --------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| HUAWEI Health connection                                              | Stub. Access to sensitive data through Health Service Kit needs Huawei's approval for the app; it was not granted during the hackathon. |
| HUAWEI Health authorization screen                                    | Not shown. A DEMO placeholder stands in its place; FairWear does not copy Huawei's screen.                                              |
| Consent logic, status transitions, per-data-type switches             | Real, covered by tests (`common/src/test/Health.test.ets`).                                                                             |
| Demo history in HUAWEI Health record format (`SyntheticHealthSource`) | Not in this branch yet. The demo source is empty, so the screens show "—".                                                              |
| Scoring (HES-Lite), tier, coverage                                    | Not in this branch yet. The tier is shown as "—" with "HES-Lite not connected".                                                         |
| VO₂max and HRV from HUAWEI Health                                     | Will not be scored without a cited percentile table.                                                                                    |

## Permissions

| Module  | Permission                         | Reason shown to the user                                                                          |
| ------- | ---------------------------------- | ------------------------------------------------------------------------------------------------- |
| `entry` | none                               | The add-on screens need no permission in this build; the HUAWEI Health adapter is a stub.         |
| `watch` | `ohos.permission.READ_HEALTH_DATA` | "FairWear shows your live heart rate on the watch and uses it to tell whether the watch is worn." |
| `watch` | `ohos.permission.ACTIVITY_MOTION`  | "FairWear shows the steps counted today on the watch."                                            |

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
| A host app or the command line | `Want` parameter `fwTarget`                        | the named screen                   |

`EntryAbility` passes the want to `routeFromWant` (`entry/src/main/ets/nav/EntryRouter.ets`) in `onCreate`
and `onNewWant`; the start page opens the screen. The value is untrusted input. `resolveFwTargetFromWant`
(`common/src/main/ets/nav/EntryTarget.ets`) accepts `dashboard`, `share` and `source`; a missing value, an
unknown value, a non-string, an oversized string or malformed card parameters open the start page and never
throw (7 tests in `common/src/test/EntryTarget.test.ets`). `share` is reserved for the share screen, which
is not in this build, so it opens the start page and there is no shortcut for it yet.

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
home screen, and changes from "HUAWEI Health · not connected" to "HUAWEI Health · DEMO" after consent
(`docs/screenshots/ta1-home-card-phone.jpeg`, `ta1-home-card-after-consent-phone.jpeg`).
Coverage and "Score ready" stay "—" until the scoring module is part of the build.
The card and Preferences need no permission.
