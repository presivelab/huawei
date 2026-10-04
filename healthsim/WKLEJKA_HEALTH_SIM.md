# WKLEJKA: Health Sim — symulator Huawei Health na emulatorze telefonu

Wklej do Claude Code w repo FairWear wszystko poniżej linii. Paczka `HealthSim.zip` musi być już rozpakowana w repo jako `healthsim/` (obok modułów FairWear, nie w środku `common`).

---

Pracujesz w repo FairWear (HarmonyOS/ArkTS). W `healthsim/` leży gotowy kod drugiej aplikacji: **Health Sim** (`com.fairwear.healthsim`). To aplikacja na telefon, która udaje źródło danych Huawei Health na emulatorze. Generuje deterministyczne dane w kształcie próbek Health Service Kit, pokazuje je (Dziś / Historia / Scenariusz), a FairWear pobiera je przez ekran zgody i `openLink`. UI jest po angielsku i chińsku (zależnie od języka systemu).

Zadanie: (A) zbudować Health Sim i uruchomić na emulatorze telefonu, (B) podłączyć FairWear przez `HealthSimClient`. Pracuj na gałęzi `feature/health-sim`, małymi commitami. Merge do `main` robi człowiek.

## Twarde zasady

1. Korzystaj ze skilli z repo zadania: `ohos-app-scaffold` (tylko szkielet), potem `ohos-app-dev` (lint → build → run → log → screenshot), `hmos-arkui-develop-skill` przy błędach ArkUI. Wszystko przez `devecocli`.
2. **Folder `healthsim/entry/src/main/ets/healthsim/` jest wspólny.** Kopiujesz go do FairWear bez zmian. Jeśli coś w nim zmieniasz, zmieniasz w obu kopiach i dodajesz test, który porównuje pliki bajt po bajcie.
3. Nie zmieniaj `types.ets`, `defaults.ets`, `TierClaim`, progów ani nazw/poziomów person FairWear bez zgody człowieka. Jeśli adapter tego wymaga, zatrzymaj się i zapytaj.
4. Nie zgaduj API Health Service Kit. Stałe `HsDataType` są tymczasowe (`PROVISIONAL`). Jeśli w SDK DevEco są deklaracje `@kit.HealthServiceKit`, wypisz mi dokładne nazwy `samplePointHelper.*`, ale niczego nie importuj z tego kitu.
5. Bez logo, kolorów i wyglądu Huawei Health. Baner „SIMULATED DATA” zostaje na każdym ekranie Health Sim.
6. Zakazane sformułowania (UI, README, pitch): „official Huawei Health plugin/extension”, „runs inside the Huawei Health app”, „approved by Huawei”, „uses real Huawei Health data”. Dozwolone: „Data: simulated, Huawei Health format (Health Sim)”.
7. Kod, komentarze i UI po angielsku (zh_CN tylko w zasobach Health Sim). Ścisły ArkTS.

## A0: rozpoznanie (bez zmian w kodzie, maks. 10 min)

Zgłoś mi krótko:
- `devecocli -V`, listę urządzeń (`devecocli device list --format json`) i czy działa emulator **telefonu**;
- `compatibleSdkVersion`, `targetSdkVersion`, `compileSdkVersion` i `runtimeOS` z `build-profile.json5` FairWear (skopiujesz je 1:1 do Health Sim);
- interfejs źródła danych FairWear: czy istnieją `HealthStoreLike` / `MockHealthStore` / `HuaweiHealthDataSource` z wcześniejszej wklejki (`WKLEJKA_MOCKUP_HUAWEI_HEALTH`), jakie mają metody i typy; gdzie jest ekran zgody / onboarding i wiersz „źródło danych”;
- persony FairWear i ich docelowe poziomy (A/B/C);
- czy w SDK są pliki `@kit.HealthServiceKit*.d.ts`.

## A1: szkielet (skill `ohos-app-scaffold`)

```
devecocli create --project-path ./healthsim-scaffold --app-name HealthSim --bundle-name com.fairwear.healthsim
```

Potem w `healthsim-scaffold/build-profile.json5` ustaw wersje SDK takie jak w FairWear (z A0). Nie wymyślaj stringów wersji.

## A2: nałożenie kodu

Z `healthsim/` do `healthsim-scaffold/`:
- `entry/src/main/ets/**` — skopiuj w całości (nadpisz `pages/Index.ets` i `entryability/EntryAbility.ets` ze szkieletu);
- `entry/src/main/resources/**` — skopiuj (base + zh_CN, ikony, `main_pages.json` z `pages/Index` i `pages/AuthPage`);
- `entry/src/main/module.json5` — **scal**: weź `abilities` z naszego pliku (EntryAbility + AuthAbility z deep linkiem `healthsim://authorize`), zostaw ze szkieletu to, czego u nas nie ma (np. `extensionAbilities` backupu);
- `AppScope/` — scal: `bundleName` musi zostać `com.fairwear.healthsim`, `label` = `$string:app_name`, ikona `$media:layered_image` (pliki są w `AppScope/resources`).

Następnie przenieś wynik z powrotem do `healthsim/` (jeden folder projektu w repo), a `healthsim-scaffold/` usuń.

## A3: build i uruchomienie (skill `ohos-app-dev`)

```
devecocli check lint --format json healthsim
cd healthsim && devecocli build
devecocli device list --format json
devecocli run --skip-build --module entry --device <emulator telefonu>
devecocli ui screenshot --device <nazwa> --path artifacts/snapshots/healthsim-today.png
```

- Ostrzeżenia `getUIContext ... compatible SDK version is 10` z `linter-cli` to fałszywy alarm (linter ma na sztywno API 10). `devecocli check lint` na projekcie z API 20 nie powinien ich zgłosić.
- Błędy kompilacji poprawiasz po jednym, każdy wpisujesz do `artifacts/logs/learning.md`.
- Sprawdź ręcznie na emulatorze: zakładki Today/History/Scenario, zmiana persony zmienia Data ID, przełącznik „Scenario truth” w Historii, przełączenie języka emulatora na chiński zmienia UI.

Testy logiki (bez emulatora):

```
cd healthsim/tools/logic-tests && npm install && npm test
```

Oczekiwane: `69 passed, 0 failed`.

## B1: wspólny kod w FairWear

Skopiuj `healthsim/entry/src/main/ets/healthsim/` do `common/src/main/ets/healthsim/` (lub odpowiednika w FairWear). Eksportuj z `common` przynajmniej: `HealthSimClient`, `HsConnectResult`, `HsConnectStatus`, `HsSimStore`, `HsDataType`, `HsCodec`.

Dodaj test, który porównuje obie kopie folderu (identyczne bajty).

## B2: adapter do silnika FairWear

Na podstawie A0:
- **Jeśli jest `HealthStoreLike` z wcześniejszej wklejki:** napisz `SimAppHealthStore implements HealthStoreLike`, który deleguje do `HsSimStore.readData` / `lastSyncTime`. Zmapuj typy danych i pola (`HsFields.steps/bpm/stage/spo2/celsius/score/value`) na ich odpowiedniki. Nie zmieniaj `HealthStoreLike`.
- **Jeśli nie ma:** napisz adapter z `HsSimStore` do istniejącego interfejsu źródła danych (sloty 5-min + agregaty dnia), tak jak robi to dziś generator person.
- Noszenie wyprowadzasz z luk w próbkach tętna, jak dotąd. Health Sim nie wysyła stanu noszenia ani „prawdy scenariusza”.
- `readData` dla typu bez zgody odrzuca `HsError` z kodem 201. Silnik ma wtedy pokazać brak czynnika, a nie paść.

## B3: ekran zgody / źródła w FairWear

- Przycisk „Connect Huawei Health (simulated)”. Woła:
  ```ts
  const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
  HealthSimClient.connect(ctx, HsDataType.all(), 30, 'FairWear')
  ```
  (lub tylko typy, których silnik używa).
- `granted`: zapisz store jako aktywne źródło, przelicz wynik, pokaż **Data ID** (`store.datasetId()`), personę i „Source: Health Sim app · simulated Huawei Health format”.
- `denied`: komunikat i powrót.
- `not_installed` / `error`: zaproponuj `HealthSimClient.connectLocal(personaId, 42, 30, types, true)` z wyraźną etykietą „local simulation”.
- Etykieta „SIMULATION” ma być widoczna zawsze, gdy aktywne jest to źródło.

## B4: zgodność person

Health Sim ma persony `ania` (A), `kasia` (B), `marek` (C, wybiórcze zdejmowanie), `wei` (C, nabijanie kroków) z pokrętłami jak w HH-3. Dla każdej przelicz poziom w FairWear na danych z Health Sim (tryb demo, seed 42).
- Jeśli wynik ≠ `expectedTier`, **zmieniaj pokrętła persony w `HsPersonas.ets` (obie kopie)**, nie progi silnika. Zgłoś mi zmiany.
- Jeśli FairWear ma persony, których tu brakuje, dopisz je w `HsPersonas.ets` i w zasobach Health Sim (`persona_<id>_desc` w base i zh_CN, gałąź w `ScenarioView.personaDesc`).
- `HR_PER_SPM = 0.2` w `HsGenerator.ets` musi pasować do reguły K20. Jeśli K20 odrzuca uczciwe kroki Ani lub Kasi, zgłoś mi liczby, zanim cokolwiek zmienisz.

## B5: przebieg demo (sprawdź na emulatorze)

1. Health Sim → Scenario → Marek, „Demo (Sun 4 Oct, 09:00)”. Zanotuj Data ID.
2. FairWear → Connect → otwiera się ekran zgody Health Sim → Allow → powrót do FairWear.
3. Data ID w FairWear = Data ID w Health Sim. Wynik Marka zgodny z oczekiwanym.
4. Health Sim → Kasia → ponownie Connect w FairWear → inny wynik.
5. Ekran zgody: odznacz „Sleep” → w FairWear znika czynnik snu, rośnie „brak danych”.

Oba programy na **tym samym** emulatorze telefonu. Emulator nie obsługuje funkcji rozproszonych ani parowania.

## Znane ryzyka

- `openLink` z własnym schematem: jeśli system pokaże wybór aplikacji, wybierz Health Sim. Przy kodzie 16000019 klient sam przechodzi na jawne `startAbilityForResult`.
- Limit WantParams to 100 KB. Payload dla 30 dni i wszystkich typów ma 65–71 KB. Nie zwiększaj `MAX_DAYS`.
- Tryb „Live (now)” daje inne dane przy każdym uruchomieniu. Na demo używaj trybu Demo.
- Nie zweryfikowano jeszcze: builda w DevEco i działania na emulatorze. Zweryfikowano: `linter-cli` z repo zadania (zero uwag w plikach projektu) i 69/69 testów logiki.

## README FairWear

W tabeli „real / simulated / needs device / needs Huawei approval” dodaj wiersz:
„Huawei Health history — simulated by the Health Sim app (separate HAP on the same phone emulator, Health Service Kit sample-point shape); real access needs Huawei approval of Health Service Kit.”

## Raport po każdym kroku

Wynik lintu i builda (`DEVECOCLI_BUILD_EXIT_CODE`), testy, lista zmienionych plików, screenshoty i wszystko, co odbiega od tej wklejki.
