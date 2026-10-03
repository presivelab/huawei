# AI Workflow

This project uses AI-assisted development. Keep this document current and public-safe. Do not include credentials, tokens, personal data, private endpoints, or confidential prompts.

## Tools used

| Model, agent, MCP server, or Agent Skill                                        | Version or source                                                         | Role in the project                                                                       |
| ------------------------------------------------------------------------------- | ------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| Claude Code (coding agent) with Claude Opus 5.5 (`claude-opus-5-5`, 1M context) | Claude Code VS Code extension 2.1.288, Anthropic                          | Environment checks, project documents, implementation, build and emulator runs, debugging |
| Claude (claude.ai) with Claude Opus 5.5                                         | claude.ai, Anthropic                                                      | Research, evaluation of the idea, the `IMPLEMENTATION.md` plan                            |
| Hackathon agent skills from the installer                                       | [versions to be added after the installer runs]                           | [to be added after the installer runs]                                                    |
| `devecocli` (`@deveco/deveco-cli`)                                              | 1.3.4, pinned by the installer [to be confirmed after the installer runs] | [to be added after the installer runs]                                                    |

## Important prompts and instructions

- `AGENTS.md` — repository-wide hackathon constraints and working agreement.
- `IMPLEMENTATION.md` — the team's implementation plan, written with Claude (claude.ai) and used as the standing instruction for the coding agent: ArkTS rules, data contract, steps K0–K9, approved UI direction (sections 12–13), tests, and the list of what is real and what is simulated.
- [Summarize the important project prompt or reusable instruction. Include the full public-safe text when practical.]

## AI-assisted work log

| Date       | Tool/model                               | Request or task                                                                                                                                                                                                                                                                                                                                                                                                          | Generated or changed                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | Human review and validation                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| ---------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-10-03 | Claude Code / Claude Opus 5.5            | Fill in `HACKATHON_BRIEF.md` from the plan; write the data contract from section 3 of the plan                                                                                                                                                                                                                                                                                                                           | `HACKATHON_BRIEF.md`, `common/src/main/ets/model/types.ets`, `common/src/main/ets/model/defaults.ets`                                                                                                                                                                                                                                                                                                                                                                                                                                        | A team member read both, approved `types.ets` with two changes (English comments, defaults in a separate file) and supplied the "User problem" and "First-minute narrative" text. Not compiled yet.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| 2026-10-04 | Claude Code / Claude Opus 5.5 (subagent) | Change of direction written by the team: FairWear as an add-on for HUAWEI Health users. Two agents worked in one worktree. Part 1: the health source layer, the phone add-on screens (connect, two-step consent, data source, disconnect) and a Node runner for the logic tests. Part 2: `LiveWearState` (wear state from raw heart-rate readings) and the watch live screen with heart rate, steps today and wear state | `common/src/main/ets/live/`, `common/src/test/LiveWear.test.ets`, `watch/src/main/ets/` (live screen, sensors, daily step counter), `watch/src/test/DaySteps.test.ets`, `common/src/main/ets/health/`, `common/src/test/Health.test.ets`, `entry/src/main/ets/addon/`, `entry/src/main/ets/view/`, `entry/src/main/ets/pages/Index.ets`, `entry/src/main/ets/platform/HuaweiHealthSource.ets` (stub), `tools/run-logic-tests.sh`, `tools/logic-tests/`, `tools/check-wording.sh`, `README.md`, `docs/ARCHITECTURE.md`, `docs/DEMO_SCRIPT.md` | Checked by the agents: Node tests (14 health, 6 wear state, 6 daily steps), text check with 0 hits, ArkTS build of `common`, `entry` and `watch`, the connect / refuse / consent / disconnect / reconnect path on the phone emulator with screenshots, the watch screen and both permission dialogs on the wearable emulator with screenshots (`docs/test-results.txt`). Not checked: any connection to HUAWEI Health (the adapter is a stub); a real heart rate (the emulator sent only 0); the 70 -> 0 -> 70 change in the emulator's Virtual sensor panel; dark mode; DevEco Local Test. No code was copied from the HMOS Code Workshop samples. Not yet reviewed by a team member. |

## Workflow

### Ideation and architecture

[Describe how AI influenced the product idea, scope, architecture, and platform-capability choice.]

### Implementation

[Describe the AI-assisted coding workflow and how generated output was reviewed before acceptance.]

### Testing and debugging

[Record builds, linting, tests, device/emulator runs, UI inspection, logs, screenshots, and manual checks.]

## Unsuccessful approaches

- [What was tried, why it failed, and what changed afterward.]

## Known limitations

- [Product, platform, model, data, testing, or tooling limitation.]

## Lessons learned

- [Concise lesson that would help reproduce or improve the work.]

## AI feature disclosure

Complete this section only if AI is part of the product itself; otherwise write "Not applicable."

- Model or service: [Name/version/provider]
- Inference flow: [On-device, remote, or hybrid; inputs and outputs]
- Data handling and privacy: [What leaves the device, retention, consent, and safeguards]
- Failure and fallback behavior: [How errors, latency, offline use, and unsafe output are handled]
- Evaluation: [Test cases, quality measures, human review, and known model limitations]
