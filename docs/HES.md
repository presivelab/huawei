# HES vNext in FairWear

HES (Health Engagement Score) turns a history of completed days into one integer score from 0 to 100, a tier
A / B / C, an Evidence Coverage percentage and a Data Confidence label. It is deterministic rules and curves:
no learned model, no network, no clock. It is not AI / ML. A missing measurement is never guessed and never
counted as zero, and the running day never enters the score before it is closed.

HES vNext replaces HES-Lite v1.0. The specification it was built from is kept one to one in
`docs/HES_VNEXT_SPEC.md`; this document says how the repository reads it. There is one engine, in the `common`
module, and both apps use it: FairWear on the phone calculates the score, Health Sim (the simulator that stands
in for HUAWEI Health) previews it with the same code. The watch does not calculate it.

All weights, curves, thresholds, windows and minimum counts are research-informed product assumptions, not
clinically or actuarially validated coefficients. Future validation must use real cohort/outcome data.

## Where what runs

| Where           | Role                                                                                                                                                    |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `common`        | the engine and the persona generator: the only place a weight, a curve point or a threshold is written                                                  |
| Health Sim      | holds and shows the raw data the score needs; after consent hands it to FairWear (contract version 2); its "FairWear readiness" tool previews the score |
| FairWear, phone | calculates HES from the data Health Sim sent (or from the built-in personas) and shows it                                                               |
| FairWear, watch | shows live readings with the label "Live · not scored". It never calculates HES: the watch measures, the phone judges                                   |

`tools/check-single-engine.sh` fails when a weight table, a curve point or a piecewise function turns up
outside `common/src/main/ets/hes`, or when Health Sim carries copied sources again.

## Files and specification sections

| File (`common/src/main/ets/hes/`) | Specification | What it holds                                                                                                                         |
| --------------------------------- | ------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `HesTypes.ets`                    | 15            | the enums (`HesProfile`, `ComponentId`, `HesTier`, `HesConfidence`, `HesStatus`), the input records, `ComponentResult`, `HesResult`   |
| `HesModel.ets`                    | 1, 2, 3, 5    | every number of the model: the two weight tables in thousandths, Core flags, minimum and target counts, windows, the eight curves     |
| `HesCurves.ets`                   | 5             | `piecewise(points, x)`: straight lines between points, the end scores beyond the ends, clamped to 0..100, no score for a non-finite x |
| `HesAggregate.ets`                | 3, 4          | which reading is valid, the calendar windows, one raw value and a valid count per component                                           |
| `HesEngine.ets`                   | 6 – 11        | `computeHes(profile, history)`: components, Core check, renormalization, effective weights, confidence, tier                          |
| `HesExplain.ets`                  | 13, 14        | strongest, to improve, missing optional, missing Core, points to the next tier                                                        |
| `HesFormat.ets`                   | —             | numbers as text for both apps: "87.5%", "18.8%", "7 h 24 min", "6 of 14 nights"                                                       |
| `HesSession.ets`                  | 12            | live values (never scored), close the day, reset                                                                                      |
| `HesPersonas.ets`                 | —             | the six demo personas as a recipe without random numbers                                                                              |
| `HesPrng.ets`                     | —             | a seeded generator, used only by the wear calendar (`wear/WearPersonas.ets`)                                                          |

Next to it: `report/PartnerProgram.ets` (the partner's profile), `report/EngineReports.ets` (the phone's view
model), `health/HealthSimPayload.ets` (the contract with Health Sim), `health/HealthSimReadiness.ets` (what
Health Sim's Scenario tool shows).

## Profiles and weights

Two weight profiles over the same eight components and the same curves. Weights are held in thousandths
(whole numbers), so coverage is exact: as floats the Longevity weights sum to 0.9999999999999999.

| Component               | Core | Health & wellness | Longevity |
| ----------------------- | ---- | ----------------- | --------- |
| VO₂max (`crf`)          |      | 12.5%             | 22.5%     |
| Resting HR (`rhr`)      | yes  | 12.5%             | 15%       |
| MVPA (`mvpa`)           | yes  | 20%               | 15%       |
| Daily steps (`steps`)   | yes  | 15%               | 17.5%     |
| Sleep timing regularity | yes  | 15%               | 10%       |
| Sleep duration          | yes  | 12.5%             | 7.5%      |
| HRV (`hrv`)             |      | 7.5%              | 7.5%      |
| HRR (`hrr`)             |      | 5%                | 5%        |

The default profile is Health & wellness. **The profile is the partner's choice** (`PARTNER_HES_PROFILE`, Health
& wellness in the demo): the tier that is shared, eligibility and the benefit are always calculated in it. The
profile switch on the Report and Why screens only explains how the score would read in the other profile.

## Windows, minimum and target counts

Windows are calendar days back from the last completed day (0 = that day). In production a day closes at
midnight; in the demo the "Close the day" button closes it.

| Component               | Window    | Raw value                                              | Minimum | Target |
| ----------------------- | --------- | ------------------------------------------------------ | ------- | ------ |
| Daily steps             | 28 days   | mean of the valid days                                 | 14      | 21     |
| MVPA                    | 28 days   | mean daily equivalent (moderate + 2 × vigorous) × 7    | 14      | 21     |
| Resting HR              | 28 days   | median of the daily resting heart rate                 | 10      | 14     |
| Sleep duration          | 28 nights | median total sleep, hours                              | 14      | 21     |
| Sleep timing regularity | 28 nights | timing SD, minutes                                     | 14      | 21     |
| HRV                     | 14 nights | median of the nightly percentile, protocol `nocturnal` | 7       | 14     |
| VO₂max                  | 90 days   | the newest valid percentile (for age and sex)          | 1       | 2      |
| HRR                     | 60 days   | median HRR1 of the comparable sessions                 | 2       | 3      |

A reading is valid when it is present, finite and not negative. What is physiologically plausible is the
source's decision (the device or its API), not the score's. Nothing is interpolated, filled in or
extrapolated. A night belongs to the day the person woke up on.

Timing SD is `sqrt((bedtimeSD² + wakeSD²) / 2)` with the population SD (divisor n), on minutes counted from
18:00 so that a night never wraps at midnight: 23:30 is 330 and 00:30 is 390, 60 minutes apart.

## How a score is calculated

1. Each component counts its valid observations in its window. With fewer than its minimum it is not
   available: it has no raw value and no score. It never gets a score of zero.
2. An available component gets a score from 0 to 100 on its curve (specification section 5): straight lines
   between the points, the end scores beyond the ends.
3. `quality = min(validCount / targetCount, 1)`.
4. **Evidence Coverage** = the sum of the base weights of the available components, in the selected profile.
   A missing HRV lowers coverage by exactly 7.5 points.
5. If any of the five Core components is not available there is no score: `score` absent, tier `NONE`, status
   `INSUFFICIENT_DATA`, confidence `NOT_ENOUGH_DATA`. Coverage is still reported.
6. Otherwise the observed score is the weighted mean of the available components: missing optional ones are
   left out of both the numerator and the denominator (explicit renormalization). HES is the observed score
   rounded half up.
7. The **effective weight** of a component is its base weight divided by the denominator. It explains the
   current score when optional evidence is missing and never replaces the base weight.
8. **Data Confidence**: the confidence index is coverage (as a fraction) times the weighted quality. High from
   0.80, Medium from 0.60, Low below.
9. **Tier**: A from 80, B from 60, C below. Without a score the tier is `NONE`, never C.

## Why this tier

- **Strongest**: the available components, highest score first, top 3.
- **To improve**: the available components that are not in Strongest, lowest score first, at most 3.
- **Missing data (optional)**: optional components without enough data, with their count against the minimum
  ("HRV — 4 of 7 nights"). Never in To improve, never with a score of 0, never as a negative factor.
- Scores closer than 1e-9 are a tie: the higher base weight goes first, then the fixed order `crf`, `rhr`,
  `mvpa`, `steps`, `sleepRegularity`, `sleepDuration`, `hrv`, `hrr`.
- The effective weight is shown next to a component when coverage is below 100%.

**Without a score** (Core incomplete) the screens say "No score yet" and show the Evidence coverage, "Measured
so far" (raw values and counts, no component scores), "Needed for a score" ("Sleep timing regularity — 6 of 14
nights") and the optional components apart. There is no tier and Share says the tier is not available.

## Live values and closing the day

- The live heart rate and today's steps change the Live card only ("Live · not scored"). A heart rate going
  from 70 to 145, or steps from 1,200 to 8,000, leave the score as it is.
- `closeDay()` appends a copy of today's record to the history, with the steps as they stand now; the windows
  move and the aggregates, the components and the score are calculated again. The history is one day longer.
- The next running day is the source's record for today again (the persona's base steps, not 0), one calendar
  day later.
- A value that was never there stays absent. Zero is never written because a live value was cleared or not
  set.
- The resting heart rate of the day that is closed comes from the source's daily record, never from the live
  heart rate.
- `resetDemo()` goes back to the snapshot the session started from (the one Health Sim sent, when it did).

## Personas

`HesPersonas.IDS` = `ania`, `marek`, `kasia`, `tomek`, `ewa`, `ola`. Each persona is a recipe without random
numbers (`HesPersonas.ets`): `pattern(A, d, n)` gives n values around the base A whose mean and median are A,
and a series of n values goes to the n newest days; older days do not have that field. Histories are 28
completed days (Ola 16) ending the day before `today`, which is a parameter (`2026-10-04` in the demo and in
the tests). The clock is never read in the engine or in the generator.

| Persona | Raw values (valid observations)                                                                                                             | Health & wellness                       | Longevity               |
| ------- | ------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------- | ----------------------- |
| Ania    | VO₂max 77 (2) · resting HR 58 (28) · MVPA 238 (28) · steps 8,800 (28) · sleep timing ±45 (28) · sleep 7.4 h (28) · HRV 60 (14) · HRR 32 (3) | **92 · A · 100% · High**                | 92 · A · 100% · High    |
| Marek   | resting HR 68 (28) · MVPA 119 (28) · steps 6,200 (28) · sleep timing ±70 (28) · sleep 6.6 h (28) · HRV 40 (14) · HRR 24 (3)                 | **75 · B · 87.5% · High**, flagged      | 76 · B · 77.5% · Medium |
| Kasia   | resting HR 72 (18) · MVPA 98 (20) · steps 6,000 (20) · sleep timing ±70 (16) · sleep 6.4 h (16) · HRV 4 nights                              | **73 · B · 75% · Medium**               | 74 · B · 65% · Low      |
| Tomek   | VO₂max 50 (2) · resting HR 62 (28) · MVPA 147 (28) · steps 7,000 (28) · sleep timing ±80 (28) · sleep 6.5 h (28) · HRR 27 (3)               | **79 · B · 92.5% · High**, 1 point to A | 79 · B · 92.5% · High   |
| Ewa     | resting HR 76 (20) · MVPA 70 (20) · steps 4,400 (20) · sleep timing ±85 (16) · sleep 6.2 h (16) · HRV 3 nights · HRR 20 (2)                 | **59 · C · 80% · Medium**               | 59 · C · 70% · Medium   |
| Ola     | resting HR 68 (16) · MVPA 112 (16) · steps 6,800 (16) · sleep 6 nights · HRV 6 nights                                                       | **No score · 47.5%**                    | No score · 47.5%        |

Benefits (always by the partner's profile): Ania full, Kasia partial, Tomek partial, Marek none (flagged), Ewa
none (tier C), Ola none (no score). The wear results did not change with the model: Marek is flagged with 3
suspicious breaks and 4 red days, Kasia has 1 suspicious break and no flag.

Ola's record for today has a night and HRV: from now on she sleeps with the watch on. Seven closed days are
still not enough (coverage 55%); the eighth gives her first score: 84 · A · 82.5% · Medium (Longevity
84 · A · 72.5% · Medium).

These numbers were given with the specification as golden values, calculated by a reference implementation and
checked by a second one. The tests assert them number by number (`HesPersonas.test.ets`); a disagreement means
the engine is wrong, not the table.

### Compared with HES-Lite v1.0

| Persona | HES-Lite v1.0              | HES vNext (Health & wellness)                                                     |
| ------- | -------------------------- | --------------------------------------------------------------------------------- |
| Ania    | A / 92, 100%, High         | A / 92, 100%, High                                                                |
| Marek   | B / 75, 85%, High, flagged | B / 75, **87.5%**, High, flagged                                                  |
| Kasia   | B / 73, 70%, Medium        | B / 73, **75%**, Medium (without all Core there is no score, so 75% is the floor) |
| Tomek   | B / 79, 90%, High, 1 to A  | B / 79, **92.5%**, High, 1 point to A                                             |
| Ewa     | C / 59, 75%, Medium        | C / 59, **80%**, Medium                                                           |
| Ola     | no score, 43%              | no score, **47.5%**                                                               |

## Health Sim and the contract

Health Sim serves the personas from the generator in `common` and hands them to FairWear, after the user allows
it, as one JSON text (`health/HealthSimPayload.ets`):

```
{"schema":"fairwear.health-export","version":2,"source":"Health Sim","exportedAt":"...",
 "people":[{"personaId":"ania","name":"Ania","today":{day},"days":[{day},...],
            "crf":[{"date","percentile"}],"hrr":[{"date","protocolId","peakHr","hr60"}],"wear":[...]}]}
```

- A reading that does not exist is a key that is not there. It is never written as 0 or -1, and the reader
  never turns a missing key into a number.
- The contract is versioned. A text of another schema or version is refused with "Health Sim data format is
  outdated — update Health Sim" and nothing is calculated from it.
- The channel is the one that was there: `startAbilityForResult`, answered under the Want parameter `fwhs1`.
  The size of the text is in `docs/test-results.txt`; the reader accepts up to 90,000 characters.
- The consent filters the data before scoring: a data type that is switched off is removed from every day,
  from the running day (and so from every day closed later), and without VO₂max or Workouts there are no
  estimates or sessions. It lowers coverage and is never counted as zero.
- Health Sim takes `common` as a built package (`healthsim/libs/common.har`, made by
  `tools/sync-common-har.sh`). It has no copy of any formula.
- "FairWear readiness" in Health Sim (`health/HealthSimReadiness.ets`): eight rows (valid of minimum / target,
  Core or Optional, ready or not), coverage in both profiles and a preview of the score with the caption
  "Simulator check — FairWear computes the official result". The preview equals what FairWear calculates from
  the exported data for every persona and both profiles (`HealthSimReadiness.test.ets`).

## The claim

The tier claim carries the tier, eligibility, the period, a nonce, the time and the key id. It never carries a
score, coverage, confidence or components, and the model change did not touch it: the fields, the signing and
the verifier are as they were. Its `v` is the number of the claim's wire format, which the verifier checks; it
does not name a score model, so it was left alone.

## Decisions (D1 – D23 of the build brief, in short)

1. **"≥"** on the last point of every curve and on the confidence thresholds (High ≥ 0.80, Medium ≥ 0.60).
2. **Weights in thousandths**; coverage is a whole number of thousandths, shown as "47.5%", "75%", "87.5%".
3. **Rounding** `floor(observed + 0.5 + 1e-9)`: 84.49 gives 84, 84.50 gives 85. Thresholds are compared with a
   tolerance of 1e-9. An effective weight is shown with one decimal by the same rule (150/800 reads 18.8%).
4. **Validity is the source's**: present, finite, not negative. No physiological thresholds in the score.
5. **MVPA a week = mean daily equivalent of the valid days × 7** (see Deviations).
6. **Median** of an even count is the mean of the two middle values.
7. **SD is the population SD**; timing SD on minutes from 18:00.
8. **A night belongs to the wake-up date** and enters the history with that day.
9. **Windows are calendar days** back from the last completed day: 28 / 14 / 60 / 90.
10. **HRV**: protocol `nocturnal` only; other protocols are skipped. Never derived from a heart rate.
11. **VO₂max**: the newest valid percentile in 90 days. Never derived from steps or MVPA.
12. **HRR**: HRR1 = peak − heart rate after 60 s; comparable sessions only (see Deviations).
13. **Profiles**: Health & wellness by default; sharing, eligibility and benefit use the partner's profile.
14. **The claim has no score in it** and was not changed.
15. **Why this tier**: no component in both lists; ties by base weight, then the fixed order.
16. **No-score state**: no tier, never C; measured, needed and optional apart.
17. **Live values** are not scored; closing the day uses the source's record with the live steps.
18. **The watch does not calculate HES.**
19. **One source of truth**: the engine and the generator exist only in `common`.
20. **The Health Sim contract is versioned**; another version is refused.
21. **Benefit and eligibility**: the rule did not change (compliance, no flag, a score); the score now comes
    from vNext in the partner's profile.
22. **Naming**: "HES vNext" in documents, `HES_MODEL_VERSION = 'vnext-1'` in code, no version name on screen.
23. **No clock** in the engine or the generator: today is a parameter.

## Deviations from the spec

- **MVPA = mean × 7 (D5).** The specification divides the 28-day sum by 4. With missing days that counts each
  of them as zero minutes, against "missing is never zero". The weekly value here is the mean daily equivalent
  of the valid days times 7: exactly SUM / 4 with 28 valid days. The literal formula would give Kasia 70
  minutes and 69 · B, and Ewa 50 minutes and 56 · C.
- **Comparable HRR sessions (D12).** The specification asks for a comparable protocol and does not say which.
  Comparable = the sessions of the protocol with the most sessions in the 60-day window; on equal counts the
  protocol of the newest session. So one new session of another protocol does not switch the component off.
- **No duplicates in To improve (D15).** The specification takes the bottom 3 of the available components,
  which repeats Strongest when five are available. Here To improve takes only components that are not in
  Strongest (five available give 3 + 2).
- **All six people in one export.** The brief describes the export for one `personaId`. The channel that was
  already there sends all six demo people in one answer, and the demo switches between them, so the version 2
  text keeps a `people` list and each person carries `personaId`, `today`, `days`, `crf`, `hrr` (and `wear`).
- **The wear calendar is independent of the score's history.** The wear month keeps the parameters it was
  built on, so the wear results are unchanged (checked by checksum against the previous build). The score's
  history follows the persona recipe, which fills the newest days; it is not blanked on the days the wear
  calendar marks as off the wrist.
- **The reference oracle** (`tools/hes_vnext_oracle.cjs`) arrived cut in half; its lower half was completed in
  the repository. It reproduces the golden table, and `tools/check-oracle.sh` compares the engine with it for
  the six personas in both profiles. The independent check is the golden table itself.

## The report on the phone

`common/src/main/ets/report/EngineReports.ets` builds the phone's view model (`PersonaReport`) from the engine.
Every screen reads `PersonaReport` and nothing else.

| Function                                                | Returns                                                                                  |
| ------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `engineReports(profile?)`, `engineReport(id, profile?)` | the reports of the personas' starting histories, built once per profile                  |
| `engineSession(id, scopes?)`                            | a `HesSession` of the persona with the consent applied                                   |
| `engineSessionFrom(person, scopes?)`                    | the same from what Health Sim sent                                                       |
| `engineReportOf(id, session, profile?)`                 | the report as the session stands now; live values only in `live`                         |
| `engineReportFromPerson(person, session, profile?)`     | the same for a person from Health Sim (source "Health Sim · Simulated data")             |
| `engineWhatIf(result)`                                  | the counterfactual: one change in one Core component that reaches the next tier, or null |
| `engineDayDetails(id)`, `engineDayDetailsFrom(person)`  | the 30 days of the wear month as `DayDetail`                                             |

Without a profile argument a report is in the partner's profile. In any profile `eligible`, `benefit` and
`benefitReason` are those of the partner's profile. Missing stays missing: no score is `-1` in the view model,
a component that is not available has no value, score, weight or bar, and carries its count ("6 of 14 nights").
Effective weights have one decimal ("18.8%"). The wear month does not move when a day is closed.

## Tests

`tools/run-logic-tests.sh common` runs them under Node. For the score: `Hes.test.ets` (curves, model,
aggregation windows, filters, rounding, the no-score state, a seeded fuzz of 1000 histories with NaN, Infinity,
negative and missing values, numbers as text), `HesPersonas.test.ets` (the golden values in both profiles, Why
lists, effective weights, sleep across midnight, missing optional data, closing days, windows and protocols,
the generator), `HesSession.test.ets` (live values, close the day, reset), `HesOracle.test.ets` (the engine
against the oracle), `HealthSimPayload.test.ets` (the contract), `HealthSimReadiness.test.ets` (Health Sim's
preview equals FairWear). Current counts are in `docs/test-results.txt`.

## Known limits

A day with at least 20 h of wear and a suspicious break is drawn as SUSPICIOUS in the calendar but still counts
as a compliant day in the monthly percentage. None of the six personas has such a day.

Percentiles for VO₂max and HRV are simulated in Health Sim; a real source has to supply them already
normalized. Recovery sessions exist only as far as the source records a peak heart rate and the heart rate 60
seconds later under a named protocol.

## What this is not

HES is a transparent prototype that summarises longitudinal wearable evidence with fixed rules. It is not a
diagnosis and not a medical device output, and its coefficients are not clinically or actuarially validated.
Verified watch days are shown in the app and do not feed this score.
