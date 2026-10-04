> Public-safe copy of a team brief (in Polish) that was handed to a coding-agent session as its standing instruction during HackYeah 2026. Kept as written; which briefs are still in force is listed in `docs/prompts/README.md`.

# Poprawka kierunku: FairWear + HES jako add-on do Huawei Health

Pracujesz w repo FairWear (HackYeah 2026, zadanie Huawei; ArkTS/ArkUI, minimum API 20; moduły: `entry` = telefon, `watch` = zegarek, `common` = HAR z logiką bez UI). Ta wklejka **koryguje kierunek**. Nie budujemy samodzielnej apki zdrowotnej, która zbiera własne dane. FairWear jest **dodatkiem do Huawei Health**.

## Nowy model produktu (przeczytaj, zanim cokolwiek zmienisz)
- Użytkownik ma już WATCH 5 i Huawei Health. Huawei Health mierzy i przechowuje kroki, tętno spoczynkowe, sen, aktywność, VO₂max, HRV i treningi.
- FairWear za zgodą użytkownika **czyta te dane z Huawei Health** przez Health Service Kit.
- Na telefonie FairWear liczy HES-Lite i reguły noszenia. Na zewnątrz wysyła tylko podpisany tier (QR → partner).
- **Nie dublujemy** tego, co Huawei Health już liczy, na przykład własnego wykrywania snu.
- Moduł `watch` zostaje. Pokazuje tętno na żywo i stan noszenia; to nasza część „na urządzeniu” i punkty za Platform use. Tętno na żywo nie pochodzi z Huawei Health i nigdy nie wchodzi do HES (spec HES-Lite, sekcja 10).
- **Ograniczenie, które mówimy wprost:** dostęp do danych wrażliwych (tętno itp.) przez Health Service Kit wymaga zgody Huawei dla konkretnej aplikacji. Huawei przegląda wnioski ręcznie, a trwa to kilkanaście dni roboczych. Na hackathonie tego dostępu nie mamy. Dlatego:
  - budujemy warstwę źródła danych z interfejsem;
  - działa źródło syntetyczne w formacie danych Huawei Health;
  - adapter do Health Service Kit powstaje tylko wtedy, gdy kit jest w naszym SDK;
  - UI zawsze uczciwie pokazuje, skąd są dane.

## Zasady (zespołu i nowe)
- Każdy krok robisz na osobnej gałęzi `feature/*`. Merge do `main` robi człowiek.
- Błędy kompilacji poprawiasz po jednym. Kod, komentarze i UI piszesz po angielsku. Reguł ani HES nie nazywasz „AI”.
- **Nie zmieniasz `types.ets` ani `defaults.ets` bez zgody człowieka.** Jeśli krok tego wymaga, zatrzymaj się i zapytaj.
- **Nie zgadujesz API Health Service Kit.** Nazwy modułu, funkcji, typów danych i uprawnień bierzesz wyłącznie z plików `.d.ts` w SDK zainstalowanym w DevEco. Jeśli ich tam nie ma, adaptera nie piszesz, tylko robisz stub (krok 2B).
- Bez logo Huawei Health, bez kopiowania kolorów i wyglądu Huawei Health. W tekście tylko „Reads from Huawei Health” / „Data from Huawei Health”. Stosuj się do wytycznych marki z tablicy zadania.
- **Zakazane sformułowania** (README, UI, pitch, slajdy):
  - „official Huawei Health plugin/extension”,
  - „runs inside the Huawei Health app”,
  - „approved by Huawei”,
  - „uses real Huawei Health data” (chyba że człowiek potwierdzi, że połączenie działa na urządzeniu),
  - plus dotychczasowe: „hardware-attested”, „AI detects cheating”, „tested on Watch 6”, „HES predicts health/disease/claims”, „clinically validated”.
- Zamrożenie funkcji o północy. Priorytet: krok 0 → 1 → 3 → 4. Krok 2 robisz tylko wtedy, gdy zostanie czas.

## Krok 0: rozpoznanie, bez zmian w kodzie (maks. 10 min)
1. Sprawdź, czy HES-Lite jest już w `common` (`common/src/main/ets/hes/`). Jeśli go nie ma, a w repo jest `_incoming/fairwear-ui/`, przenieś go według kroku 1 z `_incoming/fairwear-ui/WKLEJKA_CLAUDE_CODE.md`. Testy: 43/43.
2. Znajdź, skąd dziś apka bierze historię:
   - generator person,
   - `ReportBuilder`,
   - `HesPersonas`,
   - serwis demo.
3. Znajdź ekran zgody/onboardingu, wiersz „źródło danych” w ustawieniach i wszystkie miejsca z tekstem „Huawei Health”. Użyj `grep -rni "huawei health"` po `entry`, `watch`, `common`, `README*`, `docs/`.
4. Przeszukaj SDK w DevEco (katalog SDK z File → Settings → SDK) po plikach `.d.ts` zawierających `HealthServiceKit` albo `health.store`. Wypisz dokładnie:
   - ścieżkę importu,
   - funkcje inicjalizacji i autoryzacji,
   - funkcję odczytu,
   - identyfikatory typów danych: kroki, tętno spoczynkowe, sen, minuty aktywności/intensywności, VO₂max, HRV, trening,
   - wymagane uprawnienia i wpisy w `module.json5`.

   Jeśli kitu nie ma w SDK, napisz to wprost.
5. Pokaż mi raport z tych czterech punktów i zaczekaj na akceptację.

## Krok 1: gałąź `feature/health-source` (tylko `common`, czysta logika)
1. `common/src/main/ets/health/HealthRecords.ets` zawiera rekordy w **natywnych jednostkach Huawei Health** (nie w percentylach):
   - `DailyActivity { date: string; steps: number; restingHeartRate: number; moderateMinutes: number; vigorousMinutes: number }`;
   - `SleepSession { start: number /* epoch ms */; end: number; asleepMinutes: number }`;
   - `Vo2MaxEstimate { date: string; mlPerKgMin: number }`;
   - `HrvNight { date: string; rmssdMs: number }`;
   - `Workout { date: string; peakHeartRate: number; heartRate60s: number }`, gdzie `heartRate60s` to tętno 60 s po zakończeniu;
   - `HealthStatus`: enum `CONNECTED`, `NOT_AUTHORIZED`, `UNAVAILABLE`, `DEMO`.

   Brak wartości oznaczasz `-1` (tak jak `MISSING` w HES). Nigdy nie wpisujesz zera zamiast braku.
2. `common/src/main/ets/health/HealthSource.ets` definiuje interfejs `HealthSource`:
   - `status(): HealthStatus`
   - `daily(days: number): DailyActivity[]`
   - `sleep(days: number): SleepSession[]`
   - `vo2max(days: number): Vo2MaxEstimate[]`
   - `hrv(days: number): HrvNight[]`
   - `workouts(days: number): Workout[]`

   Metody są synchroniczne na danych już pobranych; pobieranie (async) robi adapter w `entry`.
3. `common/src/main/ets/health/HealthToHes.ets` zawiera mapper `toHesHistory(source, days = 90): HesHistory`. Reguły, każda z testem:
   - **Dzień:** kroki, tętno spoczynkowe, minuty umiarkowane i intensywne idą 1:1. Tętno spoczynkowe 0 albo brak daje `MISSING`.
   - **Noc:**
     - noc przypisujesz do daty pobudki;
     - sesje kończące się między 00:00 a 14:00 tego dnia łączysz w jedną: `start` = najwcześniejszy, `end` = najpóźniejszy, czas snu = suma `asleepMinutes` / 60;
     - drzemki kończące się po 14:00 pomijasz;
     - `sleepStart`/`sleepEnd` zapisujesz jako minuty od północy czasu lokalnego.
   - **Trening:** HRR1 = `peakHeartRate − heartRate60s`, tylko gdy obie wartości są > 0 i różnica jest > 0.
   - **VO₂max i HRV:** krzywe HES przyjmują **percentyle**, a Huawei Health podaje ml/kg/min i ms. Mapper dostaje opcjonalną `PercentileTable`. **Bez tabeli te składowe dostają `MISSING`.** UI pokaże je wtedy jako Missing evidence, a Coverage spadnie. To jest uczciwe zachowanie, nie błąd. Tabeli z liczbami nie wymyślasz: o źródło (np. opublikowane normy dla jednej grupy referencyjnej) pytasz człowieka.
4. Źródło demo:
   - `SyntheticHealthSource` zwraca `status() = DEMO`;
   - historię dla HES dalej bierzesz bezpośrednio z `HesPersonas.history(id)`, bo persony mają już percentyle VO₂max/HRV;
   - mapper służy realnemu adapterowi;
   - test sprawdza, że persona przepuszczona przez rekordy i mapper (bez VO₂max/HRV) daje te same kroki, tętno spoczynkowe, MVPA i sen co `HesPersonas`.
5. Dopisz eksporty do `common/Index.ets`, nie zastępując pliku. Testy w Node uruchamiasz przez `tools/run-logic-tests.sh common common/src/test/Health.test.ets health hes`. Zapisz wynik do `docs/test-results.txt`. Commit.

## Krok 2A: gałąź `feature/huawei-health-adapter` (tylko jeśli krok 0 znalazł kit w SDK i zostaje czas)
1. Utwórz `entry/src/main/ets/platform/HuaweiHealthSource.ets`, który implementuje `HealthSource`. Używa **dokładnie** nazw z `.d.ts`, które pokazałeś w kroku 0.
2. Kroki działania:
   - inicjalizacja, potem prośba o autoryzację tylko dla typów, które HES faktycznie używa;
   - async `load(days = 90)` pobiera dane do pamięci;
   - przy każdym błędzie ustawiasz `NOT_AUTHORIZED` albo `UNAVAILABLE`. **Nigdy nie podstawiasz danych syntetycznych pod etykietą Huawei Health.**
3. Uprawnienia i wpisy w `module.json5` dodajesz tylko te, które wymaga `.d.ts`/dokumentacja. Zgoda RODO art. 9 zostaje osobno w naszym UI.
4. Kod ma się kompilować. Nie oczekujemy, że zadziała na hackathonie, bo bez zgody Huawei dla naszego app ID autoryzacja się nie uda. Na urządzeniu testujesz tylko wtedy, gdy człowiek potwierdzi dostęp. Commit.

## Krok 2B (zamiast 2A, gdy kitu nie ma w SDK albo brakuje czasu)
`HuaweiHealthSource` jako stub: `status() = UNAVAILABLE`, puste listy i komentarz z linkiem do dokumentacji Health Service Kit oraz informacją, że dostęp wymaga zgody Huawei. Żadnych wymyślonych wywołań API. Commit.

## Krok 3: gałąź `feature/addon-ux` (teksty i przepływ; bez przebudowy ekranów)
1. **Onboarding/zgoda** staje się ekranem „Connect Huawei Health”:
   - **co czytamy:** kroki, tętno spoczynkowe, sen, minuty aktywności, VO₂max, HRV i treningi z ostatnich 90 dni;
   - **czego nie czytamy:** lokalizacja, EKG, ciśnienie, SpO₂, waga, kontakty;
   - **gdzie liczymy:** „on this phone”;
   - **co wychodzi:** „a signed tier, only when you share”.

   Przyciski:
   - „Connect Huawei Health” wywołuje adapter. Przy stubie albo braku zgody pokazuje „Not available in this build. Using demo data.”
   - „Use demo data”.

   Checkbox zgody na dane zdrowotne (RODO art. 9) zostaje osobno i jest wymagany w obu ścieżkach.
2. **Wiersz źródła danych** (Dashboard albo Settings, tam gdzie już jest) ma statusy:
   - „Huawei Health · connected”,
   - „Huawei Health · not authorized”,
   - „Huawei Health · unavailable in this build”,
   - „Demo data (synthetic, Huawei Health format)”.

   Przełącznik person pokazujesz tylko w trybie demo.
3. **„Why this tier”:**
   - pod nagłówkiem dopisz źródło: „Signals from Huawei Health” albo „Demo signals”;
   - przy Missing evidence dla VO₂max/HRV, gdy status to `CONNECTED` i nie ma tabeli percentyli, pokaż tekst „Not scored yet: needs a reference table”, a nie „no data”.
4. **Karta Live i moduł `watch`:** podpis „Live from FairWear on your watch. Not part of the score until the day closes.” Bez wzmianki o Huawei Health.
5. Nie zmieniaj nawigacji, motywu ani podpisu. Zrzuty ekranów: onboarding, Dashboard w demo, Why. Commit.

## Krok 4: gałąź `feature/addon-docs` (README, ARCHITECTURE, pitch)
1. **Diagram w README/ARCHITECTURE:**
   - `WATCH 5 → Huawei Health (phone) → [Health Service Kit + user authorization] → FairWear on the phone (HES-Lite + wear rules) → signed tier → QR → partner`;
   - obok: `FairWear watch app → live heart rate + wear state (not part of HES)`.
2. **Tabela „co prawdziwe, a co symulowane”:**
   - „Huawei Health connection: adapter against Health Service Kit (2A) / stub (2B); access to sensitive data needs Huawei approval, not granted during the hackathon”;
   - „Demo: synthetic history in Huawei Health record format”;
   - „VO₂max/HRV from Huawei Health: not scored without a cited percentile table”.
3. **Zdanie do pitchu:** „FairWear is an add-on for Huawei Health users: with their permission it reads what Huawei Health already measures, scores it on the phone, and shares only a signed tier.”
4. **Skrypt demo (2 min):**
   1. „Connect Huawei Health” → status „unavailable in this build” → „Use demo data”.
   2. Dashboard: HES, Coverage, Confidence.
   3. Why: Strongest, Improvement, Missing evidence.
   4. Suwak tętna na żywo: wynik stoi.
   5. Share QR → widok partnera → tamper → „Invalid signature”.
5. **AI_WORKFLOW.md:** wpis, że tę korektę kierunku i mapper przygotował Claude; co sprawdzono (testy), a czego nie (połączenie z Huawei Health).
6. Przejrzyj wszystkie teksty pod kątem listy zakazanych sformułowań. Commit.

## Raport po każdym kroku
Krótko:
- co zrobione,
- co skompilowane i uruchomione (ze zrzutem),
- jakie błędy poprawiłeś,
- czego nie dało się sprawdzić.

Po kroku 0 obowiązkowo podaj dokładne nazwy API Health Service Kit z SDK albo informację, że kitu nie ma.
