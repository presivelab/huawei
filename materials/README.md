# HackYeah 2026 — Huawei task: working materials

Everything around the FairWear build that lived outside the repository, collected on 2026-10-04.
The app itself (`entry`, `watch`, `common`) is in the repository root; nothing here is built or imported by it.

| folder                         | what it is                                                                                                                                                               | copied from                 |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------- |
| `specs/`                       | The owner's pasted specifications, verbatim, in the order they arrived. `8-POPRAWKA_FINAL.md` wins over 1–7.                                                             | `C:\dev\fairwear-specs`     |
| `hes-documents/`               | HES / HES-Lite documents: the HUAWEI WATCH 5 audit v0.4, the hackathon spec v1.0, the "final report" PDF (a target description, not a record of work done in this repo). | Desktop                     |
| `incoming/`                    | `HealthSim.zip` as received and the Health Sim v2 audit paste. The unpacked project is on `feature/health-sim-audit` under `healthsim/`.                                 | `C:\dev\FairWear\_incoming` |
| `prototypes/dowod-aktywnosci/` | The first prototype (activity proof token, HUKS signing). Device signing in FairWear was ported from here.                                                               | Desktop                     |
| `prototypes/HealthDemo/`       | A look-alike watch health app with its research notes and screenshots. Paused: it came from a misreading of the brief.                                                   | `~/DevEcoStudioProjects`    |
| `prototypes/SensorProbe/`      | A minimal app that probes which sensors the wearable emulator exposes.                                                                                                   | `~/DevEcoStudioProjects`    |
| `session-reports/`             | End-of-session reports for the health-addon, watch-link and security-watch branches.                                                                                     | `docs/` of each worktree    |

Build output (`.hvigor/`, `build/`, `oh_modules/`) was left out. The DevEco Studio installer and SDK are not part of this repository.
