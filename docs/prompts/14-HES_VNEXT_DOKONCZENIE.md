> Public-safe copy of the brief handed to a Claude Code session on 4 October 2026. One user name was removed.

# WKLEJKA — HES vNext: dokończenie na bazie `feature/hes-vnext-profiles`

> Wklej całość do **nowej** sesji Claude Code w repo FairWear (`C:\dev\FairWear`). To polecenie do wykonania od razu, nie raport.
> **Zastępuje `WKLEJKA_HES_VNEXT.md` — tamtej nie wykonuj.** Tamta zakładała przepisanie silnika od zera, nowe dane person i zmianę `v` w claimie (to by zepsuło `PartnerVerifier`). Silnik w repo jest już prawie zgodny z vNext — robisz tylko brakujące poprawki.
> **Czas:** skończ P0+P1 do **09:45** (oddanie 10:30). Cięcia na końcu (§9).

---

## 0. Zasady

1. **Wykonuj** fazami, bez czekania na potwierdzenie. Pytasz użytkownika tylko, gdy: (a) zmiana wymagałaby złamania pkt 4, (b) merge daje konflikt w `common/src/main/ets/hes/` lub `claim/`.
2. **Baza:** nowy worktree `C:\dev\FairWear-vnext`, gałąź `feature/hes-vnext` od `origin/feature/hes-vnext-profiles` (commit `59d1174`: profile HEALTH_WELLNESS / LONGEVITY_WELLNESS, okno HRV 14 nocy, `discountPct`). Potem `git fetch` i `git merge origin/main`. Jeśli na origin jest nowsza gałąź integracyjna niż `main` (np. merge agentów po 07:15) — zmerguj też ją. Konflikty poza `hes/` rozwiązuj na korzyść tamtej gałęzi.
3. **Równolegle pracują inni agenci** (osobne worktree). Jedna sesja na gałąź (`git branch --show-current` przed pierwszą edycją). **Nie ruszaj UI Health Sim** (`healthsim/*/src/main/ets/` poza `fw/`) — przerabia je inny agent. Emulator tylko przez lock: `C:\dev\_emu-phone.lock` / `C:\dev\_emu-watch.lock`, max 10 min.
4. **Nie zmieniaj:** claimu (`TierClaim` — 7 kluczy; `v` musi zostać `TIER_CLAIM_VERSION`), `ProofSigner` / `CryptoUtil` / weryfikacji, reguł noszenia i `WearPersonas`, danych person w `HesPersonas.ets` (bez dostrajania), krzywych, wag, liczności min/target, okien.
5. Commit po każdej fazie (`fix(hes): …`, `test(hes): …`, `feat(report): …`, `docs(hes): …`). **Nie pushuj i nie merguj do `main`** — na końcu zapytaj użytkownika o push gałęzi. Repo zostaje prywatne.
6. Po każdej fazie zielone: `tools/run-logic-tests.sh common`, `tools/run-logic-tests.sh watch`, `tools/check-wording.sh`. Po fazach z kodem ArkTS dodatkowo `tools/lint.sh` i build (`tools/deploy.sh` / `hvigorw assembleHap`; Health Sim wg `healthsim/README.md`).
7. Kod, komentarze, UI i docs po angielsku. HES to deterministyczne reguły i krzywe — nigdy "AI", "predicts", "validated", "risk", "healthy/unhealthy".
8. **Liczby z §8 policzono, uruchamiając silnik z `59d1174` z poprawkami z faz 1–2 (runner `tools/logic-tests`).** Jeśli twój wynik się różni, szukaj błędu w kodzie — nie dostrajaj testów.

---

## 1. Stan wyjściowy (sprawdzony na origin)

Na `feature/hes-vnext-profiles` jest już zgodne ze specem HES vNext: 8 komponentów, 5 Core, brak wyniku bez kompletu Core, renormalizacja, effective weights, krzywe, liczności 14/21 · 10/14 · 7/14 · 1/2 · 2/3, okna 28/14/60/90, sen przez północ (kotwica 18:00), quality, confidence ≥0.80 / ≥0.60, tier A ≥80 / B ≥60 / C, Why bez duplikatów, stan "No score yet", live HR/kroki nie ruszają HES, Close the day / Reset, oba profile z wagami w promilach, `HesSession.setProfile`. Testy: common 397/397, watch 6/6.

**Braki względem specu (to robisz):**

| #   | Brak                                                                                                                                                                | Spec                                                        |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| G1  | Coverage zaokrąglana do całych % (`hesRound`) → 87.5 pokazuje się jako 88, a brak HRV obniża coverage o 7, nie o 7.5. Confidence liczy się z zaokrąglonej coverage. | §7, §10, §17 "Coverage decreases exactly by missing weight" |
| G2  | Wartość `Infinity` (lub ogromna) przechodzi walidację i daje `rawValue = Infinity`. Fuzz 1000 historii: 2352 naruszenia.                                            | §16 "never return Infinity"                                 |
| G3  | Profil jest tylko w silniku — w UI telefonu nie da się go wybrać.                                                                                                   | §1                                                          |
| G4  | Docs nie mówią, jak spełniony jest wymóg jednego protokołu HRV/HRR; stare liczby coverage w docs.                                                                   | §3                                                          |

---

## 2. Faza 1 (P0) — Coverage dokładna (G1)

`common/src/main/ets/hes/HesComposite.ets`:

```ts
/** Evidence Coverage (section 7): 100 x the sum of the base weights of the available components.
 *  Exact: weights are whole thousandths, so the coverage is a multiple of 0.5 and is never rounded. */
export function coverage(components: HesComponentResult[]): number {
  return availableWeightPermille(components) / PERMILLE_PER_PERCENT;
}
```

Popraw komentarz nagłówka pliku (koniec z "42.5 rounds up to 43"). `confidenceIndex()` w `HesConfidence.ets` korzysta z `coverage()`, więc liczy się teraz z dokładnej wartości — nic więcej tam nie zmieniasz. `hesRound` zostaje dla wyniku HES.

**UI/teksty:** wszystkie miejsca robią `${coveragePct}%` / `toString() + '%'`, więc wyświetlą `87.5%`. Sprawdź grepem `coverage` w `entry/`, `common/src/main/ets/report/`, `common/src/main/ets/card/`, czy nic nie zakłada liczby całkowitej (np. `Math.round`, `toFixed(0)`, szerokość paska). Wartości całkowite dalej bez `.0` (`75%`, nie `75.0%`).

**Testy, które muszą się zmienić (i tylko te — 18 sztuk):**

- `EngineReports.test.ets`: "the six personas equal the fixed table…", "engine and preview agree…"
- `HealthSimCopies.test.ets` — zielony po fazie 3
- `Hes.test.ets`: "Coverage is lower by exactly the HRV weight (7.5 points, 92.5 rounds to 93)" → oczekuj **92.5** i zmień nazwę; "Status = insufficient_data" (87.5); "Core + VO2max -> 87.5 -> 88%, … 92.5 -> 93%" → 87.5 i 92.5; "a coverage of 42.5 rounds up to 43…" → "a coverage of 42.5 stays 42.5, the same on every run"; "steps, MVPA and both sleep components need 14 valid days…" (12.5); "HRV needs 7 valid nights" (82.5); "a missing Core component gives no score in either profile" (92.5); "a tier is assigned only with all five Core components" (87.5)
- `HesPersonas.test.ets`: Marek 87.5, Tomek 92.5, Ola 47.5 (HW); "Ania: A / 91, Marek: B / 75, Kasia: B / 71" (Marek 87.5); "Tomek reaches A / 80…" (92.5); "Ewa: C / 59, coverage 70%, Medium; Ola: no score, coverage 48%" → 47.5
- `HesSession.test.ets`: "Ola still has no score after 20 more days…" (47.5)

Zmień też nazwy testów, w których jest stara liczba (`88%` → `87.5%` itd.). `common/src/main/ets/report/PreviewReports.ets` — tabela stała: Marek 87.5, Tomek 92.5, Ola 47.5.

**Nowy test** (`Hes.test.ets`): Ania bez HRV (wszystkie `hrvPercentile = HES_MISSING`) w obu profilach — coverage 100 → **92.5** (dokładnie −7.5), wynik nadal liczony:

- HW: 93 · A · High, observed 93.2946 (±1e-3), effectiveWeight MVPA = 200/925 = 0.21622
- LW: 92 · A · High, observed 92.0082 (±1e-3), effectiveWeight MVPA = 150/925 = 0.16216

Commit: `fix(hes): exact evidence coverage (vNext section 7)`.

---

## 3. Faza 2 (P0) — Nigdy NaN / Infinity (G2)

1. `HesSufficiency.ets` → `isValidFor`: zanim sprawdzisz zakres, odrzuć wartość nieskończoną. Pola: RHR `restingHeartRate`; MVPA `moderateMinutes` i `vigorousMinutes`; regularność snu `sleepStartMin` i `sleepEndMin`; kroki `steps`; długość snu `sleepMinutes`; HRR `hrr1` — każde musi spełniać `Number.isFinite(x)`. Percentyle i godziny mają już zakres 0..100 / 0..1439.
2. `HesComponents.ets` → `evaluateComponent`: po `rawValueOf` sprawdź `Number.isFinite(rawValue) && rawValue >= 0`. Jeśli nie, komponent jest niedostępny (`available = false`, `rawValue = score = HES_MISSING`). Chroni to przed przepełnieniem średniej, np. kilka dni z `1e308` kroków.
3. Zaktualizuj komentarze decyzji w obu plikach.
4. **Nowy test fuzz** (`common/src/test/HesFuzz.test.ets`): `new HesPrng(20261004)`, 1000 historii o długości 0..99 dni. Każde pole z prawdopodobieństwem 25% ma wartość z `[NaN, Infinity, -Infinity, -1, -5, 0, 1e308, Number.MAX_VALUE]`, z 15% `HES_MISSING`, w pozostałych przypadkach typową wartość ×(0.5..1.5). Każdą historię liczysz w obu profilach. Asercje: brak wyjątku; `score` jest skończony (liczba całkowita albo `HES_MISSING`); `coverage` skończona i w 0..100; dla każdego komponentu `rawValue`, `score`, `quality` i `effectiveWeight` są skończone; niedostępny komponent ma `score === HES_MISSING` (nigdy 0); brak wyniku ⇒ tier `NONE`, nigdy C. Przed poprawką ten test daje 2352 naruszenia, po niej 0.
5. Test punktowy: jeden dzień z `steps = Infinity` w pełnej historii Ani → validCount kroków spada o 1, wynik bez zmian.

Wyniki person się nie zmieniają (sprawdzone). Commit: `fix(hes): non-finite readings are never evidence (vNext section 16)`.

---

## 4. Faza 3 (P0) — Health Sim: te same pliki silnika

Health Sim liczy na kopiach `common` w `healthsim/entry/src/main/ets/fw/` (pilnuje tego `common/src/test/HealthSimCopies.test.ets`). Skopiuj 1:1 każdy zmieniony plik z `common/src/main/ets/`, który ma bliźniaka pod `healthsim/*/src/main/ets/fw/` (co najmniej `hes/HesComposite.ets`, `hes/HesSufficiency.ets`, `hes/HesComponents.ets`). Uruchom test kopii i zbuduj Health Sim. **Bez zmian w ekranach Health Sim i w formacie `fwhs1`.**

Commit: `chore(healthsim): sync the HES vNext engine copies`.

---

## 5. Faza 4 (P1) — Wybór profilu na telefonie (G3)

Przeczytaj `.claude/skills/fairwear-ui/SKILL.md`.

- **Report:** pod kartą wyniku przełącznik segmentowy z dwiema opcjami z `hesProfileLabel`: **"Health insurance" | "Life insurance"**. Domyślnie HEALTH_WELLNESS. Zmiana przelicza **te same zamknięte dni** wybranej persony (`HesSession.setProfile` albo `computeHes(history, profile)`). Zmienia się: wynik, tier, coverage, confidence, "N points to A/B", listy Why, linia rabatu (`discountPct`). Wartości live zostają. Close the day i Reset nie zmieniają wybranego profilu. Profil wraca do domyślnego przy zmianie persony albo restarcie.
- **Share, partner, benefit/eligibility, kartka na ekranie głównym, mowa:** zawsze HEALTH_WELLNESS (partner demo to ubezpieczyciel zdrowotny). W Share dodaj jedną linię: **"For: Health insurance"**. Claim bez zmian (7 kluczy). Przykład: Tomek w "Life insurance" pokazuje 80 · A, a kod w Share ma tier **B**.
- **Implementacja tak, żeby Share nie trzeba było ruszać:** `ReportService.report(id)` zostaje bez zmian (zawsze HEALTH_WELLNESS). Dodaj `reportFor(id: string, profile: HesProfile): PersonaReport` — w `EngineReportService` na tej samej sesji, w `PreviewReportService` zwraca `report(id)`. Logikę budowania raportu dla profilu trzymaj w `common/src/main/ets/report/EngineReports.ets`, żeby dało się ją przetestować w Node.
- Przełącznik w osobnym pliku (np. `entry/src/main/ets/view/ProfileSwitch.ets`), w `ReportView` tylko wpięcie — inny agent może edytować `ReportView`. Dark mode przez kolory z `fw_color.json` (base i dark).
- **Testy (common):** `reportFor('tomek', LONGEVITY_WELLNESS)` → 80 · A · 92.5%, a `report('tomek')` → 79 · B; `reportFor` w HW jest identyczny z `report`; przełączenie profilu po `closeDay` używa historii z dodanym dniem; Ola w obu profilach: brak wyniku, 47.5%.
- **Zegarek:** nic nie zmieniasz. Sprawdź tylko grepem, że `watch/` nie importuje niczego z `hes/` (dni z zegarka są pokazywane, nie liczone do wyniku).

Commit: `feat(report): choose the HES vNext profile on the Report screen; Share stays on health insurance`.

---

## 6. Faza 5 (P1) — Docs (G4)

Edytuj krótko — inny agent też zmienia docs.

- `docs/HES.md`:
  - sekcja **"HES vNext conformance"**: tabela §1–§17 specu → plik/funkcja → test;
  - **"Deviations from the spec"**: MVPA = średnia ważnych dni × 7 (nie SUM/4 — brakujący dzień nie jest zerem); SD próbkowe (n−1) w regularności snu; Why bez duplikatów (3 + 2 przy 5 komponentach); coverage dokładna do 0.5 pkt;
  - **jeden protokół HRV/HRR:** Health Sim podaje tylko nocny percentyl HRV i HRR1 z jednego testu powysiłkowego; `fwhs1` nie ma drugiego protokołu, więc protokoły nie mogą się wymieszać; prawdziwe źródło musi filtrować przed przekazaniem danych;
  - zdania: "All weights, curves, thresholds, windows and minimum counts are research-informed product assumptions, not clinically or actuarially validated coefficients." oraz "Future validation must use real cohort/outcome data.";
  - Share zawsze na health insurance.
- Grep po starych liczbach w `README.md`, `docs/DEMO_SCRIPT.md`, `docs/REQUIREMENTS_CHECK.md`, `HACKATHON_BRIEF.md`: `88%`, `93%`, `48%`, `43%`, "coverage 90%". Przykład: `DEMO_SCRIPT.md` "with HRV off Ania reads 93 · A, coverage 90%" → **92.5%**. W README "HES-Lite" → "HES vNext" w tabeli real vs simulated.
- `docs/test-results.txt`: nowe liczby testów. `AI_WORKFLOW.md`: wpis o tej sesji. Kopia tej wklejki do `docs/prompts/` (public-safe) + wpis w `docs/prompts/README.md`.

Commit: `docs(hes): vNext conformance, deviations, exact coverage`.

---

## 7. Faza 6 (P2 — tylko jeśli o 09:30 P0+P1 są zielone)

- Screenshoty (z lockiem emulatora): Report Tomek w Health / Life insurance, Ola "No score yet · 47.5%", Share z linią "For: Health insurance" — do `docs/screenshots/`.
- Nic więcej. Karta "FairWear readiness" w Health Sim **nie teraz** (konflikt z przebudową UI Health Sim).

---

## 8. Złote wartości po zmianach (dane person bez zmian)

| Persona | HEALTH_WELLNESS (Share, benefit)                    | LONGEVITY_WELLNESS        | Observed HW / LW | CI HW / LW    |
| ------- | --------------------------------------------------- | ------------------------- | ---------------- | ------------- |
| Ania    | 92 · A · 100% · High                                | 91 · A · 100% · High      | 92.373 / 91.183  | 1 / 1         |
| Marek   | 75 · B · **87.5%** · High (flagged → brak benefitu) | 75 · B · **87.5%** · High | 74.890 / 74.511  | 0.875 / 0.875 |
| Kasia   | 71 · B · 75% · Medium                               | 71 · B · 65% · Medium     | 71.367 / 71.452  | 0.75 / 0.65   |
| Tomek   | 79 · B · **92.5%** · High · "1 point to A"          | **80 · A** · 92.5% · High | 78.501 / 79.682  | 0.925 / 0.925 |
| Ewa     | 58 · C · 80% · High                                 | 59 · C · 70% · Medium     | 57.559 / 59.385  | 0.80 / 0.70   |
| Ola     | No score · **47.5%** · Insufficient data            | No score · 47.5%          | —                | —             |

- Ania bez HRV: HW 93 · A · 92.5% · High; LW 92 · A · 92.5% · High.
- Tomek po 1× Close the day: HW 78 · B, LW 80 · A (coverage 92.5%).
- Ola: dalej bez wyniku po 30× Close the day (coverage 52.5%) — jak dotąd.
- Testy po fazach 1–3: common 397 + nowe, wszystkie zielone; watch 6/6.

Kasia 71 i Ewa 58 (zamiast 73 / 59 z raportu HES-Lite) to skutek wag vNext z commita `59d1174` — **nie dostrajaj person**.

---

## 9. Definition of Done i cięcia

- [ ] `feature/hes-vnext` w osobnym worktree, zmergowane `origin/main` (+ nowsza integracja, jeśli jest)
- [ ] G1 coverage dokładna, G2 fuzz 1000/0 naruszeń, 18 testów zaktualizowanych, nowe testy zielone
- [ ] Kopie w Health Sim zsynchronizowane, Health Sim się buduje
- [ ] Przełącznik profilu na Report; Share zawsze na health insurance, z linią "For: Health insurance"; claim bez zmian; testy crypto/share zielone
- [ ] `watch` bez importów z `hes/`
- [ ] lint 0, build entry + watch + common + Health Sim OK, `check-wording` OK
- [ ] Docs zaktualizowane
- [ ] Commity tylko lokalnie

**Kolejność cięć** (pierwsze wylatuje): screenshoty → linia "For: Health insurance" → przełącznik profilu (wtedy w docs: "profile selectable in the engine; the app shows health insurance"). **Nie wolno ciąć:** G1, G2, synchronizacji kopii, testów.

## 10. Raport końcowy (krótko, po polsku)

Tabela faza | status | commit; tabela person z §8 (wynik z aplikacji vs złota wartość); liczby testów, lint, build; odstępstwa od tej wklejki z uzasadnieniem; co użytkownik ma zrobić ręcznie (push gałęzi, merge — robi to człowiek, reinstalacja obu `.hap` FairWear + Health Sim).
