## Result

133 reference images saved to `C:\Users\robac\DevEcoStudioProjects\HealthDemo\docs\ref\`. I opened every one (individually or on a full-resolution contact sheet) and kept only images that show a watch screen.

Things to know before using them:
- **Five files in that folder are not mine:** `system-611-*.jpg` (466x466) appeared during my run. I did not create, open or change them.
- **Real captures vs renders.** Files without `official` in the name are real on-device screenshots (470x470 = 466 px screen plus a 2 px frame). Files with `official` are Huawei marketing renders: accurate UI in English, but not captures.
- **UI language.** Real captures are German (Notebookcheck) or Russian (3DNews, ixbt, rozetked, iphones.ru). English label strings come from the official renders.
- **Hex values** are sampled from pixels (some from JPEG), so treat them as approximate. Font sizes are estimates on a 466 px screen.
- **OS versions.** Watch 5 = HarmonyOS 5.1 (its About screen reads "HarmonyOS NEXT, 5.1.0.108"). GT 5 / GT 5 Pro = HarmonyOS 5.0 (per GSMArena). Other models' versions were not verified.
- **"Activity Rings 2.0":** I found no source using that name and no visual change. The same open horseshoe rings appear on GT 5 (2024), GT 5 Pro, Watch 5 (2025), Ultimate 2 and the Watch 6 watch-face render (2026). The only difference is the background: pure black on GT 5 Pro, brown-tinted on Watch 5.
- **Square-watch images:** `*-d2*` (Watch D2 renders) and `fit4pro-*` are rectangular screens, kept only where no round image exists or as a secondary reference.
- Working downloads are still in `%TEMP%\hwref`; the cleanup command was denied. Nothing else was written to the project.

## Source keys

- **NBC** = `https://www.notebookcheck.net/fileadmin/Notebooks/Huawei/`
  - Watch 5: `Watch_5/WatchScreenshot_20250514_<id>.png` or `Watch_5/WatchApScreenshot_20250514_<id>.png` (review: `.../Healthier-and-faster-to-your-goals-Huawei-Watch-5-smartwatch-review.1019754.0.html`)
  - GT 5: `Watch_GT_5/WatchScreenshot_20240918_<id>.png`
  - GT 6: `Watch_GT_6/WatchScreenshot_20250918_<id>.png`
  - GT 6 Pro: `Watch_GT_6_Pro/WatchScreenshot_20250918_<id>.png`
  - GT Runner 2: `Watch_GT_Runner_2/WatchScreenshot_20260402_<id>.png`
  - Ultimate 2: `Watch_Ultimate_2/Huawei_Watch_Ultimate2_<Name>.jpg`
  - Fit 4 Pro: `Watch_Fit_4_Pro/WatchScreenshot_<id>.png`
- **HW** = `https://consumer.huawei.com/dam/content/dam/huawei-cbg-site/common/mkt/pdp/wearables/`
  - For Watch D2 and Watch 6 I recorded only the file name; the image is linked from `consumer.huawei.com/en/wearables/watch-d2/` and `/watch-6/`.
- **3DN** = `https://cdn.3dnews.ru/assets/external/galleries/2024/09/23/66f1ce21742eec4c0a8b457a/<hash>.png` (GT 5 Pro review, 3dnews.ru/1111407)
- **IXBT** = `https://www.ixbt.com/img/r30/00/02/82/93/photo20250512-<t>.jpeg` (Watch 5 review, ixbt.com/live/comments/4192058)
- **RZ** = `https://static.rozetked.me/imager/full/uploads/<x>.webp` (Watch 5 review, rozetked.me/reviews/39122-…; converted to PNG; a serial-number watermark is overlaid)
- **IP** = `https://www.iphones.ru/wp-content/uploads/2025/05/<n>.jpg` (Watch 5 review)
- **GSM** = `https://fdn.gsmarena.com/imgroot/news/24/11/huawei-watch-gt5-pro-review/sshots/-1200x900m/gsmarena_00N.jpg`

## Per-image descriptions

### Activity rings
- **activity-rings-01-main-watch5.png** (NBC Watch 5, `WatchScreenshot_…114210453`). Three concentric open horseshoe arcs with the gap at the bottom.
  - Outer arc red-orange `#F34A29` (Move, flame badge), middle yellow `#FBCF26` (Exercise, runner badge), inner blue `#30ADFF` (Stand, standing-figure badge).
  - Stroke about 50 px, round caps; the outer arc bleeds off the screen edge. Each arc starts lower-left with a small round icon badge in its own colour. The unfilled track is a dark tint of the hue (about `#413F40` for blue).
  - In the gap, bottom-centre: three stacked bold numbers with no units, about 52 px: blue "4", yellow "45", red "549".
  - Background dark brown `#341500` to `#170700`.
- **activity-rings-02-today-steps-watch5.png** (NBC Watch 5, `…114224760`). Title "Heute" (Today) regular white about 34 px, plus ⓘ. Three rows, each with a left icon, a grey-white label and a bold white value (about 44 px) with a small unit:
  - green shoe, "Schritte", "6659 Schritte"
  - green road, "Distanz", "6,21 km"
  - teal stair-climber, "Anstieg", "22,5 m"
  - Background: vertical gradient `#632800` top to black.
- **activity-rings-03-week-watch5.png** (NBC Watch 5, `…114248142`). "Diese Woche" (grey) and "0/7 abgeschlossen" (white).
  - Row of seven day columns Mo–So, each with a mini three-ring icon; elapsed days sit in a lighter translucent capsule.
  - Three average rows: red flame "Ø 435 kcal", yellow runner "Ø 20 Min.", blue figure "Ø 12 Std."
  - Horizontal two-dot page indicator at the bottom; the active dot is a blue pill `#699CED`.
- **activity-rings-04-today-rings-detail-ult2.jpg** (NBC Ultimate 2, `Aktivitaet2`). "Heute ⓘ". Three rows, each a single mini arc icon (about 80 px) plus label plus a big coloured value with a white "/goal unit":
  - "Bewegen 1112 /545 kcal", red `#EF4C2B`
  - "Trainieren 125 /20 Min.", yellow `#F3D913`
  - "Stehen 16 /12 Std.", blue `#248DC4`
- **activity-rings-05-today-steps-ult2.jpg** (`Aktivitaet3`). Same as 02 with 17960 / 14,85 km / 208,8 m. Shows the curved vertical page-dot column on the right edge (seven dots, active = blue pill).
- **activity-rings-06-goal-badge-ult2.jpg** (`Aktivitaet4`). Goal celebration: gold laurel wreath, orange shoe, three stars, "18000 Schritte", "Starke Leistung heute!" on a brown sunburst.
- **activity-rings-07-stand-reminder-ult2.jpg** (`Aktivitaet1`). "Aufstehen und bewegen.", 3D avatar stretching, full-width blue bottom-arc button "Trainieren".
- **activity-rings-08-main-gt5pro.png** (3DN `1382b0233a27dae15cf598557967fccf`, GT 5 Pro). Same rings, numbers 15 / 8 / 261, pure black background.
- **activity-rings-09-main-official-watch5.png** (HW `watch-5/img/system/system-sport-mode-image-3.png`). Render on the watch body: 12 / 30 / 300.
- **health-clover-01-watch5.png** (NBC Watch 5, `…114321731`). Three large overlapping petals: orange top (active, runner icon), dim purple left (sleep moon), dim teal right (mood smiley). "0/3" bold plus "…erte Aufgaben" (completed tasks). Handle bar at the bottom; vertical scrollbar on the right.

### Heart rate
- **heart-rate-01-day-chart-official-d2.png** (HW Watch D2 page, `huawei-watch-d-2-heart-rate.png`, square render; the closest thing found to the HR app main screen).
  - Header: glossy red 3D heart, "78" bold white about 90 px, small "bpm".
  - Rounded translucent card: red line and area chart, dashed gridlines, right-hand y labels 200/150/100/50, dotted x axis with 00:00 / 12:00 / 24:00, a dot marker at the peak and a grey dot at "now".
  - Below: "▲151" (red triangle) and "▼53" (grey triangle), bold white.
  - Background maroon `#4A0012` to `#1B040A`.
- **heart-rate-02-resting-hr-official.png** (HW `watch-gt-runner-2/imgs/…top-ksp-comprehensive-health-management-5.png`, native 466x466 round).
  - "Resting heart rate ⓘ" bold; "Today 62 bpm" (number bold about 44 px).
  - Card with a seven-point polyline with dots over an area fill (`#94213A`), y label 80, x labels 12–18.
  - "Avg from last 7 days" / "65 bpm".
  - Vertical page dots on the right edge (blue active). Same maroon gradient.
- **heart-rate-03-hrv-official.png** (HW runner-2 `…hrv-tracking.png`). "HRV ⓘ", "48 ms, 10 min ago", area chart, x labels "9/19 12:00 / 18:00 / 9/19 00:00", y 80, "▲74 ▼48".
- **heart-rate-04-high-hr-alert-official.png** (HW runner-2 `…heart-rate-alert.png`). Black; red heart with "!" at top; "189" huge red-orange with grey "bpm"; bottom third is a filled red-orange arc with white "Limit exceeded".
- HR zones: see workout-record-08. Live HR in a workout: see in-workout-01/06/07.

### SpO2
- **spo2-01-app-official.png** (HW runner-2 `…top-ksp-…-4.png`, native 466).
  - Header: red glossy blood-cell sphere icon, "97%" bold about 60 px, ⓘ; "5 min ago".
  - Card with a green bar chart (`#76D96C`, thin bars, future slots as dim bars), y "100%", x 00:00 / 12:00 / 24:00.
  - "HR: 65 bpm"; pill button "Measure" (green text on a translucent dark-green pill).
  - Background `#003117` to dark grey-green.
- **spo2-02-result-watch5.jpg** (IXBT `01.56.49`). Real Watch 5 result: "98% ⓘ", "Только что" (just now), card with a flat green band between dashed 90% and 100% lines, x 00:00:00–00:00:11, "Пульс: 61 уд/мин", button "Готово" (Done).
- **spo2-03-xtap-measuring-watch5.jpg** (IXBT `02.03.23`). Black; "98%" huge; "Пульс: 62 уд/мин"; red pulse waveform over a dotted red grid; right-edge contact-quality scale arc (green and red ticks, white pointer); hint text at the bottom.
- **spo2-04-xtap-countdown-watch5.jpg** (IXBT `01.56.18`). "1 c" countdown, floating red and blue 3D blood cells, "Не нажимайте слишком сильно", right-edge scale.
- **spo2-05-xtap-prompt-watch5.jpg** (IXBT `01.44.12`). Illustration of the watch with red waves and a finger on the side sensor; "Коснитесь датчика X-TAP, чтобы начать."
- **spo2-06-xtap-countdown-official.png** (HW `watch-5/video/design/design-blood-oxygen-ui.png`). "3 sec", "Stay in the green area."
- **spo2-07-fingertip-official-ult2.jpg** (HW `watch-ultimate-2/new/imgs/huawei-watch-ulitimate-2-health-monitoring2.jpg`). "Fingertip SpO2", "96%", "HR: 77 bpm", red wave, "Keep contact to continue measuring."
- **spo2-08-chart-official-gt6.jpg** (HW `watch-gt6/images/emotional/…assistant-6.jpg`). "SpO2", green bars, y 100%, x 00:00:00 / 02:28:33 / 04:57:07, "▲99% ▼90%".
- **spo2-09-app-official-d2.png** (HW D2, square). "SpO2 ⓘ … 5 min ago", "97%", "Heart rate 65 bpm", chart with 100/95/90% gridlines, "Measure".

### Sleep
- **sleep-01-score-gt5.png** (NBC GT 5, `…170250`).
  - Full-screen progress ring at the bezel, purple `#A34DFA`, about 22 px, with a lighter head.
  - Lilac moon icon; "86" bold about 80 px; "Schlafwert" (sleep score); five yellow stars (4.5 filled); "7 Std. 21 Min." (numbers bold); "Dauer | Ziel: 8 Std."; handle bar.
  - Background indigo `#302373` to `#09012A`.
- **sleep-11-score-runner2.png** (NBC Runner 2, `…131116091`). Same screen on newer firmware, with vertical page dots on the right.
- **sleep-02-stages-gt5.png** (`…170258`). Title "Nacht ⓘ". Card with four rows (label left, value right, thin progress bar underneath):
  - Tiefschlaf 1 Std. 43 Min., violet `#6E37B7`
  - Leichtschlaf "↑4 Std. 41 Min." (orange arrow and text = out of range), lilac `#A473E6`
  - REM-Schlaf 57 Min., salmon `#D88AA2`
  - Wach 0-mal/0 Min., grey track
  - Below the card: "7 Std. 21 Min." bold.
- **sleep-03-hypnogram-watch5.png** (NBC Watch 5, `…131038130`). "Nacht ⓘ". Card with a stepped hypnogram: salmon awake blocks on top, lilac `#B363FF` in the middle, violet `#8233DA` deep at the bottom. Dotted time axis; "Eingeschlafen 23:19 / 13.5" left, "Aufgewacht 05:48 / 14.5" right; "6 Std. 29 Min."
- **sleep-04-health-hr-hrv-watch5.png** (`…131041834`). Title "Schlafgesundheit ⓘ". Two blocks separated by a hairline:
  - "HF - Ø", "49 bpm", three-segment range bar (purple / blue / purple) with a white triangle marker, caption "Innerhalb des Bereichs", "Persönlicher Bereich: 49–54 bpm".
  - "Herzfrequenzvariabilität (Ø)", "84 ms", "Oberhalb des Bereichs", "Persönlicher Bereich: 61–81 ms".
- **sleep-05-health-spo2-resp-watch5.png** (`…131050404`). Same layout: "SpO2 (Ø) 98 %", "Atemfrequenz (Ø) 12 AZ/min", "Persönlicher Bereich: 12–14 AZ/min".
- **sleep-06-health-ranges-gt5.png** (`…170309`). Card table: Atemfrequenz 9–17 bpm, Herzfrequenz 43–75 bpm, Sauerstoff im Blut 96–99 % (values bold).
- **sleep-10-health-ranges-gt5pro-gsmarena.jpg** (GSM `_008`). English version: "Sleep health ⓘ", Respiratory r… 9–20 bpm, Heart rate 43–76 bpm, Blood oxygen 95–99%.
- **sleep-07-health-spo2-resp-official-en.png** and **sleep-08-health-hr-hrv-official-en.png** (HW runner-2 `…sleep-tracking.png` and `…top-ksp-…-2.png`). English strings: "Avg SpO2 98 % / Within range / Personal range: 96–99%", "Avg respiratory rate 14 brpm", "Avg HR 60 bpm / Personal range: 58–63 bpm", "Avg HRV 47 ms / Personal range: 35–51 ms".
- **sleep-09-stages-official-en-ult2.jpg** (HW ultimate-2 `…health-monitoring4.jpg`). "Sleep ⓘ", Deep sleep 2 h 29 min, Light sleep 3 h 16 min, REM sleep 1 h 50 min, Awake 0 time/0 min, "7 h 35 min".

### Stress
- **stress-01-gauge-gt5pro.png** (3DN `3d2dffa6203453a31bd25e66c39deec5`).
  - Edge arc gauge in four segments with gaps: blue `#5F9BFD`, teal, yellow, orange `#EC7107`, with a white triangle pointer.
  - "Сейчас" (Now); "46" huge teal `#2DD7D4` bold, about 110 px, with the level label "Нормальный"; "▲53 ▼30"; pill button "Дыхательные у…" (Breathing exercises).
  - Background teal `#002021` to `#005355`.
- **stress-02-chart-official-gt6.jpg** (HW gt6 `…assistant-4.jpg`). Light theme (mint to white). Teal person-heart icon, "48" bold black, teal "Average ⓘ", "Stress value". Bar chart with teal and blue bars, y 99/79/59/29, x "9/19 00:00 / 12:00 / 9/19 24:00". "▲56 ▼19".
- **stress-03-chart-official-d2.png** (HW D2, square, dark teal). "Stress … Latest", "48 Average", same chart.

### Skin temperature
- **skin-temperature-01-gt5pro.png** (3DN `67b21c25ddd34ec7550bb123510d75ba`).
  - Teal round thermometer icon, "35.2 °C" bold, ⓘ; "Только что".
  - Card with a dot plot, y 37/36/35/34, x 00:00 / 12:00 / 24:00; "▲ -- ▼ --".
  - One-line scrolling disclaimer with ">"; teal text button "Измерить" (Measure).
  - Background teal `#005E60` to near-black.
- **skin-temperature-02-official-d2.png** (HW D2). "33.0 °C", dotted line chart y 35–32, disclaimer "Results are for reference only and can be affected by strap tightness, the ambient temperature, and other factors.", "▲33.2 ▼31.5".

### ECG and pulse-wave arrhythmia
- **ecg-01-recording-watch5.jpg** (IP `8-1-1.jpg`). Countdown "27 c" at top, red ECG trace with a white head dot on a dark-red dotted grid, "Не двигайтесь." (Don't move), glossy heart and "-- уд./мин".
- **ecg-02-recording-official-gt6pro.jpg** (HW `watch-gt6-pro/images/trusensesystem/huawei-watch-gt-6-pro-ecg-analiysis.jpg`). Same screen, English, "78 bpm".
- **ecg-03-intro-gt6pro.png** (NBC GT 6 Pro, `…150439983`). "Infos zum EKG ⓘ", illustration of a finger on the electrode, instruction text.
- **ecg-04-recording-official-d2.png** (HW D2). "30 sec", trace, "78 bpm".
- **pulse-wave-arrhythmia-01-official.png** (HW runner-2 `…top-ksp-…-1.png`, native 466). Red round icon (white pulse bars with a magnifier), "No abnormalities ⓘ" green bold, "5 min ago", "Measure" pill. Dark-green background; three vertical dots.
- **pulse-wave-arrhythmia-02-list-official-ult2.jpg** (HW ultimate-2 `…health-monitoring5.jpg`). "Arrhythmia ⓘ / Last 24 h" with rows and bars: No abnormalities, Risk of premature beats, Risk for A-fib, Suspected premature beats, Suspected A-fib, each "N times".

### Health Glance and Health Insights
- **health-glance-01-report-official-watch5.jpg** (HW `watch-5/img/design/design-health-checkup-detail-ui-1-2x.jpg`, 506 px-wide scroll strip). Dark-green background (about `#00201A`), cards in lighter translucent green (about `#1A3731`) with roughly 40 px radius.
  - "Health Glance" bold, date "11/10 14:00".
  - Card: red "1 abnormality" bold, "11 tests total, 11 successful, 1 abnormality".
  - Section label "Abnormalities": "1 ECG: Atrial premature beats".
  - "Compared to last report": bullet text.
  - "Personal Information": Height 163 cm, Weight 58 kg, BMI 21.8, teal link "View more".
  - "Basic health data ⓘ": one pill card per metric, each with a round icon, label and bold value:
    - Avg heart rate 78 bpm
    - HRV 48 ms, "Time: 11/10 08:25"
    - SpO2 98 %, with a red / orange / green segmented bar and white marker
    - Skin temperature 31.5 °C, teal bar
    - Stress 29 Relax, four-colour bar (blue / teal / yellow / orange) with marker
    - Emotion Pleasant
- **health-glance-02-report-cardio-arterial-official-watch5.jpg** (`…ui-2-2x.jpg`). "Cardiovascular health".
  - ECG card: "Atrial premature beats ⓘ" with explanation text. This is the only ECG result layout found.
  - Arrhythmia card: five rows with thin coloured bars (green / yellow / orange / orange / red) and "N times", plus a summary.
  - "Arterial stiffness detection" card: "Normal ⓘ" teal, "6.5 PWV (m/s)" | "95 Heart rate (bpm)". This is the only arterial stiffness layout found.
- **health-glance-03-report-respiratory-official-watch5.jpg** (`…ui-3-2x.jpg`). "Respiratory check: Good ⓘ, 83 FEV1/FVC (%) | 4.1 FVC (L)"; "Sleep breathing awareness: No abnormalities ⓘ"; note card; a teal bottom-arc button "View on phone".
- **health-glance-04-real-watch5-4screens.jpg** (IP `7-1-1.jpg`). Collage of four real Watch 5 screens in Russian: step 1 X-TAP prompt; report header "Нет отклонений / Всего 8 тестов, 7 завершено"; metric pills (avg HR 61, SpO2 94 % with bar, skin temp 29,4 °C); ECG "Синусовый ритм ⓘ" plus arterial stiffness "Норма ⓘ 7,3 СПВ (м/с) | 61".
- **health-glance-05-step1-xtap-ult2.jpg** (NBC Ultimate 2, `Gesundheit6`). "Schritt 1", marquee subtitle, watch illustration with a red dotted heart, teal link "Mehr erfahren >".
- **health-glance-06-start-official-watch6.jpg** (HW watch-6 `huawei-watch-6-14-health-metrics.jpg`). Blue gradient; "Health Glance"; four glass circle icons around a report-with-stethoscope icon; "No abnormalities" cyan; "14 items total / 14 items checked".
- **health-insights-01-official.png** (HW runner-2 `…health-insight.png`). "Health Insights ⓘ"; card with "1 Abnormality" plus a teal round icon, "4 Changes" plus a teal chart icon; "Updated 09:43"; right-edge dots.
- **health-insights-02-key-factors-official-watch6.png** (HW watch-6 `…health-insights-ux.png`). "Key factors / Updated: 08:30". Rows of icon, label, cyan status "Improved", today's value bold over the previous value, and an arrow: Sleep quality 90/85, Average sleep HRV 78/73, Avg sleep HR 54/56, Stress (yesterday) 18/22, Move calories (yesterday) 420/367. Footer "↓↑ Compared to 7-day trend". Navy background.
- **health-insights-03-readiness-official-watch6.jpg** (HW watch-6 `…health-insights.jpg`). "Readiness ⓘ / Today / 92 / Excellent", five-segment colour scale 60–90 with marker, "Learn more" pill.

### Emotional wellbeing
- **emotional-wellbeing-01-neutral-official-gt6.jpg** (HW `watch-gt6/videos/emotional/…-1-calm.jpg`). Light mint background; "Neutral" bold black; "5 min ago"; large teal five-petal translucent flower; teal link "Calm >"; right-edge vertical dots; two-dot indicator at the bottom.
- **emotional-wellbeing-02-pleasant-official.png** (HW runner-2 `…emotional-sates-tracking.png`). Cream background; "Pleasant"; golden layered flower; "Excited >" in orange.
- **emotional-wellbeing-03-timeline-gt5pro.png** (3DN `60825359abb3cad375a22bf8b482a2cc`). Real GT 5 Pro. Lilac background; purple flower icon with "Негативные ⓘ" (Unpleasant); "2 мин назад"; white card with three tick-mark timeline rows (orange Pleasant, teal Neutral, purple Unpleasant); x labels "22.09 11:00 / 17:00 / 22.09 23:00".
- **emotional-wellbeing-04-timeline-official-d2.png** (HW D2). Same timeline in English, "Pleasant", cream.

### Breathing
- **breathing-01-gt5pro.png** (3DN `2227b3313b89a0b7a6a289acb2d9a838`). Light theme. Title "Дыхание" bold black. Scenic image card (misty teal forest and moon) labelled "Баланс ⓘ" (Balance), with a bottom strip "⏱ 1 мин" and "Умеренно" (rhythm: moderate). A second card (lotus) is partly visible below.
- **breathing-02-panda-exhale-official-gt6.jpg** (HW gt6 `…assistant-2.jpg`). GT 6 guided session: "Exhale" over a panda scene, with a thin progress arc at the bezel.

### Workout list, start, settings
- **workout-list-01-watch5.png** (NBC Watch 5, `…132057159`), **-02-gt5.png** (`…164032`), **-03-running-gt5.png** (`…171507`), **-04-gt5pro.png** (3DN `ce7761a56b49d91de66ac60d55b10f9c`). Vertical list of large pill cards with fisheye scaling (the centre item is larger).
  - Each pill is tinted by sport: dark green (walk, hula hoop, indoor cycle), dark brown-orange (run, about `#3C1B0C`), dark crimson (cycling), navy (swim, diving).
  - Left: a flat sport pictogram in the bright sport colour. Centre: the name, with the goal state below in grey ("Ohne Ziel" = no goal). Right: a two-dot "more" button.
  - Black background; scrollbar on the right edge.
- **workout-list-05-header-recovery-gt5pro.png** (3DN `7ab222a0100e85b1c0d989d63153109e`). Top of the list: title "Тренировка", pie icon with "Восстановление: 0 ч" (Recovery: 0 h), a navy "Курсы и планы >" pill, then "Эскиз маршрута" (RouteDraw).
- **workout-start-01-run-watch5.png** (`…132114637`).
  - Top: battery pill "81" and "13:21"; title "Laufen (Outdoor)".
  - Left: orange runner pictogram. Right: GPS icon with signal bars, white heart with "84".
  - Bottom: a full-width orange arc button "GO" (white bold, about 64 px; about `#ED6414`).
  - Background solid dark brown `#3E1D0C`.
- **workout-start-02-trail-gt6pro.png** (NBC GT 6 Pro, `…155051021`). Newer layout: the GO button is a pill on the right, a round secondary button "Aufwärmen" (warm-up) on the left, radial brown glow.
- **workout-start-03-cycling-gt6.png** (NBC GT 6, `…115707258`). Crimson variant: "Radfahren (Outdoor)", bike picker "Fahrrad 1 / Fahrrad 2", red GO pill.
- **workout-start-05-race-runner2.png** (`…131413606`). "Testlauf", target "03:16:28 / 21.0975 km", "Ziele bearbeiten", GO.
- **workout-start-04-yoga-official-gt6.png** (HW gt6 `…indoor-sports-1-watch.png`, cropped). "Yoga", heart "80", GO arc.
- **workout-goal-01-gt5.png** (`…171526`), **workout-settings-01-gt5.png** (`…171538`), **workout-settings-02-gt5.png** (`…171547`). System list style: dark-grey pill rows (about `#1C1C1C`) with a round coloured icon on the left, title (and subtitle), and a chevron or orange toggle on the right. Rows shown: Distanz, Zeit, Intervall 1,00 km, Herzfrequenz Aus, Trainingsbelastung (toggle), Metronom 180, Abschnitt, Auto-Pause.

### In-workout data screens
- **in-workout-01-hr-zone-data-runner2.png** (NBC Runner 2, `…131444248`).
  - Five-segment HR-zone arc around the bezel with gaps: blue lower-left, green upper-left, yellow top `#FCC200`, orange upper-right, red lower-right; white triangle pointer.
  - Top: activity icon and "55" white bold about 90 px, caption "Herzfrequenz (bpm)".
  - Middle: two columns split by a hairline: "--'--"" / "Tempo (/km)" and "0,00" / "Distanz (km)".
  - Then "00:00:21" bold about 56 px with caption "Dauer".
  - Bottom: battery pill "26" and "13:14".
  - Black background; dotted page indicator on the right edge.
- **in-workout-02-steps-cadence-runner2.png** (`…131449535`). Same frame: "0 Schritte", "0 Kadenz (/Min.)" | "1 Gesamt (kcal)".
- **in-workout-03-pace-guidance-runner2.png** (`…131430733`). Arc is green at top with orange sides; pace "--'--"", "Empfohlen: 09'00"–09'35"", "00:00:08 Aktuell" | "03:16:34 Gesamt", HR 54 | distance 0,00.
- **in-workout-04-split-diff-runner2.png** (`…131436702`). "Gesamtdifferenz", "+0:12 Rückstand" in red, highlighted current-km pill, table km / Zielzeit / +/-.
- **in-workout-05-pacer-runner2.png** (`…131440598`). "Tempo (Ø) --'--" /km" | heart "55"; red runner figure with a teal ghost pacer; "Rückstand 0,03 km" red.
- **in-workout-06-anaerobic-official-watch5.png** and **-07-aerobic-official-watch5.png** (HW `watch-5/img/system/system-sport-mode-image-5.png` and `-6.png`). English. The background is tinted by zone (dark red or dark green radial). Zone-name pill at top ("Advanced anaerobic" red / "Advanced aerobic" green). HR value in the zone colour ("175" / "151") with a round sport icon. "2'45" Pace (/km)" | "1.55 Distance (km)"; "00:04:16 Time"; battery "80" and "10:08".
- **in-workout-08-fatburning-official-runner2.png** (HW runner-2 `…heart-rate-guidance.png`). "Fat-burning" green pill; "5'35" Pace"; "6'02" Avg Pace" | "156 Heart rate" (green); "5.88 Distance" | "00:35:28 Duration".
- **in-workout-09-paused-official-runner2.png** (HW runner-2 `…easy-control.png`). Pause overlay over the dimmed data: round grey settings and volume buttons; "Goal reached / Auto-paused 00:00:12"; green round play button and red round stop button.
- **in-workout-10-cycling-official-gt6pro.jpg** (HW `watch-gt6-pro/images/cycling/…road-cycling-3.jpg`). "Aerobic" yellow pill; HR "136" yellow; Speed 25.21 | Virtual power 211; Time 02:59:15 | Distance 86.38.
- **in-workout-11-running-form-official-gt6.jpg** (HW `watch-gt6/images/sports/huawei-watch-gt-6-running-2.jpg`). "L:49.5 R:50.5 Balance", "8.6 Vertical oscillation (cm)" | "274 Ground contact time (ms)".

### Workout record detail
- **workout-record-01-summary-run-watch5.png** (NBC Watch 5, `…132132310`). Black. Small orange sport icon at top; "5,39" huge bold with "km"; "Laufen (Outdoor)" grey; mini blue route trace at left; three metric rows each with a round coloured icon: cyan stopwatch "00:35:30", orange gauge "6'35" /km", red flame "449"; handle bar.
- **workout-record-04-summary-rowing-watch5.png** (`…132224425`). "121 kcal", "Rudergerät", 00:12:41, "19 Züge/Min.", "248 Züge".
- **workout-record-02-pace-chart-watch5.png** (`…132139752`). "Tempo"; grey rounded card with an orange line and area, dashed max and min lines labelled 4'54" and 8'20", x 00:00:00 / 00:17:45 / 00:35:30; below "▲ 5'23"" and "Ø 6'35" /km".
- **workout-record-03-pace-zones-watch5.png** (`…132148111`). "Tempo" zones; rows of label, minutes and a thin bar: HIIT-Lauf <1 Min. (red), Anaerob 4 Min. (orange), Laktatschwelle 14 Min. (yellow), Marathon 15 Min. (green), Joggen 1 Min. (blue).
- **workout-record-05 to -14-…-ult2.jpg** (NBC Ultimate 2, `Training1` to `Training10`, newer firmware). Each chart page has a full-screen gradient tinted by metric, and the right-edge dot indicator.
  - 05 summary: "2,48 km", Gehen (Outdoor), 00:29:48, 12'1" /km, 210 kcal.
  - 06 "Tempo": orange gradient `#8D4E1B` to black.
  - 07 "Herzfrequenz": maroon; red line and area; y 144 and 73; "▲137 ▼76 / Ø 116 bpm".
  - 08 "Herzfrequenzzonen": Extrem 0 Min. (red), Anaerob 0 Min. (orange), Aerob 1 Min. (yellow `#F9C21D`), Fettverbrennung 19 Min. (green `#64B95B`), Aufwärmen 6 Min. (blue `#6C9AE5`).
  - 09 "Kalorien": Gesamt 210 kcal, Aktiv 165 kcal.
  - 10 "Höhe" chart: teal gradient `#015B63`, cyan line `#54DEE8`.
  - 11 "Höhe" values: max, min and average.
  - 12 "Kadenz": olive-yellow gradient; "▲112 Ø105".
  - 13 "Schritte": 3134 Schritte, Schrittlänge (Ø) 79 cm.
  - 14 "Trainingsbelastung >": two ring gauges "1,0 Aerob" (blue ring) and "<1,0 Anaerob" (grey ring).
- **workout-record-15-summary-trail-official-gt6pro.jpg** (HW `watch-gt6-pro/images/running/…trail-running-4.jpg`). English summary: "24.29 km / Trail run / 04:57:07 / 12'14" /km / 1,444.1 m".
- No image of the workout-records list was found; only its launcher entry (see launcher-list-05).

### Training status, running ability, recovery
- **training-status-01-training-index-gt5pro-gsmarena.jpg** (GSM `_007`, GT 5 Pro, English).
  - Five-segment bezel arc: red, orange, yellow, green, blue, with a white triangle pointer.
  - "Training index"; "6.2" huge blue (about `#6DA0FB`) with a white "↑"; "You are at peak condition."; "13.4↓ Fitness" | "7.2↓ Fatigue".
  - Navy gradient `#20202A` to `#27446E`.
- **training-status-02-running-ability-official-runner2.jpg** (HW runner-2 `…single-running-ability-index.jpg`). Ring gauge with orange, green and blue segments; "Single RAI"; "58.1" blue; "Performance this time"; "Excellent".
- **training-status-03-predicted-times-official-runner2.jpg** (HW `…performance-prediction.jpg`). "Predicted times ⓘ" table (Distance / Duration / Avg pace) with pill rows: 5 km (blue), 10 km (green), Half marathon (orange), Marathon (red).
- **training-status-04-lactate-running-form-official-runner2.png** (HW `…professional-metrics.png`). Two watches: "Running lactate threshold: 166 Heart rate (bpm) | 3'58" Pace (/km)" and a running-form data screen.
- Recovery: only the "Восстановление 0 ч" header (workout-list-05) and the orange recovery card (cards-03).

### Cycle calendar
- **cycle-calendar-01-official-gt6.png** (HW `watch-gt6/images/women/huawei-watch-gt-6-women-health-1.png`, cropped to the watch). Light theme, gradient from lavender-blue at top to pink at the bottom.
  - "Cycle Calendar" bold black with a small ring icon; month navigation "‹ September 19, Fri ›".
  - Seven-column date grid.
  - Period days 8–12: red numbers on a connected pink blob.
  - Fertile window 18–22: blue numbers on a connected blue blob.
  - Today (19): outlined circle. Day 23: filled blue flower shape.
  - "Edit" pill with red text.

### Launcher
- **launcher-grid-01-watch5.png** (NBC Watch 5, `WatchApScreenshot_…102221`), **launcher-grid-02-gt5pro.png** (3DN `d380c7bf0b2e3daeea5abf95e632a279`), **launcher-grid-03-health-icons-watch5.png** (RZ `tp/tpfNrd4FZ3NB`). Honeycomb grid of round icons on black with fisheye scaling (centre about 110 px, edges about 40 px).
  - Icons visible: Workout (orange, white runner), Activity rings (black with a tri-colour arc), Heart rate (red-pink with a white heart), Sleep (purple moon), SpO2 (red blood cells), Skin temperature (teal thermometer), Health clover (white with a green clover), Stay Fit (white "kcal" gauge), Health Glance (teal heart with stethoscope), Workout records (orange), Workout status (green).
- **launcher-list-01 to -05-…-watch5.jpg** (IXBT `01.39.06-1`, `01.39.06-2`, `01.39.05-2`, `01.39.03-1`, `02.11.21`). List-mode launcher: translucent grey-violet pill rows over a blurred dark background, with a round icon on the left and the name in white medium type; the centre row is larger.
  - Rows include Показатели здоровья (Health Glance), Пульс (Heart rate), ЭКГ (ECG), Статус тренировки (Workout status), Записи активностей (Activity records), Будь в форме (Stay Fit), Дыхательные упражнения (Breathing), Эмоции (Emotional wellbeing).
  - A folder shows Тренировка / Эскиз маршрута / Записи (Workout / RouteDraw / Records).

### Cards and widgets (swipe from the watch face)
- **cards-01-widgets-hr-weather-watch5.png** (NBC Watch 5, `WatchApScreenshot_…102206`). Time at top; grid of round app shortcuts (Phone, Camera, Maps) on the left. A glass pill widget "66 bpm" with a heart icon, and a blue weather card (location, "13°", "23° / 8°"). Horizontal page indicator at the bottom. Blurred blue wallpaper behind.
- **cards-02-hr-chart-spo2-watch5.png** (RZ `F4/F4jpwylzZLX1`). Large red HR card (heart, "-- уд/мин", mini chart 00:00–24:00, ▲ ▼); round stairs widget; "+" add tiles; SpO2 pill widget ("--% / - зад") with a red icon.
- **cards-03-recovery-spo2-watch5.png** (RZ `jv/jvB9Z0BUzRpj`). Phone shortcut, SpO2 pill, distance mini widget, an orange "Восстановление 0 ч" (Recovery) card with a white workout pill, "+" tile.
- **cards-04-health-hr-stress-sleep-spo2-gt5pro.png** (3DN `40f835ed8d518764b4b041d0969ce578`). HarmonyOS 5.0 health card on black. Top: heart with "67 уд/мин" and a red mini chart with 00:00 / 12:00 / 24:00. Middle: three round shortcuts (breathing, skin temp, clover). Bottom: three arc gauges: stress "46", sleep "8.6" (purple), SpO2 "96%".
- **cards-05-workout-shortcuts-rings-gt5pro.png** (3DN `d6c3ad345327e399028e8a0775b516d3`). Four round workout shortcuts (run, walk, cycle, swim) in the centre. Ring progress shown as thin arcs at the bezel with text along the arc: "7885 шага" (green, top), "15 ч" (blue, left), "8 мин" (yellow, right), "261 ккал" (red, bottom).
- **cards-06-shortcuts-weather-gt5pro.png** (3DN `d19ae8d68d285155b66cdec4e41d1386`). Calendar and weather card with Phone, Calendar and Music shortcuts.
- **cards-07-weather-notification-center-watch5.png** (`WatchApScreenshot_…102157`) and **cards-08-music-watch5.png** (RZ `Ir/IrOibJ9Xb6n1`). Stacked glass cards under a large time and date.
- **control-center-01-watch5.png** (`WatchApScreenshot_…102148`). Round glass toggles (settings, find phone, alarm, flashlight), a wide "Schlaf" pill, and a status pill (battery 85, Wi-Fi, NFC).

### Watch faces with complications
- **watch-face-01-steps-kcal-watch5.png** (`WatchApScreenshot_…102142`). Blue vortex face, "10 / 21" digital; curved edge complications "549" (kcal) upper-right and "6659" (steps) lower-right.
- **watch-face-02-bpm-steps-watch5.jpg** (IXBT `01.38.59`). Purple variant; "95 bpm" tab at the right edge; steps "2050".
- **watch-face-03-rings-stress-sleep-official-gt6.png** (HW gt6 `…assistant-3-3.png`). Modular face. Round ring complications: battery "80%" (green ring), sleep "7.8" (purple ring with moon), activity-rings mini (three arcs). Wide pill "36 Normal / Stress" with a teal icon. Curved bezel text "742 hPa" and "2552 m"; date in blue; "LON 02:08".
- **watch-face-04-hr-gauge-official-gt6.png** (`…3-5.png`). "10:08" bold; HR complication = red open-arc gauge with a white pointer, "97" and a heart; temperature gauge "24°" with a multicolour arc; battery ring.
- **watch-face-05-weather-battery-sleep-official-gt6.png** (`…3-8.png`). "10:08:36", blue weather card, battery and sleep rings.
- **watch-face-06-rings-steps-official-watch6.png** and **-07-move-exercise-stand-official-watch6.png** (HW watch-6 `huawei-watch-6-watch-face-4.png` and `-5.png`, 320 px). Complications: emotion flower, mini rings, steps "7645" (green arc with shoe); and separate Move "280" (red arc with flame), Exercise "16" (yellow with runner), Stand "3" (blue with figure), plus a stress gauge "46" and a "16 min Exercise" pill.
- **watch-face-08-steps-subdial-gt5pro.png** (3DN `43b7c24d639f539ee92f69200ebbbeac`). Analogue world-time face with a steps sub-dial "7885".

### Other
- **os-version-01-harmonyos-next-5.1-watch5.jpg** (IP `5-1-1.jpg`). About screen "HarmonyOS NEXT / Версия 5.1.0.108 / HUAWEI WATCH 5".
- **fit4pro-activity-rings.png**, **fit4pro-sleep-score.png**, **fit4pro-watch-face-complications.png** (NBC Fit 4 Pro, `…20250514_162818682`, `…20250502_201914000`, `…20250502_201816896`). Square 412x484; the same apps with a top status row (title left, clock right) and round corner buttons.

## Design language common across screens

- **Backgrounds.** Each health app has its own full-screen vertical gradient: a saturated dark hue at the top fading to near-black at the bottom. Flat black is used only for system lists, the workout list, in-workout data pages and plain value pages.

  | App | Gradient |
  |---|---|
  | Activity | brown `#632800` → black |
  | Heart rate / HRV | maroon `#4A0012` → `#1B040A` |
  | SpO2 / arrhythmia | dark green `#003117` → black-green |
  | Sleep | indigo `#34238B` → `#09012A` |
  | Stress / skin temperature | teal `#005E60` / `#002021` → near-black |
  | Health Glance / Insights | deep green `#00201A` |
  | Training index | navy |

  Emotional wellbeing, Breathing and Cycle calendar use a light theme (mint, cream, lilac or pink) with black text. The GT 6 stress render is also light.
- **Cards.** Content sits on a translucent lighter panel of the same hue (about 8–12 % white overlay) with a 36–44 px radius. The panel often spans the full width, so the round bezel clips its sides. Hairline dividers separate blocks inside a card.
- **Typography.** HarmonyOS Sans, white.
  - Titles: medium or bold, about 30–34 px, centred, often followed by an outlined ⓘ.
  - Hero values: bold, 60–110 px. The unit follows on the same baseline in regular weight at about 35–40 % of the number size.
  - Captions and labels: 60 % white, about 22–26 px.
  - Long titles are clipped or marquee-scrolled, not wrapped.
- **Colour per metric.**
  - Move / calories: red-orange `#F34A29`. Exercise: yellow `#FBCF26`. Stand: blue `#30ADFF`.
  - Heart rate: red-pink (line about `#FF3B5C`). SpO2: green `#76D96C`. Sleep: purple `#A34DFA` (deep violet `#6E37B7`, light lilac `#A473E6`, REM salmon `#D88AA2`).
  - Stress: teal `#2DD7D4`. Skin temperature: teal/cyan. Altitude: cyan `#54DEE8`. Pace: orange. Cadence: yellow.
  - HR zones, low to high: blue `#6C9AE5`, green `#64B95B`, yellow `#F9C21D`, orange, red.
  - Workout accent: orange `#ED6414` (the GO button).
- **Charts.**
  - HR, HRV, pace, altitude: line with a gradient area fill, thin vertical hatch lines, a dotted x axis with three time labels, one or two right-hand y labels, and a white dot on the selected point.
  - SpO2 and stress: thin bars.
  - Min/max always appear under the chart as "▲ value ▼ value" in bold white (the up triangle in the metric colour, the down triangle grey).
  - Range indicators are three-segment horizontal bars with a white triangle marker.
  - Zone breakdowns are label + minutes rows with a thin coloured bar on a dim track.
- **Gauges.** Segmented arcs hug the bezel (stress, training index, in-workout HR zone) with a white triangle pointer. Scores use a full-circle progress ring at the bezel (sleep).
- **Buttons.** The primary action is either a full-width filled arc at the bottom ("GO", "Trainieren", "View on phone") or a centred translucent pill with accent-coloured text ("Measure", "Готово"). Lists are dark-grey pill rows with a round coloured icon on the left and a chevron, toggle or radio on the right; the centre row is scaled up.
- **Page indicators.** Vertical pager: a column of small grey dots following the right bezel curve, with the active one a blue elongated pill; a short handle bar at the bottom centre marks "more below". Horizontal pager: two or three dots at the bottom centre with a blue pill for the active page.
- **Icons.** Glossy 3D glyphs for the hero metric (heart, blood-cell sphere, thermometer disc, flower); flat single-colour pictograms for sports; round filled badges for list icons.
- **Status row in workouts.** A battery pill with the number inside plus the clock: at the top on the start screen, at the bottom on data screens.

## Screens with NO usable image found

- **Stay Fit / calories app screens:** only the launcher icon and name (launcher-grid-02, launcher-list-02). The Huawei support article has a video only.
- **Workout records list:** only the launcher entry, plus the detail pages of a single record.
- **Arterial stiffness standalone app or measurement screen:** only the result card inside Health Glance (health-glance-02, health-glance-04).
- **ECG result screen of the ECG app:** only the recording screens and the result card inside Health Glance.
- **Heart rate app on a round watch as a real capture:** covered only by the Watch D2 square render, the round resting-HR and HRV renders, and the HR card widgets.
- **HR zones page of the Heart rate app:** only the post-workout zones (workout-record-08) and in-workout zone arcs.
- **Breathing exercise in-session screen in the classic (non-panda) style:** only the setup screen.
- **Training status detail pages** (load, recovery time, VO2max): only the training index, RAI, predicted times, and the recovery header and card.
- **Activity rings per-ring hourly charts** (Move / Exercise / Stand bar charts): not found.
- **Health clover detail pages:** only the main page.
- **Anything confirming an "Activity Rings 2.0" redesign.**
