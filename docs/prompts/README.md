# Prompts: the team's briefs

These are the briefs a team member handed to coding-agent sessions as their standing instructions during
HackYeah 2026 (3–4 October 2026). They are kept as written, in Polish, so that `AI_WORKFLOW.md` can point to
the full text. Each file starts with one added line saying it is a public-safe copy; apart from that only a leftover paste marker was removed from `3` and `4`.
They contain no credentials, e-mail addresses or user names; the paths in them (`C:\dev\…`) are the
development machine's working folders.

A brief describes what was asked at the time, not the state of the code. Where a brief and the repository
disagree, the repository and `docs/` are right. The decisions still in force are written out in
`HACKATHON_BRIEF.md` and `AGENTS.md` ("Decisions in force").

| File | What it asked for | File saved (CEST) | Status |
| --- | --- | --- | --- |
| `1-POPRAWKA_HUAWEI_HEALTH.md` | Change of direction: FairWear as an add-on for HUAWEI Health users; the list of wordings never to use | 3 Oct 23:56 | archived, replaced by `00` |
| `2-DODATEK_DECYZJE_I_EKRANY.md` | Decisions and screens of the add-on (connect, two-step consent, data source, disconnect) | 3 Oct 23:56 | archived, replaced by `00` |
| `3-ZEGAREK_HH_tylko_reguly.md` | The watch records data the way HUAWEI Health does; the same data on both emulators | 3 Oct 23:56 | archived, replaced by `00` |
| `4-MOCKUP_HH_zastapiona.md` | A mock "HUAWEI Health" data source | 3 Oct 23:56 | archived (its name marks it replaced); the role went to Health Sim (`healthsim/`) |
| `5-TA_B_CODE_WORKSHOP_COMPLIANCE.md` | Phone patterns from HMOS Code Workshop (card, shortcut, one entry point) and a check against the challenge rules | 4 Oct 00:02 | archived, replaced by `00` |
| `6-INTEGRACJA_HES_I_ODDANIE.md` | Merge of the branches, HES-Lite, the watch per the HES-Lite report, submission | 4 Oct 00:35 | archived, replaced by `00` |
| `7-WYGLAD_NATYWNY_HARMONYOS.md` | Native HarmonyOS look for the phone, the watch and the card | 4 Oct 00:47 | archived, replaced by `00` |
| `8-POPRAWKA_FINAL.md` | One version of the truth: claim with seven keys, one wear rule, merge order | 4 Oct 01:03 | archived, folded into `00` |
| `9-SECURITY.md` | Security hygiene and the trust model (blocks S0–S4, tests S-1…S-20) | 4 Oct 01:04 | archived, folded into `00` |
| `10-AUDYT_SKILLE_UI_SUKCES.md` | Audit of the agent skills, the stack and the UI | 4 Oct 01:24 | archived, replaced by `00` |
| `00-FAIRWEAR_PLAN.md` | The single plan: repository state, binding decisions, phased tasks with gates, demo script, security tests | 4 Oct 01:33 | the plan the later briefs build on |
| `11-DANE_WYMAGANIA_BRAKI.md` | Data: what is collected, what the score needs, what is missing | 4 Oct 02:01 | complements `00` |
| `12-TELEFON_RAPORT_UI.md` | Phone report: what goes where on the screens and how to build it natively | 4 Oct 02:18 | complements `00` |
| `13-MOCK_TELEFON_ARKUI.md` | Phone screens from the design canvas as working ArkUI on the emulator | 4 Oct 02:27 | complements `00` |
| `14-TEKSTY_UI_DO_ZASOBOW.md` | UI texts of `entry`, `watch` and the card moved into string resources (`$r`), English unchanged; sentences built in `common` left for a second step | 4 Oct 08:10 | prepared by Claude in the review session, not run yet |

Not in this folder:

- `IMPLEMENTATION.md`, the first plan written with Claude (claude.ai) on 3 October. The decisions from it that
  are still in force are in `HACKATHON_BRIEF.md`.
- The Watch Link brief, the four briefs of the last night (engine, screens, watch, share) and the Health Sim
  round: they were pasted into the sessions from claude.ai conversations and not saved as files. What each
  of them asked for and what came out of it is in the work log of `AI_WORKFLOW.md` and in `docs/WATCH_LINK.md`.
- The HES-Lite specification documents. The score's specification as built is `docs/HES.md`.
- The design canvas pages (`mock-telefon/*.html`) that `13` refers to.

`tools/check-wording.sh` does not search this folder: the briefs quote the forbidden wordings in their
"never say" lists.
