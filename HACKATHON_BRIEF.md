# Hackathon Brief

The user owns the decisions recorded here. Unresolved fields may remain blank; do not ask the user to complete them until the current work depends on them.

The first plan (`IMPLEMENTATION.md`, written with Claude on claude.ai) is not in this repository; the decisions it held that are still in force are written out below, and later team decisions replace it where they differ (the add-on for HUAWEI Health users, benefit levels instead of discount percentages, the seven-key claim, Watch Link). Where this brief and `hackathon_challenge.md` disagree, the challenge statement wins.

## Pitch

**User problem:** Programmes that reward regular activity and sleep (for example an insurer's) need wearable data they can trust, and users shouldn't have to hand over raw health data to get a benefit. Today both sides lose: people can game wear-based programs by taking the watch off on bad days, while honest users share far more than necessary. FairWear computes wear compliance and an explainable evidence tier on the device and gives the partner only a signed A/B/C tier, never raw heart-rate data.

**Desired demonstration:** A native ArkTS/ArkUI app in two modules. The watch (wearable emulator) records signed, hash-chained wear days. The phone (phone emulator) scores six synthetic demo personas with HES vNext (two profiles: health insurance and life insurance), detects selective non-wear, shows "Why this tier" and an Evidence calendar where a day can be appealed, and shares a signed A/B/C tier as a QR code that a demo partner verifies. Raw data never leaves the device. The full script is `docs/DEMO_SCRIPT.md`.

**Lead challenge theme:** Human-Centric Technology (responsible technology, digital wellbeing).

**Distinctive platform capability:** One capability end to end: the history (Health Sim in the place of HUAWEI Health on the emulators) → the score and the wear rules on the phone → a signed tier. The watch (Sensor Service Kit: heart rate, pedometer, wear detection) adds signed, hash-chained proofs of wear, which are shown and not counted into the score. HUKS (Universal Keystore Kit) is the trust link in that chain, not a separate feature: it keeps every signing key on its device. What it does not give the partner yet is proof that a key really is in a device's keystore: HUKS key attestation at enrolment is the next step (README, "What the signatures prove").

## Target

- Platform: HarmonyOS product. Kits imported: Ability, ArkData, ArkTS, ArkUI, Basic Services, Core File, Crypto Architecture, Form, Performance Analysis (logging), Sensor Service, Universal Keystore, and Wear Engine (send path in code, not run; HarmonyOS only). Not tested on Oniro; no such claim is made.
- API level: minimum (compatible) API 20 (`6.0.0(20)`), target API 24 (`6.1.1(24)`), built with the HarmonyOS 6.1.1 (API 24) SDK of DevEco Studio 6.1.1.280.
- Device type: phone (`entry` module) + wearable (`watch` module, round 466×466)
- Validation target: DevEco Studio emulators: Phone, HarmonyOS 6.1.1 (API 24); Wearable, HarmonyOS 6.1.1 (API 24), round 466×466.

## Intended user flow

The recorded demo follows `docs/DEMO_SCRIPT.md` (part A, about four minutes):

1. Phone: connect HUAWEI Health (labelled DEMO placeholder), FairWear's own consent with a switch per data type.
2. Phone, Report: persona Ania (labelled "Demo data") shows 92 · A, full benefit, 30 of 30 days worn.
3. Phone: Marek and Kasia wear the watch on the same 26 of 30 days; only Marek is flagged for selective non-wear (three suspicious breaks), so he gets no benefit this month; Kasia gets a partial benefit.
4. Phone, Evidence: the calendar of the month with the reason behind each day; "Appeal this day".
5. Phone, Why this tier: strongest factors, what to improve, missing data, the one change that reaches the next tier.
6. Phone, Report: the Live card and the demo controls ("Close the day" recalculates, "Reset demo").
7. Phone, Share: the partner side issues a single-use nonce (in the demo the partner verifier runs inside the same app), the phone signs the seven-key claim over it with its HUKS key and shows the token as a QR code, next to "What the partner sees". Every code shown is recorded with its exact text in "What left this phone". A persona without a score gets no code.
8. Phone, Partner view (demo): takes the code from the same phone (the emulator has no camera) and sees only tier, eligibility, period and the verification status. Verifying the same code again gives "Already used"; changing the tier gives "Invalid signature".
9. Watch → phone: a signed day from the watch is relayed to the phone and verified; a changed day is refused, a held-back day shows as missing.

**UI direction:** the project skill `.claude/skills/fairwear-ui/SKILL.md` holds the look and wording rules every screen follows.

## Acceptance checks

- [x] `entry` launches on the phone emulator and `watch` launches on the wearable emulator; both use the `common` module (`docs/test-results.txt`, `docs/screenshots/`).
- [x] On the wearable emulator, the watch shows heart rate, steps and wear state; without a heart-rate reading the wear state is unknown or off-wrist, never invented (`LiveWear.test.ets`, `WatchLinkFlow.test.ets`, `docs/screenshots/i3-watch-wear-state.jpeg`). Changing the heart rate in the emulator's Virtual sensor panel was not run.
- [x] Ania: A / 92, full benefit. Kasia: B / 71, partial benefit, no flag. Marek: B / 75, flagged for selective non-wear, not eligible, no benefit (`HesPersonas.test.ets`, `WearMonth.test.ets`, `EngineReports.test.ets`, `docs/screenshots/final/`).
- [x] A signed claim verifies in the partner view; a tampered payload, a reused nonce and an unknown key are rejected without a crash (`ClaimVerifier.test.ets`, `ShareFlow.test.ets`, `docs/screenshots/final/a4-partner-*`).
- [x] The pure-logic tests pass under Node (`tools/run-logic-tests.sh common` and `watch`; counts in `docs/test-results.txt`).

## Scope boundaries

- In scope: the `common` HAR (data contract, HES vNext and the six personas, wear month and the selective non-wear flag, report view models, claim codec and verifier, Watch Link logic of both sides), the phone screens, the watch screens with live sensors and the Watch Link recorder, tests, submission documents.
- Out of scope: reading real HUAWEI Health data (Health Service Kit needs Huawei's approval; the adapter is a stub); Wear Engine on paired devices (not run); a separate partner system; QR scanning with a camera; penalties of any kind (benefits only); an actuarial model; `conductor-dev`.
- Health Sim: our own simulator app (`healthsim/`) stands in for HUAWEI Health on the emulators. FairWear asks it for data with `startAbilityForResult` after its consent, on the phone (histories of the six people) and on the watch (the script of the demo day); without it FairWear uses its built-in demo data.
- Mocked or simulated behavior:

| Element                                   | Status                                                                                                 |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Heart rate and steps on the watch         | Real API (Sensor Service Kit); on the emulator the recorded days came from the labelled demo feed       |
| Wear state                                | Real `WEAR_DETECTION` API where available; on the emulator inferred from the heart-rate signal         |
| Score, wear rules, tier, benefit level    | Real code, computed on the device                                                                      |
| History on the phone                      | Synthetic, deterministic personas                                                                      |
| Watch-to-phone transfer                   | Signed day packets over a development relay (`hdc`); Wear Engine send path in code, not run            |
| Claim signature                           | Real ECDSA; key in HUKS, a software-key fallback labelled in the UI                                    |
| Partner                                   | A screen in the same app, not a separate system                                                        |
| Benefit levels                            | Illustrative: eligible and A is a full benefit, eligible and B a partial benefit, anything else none   |

## First-minute narrative

The opening of recording A in `docs/DEMO_SCRIPT.md`: the six people are synthetic demo personas; HUAWEI Health
is played by Health Sim, our own simulator app with the banner "SIMULATED DATA"; the watch days come from the
labelled demo feed because the emulator's heart rate is 0; watch to phone goes over a development relay on `hdc`
instead of Wear Engine; the score is deterministic rules and curves, not AI.
