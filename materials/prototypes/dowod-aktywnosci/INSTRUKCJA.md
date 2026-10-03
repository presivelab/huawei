# Dowód aktywności — instrukcja dla zespołu

Moduł `entry` w ArkTS: zgody → ocena 4 tygodni na telefonie → detektor oszustw → podpis kluczem z HUKS → QR → weryfikacja i decyzja człowieka po stronie ubezpieczyciela.

## Co jest w paczce

```
entry/src/main/ets/
  model/      Types, Personas (dane syntetyczne), DateUtil      — czysty ArkTS, testowany
  logic/      Evaluator, AnomalyDetector, ProofToken, Codec,
              LiveDayCollector, Labels                           — czysty ArkTS, testowany
  platform/   ProofSigner (HUKS), CryptoUtil (cryptoFramework),
              SensorSource (@ohos.sensor), Permissions           — sprawdzone na deklaracjach SDK
  pages/      Index.ets — cała aplikacja, 5 zakładek
entry/src/test/ Logic.test.ets + List.test.ets                  — 26 testów lokalnych (Hypium)
config/        fragmenty do module.json5 i string.json
tools/         run-logic-tests.sh — te same testy w Node, bez DevEco
README.md      opis dla jury (architektura, uruchomienie, co jest symulowane)
AI_WORKFLOW.md wymagany plik o użyciu AI — uzupełnijcie swoją część
```

## Wdrożenie (ok. 10 minut)

1. DevEco Studio → **New Project → Empty Ability**, język ArkTS, SDK **API 12 lub nowsze**. Jeśli macie już projekt, użyjcie go.
2. Skopiujcie katalogi `model/`, `logic/`, `platform/` do `entry/src/main/ets/` i **podmieńcie** `entry/src/main/ets/pages/Index.ets`.
3. Skopiujcie `entry/src/test/Logic.test.ets` i podmieńcie `entry/src/test/List.test.ets`.
4. Do `entry/src/main/module.json5` dopiszcie blok z `config/module.json5.requestPermissions.txt` (wewnątrz `"module"`). **Nie podmieniajcie całego pliku.**
5. Do `entry/src/main/resources/base/element/string.json` dopiszcie dwa wpisy z `config/string.json.entries.txt`.
6. Podpis: **File → Project Structure → Signing Configs → Automatically generate signature** (potrzebne do emulatora i urządzenia).
7. Uruchomcie na emulatorze. `.hap` do zgłoszenia: **Build → Build Hap(s)/APP(s) → Build Hap(s)**, plik w `entry/build/default/outputs/default/`.

### Jeśli coś się nie kompiluje

Kod logiki i warstwy platformowej był sprawdzany kompilatorem, ale **UI (`Index.ets`) nie był kompilowany poza DevEco** — nie mam tu kompilatora ArkUI. Najbardziej prawdopodobne problemy:

| Objaw | Co zrobić |
|---|---|
| Ostrzeżenie, że `getContext` jest przestarzałe | Można zignorować. Albo zamienić na `this.getUIContext().getHostContext()`. |
| `anonAttestKeyItem` nie istnieje w waszym SDK | Usuńcie wywołanie `tryAttest` w `ProofSigner.ets` i zwracajcie `attested: false`. |
| Błąd lintera ArkTS przy `catch (e)` / `e as BusinessError` | Zamieńcie na `catch (e) { const err: BusinessError = e as BusinessError; ... }`. |
| Komponent nie odświeża się po zmianie stanu | Nie przekazujcie wartości stanu jako parametrów `@Builder` — czytajcie `this.xxx` bezpośrednio w builderze. |

## Testy

- **DevEco:** prawy klik na `entry/src/test` → **Run 'Local Test'** (bez emulatora).
- **Node (CI, bez DevEco):** `./tools/run-logic-tests.sh` → `26/26 testów przeszło`. Kompiluje `model/` i `logic/` przez `tsc --strict` i uruchamia te same testy Hypium z zaślepką.

Testy pokrywają: wyniki każdej persony, ograniczenie progu bez zgody na tętno, brak pola snu bez zgody, mieszczenie się tokenu w QR, odrzucenie złego nonce/starego raportu/złego podpisu, wykrycie manipulacji, śmieciowe wejście, detektor na żywo.

## Co jest prawdziwe, a co symulowane

| Element | Stan |
|---|---|
| Ocena 4 tygodni, detektor oszustw, progi | Prawdziwy kod, testy |
| Historia 56 dni | **Dane syntetyczne** (4 persony) w formacie dziennych agregatów z czujników |
| Czujniki na żywo (krokomierz, tętno, noszenie) | Prawdziwe `@ohos.sensor`. Na emulatorze zwykle ich nie ma → przyciski symulacji karmią **ten sam** detektor |
| Klucz i podpis | Prawdziwy HUKS (ECC P-256), autotest weryfikacji. Gdy HUKS zawiedzie → klucz programowy, wyraźnie oznaczony w UI |
| Atestacja klucza | Prawdziwe `anonAttestKeyItem`. Wymaga sieci i wsparcia urządzenia — na emulatorze zwykle „niedostępna” |
| Weryfikacja u ubezpieczyciela | Prawdziwe ECDSA w `cryptoFramework`. Ubezpieczyciel jest **w tej samej aplikacji** (zakładka 5) |
| Huawei Health / Health Service Kit | **Nie użyte** — wymaga wniosku do Huawei (do 15 dni roboczych) |

## Persony (wyniki z testów)

| Persona | Z tętnem | Bez tętna |
|---|---|---|
| Anna — aktywna | 4/4, **Złoty**, OK | Srebrny (limit bez tętna) |
| Marek — tydzień grypy | 3/4, **Złoty**, OK | Srebrny |
| Zofia — mało kroków, poprawa vs własna baza | 2/4, **Srebrny**, OK | Srebrny |
| Kamil — zegarek na wiertarce | **Do przeglądu**, bez zniżki | Do przeglądu — złapany tylko na zdjętym zegarku |

## Scenariusz demo (90 s) w aplikacji

1. **Zgody:** pokażcie wyszarzony cykl i GPS („celowo nie zbieramy”). Wyłączcie tętno → poziom pewności spada.
2. **Tygodnie:** Marek — tydzień grypy niezaliczony, a i tak Złoty.
3. **Kontrola:** Kamil — 5 dni „kroki bez wzrostu tętna” i 1 dzień „kroki przy zdjętym zegarku”. Potem **Symuluj oszustwo** → werdykt na żywo.
4. **Raport:** Anna → Utwórz klucz → Podpisz → podgląd „co wychodzi” i QR.
5. **Ubezpieczyciel:** Weryfikuj → wszystko zielone, zniżka 10%. Potem **Symuluj manipulację** → „Podpis cyfrowy ✗” (u Anny podmienia numer polisy, u Kamila podnosi próg i kasuje flagi).
6. Kamil → Raport → Podpisz → Wyślij → Weryfikuj → **decyzja człowieka** zapisana w dzienniku.

## Pliki do zgłoszenia — co jeszcze zostało

- [ ] Publiczne repo z historią commitów (commitujcie często)
- [ ] `.hap` (punkt 7 wyżej)
- [ ] Nagranie demo
- [ ] `README.md` — gotowy, dopiszcie nazwiska i link do nagrania
- [ ] `AI_WORKFLOW.md` — uzupełnijcie sekcję zespołu
