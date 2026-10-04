# 12: Telefon — jak wygląda raport, gdzie co jest w UI, co daje natywność, jak to zbudować (stan 02:20)

Uzupełnia `00-FAIRWEAR_PLAN.md` (decyzje obowiązują) i `11-DANE_WYMAGANIA_BRAKI.md`. Teksty UI są po angielsku.

## 0. Stan wyjściowy (gałąź `feature/ui-kit`, 02:13)

**Jest:**
- AD-1/AD-2/AD-3 i Settings;
- UI kit: `RingStat`, `MetricTile`, `DayStrip`, `WearBar`, `StatusPill`, `SectionCard`, `EmptyState`, `ValueWithUnit`;
- tokeny kolorów (metryki, stany noszenia, tiery; jasne i ciemne);
- karty Watch link w wersji dla użytkownika oraz osobna strona „Verification details”;
- `PartnerVerifier` z testami S-1–S-20;
- Demo feed na zegarku;
- karta 2×2 i skrót;
- skill projektu `fairwear-ui`.

**Nie ma:**
- silnika HES-Lite, person i serwisu (`fairwear-ui.zip` nadal poza `_incoming/`);
- ekranów: Raport (Home z wynikiem), Why this tier, Calendar, Share, Partner;
- prywatności: dziennik wysłanych danych, eksport, usuwanie.

---

## 1. Czym jest „raport” na telefonie

Raport to **podsumowanie ostatnich 30 dni programu**. Składa się z czterech warstw, każda liczona osobno:

| Warstwa | Co pokazuje | Skąd | Wychodzi do partnera? |
|---|---|---|---|
| **Wynik** | HES 0–100, tier A/B/C, Evidence Coverage, Data Confidence | HES-Lite na zakończonych dniach (28 d) | tylko **tier** |
| **Noszenie** | dni zgodne (≥ 85%), noce, przerwy, podejrzane przerwy, flaga | reguły noszenia (`defaults.ets`) na slotach W/C/O/U | tylko **eligible** (tak/nie) |
| **Uprawnienie i korzyść** | eligible = noszenie OK **i** brak flagi **i** wynik dostępny; poziom korzyści | reguła poniżej | `eligible` |
| **Dowody** | kalendarz dni, zweryfikowane dni z zegarka, odwołania, pauzy | `ReportBuilder` i Watch Link | **nic** |

Poziom korzyści (zgodny ze wszystkimi personami z raportu; wpisz do README):

| Warunek | Poziom |
|---|---|
| eligible i tier A | **Full benefit** |
| eligible i tier B | **Partial benefit** |
| tier C albo nie eligible albo brak wyniku | **No benefit this month** |

Podany zawsze z powodem, np. „3 suspicious breaks”, „Score C”, „Not enough data yet”.

**Do partnera wychodzi wyłącznie podpisany claim:** `tier`, `eligible`, `period` (plus `v`, `nonce`, `issuedAt`, `kid`). HES, Coverage, flagi, pauzy i wartości zdrowia **nigdy** nie wychodzą (S-17).

---

## 2. Mapa ekranów (natywna nawigacja: `Tabs` + `Navigation` + `bindSheet`)

```
Onboarding (pierwsze uruchomienie, już jest)
  AD-1 Welcome → AD-2 krok 1 (HUAWEI Health: plansza DEMO albo Health Sim)
               → AD-2 krok 2 (zgoda RODO per typ) → [opcjonalnie: Pair your watch] → Report

Tabs (dolny pasek, 3 zakładki)
├── Report ......... raport miesiąca (Home)
│     ├── Why this tier                      (push)
│     └── Metric detail (np. Sleep)          (sheet, opcjonalnie)
├── Evidence ....... [Calendar | Watch days]  (segmented)
│     ├── Day details                        (sheet) → Appeal this day / Mark as sick day
│     └── Verification details               (push, już jest)
└── Share .......... kod dla partnera (QR)
      └── Partner view (DEMO)                (push, inny kolor nagłówka)

Ikona ⚙ w nagłówku → Settings
  ├── Data source (AD-3: status, zakresy, Disconnect / Reconnect)
  ├── Watch (parowanie, sync, forget)
  ├── Privacy: What left this phone · Export my data · Delete my data
  ├── Demo controls: persona, live HR i kroki, Close the day, Reset demo, demo clock
  └── About (zastrzeżenia, wersja, licencje)

Poza aplikacją: karta 2×2 na ekranie głównym, skróty pod ikoną, wejście fwTarget
```

**Zmiana `fwTarget`:**
- `dashboard` → zakładka Report;
- `share` → zakładka Share;
- `source` → Settings › Data source.

Dodaj `evidence` (zakładka Evidence) i rozszerz test `EntryTarget`.

---

## 3. Ekrany: jak wyglądają, jakie dane, jakie stany

Szkice są poglądowe. Odstępy, kolory i typografia pochodzą ze skilla `fairwear-ui` i z UI kitu.

### 3.1 Report — persona z wynikiem (Ania A/92, Tomek B/79, Marek B/75)

```
┌─────────────────────────────────────────┐
│ FairWear                    [Ania ▾ DEMO] ⚙ │  ← przełącznik person tylko w demo
│ ● HUAWEI Health · Demo data · 07:00          │  ← StatusPill → Settings › Data source
│ 4 Sep – 3 Oct                                │
│ ┌───────────────────────────────────────┐   │
│ │   ╭───────╮   A  Strong overall profile│   │  ← RingStat (HES) + znaczek tieru
│ │   │  92   │   [Coverage 100%] [High]  │   │  ← chipy Coverage / Confidence
│ │   ╰───────╯                           │   │
│ │   ✓ Full benefit · eligible            │   │  ← poziom korzyści + powód
│ │   Why this tier ›                      │   │
│ └───────────────────────────────────────┘   │
│ ┌ Wear this month ──────────────────────┐   │
│ │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░  28 of 30 days ✓  │   │  ← WearBar (≥ 85% wymagane)
│ │ ○○●●●●● last 7 days  · 0 suspicious   │   │  ← DayStrip → Evidence
│ └───────────────────────────────────────┘   │
│ ┌ Steps ─────────┐ ┌ Active minutes ─────┐  │  ← MetricTile ×8, 2 kolumny
│ │ 9 412 /day      │ │ 212 min/week        │  │     wartość + jednostka,
│ │ ▁▃▅▆▅▇▆ 28 d    │ │ ▂▄▆▅▇▆▅             │  │     słupki 28 d, plakietka
│ │ HUAWEI Health   │ │ HUAWEI Health       │  │     pochodzenia
│ └─────────────────┘ └─────────────────────┘  │
│  Resting HR · Sleep · Sleep regularity ·     │
│  VO₂max · HRV · Recovery (HRR)               │
│ ┌ Today · live, not scored ─────────────┐   │  ← Live card
│ │ ♥ 72 bpm   👣 5 843 steps             │   │
│ │ Enters your score when the day closes. │   │
│ └───────────────────────────────────────┘   │
│ Prototype weights, not clinically validated. │
├─────────────────────────────────────────┤
│   Report        Evidence        Share        │
└─────────────────────────────────────────┘
```

**Stany do pokazania:**
- **Tomek:** „1 point to A” pod znaczkiem tieru i „Partial benefit”. Kafel HRV „Not measured — doesn't lower your score”, szary i neutralny.
- **Marek:** „No benefit this month · 3 suspicious breaks” i czerwona kropka w „Wear this month”. Dotknięcie otwiera Evidence z przefiltrowanymi dniami.
- **Zakres wyłączony w AD-2:** kafel „Off · missing evidence”, Coverage niższe.

### 3.2 Report — brak wyniku (Ola, 43%)

```
┌ Hero ─────────────────────────────────┐
│   ◌  No score yet                      │  ← EmptyState w miejscu RingStat
│      43% of the evidence we need       │
│ ┌ What unlocks your score ──────────┐ │  ← karta gotowości (DN-4)
│ │ Sleep regularity     9 of 14 nights │ │     liczniki validCount / minCount
│ │ Resting HR           6 of 10 days   │ │
│ │ ▸ Wear the watch at night           │ │     instrukcje, nie odczyt ustawień
│ │ ▸ Turn on continuous heart rate     │ │
│ │   monitoring in HUAWEI Health       │ │
│ └─────────────────────────────────────┘ │
│   Share is available once you have a score │
└────────────────────────────────────────┘
```

### 3.3 Why this tier (push z Report; przykład: Tomek)

```
HES 79 · B · 1 point to A
Coverage 90% · Confidence High

Strongest
  ☾ Sleep timing regularity  ███████████▉ 96   ±24 min · weight 17%
  ◇ VO₂max                   ███████████▏ 89   82nd percentile
  👣 Daily steps              ██████████▊  86   8 640 /day
To improve
  ↺ Heart-rate recovery      ███████▏     58   22 bpm in 60 s
  ⚡ Active minutes           ████████▏    67   118 min/week
  ♥ Resting heart rate       █████████    74   66 bpm
  → Sleeping 7 h a night would lift you to A.   ← kontrfakt (WhatIf), tylko składniki Core
Missing evidence
  HRV — not measured. Missing data never lowers your score.
How it's calculated ▾   (wagi, wzór, minima, „prototype assumptions”)
```

Wagi efektywne (`effectiveWeight`) sumują się do 100% dostępnych składników.

### 3.4 Evidence › Calendar (Marek) i szczegóły dnia

```
[ Calendar | Watch days ]
┌ This month ───────────────────────────┐
│ 26 of 30 days compliant · 3 suspicious │
│ breaks → flagged                        │
│ One break never flags. Flag = 3 or more,│
│ or 2+ on over 30% of days.              │
└────────────────────────────────────────┘
 Mo Tu We Th Fr Sa Su
  ●  ●  ●  ◐  ●  ●  ●     ● compliant  ◐ short
  ●  ✖  ●  ●  ●  ✖  ●     ✖ suspicious ⏸ sick day
  ...                     ○ unknown

Sheet „Wed 17 Sep":
  Worn 14 h 20 min · night 5 h 10 min · charging 40 min
  Off-wrist 13:05–18:40 (5 h 35 min)
  24 h before: resting HR +9 bpm, steps −46%
  → "Resting heart rate +9 bpm and steps −46% in the 24 h before this break."
  [ Appeal this day ]   [ Mark as sick day (2 of 5 left) ]
  Sick days are never sent to your partner.
```

### 3.5 Evidence › Watch days (już jest, karty z UI kitu)

`DayStrip` z 7 dni, karty dni z `WearBar` W/C/O/U i plakietką „Verified ✓”. Etykieta „Demo clock”, jeśli dotyczy. Pod spodem „Verification details ›” (`kid`, `seq`, chain, log, transport „DEMO relay (hdc)”).

### 3.6 Share

```
Show this code to your partner
┌ What the partner sees ────────────────┐
│ Tier B · Eligible: no · 4 Sep – 3 Oct  │
│ Technical ▾ (kid, nonce, issued at)    │
└────────────────────────────────────────┘
          ┌──────────────┐
          │   QR CODE    │                ← komponent QRCode
          └──────────────┘
  312 of 512 characters · 🔒 HUKS key
  Not in this code: your score, coverage, flags,
  sick days or any health data.
  [ Open partner view (demo) ]
```

**Przepływ nonce w demo (D4):** wejście na Share prosi o nonce `PartnerVerifier` (rola partnera w tej samej aplikacji), podpisuje claim i zapisuje `LedgerEntry`.

**Ola (brak wyniku):** „Tier: not available”, a przycisk jest nieaktywny z wyjaśnieniem.

### 3.7 Partner view (DEMO, inny kolor paska: „PARTNER · demo”)

```
[ Use the code from this phone ]     ← emulator nie ma kamery, token przekazywany w aplikacji
        ✓ Signature valid
  Tier B · Eligible: no · 4 Sep – 3 Oct
  Key: HUKS key (from partner registry)
  Checked: format → key → signature → nonce → not used
  [ Verify the same code again ] → ✗ Already used
  [ Change tier to A and verify ] → ✗ Invalid signature (stopped at: signature)
```

### 3.8 Settings

| Sekcja | Zawartość |
|---|---|
| Data source | już jest (AD-3); dochodzi lista 7 zakresów z przełącznikami (ponowna zgoda) |
| Watch | parowanie, ostatni sync, Sync now, Forget |
| Privacy | **What left this phone** (lista `LedgerEntry`: czas, odbiorca, dokładny token, bajty) · **Export my data** (plik JSON w sandboksie) · **Delete my data** (historia, klucz, dziennik; z potwierdzeniem) |
| Demo controls | persona, suwaki live HR i kroków (nie zmieniają HES), Close the day, Reset demo, demo clock |
| About | „Not a medical device. Prototype weights, not clinically validated.”, wersja, licencje |

### 3.9 Poza aplikacją

| Element | Zawartość |
|---|---|
| Karta 2×2 | już jest; po HES: pierścień Coverage, „Score ready”, status, nigdy tier |
| Skróty | „Data source”; po Share dochodzi „Show partner code” (`fwTarget: share`) |

---

## 4. Gdzie dokładnie dodajemy każdą opcję

| Funkcja | Miejsce w UI | Trasa / komponent | Plik (propozycja) |
|---|---|---|---|
| Raport miesiąca | zakładka Report | `ReportView` (zastępuje `DashboardView`) | `entry/.../view/ReportView.ets` |
| Przełącznik person (demo) | chip w nagłówku Report + Demo controls | sheet z listą `HesPersonas.IDS` | `view/PersonaSheet.ets` |
| Why this tier | „Why this tier ›” w karcie wyniku | push `why` | `view/WhyPage.ets` |
| Karta gotowości | Report (Coverage < 100% albo brak wyniku) | sekcja | `view/ReadinessCard.ets` |
| Kalendarz i szczegóły dnia | Evidence › Calendar | sheet `DaySheet` | `view/EvidenceView.ets`, `view/DaySheet.ets` |
| Odwołanie i pauza chorobowa | `DaySheet` | akcje | jw. + logika w `common` |
| Dni z zegarka | Evidence › Watch days | już jest | `WatchLinkCard` |
| Share i QR | zakładka Share | `ShareView` | `view/ShareView.ets` |
| Partner | Share › „Open partner view” | push `partner` | `view/PartnerPage.ets` |
| Dziennik wysłanych danych | Settings › Privacy | push `ledger` | `view/LedgerPage.ets` |
| Eksport i usuwanie | Settings › Privacy | akcje z potwierdzeniem | `platform/DataStore.ets` |
| Demo controls | Settings › Demo | push `demo` | `view/DemoControlsPage.ets` |

---

## 5. Co dajemy, zostając natywni (ArkTS/ArkUI, bez WebView i RN)

Każdy punkt ma uzasadnienie dla użytkownika (kryterium „nie na pokaz”):

| Funkcja platformy | Gdzie | Po co użytkownikowi / jury | Stan |
|---|---|---|---|
| **HUKS** (klucz nieeksportowalny, ECDSA P-256) | Share | podpisu nie da się podrobić bez urządzenia | ✓ |
| **CryptoFramework** (losowy nonce, weryfikacja) | Partner | jednorazowy kod, powtórka odrzucona | ✓ (`PartnerVerifier`) |
| **Form Kit** (karta 2×2) | ekran główny | status bez otwierania aplikacji, bez tieru | ✓ |
| **Skróty pod ikoną** | ikona | szybki kod przy okienku partnera | ✓ / dochodzi Share |
| **Want / `fwTarget`** | wejście | aplikacja gospodarz może otworzyć FairWear (droga do HUAWEI Health) | ✓ |
| **`Navigation` + `Tabs` + `bindSheet`** | cała aplikacja | systemowe przejścia, gesty wstecz, arkusze | częściowo |
| **`QRCode`** (komponent systemowy) | Share | bez zewnętrznych bibliotek | do zrobienia |
| **HM Symbol, `sys.color`, tryb ciemny** | cała aplikacja | wygląd systemowy, automatyczny dark mode | ✓ kit |
| **Dostępność** (`accessibilityText`, skalowanie czcionki) | `RingStat`, `MetricTile`, kalendarz | czytnik ekranu czyta „Score 92, tier A”; Human-Centric | **do zrobienia (15–20 min)** |
| **Preferences** (lokalny stan, bez sieci i uprawnień) | karta, dziennik, pauzy | dane zostają na telefonie | ✓ |
| **Sensor + battery** (zegarek) | zegarek | dowód noszenia, ładowanie | ✓ |
| **`openLink` / `startAbilityForResult`** | AD-2 (Health Sim, opcja) | prawdziwa zgoda między dwiema aplikacjami | K6 |
| **Lokalizacja zh_CN** (opcja) | główne ekrany | rynek chiński (HarmonyOS), jury Huawei | P2, około 45 min |

---

## 6. Czego w tej wersji nie osiągniemy i jak to pokazać uczciwie

| Ograniczenie | Pokazujemy jako |
|---|---|
| Prawdziwe dane z HUAWEI Health (wymagają zgody Huawei, około 15 dni roboczych) | status „Demo data”, tabela real vs simulated, ścieżka produkcyjna w ARCHITECTURE |
| Skan QR kamerą na emulatorze | „Use the code from this phone” (token przekazywany w aplikacji) |
| Połączenie telefon ↔ zegarek na emulatorach | relay `hdc` z etykietą „DEMO relay” |
| Atestacja klucza (zmodyfikowana aplikacja może podpisać dowolny tier) | jawne ograniczenie w SECURITY.md |
| Powiadomienia i synchronizacja w tle | „Next steps” (zbędne uprawnienia teraz) |

---

## 7. Jak to zbudować: dwie ścieżki i decyzja o 03:00

**Ścieżka A (paczka dotrze do `_incoming/` do 03:00).** Bierzesz z `fairwear-ui` **logikę i modele widoku**, a **nie widoki**:
- `hes/`, `HesPersonas`, `HesSession`, `ReportBuilder`;
- `FairWearService` i `EngineFairWearService`;
- `ViewModels` (`MonthVM`, `ClaimVM`).

Ekrany z sekcji 3 rysujesz **na naszym UI kicie** (`ReportView`, `WhyPage`, `EvidenceView`, `ShareView`, `PartnerPage`). Widoki z paczki służą tylko jako wzór treści. Unikasz dwóch stylów w jednej aplikacji.

Szacunek: logika 45 min, ekrany 2–2,5 h.

**Ścieżka B (o 03:00 paczki nadal nie ma).** Odtwarzasz HES-Lite **ze specyfikacji** `materials/hes-documents/HES_Lite_Final_Hackathon_Spec_v1.0.docx`. Specyfikacja jest kompletna:
- wagi, krzywe (sekcja 6), minima i cele (sekcja 7), Confidence (sekcja 8), tiery (sekcja 9);
- szkielet typów i funkcji (sekcje 12–13);
- listę testów (sekcja 15);
- wymagane tablice person (sekcja 16).

Kroki:
1. `common/src/main/ets/hes/` i testy z sekcji 15. Około 1 h.
2. Generator 6 person (dziennie: kroki, RHR, moderate, vigorous, początek i koniec snu, długość snu; opcjonalnie VO₂max i HRV jako percentyle, HRR1), deterministyczny, z seedem. Strojenie pod Załącznik B planu. Około 1 h.
3. **Jeśli do 04:00 wyniki person nie trafiają dokładnie w Załącznik B,** agent raportuje swoje liczby, a człowiek decyduje, czy zatwierdzić je jako nowy Załącznik B. Raport HES-Lite to cel, nie umowa. Tiery, flagi i „brak wyniku u Oli” muszą się zgadzać zawsze.
4. Reguły noszenia i kalendarz Marka z `ReportBuilder` własnej roboty: sloty z generatora, `SelectiveNonWear` już jest.

**Wspólne dla A i B (kolejność):**
1. `ReportView` i stany z 3.1 i 3.2.
2. `WhyPage`.
3. `ShareView` i `PartnerPage` (na gotowym `PartnerVerifier`).
4. `EvidenceView` z kalendarzem i `DaySheet`.
5. `LedgerPage`.
6. Dostępność.
7. Eksport i usuwanie danych.
8. Pauza chorobowa.

Po każdym ekranie: zrzut jasny i ciemny, test logiki (gdzie jest logika), lint.

---

## 8. Wklejka dla agenta

```
TELEFON (uzupełnienie planu 00 i pliku 11; decyzje planu obowiązują; UI po angielsku; tylko UI kit
i skill fairwear-ui)

TEL-0 Decyzja o 03:00: jeśli _incoming/fairwear-ui istnieje → ścieżka A, inaczej ścieżka B
      (plik 12, sekcja 7). Zgłoś wybór.
TEL-1 Nawigacja: dolne Tabs [Report | Evidence | Share] wewnątrz istniejącej Navigation; ⚙ → Settings.
      fwTarget: dashboard→Report, evidence→Evidence (nowy), share→Share, source→Settings›Data source.
      Rozszerz test EntryTarget.
TEL-2 Logika raportu w common (czysta, z testami):
      benefitLevel(eligible, tier, hasScore) → FULL | PARTIAL | NONE z powodem tekstowym.
      Testy dla wszystkich 6 person z Załącznika B.
TEL-3 ReportView (zastępuje DashboardView), plik 12 sekcje 3.1 i 3.2:
      RingStat HES, znaczek tieru, chipy Coverage i Confidence, benefit z powodem,
      "Why this tier ›", "Wear this month" (WearBar + DayStrip), 8 × MetricTile z plakietką
      pochodzenia i stanami "Off · missing evidence" / "Not measured", Live card
      "live, not scored", karta "What unlocks your score" (validCount / minCount),
      chip persony (tylko demo). Zrzuty: Ania, Tomek, Marek, Ola (jasny i ciemny).
TEL-4 WhyPage (3.3): Strongest / To improve / Missing evidence, effectiveWeight, wartości surowe
      z jednostką, jedno zdanie kontrfaktu (tylko składniki Core), sekcja
      "How it's calculated" z disclaimerem.
TEL-5 ShareView (3.6): nonce z PartnerVerifier w chwili wejścia, podpis ProofSigner,
      QRCode, karta "What the partner sees", długość "x of 512", plakietka klucza,
      LedgerEntry przy pokazaniu kodu. Bez wyniku (Ola): przycisk nieaktywny z powodem.
TEL-6 PartnerPage (3.7): pasek "PARTNER · demo", "Use the code from this phone", duży status
      i kroki weryfikacji, przyciski "Verify again" (→ Already used) oraz
      "Change tier and verify" (→ Invalid signature).
TEL-7 EvidenceView (3.4): segmented Calendar | Watch days; kalendarz 30 dni z legendą;
      DaySheet: noszenie, noc, ładowanie, przerwa, kontekst 24 h, zdanie powodu,
      "Appeal this day" → "Appeal sent".
      "Mark as sick day" (≤ 5 / 30, nigdy w claimie ani w dzienniku) — jeśli brak w paczce.
      Watch days = istniejące karty.
TEL-8 Settings › Privacy: LedgerPage, Export my data (JSON w sandboksie), Delete my data
      (potwierdzenie; czyści historię, klucz, dziennik, kartę).
TEL-9 Dostępność: accessibilityText na RingStat ("Score 92, tier A, coverage 100 percent"),
      MetricTile, dniach kalendarza i QR; test zrzutem przy dużej czcionce systemowej.
TEL-10 Skrót "Show partner code" (fwTarget share). Karta 2×2: pierścień Coverage
       i "Score ready", nigdy tier.

Kolejność: TEL-0 → TEL-1 → TEL-2 → TEL-3 → TEL-4 → TEL-5 → TEL-6 → TEL-7 → TEL-9 →
TEL-8 → TEL-10. Bramka 04:00 (plan 00): TEL-3 i TEL-5/6 na emulatorze z personami.
Po 06:30 żadnych nowych ekranów. Raport jak w planie.
```

---

## 9. Scenariusz demo na telefonie (około 90 s z całych 2–3 min)

1. Welcome → zgoda (2 kroki) → **Report: Ania A/92, Full benefit**.
2. Chip persony → **Tomek B/79**: „1 point to A” → Why this tier (najmocniejsze, do poprawy, HRV missing nie obniża wyniku).
3. **Marek:** „No benefit · 3 suspicious breaks” → Evidence → czerwony dzień → arkusz z powodem → „Appeal this day”.
4. **Ola:** „No score yet, 43%” i „What unlocks your score”.
5. **Share:** QR, „Not in this code: your score…” → Partner view: ✓ Signature valid → „Verify again” → Already used → „Change tier” → Invalid signature.
6. Settings › Privacy › **What left this phone**: dokładnie ten jeden token. Data source → Disconnect → Reconnect.
