# HES vNext — backend implementation specification

The specification the engine in `common/src/main/ets/hes/` was built from, kept one to one as it was handed
over (the only change: the "≥" signs lost in copying were put back in ten lines). How the repository reads
it, and where it knowingly departs from it, is in `docs/HES.md`.

```text
HES vNext — BACKEND IMPLEMENTATION SPEC

IMPORTANT
- Deterministic rule-based score.
- Not AI / ML.
- Missing data is NEVER treated as score = 0.
- All exact weights, thresholds, curves, minimum counts and tier boundaries
  are research-informed PRODUCT ASSUMPTIONS, not clinically/actuarially validated coefficients.
- Current incomplete day MUST NOT affect longitudinal HES until day is closed.


==================================================
1. SCORE PROFILES
==================================================

enum HESProfile {
  HEALTH_WELLNESS,
  LONGEVITY_WELLNESS
}

HEALTH_WELLNESS weights:
- crf:               0.125
- rhr:               0.125
- mvpa:              0.200
- steps:             0.150
- sleepRegularity:   0.150
- sleepDuration:     0.125
- hrv:               0.075
- hrr:               0.050

TOTAL = 1.000


LONGEVITY_WELLNESS weights:
- crf:               0.225
- rhr:               0.150
- mvpa:              0.150
- steps:             0.175
- sleepRegularity:   0.100
- sleepDuration:     0.075
- hrv:               0.075
- hrr:               0.050

TOTAL = 1.000


DOMAIN GROUPS:

Activity:
- mvpa
- steps

Sleep:
- sleepRegularity
- sleepDuration

Cardiorespiratory / autonomic:
- crf
- rhr
- hrv
- hrr

Do not introduce additional dynamic weighting inside a domain.


==================================================
2. REQUIRED CORE COMPONENTS
==================================================

CORE:
- rhr
- mvpa
- steps
- sleepRegularity
- sleepDuration

OPTIONAL / ADVANCED:
- crf
- hrv
- hrr

RULE:

If ANY Core component is unavailable:

score = undefined
tier = NONE
status = INSUFFICIENT_DATA
confidence = NOT_ENOUGH_DATA

Optional components may be missing.

Missing optional component:
- available = false
- excluded from numerator
- excluded from denominator
- lowers Evidence Coverage
- NEVER receives score 0


==================================================
3. LOOKBACK / AGGREGATION
==================================================

STEPS
lookback:
- last 28 COMPLETED days

aggregation:
- mean valid daily steps

minimum:
- 14 valid days

target:
- 21 valid days

current day:
- display live
- exclude from HES

freshness:
- rolling 28-day window


MVPA
lookback:
- last 28 COMPLETED days

daily equivalent:
moderateMinutes + 2 * vigorousMinutes

weekly equivalent:
SUM(dailyEquivalent over 28 days) / 4

minimum:
- 14 valid days

target:
- 21 valid days

current day:
- exclude until closed


RHR
lookback:
- last 28 COMPLETED days

aggregation:
- median valid DAILY RESTING heart rate

minimum:
- 10 valid days

target:
- 14 valid days

IMPORTANT:
- live HR != RHR
- instantaneous HR MUST NOT enter RHR score


SLEEP DURATION
lookback:
- last 28 COMPLETED nights

aggregation:
- median total sleep duration

minimum:
- 14 valid nights

target:
- 21 valid nights


SLEEP TIMING REGULARITY
lookback:
- last 28 COMPLETED nights

minimum:
- 14 valid nights

target:
- 21 valid nights

bedtime/wake time must be converted to midnight-safe relative minutes.

relativeMinutes =
(minutesSinceMidnight - 1080 + 1440) % 1440

1080 = 18:00 anchor

Example:
23:30 => 330
00:30 => 390
difference = 60 min

bedtimeSD =
SD(relativeBedtimes)

wakeTimeSD =
SD(relativeWakeTimes)

TimingSD =
sqrt(
  (bedtimeSD^2 + wakeTimeSD^2) / 2
)


HRV
recommended measurement:
- one consistent protocol only
- preferably nocturnal HRV / same vendor-derived metric

lookback:
- recent 14 nights

minimum:
- 7 valid nights

target:
- 14 valid nights

aggregation:
- use normalized HRV percentile
- do NOT mix different HRV protocols

missing:
- allowed


CRF / VO2MAX
input:
- age/sex normalized VO2max percentile
- NOT raw VO2max directly across whole population

lookback:
- last 90 days

minimum:
- 1 valid estimate

target:
- 2 valid estimates

recommended aggregation:
- latest valid estimate
OR
- latest stable vendor estimate

expiry:
- unavailable if no valid estimate in previous 90 days


HRR
use:
- HRR1 only

definition:
HRR1 =
peakHeartRate - heartRateAt60Seconds

lookback:
- last 60 days

minimum:
- 2 comparable sessions

target:
- 3 comparable sessions

IMPORTANT:
- sessions must use comparable exercise/recovery protocol
- HRR2 / HRR3 are not used


==================================================
4. OUTLIERS / VALID DATA
==================================================

General:
- invalid sensor readings must be removed BEFORE aggregation
- incomplete current day/night must not be used
- do not manually replace missing values
- do not extrapolate values

Prefer robust statistics:
- RHR -> median
- Sleep duration -> median
- Steps -> mean over valid completed days
- MVPA -> sum/weekly equivalent
- Sleep regularity -> SD of timing
- CRF -> valid normalized estimate
- HRV -> normalized percentile
- HRR -> valid comparable sessions

Exact physiological artefact thresholds should come from device/API validation,
not invented inside HES.


==================================================
5. SCORING CURVES
==================================================

Generic piecewise interpolation:

Given:
(x0, y0)
(x1, y1)

for:
x0 <= x <= x1

score =
y0 + ((x - x0) / (x1 - x0)) * (y1 - y0)

Rules:
- exact point => exact score
- <= first x => first y
- >= last x => last y
- clamp 0–100
- no extrapolation beyond endpoints


--------------------------------------------------
CRF / VO2MAX percentile
--------------------------------------------------

<= 5   -> 10
10     -> 20
25     -> 45
50     -> 70
75     -> 88
90     -> 97
>= 95  -> 100



--------------------------------------------------
RHR bpm
--------------------------------------------------

<= 40  -> 90
45     -> 98
50     -> 100
55     -> 100
60     -> 95
65     -> 90
70     -> 84
75     -> 76
80     -> 66
90     -> 45
100    -> 20
>= 110  -> 5


Low-HR plateau is intentional.
Do NOT implement "lower is always better".


--------------------------------------------------
MVPA weekly equivalent minutes
--------------------------------------------------

0      -> 0
30     -> 20
60     -> 40
100    -> 60
150    -> 80
250    -> 95
>= 300  -> 100



--------------------------------------------------
STEPS / day
--------------------------------------------------

<=1000  -> 0
2000    -> 20
4000    -> 50
5000    -> 65
6000    -> 80
7000    -> 90
8000    -> 95
>= 10000 -> 100



--------------------------------------------------
SLEEP TIMING REGULARITY
TimingSD in minutes
--------------------------------------------------

<=30   -> 100
45     -> 90
60     -> 80
90     -> 60
120    -> 40
180    -> 15
>= 240  -> 0



--------------------------------------------------
SLEEP DURATION hours
--------------------------------------------------

<=4.5  -> 0
5.0    -> 25
5.5    -> 45
6.0    -> 65
6.5    -> 82
7.0    -> 95
7.5    -> 100
8.0    -> 100
8.5    -> 100
9.0    -> 100
9.5    -> 95
10.0   -> 90
11.0   -> 80
>= 12.0 -> 65



--------------------------------------------------
HRV percentile
--------------------------------------------------

<=5   -> 10
10    -> 25
25    -> 50
50    -> 75
75    -> 90
90    -> 97
>= 95  -> 100



--------------------------------------------------
HRR1 bpm
--------------------------------------------------

<=12  -> 10
18    -> 30
24    -> 55
30    -> 70
36    -> 82
42    -> 92
>= 50  -> 100



==================================================
6. COMPONENT QUALITY
==================================================

For each component:

quality_i =
min(
  validCount_i / targetCount_i,
  1
)

available_i =
validCount_i >= minimumCount_i

For CRF:
validCount = valid estimates in last 90 days

For HRR:
validCount = comparable sessions in last 60 days


==================================================
7. EVIDENCE COVERAGE
==================================================

For current selected profile:

Coverage =
100 *
SUM(
  baseWeight_i * available_i
)

Example:

If HRV weight = 7.5%
and HRV is missing:

Coverage drops by 7.5 percentage points.

Do NOT substitute HRV score = 0.


==================================================
8. HES CALCULATION
==================================================

Only if ALL Core components are available:

denominator =
SUM(
  weight_i
  for available components
)

numerator =
SUM(
  weight_i * componentScore_i
  for available components
)

ObservedHES =
numerator / denominator

HES =
round(ObservedHES)

This is explicit renormalization.


==================================================
9. EFFECTIVE WEIGHTS
==================================================

Used only for explanation UI:

effectiveWeight_i =
baseWeight_i / denominator

Do NOT overwrite baseWeight with effectiveWeight.

baseWeight:
model definition

effectiveWeight:
explanation of current score when optional evidence is missing


==================================================
10. DATA CONFIDENCE
==================================================

WeightedQuality =

SUM(
  weight_i
  * available_i
  * quality_i
)
/
SUM(
  weight_i
  * available_i
)

CoverageFraction =
Coverage / 100

ConfidenceIndex =
CoverageFraction * WeightedQuality

Labels:

HIGH:
>= 0.80


MEDIUM:
>= 0.60 and < 0.80


LOW:
< 0.60

If Core incomplete:

NOT_ENOUGH_DATA


==================================================
11. TIER
==================================================

Only assign Tier if:
ALL Core components available

A:
HES >= 80

B:
60 <= HES < 80

C:
HES < 60

If insufficient Core data:

tier = NONE


==================================================
12. LIVE DATA RULES
==================================================

LIVE HEART RATE:

live HR:
70 -> 145

Expected:
- live card changes
- HES unchanged


TODAY STEPS:

1200 -> 8000

Expected:
- live Today value changes
- HES unchanged


CLOSE DAY:

On Close Day:

today data
-> completed day history
-> rolling aggregates recalculated
-> component scores recalculated
-> HES recalculated

historyLength += 1


==================================================
13. WHY THIS TIER
==================================================

For every component store:

id
label
rawValue
score
baseWeight
effectiveWeight
available
requiredCore
validCount
minimumCount
targetCount
quality

Strongest:
available components
sort score DESC
top 3

Improvement opportunities:
available components
sort score ASC
bottom 3

Missing optional:
show separately

Missing metric must NEVER appear as:
score = 0
bad factor
negative health factor


==================================================
14. NO-SCORE STATE
==================================================

If Core incomplete:

score = undefined
tier = NONE
status = INSUFFICIENT_DATA
confidence = NOT_ENOUGH_DATA

UI:

"No score yet"

Show:
- Evidence Coverage
- measured components
- missing Core requirements

Example:

Sleep timing regularity
0 of 14 nights
Needed for a score


==================================================
15. RECOMMENDED TYPES
==================================================

ComponentId =
  crf
  | rhr
  | mvpa
  | steps
  | sleepRegularity
  | sleepDuration
  | hrv
  | hrr


ComponentResult {
  id: ComponentId
  rawValue?: number
  score?: number
  available: boolean
  requiredCore: boolean

  validCount: number
  minimumCount: number
  targetCount: number

  quality: number

  baseWeight: number
  effectiveWeight?: number
}


HESResult {
  profile: HESProfile

  score?: number

  tier:
    A
    | B
    | C
    | NONE

  coverage: number

  confidence:
    HIGH
    | MEDIUM
    | LOW
    | NOT_ENOUGH_DATA

  status:
    OK
    | INSUFFICIENT_DATA

  components: ComponentResult[]
}


==================================================
16. BACKEND SAFEGUARDS
==================================================

MUST:
- never return NaN
- never return Infinity
- never divide by zero
- never convert missing metric to 0
- never infer HRV from HR
- never infer CRF from Steps/MVPA inside HES
- never use current live HR as RHR
- never use incomplete current day in longitudinal aggregates
- never assign Tier C because score is unavailable

If denominator <= 0:
return insufficient data / error state


==================================================
17. REQUIRED UNIT TESTS
==================================================

Piecewise:
- exact boundaries
- interpolation
- below first point
- above last point

Steps:
1000 -> 0
2000 -> 20
3000 -> 35
10000 -> 100

MVPA:
150 -> 80

RHR:
55 -> 100
110 -> 5

Sleep midnight:
23:30 -> 330
00:30 -> 390
difference = 60

Missing optional:
- score still calculated
- denominator renormalized
- Coverage decreases exactly by missing weight

Missing Core:
- score undefined
- Tier NONE
- INSUFFICIENT_DATA

Rounding:
84.49 -> 84
84.50 -> 85

Live HR:
change does not change HES

Live steps:
change does not change HES

Close Day:
history +1
recalculate aggregates
recalculate HES

No NaN / Infinity.


==================================================
18. IMPORTANT PRODUCT ASSUMPTIONS
==================================================

These exact values are NOT directly derived from a single clinical study:

- exact component weights
- exact control points of score curves
- Tier A/B/C boundaries
- minimum observation counts
- target observation counts
- Confidence thresholds
- exact 28/60/90-day windows

They are research-informed reliability/product rules.

Broad evidence supports:
- selected signals
- general direction of association
- nonlinear / plateau / U-shaped behavior where applicable

Future validation must use real cohort/outcome data.
```
