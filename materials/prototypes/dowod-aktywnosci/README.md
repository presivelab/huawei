# Dowód aktywności — proof of healthy habits without giving away health data

An OpenHarmony app (ArkTS) that lets a policyholder earn an insurance discount for being active **without sending raw health data to the insurer**. The phone evaluates 28 days of activity locally, runs anti-fraud checks, and signs a small result with a hardware-backed key (HUKS). The insurer receives only the signed verdict (~370 characters, fits a QR code) and verifies it with standard ECDSA.

Challenge areas: **Human-Centric Technology** (privacy by design, fairness rules, human review) and **Intelligent Experiences** (on-device evaluation and fraud detection).

## Problem

Activity-linked insurance programmes already exist (e.g. Vitality), but they pull workout data from the wearable's cloud into the insurer's platform. Users trade sensitive health data for a discount, and insurers inherit GDPR Art. 9 data they do not need. Our solution sends the insurer a verifiable *answer* instead of the data.

## How it works

```
 Sensors (@ohos.sensor)          Synthetic 56-day history
 pedometer · heart rate · wear   (same shape as daily sensor aggregates)
            │                                │
            └──────────────┬─────────────────┘
                           ▼
        On-device evaluation (logic/Evaluator)          ← stays on the phone
        · 4 weeks vs WHO goal (150 active min) or +10% vs own baseline
        · 3 of 4 weeks = Gold (one sick week is tolerated)
        · anomaly rules (logic/AnomalyDetector)
                           ▼
        Payload: 13–15 fields, no daily values (only period start)
                           ▼
        Sign: ECDSA P-256 / SHA-256 with key in HUKS    ← private key never leaves keystore
                           ▼
        Token  PA1.<base64url payload>.<base64url signature>  →  QRCode
                           ▼
 Insurer: registered public key (kid) · signature · nonce · freshness · period
        → status OK: example discount by insurer's price list
        → status REVIEW: human underwriter decides, decision log
```

## Use of platform capabilities

| Capability | Where | Why |
|---|---|---|
| **Universal Keystore Kit (HUKS)** — ECC P-256 key generation, sign session, public key export, `anonAttestKeyItem` | `platform/ProofSigner.ets` | The report is unforgeable; the private key is hardware-protected. A self-test verifies the HUKS signature with standard ECDSA before the key is used. |
| **Crypto Architecture Kit** — `createVerify('ECC256\|SHA256')`, `createMd`, `createRandom` | `platform/CryptoUtil.ets` | Insurer-side verification, key id, nonce from a CSPRNG. |
| **Sensor Service Kit** — `PEDOMETER`, `HEART_RATE`, `WEAR_DETECTION` | `platform/SensorSource.ets` | Live plausibility check: walking cadence vs. heart-rate rise, steps while the watch is off. |
| **Ability Kit** — `abilityAccessCtrl.requestPermissionsFromUser` | `platform/Permissions.ets` | Each in-app consent maps to a system permission (`ACTIVITY_MOTION`, `READ_HEALTH_DATA`). |
| **ArkUI** — `Tabs`, `Toggle`, `QRCode`, state management | `pages/Index.ets` | Five-tab flow: consents → weeks → checks → report → insurer. |

## Anti-fraud rules (explainable by design)

| Code | Rule | Severity |
|---|---|---|
| `IMPV` | Values outside physiological range | High → human review |
| `SWNW` | More than 150 steps per minute of wear time (steps while the watch is off) | High → human review |
| `SWHR` | ≥15,000 steps while active heart rate is <15 bpm above resting (needs HR consent) | High → human review |
| `NWRN` | Watch worn <10 h | Low → day skipped, no penalty |

No ML model is used for decisions. This is deliberate: risk assessment and pricing in life and health insurance is a high-risk use case under the EU AI Act (Annex III, 5(c)); rules are testable and can be explained to the customer (GDPR Art. 22). The MVP targets accident insurance (NNW).

## Privacy and fairness choices

- Raw data never leaves the device; the payload contains counts and codes only.
- Menstrual cycle and GPS routes are **not collected** (shown greyed out in the UI): sex-based pricing is not allowed in the EU, and location is unnecessary.
- Discounts only, never surcharges. Goals relative to one's own baseline, not a fixed step count.
- Without heart-rate consent, fraud cannot be fully excluded, so the maximum tier is Silver (shown to the user).
- Suspicious weeks go to a human, not to an automatic rejection. Every decision is logged.
- A nonce from the insurer's request prevents replaying an old report; reports expire after 24 h.

## Token format (v1)

`PA1.<base64url(JSON)>.<base64url(DER signature)>`. The public key is registered once (`kid` = first 4 bytes of SHA-256 of the key), so the token stays under the 512-character limit of the ArkUI `QRCode` component. Field list: see the header of `logic/ProofToken.ets`.

## Build and run

Requirements: DevEco Studio with an OpenHarmony / HarmonyOS SDK, **API 12+**.

1. Create an *Empty Ability* ArkTS project, copy `entry/src/main/ets/{model,logic,platform,pages}` into it.
2. Add the permissions block from `config/module.json5.requestPermissions.txt` to `entry/src/main/module.json5` and the strings from `config/string.json.entries.txt`.
3. Enable automatic signing (File → Project Structure → Signing Configs) and run on the emulator.
4. `.hap`: Build → Build Hap(s)/APP(s) → Build Hap(s).

On the emulator, sensors are usually absent: the *Kontrola* tab says so and offers simulation buttons that feed the same live detector. HUKS attestation needs network access and device support; when unavailable the UI says so, and if HUKS itself is unavailable a software key is used and clearly labelled.

## Tests

- DevEco: right-click `entry/src/test` → *Run 'Local Test'*.
- Without DevEco: `./tools/run-logic-tests.sh` compiles `model/` and `logic/` with `tsc --strict` and runs the same Hypium test file in Node (26 tests).

## What is simulated

| Part | Status |
|---|---|
| Evaluation, fraud rules, tiers, token, signature, verification | Real code |
| 56-day history | Synthetic personas (deterministic) in the shape of daily sensor aggregates |
| Live sensors | Real `@ohos.sensor`; simulation on the emulator |
| Insurer | Same app, separate tab |
| HUAWEI Health data | Not used (Health Service Kit requires a vendor review) |

## AI usage

See [AI_WORKFLOW.md](AI_WORKFLOW.md). The product itself contains no AI model.
