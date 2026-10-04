<pasted_content id="381a">
# WKLEJKA: zegarek zapisuje dane jak Huawei Health, a w emulatorze zegarka i telefonu wychodzą te same dane

## Kontekst

Repo FairWear (HarmonyOS/ArkTS, moduły: telefon, zegarek, `common`). Mock Huawei Health z wklejki `WKLEJKA_MOCKUP_HUAWEI_HEALTH.md` jest gotowy albo w budowie w `common/.../datasource/hh/` (HhTypes, HealthStoreLike, MockHealthStore, HhPersonaGenerator, HuaweiHealthDataSource, HhRandom). Ta wklejka rozszerza go o zegarek.

## Cel

1. Zegarek w emulatorze zapisuje dane tak jak Huawei Health: te same typy próbek, kadencja, jednostki i luki.
2. Dla tej samej persony, ziarna i kotwicy czasu zegarek i telefon mają identyczne próbki i ten sam tier. Widać to po odcisku danych na obu ekranach.
3. Na zegarku działa tryb na żywo. Tętno i kroki ustawiane w panelu emulatora przechodzą przez ten sam rejestrator co generator.

## Ograniczenia (przyjąć, nie obchodzić)

- W emulatorach nie ma prawdziwego Huawei Health ani jego danych. Prawdziwy Health Service Kit wymaga zgody Huawei. Mock nie importuje `@kit.HealthServiceKit`.
- Emulator DevEco nie obsługuje funkcji rozproszonych ani parowania Bluetooth (tabela „Emulator capability comparison” w README wyzwania). Zegarek nie wyśle danych do telefonu. Nie buduj synchronizacji. Spójność zapewnia determinizm.
- Emulator symuluje tętno, kroki i koronę. Czujnika założenia zegarka nie symuluje, więc noszenie dalej wnioskujemy z luk w tętnie.
- Nie kopiuj wyglądu Huawei Health: żadnego logo, ikon, układu ekranów ani kolorystyki. UI jest własny, z natywnych komponentów ArkUI. Źródło opisujemy tekstem: „Format: Huawei Health · dane symulowane”.
- Nazwy API sprawdzaj skillem `hmos-arkts-knowledge-retriever` albo w zainstalowanym SDK, nie z pamięci. Jeśli czegoś nie ma w API 20–24, zgłoś i zaproponuj obejście.

## ZW-0: rozpoznanie (bez zmian w kodzie)

Zgłoś krótko:

- czy `datasource/hh/` istnieje i w którym module; czy moduł zegarka i telefonu zależą od tego samego `common`, czy mają kopie;
- skąd generator bierze „teraz” (`Date.now()`, `new Date()`), strefę czasową i granice dób;
- czy silnik tieru jest w `common` i może działać na zegarku;
- co dziś pokazuje moduł zegarka i z jakich czujników korzysta;
- typ urządzenia i uprawnienia w `module.json5` modułu zegarka.

Jeśli coś przeczy tej wklejce, zatrzymaj się i zapytaj. W przeciwnym razie kontynuuj.

## ZW-1: jeden generator dla obu modułów

- Generator, PRNG, typy i adapter są tylko w `common`. Kopie w modułach usuń, gdy potwierdzisz, że nic innego ich nie używa.
- W generatorze nie wolno używać `Math.random`, `Date.now()`, `new Date()` bez argumentów ani strefy i locale urządzenia. Wszystko przychodzi z parametrów.
- Zaokrąglaj w jednym miejscu, w generatorze: tętno i kroki do liczb całkowitych, reszta według obecnych typów. UI niczego nie zaokrągla.

## ZW-2: stała kotwica i strefa czasowa

```ts
// common/.../datasource/hh/HhClock.ets
export const DEMO_ANCHOR_MS: number = Date.UTC(2026, 9, 4, 6, 0, 0); // 4.10.2026 08:00 Europe/Warsaw (UTC+2)
export const DEMO_TZ_OFFSET_MIN: number = 120; // 30 dni wstecz nie przecina zmiany czasu (25.10.2026)

export enum HhClockMode { DEMO = 0, LIVE = 1 }

// DEMO -> DEMO_ANCHOR_MS; LIVE -> nowMs zaokrąglone w dół do 5 min
export function anchorFor(mode: HhClockMode, nowMs: number): number { /* ... */ }

// początek doby lokalnej z jawnego offsetu, nie ze strefy urządzenia
export function localDayStart(ms: number, tzOffsetMin: number): number { /* ... */ }
```

- Domyślny tryb na obu modułach to DEMO. Domyślna persona, ziarno i tryb są stałymi w `common`, więc oba moduły startują z tymi samymi.
- Wszystkie granice dób liczysz z `tzOffsetMin` persony. Strefa emulatora może być inna niż warszawska.

## ZW-3: odcisk danych

```ts
// common/.../datasource/hh/HhFingerprint.ets
export function hhFingerprint(samples: HhSamplePoint<Object>[]): string // 8 znaków hex
```

- Posortuj kopię po (dataType, startTime, endTime, dataSourceId). Każdą próbkę serializuj kanonicznie, z kluczami alfabetycznie, także w `fields`. Jeśli ArkTS nie pozwala na dynamiczne klucze, napisz serializer dla każdego typu pól.
- Haszuj FNV-1a 32-bit. To identyfikator danych, nie zabezpieczenie, i nie trafia do claimu.
- Na obu ekranach pokaż małym tekstem jedną linię, np. `HH-2 · seed 42 · dane 3f9a12c0 · DEMO`.

## ZW-4: reguły zapisu jak w Huawei Health

Plik `common/.../datasource/hh/HhRecorderRules.ets` to jedyne źródło reguł. Używają go generator i tryb na żywo.

- **Tętno.** Huawei Health ma ciągły pomiar w dwóch trybach: w czasie rzeczywistym (raz na sekundę) albo inteligentnym, który dopasowuje częstość do aktywności. Modelujemy tryb inteligentny z parametrami `HR_REST_INTERVAL_MIN = 10`, `HR_ACTIVE_INTERVAL_MIN = 1`, `ACTIVE_STEPS_PER_MIN = 60`. Dokładnych interwałów Huawei publicznie nie podaje, więc oznacz je w kodzie i README jako założenie. Jeśli generator ma już kadencję, przenieś ją tutaj zamiast wymyślać nową.
- Próbka tętna to średnia odczytów z okna, zaokrąglona. Brak odczytów albo odczyt ≤ 0 oznacza brak próbki (lukę), nigdy próbkę z zerem.
- Pojedynczy pomiar na żądanie nie trafia do danych, bo w Huawei Health się nie synchronizuje. Jeśli zegarek ma taki przycisk, pokazuje wartość i niczego nie zapisuje.
- **Kroki** to próbki przedziałowe z deltą (`hh.steps.delta`) w tym samym oknie i z tą samą konwencją dla pustych okien co w obecnym generatorze.
- **Noszenie** nie ma osobnego typu. Wynika z luk w tętnie według istniejącej logiki silnika.
- Generator buduje próbki przez te same funkcje (np. `bucketHeartRate`, `stepsDelta`), a nie przez własną pętlę. Wtedy dane na żywo i historia z definicji mają ten sam kształt.

## ZW-5: tryb na żywo na zegarku (emulator)

- W `module.json5` zegarka dodaj `ohos.permission.READ_HEALTH_DATA` (tętno) i `ohos.permission.ACTIVITY_MOTION` (krokomierz), z `reason` i `usedScene`. Oba są nadawane przez użytkownika, więc proś o nie w trakcie działania przez `abilityAccessCtrl.requestPermissionsFromUser`.
- `HhLiveRecorder.ets` przyjmuje surowe odczyty `(timestampMs, heartRate)` i `(timestampMs, cumulativeSteps)` i zwraca `HhSamplePoint[]` według `HhRecorderRules`. Rekorder nie importuje `@ohos.sensor`. Subskrypcja jest w osobnej klasie, dzięki czemu rekorder da się testować bez emulatora.
- Subskrypcja: `sensor.on(sensor.SensorId.HEART_RATE, ...)` z `data.heartRate` i `sensor.on(sensor.SensorId.PEDOMETER, ...)` z `data.steps` (licznik narastający). Najpierw sprawdź listę czujników. Jeśli czujnika brak, wyłącz tryb na żywo z komunikatem, a reszta działa dalej. Przy wyjściu ze strony wywołaj `sensor.off`.
- Kroki narastające zamieniaj na deltę. Jeśli licznik spadnie (reset), nową wartość licz od zera.
- W trybie LIVE historia z generatora kończy się na `localDayStart(anchor)`, a dzisiejsze dane pochodzą tylko z rekordera. Tier przeliczaj po zamknięciu każdego okna albo przyciskiem „Przelicz”.
- Opcjonalnie dodaj przełącznik „czas ×60” (1 s to 1 min zapisu), wyraźnie oznaczony na ekranie. Dzięki niemu w nagraniu demo widać wykrycie zdjętego zegarka bez czekania pół godziny. Domyślnie jest wyłączony.
- Scenariusz w panelu emulatora: tętno 70, kroki rosną, potem tętno 120 przy szybszych krokach, potem tętno 0 (zdjęty zegarek), luka i spadek noszenia. Sprawdź, co emulator wysyła przy tętnie 0 (zero czy brak zdarzeń), i zapisz to w README. Obie sytuacje mają dać lukę.

## ZW-6: zegarek i telefon bez synchronizacji

- W trybie DEMO oba moduły liczą tier z tej samej historii (ta sama persona, ziarno i kotwica). Dają więc ten sam odcisk i ten sam tier, a linia z ZW-3 jest identyczna na obu ekranach.
- Dane z trybu LIVE zostają na zegarku. Nie udawaj, że trafiły do telefonu.
- W README i na ekranie „Źródło” umieść jedno zdanie: „Na urządzeniu dane z zegarka trafiają do telefonu przez Huawei Health. Emulatory nie mają synchronizacji, więc oba moduły odtwarzają tę samą historię z tego samego ziarna, co potwierdza identyczny odcisk danych.”

## ZW-7: UI zegarka

Dopasuj do istniejących ekranów zegarka i dodaj tylko to, czego brakuje:

1. Dziś: tętno (na żywo albo ostatnia próbka), kroki, noszenie w %.
2. Wynik: tier A/B/C i pokrycie danych.
3. Źródło: tryb DEMO/LIVE, persona, odcisk, etykieta „SYMULACJA” i zdanie z ZW-6.

Treść mieści się w bezpiecznym obszarze okrągłego ekranu. Styl jest własny, FairWear, bez elementów graficznych Huawei Health.

## Testy (w `common`, bez emulatora, gdzie się da)

1. Determinizm: dwa wywołania generatora z tymi samymi parametrami dają ten sam odcisk.
2. Złote odciski: `hh_golden.json` zawiera odcisk i tier dla każdej persony (seed 42, `DEMO_ANCHOR_MS`), a test je porównuje. Zmiana generatora ma ten test celowo wywalić. Plik aktualizujesz tylko świadomie, z opisem w commicie.
3. Granice dób: dla offsetu 120 chwile 23:59 i 00:01 czasu warszawskiego trafiają do różnych dób.
4. Zgodność rekordera z generatorem: scenariusz 30 min spoczynku (tętno 65, kroki stałe) i 10 min ruchu (tętno 120, 100 kroków/min) przepuszczony przez funkcje generatora i przez `HhLiveRecorder` daje identyczne próbki: 3 próbki tętna w spoczynku, 10 w ruchu i 1000 kroków.
5. Kroki: strumień narastający z resetem daje nieujemne delty, a ich suma równa się rzeczywistej liczbie kroków.
6. Tętno 0 i brak odczytów nie tworzą próbek. Po przekroczeniu progu silnik zgłasza brak noszenia.
7. Ręcznie w emulatorach: w trybie DEMO zegarek i telefon pokazują ten sam odcisk i tier. Zrzuty ekranu zapisz w `docs/`.

## Kolejność i cięcia

- **Musi być:** ZW-0, ZW-1, ZW-2, ZW-3, ZW-6, testy 1–3, etykieta „SYMULACJA”.
- **Powinno być:** ZW-4, ZW-5 (tętno i kroki na żywo), testy 4–6.
- **Jeśli zostanie czas:** „czas ×60”, dopracowanie ZW-7, test 7 ze zrzutami.

Po każdym kroku podaj wynik testów, listę zmienionych plików, odciski dla person i wszystko, co odbiega od tej wklejki.
</pasted_content id="381a">
