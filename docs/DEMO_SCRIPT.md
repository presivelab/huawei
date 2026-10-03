# Demo script: connecting and disconnecting HUAWEI Health

**This is the path matching Huawei's verification requirements for an integration. All data is DEMO.**

Huawei verifies an integration on a recording that has to show: the entry to the first authorization, the full
list of permissions as in the application, the app working after authorization, disconnecting, asking for
consent again, and the app working after that. The FairWear demo recording follows the same path:

AD-1 → AD-2 (consent) → result → AD-3 (disconnect) → AD-2 (consent again) → result.

## What is real and what is simulated in this path

- FairWear does not read from HUAWEI Health in this build. Access to health data through Health Service Kit
  has to be granted to the app by Huawei; FairWear does not have it. The adapter is a stub with the status
  `UNAVAILABLE`.
- The HUAWEI Health authorization screen is not shown and not copied. In its place there is a neutral DEMO
  placeholder with two buttons that stand in for the user's answer.
- The status after consent is `DEMO`. No demo records are loaded in this build, and the scoring module
  (HES-Lite) is not part of it yet, so the tier, the Health Evidence Score, coverage and last sync are shown
  as "—". Nothing on the result screen is an invented number.
- The consent logic is real: both steps are required, each data type can be switched off, and disconnecting
  takes the status back to `NOT_AUTHORIZED` (tests in `common/src/test/Health.test.ets`).

## Steps

Phone emulator, app started with `tools/deploy.sh entry`. The source status is visible on every screen.

| #   | Screen           | What to do                                                                             | What to show                                                                                                                                                                                        | Screenshot                                                                                               |
| --- | ---------------- | -------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| 1   | AD-1 welcome     | Start FairWear.                                                                        | Status `HUAWEI Health · NOT_AUTHORIZED`, no tier. One sentence on what is read, what is not, and what leaves the phone.                                                                             | `screenshots/addon-01-welcome.jpeg`                                                                      |
| 2   | AD-1 → AD-2      | Tap **Connect HUAWEI Health**.                                                         | The entry to the first authorization.                                                                                                                                                               |                                                                                                          |
| 3   | AD-2, step 1     | Read the list aloud, then tap **Simulate consent**.                                    | DEMO placeholder where HUAWEI Health shows its own screen. Full list of what FairWear asks for: steps, resting heart rate, sleep, activity minutes, VO₂max, HRV, workouts; last 90 days, read only. | `screenshots/addon-02-consent-step1-demo-placeholder.jpeg`                                               |
| 4   | AD-2, step 2     | Optionally switch one data type off. Tick the consent box, tap **Agree and continue**. | FairWear's own consent (GDPR Article 9), separate from step 1, with a switch per data type.                                                                                                         | `screenshots/addon-04-consent-step2-gdpr.jpeg`, `screenshots/addon-05-consent-step2-hrv-off-agreed.jpeg` |
| 5   | Result           | Scroll down to **Data source**.                                                        | Status `HUAWEI Health · DEMO · last sync —`. Tier "—" with "HES-Lite not connected". A data type that was switched off shows "Off · missing evidence".                                              | `screenshots/addon-06-result-demo.jpeg`, `screenshots/addon-07-result-data-source-card.jpeg`             |
| 6   | AD-3             | Tap **Disconnect HUAWEI Health** (on the result screen or in Settings, the gear icon). | Status back to `NOT_AUTHORIZED`, the tier is hidden. The sentence about HUAWEI Health privacy settings.                                                                                             | `screenshots/addon-08-settings-connected.jpeg`, `screenshots/addon-09-disconnected-reconnect.jpeg`       |
| 7   | AD-3 → AD-2      | Tap **Reconnect**.                                                                     | Consent is asked again from step 1; nothing is remembered from before.                                                                                                                              | `screenshots/addon-10-settings-not-authorized.jpeg`                                                      |
| 8   | AD-2, both steps | **Simulate consent**, tick the box, **Agree and continue**.                            | Same two steps as before.                                                                                                                                                                           |                                                                                                          |
| 9   | Result           | —                                                                                      | Status `DEMO` again, all seven data types allowed.                                                                                                                                                  | `screenshots/addon-11-reconnected-result.jpeg`                                                           |

Side path, refusal: on AD-2 step 1 tap **Simulate refusal**. The status stays `NOT_AUTHORIZED` and the welcome
screen says what cannot be calculated without consent (`screenshots/addon-03-refusal-not-authorized.jpeg`).

The whole path above was run on the phone emulator on 2026-10-04 with scripted taps; the screenshots are
from that run.

## Not in this path yet

The score, "Why this tier", sharing the signed tier and the partner view depend on HES-Lite and are not part
of this branch. When they are added, they go between steps 5 and 6 and again after step 9.
