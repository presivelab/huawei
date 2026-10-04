# HES-Lite v1.0 in FairWear

HES-Lite (Health Evidence Score) turns a history of completed days into one integer score from 0 to 100, a tier
A / B / C, an Evidence Coverage percentage and a Data Confidence label. It is deterministic rules: no learned
model, no network, no clock. A missing measurement is never guessed and never counted as zero.

This engine was rebuilt from the written specification `HES_Lite_Final_Hackathon_Spec_v1.0` ("path B" of the
phone brief), because the package that was to contain it did not arrive. It is pure logic in the `common`
module and has no UI.

All weights, curves, thresholds and minimum counts are prototype product assumptions, not clinically tested.

## Files and specification sections

| File (`common/src/main/ets/hes/`) | Specification    | What it holds                                                                                                                        |
| --------------------------------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `HesTypes.ets`                    | 12               | `HesDay`, `HesComponentResult`, `HesResult`, `HesWhy`, the enums, `HES_MISSING = -1`                                                 |
| `HesPiecewise.ets`                | 5, 13            | `piecewiseScore`: straight lines between points, inclusive boundaries, clamped to 0..100                                             |
| `HesCurves.ets`                   | 2, 3, 6, 7, 8, 9 | every number of the model: weights, Core flags, the eight curves, minimum and target counts, windows, tier and confidence thresholds |
| `HesMath.ets`                     | 4.2, 6.4         | mean, median, sample SD, half-up rounding, the midnight-safe clock conversion, timing SD                                             |
| `HesSufficiency.ets`              | 7, 8             | which reading is valid, valid days inside a window, `available = validCount >= minimum`, `quality`                                   |
| `HesComponents.ets`               | 6                | raw value of each component and its score on the curve                                                                               |
| `HesComposite.ets`                | 4, 11            | Evidence Coverage, observed HES, effective weights, the Core check                                                                   |
| `HesConfidence.ets`               | 8                | weighted quality, confidence index, High / Medium / Low                                                                              |
| `HesTier.ets`                     | 9                | A from 80, B from 60 to 79, C below 60; labels; points to the next tier                                                              |
| `HesWhy.ets`                      | 11               | strongest factors, improvement opportunities, missing evidence                                                                       |
| `HesEngine.ets`                   | 14               | `computeHes(history)`: the whole flow                                                                                                |
| `HesSession.ets`                  | 10               | live heart rate (never stored), today's steps (stored when the day closes), close the day, reset                                                          |
| `HesPrng.ets`, `HesPersonas.ets`  | 16               | the seeded generator and the six personas                                                                                            |

The wear month is next to it, in `common/src/main/ets/wear/`: `WearMonth.ets` (the rules) and `WearPersonas.ets`
(a 30-day wear record per persona).

Tests: `common/src/test/Hes.test.ets` (75, every line of specification section 15 as its own test, then sections
2 to 11), `HesPersonas.test.ets` (16), `HesSession.test.ets` (11), `WearMonth.test.ets` (22).

## How a score is calculated

1. The history is a list of completed days, oldest first, one entry per calendar day. Today is not in it.
2. Each of the eight components counts its valid readings in its window (28 days; 60 days for heart-rate
   recovery; 90 days for VO₂max). With fewer than the minimum, the component is missing.
3. An available component gets a raw value (mean, median, latest, or timing SD) and a score on its curve.
4. If any of the five Core components is missing there is no score and no tier: status `insufficient_data`,
   tier `NONE`, confidence "Insufficient data". Coverage is still reported.
5. Otherwise the score is the weighted mean of the available components, rounded to an integer. Missing
   components are left out of both the numerator and the denominator.
6. Coverage is the sum of the base weights of the available components. Confidence is coverage times the
   weighted data quality.

## Personas

`HesPersonas.IDS` = `ania`, `marek`, `kasia`, `tomek`, `ewa`, `ola`. Each persona is a set of parameters in
`HesPersonas.ets` and a seed; the generator has no `Math.random`, so the history is the same on every run. Only
persona parameters were tuned to reach the team's fixed table. The engine's weights, curves and thresholds were
not changed for it.

| Persona | Engine result | Coverage | Confidence        | Available components                             |
| ------- | ------------- | -------- | ----------------- | ------------------------------------------------ |
| Ania    | A / 92        | 100%     | High              | all eight                                        |
| Marek   | B / 75        | 85%      | High              | Core + VO₂max                                    |
| Kasia   | B / 73        | 70%      | Medium            | Core only                                        |
| Tomek   | B / 79        | 90%      | High              | Core + VO₂max + heart-rate recovery              |
| Ewa     | C / 59        | 75%      | Medium            | Core + heart-rate recovery                       |
| Ola     | no score      | 43%      | Insufficient data | resting heart rate, MVPA, steps (8 of 14 nights) |

All six match the fixed table. The unrounded values are 92.000, 74.996, 72.988, 79.000 and 58.999, so no score
sits near a rounding edge.

Wear month (30 days, 4 September to 3 October 2026, default thresholds):

| Persona | Compliant days | Nights worn | Breaks (judged) | Suspicious | Flag | Day states                          |
| ------- | -------------- | ----------- | --------------- | ---------- | ---- | ----------------------------------- |
| Ania    | 30 of 30       | 30          | 0               | 0          | no   | 30 compliant                        |
| Marek   | 26 of 30       | 30          | 5 (5)           | 3          | yes  | 26 compliant, 1 short, 3 suspicious |
| Kasia   | 26 of 30       | 26          | 4 (3)           | 1          | no   | 26 compliant, 3 short, 1 suspicious |
| Tomek   | 29 of 30       | 30          | 1 (1)           | 0          | no   | 29 compliant, 1 short               |
| Ewa     | 27 of 30       | 27          | 3 (3)           | 0          | no   | 27 compliant, 3 short               |
| Ola     | 8 of 30        | 8           | 16 (16)         | 0          | no   | 8 compliant, 16 short, 6 unknown    |

The flag ("selective non-wear") is a rule over counted breaks (`common/src/main/ets/rules/SelectiveNonWear.ets`),
with the default thresholds:

- one suspicious break never raises the flag;
- three or more suspicious breaks always raise it;
- two suspicious breaks raise it only when they are more than 30% of all **breaks** of the month (not of the
  days).

A break is suspicious when it was judged (at least 12 heart-rate readings in the 24 h before it), the resting
heart rate in those 24 h was at least 7 bpm above the person's baseline, and the steps were below 60% of the
usual. Marek has 3 suspicious breaks of 5, so he is flagged; Kasia has 1 of 4, so she is not.

## Decisions where the specification is silent or contradicts itself

Engine:

1. **Missing numbers are -1, not optional fields.** The specification writes `rawValue?` and `score?`; the
   repository's convention is `HEALTH_MISSING = -1`. `HES_MISSING` is the same value.
2. **Weights are held in thousandths.** 0.15 + 0.15 + 0.125 is not exactly 0.425 in floating point, so a
   coverage of 42.5% could round either way. With whole numbers 42.5 always rounds to 43 and 84.50 to 85.
3. **Rounding is half up** (`floor(x + 0.5)`), as the test list asks: 84.49 gives 84, 84.50 gives 85.
4. **MVPA with missing days.** The specification divides the 28-day sum by 4. With missing days that counts
   each of them as zero minutes, against "missing metrics are not treated as zero". The weekly value is the
   mean of the valid days times 7, which is the same number when all 28 days are valid.
5. **An MVPA day is valid only with both** the moderate and the vigorous minutes present.
6. **SD is the sample SD** (divisor n - 1). The specification says "SD" without the divisor.
7. **HRV has no aggregation in the specification.** The median of the valid nights in the 28-day window is
   used. The window is not given either; 28 days is used, as for the other nightly values.
8. **Heart-rate recovery has no aggregation either.** The median of the valid sessions of the last 60 days is
   used.
9. **A resting heart rate of 0 bpm or less is no reading** (the rule the watch already applies). Sleep duration
   is valid above 0 minutes. Percentiles are valid from 0 to 100. A recovery value is valid above 0.
10. **Windows are counted in history entries.** The history has one entry per calendar day; a day without data
    is an entry of -1 values. "Last 28 completed days" is the newest 28 entries.
11. **A missing component has no raw value and no score** (-1), even when a few readings exist. Its valid,
    minimum and target counts are reported so a screen can show "8 of 14 nights".
12. **Component scores are not rounded**; only the final score is. A screen rounds them for display.
13. **Confidence boundaries are inclusive with a tolerance of 1e-9**, so an index meant to be exactly 0.80 is
    High even if floating point delivers 0.7999999999.
14. **Confidence uses the rounded coverage percentage**, as the function in specification section 13 does.
15. **"Why this tier" list sizes.** The specification says "2-3". Strongest takes up to 3 but at most half of
    the available components, rounded up; improvement takes up to 3 of the remaining ones, so nothing is in
    both lists (5 available give 3 + 2). Equal scores keep the order of the weight table. Without a score both
    lists are empty and only the missing list is filled; that list holds Core components too.
16. **The tier of "no score" is `NONE`**, the value `TIER_NO_SCORE` the claim code already uses.
17. **Component labels** follow the phone brief ("Active minutes", "Daily steps"), not the specification's
    table ("MVPA", "Steps").

Session:

18. **Close the day** appends the persona's next generated day; today's steps replace the generated steps when
    a live count was set. The live heart rate is never stored. After closing, today's steps are "no reading"
    again. A session built without a day source appends a day that carries only the steps.

Personas and wear month:

19. **Persona dates are fixed**: every history ends on 2026-10-03. Histories are 90 days, Ola's is 24 days.
20. **"Red days" are the observed days that fail compliance.** Marek has 3 days with a suspicious break and 1
    short day; that is his 4.
21. **The share rule of the flag follows the code** (`isSelectiveNonWear`: more than 30% of all breaks), not
    the wording "30% of days" in one of the planning notes.
22. **An unobserved day** is `UNKNOWN`: no break, not compliant, still in the total. **A sick day** is left out
    of the total and its breaks are not counted; at most 5 are honoured.
23. **A day with a suspicious break is shown as `SUSPICIOUS`** even when its hours make it compliant; the day
    still counts as compliant in that case. Charging time is not an input of the break rule.
24. **The wear month reuses the persona's health history**: a day with no health data is a day off the wrist,
    a night with no sleep record is a night not worn. The 24 h before each break (heart-rate readings, resting
    heart rate difference, steps ratio) is scripted per persona, not derived from the history.

## The report on the phone

`common/src/main/ets/report/EngineReports.ets` builds the phone's view model (`PersonaReport`, the shape the
fixed preview fills) from the engine. Tests: `common/src/test/EngineReports.test.ets` (33).

On the phone the screens get it through `entry/src/main/ets/report/EngineReportService.ets`, which
`ServiceLocator.ets` puts in use: one `HesSession` per persona, created the first time the persona is opened.
`closeSelectedDay()` closes the running day of the persona on screen, `resetSelected()` takes that persona back
to its starting history, `setSelectedLive(hr, steps)` sets the live readings. `isPreview()` is false, so no
screen writes "preview". The fixed preview (`PreviewReportService`) is still in the code as the second
implementation of the same interface; it is not in use.

| Function                      | Returns                                                                                              |
| ----------------------------- | ---------------------------------------------------------------------------------------------------- |
| `enginePersonas()`            | the six ids and names, in the order of the preview                                                   |
| `engineReport(id)`            | the report of a persona's starting history, no live values; an unknown id gives the default persona  |
| `engineReports()`             | the six reports, built once                                                                          |
| `engineSession(id)`           | a `HesSession` of the persona: `setLive`, `closeDay`, `reset`                                        |
| `engineReportOf(id, session)` | the report as the session stands now; live values only in `live`                                     |
| `engineWhatIf(result)`        | the counterfactual of an engine result (component, values, new score and tier, sentence) or null     |
| `nextTierOf(tier)`            | the tier `pointsToNext` counts to: A for B, B for C, empty otherwise                                 |
| `engineDayDetails(id)`        | the 30 days of the wear month as `DayDetail`: worn and charging minutes, the night, breaks, `reason` |

25. **Eligible** is the wear month's verdict (compliance passes and no flag) and a score. Benefit and its reason
    come from `Benefit.ets`.
26. **Missing stays missing**: no score is `-1`, points to the next tier are `-1` without a score, a day
    without data has the bar `-1`, a live value that was not set is `-1`. A component that is not available
    has no value, score, weight or bar; it carries its valid count, and its minimum when the score needs it.
27. **Weights have one decimal** (16.7), so equal weights read the same; for the six personas they add up to
    between 99.8 and 100.2. Without a score every weight is 0.
28. **VO₂max and HRV are shown as percentiles**, which is what the persona history holds.
29. **A seven-day bar** is that day's reading on the component's curve. Sleep timing regularity has no value
    for one night; its bar is that night's distance from the person's average bedtime and wake time, on the
    same curve.
30. **The counterfactual** moves one Core component along its own curve, point by point towards the top of the
    curve, recalculates the score and keeps the first point that reaches the next tier. Of the components
    that can do it, the one with the smallest change relative to today's value is taken. The resting heart
    rate is taken only when none of steps, active minutes, sleep duration and sleep timing is enough. There
    is no sentence without a score, in tier A, or when no single Core change is enough.
31. **The wear month does not move when a day is closed.** Closing a day changes the score, the components
    and the bars; the period and the 30 day cells stay those of 4 September to 3 October.
32. **A day cell's worn share is 0 to 100.** A day the watch did not observe has the state `UNKNOWN` and the
    share 0, because the model has no "missing" for that number: a screen reads the state before the share.
33. **The reason of a day is written by the engine side, not by a screen.** `DayDetail.reason` is one line with
    the numbers the wear rule compared: a suspicious day reads "Off the wrist 13:05 for 5 h 35 min after
    resting HR +9 bpm and 46% fewer steps in the 24 h before" (Marek, 17 September); a short day reads "Worn
    17 h 5 min of 20 h", with the charging time the rule counted, or "Night not worn"; a break with too few
    heart-rate readings reads "break not judged (8 heart-rate readings before it, 12 needed)" (Kasia). It
    never says why the watch was taken off.
34. **`DayDetail.breaks` holds only what the rule counts as a break** (at least 120 minutes off the wrist and
    not on the charger). A day the watch did not observe has no breaks and 0 worn and charging minutes.
35. **Close the day and reset work per persona.** Each persona has its own session; closing a day for one
    does not touch another. One closed day moves Ewa from C / 59 to B / 64; reset gives C / 59 again. The live
    heart rate never changes a score and is never stored. Today's step count changes nothing until the day is
    closed; closing the day stores it as that day's steps (decision 18), so a closed day can move the score.

## What this is not

HES-Lite is a transparent prototype that summarises longitudinal wearable evidence. It is not a diagnosis and
not a medical device output. Verified watch days are shown in the app and do not feed this score.
