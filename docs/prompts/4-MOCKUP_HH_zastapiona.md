> Public-safe copy of a team brief (in Polish) that was handed to a coding-agent session as its standing instruction during HackYeah 2026. Kept as written; which briefs are still in force is listed in `docs/prompts/README.md`.

# Wklejka dla Claude Code: mockup źródła danych „Huawei Health”

Wklej do Claude Code w repo FairWear wszystko poniżej linii.

---

Pracujesz w repo FairWear (HarmonyOS/ArkTS, moduły phone + watch + common, min API 20 / compile API 23 / target API 24). Zadanie: dodać źródło danych **„Huawei Health (symulacja)”**. To mock, który zwraca dane w kształcie Health Service Kit (`healthStore`). Siedzi za interfejsem, więc później da się go wymienić na prawdziwy kit bez ruszania silnika. Pracuj na gałęzi `feature/hh-mock`, małymi commitami. Na koniec każdego kroku HH-x uruchom testy i wypisz wynik.

## Twarde zasady

1. **Nie importuj `@kit.HealthServiceKit`.** Kit działa tylko na HarmonyOS i wymaga zgody Huawei. Mock ma własne, lokalne typy, które odwzorowują kształt kitu.
2. **Nie zmieniaj `TierClaim`, progów ani kontraktów silnika.** Zmieniają je już inne kroki (K4+, K19, K21). Mock dostarcza dane do istniejącego interfejsu źródła danych (`DataSource` lub odpowiednik).
3. **Nie zmieniaj nazw person ani ich docelowych poziomów.** Generator ma odtwarzać istniejące scenariusze.
4. **Żadnej sieci.** Dane generują się na urządzeniu z ziarna. Poza aplikację wychodzi tylko podpisany claim, tak jak dotąd.
5. **Bez logo, kolorów i wyglądu Huawei.** W UI pisz tekstem „Huawei Health (symulacja)”. Etykieta „SYMULACJA” musi być widoczna zawsze, gdy aktywny jest mock.
6. **Nie mockuj HRV ani stanu noszenia jako typów danych.** Nie ma ich na liście otwartych typów Huawei. Noszenie wyprowadzamy z luk w próbkach tętna (patrz HH-4).
7. Kod ma przejść ścisły ArkTS: bez `any` i `unknown`, literały obiektów tylko dla zadeklarowanych interfejsów i klas, bez destrukturyzacji.

## HH-0: rozpoznanie (bez zmian w kodzie)

Zgłoś mi krótko, zanim cokolwiek zmienisz:

- gdzie jest interfejs źródła danych i jakie ma metody; jak wygląda typ slotu 5-minutowego i agregat dnia; gdzie jest obecny generator person i jakie ma parametry (persony, pole `tz`, chorobowe dni, pauzy, nabijanie kroków);
- czy `TierClaim` ma pole źródła lub poświadczenia i jakiego jest typu (string czy enum);
- jaki runner testów działa bez emulatora (np. `tools/run-logic-tests.sh`).

Potem przeszukaj zainstalowane SDK DevEco (ścieżkę znajdziesz w ustawieniach SDK) pod kątem `samplePointHelper` i `SamplePointReadRequest`. Jeśli znajdziesz deklaracje Health Service Kit, wypisz **dokładne** nazwy: pola `SamplePoint`, pola `SamplePointReadRequest` oraz nazwy `samplePointHelper.*` dla tętna, tętna spoczynkowego, kroków / aktywności dziennej, snu, SpO2, temperatury skóry, stresu i VO2max, każdą z polami. Tych nazw użyj w HH-1. Jeśli nie znajdziesz, użyj nazw tymczasowych z HH-1 i oznacz każdą komentarzem `// PROVISIONAL: sprawdzić w @kit.HealthServiceKit`.

Co jest potwierdzone w dokumentacji Huawei i ma zostać odwzorowane:

- import w prawdziwym kicie to `import { healthStore } from '@kit.HealthServiceKit'`;
- przed pierwszym wywołaniem trzeba wywołać `healthStore.init`;
- odczyt to `readData<T extends SamplePoint>(request: SamplePointReadRequest): Promise<T[]>`;
- zapytanie ustawia `samplePointDataType: healthStore.samplePointHelper.<typ>.DATA_TYPE` i zakres czasu;
- próbka składa się z czasu (chwili albo przedziału), wartości i źródła danych;
- próbki SpO2 nie mogą na siebie nachodzić, a dane przychodzą z opóźnieniem liczonym w godzinach.

## HH-1: typy i interfejs magazynu

W `common` utwórz katalog `datasource/hh/`:

```
datasource/hh/
  HhTypes.ets               // stałe typów danych, pola, próbka, zapytanie
  HealthStoreLike.ets       // interfejs magazynu, sygnatury jak w kicie
  MockHealthStore.ets       // implementacja mock
  HhPersonaGenerator.ets    // generator 30 dni próbek
  HuaweiHealthDataSource.ets// adapter: próbki -> sloty i dni silnika
  HhRandom.ets              // deterministyczny PRNG (mulberry32)
```

Kształt tymczasowy (zamień na nazwy z SDK, jeśli są):

```ts
export class HhDataType {
  static readonly STEPS: string = 'hh.steps.delta';          // przedział
  static readonly HEART_RATE: string = 'hh.heart_rate';      // chwila
  static readonly RESTING_HR: string = 'hh.resting_heart_rate'; // 1 na dobę
  static readonly SLEEP_FRAGMENT: string = 'hh.sleep.fragment'; // przedział
  static readonly SPO2: string = 'hh.spo2';                  // chwila
  static readonly SKIN_TEMP: string = 'hh.skin_temperature'; // chwila
  static readonly STRESS: string = 'hh.stress';              // chwila
  static readonly VO2MAX: string = 'hh.vo2max';              // chwila
}

export interface HhSamplePoint<F> {
  dataType: string;
  startTime: number;   // ms epoch
  endTime: number;     // ms epoch; == startTime dla próbek chwilowych
  dataSourceId: string;// 'mock:watch5:<persona>'
  fields: F;
}

export interface HhStepsFields { steps: number }
export interface HhHeartRateFields { bpm: number }
export interface HhRestingHrFields { bpm: number }
export interface HhSleepFields { stage: number } // 1 lekki, 2 głęboki, 3 REM, 4 czuwanie (PROVISIONAL)
export interface HhSpo2Fields { spo2: number }   // %, zakres (0, 100]
export interface HhSkinTempFields { celsius: number }
export interface HhStressFields { score: number }// 1–99
export interface HhVo2maxFields { value: number }// ml/kg/min

export interface HhReadRequest {
  samplePointDataType: string;
  startTime: number;
  endTime: number;
}

export interface HealthStoreLike {
  init(): Promise<void>;
  readData<F>(request: HhReadRequest): Promise<HhSamplePoint<F>[]>;
  lastSyncTime(dataType: string): number; // tylko mock; prawdziwy kit: z danych
}
```

## HH-2: MockHealthStore

- Konstruktor: `(persona, anchorTime, seed, grantedTypes: string[])`. `anchorTime` to „teraz” zaokrąglone w dół do 5 minut. W testach podawaj stałą datę.
- `init()` generuje dane raz i trzyma je w pamięci, posortowane według typu i czasu.
- `readData` zwraca próbki danego typu z przedziału `[startTime, endTime)`. Pomija próbki nowsze niż czas synchronizacji tego typu. Dla typu spoza `grantedTypes` rzuca błąd z kodem „brak zgody”, żeby UI mogło pokazać brak czynnika.
- Opóźnienie synchronizacji (konfigurowalne): kroki, tętno i stres 30 min; sen, SpO2 i temperatura skóry 3 h; tętno spoczynkowe i VO2max raz na dobę. `lastSyncTime` zwraca odpowiedni czas, a UI pokazuje „Ostatnia synchronizacja z Huawei Health: hh:mm”.

## HH-3: generator person

Deterministyczny: to samo ziarno, persona i `anchorTime` dają identyczny wynik. Generuje 30 dni wstecz od `anchorTime`, a doby liczy w strefie czasowej persony (pole `tz`).

**Kolejność generowania w każdym slocie 5-minutowym:**

1. **Noszenie (ukryte, nie trafia do mocka jako typ).** Z harmonogramu persony: średnie godziny noszenia, ładowanie (np. 60 min co 2 dni, o stałej porze z małym rozrzutem), noce bez zegarka, a dla persony z wybiórczym zdejmowaniem dodatkowe zdjęcia wokół dni chorobowych.
2. **Kroki**, tylko gdy noszony: z profilu dnia persony (rano i popołudnie aktywniej, noc 0). Zapisuj jako przedziały 5-minutowe tylko tam, gdzie kroki > 0.
3. **Tętno**, tylko gdy noszony: jedna próbka co `hrIntervalMin` (domyślnie 5 min, z rozrzutem ±60 s). Tętno **musi zależeć od kroków**: `bpm = bazaDnia + k * kroki_w_slocie / 5 + szum` (k ok. 0,1–0,15, szum σ ok. 3). W nocy podstawa spada o ok. 8–10 bpm. Bez tego K20 odrzuci uczciwe kroki.
4. **Dni chorobowe** (z definicji persony): co najmniej **2 kolejne dni** z bazą wyższą o 6–10 bpm, kroki ×0,4–0,6, temperatura skóry w nocy +0,4–0,8°C, SpO2 o 1–2 pkt niżej. K18 wymaga dwóch kolejnych dni podwyższonego tętna.
5. **Nabijanie kroków** (persona typu Wei): `padSlotsPerDay` slotów z wysokimi krokami (≥ 300 na slot) i tętnem poniżej bazy + 5. Mają je wyłapać reguły K20 (c).
6. **Tętno spoczynkowe:** jedna próbka dziennie o ok. 07:00, równa 10. percentylowi nocnego tętna tej doby (zaokrąglona). Jeśli w nocy zegarka nie było, brak próbki.
7. **Sen:** fragmenty (lekki / głęboki / REM / czuwanie) tylko w nocnych przedziałach noszenia; cykle ok. 90 min. Bez noszenia brak snu.
8. **SpO2:** co 30 min w nocy, gdy noszony, wartości 95–99, bez nakładania się.
9. **Temperatura skóry:** co 30 min w nocy, gdy noszony.
10. **Stres:** co 30 min w dzień, gdy noszony (dodaj tylko, jeśli silnik albo HES go używa).
11. **VO2max:** jedna wartość na tydzień, stabilna dla persony (np. 36–46).

**Persony:** odtwórz istniejące (np. Ania, Kasia, Marek, Wei) z ich obecnymi poziomami docelowymi. Zmapuj ich obecne parametry na pokrętła generatora: `stepsMean`, `wearHoursMean`, `chargeEveryDays`, `sickDays[]`, `selectiveRemovalAroundSick`, `padSlotsPerDay`, `tz`. Jeśli jakiejś persony nie da się odtworzyć bez zmiany jej poziomu, zatrzymaj się i zgłoś to.

## HH-4: adapter `HuaweiHealthDataSource`

Implementuje istniejący interfejs źródła danych. Czyta przez `HealthStoreLike`, nigdy bezpośrednio z generatora.

- **Noszenie z luk w tętnie.** Kolejne próbki tętna z odstępem ≤ `hrGapMin` (domyślnie 3 × `hrIntervalMin` = 15 min) tworzą odcinek noszenia. Slot jest „noszony”, jeśli odcinki pokrywają co najmniej 50% jego czasu. W README zapisz wprost, że w tej ścieżce noszenie jest wnioskowane, a nie mierzone.
- **Kroki z dowolnych okien.** Przedział kroków rozkładaj proporcjonalnie na sloty, które przecina. Prawdziwy kit może zwracać okna inne niż 5 min.
- **Pozostałe typy** agreguj do tego, czego chce silnik: tętno w slocie, tętno spoczynkowe na dobę, minuty snu na noc, nocne SpO2 i temperaturę, VO2max.
- **Brak zgody na typ** oznacza brak czynnika, a nie zero. Ten czynnik wypada i idzie przez pokrycie, tak jak dziś.
- **Źródło w claimie:** jeśli `TierClaim` ma pole źródła typu string, wpisz `HH_SIM`. Jeśli to enum, **nie rozszerzaj go dziś**. Pokaż źródło tylko w UI i opisz to w README.
- Doby agreguj w strefie persony, nie w strefie urządzenia.

## HH-5: UI (moduł phone)

1. **Wybór źródła** w ustawieniach: „Zegarek na żywo” albo „Huawei Health (symulacja)”. Moduł watch zostaje bez zmian: tam ścieżka na żywo.
2. **Ekran zgody** przed pierwszym użyciem mocka. Lista typów z przełącznikami: kroki, tętno, tętno spoczynkowe, sen, SpO2, temperatura skóry, VO2max (i stres, jeśli używany). Pod listą tekst: „W prawdziwej wersji tę zgodę wyświetla Huawei Health. Tu jest symulowana.” Wyłączenie typu ma od razu zmienić pokrycie i wynik.
3. **Pasek źródła** na pulpicie: „Dane: Huawei Health (symulacja) · 30 dni · HUAWEI WATCH 5” oraz etykieta „SYMULACJA”.
4. **Linia synchronizacji:** „Ostatnia synchronizacja: hh:mm” z `lastSyncTime`.
5. Analiza w tej ścieżce działa na telefonie. Podpis robi telefon, tak jak dziś dla ścieżki telefonicznej.

## HH-6: testy (runner bez emulatora)

1. **Kształt:** każdy typ z dozwolonej listy; `startTime ≤ endTime`; tętno 30–220, SpO2 w (0, 100], kroki ≥ 0, stres 1–99; próbki SpO2 tego samego źródła nie nachodzą na siebie.
2. **Strażnik listy typów:** w mocku nie ma HRV ani żadnego typu stanu noszenia.
3. **Determinizm:** dwa przebiegi z tym samym ziarnem dają identyczne dane.
4. **Spójność:** w czasie nienoszenia nie ma tętna, snu, SpO2 ani temperatury; tętno spoczynkowe różni się o ≤ 3 bpm od 10. percentyla nocnego tętna.
5. **Sprzężenie tętna z krokami:** uczciwe persony mają 0 odrzuconych kroków (K20) i 0 nieplanowanych dni ostrych (K18).
6. **Wyniki:** każda persona ma swój dotychczasowy poziom; Marek ma flagę wybiórczego zdejmowania; dla Wei wynik(Wei) == wynik(Wei bez slotów nabijania).
7. **Wnioskowanie noszenia:** na personie z ładowaniem co 2 dni odcinki ładowania wychodzą jako nienoszone (± 1 slot).
8. **Okna kroków:** te same kroki podane w oknach 1-, 5- i 15-minutowych dają identyczne sumy w slotach.
9. **Zgoda:** wyłączenie snu obniża pokrycie i nie rzuca wyjątku w silniku.
10. **Regresja:** jeśli stary generator person zostaje, porównaj poziomy z obu ścieżek i wypisz różnice (raport, bez asercji).

## HH-7: dokumentacja

Dopisz do README sekcję „Źródła danych” (albo utwórz `docs/DATA_SOURCES.md`):

| Ścieżka | Skąd dane | Co mierzone | Co symulowane |
|---|---|---|---|
| Zegarek na żywo | `@ohos.sensor` na zegarku | tętno, kroki, noszenie | nic |
| Huawei Health (symulacja) | `MockHealthStore` w kształcie Health Service Kit | nic | wszystko; noszenie wnioskowane z luk w tętnie |

Oraz krótko, jak przejść na prawdziwy kit:

1. Wniosek o Health Service Kit w konsoli Huawei, konfiguracja Client ID, wniosek o każdy zakres danych. Zakresy wrażliwe (m.in. tętno i SpO2) przechodzą ręczną weryfikację; z wcześniejszego researchu wynika ok. 15 dni roboczych.
2. `RealHealthStore` implementujący `HealthStoreLike` przez `healthStore.init` i `healthStore.readData`, tylko w produkcie lub module dla HarmonyOS, żeby build OpenHarmony pozostał czysty.
3. Podmiana w jednym miejscu (fabryka źródła danych); silnik bez zmian.

Zdanie do pitchu (wpisz do README dosłownie): „Dane z Huawei Health są tu symulowane w formacie Health Service Kit. Przepływ i analiza są gotowe; prawdziwy dostęp wymaga zatwierdzenia przez Huawei. Analiza działa lokalnie, a na zewnątrz wychodzi tylko podpisany poziom.”

## Kolejność i cięcia

- **Musi być:** HH-0, HH-1, HH-2, HH-3 (punkty 1–6), HH-4, etykieta SYMULACJA, testy 1–6.
- **Powinno być:** sen i SpO2 (HH-3 pkt 7–8), ekran zgody, linia synchronizacji, testy 7–9, README.
- **Jeśli zostanie czas:** temperatura skóry, stres, VO2max, test 10.

Po każdym kroku: wynik testów, lista zmienionych plików i wszystko, co odbiega od tej specyfikacji.
