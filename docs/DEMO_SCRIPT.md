# Demo script

Two recordings: **A**, the whole product in about four minutes, and **B**, the HUAWEI Health connect /
disconnect path that Huawei asks to see when it verifies an integration. Both run on the DevEco Studio
emulators (Phone and Wearable, HarmonyOS 6.1.1, API 24) with the unsigned debug HAPs from this repository.

Say once, at the start of A: the six people are synthetic demo personas; the HUAWEI Health authorization is a
labelled DEMO placeholder (Health Service Kit access needs Huawei's approval); the watch days come from the
labelled demo feed because the emulator's heart rate is 0; watch → phone goes over a development relay on
`hdc` instead of Wear Engine (needs paired devices). The score is deterministic rules and curves, not AI.
Everything in the app was built during HackYeah 2026.

## A. The whole product (about 4 min)

### Before recording

1. Start both emulators, then `tools/deploy.sh watch` and `tools/deploy.sh entry`.
2. Pair: on the watch, page with **Pair phone** → `node tools/watch-phone-relay.mjs` → on the phone
   **Pair watch …?** → **Confirm** → relay again.
3. Watch: **Demo clock ×300**, then **Demo feed: on**, then **Close day (demo)** once, so every shown day
   starts at 00:00 (a day the feed starts at midday has no break with enough context). Let the watch seal
   four more days (one every 4 min 48 s) and relay them: Evidence › Watch days says "All … days verified".
   Leave the last sealed day unsent for step 3:15.
4. Phone: Settings (gear) › **Disconnect HUAWEI Health**, so the recording starts on the welcome screen.
5. If you rehearsed: on each persona you touched, **Reset demo**. A used partner code is replaced by itself.

### Recording

| Time | Screen                       | Do                                                                    | Show                                                                                                                                                                       |
| ---- | ---------------------------- | --------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 0:00 | Welcome                      | —                                                                     | "HUAWEI Health · Not connected"; what is read, what never leaves the phone                                                                                                |
| 0:10 | Connect                      | **Connect HUAWEI Health** → **Simulate consent**                      | DEMO placeholder in place of Huawei's screen; the full list of data types, last 90 days, read only                                                                       |
| 0:20 | FairWear consent             | switch HRV off, tick the box, **Agree and continue**                  | FairWear's own consent (GDPR Art. 9), one switch per data type                                                                                                            |
| 0:30 | Report · Ania                | —                                                                     | 92 · A, coverage 100%, confidence High, "Full benefit · Eligible", 30 of 30 days, "HUAWEI Health · Demo data"                                                            |
| 0:45 | Report · Marek, then Kasia   | persona chip → Marek, then Kasia                                      | both 26 of 30 days; Marek B / 75 with "No benefit" and "3 suspicious breaks"; Kasia B / 73 with "Partial benefit": the same wear, a different pattern                     |
| 1:05 | Evidence › Calendar · Marek  | persona chip → Marek, **Evidence**, tap Thu 17 Sep                   | "Flagged" and the flag rule; "Off the wrist 13:05 for 5 h 35 min after resting HR +9 bpm and 46% fewer steps in the 24 h before"; **Appeal this day** → "Appeal sent", score unchanged |
| 1:30 | Why this tier · Tomek        | persona chip → Tomek, **Why this tier**                               | 79 · B, one point to A; Strongest / To improve / Missing data; the one change that reaches A; "How it's calculated"                                                      |
| 1:50 | Report · Ewa, Live card      | persona chip → Ewa; move the heart-rate slider; **Close the day**; **Reset demo** | the slider changes only the Live card; Close the day: the toast "Day closed · HES 64 · Tier B" (from C / 59); Reset: "Demo reset · HES 59 · Tier C"                       |
| 2:10 | Share · Marek                | persona chip → Marek, **Share**                                       | QR code; "What the partner sees": "Eligible: no · 3 suspicious breaks. The reason stays on this phone."; **Technical details** with "HUKS key"                            |
| 2:30 | Partner view · demo          | **Open partner view (demo)** → **Use the code from this phone**       | "Signature valid", the checks in order, "The code does not say why."                                                                                                      |
| 2:45 | Try to cheat                 | **Verify the same code again**; **Change tier to A and verify**       | "Already used · stopped at: not used before"; "Invalid signature · stopped at: signature"; back on Share: "Used once · no longer valid"                                    |
| 2:55 | What left this phone         | Share › **What left this phone**                                      | every code shown, with its exact text and size                                                                                                                            |
| 3:05 | Watch dial                   | —                                                                     | "DEMO ×300 · FEED", the ring with charging, worn and the 12:00–15:00 break, "1 to sync"                                                                                  |
| 3:15 | Relay → Evidence › Watch days | `node tools/watch-phone-relay.mjs once --tamper`, then `node tools/watch-phone-relay.mjs` | the relay prints `REJECTED (Invalid signature)` and the day is not taken in; the clean run: the day verified with worn / charging / off-wrist time and its break |
| 3:35 | How Watch Link works         | run the three checks                                                  | "Invalid signature · Not taken in"; "Duplicate day"; "Accepted · Missing 1 day(s)", then "Fills the gap"; "Your stored days were not changed"                             |
| 3:55 | Settings                     | **Disconnect HUAWEI Health**                                          | back to "Not connected"; consent is asked again from step 1                                                                                                               |

Optional: the home-screen card (long-press the icon → Widgets: source, coverage and whether a score is ready,
never the tier); the icon shortcut "How Watch Link works"; `node tools/watch-phone-relay.mjs once --drop 3`
→ "1 day missing".

Close the day per persona, for a longer demo: Tomek reaches A on the fourth closed day; Ania stays A; Marek
stays flagged; Ola does not reach a score (she wears the watch too rarely at night). Reset after each.

### Plan B (live demo fails)

- Relay or pairing stuck: show `docs/screenshots/watchlink-08…14` and the tour screenshots `tour-01…04`.
- Phone screens: `docs/screenshots/final/` (Report, Evidence with the appeal, Why, Share, partner checks).
- A second run of the relay after a rehearsal answers again (the relay forgets old ACKs when a new pairing or
  a new day is sent). If the watch was reset, also tap **Forget watch** twice on the phone, then pair again.

## B. HUAWEI Health integration path (DEMO data)

Huawei verifies an integration on a recording that has to show: the entry to the first authorization, the full
list of permissions as in the application, the app working after authorization, disconnecting, asking for
consent again, and the app working after that.

- FairWear does not read from HUAWEI Health in this build. The adapter is a stub; access to health data
  through Health Service Kit has to be granted to the app by Huawei.
- The HUAWEI Health authorization screen is not shown and not copied. In its place there is a neutral DEMO
  placeholder with two buttons that stand in for the user's answer.
- The consent logic is real: both steps are required, each data type can be switched off, and disconnecting
  takes the status back to "Not connected" (tests in `common/src/test/Health.test.ets`).

| #   | Screen           | What to do                                                                             | What to show                                                                                                       |
| --- | ---------------- | -------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| 1   | Welcome          | Start FairWear.                                                                        | "HUAWEI Health · Not connected", no tier; what is read, what is not, and what leaves the phone.                    |
| 2   | Connect          | Tap **Connect HUAWEI Health**.                                                         | The entry to the first authorization.                                                                              |
| 3   | Consent, step 1  | Read the list aloud, then tap **Simulate consent**.                                    | DEMO placeholder; the full list: steps, resting heart rate, sleep, activity minutes, VO₂max, HRV, workouts; 90 days. |
| 4   | Consent, step 2  | Optionally switch one data type off. Tick the box, tap **Agree and continue**.         | FairWear's own consent (GDPR Article 9), separate from step 1, with a switch per data type.                        |
| 5   | Report           | —                                                                                      | "HUAWEI Health · Demo data"; the report of the selected demo persona.                                              |
| 6   | Disconnect       | Settings (gear) › **Disconnect HUAWEI Health**.                                        | Status back to "Not connected"; the sentence about HUAWEI Health privacy settings.                                 |
| 7   | Connect again    | **Connect HUAWEI Health**, **Simulate consent**, tick the box, **Agree and continue**. | Consent is asked again from step 1; nothing is remembered from before.                                             |
| 8   | Report           | —                                                                                      | "Demo data" again.                                                                                                 |

Side path, refusal: on step 1 tap **Simulate refusal**. The status stays "Not connected" and the welcome
screen says what cannot be calculated without consent.

Screenshots `screenshots/addon-01…11` are from the run on 2026-10-04 00:10, before the scoring engine was in
the build; the screen after consent is now the Report tab.
