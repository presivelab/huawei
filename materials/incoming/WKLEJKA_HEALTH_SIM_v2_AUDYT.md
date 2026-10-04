# WKLEJKA v2: Health Sim — najpierw audyt (co jest, czego brakuje), potem domknięcie

Wklej do Claude Code w repo FairWear wszystko poniżej linii. Zastępuje `WKLEJKA_HEALTH_SIM.md`.

---

Pracujesz w repo FairWear (`Desktop/fairwear-staging`, gałąź `main`, bez remote). Projekt DevEco, bundle `com.fairwear.app`, **API 24**, moduły `entry` (telefon), `watch` (zegarek), `common` (HAR `com.fairwear.common`). Silnik HES jest w `common/src/main/ets/hes/`, a testy uruchamia `tools/run-logic-tests.sh`.

Do repo trafiła paczka **Health Sim** (`HealthSim.zip`, prawdopodobnie w `_incoming/` albo już jako `healthsim/`). To osobna aplikacja na telefon (`com.fairwear.healthsim`, ArkTS/ArkUI). Udaje Huawei Health na emulatorze i oddaje dane FairWear przez ekran zgody (`openLink` → `healthsim://authorize`). Wcześniej powstały też dwie inne wklejki z tym samym celem: `WKLEJKA_MOCKUP_HUAWEI_HEALTH` (kroki HH-0…HH-7) i `WKLEJKA_ZEGAREK_HH` (ZW-0…ZW-6). Mogły być wdrożone częściowo.

**Źródło prawdy:** „Finalny raport wdrożenia HES-Lite v1.0 w FairWear” z poprawkami (API 24; VO₂max i HRV to autentyczne dane z zegarka i wchodzą do HES) oraz ta wklejka. Gdy coś w kodzie przeczy raportowi, to jest luka, a nie nowa prawda.

Najpierw **Faza 1: audyt bez zmian w kodzie**. Potem raport w podanym formacie. Dopiero potem **Faza 2: domknięcie** tylko tego, czego brakuje.

## Zasady

1. **Faza 1 jest tylko do odczytu.** Wolno czytać pliki, używać `git`, `grep`/`rg`, liczyć hashe, uruchamiać `devecocli check lint`, `devecocli build`, testy i emulator. Nie wolno edytować plików, commitować ani instalować paczek w FairWear.
2. **Każdy status wymaga dowodu:** ścieżka i linia, wynik komendy, liczba testów albo screenshot. Słowa „chyba”, „powinno” i „wygląda na to” nie są dowodem. Nie ufaj `AI_WORKFLOW.md` ani wcześniejszym raportom; sprawdzaj w kodzie.
3. **Nie wolno zepsuć:** HES 43/43, UiService 23/23 i oczekiwanych wyników person z raportu (tabela w 1.6). Na początku audytu zapisz bazowe wyniki, a po każdym kroku Fazy 2 porównaj z nimi.
4. Bez zgody człowieka nie zmieniasz `types.ets`, `defaults.ets`, `TierClaim`, wag, krzywych ani progów HES i reguł noszenia.
5. Folder `healthsim/` (wspólny kod `Hs*`) ma być identyczny w Health Sim i w FairWear. Jeśli zmieniasz go w jednym miejscu, zmieniasz w obu, a test sprawdza identyczność bajtów.
6. Nie importujesz `@kit.HealthServiceKit` i nie zgadujesz jego API. Typy `hh.*` są tymczasowe (`PROVISIONAL`).
7. Bez logo, kolorów i wyglądu Huawei Health. Baner „SIMULATED DATA” zostaje. Zakazane sformułowania: „official Huawei Health plugin/extension”, „runs inside the Huawei Health app”, „approved by Huawei”, „uses real Huawei Health data”, „predicts health/disease”, „validated”, „risk”, „AI” w odniesieniu do HES, „healthy/unhealthy”. Dozwolone: „Data: simulated, Huawei Health format (Health Sim)”.
8. Pracuj na gałęzi `feature/health-sim-audit`, małymi commitami. Merge robi człowiek. Kod, komentarze i UI piszesz po angielsku (chiński tylko w zasobach `zh_CN` Health Sim).
9. Korzystaj ze skilli z repo zadania: `ohos-app-scaffold` (tylko szkielet), `ohos-app-dev` (lint → build → run → log → screenshot), `hmos-arkui-develop-skill` przy błędach ArkUI, `hmos-arkts-knowledge-retriever` przy niepewnych API.

## Faza 1: audyt (read-only)

### 1.1 Stan bazowy

- `git status`, `git branch -a`, `git log --oneline -20`.
- Gdzie jest Health Sim: `healthsim/`, `_incoming/HealthSim/` czy nigdzie?
- Bazowe testy: `tools/run-logic-tests.sh` (HES x/43, UiService x/23, pozostałe).
- Bazowy build FairWear: `devecocli build` i `DEVECOCLI_BUILD_EXIT_CODE`.
- `devecocli device list --format json`: który emulator telefonu, a który zegarka działa.

### 1.2 Aplikacja Health Sim (HS)

| ID | Co sprawdzić | Jak |
|---|---|---|
| HS-01 | Projekt istnieje jako jeden folder DevEco, `AppScope/app.json5` ma `bundleName: com.fairwear.healthsim` | odczyt pliku |
| HS-02 | `build-profile.json5`: `compatibleSdkVersion`, `targetSdkVersion`, `compileSdkVersion` i `runtimeOS` takie same jak w FairWear | porównanie obu plików |
| HS-03 | `module.json5` ma `EntryAbility` i `AuthAbility` (`exported: true`, skill z `actions: ohos.want.action.viewData` i `uris: scheme healthsim, host authorize`), a `main_pages.json` ma `pages/Index` i `pages/AuthPage` | odczyt plików |
| HS-04 | Wspólne pliki `healthsim/*.ets` są niezmienione względem paczki | SHA-256 i tabela niżej |
| HS-05 | Każde `$r('app.string/color.*')` istnieje w `base` i `zh_CN` z tymi samymi `%s` i `%d` | krótki skrypt |
| HS-06 | `devecocli check lint --format json healthsim` bez błędów | lint |
| HS-07 | `devecocli build` w Health Sim: exit 0 | build |
| HS-08 | Instaluje się i startuje na emulatorze telefonu | `devecocli run`, screenshot |
| HS-09 | Testy logiki 69/69: `cd healthsim/tools/logic-tests && npm install && npm test` | testy |
| HS-10 | Zakładki Today, History i Scenario; baner na każdym ekranie; zmiana persony zmienia Data ID; chiński język emulatora zmienia UI | screenshoty |

Hashe plików z paczki (pierwsze 16 znaków SHA-256; w PowerShell `Get-FileHash -Algorithm SHA256`):

```
73cacb44a8e76d88  HealthSimClient.ets
78c69426ebb43dd8  HsCodec.ets
b49a25dba367ccc6  HsGenerator.ets
cb8f16f253b03315  HsPersonas.ets
f5450fd88ac618df  HsRandom.ets
38c382d7fc18a0ee  HsStore.ets
01acace5646d2fbd  HsSummary.ets
96f70bc6525f9c82  HsTypes.ets
```

Inny hash nie oznacza automatycznie błędu. Oznacza, że ktoś zmienił plik: wypisz diff.

### 1.3 Integracja z FairWear (FW)

| ID | Co sprawdzić |
|---|---|
| FW-01 | Kopia `healthsim/` jest w `common/src/main/ets/healthsim/` i ma identyczne bajty jak kopia w Health Sim |
| FW-02 | Eksporty w `common/Index.ets` nie kolidują z istniejącymi nazwami. Kolizje aliasuj tak, jak zrobiono to z `median → hesMedian` |
| FW-03 | **Gdzie dziś wchodzą dane do silnika:** skąd `ReportBuilder` i `HesSession` biorą historię persony (który generator, jaki format, sloty 5-min czy agregaty dnia). To jest punkt wpięcia |
| FW-04 | Istnieje adapter Health Sim → format historii FairWear i dane z Health Sim **naprawdę trafiają do `HesSession`**, a nie są tylko wyświetlane |
| FW-05 | Przycisk połączenia z Health Sim jest na ekranie Consent albo w Demo controls i obsługuje `granted`, `denied`, `not_installed` i `error` |
| FW-06 | UI pokazuje źródło („Data: simulated, Huawei Health format (Health Sim)”), etykietę SIMULATION i Data ID |
| FW-07 | Brak danych dla odznaczonego typu (`HsError` 201) obniża pokrycie i nie wywraca silnika |
| FW-08 | Testy: identyczność obu kopii, adapter, wyniki person na danych z Health Sim |
| FW-09 | W README jest wiersz o Health Sim w tabeli „real / simulated”; grep zakazanych sformułowań w README, UI i docs daje 0 trafień |
| FW-10 | Przebieg na emulatorze: Health Sim → FairWear Connect → zgoda → powrót; Data ID taki sam w obu aplikacjach |

### 1.4 Wcześniejsze wklejki (OLD)

- **HH (WKLEJKA_MOCKUP_HUAWEI_HEALTH):** czy istnieją `datasource/hh/`, `HhTypes`, `HealthStoreLike`, `MockHealthStore`, `HhPersonaGenerator`, `HuaweiHealthDataSource`, ekran zgody, etykieta SYMULACJA? Czy coś z tego jest używane?
- **ZW (WKLEJKA_ZEGAREK_HH):** wspólny generator dla telefonu i zegarka, stała kotwica czasu, odcisk danych na obu ekranach, testy determinizmu?
- **Wypisz wszystkie generatory danych w repo** (np. `HesPersonas`/`ReportBuilder`, `HhPersonaGenerator`, `HsGenerator`) i wskaż ten, który dziś zasila `HesSession`. Dwa generatory tych samych person to konflikt (status CONFLICT).

### 1.5 Wejścia HES a typy Health Sim

Z `hes/HesTypes.ets` i `docs/HES.md` wypisz każdą metrykę HES z wagą i zmapuj na typ Health Sim:

| Metryka HES | Waga | Typ Health Sim | Status |
|---|---|---|---|

Health Sim ma: kroki (`hh.steps.delta`), tętno (`hh.heart_rate`), tętno spoczynkowe, fragmenty snu, SpO₂, temperaturę skóry, stres i VO₂max (raz w tygodniu). **Nie ma HRV.** Jeśli HES używa HRV, to luka (decyzja D3).

### 1.6 Persony

Oczekiwane wyniki z raportu:

| Persona | Tier/wynik | Pokrycie | Pewność | Uwagi |
|---|---|---|---|---|
| Ania | A/92 | 100% | High | pełna korzyść |
| Marek | B/75 | 85% | High | flagged → brak korzyści; 4 czerwone dni w kalendarzu; 3 podejrzane przerwy |
| Kasia | B/73 | 70% | Medium | częściowa korzyść; 1 podejrzana przerwa, bez flagi |
| Tomek | B/79 | 90% | High | „1 point to A” |
| Ewa | C/59 | 75% | Medium | brak korzyści |
| Ola | brak wyniku | 43% | — | za mało danych |

Health Sim w paczce ma inne persony: `ania` (A), `kasia` (B), `marek` (C) i `wei` (C, nabijanie kroków). Nie ma Tomka, Ewy ani Oli, a oczekiwane poziomy Marka i Wei przeczą raportowi. Policz, co silnik FairWear daje na danych z `HsGenerator` (tryb demo, seed 42) dla `ania`, `kasia` i `marek`, i wpisz obok wartości z raportu.

### 1.7 Raport audytu (format obowiązkowy)

```
BAZA: HES x/43, UiService x/23, build FairWear exit=?, emulatory: ...
| ID | Status | Dowód | Czego brakuje | Szac. min |
Status: DONE / PARTIAL / MISSING / CONFLICT / BLOCKED
DECYZJE: D1=?, D2=?, D3=? (rekomendacja + uzasadnienie w 1 zdaniu)
PLAN FAZY 2: lista ID w kolejności P0 → P1 → P2 z sumą minut
```

Po raporcie przejdź do Fazy 2 **bez czekania** z pozycjami, które nie zależą od decyzji. Przy decyzjach D1–D3 zatrzymaj się, jeśli wybór wymaga zmiany oczekiwanych wyników z raportu albo usunięcia kodu.

## Decyzje (rekomendacje)

**D1. Skąd biorą się dane person w Health Sim?**
- **(a) Rekomendowane:** Health Sim pokazuje i oddaje **historię person z generatora FairWear**, przekonwertowaną na próbki `Hs*`. Silnik dostaje wtedy przez Health Sim te same dane co dziś, więc 43/43 i wyniki z 1.6 zostają bez zmian. Wybierz (a), jeśli generator person w `common` nie importuje `@kit.*`.
  - Wykonanie: skopiuj potrzebne czyste pliki generatora do Health Sim (z testem identyczności) albo dodaj zależność od HAR `common` przez `file:` w `oh-package.json5` Health Sim. Wybierz to, co ma mniej plików i mniejsze ryzyko builda, i zgłoś wybór.
  - Napisz `HesHistoryToHs` (historia FairWear → `HsDataset`) i odwrotny adapter po stronie FairWear.
  - Lista person w zakładce Scenario Health Sim = `HesPersonas.IDS`. `HsGenerator` zostaje tylko jako tryb „Live” albo fallback.
  - **Test akceptacyjny:** dla każdej persony wynik silnika na danych „generator → Health Sim → payload → adapter” jest **identyczny** (tier, wynik, pokrycie, pewność, flaga, eligible, dni w kalendarzu) jak na danych bezpośrednio z generatora.
- **(b)** Zostaje `HsGenerator` z personami dostrojonymi pokrętłami w `HsPersonas` (dopisać Tomka, Ewę i Olę, Wei usunąć z listy demo). Tiery i flagi muszą się zgadzać z 1.6, a wynik może się różnić o ±3 pkt. To zmienia liczby z raportu, więc **wymaga zgody człowieka**.

**D2. Stare generatory (HH/ZW).** Niczego nie usuwasz. Jeden generator zasila `HesSession`; pozostałe oznaczasz `@deprecated` w komentarzu i nie podpinasz do UI. Usunięcie tylko za zgodą.

**D3. HRV.** Jeśli 1.5 pokaże, że HES używa HRV, dodaj HRV do wspólnego folderu dokładnie tak:
- `HsTypes`: `HsDataType.HRV = 'hh.hrv'` (z komentarzem `PROVISIONAL`, bo HRV nie jest potwierdzone jako otwarty typ Health Service Kit), dopisz do `all()`; `HsEventKind.HRV = 7`.
- `HsGenerator`: jedna wartość na noc, gdy było co najmniej 36 slotów snu w zegarku; znacznik czasu 25 min po przebudzeniu; RMSSD w ms. **Osobny strumień PRNG** `new HsRandom(hash32(id + '|' + seed + '|' + epochDay + '|hrv'))`, żeby pozostałe dane się nie zmieniły. W wariancie D1(a) wartość bierzesz z historii FairWear.
- `HsCodec.kindToType`, `HsStore.typeToKind`/`fieldsFor` (`{ value: ms }`), `AuthPage.typeLabel`, zasób `type_hrv` („Heart rate variability (HRV)” / „心率变异性”).
- Testy: wartość obecna tylko w nocy z noszeniem, kodek round-trip, payload nadal < 90 KB.
- README: HRV pochodzi z zegarka; w Health Sim jest symulowane.

## Faza 2: domknięcie (tylko pozycje bez DONE)

**P0 — bez tego nie ma demo:**
1. HS-01…HS-08: szkielet przez `ohos-app-scaffold`, nałożenie kodu (`module.json5` i `AppScope` scalasz, nie nadpisujesz), wersje SDK z FairWear, lint, build, run na emulatorze telefonu.
2. FW-01…FW-04 według D1: wspólny folder, adapter, dane z Health Sim w `HesSession`.
3. FW-05 i FW-06: przycisk Connect na Consent/Demo controls, etykieta źródła, SIMULATION, Data ID.
4. Test akceptacyjny z D1 (albo z D1(b) po zgodzie) i porównanie z bazą: HES 43/43, UiService 23/23.

**P1:**
5. Persony (1.6) i D3 (HRV), jeśli dotyczy.
6. FW-07, FW-08: brakujący typ obniża pokrycie; testy identyczności, adaptera i person.
7. FW-10: przebieg E2E na emulatorze ze screenshotami do `docs/screenshots/` (Health Sim Today, ekran zgody, FairWear z tym samym Data ID).

**P2:**
8. FW-09: README (wiersz niżej), `docs/test-results.txt`, grep zakazanych sformułowań.
9. HS-10: sprawdzenie zh_CN; OLD wg D2.

Po każdym kroku podajesz: wynik lintu i builda (`DEVECOCLI_BUILD_EXIT_CODE`), testy względem bazy, zmienione pliki i odstępstwa od tej wklejki. Jeśli zabraknie czasu, kończysz na P0 i oznaczasz resztę w README jako „designed, not built”.

Wiersz do README (tabela „real / simulated / needs device / needs Huawei approval”):
„Huawei Health history — simulated by the Health Sim app (separate HAP on the same phone emulator, Health Service Kit sample-point shape); real access needs Huawei approval of Health Service Kit.”

## Znane ryzyka

- `openLink` z własnym schematem może pokazać systemowy wybór aplikacji. Przy błędzie 16000019 klient sam przechodzi na jawne `startAbilityForResult`.
- WantParams mają limit 100 KB. Payload dla 30 dni i wszystkich typów ma 65–71 KB. Nie zwiększaj `MAX_DAYS`. Jeśli FairWear potrzebuje 90 dni, zgłoś to: trzeba będzie dzielić żądanie albo kompresować dane.
- Oba programy muszą działać na **tym samym** emulatorze telefonu. Emulator nie obsługuje funkcji rozproszonych.
- `linter-cli` z repo zadania ma na sztywno API 10, więc ostrzeżenia o `getUIContext` to fałszywy alarm. Rozstrzyga `devecocli check lint` na projekcie.
- Tryb „Live (now)” daje inne dane przy każdym uruchomieniu. Na demo używaj trybu Demo.
