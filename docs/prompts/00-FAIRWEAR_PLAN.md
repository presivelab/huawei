> Public-safe copy of a team brief (in Polish) that was handed to a coding-agent session as its standing instruction during HackYeah 2026. Kept as written; which briefs are still in force is listed in `docs/prompts/README.md`.

# FAIRWEAR: PLAN JEDYNY (stan 04.10, 01:30)

**Ten plik zastępuje wklejki 1–10 i `WKLEJKA_HEALTH_SIM_v2_AUDYT.md`.** Tamte pliki to od teraz archiwum i nie są instrukcjami.

Zasady pierwszeństwa:
- **Kod przeczy temu plikowi:** dopasuj się do kodu i zgłoś rozbieżność.
- **Raport „Finalny raport wdrożenia HES-Lite v1.0” przeczy repo:** wygrywają repo i ten plik. Raport jest tylko celem dla wyników person i zestawu ekranów, a nie opisem stanu kodu.

---

## 1. Produkt i hackathon

**FairWear to dodatek do HUAWEI Health.**
- Za zgodą użytkownika czyta to, co HUAWEI Health już mierzy.
- Na telefonie liczy deterministyczny wynik HES-Lite i tier A/B/C.
- Na zewnątrz wychodzi tylko **podpisany tier** (QR), który partner, np. ubezpieczyciel, weryfikuje bez dostępu do danych.
- Zegarek dokłada **podpisane, łańcuchowane dni noszenia** (Watch Link), więc wybiórczego zdejmowania zegarka nie da się ukryć.

**HackYeah 2026, zadanie Huawei.**
- Oddanie do **10:30**, koniec kodowania 11:00.
- Kryteria: oryginalność 20%, użyteczność 20%, wykonanie 20%, platforma 20%, demo 10%, powtarzalność 10%.
- Wymagane materiały:
  - publiczne repo;
  - instrukcje;
  - działające `.hap`;
  - nagranie;
  - opis architektury;
  - `AI_WORKFLOW.md`.

---

## 2. Stan repo `C:\dev\FairWear` (sprawdzony 01:30)

| Gałąź | Commit | Zawartość |
|---|---|---|
| `main` | `491bcb4` | integration (home-card + health-addon + watch-link) + W-0 |
| `feature/ui-foundation` | `f8b9720` | `main` + `security-watch` |
| `feature/security-watch` | `033ee7a` | S0, S1, S2, jedna reguła noszenia (I-3, część) |
| `feature/health-sim-audit` | `0e1143a` | Health Sim w `healthsim/` jako osobny projekt (P0 krok 1) |

Pozostałe gałęzie są już scalone i nieaktywne.

**Działa (z dowodami w `docs/test-results.txt` i `docs/screenshots/`):**
- Testy: common 83/83, watch 6/6. Build entry, watch i common przechodzi. Lint: 0 błędów.
- Przepływ dodatku:
  - AD-1: Welcome;
  - AD-2: zgoda w dwóch krokach z przełącznikami;
  - AD-3: status i odłączenie;
  - etykiety statusów po ludzku.
- Karta 2×2 bez tieru, skrót „Data source”, jedno wejście `fwTarget` z walidacją.
- Podpis HUKS ECDSA P-256 z kluczem zapasowym. Claim ma 7 pól, kanoniczne kodowanie i ścisły decode.
- Watch Link na emulatorach przez relay `hdc`: parowanie, pakiety dnia, łańcuch, „Invalid signature” i „Missing 1 day”.
- Bezpieczeństwo: S0 (hook pre-commit, lock files, klon w README), S1 (uprawnienia), S2 (logi bez wartości zdrowia).
- Zegarek: `LiveWearState` to adapter na `WearStateMachine`.

**Brakuje (to decyduje o wyniku):**
1. **HES-Lite i ekrany z `fairwear-ui`:** Dashboard z wynikiem, Why this tier, Demo controls, Wearable calendar, Share QR, widok partnera, `DayDial`. Paczka **nie leży w `_incoming/`**.
2. Weryfikator claimu (`PartnerVerifier`) i twardszy decode (S3, S4).
3. Dane na ekranach. Telefon ma „—”. Zegarek na emulatorze dostaje tętno 0, więc dni pokazują „worn 0 h · not observed 24 h”.
4. Wizualizacja i układ informacji. Brak pierścieni, wykresów, kafli i animacji. Karta Watch link wygląda jak konsola deweloperska.
5. Dokumenty: `AI_WORKFLOW.md` (puste sekcje szablonu), `docs/SECURITY.md`, pełny README i skrypt demo.
6. Oddanie: podpisane `.hap`, publiczne repo, nagranie.

---

## 3. Decyzje obowiązujące

| # | Decyzja |
|---|---|
| D1 | **Model dodatku.** Adapter Health Service Kit to stub (`UNAVAILABLE`). Zgoda HUAWEI Health to neutralna plansza DEMO, chyba że powstanie Health Sim (D15). Statusy w UI: „Not connected”, „Demo data”, „Unavailable in this build”, „Connected”. Enumy nigdy nie trafiają do UI. |
| D2 | **Claim ma 7 pól:** `v, period, tier, eligible, nonce, issuedAt, kid`. Kod z `fairwear-ui` dostosowujesz do repo. Mapowanie z raportu jest w Załączniku A. |
| D3 | **Weryfikacja ma statusy w stałej kolejności:** `Invalid format` → `Unknown key` → `Invalid signature` → `Nonce mismatch` → `Already used` → `Signature valid`. |
| D4 | **Nonce wydaje partner** (16 B z `cryptoFramework`, base64url, 22 znaki, TTL 10 min). Powtórki rozpoznajesz **po nonce**, nigdy po podpisie. Źródło klucza (HUKS albo software) pochodzi z rejestru partnera, nigdy z tokenu. `Math.random` w ścieżce podpisu jest zabronione. |
| D5 | **Jedna reguła noszenia: `WearStateMachine`.** Próg 60 s. Krótszy próg tylko z etykietą „Demo clock”. Odczyt ≤ 0 bpm to brak odczytu. Stan „Charging” bierzesz z `batteryInfo.pluggedType`. `DayDial` tylko rysuje stany. |
| D6 | **Zegarek nie zasila wyniku.** Zdanie do README: *"In production, verified watch days are the wear evidence for the break rules; in this build the score uses persona history and verified watch days are shown, not scored."* |
| D7 | **VO₂max i HRV.** W demo pochodzą z person (percentyle) i wchodzą do HES. Prawdziwy adapter przelicza VO₂max (ml/kg/min) na percentyl tabelą ze źródłem. HRV: README mówi „HRV where the data source provides it”. Tekst „Not scored yet” tylko przy `CONNECTED`. |
| D8 | **Bez AI w produkcie.** Usuń `'LLM'` z `types.ets` (zmiana `types.ets` idzie osobnym commitem po zgodzie człowieka) i zdanie o AI z `HACKATHON_BRIEF.md`. README: *"HES is deterministic rules, not AI. AI feature disclosure: not applicable."* |
| D9 | **Logi.** W `%{public}` żadnych wartości zdrowia, tokenów, nonce ani kluczy. |
| D10 | **Uprawnienia.** `entry` nie ma żadnych. Każda próba dodania to STOP i pytanie. `watch` ma `READ_HEALTH_DATA` i `ACTIVITY_MOTION` z `reason` i `inuse`. |
| D11 | **API.** `compatibleSdkVersion 6.0.0(20)`, `targetSdkVersion 6.1.1(24)`. Bez zmian. |
| D12 | **Zakazane sformułowania** (Załącznik C), sprawdzane przez `tools/check-wording.sh`. |
| D13 | **Karta 2×2 nigdy nie pokazuje tieru.** Nie ma karty na ekranie blokady. |
| D14 | **Wyniki person są stałe** (Załącznik B). Rozbieżność to błąd do zgłoszenia, nigdy powód do strojenia progów. `types.ets` i `defaults.ets`, wagi, krzywe i progi zmieniasz tylko za zgodą. |
| D15 | **Health Sim jest opcjonalny.** Robisz go tylko po bramce 04:00 i tylko jeśli do 06:30 zostaje ≥ 1 h (K6). Dane person bierze z generatora FairWear (wariant „a”). |
| D16 | **UI natywne dla HarmonyOS:** komponenty ArkUI, HM Symbol (`SymbolGlyph`), zasoby `sys.color`/`sys.float`, kolory metryk jako `app.color` (jasne i ciemne). Bez zewnętrznych bibliotek UI. Bez wyglądu, ikon i logo HUAWEI Health („HUAWEI Health” tylko jako tekst źródła). Dane techniczne (`kid`, `seq`, `chain`, hashe) tylko na ekranie „Verification details”. |

---

## 4. Zasady pracy

1. **Najwyżej dwie sesje naraz, każda na swojej gałęzi.**
   - Sesja **A** robi rdzeń: K2, K3, K4.
   - Sesja **B** robi UI (K5), a po bramce 04:00 Health Sim (K6).

   Merge do `main` robi jedna osoba z zespołu.
2. **Po każdym bloku:** build `entry` i `watch`, `tools/run-logic-tests.sh common` i `… watch`, lint. Jeśli coś jest czerwone, cofasz blok i raportujesz.
3. **Każdy zmieniony ekran** ma zrzut „przed” i „po”, w trybie jasnym i ciemnym, w `docs/screenshots/design/`.
4. **Skille:**
   - `ohos-app-dev` dla pętli lint → build → run → log → screenshot (skrypty `tools/` są jej odpowiednikiem);
   - `hmos-arkui-develop-skill` i `hmos-arkui-scenario-development` przy każdej zmianie UI;
   - `hmos-arkui-mvvm-pattern` przy podziale stron;
   - `hmos-arkts-knowledge-retriever` przy każdym niepewnym API;
   - **nie używasz** `apple-design`, `write-swift`, `animate-expo`, `pick-ui-library`, `ask-sonner` ani `emil-design-eng`, bo celują w iOS i web.

   Użyte skille wpisujesz do `AI_WORKFLOW.md`.
5. **Przed operacjami nieodwracalnymi** (przepisanie historii, usuwanie, nowy materiał podpisu, odinstalowanie) pytasz.
6. **Nie piszesz, że coś działa,** jeśli tego nie uruchomiłeś. Kod, komentarze i UI piszesz po angielsku.
7. **Na koniec sesji** robisz `/raport` i `/backup`.

---

## 5. Plan pracy

### H0 — człowiek, teraz (5 min)
- [ ] Pobrać `fairwear-ui.zip` z czatu „Analiza arkusza” i rozpakować do `C:\dev\FairWear\_incoming\fairwear-ui\`. **To jest wąskie gardło całego projektu.**
- [ ] Merge `feature/ui-foundation` → `main` (jest w niej security-watch).
- [ ] Emulator zegarka: Virtual sensor → tętno 70.
- [ ] Zgoda na D8, czyli usunięcie `'LLM'` z `types.ets`.

### K0 — skille i źródło prawdy (sesja A, 15 min)
- [ ] `ls ~/.claude/skills` i wpisanie skilli z wersjami do tabeli „Tools used” w `AI_WORKFLOW.md`.
- [ ] `AGENTS.md`, sekcja „Project state”:
  - jedynym planem jest `C:\dev\fairwear-specs\00-FAIRWEAR_PLAN.md`;
  - HES-Lite nie jest w repo, dopóki nie istnieje `_incoming/fairwear-ui`;
  - lista skilli do użycia i do pominięcia (pkt 4.4).
- [ ] Commit.

### K1 — bezpieczeństwo bez HES
- [x] S0 `ac5da31`, S1 `2395cb5`, S2 `1bdd070`, I-3 jedna reguła noszenia `033ee7a`.

### K2 — HES-Lite i ekrany z `fairwear-ui` (sesja A, po H0; bramka 04:00)

Wykonaj kroki 1–6 z `_incoming/fairwear-ui/WKLEJKA_CLAUDE_CODE.md` z poniższymi zmianami:

1. Skopiuj `hes/` do `common/src/main/ets/hes/` i `Hes.test.ets` do testów (cel 43/43). Narzędzia z paczki scal z `tools/` bez nadpisywania. Eksporty dopisz do `common/Index.ets`, a kolizje aliasuj (`median → hesMedian`).
2. Ekran Consent z paczki **nie wchodzi**. Zostaje AD-1/AD-2/AD-3. Za AD-2 wpinasz z paczki:
   - Dashboard;
   - 24h dial;
   - Live card;
   - Why this tier;
   - Demo controls;
   - Wearable calendar;
   - Share;
   - widok partnera.
3. `SyntheticHealthSource` ma `status() = DEMO` i podaje historię `HesPersonas` przez istniejącą `HealthConnection`. Zakres wyłączony w AD-2 daje `MISSING` w HES i niższe pokrycie. Dopisz na to test.
4. Demo-signer FNV z paczki zastępujesz `ProofSigner` (HUKS z kluczem zapasowym). Plakietka w UI: „HUKS key” albo „Software key (emulator)”.
5. Claim według D2. Testy UiService (cel 23/23) mogą się zmienić przy adaptacji. Każdą zmienioną asercję wypisz w raporcie.
6. `CardDigest` dostaje prawdziwe pokrycie i „Score ready”. Tier nigdy nie trafia na kartę (D13).
7. **Bramka 04:00:** wyniki person zgodne z Załącznikiem B i przejście na emulatorze telefonu: AD-1 → AD-2 → Dashboard (Ania) → Why → Share → partner (`Signature valid`) → AD-3 → AD-2 → wynik. Jeśli bramka nie przeszła, wszystko idzie na K2, a z K5 zostaje tylko Dashboard.

### K3 — weryfikator i twardszy claim (sesja A, w ramach K2)

1. **S3, decode** (`TierClaimCodec`). Każdy z poniższych przypadków daje `Invalid format` jeszcze przed lookupem `kid`:
   - `claimJson` dłuższy niż 256 znaków albo token dłuższy niż 512;
   - wynik niezgodny z formą kanoniczną: sprawdzasz `encodeTierClaim(decoded) === claimJson`, co łapie powtórzone klucze, spacje i kolejność;
   - `v` inne niż wersja;
   - `tier` spoza zbioru;
   - `period` niezgodne z regexem kodu;
   - `nonce` niepasujące do `/^[A-Za-z0-9_-]{22}$/`;
   - `kid` niepasujące do `/^[0-9a-f]{8}$/`;
   - `issuedAt` niecałkowite, niedodatnie albo ponad 5 min w przyszłości;
   - `eligible` przy braku wyniku;
   - `kid` w `SignedClaim` różne od `kid` w claimie;
   - podpis DER dłuższy niż 72 B.
2. **S4, `PartnerVerifier`** w `common` (czysta logika i testy):
   - `issueNonce()`;
   - rejestr `kid → {publicKeyDer, source}`, zapisywany przy zgodzie i odświeżany na start sesji (klucz software zmienia się po restarcie);
   - weryfikacja w kolejności z D3;
   - ekran partnera tylko wywołuje weryfikator i pokazuje duży status, krok zatrzymania i plakietkę klucza z rejestru.
3. Share podpisuje nonce wydany przez partnera w chwili otwarcia ekranu.
4. **Testy S-1 do S-20** (Załącznik D), łącznie z S-16, czyli powtórką z podpisem (r, n−s).

### K4 — zegarek (sesja A)

- [ ] **Demo feed** (45 min, przed paczką).
  - Działa tylko przy zegarze demo i ma etykietę na tarczy.
  - To skryptowany strumień tętna i kroków: dzień z noszeniem, nocnym ładowaniem i jedną przerwą. Trafia do tego samego rekordera co czujniki.
  - Pakiet ma pole `clock`, np. `DEMO_X300_FEED`. Dopisz wiersz do tabeli „real vs simulated”.
  - Dzięki temu tarcza i „Days from the watch” mają kształty zamiast zer.
- [ ] Stan „Charging” z `batteryInfo.pluggedType` (D5), jeśli jeszcze go nie ma na ekranie.
- [ ] `DayDial` i `WatchModels` z paczki (po H0) rysują stany z `WearStateMachine`.
- [ ] Ręcznie: tętno 70 → 0 → 70. Zrzuty idą do README.
- [ ] Opcjonalnie (P4b): w „Wearable calendar” zweryfikowany dzień z zegarka dostaje plakietkę „Verified watch day”. Nie wpływa na wynik.

### K5 — wygląd (sesja B)

1. **Skill projektu** `.claude/skills/fairwear-ui/SKILL.md` (commit do repo). Zawiera:
   - kiedy go używać: każda zmiana w `entry/view`, `entry/widget` i `watch/pages`;
   - tokeny: kolory metryk (kroki, tętno, sen, aktywność, VO₂max, HRV, trening, noszenie, ładowanie, nieobserwowane), tierów i statusów jako `app.color` w wersji jasnej i ciemnej; tło i tekst z `sys.color`;
   - komponenty z UI kitu;
   - zasady:
     - liczba zawsze z jednostką;
     - zero nigdy nie udaje braku danych;
     - żadnych enumów ani hashy poza „Verification details”;
     - jedna główna informacja na ekranie zegarka;
     - D16;
   - bramka zrzutów przed i po.
2. **UI kit** w `entry/src/main/ets/ui/kit/` i `watch/src/main/ets/ui/kit/`:
   - `ValueWithUnit`;
   - `MetricTile` (symbol, nazwa, wartość z jednostką, słupki z 7 dni, stan „Off · missing evidence”);
   - `RingStat` (`DataPanel` albo `Gauge` z animacją wypełnienia);
   - `StatusPill`;
   - `SectionCard`;
   - `EmptyState`;
   - `DayStrip` (7 dni jako małe pierścienie W/C/O/U).

   Rozbij `watch/pages/Index.ets` (530 linii) według `hmos-arkui-mvvm-pattern`.
3. **Układ telefonu** (po bramce 04:00 na danych HES). Przed bramką robisz tylko karty Watch link.
   - Zakładki u dołu: **Home | Evidence | Share**.
   - **Home:** `RingStat` z HES, tier, pokrycie i pewność jako chipy, linia typu „1 point to A”, siatka `MetricTile` (2 kolumny), `DayStrip` „Watch evidence”, Live card z etykietą „Demo values”.
   - **Evidence:** kalendarz noszenia (kropki dni, szczegóły w sheet, „Appeal this day”) i dni z zegarka jako karty z paskiem W/C/O/U i plakietką „Verified”. Pod spodem przycisk **Verification details**: `kid`, `seq`, `chain`, log synchronizacji, transport „DEMO relay (hdc)”.
   - **Share:** `QRCode` i karta „What the partner sees” (`tier`, `eligible`, `period`; pod „Technical” są `kid`, `nonce` i `issuedAt`). Główny przycisk przypięty u dołu.
   - **Partner:** duży status z symbolem i krokiem zatrzymania.
   - Duże tytuły `Navigation`. Przejścia i wypełnianie pierścieni animowane przez `animateTo` (300–600 ms).
4. **Zegarek** (na UI kicie):
   - na środku duże tętno z `SymbolGlyph` serca;
   - na obrzeżu pierścień slotów dnia w kolorach tokenów;
   - pod spodem jeden krótki stan („On wrist”, „Not on wrist”, „Charging”);
   - footer najwyżej „Demo”;
   - brak odczytu: „Waiting for heart rate”;
   - Watch Link controls na `ArcList`;
   - zrzuty 466×466.
5. **Karta 2×2:** mały pierścień pokrycia, „Score ready” albo „Not yet”, status. Bez tieru. Sprawdź, które komponenty działają w kartach ArkTS.

### K6 — Health Sim (sesja B, opcjonalnie; tylko po bramce 04:00 i przy ≥ 1 h do 06:30)

Gałąź `feature/health-sim-audit` (P0 krok 1 jest zrobiony).

1. Health Sim to osobny HAP `com.fairwear.healthsim` na tym samym emulatorze telefonu.
   - `AuthAbility` ze skillem `healthsim://authorize`.
   - SDK, lint i build takie same jak w FairWear.
   - Baner „SIMULATED DATA” na każdym ekranie.
   - Bez wyglądu HUAWEI Health.
2. **Dane (wariant a):** Health Sim pokazuje i oddaje historię `HesPersonas`, przekonwertowaną na próbki `Hs*` (`HesHistoryToHs` i odwrotny adapter w FairWear). Lista person = `HesPersonas.IDS`.
   - **Test akceptacyjny:** wynik silnika na danych „generator → Health Sim → payload → adapter” jest **identyczny** z wynikiem na danych z generatora. Porównujesz tier, wynik, pokrycie, pewność, flagę, `eligible` i dni kalendarza.
   - Folder wspólny `Hs*` ma identyczne bajty w obu aplikacjach. Pilnuje tego test.
3. **HRV:** HES go używa, więc dodaj `HsDataType.HRV = 'hh.hrv'` (PROVISIONAL): jedna wartość na noc, osobny strumień PRNG, kodek, etykieta i testy.
4. **W FairWear:** przycisk „Connect Health Sim” w AD-2 obsługuje stany `granted`, `denied`, `not_installed` i `error`. Etykieta źródła: „Data: simulated, Huawei Health format (Health Sim)”, z Data ID. Brak typu (`HsError` 201) obniża pokrycie i nie wywraca silnika.
5. **Ryzyka:**
   - `openLink` może pokazać okno wyboru aplikacji; przy błędzie 16000019 przechodzisz na `startAbilityForResult`;
   - limit `WantParams` to 100 KB, a 30 dni danych to 65–71 KB, więc `MAX_DAYS` nie rośnie;
   - używasz tylko trybu Demo.
6. **Wiersz do README:** „Huawei Health history — simulated by the Health Sim app (separate HAP on the same phone emulator, Health Service Kit sample-point shape); real access needs Huawei approval of Health Service Kit.”

Jeśli czasu zabraknie: README „Next steps” i nic więcej.

### K7 — dokumenty (06:30–08:00)

- **README:**
  - „FairWear as a component”: co robi, jak się integruje, jak zainstalować (dwa `.hap`), jak sprawdzić;
  - tabela „real / simulated / needs device / needs Huawei approval” dla telefonu, zegarka, Watch Link, Demo feed i Health Sim;
  - mapowanie claimu (Załącznik A);
  - zdania z D6 i D8;
  - „Security & privacy” (4–5 sprawdzalnych zdań, link do SECURITY.md);
  - „Design” (D16);
  - zdanie z S1: *"The phone app declares no permissions and has no network code: health history and the score never leave the phone; the only output is the signed tier claim the user chooses to show as a QR code."*
- **`docs/ARCHITECTURE.md`:** przepływ HUAWEI Health → `HealthSource` → HES → claim → partner; ścieżka zegarka; prawdziwa ścieżka Huawei ID → autoryzacja → odczyt → odłączenie; jedno wejście `fwTarget`.
- **`docs/SECURITY.md`** (po angielsku):
  - scope, assets i actors;
  - tabela zagrożeń: Threat | Mitigation | Status;
  - **ograniczenie wprost:** zmodyfikowana aplikacja lub urządzenie z rootem może podpisać dowolny tier; produkcyjnie potrzebna jest atestacja klucza HUKS i kontrola integralności;
  - out of scope: osobny klucz per partner, 32-bitowy `kid`;
  - „How to verify”.
- **`docs/DEMO_SCRIPT.md`:** scenariusz z sekcji 6.
- **`AI_WORKFLOW.md`:**
  - narzędzia z wersjami i skillami;
  - prompty: kopia tego pliku i paczek w `docs/prompts/`, bez danych osobowych i ścieżek z nazwą użytkownika;
  - przebieg pracy;
  - weryfikacja;
  - nieudane podejścia (aplikacja samodzielna zastąpiona dodatkiem, mock HH zastąpiony przez `common/health`, dwie reguły noszenia scalone);
  - ograniczenia i wnioski;
  - „AI feature disclosure: Not applicable”.
- **`docs/REQUIREMENTS_CHECK.md`** i tabela „Hackathon requirements → where to verify” w README (Załącznik E).
- **`docs/test-results.txt`:** aktualne liczby. `tools/check-wording.sh`: 0 trafień.

### K8 — oddanie (08:30–10:00)

- [ ] **Checklista S8:**
  - skan sekretów po `--all` czysty;
  - `git ls-files` bez materiału podpisu, `local.json`, `build/` i `oh_modules/`;
  - commitowany `build-profile.json5` bez haseł i ścieżek;
  - uprawnienia zgodne z D10;
  - testy zielone;
  - świeży klon buduje się według README.
- [ ] **Podpis:** DevEco → File → Project Structure → Signing Configs → automatyczny podpis. Zmienionego `build-profile.json5` **nie commitujesz**. Podpisane `.hap` telefonu i zegarka muszą zainstalować się na czystym emulatorze.
- [ ] **Publiczne repo** na GitHubie. Adres e-mail w commitach stanie się publiczny: decyzja właściciela. `.hap` dołączasz jako GitHub Release.
- [ ] **Nagranie według sekcji 6.** Na miejscu poproś mentora o uruchomienie `.hap` zegarka na prawdziwym zegarku Huawei.
- [ ] **Zgłoszenie do 10:30.**

---

## 6. Scenariusz demo (około 2–3 min)

1. AD-1 → AD-2 (zgoda) → Home: **Ania A/92** → Why this tier.
2. Demo controls → suwak tętna na żywo: wynik się nie zmienia („Demo values, not scored”).
3. **Marek:** czerwone dni w Evidence → szczegóły dnia → „Appeal this day” → „Appeal sent”.
4. **Ola:** „No score yet” zamiast niskiego wyniku.
5. **Zegarek:**
   - tętno 70 → 0 → 70 i „Not on wrist”;
   - Demo feed i „Close day” → relay → telefon: „Chain ✓ · Signature valid”;
   - `--tamper` → „Invalid signature”.

   Wszystko z etykietą „DEMO relay (hdc)”.
6. **Share QR** → widok partnera:
   - „Signature valid”;
   - ten sam token drugi raz → „Already used”;
   - zmieniony tier → „Invalid signature”.
7. **AD-3:** odłączenie → ponowne połączenie → wynik wraca.
8. *(Jeśli powstał K6)* krok 1 przez Health Sim: Connect → zgoda w Health Sim → powrót z tym samym Data ID.

---

## 7. Harmonogram

| Godzina | Sesja A (rdzeń) | Sesja B (wygląd, potem Health Sim) | Człowiek |
|---|---|---|---|
| 01:30–02:15 | K0, K4 Demo feed | K5.1 skill, K5.2 UI kit, karty Watch link | H0 |
| po paczce – 04:00 | K2 + K3 | K5.4 zegarek na UI kicie | merge do `main` |
| **04:00** | **bramka:** persony i przejście na emulatorze | | decyzja: czy K6 |
| 04:00–06:30 | K4 (`DayDial`, ładowanie), P4b | K5.3 Home, Evidence, Share; K5.5; ewentualnie K6 | |
| **06:30** | **koniec nowych funkcji** | | |
| 06:30–08:00 | K7 | K7 (zrzuty, Design), testy S | |
| **08:30** | **zamrożenie kodu** | | |
| 08:30–10:00 | K8 | K8 | nagranie, repo |
| **10:30** | | | **oddanie** |

---

## 8. Raport po każdym kroku

Raport zawiera:
- testy: common, watch, HES, UiService, security;
- build i lint;
- zmienione pliki;
- commit;
- zrzuty przed i po;
- rozbieżności z tym plikiem lub z Załącznikiem B;
- status punktów z Załącznika E.

---

## Załącznik A — mapowanie claimu

| Raport HES-Lite | Repo |
|---|---|
| `version` | `v` |
| `periodStart` + `periodEnd` | `period` |
| `iat` | `issuedAt` |
| `from` | celowo pominięte |
| `tier`, `eligible`, `nonce`, `kid` | bez zmian |

## Załącznik B — wyniki person (stałe)

| Persona | Tier / wynik | Pokrycie | Pewność | Uwagi |
|---|---|---|---|---|
| Ania | A/92 | 100% | High | pełny benefit |
| Marek | B/75 | 85% | High | oflagowany, bez benefitu; 4 czerwone dni; 3 podejrzane przerwy |
| Kasia | B/73 | 70% | Medium | częściowy benefit; 1 podejrzana przerwa, bez flagi |
| Tomek | B/79 | 90% | High | „1 point to A” |
| Ewa | C/59 | 75% | Medium | bez benefitu |
| Ola | brak wyniku | 43% | — | za mało danych |

**Reguły noszenia:**
- noc liczy się przy ≥ 4 h noszenia między 00:00 a 06:00;
- przerwa jest „przyłożona”, jeśli w 24 h przed nią było ≥ 12 odczytów tętna;
- flaga przy ≥ 3 podejrzanych przerwach albo przy ≥ 2 i udziale > 30% dni, nigdy za jedną przerwę.

## Załącznik C — zakazane sformułowania

- „official Huawei Health plugin/extension”;
- „wtyczka HUAWEI Health”;
- „Works with HUAWEI Health”;
- „certyfikowany”;
- „runs inside the Huawei Health app”;
- „approved by Huawei”;
- „uses real Huawei Health data”;
- „predicts health/disease”;
- „validated”;
- „risk”;
- „AI” w odniesieniu do HES;
- „healthy/unhealthy”;
- enumy statusów w tekstach UI.

**Dozwolone:** „add-on for HUAWEI Health users”, „Data: simulated, Huawei Health format”.

## Załącznik D — testy bezpieczeństwa (dopisujesz, istniejących nie zmieniasz)

| # | Scenariusz | Wynik |
|---|---|---|
| S-1 | pusty string | Invalid format |
| S-2 | token 513 znaków (bez `JSON.parse`) | Invalid format |
| S-3 | nie-JSON / emoji | Invalid format |
| S-4 | brak każdego z 7 kluczy | Invalid format |
| S-5 | dodatkowy klucz | Invalid format |
| S-6 | powtórzony klucz `tier` | Invalid format |
| S-7 | niekanoniczne spacje / kolejność | Invalid format |
| S-8 | tier „S”, zły nonce, zły `kid`, `issuedAt` w przyszłości | Invalid format |
| S-9 | `kid` w `SignedClaim` ≠ `kid` w claimie | Invalid format |
| S-10 | nieznany `kid` | Unknown key |
| S-11 | zmieniony tier | Invalid signature |
| S-12 | zmieniony nonce | Invalid signature |
| S-13 | nonce niewydany przez partnera | Nonce mismatch |
| S-14 | nonce starszy niż TTL | Nonce mismatch |
| S-15 | ten sam token drugi raz | Already used |
| S-16 | powtórka z podpisem (r, n−s) | Already used |
| S-17 | token bez HES, pokrycia, flag i wartości zdrowia | pass |
| S-18 | 1000 nonce'ów: unikalne, 22 znaki, base64url | pass |
| S-19 | `setLive(200, 99999)` nie zmienia HES | pass |
| S-20 | `keySource` „HUKS” w tokenie przy kluczu software w rejestrze; UI pokazuje „Software key” | pass |

Do S-16 potrzebny jest rząd krzywej P-256:

```
n = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551
```

W podpisie DER zamieniasz `s` na `n−s`, z wiodącym `0x00`, jeśli ustawiony jest najstarszy bit.

## Załącznik E — wymagania hackathonu → dowód (tabela w README)

| Wymaganie | Dowód |
|---|---|
| API 20+, minimum 20 | `build-profile.json5` |
| Działa na emulatorze | zrzuty telefonu i zegarka |
| Powtarzalne instrukcje | README; świeży klon buduje się według README |
| Funkcje platformy | HUKS, CryptoFramework, Sensor, Form Kit, skróty, `batteryInfo`, relay `hdc` (dev); każda ze ścieżką w kodzie i zdaniem, po co jest |
| Komponent: co, integracja, instalacja, weryfikacja | README „FairWear as a component” |
| Publiczne repo i `.hap` | GitHub i Release |
| Nagranie | link |
| Architektura | `docs/ARCHITECTURE.md` |
| `AI_WORKFLOW.md` | kompletny |
| Brak funkcji AI w produkcie | README (D8) |
| Higiena | `docs/SECURITY.md`, S-1–S-20, hook pre-commit, tabela uprawnień |
| Obsługa błędów | statusy źródła, `MISSING`, brak czujnika, klucz zapasowy, statusy weryfikacji, nieznany `fwTarget` |
| Historia commitów | bez squash, merge z worktree |
