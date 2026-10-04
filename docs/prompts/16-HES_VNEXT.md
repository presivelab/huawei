> Public-safe copy of a team brief (in Polish) that was handed to a coding-agent session as its standing instruction during HackYeah 2026. Kept as written; which briefs are still in force is listed in `docs/prompts/README.md`.
> The paste of this brief was cut by the 50,000-character limit of the chat input, in the middle of Appendix C (the reference oracle). The text below is everything that arrived, unchanged. How the oracle was completed is written in the header of `tools/hes_vnext_oracle.cjs`.

# WKLEJKA — HES vNext w FairWear + Health Sim (telefon + zegarek)

> Wklej całość do Claude Code otwartego w repo FairWear (`C:\dev\FairWear` albo worktree z najnowszym zintegrowanym kodem).
> To jest **polecenie do wykonania od razu**, nie raport do przeczytania. Pracujesz fazami 0→7, commit po każdej fazie.

---

## 0. Zasady pracy (obowiązują przez cały task)

1. **Wykonuj.** Nie czekaj na potwierdzenie między fazami. Pytasz użytkownika tylko w sytuacjach z pkt 6.
2. Najpierw krótki audyt read-only (Faza 0), potem budowa.
3. **Jeden silnik HES vNext w `common`**, używany przez FairWear (telefon) i Health Sim. Zero przepisanych kopii formuł w innych modułach. **Zegarek nie liczy HES.**
4. **Nie zmieniaj:** reguł noszenia i flag (BreakRuleChecker, progi w `defaults.ets`), kryptografii (ProofSigner, CryptoUtil, verifyClaim), pól TierClaim (patrz D14), wyników wear-compliance person (Marek flagged, 4 czerwone dni, brak benefitu; Kasia 1 suspicious break, bez flagi).
5. Git: nowa gałąź `feature/hes-vnext` od gałęzi z najnowszym kodem (ustalasz w audycie). Commit po każdej fazie (`feat(hes): …`, `test(hes): …`, `docs(hes): …`). **Nie pushuj bez wyraźnej zgody użytkownika. Repo zostaje PRYWATNE — nigdy nie zmieniaj widoczności.**
6. Zatrzymaj się i zadaj użytkownikowi **jedno** pytanie tylko gdy: (a) nie da się jednoznacznie ustalić, która gałąź ma najnowszy kod; (b) nie znajdujesz projektu Health Sim na tej maszynie; (c) zmiana wymagałaby złamania pkt 4.
7. **Złote wartości person i liczby w testach zostały policzone implementacją referencyjną (Załącznik C) i sprawdzone drugą, niezależną implementacją** (listy Why, effective weights i testy 3, 4, 8, 9 — tylko tą drugą). Jeśli twój wynik się różni, błąd jest w kodzie, nie w złotych wartościach. Nie dostrajaj testów do kodu.
8. Komentarze w kodzie, UI i docs po angielsku. Nie twierdź, że HES coś "predicts", jest "validated", mierzy "risk", jest "AI", ocenia "healthy/unhealthy" czy stawia "diagnosis". Zakaz dotyczy twierdzeń o produkcie — zastrzeżenia typu "not clinically validated" czy "not AI / ML" są wymagane i zostają. HES to deterministic rules and curves, not ML.
9. Po każdej fazie: lint ArkTS + build (entry, watch, common, Health Sim) + testy logiczne (`tools/run-logic-tests.sh` lub odpowiednik). Wszystko zielone przed commitem.

---

## 1. Co budujemy

Spec HES vNext (Załącznik A — źródło prawdy) **zastępuje HES-Lite v1.0**. W skrócie: dwa profile wag (HEALTH_WELLNESS, LONGEVITY_WELLNESS), 8 komponentów (5 Core + 3 opcjonalne), okna 28/14/60/90 dni z minimalną i docelową liczbą pomiarów, jawna renormalizacja przy brakujących opcjonalnych, Evidence Coverage, Data Confidence, tier A/B/C albo "No score yet". **Brak danych nigdy nie jest zerem. Bieżący dzień nigdy nie wchodzi do HES przed "Close the day".**

"Obie apki" = **FairWear** (moduł `entry` na telefonie + `watch`) oraz **Health Sim** (symulator HUAWEI Health; telefon + moduł zegarka, jeśli istnieje):

| Gdzie | Rola w vNext |
|---|---|
| `common` | silnik vNext + generator person — jedno źródło prawdy |
| Health Sim | generuje, przechowuje i pokazuje surowe dane, których vNext potrzebuje; po zgodzie przekazuje je FairWear (kontrakt v2); ekran "FairWear readiness" z podglądem HES liczonym tym samym silnikiem |
| FairWear telefon | liczy HES vNext z danych z Health Sim i pokazuje go na wszystkich ekranach |
| FairWear zegarek | pokazuje dane na żywo z etykietą "Live · not scored"; nigdy nie liczy HES |

---

## 2. Faza 0 — Audyt (read-only, krótko)

Zapisz wynik do `docs/hes-vnext-audit.md` (tabela: *co | ścieżka | stan*). Ustal:

- gałąź/worktree z najnowszym zintegrowanym kodem: `git worktree list`, `git log --all --oneline --graph -30`; porównaj m.in. `feature/engine-reports`, `docs/final-polish`, `fix/audit`, `main`;
- silnik HES-Lite: pliki w `common/src/main/ets/hes/` (typy, krzywe, wagi, session, mapper, persony), eksporty w `common/Index.ets`;
- generator person (HesPersonas / ReportBuilder): jakie pola ma dzień historii, jak są generowane;
- HesSession (live / setLive / closeDay / resetDemo), EngineFairWearService, HesMapper, `ui/service/FairWearContract.ets`;
- wszystkie miejsca UI, które pokazują score / tier / coverage / confidence / komponenty — w `entry`, `watch` i Health Sim (grep: `coverage|confidence|tier|HesResult|score`);
- **Health Sim:** gdzie jest projekt (osobny projekt DevEco `com.fairwear.healthsim`? inny katalog w `C:\dev`?), jego generator danych i persony, kanał przekazania danych do FairWear (openLink / startAbilityForResult / parametry Want / plik?), schemat i wersja payloadu, czy ma moduł zegarka;
- TierClaim: aktualne pola i czy jest pole wersji;
- testy: runner, liczby (common / watch / Health Sim), które testy dotyczą HES-Lite (do wymiany);
- docs: `docs/HES.md`, README ("real vs simulated"), `AI_WORKFLOW.md`, `docs/REQUIREMENTS_CHECK.md`, `docs/test-results.txt`, `docs/screenshots/`, `docs/prompts/`, skrypt demo.

Potem: `git switch -c feature/hes-vnext` od właściwej gałęzi.

---

## 3. Decyzje wiążące (rozstrzygają niejasności specu)

- **D1. Znaki "≥".** W oryginale specu część "≥" zgubiła się przy kopiowaniu (np. `= 95 -> 100`, `HIGH: = 0.80`). Czytaj: ostatni punkt każdej krzywej to "≥ x → y"; HIGH = CI ≥ 0.80; MEDIUM = 0.60 ≤ CI < 0.80. Załącznik A ma już przywrócone znaki (10 linii, nic poza tym nie zmieniono).
- **D2. Wagi w promilach (int).** HW: crf 125, rhr 125, mvpa 200, steps 150, sleepRegularity 150, sleepDuration 125, hrv 75, hrr 50. LW: crf 225, rhr 150, mvpa 150, steps 175, sleepRegularity 100, sleepDuration 75, hrv 75, hrr 50. Coverage liczona w promilach (int), wyświetlana jako %: `47.5%`, `75%`, `87.5%`. Powód: na floatach suma wag LW wychodzi 0.9999999999999999, a coverage 54.99999999999999 (sprawdzone).
- **D3. Zaokrąglenie:** `hes = Math.floor(observed + 0.5 + 1e-9)` (84.49→84, 84.50→85, odporne na błąd floata). Progi confidence porównuj z tolerancją 1e-9. Effective weight wyświetlaj z 1 miejscem po przecinku tą samą regułą (np. 150/800 = 18.75% → `18.8%`).
- **D4. Ważność danych ustala źródło** (Health Sim / API). Wartość jest ważna, gdy jest obecna, skończona i ≥ 0. Brak / null / NaN / Infinity / wartość ujemna = nieważna, czyli nie liczona. HES nie wymyśla progów fizjologicznych (spec §4). Bez interpolacji, uzupełniania i ekstrapolacji.
- **D5. MVPA tygodniowo = średnia(dzienny ekwiwalent z ważnych dni) × 7**, gdzie dzienny ekwiwalent = moderate + 2 × vigorous (dzień ważny tylko, gdy oba pola są ważne). Przy 28 ważnych dniach to dokładnie SUM/4 ze specu; przy mniejszej liczbie dni nie traktuje brakującego dnia jak 0 minut (spec: missing never 0). **To świadome odstępstwo od dosłownego wzoru** — opisz je w docs jako odstępstwo. Dla porównania: dosłowne SUM/4 dałoby Kasi MVPA 70 → HW 69 B, a Ewie MVPA 50 → HW 56 C.
- **D6.** Mediana parzystej liczby elementów = średnia dwóch środkowych.
- **D7.** SD = odchylenie **populacyjne** (÷ n). TimingSD = √((bedSD² + wakeSD²) / 2), liczone na minutach względnych `(m − 1080 + 1440) % 1440`.
- **D8. Noc należy do daty pobudki** i wchodzi do historii razem z tym dniem przy "Close the day". Wcześniej się nie liczy (niezamknięty dzień/noc).
- **D9. Okna** liczysz w dniach kalendarzowych wstecz od ostatniego zamkniętego dnia (`daysAgo 0` = ostatni zamknięty dzień): steps / mvpa / rhr / sen = 28 dni (0..27), HRV = 14 nocy (0..13), HRR = 60 dni (0..59), CRF = 90 dni (0..89). `validCount` = liczba ważnych pomiarów w oknie. W produkcji dzień zamyka się automatycznie o północy; w demo — przyciskiem "Close the day".
- **D10. HRV:** tylko protokół `nocturnal` (stała `HRV_PROTOCOL`); rekordy innego protokołu pomijasz (nie liczą się do validCount). Agregat = mediana nocnych percentyli (percentyl, już znormalizowany, dostarcza źródło). Nigdy nie wyliczaj HRV z HR.
- **D11. CRF:** wejście to percentyl VO₂max znormalizowany wiekiem i płcią (dostarcza źródło). Agregat = najnowsze ważne oszacowanie w oknie 90 dni; validCount = liczba oszacowań w oknie. Nigdy nie wyliczaj CRF ze steps/MVPA.
- **D12. HRR:** sesja = {date, protocolId, peakHr, hr60}; HRR1 = peakHr − hr60 (sesja ważna, gdy peakHr > hr60). Porównywalne = sesje protokołu, który ma najwięcej sesji w oknie 60 dni (remis → protokół najnowszej sesji). Dzięki temu jedna nowa sesja innego protokołu nie wyłącza HRR. Agregat = mediana HRR1 porównywalnych sesji; validCount = ich liczba. HRR2/HRR3 nie istnieją w modelu.
- **D13. Profile.** Domyślny jest HEALTH_WELLNESS. Przełącznik profilu na Dashboardzie i w "Why this tier" służy tylko do objaśnienia. Share/QR, eligibility i benefit zawsze liczysz profilem partnera; partner demo = HEALTH_WELLNESS (stała w konfiguracji partnera). Share pokazuje "Profile: Health & wellness (set by partner)".
- **D14. TierClaim bez wyniku.** Claim nigdy nie zawiera score, coverage, confidence ani komponentów. Jeśli claim ma już pole wersji (`version`/`v`), ustaw wartość identyfikującą model, np. `hes-vnext-hw`. Jeśli nie ma — nie dodawaj żadnych pól i nie ruszaj krypto. Testy krypto (tampered tier → Invalid signature, replay → Already used, tampered nonce → Invalid signature) przechodzą bez zmian. QR ≤ 512 znaków.
- **D15. "Why this tier".** Strongest = dostępne komponenty, score malejąco, top 3. To improve = dostępne komponenty **spoza Strongest**, score rosnąco, max 3 (przy 5 dostępnych zostają 2 pozycje — bez duplikatów). Remis = różnica wyników < 1e-9; wtedy najpierw wyższa waga bazowa, potem stała kolejność: crf, rhr, mvpa, steps, sleepRegularity, sleepDuration, hrv, hrr. Brakujące opcjonalne pokazujesz osobno jako "Missing data (optional)" z "n of min" — nigdy w To improve, nigdy z wynikiem 0, nigdy jako czynnik negatywny. Effective weight pokazujesz przy komponentach, gdy coverage < 100%.
- **D16. Stan bez wyniku** (Core niekompletne): "No score yet", Evidence coverage, "Measured so far" (wartości surowe + liczba dni, **bez** wyników komponentów), "Needed for a score" (np. "Sleep timing regularity — 6 of 14 nights"), opcjonalne brakujące osobno. Brak tieru; Share pokazuje Tier "Not available"; nigdy Tier C.
- **D17. Live.** Live HR i dzisiejsze kroki zmieniają tylko kartę Live ("Live · not scored"). `closeDay()`: do historii trafia kopia rekordu `today` z `steps` = aktualna wartość live steps (historyLength + 1); okna przesuwają się, a agregaty, komponenty i HES są przeliczane. Nowy `today` = **szablon z eksportu Health Sim** (steps = bazowe dzienne kroki persony — nie 0). Nigdy nie zapisuj 0 tylko dlatego, że wartość live została wyzerowana albo nie była ustawiona — brak wartości = pole nieobecne. restingHr zamykanego dnia pochodzi z dziennego rekordu źródła, **nigdy z live HR**. `resetDemo()` przywraca snapshot otrzymany z Health Sim.
- **D18.** Zegarek nie liczy HES ("the watch measures, the phone judges"). Jeśli UI zegarka pokazuje tier/score z HES-Lite — usuń to albo zastąp tekstem "Score on phone".
- **D19. Jedno źródło prawdy.** Silnik i generator person istnieją tylko w `common`. Health Sim korzysta z `common` jako zależności (ohpm `file:` do modułu albo do HAR). Jeśli to technicznie niemożliwe (osobny projekt/bundle) — zbuduj `.har` z `common` i podłącz go skryptem `tools/sync-common-har.*`. Ostateczność: kopia generowana skryptem + test sum kontrolnych, który failuje przy rozjechaniu. Nigdy ręcznie przepisanych formuł.
- **D20. Kontrakt Health Sim → FairWear jest wersjonowany** (`schema: "fairwear.health-export"`, `version: 2`). FairWear odrzuca payload innej wersji komunikatem "Health Sim data format is outdated — update Health Sim" i niczego nie liczy (nie zamienia braków na 0).
- **D21. Benefit/eligibility:** zostaje obecna reguła (compliance ≥ próg AND not flagged AND HES status OK) — tylko status OK pochodzi teraz z vNext (profil partnera).
- **D22. Nazewnictwo:** w docs model nazywa się "HES vNext"; stała `HES_MODEL_VERSION = 'vnext-1'`. W UI bez nazwy wersji — wystarczy "Health Engagement Score".
- **D23. Brak `Date.now()` w silniku i generatorze.** Dzień "today" jest parametrem (`today: 'YYYY-MM-DD'`, lokalnie); testy używają stałej daty `2026-10-04`.

---

## 4. Faza 1 — Silnik vNext w `common`

Zastąp HES-Lite (nie trzymaj dwóch silników). Dopasuj nazwy plików do istniejącej struktury `common/src/main/ets/hes/`:

- **`HesTypes.ets`** — wg specu §15:
  - string enums: `HesProfile { HEALTH_WELLNESS, LONGEVITY_WELLNESS }`, `ComponentId { crf, rhr, mvpa, steps, sleepRegularity, sleepDuration, hrv, hrr }`, `HesTier { A, B, C, NONE }`, `HesConfidence { HIGH, MEDIUM, LOW, NOT_ENOUGH_DATA }`, `HesStatus { OK, INSUFFICIENT_DATA }`;
  - `ComponentResult { id; label; rawValue?; score?; available; requiredCore; validCount; minimumCount; targetCount; quality; baseWeight /* 0..1 */; effectiveWeight? }`;
  - `HesResult { profile; score?; observed? /* testy i debug, nie UI */; tier; coverage /* % */; coveragePermille /* int */; confidence; confidenceIndex?; status; components: ComponentResult[]; modelVersion }`;
  - wejście: `HesDayRecord { date /* YYYY-MM-DD */; steps?; moderateMin?; vigorousMin?; restingHr?; sleep?: HesSleep; hrv?: HesHrvNight }`, `HesSleep { bedMin; wakeMin; totalSleepMin }` (minuty od północy, czas lokalny), `HesHrvNight { percentile; protocol }`, `HesCrfEstimate { date; percentile }`, `HesHrrSession { date; protocolId; peakHr; hr60 }`, `HesHistory { days: HesDayRecord[] /* tylko zamknięte, rosnąco */; crf: HesCrfEstimate[]; hrr: HesHrrSession[] }`.
- **`HesModel.ets`** — wagi w promilach (D2), CORE, liczności min/target (steps 14/21, mvpa 14/21, rhr 10/14, sleepDuration 14/21, sleepRegularity 14/21, hrv 7/14, crf 1/2, hrr 2/3), krzywe (Załącznik A §5), okna 28/14/60/90, `HRV_PROTOCOL = 'nocturnal'`, etykiety, `HES_MODEL_VERSION`.
- **`HesCurves.ets`** — `piecewise(points, x)`: ≤ pierwszy x → pierwszy y; ≥ ostatni x → ostatni y; interpolacja liniowa; clamp 0–100; dokładny punkt → dokładny wynik; nieskończone x → undefined (nigdy NaN).
- **`HesAggregate.ets`** — `aggregate(history)` → dla każdego komponentu `{ raw?: number, validCount: number }` wg D4–D12.
- **`HesEngine.ets`** — `computeHes(profile, history): HesResult`: aggregate → komponenty → kompletność Core → renormalizacja (§8) → effective weights (§9) → confidence (§10) → tier (§11). Czyste funkcje: zero I/O, zero zegara.
- **`HesExplain.ets`** — `strongest`, `toImprove`, `missingOptional`, `missingCore`, `pointsToNextTier` (B: 80 − HES, C: 60 − HES, A: undefined) wg D15/D16.
- **`HesSession.ets`** — zachowaj API (live / setLive / closeDay / resetDemo); stan = snapshot historii + rekord `today` + live HR/steps; `current(profile)` = `computeHes(profile, history)`; closeDay/reset wg D17.
- `common/Index.ets` — eksporty; kolizje nazw aliasuj jak dotąd (np. `median → hesMedian`).

Ograniczenia ArkTS: jawne interfejsy/klasy zamiast literałów obiektów bez typu, bez `any`, bez spread na obiektach i bez destrukturyzacji tam, gdzie linter tego zabrania.

---

## 5. Faza 2 — Persony (generator w `common`) + złote wartości

Przepisz dane HES person na deterministyczny przepis z **Załącznika B** (bez RNG). Wear/compliance/kalendarz person zostają bez zmian. Test porównuje agregaty i wyniki komponentów (tolerancja 1e-9; wartości z 2 miejscami jak 73.33 → 5e-3), HES, tier, coverage, confidence oraz observed i CI (podane do 3 miejsc → tolerancja 5e-4) dla **obu** profili.

### 5.1 Złote wartości

| Persona | Agregaty: raw (validCount) | HEALTH_WELLNESS | LONGEVITY_WELLNESS |
|---|---|---|---|
| **Ania** | crf 77 (2) · rhr 58 (28) · mvpa 238 (28) · steps 8800 (28) · sleepReg 45 min (28) · sleepDur 7.4 h (28) · hrv 60 (14) · hrr 32 (3) | **92 · A · 100% · HIGH** | 92 · A · 100% · HIGH |
| **Marek** | crf — (0) · rhr 68 (28) · mvpa 119 (28) · steps 6200 (28) · sleepReg 70 (28) · sleepDur 6.6 (28) · hrv 40 (14) · hrr 24 (3) | **75 · B · 87.5% · HIGH** | 76 · B · 77.5% · MEDIUM |
| **Kasia** | crf — (0) · rhr 72 (18) · mvpa 98 (20) · steps 6000 (20) · sleepReg 70 (16) · sleepDur 6.4 (16) · hrv n/a (4) · hrr — (0) | **73 · B · 75% · MEDIUM** | 74 · B · 65% · LOW |
| **Tomek** | crf 50 (2) · rhr 62 (28) · mvpa 147 (28) · steps 7000 (28) · sleepReg 80 (28) · sleepDur 6.5 (28) · hrv — (0) · hrr 27 (3) | **79 · B · 92.5% · HIGH** ("1 point to A") | 79 · B · 92.5% · HIGH |
| **Ewa** | crf — (0) · rhr 76 (20) · mvpa 70 (20) · steps 4400 (20) · sleepReg 85 (16) · sleepDur 6.2 (16) · hrv n/a (3) · hrr 20 (2) | **59 · C · 80% · MEDIUM** | 59 · C · 70% · MEDIUM |
| **Ola** | crf — (0) · rhr 68 (16) · mvpa 112 (16) · steps 6800 (16) · sleepReg n/a (6) · sleepDur n/a (6) · hrv n/a (6) · hrr — (0) | **No score · NONE · 47.5% · NOT_ENOUGH_DATA** | No score · NONE · 47.5% · NOT_ENOUGH_DATA |

`n/a` = są pomiary, ale poniżej minimum → komponent niedostępny.

**Observed przed zaokrągleniem (HW / LW):** Ania 92.115 / 91.775 · Marek 75.223 / 75.811 · Kasia 72.967 / 74.151 · Tomek 78.930 / 79.148 · Ewa 58.802 / 58.979.
**Confidence index (HW / LW):** Ania 1.000 / 1.000 · Marek 0.875 / 0.775 · Kasia 0.668 / 0.593 · Tomek 0.925 / 0.925 · Ewa 0.701 / 0.626.

### 5.2 Wyniki komponentów (krzywe są wspólne, więc HW = LW)

| Persona | crf | rhr | mvpa | steps | sleepReg | sleepDur | hrv | hrr |
|---|---|---|---|---|---|---|---|---|
| Ania | 89.2 | 97 | 93.2 | 97 | 90 | 99 | 81 | 74 |
| Marek | — | 86.4 | 67.6 | 82 | 73.33 | 84.6 | 65 | 55 |
| Kasia | — | 80.8 | 59 | 80 | 73.33 | 78.6 | — | — |
| Tomek | 70 | 93 | 78.8 | 90 | 66.67 | 82 | — | 62.5 |
| Ewa | — | 74 | 45 | 56 | 63.33 | 71.8 | — | 38.33 |

### 5.3 Why this tier (oba profile identyczne)

- **Ania** — Strongest: Sleep duration 99, Daily steps 97, Resting HR 97 · To improve: HRR 74, HRV 81, VO₂max 89.2 · Missing: —
- **Marek** — Strongest: Resting HR, Sleep duration, Daily steps · To improve: HRR, HRV, MVPA · Missing (optional): VO₂max 0 of 1
- **Kasia** — Strongest: Resting HR, Daily steps, Sleep duration · To improve: MVPA, Sleep timing regularity · Missing (optional): VO₂max 0 of 1, HRV 4 of 7 nights, HRR 0 of 2 sessions
- **Tomek** — Strongest: Resting HR, Daily steps, Sleep duration · To improve: HRR, Sleep timing regularity, VO₂max · Missing (optional): HRV 0 of 7 nights
- **Ewa** — Strongest: Resting HR, Sleep duration, Sleep timing regularity · To improve: HRR, MVPA, Daily steps · Missing (optional): VO₂max 0 of 1, HRV 3 of 7 nights
- **Ola** — No score yet · Measured so far: Steps 6,800/day (16 days), MVPA 112 min/week (16 days), Resting HR 68 bpm (16 days) · Needed for a score: Sleep timing regularity 6 of 14 nights, Sleep duration 6 of 14 nights · Optional, not yet: VO₂max 0 of 1, HRV 6 of 7 nights, HRR 0 of 2 sessions

**Effective weights (HW, gdy coverage < 100%):**
Marek — rhr 14.3 · mvpa 22.9 · steps 17.1 · sleepReg 17.1 · sleepDur 14.3 · hrv 8.6 · hrr 5.7 (%)
Kasia — rhr 16.7 · mvpa 26.7 · steps 20.0 · sleepReg 20.0 · sleepDur 16.7
Tomek — crf 13.5 · rhr 13.5 · mvpa 21.6 · steps 16.2 · sleepReg 16.2 · sleepDur 13.5 · hrr 5.4
Ewa — rhr 15.6 · mvpa 25.0 · steps 18.8 · sleepReg 18.8 · sleepDur 15.6 · hrr 6.3

### 5.4 Zmiany względem HES-Lite v1.0 (świadome — zaktualizuj testy, docs, skrypt demo)

| Persona | HES-Lite v1.0 | HES vNext (HW) |
|---|---|---|
| Ania | A/92, 100%, High | A/92, 100%, High — bez zmian |
| Marek | B/75, 85%, High, flagged | B/75, **87.5%**, High, flagged |
| Kasia | B/73, 70%, Medium | B/73, **75%**, Medium (w vNext bez kompletu Core nie ma wyniku, więc minimum to 75%) |
| Tomek | B/79, 90%, High, "1 point to A" | B/79, **92.5%**, High, "1 point to A" |
| Ewa | C/59, 75%, Medium | C/59, **80%**, Medium |
| Ola | no score, 43% | no score, **47.5%** |

Benefity bez zmian: Ania full, Kasia partial, Marek brak (flagged), Ewa brak.

---

## 6. Faza 3 — Health Sim

1. **Dane.** Health Sim serwuje persony z generatora w `common` (D19): te same 6 osób (Ania, Marek, Kasia, Tomek, Ewa, Ola), ta sama historia. Do tego rekord `today` (szablon, deterministyczny): steps = bazowe dzienne kroki persony (A), moderate/vigorous = bazowy dzienny ekwiwalent persony rozbity regułą z Załącznika B, restingHr = bazowe RHR persony, sen z ostatniej nocy = wzorzec bazowy (bez przesunięcia, total = bazowy czas snu), HRV = bazowy percentyl (tylko persony, które mają HRV; Tomek nie ma). Ola: `today` ma sen i HRV — od teraz śpi w zegarku, więc w demo po 8× "Close the day" (bez ruszania kroków) dostaje pierwszy wynik: 84 · A · MEDIUM (test 9b).
2. **Eksport do FairWear (D20).** Rozszerz istniejący kanał (nie wymyślaj nowego, jeśli działa): `{ schema: "fairwear.health-export", version: 2, personaId, exportedAt, today, days: HesDayRecord[], crf: HesCrfEstimate[], hrr: HesHrrSession[] }`. Zmierz rozmiar JSON najcięższej persony (Ania) i sprawdź, czy mieści się w limicie kanału. Jeśli nie — skróć nazwy pól w transporcie, ale nie obcinaj danych.
3. **UI Health Sim** (po angielsku, wygląd aplikacji zdrowotnej):
   - **Today:** steps so far, live HR (etykieta "Live"), intensity minutes (moderate / vigorous), last night's sleep (bed–wake, total), resting HR, HRV.
   - **History:** 28 dni: steps, intensity minutes (mod/vig), resting HR, sleep (bed–wake, total), HRV percentile; sekcje "VO₂max estimates" (data, percentyl) i "Heart-rate recovery tests" (data, protokół, peak → 60 s, HRR1).
   - **Scenario (narzędzie dev):** wybór persony + "FairWear readiness": 8 wierszy (komponent, n of minimum/target, Core/Optional, ✓/✗), coverage dla HW i LW oraz "Preview" HES / tier / confidence liczony silnikiem z `common`, z podpisem "Simulator check — FairWear computes the official result". Wartości muszą być identyczne z FairWear.
4. **Zegarek Health Sim** (jeśli jest moduł): live HR w spoczynku w okolicy RHR persony; nic więcej z HES.

---

## 7. Faza 4 — FairWear telefon

- EngineFairWearService / HesMapper / HesSession → vNext. Profil partnera dla `month()` / eligible / Share; profil wybrany przez użytkownika dla Dashboardu i Why.
- **Dashboard:** karta HES — score albo "No score yet", tier, "Evidence coverage 87.5%", "Data confidence: High", przełącznik profilu (segmented: "Health & wellness" | "Longevity"), dla B/C "N points to A/B".
- **Why this tier:** Strongest / To improve / Missing data (optional) wg D15 + effective weight (gdy coverage < 100%) + wartość surowa w czytelnych jednostkach; dla stanu bez wyniku layout z D16.
- **Formaty wartości surowych:** VO₂max "77th percentile (age & sex)", Resting HR "58 bpm", MVPA "238 min/week (vigorous counts ×2)", Steps "8,800/day", Sleep timing "±45 min", Sleep duration "7 h 24 min", HRV "60th percentile", HRR "32 bpm drop in 60 s".
- **Live card:** "Live · not scored" — zmiana HR 70→145 i kroków 1200→8000 nie rusza HES (test + sprawdzenie ręczne).
- **Demo controls:** Close the day (historyLength +1, przeliczenie), Reset demo (snapshot z Health Sim).
- 24h dial, kalendarz noszenia, Appeal, Consent — logika bez zmian.
- **Share:** tier z profilu partnera; "Not available", gdy brak wyniku; claim bez score/coverage (D14).
- Dark mode na każdym zmienionym ekranie (`fw_color.json` w base i dark).

---

## 8. Faza 5 — FairWear zegarek

- Sprawdź, czy `watch` importuje cokolwiek z HES. Jeśli tak — usuń zależność od wyniku (D18).
- Live HR z podpisem "Live · not scored" (albo "Live" + mały podpis, jeśli brakuje miejsca).
- Nie dodawaj liczenia HES na zegarku.

---

## 9. Faza 6 — Testy (dopisz do istniejącego runnera; wszystkie zielone)

1. **piecewise:** dokładne punkty, interpolacja, wartość poniżej pierwszego i powyżej ostatniego punktu — dla każdej z 8 krzywych co najmniej jeden punkt pośredni.
2. Steps 1000→0, 2000→20, 3000→35, 10000→100 · MVPA 150→80 · RHR 55→100, 110→5, 35→90 (plateau — nie "lower is better").
3. **Sen przez północ:** 23:30→330, 00:30→390, różnica 60. Ewa: TimingSD = 85. Naiwne minuty od północy dałyby bedtime SD ≈ 635 i TimingSD ≈ 453 — test wyłapuje ten błąd.
4. **Brak opcjonalnego:** Ania bez HRV → coverage 100 → 92.5 (dokładnie −7.5) w obu profilach; wynik nadal liczony. HW: 93 (observed 93.016), effective weight mvpa = 200/925 = 0.2162. LW: 93 (observed 92.649), effective weight mvpa = 150/925 = 0.1622.
5. **Brak Core:** score undefined, tier NONE, status INSUFFICIENT_DATA, confidence NOT_ENOUGH_DATA, coverage nadal liczona (Ola 47.5).
6. **Zaokrąglanie:** 84.49→84, 84.50→85.
7. **Live:** HR 70→145 nie zmienia HES; kroki 1200→8000 nie zmieniają HES.
8. **Close Day — poziom silnika (Ania):** dopisz do `HesHistory` dzień {steps 8000, moderate 20, vigorous 7, restingHr 58, bez snu i HRV} → steps raw 8792.857142857 (n 28), mvpa 239.5, rhr 59, sleepDuration n 27; HES 92 · A · HIGH (observed 92.385).
   **8b. Close Day — poziom HesSession (Ania, szablon today bez zmian):** historyLength +1; steps 8821.428571429, mvpa 239.5, rhr 59, sleepDuration 7.55 h, HRV 62.5; HES 92 · A · HIGH (observed 92.365).
9. **Ola zdobywa wynik:** +7 zamkniętych dni z pełnymi danymi → nadal INSUFFICIENT_DATA (coverage 55%); +8 → HW 84 · A · 82.5% · MEDIUM (observed 84.194, CI 0.733), LW 84 · A · 72.5% · MEDIUM (83.903, CI 0.667). Dzień: {steps 6800, moderate 10, vigorous 3, restingHr 68, sleep 23:15–07:00, total 420 min, hrv 50 nocturnal} — to dokładnie szablon `today` Oli.
   **9b.** To samo przez HesSession: 8× `closeDay()` bez zmiany live steps → ten sam wynik.
10. **Persony:** wszystkie liczby z §5 (agregaty, komponenty, HES, tier, coverage, confidence, CI, listy Why) dla obu profili.
11. **Safeguards (§16):** fuzz 1000 losowych historii (seeded) z NaN / Infinity / ujemnymi / pustymi → nigdy NaN ani Infinity w wyniku, nigdy dzielenie przez 0, brak wyjątku. Brak danych nigdy nie daje komponentowi score 0. Brak wyniku nigdy nie daje tieru C. HRV niedostępne, gdy jest tylko HR (Tomek). CRF niedostępne, gdy są tylko kroki/MVPA (Kasia). Live HR nigdy nie trafia do rhr.
12. **Filtry:** HRV z protokołu ≠ nocturnal pomijane. HRR: sesja innego protokołu wykluczona (Tomek, interval-run); Tomek + nowa sesja interval-run sprzed 1 dnia → HRR nadal 27 (n 3) (D12); sesje starsze niż 60 dni wykluczone (Ania, 75 dni). CRF starsze niż 90 dni wykluczone (Ania, 120 dni).
13. **Kontrakt:** payload version 1 → odrzucony z komunikatem, bez wyniku; payload v2 Ani → po stronie FairWear HES 92; preview w Health Sim == FairWear dla każdej persony.
14. **Wagi:** suma promili = 1000 dla obu profili.
15. **Regresja:** wszystkie dotychczasowe testy wear rules / crypto / share / UiService nadal zielone. Zmieniasz tylko testy HES-Lite.

Dodatkowo: wrzuć Załącznik C jako `tools/hes_vnext_oracle.cjs`, uruchom `node tools/hes_vnext_oracle.cjs` i dopisz test lub skrypt `tools/check-oracle.*`, który porównuje wynik silnika z oracle dla 6 person × 2 profile.

---

## 10. Faza 7 — Docs i screenshoty

- `docs/HES.md` → HES vNext: profile, wagi, Core/Optional, okna, min/target, krzywe, coverage, confidence, tier, stan bez wyniku, reguły live, skrót decyzji D1–D23, sekcja "Deviations from the spec" (D5 MVPA = mean × 7, D12 wybór porównywalnych sesji HRR, D15 bez duplikatów w To improve), plus zdania: "All weights, curves, thresholds, windows and minimum counts are research-informed product assumptions, not clinically or actuarially validated coefficients." i "Future validation must use real cohort/outcome data."
- `docs/HES_VNEXT_SPEC.md` — Załącznik A 1:1.
- README: tabela "real vs simulated" (HES = real vNext engine on synthetic Health Sim history; live values not scored; VO₂max/HRV percentiles simulated in Health Sim) + nowe wartości person.
- `AI_WORKFLOW.md` + `docs/prompts/` (dodaj tę wklejkę jako kolejny prompt), `docs/REQUIREMENTS_CHECK.md`, `docs/test-results.txt` (nowe liczby testów), skrypt demo — nowe coverage.
- Screenshoty: dashboard light/dark, Why (Tomek), No score (Ola), Share, Health Sim Scenario/readiness.

---

## 11. Definition of Done

- [ ] Audyt zapisany; gałąź `feature/hes-vnext`
- [ ] Jeden silnik vNext w `common`; HES-Lite usunięty; brak kopii formuł poza `common` (grep po wagach i punktach krzywych)
- [ ] Persony = złote wartości dla HW i LW (test)
- [ ] Health Sim: dane vNext, eksport v2, Today / History / Scenario, preview == FairWear
- [ ] FairWear telefon: Dashboard, Why, No score, Live, Close/Reset, Share, przełącznik profilu, dark mode
- [ ] Zegarek: nie liczy HES, "Live · not scored"
- [ ] Testy zielone (podaj liczby: common X/X, watch Y/Y, Health Sim Z/Z), lint 0, build OK dla wszystkich modułów
- [ ] Docs + screenshoty
- [ ] Commity tylko lokalnie; nic nie wypchnięte; repo prywatne

**Kolejność cięć przy braku czasu** (pierwsze do wycięcia): screenshoty Health Sim → przełącznik profilu w UI (zostaje sam HW) → zakładka History w Health Sim (zostaje Scenario) → effective weights w UI.
**Nie wolno ciąć:** silnika, testów, person, stanu "No score yet", reguł live, Share bez wyniku.

---

## 12. Raport końcowy (krótko)

- tabela: faza | status | commit;
- tabela person (HW i LW): FairWear | Health Sim preview | złota wartość;
- liczby testów i wynik lint/build;
- lista odstępstw od tej wklejki (jeśli są) z uzasadnieniem;
- co użytkownik musi zrobić ręcznie (instalacja obu .hap na emulatorze, kolejność uruchamiania).

---

## Załącznik B — Przepis generatora person (deterministyczny, bez RNG)

**Wzór:** `pattern(A, d, n)` — n nieparzyste → `[A, A−d, A+d, A−d, …]`; n parzyste → `[A−d, A+d, A−d, …]`. Dzięki temu średnia = mediana = A dla każdego n, a populacyjne SD wzorca parzystego = d.

**Rozmieszczenie:** wartości trafiają do **n najnowszych** dni historii (chronologicznie, od najstarszego); starsze dni nie mają danego pola (brak = nieważne). Ostatni dzień historii = wczoraj względem parametru `today`.

**Odchylenia d:** steps 600 · dzienny ekwiwalent MVPA 6 (vigorous = floor(eq/5), moderate = eq − 2·vigorous) · restingHr 2 · całkowity sen 18 min · HRV percentyl 5. **Pora snu:** `shift = pattern(0, a, n)` dodawany do bed i wake, zawijany przez `((x % 1440) + 1440) % 1440` (samo `%` w JS/ArkTS daje liczby ujemne → noc nieważna → Tomek wychodzi 85 A zamiast 79 B); czas w łóżku stały, sen ≤ czas w łóżku.

| Persona | dni | steps A, n | MVPA eq/dzień A, n | RHR A, n | sen: n, bed, wake, a, total min | HRV A, n | CRF (daysAgo: percentyl) | HRR (daysAgo, protokół, peak→hr60) |
|---|---|---|---|---|---|---|---|---|
| Ania | 28 | 8800, 28 | 34, 28 | 58, 28 | 28, 22:45, 06:45, 45, 444 | 60, 28 | 120: 60 (poza oknem) · 70: 74 · 12: 77 | 75 walk-3min 150→130 (poza oknem) · 45 walk-3min 152→122 · 25 walk-3min 154→120 · 4 walk-3min 150→118 |
| Marek | 28 | 6200, 28 | 17, 28 | 68, 28 | 28, 23:30, 06:50, 70, 396 | 40, 28 | — | 50 walk-3min 140→118 · 30 walk-3min 142→116 · 9 walk-3min 141→117 |
| Kasia | 28 | 6000, 20 | 14, 20 | 72, 18 | 16, 23:00, 06:30, 70, 384 | 52, 4 | — | — |
| Tomek | 28 | 7000, 28 | 21, 28 | 62, 28 | 28, 00:00, 07:00, 80, 390 | — (zegarek bez HRV) | 40: 48 · 5: 50 | 55 walk-3min 150→125 · 50 interval-run 178→137 (inny protokół) · 33 walk-3min 152→123 · 8 walk-3min 151→124 |
| Ewa | 28 | 4400, 20 | 10, 20 | 76, 20 | 16, 23:45, 07:15, 85, 372 | 35, 3 | — | 38 walk-3min 135→117 · 6 walk-3min 136→114 |
| Ola | 16 | 6800, 16 | 16, 16 | 68, 16 | 6, 23:15, 07:00, 40, 420 | 50, 6 | — | — |

HRV ma protokół `nocturnal`. U Kasi, Marka, Tomka i Ewy pora snu przechodzi przez północ (np. Ewa 22:20 / 01:10) — to celowy test D7.

---

## Załącznik A — HES vNext Backend Implementation Spec (verbatim; przywrócone tylko znaki "≥" w 10 liniach)

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

---

## Załącznik C — Oracle (Node, bez zależności) → `tools/hes_vnext_oracle.cjs`

Narzędzie do weryfikacji, **nie trafia do aplikacji**. Liczy agregaty i HES dla 6 person × 2 profile z przepisu z Załącznika B. Silnik ArkTS musi dawać te same liczby. Ograniczenia opisane w nagłówku pliku (okna po indeksie, brak ochrony przed nieskończonym x) — testów fuzz i wartości nieskończonych nie porównuj z oracle.

```js
// HES vNext — reference oracle (Node, no deps). NOT shipped in the app.
// Purpose: cross-check the ArkTS engine and regenerate persona goldens.
// Run: node tools/hes_vnext_oracle.cjs
// Limits: windows are by array index (last 28/14 entries) and CRF/HRR use a fixed daysAgo, so it matches
// the calendar-date rules (D9) only for gap-free histories (all personas are gap-free). piecewise() does not
// guard non-finite x. Do NOT use the oracle for fuzz / non-finite tests — those assert the engine's own guards.
'use strict';

// ---- model definition (weights in per-mille, integers -> exact coverage) ----
const ORDER = ['crf', 'rhr', 'mvpa', 'steps', 'sleepRegularity', 'sleepDuration', 'hrv', 'hrr'];
const CORE = ['rhr', 'mvpa', 'steps', 'sleepRegularity', 'sleepDuration'];
const WEIGHTS_PM = {
  HEALTH_WELLNESS:    { crf: 125, rhr: 125, mvpa: 200, steps: 150, sleepRegularity: 150, sleepDuration: 125, hrv: 75, hrr: 50 },
  LONGEVITY_WELLNESS: { crf: 225, rhr: 150, mvpa: 150, steps: 175, sleepRegularity: 100, sleepDuration: 75, hrv: 75, hrr: 50 },
};
const COUNTS = { steps: [14, 21], mvpa: [14, 21], rhr: [10, 14], sleepDuration: [14, 21], sleepRegularity: [14, 21], hrv: [7, 14], crf: [1, 2], hrr: [2, 3] };
const CURVES = {
  crf: [[5, 10], [10, 20], [25, 45], [50, 70], [75, 88], [90, 97], [95, 100]],
  rhr: [[40, 90], [45, 98], [50, 100], [55, 100], [60, 95], [65, 90], [70, 84], [75, 76], [80, 66], [90, 45], [100, 20], [110, 5]],
  mvpa: [[0, 0], [30, 20], [60, 40], [100, 60], [150, 80], [250, 95], [300, 100]],
  steps: [[1000, 0], [2000, 20], [4000, 50], [5000, 65], [6000, 80], [7000, 90], [8000, 95], [10000, 100]],
  sleepRegularity: [[30, 100], [45, 90], [60, 80], [90, 60], [120, 40], [180, 15], [240, 0]],
  sleepDuration: [[4.5, 0], [5.0, 25], [5.5, 45], [6.0, 65], [6.5, 82], [7.0, 95], [7.5, 100], [8.0, 100], [8.5, 100], [9.0, 100], [9.5, 95], [10.0, 90], [11.0, 80], [12.0, 65]],
  hrv: [[5, 10], [10, 25], [25, 50], [50, 75], [75, 90], [90, 97], [95, 100]],
  hrr: [[12, 10], [18, 30], [24, 55], [30, 70], [36, 82], [42, 92], [50, 100]],
};
const EPS = 1e-9;
const HRV_PROTOCOL = 'nocturnal';

const clamp = (v) => Math.min(100, Math.max(0, v));
function piecewise(pts, x) {
  if (x <= pts[0][0]) return clamp(pts[0][1]);
  if (x >= pts[pts.length - 1][0]) return clamp(pts[pts.length - 1][1]);
  for (let i = 0; i < pts.length - 1; i++) {
    const [x0, y0] = pts[i], [x1, y1] = pts[i + 1];
    if (x <= x1) return clamp(y0 + ((x - x0) / (x1 - x0)) * (y1 - y0));
  }
  return clamp(pts[pts.length - 1][1]);
}
const relMin = (m) => (m - 1080 + 1440) % 1440;
const mean = (xs) => xs.reduce((a, b) => a + b, 0) / xs.length;
const median = (xs) => { const a = [...xs].sort((x, y) => x - y); const m = a.length >> 1; return a.length % 2 ? a[m] : (a[m - 1] + a[m]) / 2; };
const popSd = (xs) => { const m = mean(xs); return Math.sqrt(mean(xs.map((x) => (x - m) ** 2))); };
const ok = (x) => typeof x === 'number' && Number.isFinite(x) && x >= 0;

// history: { days: DayRecord[] (oldest..newest, completed only), crf: [{daysAgo,pct}], hrr: [{daysAgo,protocolId,peakHr,hr60}] }
function aggregate(hist) {
  const N = hist.days.length;
  const w28 = hist.days.slice(Math.max(0, N - 28));
  const w14 = hist.days.slice(Math.max(0, N - 14));
  const steps = w28.map((d) => d.steps).filter(ok);
  const eq = w28.filter((d) => ok(d.moderateMin) && ok(d.vigorousMin)).map((d) => d.moderateMin + 2 * d.vigorousMin);
  const rhr = w28.map((d) => d.restingHr).filter(ok);
  const nights = w28.map((d) => d.sleep).filter((s) => s && ok(s.bedMin) && ok(s.wakeMin) && ok(s.totalSleepMin));
  const hrv = w14.map((d) => d.hrv).filter((x) => x && x.protocol === HRV_PROTOCOL && ok(x.percentile)).map((x) => x.percentile);
  const crf = hist.crf.filter((e) => e.daysAgo >= 0 && e.daysAgo <= 89 && ok(e.pct)).sort((a, b) => a.daysAgo - b.daysAgo);
  const hrrIn = hist.hrr.filter((e) => e.daysAgo >= 0 && e.daysAgo <= 59 && ok(e.peakHr) && ok(e.hr60) && e.peakHr > e.hr60).sort((a, b) => a.daysAgo - b.daysAgo);
  // comparable = protocol with the most sessions in the window; tie -> protocol of the newest session
  const counts = new Map(); hrrIn.forEach((e) => counts.set(e.protocolId, (counts.get(e.protocolId) || 0) + 1));
  let proto = null; for (const e of hrrIn) if (proto === null || counts.get(e.protocolId) > counts.get(proto)) proto = e.protocolId;
  const hrr1 = hrrIn.filter((e) => e.protocolId === proto).map((e) => e.peakHr - e.hr60);
  const r = (vals, f) => ({ raw: vals.length ? f(vals) : undefined, valid: vals.length });
  return {
    crf: { raw: crf.length ? crf[0].pct : undefined, valid: crf.length },
    rhr: r(rhr, median),
    mvpa: r(eq, (v) => mean(v) * 7),
    steps: r(steps, mean),
    sleepRegularity: { raw: nights.length ? Math.sqrt((popSd(nights.map((n) => relMin(n.bedMin))) ** 2 + popSd(nights.map((n) => relMin(n.wakeMin)))

[the paste ends here: cut by the 50,000-character limit]
