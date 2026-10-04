# Hackathon Agent Guide

## Mission

This repository is a starter for a time-boxed OpenHarmony/HarmonyOS/Oniro hackathon submission. Work like a productive hackathon teammate: follow the user's direction, keep changes focused and reproducible, and keep the project buildable throughout the event.

The submission must target HarmonyOS, OpenHarmony, or Oniro at API 20 or later. It must run on an emulator or compatible device, produce a working `.hap`, and visibly use or improve at least one platform, device, or system capability. The idea should clearly lead with one challenge theme: Intelligent Experiences, Spatial Experiences, or Human-Centric Technology.

Read [`hackathon-resources/README.md`](hackathon-resources/README.md) first. The challenge statement is not bundled in this checkout; treat the version published at https://github.com/onirodeveloper/hackyeah2026-challenge/blob/main/hackathon_challenge.md as the authoritative statement of requirements and fetch it from there. If a rule appears ambiguous or may have changed, ask the user to confirm it. The user can check current information or contact the organizers if needed.

## Non-Negotiable Submission Constraints

These constraints apply to the completed submission. Intermediate work does not need to address all of them at once. Do not block or expand the current task to resolve a submission constraint unless the requested work depends on it, violates it, or would make it materially harder to satisfy later.

- Target API 20 or later and declare API 20 as the minimum where applicable. Do not silently lower the target to make a build pass.
- Build a native ArkTS/ArkUI or C/C++ app, an OpenHarmony-compatible cross-platform app, or an installable system improvement. A web, Android, iOS, or desktop build alone does not qualify.
- Demonstrate at least one real platform capability. Clearly label mocked services and simulated sensor or device data.
- Keep setup, build, signing, installation, and launch steps reproducible from a clean checkout.
- Maintain a public-safe repository: never commit credentials, signing secrets, personal data, tokens, or private endpoints.
- Because an agent is being used, maintain the generated, public-safe `AI_WORKFLOW.md` as described below.
- Plan for every required artifact: source repository, instructions, `.hap`, short demo recording, architecture/implementation summary, `AI_WORKFLOW.md`, and extra AI integration documentation if AI is part of the product.

## Agent Working Rules

The user directs the project. Do not make product, scope, priority, UI/UX, visual design, navigation, architecture, demo, or release decisions unless the user explicitly delegates them. A request to implement a feature defines functionality; it does not authorize the agent to invent the app's UI.

When a decision is needed, ask the user before implementing it. Group related questions and present concise options where helpful. Follow existing specifications and established project patterns when they answer the question unambiguously. Routine, reversible coding details that do not affect design or behavior may be decided without asking.

Ask only about decisions needed to complete the current request. Do not require the user to resolve future features, submission positioning, challenge themes, platform integrations, demo strategy, or other later work. Leave those decisions open until the current task depends on them. Treat each request as incremental work, not as an instruction to complete or optimize the entire hackathon submission.

1. **Establish context.** Read the project instructions, `HACKATHON_BRIEF.md`, and `AI_WORKFLOW.md`, then inspect the repository and toolchain. Treat project documents as records of user-confirmed direction, not permission to fill in missing decisions.
2. **Stay within the request.** Implement the requested change without adding features, broad refactors, changing priorities, cutting scope, or substituting a different goal. If the requested approach is blocked, report the evidence and options to the user.
3. **Prefer command-line tooling.** Use the applicable skills, `devecocli`, `hdc`, and project commands for building, testing, installation, launch, logs, and screenshots. Avoid driving DevEco Studio through its graphical interface when a reliable command-line path exists.
4. **Leave complex emulator interaction to the user.** The agent may perform simple, deterministic actions such as launching the app, selecting one known control, or taking a screenshot. For multi-step journeys, substantial input, gestures, unexpected UI states, or subjective visual evaluation, give the user short test instructions and ask them to report the result. Perform more involved UI automation only when explicitly requested.
5. **Validate without overstating.** Run the relevant build, lint, and automated tests. When a target is available, install and launch the app and inspect relevant logs. Do not claim that a user journey was verified unless it was actually exercised by the agent within the limits above or confirmed by the user.
6. **Hand work back clearly.** Summarize what changed, what was validated, what remains unverified, and which decisions or manual steps belong to the user.

### Version Control

If the project uses git, work the way a hackathon teammate on a shared repo would:

- **Add a `.gitignore` if missing.** If the repository has no `.gitignore`, add one appropriate to the toolchain (build output, IDE/editor files, local config, SDK/DevEco caches, signing material, etc.) before the first commit that would otherwise pick up generated or machine-local files.
- **Commit often.** Commit after each small, working step rather than batching a day's work into one commit. Frequent commits make it easy to bisect a regression and cheap to roll back a bad experiment under time pressure.
- **Branch for new work.** Create a new branch for each feature, platform-capability integration, or risky experiment instead of committing directly to the main/demo branch. Keep the branch that judges will see buildable at all times; land finished, working slices into it rather than half-done work. Small, low-risk changes (typo fixes, README/docs tweaks, minor config adjustments) may be committed directly to main without asking.
- **Write descriptive commit messages.** State what changed and, when not obvious, why — future-you or a teammate should be able to scan `git log` and understand the project's progress without reading every diff.
- **Keep history public-safe.** Never commit credentials, signing secrets, personal data, tokens, or private endpoints, consistent with the Non-Negotiable Submission Constraints above. Check `git status`/`git diff` before committing, especially after a broad `git add`.
- **Leave merging to main to the user.** Once a feature branch's vertical slice is validated on the real target (see Agent Working Rules above), let the user know it's ready. Do not merge it into the main/demo branch yourself, and do not ask the user to merge — merging to main is the user's call to make and perform.
- **Delete the branch after merging, by default.** Once the user has merged the branch, remove it unless the user says to keep it.

If the project does not use git or version-control access is unavailable, skip this section and rely on the checkpoint discipline in the Agent Working Rules above.

## Tool Routing

Follow the Agent Working Rules above; do not use `conductor-dev` or initialize Conductor in this template. Use the appropriate implementation workflow:

- `ohos-app-scaffold` creates and initially verifies a new native application.
- `ohos-app-dev` develops, builds, deploys, debugs, and validates an ordinary application whose required APIs and permissions are public and available to ordinary apps.
- `ohos-system-app-dev` performs privilege preflight and develops a standalone app whose APIs or permissions may require `hos_system_app`, elevated APL, ACL/provisioning, a Full SDK system API, or system-app signing. Privileged inspection or control of other apps or protected device state is a clue to run this preflight, not proof that system identity is required.
- `ohos-system-dev` handles system or persistent bundles built inside an OpenHarmony source tree.
- `deveco-cli` provides DevEco documentation, build, device, emulator, logging, linting, and UI capabilities used by those workflows.

Do not classify an app solely because a feature is cross-app or device-wide. Confirm the exact target SDK's API annotations and permission definitions; public inter-application APIs remain ordinary-app work.

Follow the selected skill for command syntax, validation gates, retry behavior, and troubleshooting. Do not duplicate those mechanics here or invent platform APIs from memory. Before choosing device-dependent behavior, consult the bundled emulator capability guidance; hardware-dependent behavior requires a suitable device or a clearly disclosed simulation.

If an implementation tool is unavailable, report it and use only a fallback allowed by the selected skill. Do not install speculative replacements.

## AI Transparency

At the start of each AI-assisted session, read `AI_WORKFLOW.md` and register any newly used model, agent, MCP server, or Agent Skill before substantive work. Include its source or version when known and its role in the project.

Update the work log after a coherent piece of material work and before handover. Summarize important prompts or instructions, generated or changed work, human review and validation, consequential failures, limitations, and lessons learned. Do not log every routine command. Remove credentials, personal data, private endpoints, and confidential prompts before publication.

## Definition of Done for Each Change

- The smallest relevant build, lint, or test passes.
- Any complex user path required by the change was either confirmed by the user or clearly reported as unverified.
- Permissions, failure states, and logs were checked if the change touches a platform capability.
- README/setup/architecture notes reflect any changed command or design.
- `AI_WORKFLOW.md` records material AI-assisted work and how it was reviewed.
- No secret, generated build output, or unrelated change was added.

## Project state

Read this before relying on any earlier prompt or report. Check the repository, not a document, when the
two disagree.

**What is in the repository**

- Modules: `entry` (phone), `watch` (wearable), `common` (HAR, shared logic). Minimum API 20, target API 24.
  A second DevEco project, `healthsim/` (bundle `com.fairwear.healthsim`, modules `entry` for the phone and
  `watch`), builds Health Sim; the root project does not include it.
- Phone: the add-on flow (connect, two-step consent, disconnect), the home-screen card, one entry through
  `fwTarget`, device signing with HUKS and a software fallback.
- Watch Link: on-wrist recorder, signed day packets, chain verification on the phone, a development relay
  over `hdc`.
- Screens get the report through `entry/src/main/ets/report/ServiceLocator.ets`, the one place that chooses
  where reports come from. In use: the engine (`EngineReportService`, one `HesSession` per persona), with
  `closeSelectedDay()`, `resetSelected()`, `setSelectedLive(hr, steps)` and `selectedDayDetails()`.
- Phone after consent: tabs Report, Evidence, Share (`entry/src/main/ets/view/MainTabs.ets`). Built: the
  Report screen with the Live card and the demo controls, "Why this tier", the Evidence calendar with the
  day sheet and "Appeal this day", and "What left this phone" (`view/LedgerPage.ets`, linked from Share).
- Share and the partner view (`entry/src/main/ets/view/ShareView.ets`, `PartnerPage.ets`): the claim signed
  with the device key as a system `QRCode`, and the demo partner (`PartnerVerifier`) checking it, with
  "Verify the same code again" and "Change tier to A and verify" (B when the claim already says A). Pure logic: `common/src/main/ets/claim/ShareFlow.ets`.
  The one owner of the code, the partner and the ledger is `entry/src/main/ets/share/ShareService.ets`
  (`ledgerEntries()` is what the ledger screen reads; the file is `share/ledger.json` in the app sandbox).
  Without a score no code is signed; a score without eligibility is shared as "Eligible: no" and the reason
  never enters the claim.
- Claim: `TierClaim` with exactly seven keys (`v`, `period`, `tier`, `eligible`, `nonce`, `issuedAt`, `kid`).
- Scoring: HES vNext (the curves of HES-Lite v1.0, two profiles: health insurance and life insurance;
  `common/src/main/ets/hes/`), the six personas and the wear month
  (`common/src/main/ets/wear/`). The module was rebuilt from the written specification on the branch line
  `feature/hes-lite` → `feature/engine-reports`; the package `fairwear-ui` never arrived. Description and
  decisions: `docs/HES.md`.
- Report: the view models, the benefit rule and the report built from the engine
  (`common/src/main/ets/report/`: `ReportModels`, `Benefit`, `EngineReports`). The hand-written preview of the
  six personas is a test fixture (`common/src/test/fixtures/PreviewReports.ets`), not shipped. The claim
  verifier is `common/src/main/ets/claim/PartnerVerifier.ets`.
- Health Sim (`healthsim/`, its own DevEco project, bundle `com.fairwear.healthsim`): our simulator app that
  stands in for HUAWEI Health on the emulators, with the same six people and the banner "SIMULATED DATA". On
  the phone, **Connect HUAWEI Health** asks it for data with `startAbilityForResult`
  (`entry/src/main/ets/platform/HealthSimClient.ets`): Health Sim's own consent first, then FairWear's. On the
  watch, **Get today from Health Sim** fetches the script of the demo day. Without Health Sim FairWear uses its
  built-in demo data and says so. `common/src/test/HealthSimCopies.test.ets` keeps the copies under
  `healthsim/*/src/main/ets/fw/` identical to `common`. Build and install: `healthsim/README.md`.
- Tools: `tools/deploy.sh`, `tools/lint.sh`, `tools/run-logic-tests.sh`, `tools/check-wording.sh`,
  `tools/shot.sh`, `tools/watch-phone-relay.mjs` (the development relay that carries signed day packets between
  the two emulators over `hdc`). Results: `docs/test-results.txt`.
- Visits (`common/src/main/ets/visits/`, `entry/src/main/ets/visits/`, pages `Visits*`, `AddReceiptPage`):
  receipts checked against a demo register, visit notes taken from a demo transcript by fixed rules,
  follow-up adherence, and the `VisitClaim` (nine keys, token `fv1`) signed with the device key and checked by
  `VisitVerifier`. Demo data for Ewa only. A separate path: it does not touch `TierClaim`, `PartnerVerifier`
  or the score. Visit codes are not written to the ledger. Description: `docs/VISITS.md`.
- Day dial: `common/src/main/ets/present/DayDialModel.ets` and `view/DayDialCard.ets` on the Report tab. It
  reads the persona's starting history, not the running demo session.
- Watch: a second ability, `VisitRecordAbility` ("Visit notes"), records a visit after the doctor's consent
  into the watch sandbox; nothing is sent to the phone.
- Consent scopes: the data types switched on in FairWear's consent filter the starting history and every day
  "Close the day" adds, on the Health Sim path and on the built-in path (`engineSession(id, scopes)`,
  `EngineReportService.useScopes`, `healthsim/scopes.json` in the sandbox).

**What is NOT in the repository yet**

- Export and deletion of the data.
- The scoring module does not read HUAWEI Health and is not fed by the watch: it runs on the persona
  histories (from Health Sim when it is connected, otherwise the built-in ones). The document "Final report: HES-Lite v1.0 in FairWear" describes a target, not the state of
  this repository; check `docs/HES.md` and the code.

**Decisions in force** (the team keeps one plan, "FairWear: the single plan", which replaces every earlier
brief; its copy is `docs/prompts/00-FAIRWEAR_PLAN.md`, next to the other briefs, indexed in `docs/prompts/README.md`)

- The claim keeps its seven keys. Code that arrives with HES-Lite is adapted to the repository.
- One wear rule on the watch: `WearStateMachine`. A reading of 0 or outside 25–230 bpm is no reading (`common/src/main/ets/watchlink/WatchLinkTypes.ets`).
- Verified watch days are shown, not scored. Never write that the watch feeds the score.
- Rules and the score are deterministic and are never called AI.
- Logs carry counters only, never heart-rate or step values in public fields.
- Visit notes and receipt checks are deterministic rules and a demo register, and are never called AI.
  Emergency and inpatient visits are never shared with a partner; the rule is in `buildVisitClaim`.

**UI work**

- Read the project skill `.claude/skills/fairwear-ui/SKILL.md` first.
- Use the HarmonyOS skills from the challenge repository: `hmos-arkui-develop-skill`,
  `hmos-arkui-scenario-development`, `hmos-arkui-mvvm-pattern`, and `hmos-arkts-knowledge-retriever` for
  any API that is not certain. If they are not installed as agent skills, read them from a checkout of
  `onirodeveloper/hackyeah2026-challenge` (`skills/`).
- Do not use skills written for iOS or the web: `apple-design`, `write-swift`, `animate-expo`,
  `pick-ui-library`, `ask-sonner`, `emil-design-eng`.

**Working with several sessions**

- One session per branch. Check `git branch --show-current` before the first edit.
- Merging into `main` is done by a person.
