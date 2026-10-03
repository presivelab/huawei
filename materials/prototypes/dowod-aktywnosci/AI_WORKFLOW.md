# AI workflow

## Tools

- **Claude (Anthropic)** in the Claude app, used during the hackathon.
- *(Team: add any other tools you used, e.g. Copilot or ChatGPT.)*

## What AI was used for

1. **Idea review against the evaluation criteria.** Claude scored the initial concept against the jury criteria, checked prior art (Vitality programmes, including Huawei Health integrations), EU AI Act status for insurance pricing and GDPR constraints. Outcome: the pivot from "share health data for a discount" to "send a signed verdict, keep the data on the device".
2. **API research.** Claude read the OpenHarmony API declarations (`interface_sdk-js`) for HUKS, cryptoFramework, sensor and the `QRCode` component. This surfaced the 512-character `QRCode` limit, which shaped the token format.
3. **Code generation.** Claude produced the first version of the `entry` module: model, logic, platform wrappers, UI and tests.
4. **Verification performed on the AI output**
   - `model/` and `logic/` compiled with `tsc --strict` and run against 26 tests in Node (`tools/run-logic-tests.sh`).
   - `platform/` and the non-UI part of `pages/Index.ets` type-checked against the real SDK declaration files.
   - A negative check confirmed the type-check catches wrong API usage.
   - The ArkUI layout (`build()` and `@Builder` blocks) was **not** compiled by the AI — it was reviewed manually and compiled by the team in DevEco Studio.
   - A failing test (token 612 > 512 characters) led to a redesign of the payload schema before any UI work.

## What the team did

*(Fill in: integration in DevEco Studio, fixes after compilation, emulator/device runs, demo recording, pitch.)*

## AI in the product

None. Fraud detection and tiering are rule-based on purpose (explainability, AI Act, GDPR Art. 22).
