# Hackathon Brief

The user owns the decisions recorded here. Unresolved fields may remain blank; do not ask the user to complete them until the current work depends on them.

Source of the decisions below: `IMPLEMENTATION.md` in the project root. Where this brief and `hackathon_challenge.md` disagree, the challenge statement wins.

## Pitch

**User problem:** Insurers that reward healthy habits need wearable data they can trust, and users shouldn't have to hand over raw health data to get a discount. Today both sides lose: people can game wear-based programs by taking the watch off on bad days, while honest users share far more than necessary. FairWear computes wear compliance and an explainable health tier on the device and gives the insurer only a signed A/B/C tier, never raw heart-rate data.

**Desired demonstration:** A native ArkTS/ArkUI app in two modules. The watch (wearable emulator) turns simulated heart rate and step count into today's wear compliance. The phone (phone emulator) shows 90 days of history, detects selective non-wear, computes a tier A/B/C, and produces a package for the insurer signed with a HUKS key. Raw data never leaves the device.

**Lead challenge theme:** Human-Centric Technology (responsible technology, digital wellbeing). Secondary: Intelligent Experiences (AI-written explanations of the result).

**Distinctive platform capability:** One capability end to end: watch sensors (Sensor Service Kit: heart rate, pedometer, wear detection) → on-device compliance engine → signed tier. HUKS (Universal Keystore Kit) is the trust link in that same chain, not a separate feature. Only kits available in OpenHarmony are used.

## Target

- Platform: HarmonyOS product, built only on kits that exist in OpenHarmony (Sensor, Universal Keystore, Crypto Architecture, Network, Ability, Basic Services, ArkData, ArkUI, Form). Not tested on Oniro; no such claim is made.
- API level: minimum (compatible) API 20, compile API 23, target API 24
- Device type: phone (`entry` module) + wearable (`watch` module, round 466×466)
- Validation target: DevEco Studio emulators, one Phone and one Wearable, newest available image. Emulator names and image versions: [to be filled in once the virtual devices are created]

## Intended user flow

Demo flow from `IMPLEMENTATION.md`. It is fixed; optional extras must not change it.

1. Watch, wearable emulator: set heart rate and steps in the emulator's sensor simulation panel; the app reacts live.
2. Watch: stop the heart-rate signal; after 60 s the wear-state dot turns red and the hours-worn counter stops.
3. Phone, Consent: "Raw data never leaves your device", checkbox, Continue.
4. Phone, Dashboard: persona Ania (labelled "Synthetic data") shows Tier A and a 15% discount with the wear-compliance ring.
5. Phone: switch between Marek and Kasia. Both have about 87% wear compliance; only Marek is flagged for selective non-wear and gets 0%.
6. Phone, Why and Wear calendar: factors with points, and the suspicious gaps in red with their explanation.
7. Phone, Share: fetch a nonce, build and sign the claim, show the JSON, the shortened signature and the HUKS/SOFTWARE key badge.
8. Phone, Insurer view: sees only tier, compliance %, eligibility, period and verification status. "Tamper payload" turns the result into INVALID SIGNATURE.
9. Phone, Settings: the `minDailyHours` and `minMonthlyPct` sliders recalculate the result live.

**Approved UI direction:** sections 12 (phone UI, `entry`) and 13 (watch UI, `watch`) of `IMPLEMENTATION.md` are the UI direction approved by the team. Implement screens from those sections without asking about each screen; ask only where they leave a decision open.

## Acceptance checks

- [ ] `entry` launches on the phone emulator and `watch` launches on the wearable emulator; both use the `common` module.
- [ ] On the wearable emulator, changing simulated heart rate and steps changes the watch screen; 60 s without a heart-rate reading switches the wear state to not worn.
- [ ] Ania: Tier A, 15%. Kasia: Tier B, 8%, no flag. Marek: flagged for selective non-wear, not eligible, 0%.
- [ ] A signed claim verifies in the Insurer view; a tampered payload, a reused nonce and a malformed key are rejected without a crash.
- [ ] The explanation falls back to the deterministic template on invalid model output, timeout or no network, and the UI labels the source.
- [ ] Hypium tests from section 14 of `IMPLEMENTATION.md` pass.

## Scope boundaries

- In scope: steps K0–K9 of `IMPLEMENTATION.md` — `common` HAR (data contract, synthetic generator, day aggregation, wear compliance, selective non-wear detector, risk scorer, discount policy, report builder, HUKS/software attestor, claim verifier, explanation service), phone UI, watch UI with live sensors, tests, submission documents. Optional extras K11–K17 only after the K4–K5 tests are green and only until the feature freeze.
- Out of scope: watch-to-phone synchronisation (emulators have no distributed features); HarmonyOS-only kits (Scan Kit, Health Service Kit, Live View); a separate insurer system; QR scanning with a camera; penalties of any kind (discount only); an actuarial model; `conductor-dev`.
- Mocked or simulated behavior:

| Element                                     | Status                                                                                         |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| Heart rate and steps on the watch           | Real API (Sensor Service Kit); values come from the emulator's sensor simulation               |
| Wear state                                  | Real `WEAR_DETECTION` API where available; on the emulator inferred from the heart-rate signal |
| Compliance engine, detector, tier, discount | Real code, computed on the device                                                              |
| 90 days of history on the phone             | Synthetic, deterministic personas                                                              |
| Watch-to-phone synchronisation              | Not on the emulator (no distributed features); described in ARCHITECTURE                       |
| Claim signature                             | Real ECDSA; key in HUKS or a software key, labelled in the UI                                  |
| Insurer                                     | A screen in the same app, not a separate system                                                |
| AI summary                                  | Real model call on aggregates only; template on failure                                        |
| Discount amounts                            | Illustrative, not actuarial                                                                    |

## First-minute narrative

- **0:00–0:15** Watch emulator: we set heart rate in the emulator's sensor panel; the live HR and today's wear ring react. When the HR signal stops, the watch is marked off-wrist after 60 s.
- **0:15–0:30** Phone: Ania, 30 days computed on-device, ~94% wear compliance, Tier A, 15% discount; "Why?" shows the four factors.
- **0:30–0:50** Marek vs Kasia: both ~87% compliance. Marek took the watch off right after days of elevated resting heart rate, so no discount this month; Kasia simply forgot it, so Tier B, 8%.
- **0:50–1:10** Share with insurer: claim signed with a HUKS key; the insurer sees only tier, compliance and "signature OK". Tampering C→A gives INVALID SIGNATURE.
- **1:10–1:20** Raw data never left the device; what is real vs simulated.

The compliance figures above (~94%, ~87%) are targets until step K4 is done. After K4 they are replaced with the values the engine actually computes. If Marek and Kasia do not come out with similar compliance, the persona parameters (section 4 of `IMPLEMENTATION.md`) are tuned, not this narrative.
