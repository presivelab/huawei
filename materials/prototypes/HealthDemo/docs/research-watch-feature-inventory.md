# HUAWEI WATCH 5 (HarmonyOS 5.1 / 6.0 / 6.1) - watch-side health, fitness and wellbeing inventory

## How to read this report
- Method: WebSearch plus WebFetch. WebFetch returns a model-written summary, not raw page text. Quotes below are what the summaries returned, so treat exact wording as "as summarised".
- Official Huawei support pages are thin on watch-side screen-by-screen layout. For almost every feature I could NOT find a per-screen description. Where a screen order is not given, I say "not confirmed". A developer will have to design screen layouts from the metrics and entry points below, or from a real watch or screenshots.
- Model tags: [W5] = confirmed for WATCH 5. [GT5P], [GT6P], [F4P], [F5], [W4], [Ult2], [D2/D3] as stated. [generic] = a Huawei page for "HUAWEI watch/band" with no model named.
- WebFetch could not read the huaweicentral.com changelog pages (403). The 6.1 changelog comes from huaweiblog.de instead.

---

## 0. Cross-cutting facts

**Firmware versions**
- HarmonyOS 6.0 for WATCH 5: build 6.0.0.119 (GT 5 same build). Sizes quoted: 2.58 GB for W5, 2.85 GB for GT 5.
  - https://www.huaweiblog.de/news/huawei-watch-5-harmonyos-6-update/
  - https://the5krunner.com/2026/03/30/huawei-watch-gt-5-harmonyos-6/
- HarmonyOS 6.1 for WATCH 5: 6.1.0.330 (SP50C432E1R1P1), about 2.65 GB.
  - https://www.huaweiblog.de/firmware/huawei-watch-5-erhaelt-harmonyos-6-1-grosses-firmware-update-mit-neuen-fitness-und-gesundheitsfunktionen/
- The huaweicentral 6.1 article title confirms the rollout to global WATCH 5, but the body was unreadable (403): https://www.huaweicentral.com/harmonyos-6-1-features-rolling-out-to-global-huawei-watch-5/

**Where things live on the watch**
- App list: opened with the Up button (crown) [W5/generic]. Apps named in Huawei pages: Health Glance, Workout, Workout status, Heart rate, SpO2, Sleep, Stress, Skin temperature, Arterial stiffness detection, ECG, Pulse wave arrhythmia analysis, Emotional wellbeing, Breathing exercises, Cycle Calendar, Stay Fit, Activity records, Respiratory Study (name used in the lung-function page).
- Side button: on the watch home screen, "press the side button, select Cycle Calendar".
  - https://consumer.huawei.com/en/support/content/en-us15799828
- X-TAP sensor (W5 and Ultimate 2 only):
  - Press and hold 3 s to start Health Glance.
  - X-TAP is user-assignable to shortcuts: start a workout, real-time heart metrics, stress check, ECG, breathing exercises, app launch.
  - Gesture controls also exist: pinch to answer a call, timer, music, camera shutter.
  - https://consumer.huawei.com/uk/community/healthforward/mastering-the-huawei-watch-5-your-guide-to-quick-smarter-health-tracking/
- "Assistant:TODAY" screen holds cards, including a "Health Insights" card (see 6.1 changes).
- "Health Insights" is described by a reviewer as available in the Huawei Health app (phone) and limited to Watch 4, GT 4, Fit 4 Pro and Watch 5. A separate 6.1 changelog says the Health Insights card on the watch TODAY screen shows running route, cycling route and VO2max. Whether a full Health Insights page exists on the watch is not confirmed.
  - https://www.gsmarena.com/huawei_watch_5_review-news-67939.php

**Sensors**
- Three-in-one X-TAP sensor: ECG electrode, PPG and pressure sensor. Wrist PPG at the back.
  - https://consumer.huawei.com/uk/community/healthforward/huawei-watch-5-with-x-tap-a-60-second-glance-into-your-health/
- Skin temperature sensor: its presence on W5 is confirmed by the Android Authority summary ("skin temperature monitoring"). The Huawei skin-temperature support page names GT 5 Pro, GT 6 Pro, Ultimate, D2, Fit 5 Pro "and others", with no W5 explicit.

**Phone dependency (general)**
- Pairing and sync go through Huawei Health. Several settings can only be changed in the phone app (list per feature below).
- Medical disclaimer on every page: "not a medical device, for reference only", users 18+.

**Unit settings:** temperature unit is set in Huawei Health > Me > Settings > Units > Temperature unit (C or F). https://consumer.huawei.com/uk/support/content/en-gb15985256

---

## 1. Health Glance [W5, also W4, W4 Pro, D2]
- Name: "Health Glance". Location: app list, plus X-TAP long press (3 s) on W5.
  - Support page: "Access the app list and select Health Glance"; grant permissions on first use; tap Measure; follow prompts; report is generated automatically. https://consumer.huawei.com/en/support/content/en-us15952127/
- Duration: about 60 s total (W5 marketing and reviews). Keep the watch face up and stay still.
- Indicator count varies by source (do not hard-code):
  - Community article: "9 key indicators" (average HR, HRV, SpO2, skin temperature, stress, ECG, arterial stiffness, respiratory overview, sleep breathing awareness).
  - Search snippet of the same Huawei community page: "up to 10", with emotion added.
  - Another snippet: "11 key indicators" with "personalized analysis".
  - Support page: heart rate, blood pressure (D series only), SpO2, stress, skin temperature, ECG, arterial stiffness, lung function, "and more". Coronary heart disease and diabetes risk studies exist only on certain models and regions.
  - Sources: https://consumer.huawei.com/uk/community/healthforward/huawei-watch-5-with-x-tap-a-60-second-glance-into-your-health/ and https://consumer.huawei.com/en/support/content/en-us15952127/
- Measurement sequence on W5 (GSMArena review, one source):
  1. ECG, 30 s, finger on the X-TAP electrode.
  2. Vital signs, 15 s: SpO2, HR, stress.
  3. Respiratory check: user coughs 2-3 times towards the watch.
  - Android Authority also says "a few deliberate coughs", with onscreen prompts. https://www.gsmarena.com/huawei_watch_5_review-news-67939.php and https://www.androidauthority.com/huawei-watch-5-review-3563411/
- Respiratory check: category results are "good, average, or poor", from cough-sound analysis. Cough forcefully about 30 cm from the watch, 2-3 times, after a deep breath. https://consumer.huawei.com/uk/support/content/en-gb15950029
- HRV is new on this generation. About 6-7 days are needed to build a baseline.
- The support page lets the user specify the wearing wrist.
- The report is viewable on the watch (app list) and in Huawei Health. Past reports are listed and can be deleted. It can be exported to PDF from the phone app.
- Per-screen layout and exact result wording per indicator: not confirmed.
- Phone: watch-side measurement runs standalone. Report sync and PDF export are in Huawei Health.

## 2. Activity rings / Activity records [generic, W5 listed on Stay Fit pages]
- Watch app: "Activity records". Gestures (support page): swipe left for weekly data, swipe up for daily breakdowns, plus goal editing and reminders (Stand, Progress, Goal reached). https://consumer.huawei.com/en/support/content/en-us15952143/
- Move ring: active calories, "burned in addition to the calories you burn at rest".
- Exercise ring: total minutes of moderate and high intensity, measured with cadence and heart rate. Default goal 30 min. Not adjustable.
- Stand ring: hours in which you stood up and moved for at least one minute. Advice is to stand once per hour between 07:00 and 22:00 and reach 12 or more per day. Not adjustable. https://consumer.huawei.com/en/support/content/en-us00749518/
- Move goal: default and units are not stated in the support pages I read. NOT CONFIRMED. One older page says the three-ring set is steps, exercise and stand, with a 10,000 step default. It is a different (older) ring set and I did not reconcile the two.
- Smart suggestions: personalised fitness suggestions on select devices.
- Goals can also be edited on the phone (Activity rings card, then Edit).

## 3. Heart rate [generic; W5 listed in Health Glance and X-TAP articles]
- Watch app: "Heart rate". Individual measurement: open the app on the watch. This works only if continuous monitoring is OFF, and individual results do not sync to Huawei Health.
- Continuous monitoring: ON by default, which gives a curve. Modes: Smart (adaptive) and Real-time. Both are set in Huawei Health > Heart > Settings.
- Resting HR: bpm, measured while awake and still. Best taken on waking. It is computed automatically when continuous monitoring is on. The watch shows the last 7 days.
- Alerts: High and Low heart rate alert. The thresholds are user-set in Huawei Health. A vibration and a screen alert fire if HR stays above or below the value for more than 10 minutes while resting. In Sleep mode the alert is silent (no vibration). During detected sleep with Sleep mode off, no alert fires until motion is detected. Default values: NOT CONFIRMED.
  - https://consumer.huawei.com/ca/support/content/en-us16066712/
  - https://consumer.huawei.com/en/support/content/en-us00737153
- Workout zones: during a workout the watch shows real-time HR and the zone, and alerts when the upper limit is exceeded.
  - Three calculation methods. Max HR percentage: HRmax = 220 minus age, five zones named Extreme, Anaerobic, Aerobic, Fat-burning, Warm-up. HRR percentage: HRmax minus resting HR, five zones named Advanced anaerobic, Basic anaerobic, Lactate threshold, Advanced aerobic, Basic aerobic. LTHR percentage: from lactate-threshold HR measured on outdoor runs, five zones named Warm-up, Basic aerobic, Advanced aerobic, Lactate threshold, Anaerobic.
  - Running supports all three. Other workouts support Max HR% and HRR%.
  - The zone boundary percentages are NOT given in the pages read.
  - https://consumer.huawei.com/ca/support/content/en-us16053680

## 4. SpO2 [generic; W5 via X-TAP]
- Watch app: "SpO2". Steps: app list, SpO2, Measure, keep still with the screen facing up. https://consumer.huawei.com/en/support/content/en-us15996219/
- Automatic SpO2: toggled in Huawei Health > device > Health monitoring. It measures at rest, such as during sleep or at high altitude. Low SpO2 alert (lower limit user-set, fires while awake) is also set in Health. Default limit: NOT CONFIRMED.
- Duration of a standard measurement: not stated on the support page. NOT CONFIRMED. The W5 community article says "within 10 seconds" for X-TAP SpO2 (Health Glance article), and another W5 article says "about 60 seconds per reading". Treat the figure as inconsistent.
  - https://consumer.huawei.com/uk/community/healthforward/spo2-at-aglance-the-watch-5-with-x-tap/
- Level bands from Huawei's W5 community article: 95-100% normal at sea level, 92-94% borderline, under 92% may indicate hypoxaemia. This is an editorial article, not the support guide. https://consumer.huawei.com/uk/community/healthforward/spo2-at-aglance-the-watch-5-with-x-tap/
- High-altitude W5 article: continuous SpO2 and HRV used while training at altitude. No dedicated altitude alert or threshold UI is mentioned. https://consumer.huawei.com/uk/community/healthforward/optimizing-high-altitude-workouts-with-watch-5/
- A "High altitude monitoring" item appears in the WATCH FIT 5 manual index, with altitude-sickness evaluation. Whether W5 has it as a screen is NOT CONFIRMED. https://www.manuals.co.uk/huawei/watch-fit-5/manual

## 5. Sleep (TruSleep) [generic; W5]
- Watch app: "Sleep" (app list). It shows night sleep and naps and sleep health information. https://consumer.huawei.com/uk/support/content/en-gb16047938
- Stages: deep, light, REM, awake. https://consumer.huawei.com/my/support/content/en-gb16047938/ (search result text).
- TruSleep: ON by default. It is toggled in Huawei Health > Sleep card > settings > Advanced. If it is off, sleep data cannot be obtained.
- "Sleep mode" screen: in the Sleep app, swipe up to More, then Sleep mode. Options are Sleep mode on/off and Schedule (Add time with Bedtime, Wake-up, Repeat). Effects: call notifications and vibration are muted (alarms still sound), raise-to-wake is disabled, and the watch enters Simple mode.
- Nap summary: on certain models, shown when you wake between 12:00 and 15:00. New "Nap Summary" in HarmonyOS 6.1 for W5, which detects daytime sleep phases and gives a personalised analysis. Sleep scoring and analysis quality also improved in 6.1.
- Sleep score range and band names: NOT CONFIRMED in any Huawei source I read. Do not invent them. (A search returned a statement that scores under 80 are worth investigating, from a third-party site, not official.)
- Sleep breathing awareness: covered in section 12.

## 6. Stress [W5 and generic; Stress app]
- Watch app: "Stress". Shows the current stress level and a breakdown by category. https://consumer.huawei.com/uk/support/content/en-gb15502088
- Score scale: 1-99. Bands: Low 1-29, Normal 30-59, Moderate 60-79, High 80-99. https://consumer.huawei.com/sg/support/content/en-gb16016515 (the fetch confirmed the "Low (1-29) through High (80-99)" endpoints, and a search snippet gave the two middle bands).
- Measurement: automatic periodic test, toggled in Huawei Health > Health monitoring > Automatic stress test. It does not run during workouts. https://consumer.huawei.com/en/support/content/en-us00737129 notes the manual "single stress test" from the Health app was discontinued after app version 16.1.4.300.
- Curves in Huawei Health: daily, weekly, monthly, yearly.
- Stress is also one of the Health Glance indicators and an X-TAP shortcut target.
- Note: the same page says stress testing is unavailable on the GT series. The GT 5 Pro / GT 6 families do show stress in other Huawei text. I did not resolve this. Treat GT-series stress availability as unconfirmed.

## 7. Emotional wellbeing [HarmonyOS 6 redesign; W5, GT 5, GT 6 Pro]
- Location: app list ("Emotional wellbeing"), Up button. On phone: Health > Emotional wellbeing. https://consumer.huawei.com/uk/support/content/en-gb16028174
- Emotional wellbeing measures pleasant, neutral or unpleasant emotional state. Stress measures body activation. They can disagree. https://consumer.huawei.com/sg/support/content/en-gb16016515
- HarmonyOS 6 redesign: 12 distinct emotions, based on stress data and self-reporting. Moods are shown as flowers (GT 6 Pro "Emotional Wellbeing 2.0"). A virtual pet leads animated breathing sessions. There is a "Pet Emotions" watch face (Sweet Pet Huahua) and real-time alerts.
  - The 12 emotion names are only partly given by a secondary source (concentration, excitement, tension, anxiety, depression "and more"). Full list NOT CONFIRMED.
  - https://www.huaweicentral.com/huawei-watch-gt-6-pro-emotional-wellbeing-2-0-is-worth-your-attention/amp/ (search snippet only)
  - https://www.huaweiblog.de/news/huawei-watch-5-harmonyos-6-update/
- Breathing from this app: swipe left to start breathing exercises, with "Cuteness relief" or "Stress relief".
- Time ranges in phone app: daily, weekly, monthly, semi-annual, annual.
- Restriction: "not available in European countries" per the support page (the W5 6.0 update article still describes it, so regional availability varies). Users 18+.
- Earlier GT 5 update (5.0.0.159) added "Emotional Health Support: modify the last record". https://m.gsmarena.com/huawei_watch_gt_5_watch_gt_5_pro_new_harmonyos_5_update-news-66544.php

## 8. Breathing exercises [generic]
- Watch app: "Breathing exercises". Cards: "Stress relief" and "Cuteness relief" (the latter only on certain devices). User sets Duration and Pace, then taps the card icon (a flower on the Stress relief card). https://consumer.huawei.com/en/support/content/en-us00737155
- End screen shows post-exercise heart rate, exercise duration and an effectiveness evaluation.
- Default and range values for duration and pace: NOT CONFIRMED. Breathing is also an X-TAP shortcut.

## 9. Skin temperature [GT 5 Pro, GT 6 Pro, Ultimate series, D2, Fit 5 Pro "and others"; W5 listed in reviews]
- Watch app: "Skin temperature". Individual: app list > Skin Temperature > Measure. Continuous: enabled in Huawei Health > device > Health monitoring > Continuous skin temperature measurement, then the watch app shows a curve. https://consumer.huawei.com/uk/support/content/en-gb15985256
- Guidance: wear snugly for at least 10 minutes, dry wrist, wait 30 min after exercise or shower. Purpose is wrist-skin temperature change (during and after exercise), healthy adults 18+. Unit C or F set in Huawei Health.
- It is also a Health Glance indicator. Numeric ranges: NOT CONFIRMED. Related note: Cycle Calendar can use body temperature, HR and respiratory rate to refine predictions on supported models.

## 10. ECG [W5, W4, GT series and others]
- Watch app: "ECG". The W5 uses the X-TAP electrode. The generic page says to rest your arm flat and touch the electrode or crown without pressing it. The recording is 30 s. https://consumer.huawei.com/en/support/content/en-us15914360/
- Results: Sinus rhythm (regular, 50-110 bpm), Atrial fibrillation (irregular, 50-110 bpm), Inconclusive (extreme HR, poor signal, unclassifiable).
- After recording, the user can add symptoms: chest tightness, chest pain, anxiety, shortness of breath, dizziness, fatigue, poor sleep, cold/fever, other. Phone Health also shows a report.
- Huawei quotes 99.4% sensitivity and 93.7% specificity in a 629-person study for sinus vs AF. Regional availability applies. Needs the Huawei Health app activation on first use (watch ECG app feature is activated from the phone's Heart screen, ECG icon).

## 11. Arterial stiffness detection [W5, W4, GT 5 Pro, GT 6 Pro, F4 Pro, GT 3 Pro, GT Runner 2]
- Watch app: "Arterial stiffness detection" > Measure. Rest the arm flat, press one finger on the electrode or X-TAP sensor. About 30 s, stay still, breathe evenly, no talking. Dry skin hurts accuracy. https://consumer.huawei.com/qa/support/content/en-gb15905697
- Results: normal, slightly poor, suspected sclerosis (from a search snippet of the support page set).
- Based on pulse wave velocity (PWV). Not for under 18s, pacemaker wearers or serious arrhythmia. Results appear on the Huawei Health app home screen and the history is in the app.
- Numeric PWV values or units on the watch screen: NOT CONFIRMED.

## 12. Pulse wave arrhythmia analysis [generic; W5 listed in the manual index]
- Watch app: "Pulse wave arrhythmia analysis" > Measure. The forearm must rest flat. It uses the PPG sensor. It must first be activated in Huawei Health > Heart > Pulse wave arrhythmia analysis. https://consumer.huawei.com/en/support/content/en-us15910218/
- Automatic detection: runs while worn at rest, with optional arrhythmia alerts. Alerts fire only if abnormal results are frequent across several measurements.
- Result wording differs between my two reads of the same support set. The fetched page says "No abnormalities or Suspected A-fib". A search snippet lists five: No abnormalities, Risk of premature beats, Risk of A-fib, Suspected premature beats, Suspected A-fib. Treat the five-value list as unverified.
- Duration of a measurement: NOT CONFIRMED.

## 13. Sleep breathing awareness [W5 in Health Glance; GT 5 Pro, Fit 3/4, Ultimate 2, GT 6 Pro etc.]
- It detects breathing interruptions in sleep. Levels: Low, Moderate, High (search snippet). It runs automatically overnight. https://consumer.huawei.com/ca/support/content/en-us15972611/
- It is enabled from Huawei Health > Sleep card > bottom of the screen > Sleep breathing awareness (onscreen setup on first use). The result and records are shown in the phone app. Whether a dedicated watch-side screen exists: NOT CONFIRMED. It is a Health Glance indicator. Only available in certain markets.

## 14. Cycle Calendar [W5, Fit 5, GT, Ultimate]
- On the watch: press the side button on the home screen, select Cycle Calendar, and mark the start and end of the period. https://consumer.huawei.com/en/support/content/en-us15799828
- Views: monthly view and a ring chart. Records list lets you edit entries. The predicted period is shown with a dotted line. Ovulation window and fertile period are predicted. https://consumer.huawei.com/uk/support/content/en-gb15972610
- Records: period start and end, physical symptoms, average cycle length, average period length.
- Needs the feature package to be downloaded via the Huawei Health Cycle Calendar card first. Reminders (period start/end, fertile window start/end) are set in the phone app. "Use wearable to improve predictions" uses body temperature, HR and respiratory rate on compatible models.

## 15. Stay Fit [W5, W4, GT 5 Pro, Fit 3/4]
- Watch app: "Stay Fit" (Up button, app list). Authorisation screen ("Agree") on first use. https://consumer.huawei.com/uk/support/content/en-gb15972613
- Setup fields: Weight, Goal type, Rate of loss, Target weight. The watch then generates a weight loss or weight maintaining plan.
- Functions: weight logging on the watch, meal logging (quick entries on the watch, detailed records via the phone), calorie display with active and resting calories, workout entry, reminders and a toggle for linking to Activity rings.
- Screen-by-screen order and calorie budget numbers: NOT CONFIRMED.

## 16. Workout (modes, in-workout behaviour) [W5, generic]
- Watch app: "Workout". Swipe up/down, touch a mode to start. Custom and Reorder let you edit the list. https://consumer.huawei.com/en/support/content/en-us15771839/
- Controls: pause with the side or Up button; resume by pressing again and touching the resume icon; end by holding the side button or touching the end icon. Swipe during a workout for more data pages. Options on certain models: warm-up demos, always-on screen, audio broadcast volume, auto-pause.
- W5 mode count: Android Authority says "over 100 workout modes". Per-mode data fields: NOT CONFIRMED (not in the sources).
- HarmonyOS 6.0 added: a right-swipe quick settings screen mid-workout (reminder volume etc.), training shortcuts screen, pairing with external heart rate monitors, power meters, speed sensors and cadence sensors, golf mode (panoramic fairway and green views, distance measuring), trail running elevation chart and segment navigation. https://www.huaweiblog.de/news/huawei-watch-5-harmonyos-6-update/
- HarmonyOS 6.1 added (W5): cycling with virtual cadence, virtual power, gradient, bike type, and FTP calculation with a compatible power meter; smarter running training (speed analysis, training load assessment); improved automatic training segment detection and interval reminders. https://www.huaweiblog.de/firmware/huawei-watch-5-erhaelt-harmonyos-6-1-grosses-firmware-update-mit-neuen-fitness-und-gesundheitsfunktionen/
- Phone: workouts can run standalone. Summary and data sync to Huawei Health.

## 17. Workout status [generic; W5 includes it via training features]
- Watch app: "Workout status" (app list); swipe up for the pages. https://consumer.huawei.com/en/support/content/en-us00736792
- Items in order named by Huawei: Running Ability Index, Training load, Training index, Recovery, Predicted times, VO2max.
- Training load levels (colour in parentheses): Low (blue), Moderate (green), High (orange), Excellent (red). Based on the total workout amount over the last 7 days and fitness status.
- Recovery: hours until the body returns to 100%. It depends on intensity and duration.
- RAI and Training index apply to running modes only (outdoor, indoor, trail). Recovery and training load are not available for swimming and rope skipping.
- VO2max definition as above. Numbers and category bands for VO2max, RAI scale and training index: NOT CONFIRMED.

## 18. Fall detection and Emergency SOS [W3/4/5, GT 6, Ultimate 2]
- Setting: watch Settings > Emergency SOS > Fall detection toggle. It uses the accelerometer. A pop-up asks whether to make an emergency call. If there is no answer or you choose yes, SOS is triggered after 60 s. The first emergency contact is called and all contacts get messages. https://consumer.huawei.com/ca/support/content/en-us16066705
- This is a system feature, not a health app. The default state on is NOT CONFIRMED.

## 19. Other health-adjacent items mentioned
- Wheelchair mode: listed in the Fit 5 manual index. W5 not confirmed. https://www.manuals.co.uk/huawei/watch-fit-5/manual
- Barometer / altitude and compass: only a support article on inaccurate altitude/pressure data was found. No health content. https://consumer.huawei.com/en/support/content/en-us00733905/
- Health Insights notifications and personalized alerts when readings deviate: mentioned for W5 X-TAP articles. Thresholds NOT CONFIRMED.
- Watch faces that show health state: "Sweet Pet Huahua" (emotion), Sweet Companions and Dream Star (6.1), Module 2025, Sticker Fun. Complication data fields available: NOT CONFIRMED.

---

## Things I looked for and could not find
- Official screen-by-screen watch UI for any of these apps (page order, chart types, time axes, button labels). Not in the support pages or reviews I reached.
- Default Move goal and Move ring unit.
- Sleep score range, band names, and a list of sleep metrics shown on the watch.
- HR zone percentage boundaries, default high/low HR alert values, default low SpO2 alert value.
- HRV unit, range and watch-side display; respiratory rate display and units.
- Skin temperature numeric range or presentation (absolute vs deviation from baseline).
- Full list of the 12 emotions and the flower/pet states; breathing exercise default duration and pace.
- Full list of W5 workout modes and per-mode data fields; VO2max, RAI, training index bands.
- Raw HarmonyOS 6.1 huaweicentral changelog text (403). The huaweiblog.de summary was used.
- High-altitude monitoring as a distinct watch screen on W5.
- Whether the W5 shows a "Health Insights" page on the watch itself.
