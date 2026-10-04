> Public-safe copy of a team brief (in Polish) that was handed to a coding-agent session as its standing instruction during HackYeah 2026. Kept as written; which briefs are still in force is listed in `docs/prompts/README.md`.

# 11: Dane — co zbieramy, co jest potrzebne do działania, czego brakuje, czym wzbogacić (stan 02:00)

Uzupełnia `00-FAIRWEAR_PLAN.md`; jego decyzje obowiązują.

Źródła:
- `HES_Lite_Final_Hackathon_Spec_v1.0.docx`, `HES-dla-HUAWEI-WATCH-5-audyt-v0.4` i „Finalny raport” (gałąź `materials`);
- kod na `main` (`types.ets`, `defaults.ets`, `health/HealthRecords.ets`, `watchlink/`);
- paczka Health Sim (`_incoming/HealthSim`).

---

## 0. W skrócie

1. FairWear potrzebuje **czterech strumieni danych**:
   - historia z HUAWEI Health, z której liczony jest wynik;
   - dowód noszenia z zegarka, z którego liczona jest zgodność noszenia i wykrywane są przerwy;
   - dane od użytkownika: zgody, pauzy chorobowe, odwołania;
   - dane od partnera: nonce i rejestr kluczy.
2. **Wynik HES-Lite ma 8 składników.** Pięć z nich to **Core** (70% wagi): kroki, MVPA, tętno spoczynkowe, długość snu i regularność snu. Bez wszystkich pięciu nie ma wyniku, tylko status „Insufficient data”.
3. **Dziś nie działa żaden z ośmiu.** Silnik, persony i źródło demo są w `fairwear-ui.zip`, a paczki nadal nie ma w `_incoming/`. Rekordy (`HealthRecords`) i zgody (`HealthConnection`) są gotowe.
4. **Trzy luki w samej definicji danych (nie w kodzie):**
   - brak reguły „ważnego dnia” (noszenie);
   - brak źródła MVPA i HRR w Health Sim;
   - brak wieku i płci, potrzebnych do percentyli VO₂max i HRV w prawdziwym adapterze.
5. **Wzbogacenia o największym stosunku efektu do wysiłku:**
   - ekran „What left this phone”;
   - pauza chorobowa;
   - karta gotowości danych („co odblokuje wynik”);
   - pochodzenie każdej wartości;
   - `docs/DATA.md` (minimalizacja danych jako argument dla jury).

---

## 1. Cztery strumienie danych

| Strumień | Skąd | Po co | Stan |
|---|---|---|---|
| **A. Historia zdrowia** | HUAWEI Health przez Health Service Kit; w demo persony (`HesPersonas`) albo Health Sim | wynik HES-Lite, tier, Why this tier | warstwa `HealthRecords`, `HealthSource` i `HealthConnection` gotowa; źródło demo i silnik w paczce |
| **B. Dowód noszenia** | zegarek FairWear: sloty 5-min W/C/O/U, ładowanie, pakiety dnia (Watch Link) | zgodność noszenia, podejrzane przerwy, flaga, „Verified watch day” | Watch Link działa (relay); na emulatorze dane to zera (brak Demo feed) |
| **C. Od użytkownika** | ekrany aplikacji | zgody per typ, pauza chorobowa, odwołanie dnia, profil ograniczonej mobilności | zgody gotowe; pauza, odwołanie i profil są w `types.ets` (K11, K12, K16), UI w paczce lub brak |
| **D. Od partnera** | partner (ubezpieczyciel) | nonce, rejestr `kid → klucz` | brak (`PartnerVerifier`, K3) |

**Zasada minimalizacji.** HUAWEI Health nie ma typu „noszenie”, więc z niego **nie** czytamy surowego tętna. Dowód noszenia pochodzi z zegarka FairWear (B). Z HUAWEI Health bierzemy tylko dzienne podsumowania (A).

**Czego nie czytamy:** SpO₂, temperatury, stresu, EKG, lokalizacji ani wagi. Health Sim generuje SpO₂, temperaturę i stres, więc FairWear **nie może o nie prosić** w zgodzie.

---

## 2. Co dokładnie potrzebuje HES-Lite (spec v1.0)

**Zasady obliczania:**
- liczone są tylko **zakończone** dni;
- okno to 28 dni;
- dzisiejsze wartości służą tylko do wyświetlania i wchodzą do historii po „Close the day”;
- brak danych nigdy nie oznacza zera.

| # | Składnik | Waga | Core | Wejście (rekord w repo) | Agregacja | Min / cel | HUAWEI Health | Health Sim | Persony |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Kroki | 12,5% | tak | `DailyActivity.steps` | średnia z ważnych dni (28 d) | 14 / 21 dni | kroki dzienne ✓ | sumy z interwałów 5-min ✓ | ✓ |
| 2 | MVPA | 15% | tak | `DailyActivity.moderateMinutes`, `vigorousMinutes` | (mod + 2×vig), suma 28 d / 4 → min/tydz. | 14 / 21 dni | zakres „medium/high-intensity activity” ✓ | **brak** | ✓ |
| 3 | Tętno spoczynkowe | 15% | tak | `DailyActivity.restingHeartRate` | mediana ważnych dni (28 d); tętno na żywo nigdy go nie zastępuje | 10 / 14 dni | ✓ | ✓ | ✓ |
| 4 | Długość snu | 12,5% | tak | `SleepSession.asleepMinutes` | mediana 28 ważnych nocy | 14 / 21 nocy | sen (TruSleep) ✓ | fragmenty snu ✓ (suma bez „awake”) | ✓ |
| 5 | Regularność snu | 15% | tak | `SleepSession.start`, `end` | SD zaśnięcia i pobudki (przeliczenie odporne na północ) | 14 / 21 nocy | ✓ | ✓ | ✓ |
| 6 | VO₂max | 15% | nie | `Vo2MaxEstimate.mlPerKgMin` → **percentyl** | ostatnia ważna wartość z 90 d | 1 / 2 w 90 d | ✓ (ml/kg/min) | raz w tygodniu ✓ | percentyl ✓ |
| 7 | HRV | 10% | nie | `HrvNight.rmssdMs` → **percentyl** | — | 7 / 14 nocy | **niepewne** (audyt: zegarek pokazuje HRV, ale API dla PL niepotwierdzone) | **brak** | percentyl ✓ |
| 8 | HRR1 | 5% | nie | `Workout.peakHeartRate`, `heartRate60s` | HRR1 = szczyt − tętno po 60 s | 2 / 3 sesje w 60 d | `com.huawei.recovery_heart_rate`, tylko „selected watches” | **brak** | ✓ |

**Wynik obliczeń:**
- `Coverage` = 100 × Σ wag dostępnych składników (Core = 70%, wszystkie = 100%);
- `HES` = zaokrąglona średnia ważona dostępnych składników (brakujących nie liczymy jako zero);
- `Confidence` = Coverage × jakość (`validCount` / cel); High ≥ 0,80, Medium ≥ 0,60;
- tier: A ≥ 80, B ≥ 60, C < 60, tylko przy komplecie Core.

**Czego spec nie definiuje, a audyt HW5 nazywa krytycznym:**
- **„Ważny dzień” dla kroków i MVPA.** 1000 kroków może oznaczać dzień siedzący albo zdjęty zegarek. Bez reguły noszenia kroki z dnia bez zegarka obniżają wynik. **Propozycja (wymaga zgody człowieka, D14):** dzień jest ważny dla kroków i MVPA, gdy zegarek był noszony **≥ 10 h między 07:00 a 23:00**. To typowa granica w badaniach z akcelerometrem. W demo walidację dnia biorą persony, a w produkcji sloty W z Watch Link.
- **Noc bez zegarka to „unknown”, nie czuwanie.** Inaczej regularność snu jest fałszywie zła.
- **Percentyle VO₂max i HRV wymagają wieku i płci** oraz tabeli referencyjnej ze źródłem. W demo percentyle podają persony (D7). W prawdziwym adapterze bez wieku, płci i tabeli składnik jest „missing”.

---

## 3. Co potrzebują reguły noszenia (zgodność i wybiórcze zdejmowanie)

Parametry z `defaults.ets` (zmiana wymaga zgody człowieka):

| Reguła | Dane wejściowe | Próg |
|---|---|---|
| Dzień zgodny | minuty noszenia na dobę (sloty 5-min W/C/O/U); ładowanie liczone do limitu | ≥ 20 h; ładowanie do 120 min |
| Noc | noszenie 00:00–06:00 (strefa persony) | ≥ 240 min |
| Miesiąc | udział dni zgodnych | ≥ 85% |
| Przerwa | ciąg slotów O | ≥ 120 min |
| Przerwa podejrzana | tętno spoczynkowe w 24 h przed przerwą vs baza **oraz** kroki w 24 h przed vs mediana | +7 bpm i spadek kroków do < 0,6 |
| Przerwa oceniana | odczyty tętna w 24 h przed przerwą | ≥ 12 (inaczej przerwa nie jest oceniana) |
| Flaga | liczba podejrzanych przerw | ≥ 3, albo ≥ 2 przy udziale > 30% dni; nigdy za 1 |
| Pauza chorobowa | dni oznaczone przez użytkownika | ≤ 5 na 30 dni; **nigdy nie trafia do partnera** |

**Skąd te dane:**
- Na produkcji z Watch Link: `slots` (288 znaków), `nightWornMin`, `nightChargingMin`, `breaks[]` z kontekstem (`hrSlots24hBefore`, `rhr24hBefore`, `steps24hBefore`) i `wearSource`.
- W demo z person (`ReportBuilder` w paczce).

**Wymaganie produktowe:** w HUAWEI Health musi być włączony **ciągły pomiar tętna**. Pojedyncze pomiary nie synchronizują się do HUAWEI Health, a rzadkie próbki wyglądałyby jak brak noszenia. To trafia do karty gotowości (sekcja 6).

---

## 4. Co jest wymagane, żeby całość działała (łańcuch od danych do weryfikacji)

| # | Ogniwo | Stan | Co zrobić |
|---|---|---|---|
| 1 | Źródło historii → `HealthRecords` (5 typów) | rekordy i zgody ✓; źródło demo **brak** | `SyntheticHealthSource` z `HesPersonas` (K2) |
| 2 | Maska ważnego dnia i nocy | **brak definicji** | decyzja (sekcja 2), potem filtr w mapperze i testy |
| 3 | `HealthRecords` → historia HES (mapper: noc do daty pobudki, drzemki po 14:00 pomijane, HRR1 > 0) | **brak** (zależy od typów HES) | po paczce; test: persona → rekordy → mapper daje to samo co persona |
| 4 | Agregaty 28 d, „Close the day”, dzisiejsze dane tylko do wyświetlania | w paczce | K2 |
| 5 | Silnik HES-Lite (43 testy) | **brak** | K2 |
| 6 | Zgodność noszenia i wybiórcze zdejmowanie (`ReportBuilder` i reguła `SelectiveNonWear`) | reguła ✓, `ReportBuilder` w paczce | K2 |
| 7 | Uprawnienie do korzyści = zgodność ≥ 85% i brak flagi i HES OK → poziom korzyści (pełna / częściowa / brak) | w paczce | K2; tabela poziomów do README |
| 8 | Claim → podpis HUKS | ✓ | — |
| 9 | Partner: nonce, rejestr, weryfikacja | **brak** | K3 |
| 10 | Ekrany wyniku, Why, kalendarz, Share, partner | **brak** | K2 i K5 |
| 11 | Zakresy zgody = dokładnie typy z sekcji 2 (bez SpO₂, temperatury, stresu) | ✓ (7 typów) | przy Health Sim pilnować tej listy |
| 12 | Gotowość danych (ciągły pomiar tętna, TruSleep, trening na zewnątrz dla VO₂max) | **brak** | karta gotowości (sekcja 6) |

---

## 5. Czego brakuje (priorytety)

**P0 — bez tego nie ma działającego produktu:**
1. `fairwear-ui.zip` w `_incoming/fairwear-ui/`. To zadanie człowieka i jedyna blokada wszystkich P0.
2. Silnik HES, `SyntheticHealthSource` i mapper (ogniwa 1, 3–6). Bramka: wyniki person zgodne z Załącznikiem B planu.
3. Weryfikator partnera (ogniwo 9).

**P1 — bez tego wynik jest podatny na zarzut „liczy zdjęty zegarek”:**
4. Reguła ważnego dnia i nocy (ogniwo 2), po decyzji człowieka. Nocy bez zegarka nie traktujemy jak czuwania.
5. Demo feed na zegarku (strumień B ma kształt zamiast zer).
6. Jeśli robicie Health Sim (K6), musi podawać **MVPA** (minuty umiarkowane i intensywne), **HRV** i **treningi z HRR1**, inaczej Core się nie domknie. Zalecany wariant „a”: historia z `HesPersonas` przekonwertowana do Health Sim, więc wszystkie typy pochodzą z person.

**P2 — dokumentacja zamiast kodu:**
7. Wiek i płeć dla percentyli: opisać w `docs/DATA.md` jako wymaganie prawdziwego adaptera. W demo percentyle podają persony.
8. Macierz możliwości „WATCH 5 × Polska × firmware × Health Service Kit” jako pierwszy krok po hackathonie (audyt HW5). W README „Next steps”.
9. Wersja definicji metryk (`metric_definition_id`) i wersja modelu przy wyniku. W README jako plan.

**Ryzyko prawne poza danymi:**
- Gałąź `materials` zawiera **oficjalne zrzuty ekranów Huawei** (`materials/prototypes/HealthDemo/docs/ref/*official*`, `activity-rings-*`, `health-glance-*`).
- **Tej gałęzi nie wypychasz do publicznego repo.** Materiały cudzych firm zostają lokalnie.
- To samo dotyczy PDF-ów z audytami, jeśli nie chcecie ich publikować.

---

## 6. Czym wzbogacić (od najlepszego stosunku efektu do wysiłku)

| # | Wzbogacenie | Dlaczego daje punkty | Wysiłek | Uwagi |
|---|---|---|---|---|
| E1 | **„What left this phone”**: dziennik wszystkiego, co opuściło telefon (typ `LedgerEntry` już jest; po usunięciu `'LLM'` zostaje tylko `CLAIM`): czas, odbiorca, dokładna treść, bajty | prywatność widoczna w działaniu (Human-Centric); jury od razu widzi, że wychodzi tylko claim | 30–45 min | dane już są w ścieżce Share |
| E2 | **Pauza chorobowa** w kalendarzu: „Mark as sick day”, ≤ 5 na 30 dni, dzień wyłączony ze zgodności, **nigdy nie trafia do partnera** (`pausedDays`, K11) | uczciwość i inkluzywność, mocna linia w pitchu | 45 min, jeśli paczka tego nie ma | sprawdź najpierw paczkę |
| E3 | **Karta gotowości danych** („What unlocks your score”): checklista „ciągły pomiar tętna”, „TruSleep”, „trening na zewnątrz dla VO₂max”, „noś zegarek w nocy” oraz liczniki z HES: „Sleep regularity: 9 of 14 nights” | zamienia „No score yet” w konkretną ścieżkę; pokazuje Coverage i Confidence ze spec | 30 min (liczniki są w paczce: „Needed for a score”) | stan ustawień HUAWEI Health opisujemy jako instrukcję, nie odczyt API |
| E4 | **Pochodzenie każdej wartości**: plakietka na kaflu metryki „HUAWEI Health · demo” / „FairWear watch · verified” / „Simulated (Health Sim)” | wiarygodność i uczciwość, zgodnie z tabelą real vs simulated | 20 min na UI kicie | |
| E5 | **`docs/DATA.md`**: tabele z sekcji 1–4 (co czytamy, po co, czego nie czytamy, okna, minima, gdzie liczone, co wychodzi) | wykonanie, prywatność, powtarzalność: dowód minimalizacji danych | 20 min | kopia z tego pliku po angielsku |
| E6 | **Why this tier z kontrfaktem**: „Sleep 7 h a night would lift you to A” (`WhatIfSuggestion` już jest w typach) | użyteczność: użytkownik wie, co zrobić | w paczce lub 30 min | tylko na składnikach Core i bez porad medycznych |
| E7 | **Usuń moje dane / eksportuj moje dane** (lokalna historia, klucz, dziennik) | RODO art. 17 i 20 w działaniu | 30 min | eksport jako plik JSON w sandboksie lub udostępnienie |
| E8 | **Profil ograniczonej mobilności** (`limitedMobility`, K16): kroki niedostępne zamiast zera, informacja o niższym Coverage | dostępność, Human-Centric | tylko pitch i README | zmiana HES wymaga zgody (D14); dziś tylko opis |
| E9 | **Health Sim**: prawdziwe połączenie dwóch aplikacji na emulatorze (`openLink`, zgoda, powrót z Data ID) | platforma i realizm demo | 1–2 h | tylko po bramce 04:00 (K6), z MVPA, HRV i HRR |

**Rekomendacja na tę noc:** E5, E3, E1 i E4 (razem około 1 h 45 min po K2). E2 tylko, jeśli paczka go nie ma. E6 i E7, jeśli zostanie czas. E8 i E9 według planu.

---

## 7. Wklejka dla agenta (uzupełnia `00-FAIRWEAR_PLAN.md`)

```
DANE (uzupełnienie planu 00; decyzji planu nie zmieniasz)

DN-1 (po K2) SyntheticHealthSource podaje HealthRecords dla wszystkich typów:
     DailyActivity (kroki, RHR, moderate i vigorous), SleepSession, Vo2MaxEstimate,
     HrvNight, Workout. Dane pochodzą z HesPersonas. Wyłączony zakres daje pustą listę
     albo -1, nigdy zero.
     Test: persona → rekordy → mapper daje te same kroki, RHR, MVPA, sen, VO2max,
     HRV i HRR1 co persona (dla VO2max i HRV porównujesz percentyle).
DN-2 Reguła ważnego dnia: DECYZJA CZŁOWIEKA. Propozycja: dzień ważny dla kroków i MVPA
     przy noszeniu ≥ 10 h w 07:00–23:00; noc bez zegarka = unknown, nie czuwanie.
     Po zgodzie: stała w defaults.ets (osobny commit), filtr w mapperze, testy:
     dzień z 3 h noszenia nie wchodzi do średniej kroków; noc bez zegarka nie psuje
     regularności snu. Wyniki person z Załącznika B nie mogą się zmienić. Jeśli się
     zmieniają, STOP i raport.
DN-3 docs/DATA.md (po angielsku): tabele 1–4 z pliku 11 (strumienie, składniki HES z
     oknami i minimami, reguły noszenia, czego nie czytamy, co wychodzi z telefonu).
     Link z README.
DN-4 Karta gotowości danych na Home i w "No score yet":
     - liczniki "X of Y" z HES (validCount / minCount);
     - checklista ustawień HUAWEI Health jako instrukcja: "continuous heart rate
       monitoring", "TruSleep", "outdoor run for VO2max", "wear the watch at night".
     Bez udawania, że odczytujemy te ustawienia.
DN-5 Pochodzenie wartości: plakietka na każdym MetricTile ("HUAWEI Health · demo",
     "FairWear watch · verified", "Simulated (Health Sim)").
DN-6 Ekran "What left this phone": lista LedgerEntry (tylko CLAIM): czas, odbiorca,
     dokładna treść tokenu, bajty. Wpis powstaje przy pokazaniu QR w Share.
DN-7 (jeśli paczka nie ma) Pauza chorobowa w kalendarzu: ≤ 5 na 30 dni, dzień wyłączony
     ze zgodności, nie trafia do claimu ani do dziennika. Test: Marek z pauzą na dniu
     przerwy nie dostaje dodatkowej podejrzanej przerwy.
DN-8 Health Sim (tylko w K6): oprócz obecnych typów dodaj moderate/vigorous minutes,
     HRV (nightly) i treningi (peak, HR po 60 s). FairWear prosi tylko o 7 typów,
     nigdy o SpO2, temperaturę ani stres.
DN-9 Gałąź materials: NIE wypychaj jej do publicznego repo (oficjalne zrzuty Huawei,
     PDF-y). W S8 sprawdź, że publiczny push obejmuje tylko main.

Kolejność: DN-3 (od razu, bez paczki) → po K2: DN-1 → DN-4 → DN-5 → DN-6 → DN-2
(po decyzji) → DN-7 → DN-8 (tylko K6). Raport jak w planie.
```

---

## 8. Decyzje dla człowieka

1. **Reguła ważnego dnia:** ≥ 10 h noszenia w 07:00–23:00, tak czy nie? Jeśli nie, kroki z dni bez zegarka liczą się do wyniku. Przyznaj to wtedy w README.
2. **Health Sim:** robicie (K6, wtedy DN-8) czy zostaje w „Next steps”?
3. **Gałąź `materials`:** zostaje lokalnie, potwierdź.
