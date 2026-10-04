> Public-safe copy of a team brief (in Polish) that was handed to a coding-agent session as its standing instruction during HackYeah 2026. Kept as written; which briefs are still in force is listed in `docs/prompts/README.md`.

# WKLEJKA 14: poprawki po audycie (06:40) — FairWear, `feature/engine-reports` @ 100de25

Jesteś sesją Claude Code w repo FairWear na tym komputerze (`C:\dev\FairWear`, Git Bash). Masz jedno
zadanie: wprowadzić poniższe poprawki, sprawdzić je testami, buildem i na emulatorach, wmergować do
`feature/engine-reports` i wypchnąć na prywatny origin. Oddanie zgłoszenia jest o 10:30. Zgłoszenie
przygotowuje człowiek; ty kończysz najpóźniej o 09:30.

Kod, komentarze, dokumenty i teksty w UI piszesz po angielsku. Raport końcowy dla mnie piszesz po polsku.

---

## 0. Start (5 min)

1. Przeczytaj `AGENTS.md` (sekcja "Project state"), `.claude/skills/fairwear-ui/SKILL.md` (przed każdą zmianą
   w UI) i `AI_WORKFLOW.md`. Dopisz tę sesję do tabeli narzędzi, jeśli jej tam brakuje.
2. Sprawdź, czy ktoś jeszcze pracuje na `feature/engine-reports`:
   `git log -5 --format='%h %ad %s' --date=format:%H:%M feature/engine-reports`.
   - Jeśli HEAD to nadal `100de25` albo nowsze commity nie dotykają plików z tej wklejki, jedź dalej.
   - Jeśli nowe commity dotykają tych samych plików, zrób rebase swojej pracy na nowy HEAD, zanim zaczniesz.
3. Utwórz osobny worktree i gałąź:
   ```
   git -C C:/dev/FairWear worktree add C:/dev/FairWear-fix -b fix/final-audit feature/engine-reports
   cd C:/dev/FairWear-fix && source tools/env.sh && ohpm.bat install --all
   ```
4. Zmierz punkt wyjścia: `tools/run-logic-tests.sh common` musi dać 380/380, a `tools/run-logic-tests.sh watch`
   6/6. Jeśli wyniki są inne, zatrzymaj się i napisz mi, co widzisz.

## 1. Zasady (bez wyjątków)

- **Nie zmieniaj:**
  - `TierClaim` (7 kluczy: `v, period, tier, eligible, nonce, issuedAt, kid`);
  - kolejności weryfikacji i jej tekstów;
  - progów w `defaults.ets` i `HesCurves.ets`;
  - parametrów person w `HesPersonas.ets` i `WearPersonas.ets`;
  - formatu `fwhs1`.
- **Kopie w Health Sim:** pliki z `common/src/main/ets/` skopiowane do `healthsim/entry/src/main/ets/fw/` i
  `healthsim/watch/src/main/ets/fw/` muszą być identyczne bajt w bajt. Pilnuje tego `HealthSimCopies.test.ets`.
  - Lista skopiowanych plików: `claim/ClaimValidation`, `claim/TierClaimCodec`, `health/HealthConnection`,
    `health/HealthRecords`, `health/HealthSimPayload`, `health/HealthSource`, całe `hes/*`, `model/defaults`,
    `model/types`, `platform/Bytes`, `rules/SelectiveNonWear`, `watchlink/DemoFeed`, `watchlink/JsonRead`,
    `watchlink/WatchLinkTypes`, `wear/WearMonth`, `wear/WearPersonas`.
  - Jeśli zmienisz którykolwiek z nich: skopiuj go (`cp`) do obu miejsc, w których występuje, uruchom
    `HealthSimCopies.test.ets` i przebuduj Health Sim. Najlepiej w ogóle ich nie ruszać (wyjątek: F1).
- **Brzmienie:** wynik i reguły są deterministyczne i nigdy nie nazywaj ich "AI". Unikaj słów "predicts",
  "validated", "risk", "healthy/unhealthy". Po każdej zmianie tekstów uruchom `tools/check-wording.sh`.
- **Dni z zegarka** są pokazywane, ale nie liczone do wyniku. Nigdzie nie pisz, że zegarek zasila wynik.
- **Logi** nie zawierają wartości tętna ani kroków w polach `%{public}`.
- **Commituj** po każdym punkcie F, z opisowym komunikatem. Przed każdym commitem: testy `common` i `watch`
  zielone oraz `check-wording.sh` z wynikiem 0.
- **Emulatory** mogą być używane przez inne sesje. Przed użyciem utwórz `C:\dev\_emu-phone.lock` albo
  `C:\dev\_emu-watch.lock` z treścią w stylu `1 PHONE 07:40:00 fix-session F1 walk, up to 10 min` i usuń go po
  skończonej pracy. Jeśli plik już istnieje i nie jest starszy niż 15 minut, poczekaj.
- **Zakazy:** nie mergujesz do `main`, nie zmieniasz widoczności repo (żadnego `gh repo edit --visibility`),
  nie robisz `push --force` i nie przepisujesz historii.

## 2. Fakty z audytu (sprawdzone, nie audytuj ich od nowa)

- **Wyniki person (oba źródła dają to samo przy wszystkich typach włączonych):**

  | Persona | Wynik | Pokrycie | Pewność | Pozostałe |
  |---|---|---|---|---|
  | Ania | A/92 | 100% | High | FULL |
  | Marek | B/75 | 85% | High | flagged, NONE, 3 podejrzane przerwy, w kalendarzu 3 dni SUSPICIOUS i 1 SHORT |
  | Kasia | B/73 | 70% | Medium | PARTIAL |
  | Tomek | B/79 | 90% | High | PARTIAL, "1 point to A" |
  | Ewa | C/59 | 75% | Medium | NONE |
  | Ola | brak wyniku | 43% | Insufficient | — |

- **Close the day (bez wartości na żywo):**
  - Ewa przechodzi z C/59 na B/64.
  - Tomek osiąga A/80 na 4. zamkniętym dniu.
  - Ania zostaje na A/92.
- **Health Sim:** połączenie telefonu z FairWear działa (kontrakt `fwScopes`/`fwhs1`, kod 0). Zegarek dostaje
  jeden stały skrypt dnia.
- **To repozytorium jest prywatne.** Lokalnie jest 76 commitów, których nie ma na `origin/feature/engine-reports`.

---

## 3. P0 — błędy (gotowe i przetestowane do 08:00)

### F1. Przełączniki zgody muszą działać zawsze: na obu ścieżkach i po "Close the day"

**Co jest źle (potwierdzone testem):**
- (a) Ścieżka bez Health Sim: `AddonSession.confirmDataConsent` → `clearHealthSim()` → silnik liczy pełną
  historię persony. Po wyłączeniu HRV Ania nadal ma A/92 i 100%, choć ekran zgody obiecuje, że wyłączony typ
  to brak danych (`DataConsentPage.ets`: "A data type you switch off is treated as missing evidence").
- (b) Obie ścieżki: `HesSession.closeDay()` bierze nowy dzień z `PersonaDaySource` (`HesPersonas.ets`,
  `generatePersonaDay`) z wypełnionymi wszystkimi polami. Przy samych typach podstawowych Ania startuje z
  A/96 i 70%. Po 5 zamkniętych dniach pojawia się VO₂max (85%), po 7 HRV (100%), a wyłączone typy wracają.

**Jak to naprawić (wszystko poza plikami kopii, oprócz jednej zmiany w `HealthSimPayload.ets`):**

1. `common/src/main/ets/health/HealthSimPayload.ets`:
   - Zmień prywatną funkcję `blanked(day, scopes)` w eksportowaną
     `export function dayWithScopes(day: HesDay, scopes: HealthScope[]): HesDay` (ta sama treść).
   - `withScopes` ma jej używać.
   - Dodaj eksport w `common/Index.ets`.
   - Skopiuj plik do `healthsim/entry/src/main/ets/fw/health/HealthSimPayload.ets`.
   - To jedyny plik kopii, który zmieniasz w F1. Zachowanie Health Sim się nie zmienia.
2. `common/src/main/ets/report/EngineReports.ets` (nie jest kopiowany):
   - Dodaj klasę źródła dni z filtrem:
     ```ts
     class ScopedPersonaDays implements HesDaySource {
       private spec: HesPersonaSpec;
       private scopes: HealthScope[];
       constructor(spec: HesPersonaSpec, scopes: HealthScope[]) { this.spec = spec; this.scopes = scopes; }
       dayAfter(closedDays: number): HesDay {
         return dayWithScopes(generatePersonaDay(this.spec, closedDays), this.scopes);
       }
     }
     ```
   - `engineSession(id: string, scopes: HealthScope[] = ALL_HEALTH_SCOPES)`: historia startowa persony
     przepuszczona przez `dayWithScopes`, a źródło dni to `ScopedPersonaDays`. Użyj konstruktora
     `new HesSession(start, source)`. Nie zmieniaj `HesPersonas.session/sessionFrom`, bo to plik kopii.
   - `engineSessionFrom(person: HealthSimPerson, scopes: HealthScope[] = ALL_HEALTH_SCOPES)`: to samo, ze startem
     z `person.days`.
   - Nieznane id ma działać jak dziś (domyślna persona). Pilnuj zasad ArkTS: bez `any`, bez destrukturyzacji,
     jawne typy.
3. `entry/src/main/ets/report/EngineReportService.ets`:
   - Dodaj pole `private scopes: HealthScope[] = ALL_HEALTH_SCOPES`.
   - Dodaj metodę `useScopes(scopes: HealthScope[])`, która czyści `sessions` i `reports`.
   - `session()` przekazuje `this.scopes` do `engineSession` i `engineSessionFrom`.
4. `entry/src/main/ets/report/ServiceLocator.ets`:
   - Dodaj `useBuiltIn(scopes: HealthScope[])`: wbudowane persony z filtrem i usunięcie pliku Health Sim.
   - `useHealthSim(payload, scopes)` zapisuje także zakresy.
   - Zakresy trzymaj w sandboxie (`healthsim/scopes.json`: tablica nazw `HealthScope`, ścisłe dekodowanie,
     przy nieznanej nazwie lub błędzie ALL). Odtwarzaj je w `attachReportStore`, żeby po restarcie
     "Close the day" nie przywracało wyłączonych typów.
   - `clearHealthSim()` (rozłączenie) ustawia zakresy z powrotem na ALL.
5. `entry/src/main/ets/addon/AddonSession.ets`, `confirmDataConsent`:
   - Gdy jest `pendingHealthSim`, wywołaj `useHealthSim(withScopes(payload, scopes), scopes)`.
   - W przeciwnym razie wywołaj `useBuiltIn(scopes)` zamiast `clearHealthSim()`.

**Testy (nowy plik `common/src/test/ConsentScopes.test.ets`; runner w Node bierze każdy `*.test.ets` sam;
dopisz go też do `common/src/test/List.test.ets`, tak jak pozostałe):**
- `engineSession(id)` bez zakresów daje dokładnie dzisiejsze wyniki 6 person (tabela w sekcji 2), a Ewa po
  jednym `closeDay` ma B/64.
- Ania bez HRV, ścieżka wbudowana: **A/93, 90%, High**. Wynik identyczny jak w
  `engineSessionFrom(osoba z withScopes(healthSimPayloadFromPersonas(), te same zakresy))`.
- Ania z samymi typami `STEPS, RESTING_HEART_RATE, SLEEP, ACTIVITY_MINUTES`: start **A/96, 70%, Medium**. Po 8
  `closeDay` pokrycie nadal 70%, a `validCount` dla vo2max, hrv i hrRecovery wynosi 0. Sprawdź obie ścieżki.
- Ania bez `SLEEP`: brak wyniku (insufficient), pokrycie 73%.
- Dla każdego typu wyłączanego po kolei: po 3 `closeDay` trzy ostatnie dni historii mają `HES_MISSING` we
  wszystkich polach tego typu.
- `common` musi dać 380 starych testów + nowe, wszystkie zielone. `HealthSimCopies` 2/2.

### F2. Karta na ekranie głównym zawsze pisze "HUAWEI Health · Demo data"

- `entry/src/main/ets/nav/CardSync.ets` wylicza etykietę z samego `status`. Gdy `reportsFromHealthSim()`,
  karta ma pokazać `reportSourceLabel()` ("Health Sim · Simulated data").
- Dodaj do `buildCardDigest` w `common/src/main/ets/card/CardDigest.ets` opcjonalny parametr `label?: string`.
  Jest używany tylko przy statusie połączonym; przy NOT_AUTHORIZED i UNAVAILABLE zostaje dzisiejsza etykieta.
  Limit 48 znaków zostaje.
- Test w `CardDigest.test.ets`: etykieta Health Sim przy statusie połączonym; dla NOT_AUTHORIZED nadal
  "HUAWEI Health · Not connected" i brak pokrycia.

### F3. Wskrzeszona wklejka w drzewie

- `healthsim/WKLEJKA_HEALTH_SIM.md` został usunięty w `e30fdeb`, ale wrócił przy merge'u `da5ef1a`. Opisuje stary
  Health Sim z personą Wei.
- Zrób `git rm healthsim/WKLEJKA_HEALTH_SIM.md`. Nie przenoś go do `docs/prompts/`, bo jest nieaktualny.

### F4. Miesiąc noszenia a przełączniki zgody — DECYZJA: wariant 1

Miesiąc noszenia (przerwy, `restDeltaBpm`, `stepsRatio`, liczba odczytów tętna przed przerwą) nie jest
filtrowany zgodą (`withScopes` zostawia `person.wear`). Przy wyłączonym tętnie spoczynkowym albo krokach
reguła przerw dalej używa tych danych.

- **Wariant 1 (wykonaj ten):** sama uczciwa informacja, bez zmiany logiki.
  - W `DataConsentPage.ets` pod zdaniem "A data type you switch off…" dodaj zdanie w tym samym stylu
    (CAPTION): `The wear check always uses when the watch was on the wrist and, around each break, the
    resting heart rate and steps of the 24 h before it. It decides eligibility, not the score.`
  - To samo jednym zdaniem w README ("What is real and what is simulated" albo "Security & privacy") i w
    `docs/HES.md`.
  - Nowy zrzut ekranu zgody: `docs/screenshots/final/a5-consent-wear-note-light.jpeg`.
- **Wariant 2 (tylko jeśli człowiek zmieni tę linijkę na "wariant 2"):** przełączniki `STEPS` i
  `RESTING_HEART_RATE` zablokowane na włączone, z dopiskiem "Needed for the wear check". Wymaga nowych zrzutów
  zgody i poprawek w DEMO_SCRIPT.

---

## 4. P1 — drobne poprawki w kodzie (do 08:20; wycinaj od końca, jeśli brakuje czasu)

### F5. Jednostka przy HRR i VO₂max

- Ola pokazuje "Recovery (HRR1) 1 day". W `entry/src/main/ets/report/ReportTexts.ets` → `countUnit`:
  - `ComponentId.HR_RECOVERY` ma dawać `'workouts'`;
  - `ComponentId.VO2MAX` ma dawać `'estimates'`;
  - sen i regularność snu zostają przy `'nights'`, reszta przy `'days'`.
- Liczba pojedyncza działa przez `substring` w `countLine`. Sprawdź, że daje "1 workout" i "1 estimate".
- Popraw zrzut "Why · Ola", jeśli go odświeżasz.

### F6. Partner: limit nonce i podmiana klucza (`common/src/main/ets/claim/PartnerVerifier.ets`)

- Limit 512 usuwa najstarszy nonce bez względu na to, czy był użyty (linie około 103–109). Komentarz przy
  `MAX_OUTSTANDING_NONCES` mówi "oldest unused".
- **Napraw:**
  - użyte nonce trzymaj w osobnej mapie do końca ich TTL, z własnym limitem;
  - przy przepełnieniu usuwaj najstarszy NIEUŻYTY;
  - ponowne użycie kodu w czasie TTL zawsze ma dawać "Already used".
- **Test:** wydaj 600 nonce, użyj pierwszego tokenu, wydaj kolejne 600 i pokaż ten sam token jeszcze raz. Wynik
  ma być "Already used", a nie "Nonce mismatch".
- `registerKey`: gdy pod tym samym `kid` jest już INNY klucz publiczny, odmów (zwróć `false` albo rzuć wyjątek
  obsłużony w `ShareService.make`) zamiast po cichu go podmienić. Test na kolizję `kid`. Ponowna rejestracja tego
  samego klucza nadal ma działać.
- Kolejność weryfikacji i teksty statusów zostają bez zmian. `ClaimVerifier` i `ShareFlow` muszą przejść.

### F7. Martwe teksty

- Usuń nieużywane: `NEXT_STEP_SENTENCE` ("This screen arrives in the next step."), `TODAY_*` i
  `DAY_NOT_OBSERVED` w `ReportTexts.ets`, `isValidNonceText` w `ClaimValidation.ets`.
  - Uwaga: `ClaimValidation.ets` jest plikiem kopii. Jeśli go zmieniasz, skopiuj go do Health Sim i przebuduj
    Health Sim. Jeśli nie masz na to czasu, zostaw `isValidNonceText`.
- Usuń pośredniki bez importerów: `entry/src/main/ets/platform/Bytes.ets` i `CryptoUtil.ets`. Przed usunięciem
  sprawdź grepem, że nikt ich nie importuje.
- Nie ruszaj `PreviewReports`/`PreviewReportService`: są opisane w dokumentach i mają testy.

### F8. (Tylko jeśli masz czas po P2) Dzień jednocześnie podejrzany i zgodny

- W `wear/WearMonth.ets` (plik kopii) dzień z ≥20 h noszenia i podejrzaną przerwą jest rysowany jako SUSPICIOUS,
  ale liczony jako zgodny. Wtedy `WearMonth.redDays` = 0, a `EvidenceCalendar.redDays` = 2.
- Żadna persona dziś na to nie trafia. Jeśli to robisz: ujednolić licznik w kalendarzu i w podsumowaniu, dodać
  test, skopiować plik do Health Sim i przebudować Health Sim. W przeciwnym razie tylko jedno zdanie w
  `docs/HES.md` ("Known limits").

---

## 5. P1 — dokumenty niezgodne z kodem (do 08:45)

Każdą zmianę sprawdź z kodem, nie z tą listą. Numery linii dotyczą `100de25`.

| Plik | Co poprawić |
|---|---|
| `README.md:9` | "rewards healthy habits" zamień na sformułowanie bez "healthy" (np. "rewards regular activity and sleep"). |
| `README.md:29` | "Two HAPs, one per device". Są dwa projekty i cztery HAPy: FairWear `entry` i `watch` oraz Health Sim `entry` i `watch` (opcjonalny do pełnego demo). Zgraj to z sekcją Health Sim niżej. |
| `README.md` "What is real…" + "Security & privacy" | Zgoda działa na obu ścieżkach i po "Close the day" (F1). Ostatnie pole tokenu (`HUKS`/`SOFTWARE`) nie jest podpisane i jest informacyjne: partner pokazuje źródło klucza ze swojego rejestru. Zdanie z F4. |
| `HACKATHON_BRIEF.md:15` | "watch sensors → … score → signed tier" przeczy decyzji. Przepisz: historia (Health Sim w miejscu HUAWEI Health) → wynik i reguły noszenia na telefonie → podpisany tier; zegarek dodaje podpisane dowody noszenia, pokazywane, nieliczone. |
| `HACKATHON_BRIEF.md:9` | Usuń "healthy habits" i "health tier" w znaczeniu oceny zdrowia (np. "an explainable evidence tier"). |
| `docs/REQUIREMENTS_CHECK.md:3` | Odsyła do nieistniejącej tabeli w README. Usuń odwołanie albo dodaj krótką tabelę "Hackathon requirements → where to verify" w README. |
| `docs/REQUIREMENTS_CHECK.md:15` | 362/362 zamień na aktualne liczby z tej rundy. Wiersz "Brief recorded demonstration" zostaje `open` (nagrywa człowiek). |
| `docs/WATCH_LINK.md:25` | Stare liczby testów (WatchLinkFlow 8, DemoFeed 7, …). Policz z wyniku runnera dla każdego pliku i wpisz. |
| `AGENTS.md` "Project state" | (1) `ServiceLocator` jest w liście "NOT in the repository yet", a jest w repo: przenieś. (2) "A reading of 0 bpm or less is no reading" zamień na "a reading of 0 or outside 25–230 bpm is no reading" (`WatchLinkTypes.ets`). (3) Dopisz `healthsim/` (drugi projekt DevEco, telefon i zegarek) oraz `tools/watch-phone-relay.mjs`. (4) Odwołanie do `docs/prompts/` ma działać (patrz niżej). |
| `.claude/skills/fairwear-ui/SKILL.md:3,18,66` | `watch/src/main/ets/ui/` nie istnieje. Wskaż `watch/src/main/ets/pages/` i `watch/src/main/ets/watchlink/SlotRing.ets`. |
| `docs/DEMO_SCRIPT.md` | Po F1 przejdź plan B (bez Health Sim) i wiersze z przełącznikami zgody: przy wyłączonym HRV Ania ma teraz A/93 i 90% na OBU ścieżkach. Popraw oczekiwane wartości. Wiersze z wszystkimi typami włączonymi się nie zmieniają. |
| `docs/HES.md` | Zgoda filtruje też dni dodane przez "Close the day". Zdanie z F4. "Known limits": sytuacja z F8, jeśli jej nie naprawiasz. |
| `docs/ARCHITECTURE.md` | Tabela "Modules": dopisz wiersz o `healthsim/` jako osobnym projekcie (`com.fairwear.healthsim`, moduły entry i watch, kopie plików z `common` pilnowane testem). Przepływ zgody z F1 (zakresy w `EngineReportService`, `healthsim/scopes.json`). |
| `docs/test-results.txt` | Nowy wpis na górze w tym samym formacie: gałąź, commity, liczby testów, lint, wording, buildy, przejście na emulatorach z sekcji 6. |

**`docs/prompts/` (wymagane przez regulamin: "the main prompts, reusable instructions"):**
- Skopiuj do `docs/prompts/` pliki z `C:\dev\fairwear-specs\`: `00-FAIRWEAR_PLAN.md` oraz od `1-…` do `13-…`,
  a także tę wklejkę (14).
- Przed dodaniem każdego pliku wyczyść go: usuń wulgaryzmy, adresy e-mail, ścieżki z nazwą użytkownika
  (`C:\Users\…`), tokeny i adresy prywatnych usług. Treść merytoryczna zostaje po polsku.
- Dodaj `docs/prompts/README.md` (po angielsku): czym jest każdy plik, kolejność, które zostały zastąpione
  przez które (00 zastąpił 1–9), że prompty pisano po polsku, a kod i UI są po angielsku.

**`AI_WORKFLOW.md`:**
- Linia 29 ("These briefs are not in this repository") zamień na odwołanie do `docs/prompts/`.
- Dodaj dwa wiersze do work logu:
  - "claude.ai audit 06:40": przegląd wszystkich gałęzi tylko do odczytu, 4 równoległe podagenty review,
    uruchomienia testów w Node; wyniki trafiły do tej rundy;
  - ta runda poprawek: co zmieniono, jak sprawdzono, co zostało niezweryfikowane.
- W "Lessons learned" dopisz jedno zdanie: merge może wskrzesić usunięty plik (F3).

---

## 6. P2 — build, emulatory, HAPy (do 09:15)

1. Uruchom `tools/run-logic-tests.sh common` i `watch`, `tools/check-wording.sh` oraz `tools/lint.sh` (0 błędów).
2. Zbuduj FairWear: `assembleHap entry` i `watch`. Zbuduj Health Sim (`cd healthsim`, `ohpm install --all`,
   `assembleHap entry` i `watch`), bo zmieniłeś kopię `HealthSimPayload.ets`.
3. Zainstaluj (`install -r`) i przejdź na emulatorze telefonu, z plikiem lock:
   - Ścieżka Health Sim, HRV wyłączone w zgodzie FairWear → Ania **A/93, 90%**. "Close the day" ×5 → pokrycie
     dalej **90%**, a w "Why this tier" HRV jest w "Missing data". Zrzut:
     `docs/screenshots/final/a5-close-day-hrv-off-light.jpeg`.
   - Ścieżka bez Health Sim (odinstalowany albo "built-in demo data") z HRV wyłączonym → również A/93, 90%.
   - Karta na ekranie głównym po połączeniu z Health Sim → "Health Sim · Simulated data". Zrzut:
     `docs/screenshots/final/a5-home-card-healthsim-light.jpeg`.
   - Ekran zgody z dopiskiem z F4. Zrzut z F4.
   - Szybka regresja: Share → partner → "Signature valid", ponownie → "Already used", "Change tier" →
     "Invalid signature".
4. Na zegarku tylko regresja: aplikacja startuje, tarcza, "Get today from Health Sim" działa przy
   zainstalowanym Health Sim na zegarku.
5. **HAPy do zgłoszenia** (poza repo, `*.hap` jest w gitignore): skopiuj 4 pliki do `C:\dev\FairWear-release\`
   z nazwami
   - `fairwear-entry-<hash>.hap`,
   - `fairwear-watch-<hash>.hap`,
   - `healthsim-entry-<hash>.hap`,
   - `healthsim-watch-<hash>.hap`.

   Dołącz `SHA256SUMS.txt` i `BUILD_INFO.txt` (commit, data, wersje SDK, "unsigned debug builds, accepted by
   the emulators; install with `hdc -t <target> install -r <hap>`").

## 7. P3 — git (do 09:30)

1. W `C:\dev\FairWear-fix` wszystko jest zacommitowane, a `git status` jest czysty.
2. Merge do `feature/engine-reports` rób w worktree, w którym ta gałąź jest wyrejestrowana (`C:\dev\FairWear-hes`):
   ```
   git -C C:/dev/FairWear-hes status --short        # musi być pusto; jeśli nie, zatrzymaj się i napisz
   git -C C:/dev/FairWear-hes merge --no-ff fix/final-audit -m "Fix round after the 06:40 audit: consent on both paths and after Close the day, home card label, docs in line with the code"
   ```
   Po merge'u w `FairWear-hes`: testy `common`/`watch`, `check-wording.sh` i `assembleHap entry` mają być zielone.
3. `git push origin feature/engine-reports fix/final-audit`. Repo zostaje prywatne. Bez `--force`.
4. Nie mergujesz do `main`. Wybór gałęzi do zgłoszenia należy do człowieka.

## 8. Kolejność cięcia, jeśli zabraknie czasu

Najpierw wypada F8, potem F7, F6, F5. **F1, F2, F3, F4, sekcja 5 i sekcja 7 muszą wejść.** Jeśli F1 nie jest
zielony o 08:15, wycofaj zmiany F1, a w DEMO_SCRIPT i README napisz uczciwie, że na ścieżce bez Health Sim
przełączniki nie filtrują, a "Close the day" dodaje dzień ze wszystkimi typami. Nie zostawiaj fałszywej obietnicy
na ekranie zgody.

## 9. Świadomie NIE robisz teraz (zostaje w dokumentach jako ograniczenia)

- Podpisanie ostatniego pola tokenu (claim zostaje przy 7 kluczach).
- 32-bitowy `kid` i token na okaziciela (jedno zdanie w README "Security & privacy", jeśli go tam nie ma).
- Odbiór potwierdzeń (ACK) przez Wear Engine na zegarku.
- Zegar 24 h na telefonie.
- Testy modułu `entry`.
- Eksport i usuwanie danych.
- Skanowanie QR kamerą.
- Lista typów zatwierdzonych na ekranie Health Sim (przy "N of 7").

## 10. Raport końcowy (po polsku, krótko)

- Hashe commitów (fix i merge) oraz informacja, czy push się udał.
- Liczby testów przed i po, wynik lint i wording.
- Tabela: punkt F → zrobione / wycięte / zablokowane, z jednym zdaniem dowodu.
- Wyniki z emulatora (Ania przy HRV wyłączonym na obu ścieżkach, etykieta karty) i ścieżki zrzutów.
- Ścieżka do HAPów i sumy SHA-256.
- Co zostaje dla człowieka: wybór gałęzi zgłoszenia / merge do `main`, nagranie demo, prywatne repo vs wymóg
  "public source code repository", e-mail w metadanych commitów.
