> Public-safe copy of a team brief (in Polish) that was handed to a coding-agent session as its standing instruction during HackYeah 2026. Kept as written; which briefs are still in force is listed in `docs/prompts/README.md`.

# 13: Ekrany telefonu z kanwy jako działający ArkUI na emulatorze (teraz, bez czekania na HES)

Uzupełnia plan `00` oraz pliki `11` i `12`. Decyzje planu obowiązują.

Źródło wyglądu: kanwa „FairWear — ekrany telefonu” i jej pliki w `C:\dev\fairwear-specs\mock-telefon\*.dc.html`. Te pliki to HTML z dokładnymi wymiarami, odstępami, kolorami i tekstami. Czytasz je jako specyfikację, **nie** kopiujesz HTML do aplikacji.

## Po co i zasady uczciwości

- Ekrany powstają **teraz, na danych podglądowych**, równolegle z blokadą HES. Gdy wejdzie silnik (ścieżka A albo B z pliku 12), zmieniasz **jedno miejsce**: serwis danych.
- **Podgląd jest jawnie oznaczony.** StatusPill pokazuje „Demo data · preview”, a pod kartą wyniku stoi linia „Score engine not connected — preview values”. README: „Phone screens currently render fixed preview data matching the expected persona results; the HES-Lite engine replaces it.”
- **Share i Partner są prawdziwe.** Podpis HUKS przez `ProofSigner`, nonce i weryfikacja przez `PartnerVerifier`. Podpisywany tier pochodzi z podglądu, co oznaczasz na Share małą linią „Tier from preview data”.
- Wygląd to **nasz** projekt na tokenach FairWear, a nie kopia HUAWEI Health (D16). Na urządzeniu obowiązuje systemowy font (HarmonyOS Sans) i ikony HM Symbol z `KitTokens`. SVG z kanwy nie przenosisz.

## M-1: model i dane podglądu (`common`, czysta logika, testy)

1. `common/src/main/ets/report/ReportModels.ets` zawiera minimalne modele widoku:
   - `PersonaReport`: `id`, `name`, `period`, `hes` (−1 = brak), `tier` (`'A'|'B'|'C'|'NONE'`), `coveragePct`, `confidence` (`'High'|'Medium'|'Low'|'Insufficient'`), `eligible`, `benefit` (`'FULL'|'PARTIAL'|'NONE'`), `benefitReason`, `pointsToNext`;
   - `components: ComponentRow[]` (`id`, `label`, `score` lub −1, `raw`, `unit`, `weightPct`, `available`, `validCount`, `minCount`, `bars7: number[]`, `source`);
   - `wear`: `compliantDays`, `totalDays`, `nightsWorn`, `suspicious`, `flagged`, `days: DayCell[]` (`n`, `state`: `COMPLIANT|SHORT|SUSPICIOUS|SICK|UNKNOWN`);
   - `live`: `hr`, `steps`;
   - `whatIf`: string.

   Jeśli dotrze paczka, mapujesz `MonthVM` i `ClaimVM` na te modele, a nie odwrotnie.
2. `common/src/main/ets/report/Benefit.ets`, czyli `benefitLevel(eligible, tier, hasScore)`:

   | Warunek | Wynik |
   |---|---|
   | eligible i tier A | `FULL` |
   | eligible i tier B | `PARTIAL` |
   | w pozostałych przypadkach | `NONE` |

   Powód tekstem, np. „3 suspicious breaks”, „Score C”, „Not enough data yet”.
3. `common/src/main/ets/report/PreviewReports.ets` zawiera 6 person. HES, tier, Coverage, Confidence i benefit są **dokładnie** z Załącznika B planu. Wartości składników, dni i 7-dniowe słupki to wartości ilustracyjne zgodne z kanwą: Ania jak `Main.dc.html`, Tomek jak `WhyTomek.dc.html`, Marek z kalendarzem jak `EvidenceMarek.dc.html` (3 dni podejrzane, 1 krótki, 3 chorobowe), Ola jak `ReportOla.dc.html` (liczniki X of Y). Kasia i Ewa w tej samej konwencji.
4. Testy:
   - podgląd 6 person zgodny z Załącznikiem B: hes, tier, coverage, confidence, benefit, eligible;
   - `benefitLevel` dla wszystkich kombinacji;
   - suma `weightPct` dostępnych składników = 100 (±1).

   **Po wejściu silnika ten sam test sprawdza silnik**, czyli podgląd staje się złotym wzorcem.

## M-2: serwis i jeden przełącznik (`entry`)

- Interfejs `ReportService` (`personas()`, `report(id)`, `liveSet(...)`) ma dziś jedną implementację, `PreviewReportService`. Po HES dochodzi `EngineReportService`.
- Wybór jest w jednym pliku (`entry/.../report/ServiceLocator.ets`). Wybrana persona trzymana jest w `AppStorage`.

## M-3: nawigacja natywna

- `Tabs({ barPosition: BarPosition.End })` z systemowym `BottomTabBarStyle`: ikona `SymbolGlyph` i etykieta. Zakładki Report, Evidence i Share siedzą wewnątrz istniejącej `Navigation`. Ikona ⚙ otwiera Settings.
- Strony push: `why`, `partner`, `ledger`, istniejące `verification`, `settings` i `datasource`. `fwTarget` według pliku 12 (TEL-1).
- Tryb tytułu `Navigation` sprawdź w SDK: duży na zakładkach, mini z przyciskiem wstecz na stronach push.

## M-4: ekrany (komponenty UI kitu ↔ kanwa)

| Ekran (plik kanwy) | Elementy → komponenty ArkUI / kitu |
|---|---|
| **Report** (`Main.dc.html`, `ReportOla.dc.html`) | <ul><li>nagłówek: tytuł, chip persony (tylko demo, `bindSheet` z listą), przycisk ⚙ (`accessibilityText` „Settings”)</li><li>`StatusPill`, okres</li><li>karta wyniku: `RingStat` 124 vp z HES w środku, znaczek tieru (tło z `fw_tier_*` z alfą), 2 chipy, separator, wiersz benefitu z symbolem, „Why this tier ›”</li><li>„Wear this month”: `WearBar` z 30 dni, legenda, `DayStrip` z 7 dni, „Evidence ›”</li><li>siatka 2 × 4 `MetricTile` (`Grid` z `columnsTemplate('1fr 1fr')`, odstęp 10)</li><li>karta Today (live, not scored), disclaimer</li><li>Ola: `EmptyState` zamiast `RingStat` (przerywany pierścień 43%) i karta „What unlocks your score” z paskami X of Y i trzema instrukcjami</li></ul> |
| **Why** (`WhyTomek.dc.html`) | <ul><li>karta nagłówka: tier, HES, „1 point to A”, Coverage i Confidence, benefit</li><li>sekcje Strongest, To improve, Missing evidence: wiersz = kropka koloru metryki, nazwa, wynik, pasek 0–100 (`Progress` typu Linear albo `Row` z dwoma `Column`), surowa wartość z wagą</li><li>karta kontrfaktu, rozwijane „How it's calculated”, disclaimer</li></ul> |
| **Evidence** (`EvidenceMarek.dc.html`) | <ul><li>`SegmentButton` (komponent systemowy, sprawdź import w SDK) Calendar \| Watch days</li><li>karta podsumowania z plakietką Flagged i regułą flagi</li><li>siatka 7 × 5 (`Grid`) dni z kropką stanu, legenda</li><li>dotknięcie dnia otwiera `bindSheet` (szczegóły dnia: pasek dnia, 3 liczby, zdanie powodu, przyciski „Appeal this day” → „Appeal sent” i „Mark as sick day”, licznik pauz)</li><li>Watch days to istniejące karty</li></ul> |
| **Share** (`Share.dc.html`) | <ul><li>karta „What the partner sees” (tier, eligible, okres; Technical rozwijane: `kid`, nonce, `issuedAt`)</li><li>systemowy `QRCode` z tokenem</li><li>„x of 512 characters”, plakietka klucza z `ProofSigner`, zdanie „Not in this code…”, „Tier from preview data”</li><li>przycisk „Open partner view (demo)”</li><li>Ola: przycisk nieaktywny z powodem</li><li>pokazanie kodu zapisuje `LedgerEntry`</li></ul> |
| **Partner** (`Partner.dc.html`) | <ul><li>ciemny pasek tytułu „Partner view · PARTNER · DEMO”</li><li>„Use the code from this phone” → `PartnerVerifier.verify`</li><li>duży status z symbolem, „Checks, in order” (5 wierszy z prawdziwego wyniku weryfikatora)</li><li>„Try to cheat”: weryfikacja tego samego tokenu (→ Already used) i token ze zmienionym tierem (→ Invalid signature), z „stopped at: …”</li></ul> |
| **Ledger** (`Ledger.dc.html`) | <ul><li>Settings › Privacy › „What left this phone”: lista `LedgerEntry` z dokładnym tokenem (czcionka monospace), odbiorcą, bajtami i czasem, plus „Nothing else has left this phone.”</li><li>„Export my data” (JSON w sandboksie) i „Delete my data” (potwierdzenie, kolor błędu z `sys.color`)</li></ul> |

**Wymiary z kanwy (vp):**
- marginesy ekranu: 16;
- odstęp między kartami: 14;
- promień kart: 24, kafli: 20;
- wewnętrzny padding kart: 18–20;
- tytuł zakładki: 30 / 700;
- nagłówek karty: 16 / 600;
- liczba na kaflu: 24 / 700;
- jednostka: 12;
- pierścień: 124 i grubość 11;
- przyciski: min. 44 wysokości, główne 48–52 z pełnym zaokrągleniem.

**Kolory:**
- tło `sys.color` (background, sub_background);
- tekst `sys.color` (primary, secondary);
- metryki, stany noszenia i tiery z `fw_tokens.json` (jasne i ciemne);
- akcent `sys.color` emphasize.

## M-5: dostępność i tryb ciemny

- `accessibilityText`:
  - `RingStat`: „Score 92, tier A, coverage 100 percent”;
  - `MetricTile`: „Steps, 9412 per day”;
  - dzień kalendarza: „17 September, suspicious break”;
  - QR: „Code for your partner”.
- Zrzut przy dużej czcionce systemowej i zrzuty w trybie ciemnym.

## M-6: weryfikacja na emulatorze telefonu

- Zrzuty jasne i ciemne w `docs/screenshots/design/phone-*.jpeg`: Report Ania, Report Ola, Why Tomek, Evidence Marek z otwartym arkuszem, Share, Partner (valid, already used, invalid), Ledger.
- Porównanie z kanwą: wypisz różnice i powód każdej, np. komponent systemowy wygląda inaczej.
- Lint 0 błędów, `check-wording` 0 trafień. Testy M-1 dopisz do `docs/test-results.txt`.

## Kolejność i czas (około 3 h, równolegle z odblokowaniem HES)

| Krok | Czas |
|---|---|
| M-1 | 30 min |
| M-2 i M-3 | 30 min |
| Report (z Olą) | 45 min |
| Share i Partner | 40 min |
| Why | 25 min |
| Evidence z arkuszem | 35 min |
| Ledger | 15 min |
| M-5 | 15 min |
| M-6 | na bieżąco |

**Po wejściu HES:** `EngineReportService`, przełącznik w `ServiceLocator`, a etykieta podglądu znika. Testy M-1 muszą przejść na silniku.

Raport po każdym kroku jak w planie. Na koniec `/raport` i `/backup`.
