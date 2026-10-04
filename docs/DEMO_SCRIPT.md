# Demo script

Two recordings: **A**, the whole product in about four minutes, and **B**, the HUAWEI Health connect /
disconnect path that Huawei asks to see when it verifies an integration. Both run on the DevEco Studio
emulators (Phone and Wearable, HarmonyOS 6.1.1, API 24) with the unsigned debug HAPs from this repository.

Say once, at the start of A: the six people are synthetic demo personas; HUAWEI Health is played by Health Sim,
our own simulator app with the banner "SIMULATED DATA" (Health Service Kit access needs Huawei's approval); the watch days come from the
labelled demo feed because the emulator's heart rate is 0; watch → phone goes over a development relay on
`hdc` instead of Wear Engine (needs paired devices). The score is deterministic rules and curves, not AI.
Everything in the app was built during HackYeah 2026.

## A. The whole product (about 4 min)

### Before recording

1. Start both emulators, then `tools/deploy.sh watch` and `tools/deploy.sh entry`. Install Health Sim on
   both (`healthsim/README.md`: the `entry` HAP on the phone, the `watch` HAP on the watch). On the watch,
   check that FairWear is the app in front after the install: on this machine another prototype
   ("Health Demo") has come to the front more than once, and FairWear records only while it is open.
2. Pair: on the watch, page with **Pair phone** → `node tools/watch-phone-relay.mjs` → on the phone
   **Pair watch …?** → **Confirm** → relay again.
3. Watch: **Demo clock ×300**, then **Get today from Health Sim** (the page answers "Today from Health
   Sim · used by the demo feed"), then tap **Demo feed: off** (it then reads "Demo feed: on"), then **Close day (demo)** once, so
   every shown day starts at 00:00 (a day the feed starts at midday has no break with enough context). That
   first day stays in the list as "Not observed 24 h · The watch recorded nothing on this day". Let the watch
   seal four more days (one every 4 min 48 s) and relay them: Evidence › Watch days says "All … days
   verified". Leave the last sealed day unsent for step 3:15.
   Timing: days keep sealing while the demo clock runs. Start the recording at the moment the watch seals the
   day you leave unsent; the 3:05 step then falls between 3:00 and 4:48 after that seal, when the ring already
   shows the break and the watch still says "1 to sync". Earlier the ring has no break yet; later it says
   "2 to sync".
4. Phone: close FairWear and start it again, so the recording starts on the clean welcome screen: a fresh
   start is always "Not connected" with **Connect HUAWEI Health** (consent is not kept across restarts).
   After Settings › **Disconnect HUAWEI Health** in the same session the button reads **Reconnect** and the
   welcome screen shows "HUAWEI Health disconnected".
5. If you rehearsed: on each persona you touched, **Reset demo**. A used partner code is replaced by itself.

### Recording

| Time | Screen                        | Do                                                                                        | Show                                                                                                                                                                                   |
| ---- | ----------------------------- | ----------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 0:00 | Health Sim · Health           | start on Health Sim                                                                       | the banner "SIMULATED DATA · stands in for HUAWEI Health"; "Activity records" with the Steps and Exercise rings; one card per metric. Our simulator, laid out like a health app, not a HUAWEI app |
| 0:05 | Health Sim · Me               | tab **Me** → Connected apps → **Open FairWear**; if the system asks "Allow Health Sim to open FairWear?", **Allow** | the FairWear card: "Simulated integration point · real HUAWEI Health has no such card"; FairWear opens on its welcome screen: "HUAWEI Health · Not connected"; what is read, what never leaves the phone |
| 0:10 | Connect → Health Sim | **Connect HUAWEI Health**; if the system asks "Allow FairWear to open Health Sim?", **Allow**; in Health Sim **Allow** | Health Sim opens with the banner "SIMULATED DATA · stands in for HUAWEI Health" and its own consent (the first jump after an install may go straight to Health Sim, without the system's question): the full list of data types. It is our simulator, not a HUAWEI app |
| 0:20 | FairWear consent              | scroll down, tick the box, **Agree and continue** (leave the switches on)                        | FairWear's own consent (GDPR Art. 9), one switch per data type. Leave them on: with the HRV data type off Ania reads 93 · A, Evidence coverage 92.5% and the numbers below change                                                                                                                       |
| 0:30 | Report · Ania                 | —                                                                                         | 92 · A, Evidence coverage 100%, Data confidence High, "Full benefit · Eligible", 30 of 30 days, "Health Sim · Simulated data"                                                                          |
| 0:45 | Report · Marek, then Kasia    | persona chip → Marek, then Kasia                                                          | both 26 of 30 days; Marek 75 · B · 87.5% with "No benefit" and "3 suspicious breaks"; Kasia 73 · B · 75% with "Partial benefit": the same wear, a different pattern                                  |
| 1:05 | Evidence › Calendar · Marek   | persona chip → Marek, **Evidence**, tap Thu 17 Sep                                        | "Flagged" and the flag rule; "Off the wrist 13:05 for 5 h 35 min after resting HR +9 bpm and 46% fewer steps in the 24 h before"; **Appeal this day** → "Appeal sent", score unchanged |
| 1:30 | Why this tier · Tomek         | persona chip → Tomek, **Why this tier**                                                   | 79 · B, one point to A; Strongest / To improve / Missing data; the one change that reaches A; "How it's calculated"                                                                    |
| 1:50 | Report · Ewa, Live card       | persona chip → Ewa; move the heart-rate slider; **Close the day**; **Reset demo**         | the slider changes only the Live card ("Live · not scored"); Close the day: the toast "Day closed · HES 59 · Tier C", Ewa stays 59 · C; Reset: "Demo reset · HES 59 · Tier C"                                    |
| 2:10 | Share · Marek                 | persona chip → Marek, **Share**                                                           | QR code; "What the partner sees": "Eligible: no · 3 suspicious breaks. The reason stays on this phone."; "HUKS key" under the QR code; **Technical details**: Key ID, One-time number, Signed at                                         |
| 2:30 | Partner view · demo           | **Open partner view (demo)** → **Use the code from this phone**                           | "Signature valid", the checks in order, "The code does not say why."                                                                                                                   |
| 2:45 | Try to cheat                  | **Verify the same code again**; **Change tier to A and verify**                           | "Already used · stopped at: not used before"; "Invalid signature · stopped at: signature"; back on Share: "Used once · no longer valid"                                                |
| 2:55 | What left this phone          | Share › **What left this phone**                                                          | every code shown, with its exact text and size                                                                                                                                         |
| 3:05 | Watch dial                    | —                                                                                         | "FEED · Health Sim", the ring with charging, worn and the 12:00–15:00 break, "1 to sync"                                                                                                |
| 3:15 | Relay → Evidence › Watch days | `node tools/watch-phone-relay.mjs once --tamper`, then `node tools/watch-phone-relay.mjs` | the relay prints `REJECTED (Invalid signature)` and the day is not taken in; the clean run: the day verified with worn / charging / off-wrist time and its break ("Off wrist 12:05–15:00" or "12:10–15:00"). With two days waiting, the tamper run rejects the first and takes the second with "Missing 1 day(s)" until the clean run                     |
| 3:35 | How Watch Link works          | run the three checks                                                                      | "Invalid signature · Not taken in"; "Duplicate day"; "Accepted · Missing 1 day(s)", then "Fills the gap"; "Your stored days were not changed"                                          |
| 3:55 | Settings                      | **Disconnect HUAWEI Health**                                                              | back to "Not connected"; consent is asked again from step 1                                                                                                                            |

Consent switches, for a longer demo: with the HRV data type switched off in FairWear's consent, Ania reads 93 · A, Evidence
coverage 92.5%. This is the same on the Health Sim path ("Health Sim · Simulated data") and on the
built-in path ("HUAWEI Health · Demo data"). "Close the day" keeps the Evidence coverage at 92.5%: "Why this tier" lists
HRV under "Missing data" as "Not measured".

Optional beats (not timed):

- Profile switch. On Report or Why this tier, persona chip → Marek, switch **Health & wellness | Longevity**: Marek reads 76 · B · 77.5% · Medium in Longevity (75 · B · 87.5% · High in Health & wellness). The switch only explains: the shared tier, eligibility and the benefit do not change, and Share shows "Profile: Health & wellness (set by partner)".
- No score yet. Persona chip → Ola: "No score yet", Evidence coverage 47.5%, "Measured so far", "Needed for a score", "Optional, not yet"; Share gives no code.
- Health Sim readiness. In Health Sim, tab **Me** → developer tool **FairWear readiness**: eight rows (valid of minimum / target, Core or Optional, ready or not), coverage in both profiles and a preview of the score with the caption "Simulator check — FairWear computes the official result". The preview equals what FairWear shows for the same person.

Optional: Health Sim › any metric card opens that metric's last 30 days; the home-screen card (long-press the icon → Widgets: source, coverage and whether a score is ready,
never the tier); the icon shortcut "How Watch Link works"; `node tools/watch-phone-relay.mjs once --drop <seq>`
with the older of two unsent days as `<seq>` → "… of … days verified" and "1 day never reached this phone".

Close the day per persona, for a longer demo: Ania stays A; Marek stays flagged; Ewa stays 59 · C after one closed day; Ola does not reach a score with
seven closed days (coverage 55%), the eighth gives her first score, 84 · A · 82.5% · Medium. Reset after each.

### Plan B (live demo fails)

- Health Sim is not installed, or does not answer: nothing breaks. On the phone the Connect page says
  "Health Sim is not installed: built-in demo data" and offers the labelled demo placeholder (**Simulate
  consent**); the Report then reads "HUAWEI Health · Demo data" with the same six results (and, with HRV
  switched off in the consent, the same 93 · A and 92.5% for Ania). Start the recording on FairWear's welcome
  screen instead of Health Sim. On the watch the
  button answers "Health Sim not on this watch · built-in script" and the dial reads "DEMO ×300 · FEED".
  The rest of the script is the same. If the system's question "Allow FairWear to open Health Sim?" was
  cancelled, the page offers **Ask Health Sim again** and **Continue with built-in demo data**.
- Relay or pairing stuck: show `docs/screenshots/watchlink-08…14` and the tour screenshots `tour-01…04`.
- Phone screens: `docs/screenshots/final/` (Report, Evidence with the appeal, Why, Share, partner checks).
- A second run of the relay after a rehearsal answers again (the relay forgets old ACKs when a new pairing or
  a new day is sent). If the watch was reset, also tap **Forget watch** twice on the phone, then pair again.
- The relay prints `REJECTED (Invalid format)` for a packet nobody changed: the phone looked into its inbox
  while the file was still arriving. The app now leaves such a file for its next look
  (`docs/WATCH_LINK.md`, Known limitations), so this should not happen any more; if it does, run the relay
  once more for a day, and for a pairing request tap **Pair phone** on the watch again and run the relay.
- The watch shows another app or the watch face: FairWear records only while it is open. Start it again
  from the app list and check that the dial says "FEED · Health Sim" (or "DEMO ×300 · FEED" on the built-in script) before the 3:05 step. A day recorded
  across such a pause has "Not observed" time and may have no break.

## B. HUAWEI Health integration path (DEMO data)

Huawei verifies an integration on a recording that has to show: the entry to the first authorization, the full
list of permissions as in the application, the app working after authorization, disconnecting, asking for
consent again, and the app working after that.

- FairWear does not read from HUAWEI Health in this build. The adapter is a stub; access to health data
  through Health Service Kit has to be granted to the app by Huawei.
- The HUAWEI Health authorization screen is not shown and not copied. In its place Health Sim, our own
  simulator app, shows its own consent screen (**Allow** / **Don't allow**) and hands the data over with
  `startAbilityForResult`. Without Health Sim a neutral DEMO placeholder with two buttons stands in.
- The consent logic is real: both steps are required, each data type can be switched off, and disconnecting
  takes the status back to "Not connected" (tests in `common/src/test/Health.test.ets`).

| #   | Screen          | What to do                                                                             | What to show                                                                                                         |
| --- | --------------- | -------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| 1   | Welcome         | Start FairWear.                                                                        | "HUAWEI Health · Not connected", no tier; what is read, what is not, and what leaves the phone.                      |
| 2   | Connect         | Tap **Connect HUAWEI Health**. | The entry to the first authorization: Health Sim opens (the system may first ask "Allow FairWear to open Health Sim?"). |
| 3   | Consent, step 1 | In Health Sim read the list aloud, then tap **Allow**. | Health Sim's consent, banner "SIMULATED DATA"; the full list: steps, resting heart rate, sleep, exercise, VO₂max, heart rate variability, workouts. |
| 4   | Consent, step 2 | Optionally switch one data type off. Tick the box, tap **Agree and continue**.         | FairWear's own consent (GDPR Article 9), separate from step 1, with a switch per data type.                          |
| 5   | Report           | —                                                                                      | "Health Sim · Simulated data"; the report of the selected demo persona. |
| 6   | Disconnect      | Settings (gear) › **Disconnect HUAWEI Health**.                                        | Status back to "Not connected"; the sentence about HUAWEI Health privacy settings.                                   |
| 7   | Connect again   | **Reconnect** (the button's label after a disconnect), **Allow** in Health Sim, tick the box, **Agree and continue**. | Consent is asked again from step 1; nothing is remembered from before: the data Health Sim sent was removed on Disconnect. |
| 8   | Report          | — | "Health Sim · Simulated data" again. |

Side path, refusal: on step 1 tap **Don't allow** in Health Sim. The status stays "Not connected" and the welcome
screen says what cannot be calculated without consent.

Screenshots `screenshots/addon-01…11` are from the run on 2026-10-04 00:10, before the scoring engine was in
the build; the screen after consent is now the Report tab.
