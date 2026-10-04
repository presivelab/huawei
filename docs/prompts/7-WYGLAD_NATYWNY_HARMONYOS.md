> Public-safe copy of a team brief (in Polish) that was handed to a coding-agent session as its standing instruction during HackYeah 2026. Kept as written; which briefs are still in force is listed in `docs/prompts/README.md`.

# WKLEJKA 7: wygląd na natywnym poziomie HarmonyOS (telefon, zegarek, karta)

## Kontekst i zasady

Obecne ekrany są poprawne, ale wyglądają jak szkic:
- puste „—” zamiast liczb;
- surowe nazwy stanów (`NOT_AUTHORIZED`) widoczne dla użytkownika;
- akapity tekstu zamiast hierarchii;
- brak ikon i wykresów;
- szablonowa ikona aplikacji;
- tarcza zegarka zapełniona zdaniami.

**Kolejność:**
- **W-0** robisz od razu, niezależnie od reszty.
- **W-1 do W-4** robisz **po I-2** z wklejki 6 (HES-Lite i ekrany z `fairwear-ui`). Ekrany i tak się zmienią, a bez danych żaden wygląd nie zadziała.

**Zasada:** nie kopiujesz ekranów, ikon, układu ani kolorystyki HUAWEI Health. Natywny wygląd budujesz tym, czego używają aplikacje systemowe:
- komponenty ArkUI;
- ikony HM Symbol (`SymbolGlyph` z `sys.symbol.*`);
- zasoby systemowe (`sys.color.*`);
- wytyczne HarmonyOS Design.

Sięgasz po skille `hmos-arkui-develop-skill` i `hmos-arkui-scenario-development`. Nazwy symboli, zasobów i komponentów sprawdzasz w SDK. Żadnych bibliotek wykresów z ohpm, bo jury ocenia zależności (B14).

## W-0: szybkie poprawki (teraz, około 30 min)

1. **Statusy po ludzku.** W UI pokazujesz tylko etykiety, a enumy zostają w logach i testach:

   | Enum | Etykieta w UI |
   | --- | --- |
   | `NOT_AUTHORIZED` | „Not connected” |
   | `DEMO` | „Demo data” |
   | `UNAVAILABLE` | „Unavailable in this build” |
   | `CONNECTED` | „Connected” |

   Obok etykiety stoi kolorowa kropka statusu. Zaktualizuj `tools/check-wording.sh`, żeby wyłapywał enumy w tekstach UI.
2. **Ekran powitalny.** Zamiast akapitu: jedno zdanie wartości i trzy krótkie wiersze z symbolami:
   - „Reads” — co czytamy;
   - „Never reads” — czego nie czytamy;
   - „Leaves the phone” — tylko podpisany tier, gdy go udostępnisz.

   Pełna lista typów danych jest pod „Details”. Dolna połowa ekranu nie może zostać pusta: zajmuje ją prosta ilustracja albo przycisk przy dolnej krawędzi.
3. **Ikona aplikacji.** Własna ikona warstwowa (pierwszy plan i tło) zamiast szablonowej. Prosty znak FairWear: okrąg albo tarcza z literą „F” lub z łukiem. Bez serca i bez elementów ikon HUAWEI Health.
4. **Puste stany.** Zamiast samych „—” wyświetlasz symbol i jedno zdanie, np. „Score appears after HUAWEI Health data is connected”.

## W-1: wspólny system wizualny

- **Kolory.** Jeden plik tokenów (rozszerz istniejący `fw_color.json` z paczki albo `color.json`), w wersji jasnej i ciemnej:
  - jeden kolor na metrykę: kroki, tętno, sen, minuty aktywności, VO₂max, HRV, treningi;
  - kolory tierów A/B/C;
  - kolory statusów.

  Tła i tekst bierzesz z zasobów systemowych, np. `sys.color.ohos_id_color_background`, `…_sub_background`, `…_text_primary` i `…_text_secondary`.
- **Typografia.** Cztery poziomy: duża liczba, jednostka (mniejsza, tuż przy liczbie, ta sama linia bazowa), etykieta i opis. Liczba nigdy nie stoi bez jednostki.
- **Ikony.** Każda metryka ma jeden `SymbolGlyph` w swoim kolorze, wszędzie ten sam: dashboard, „Why this tier”, kalendarz, zgoda.
- **Karty.** Zaokrąglone, bez obramowań, z odstępami w siatce 4/8/12/16/24. Jeden akcent koloru na kartę.
- **Ruch.** Pierścienie wypełniają się animacją (`animateTo`, 300–600 ms), liczby przy wejściu ekranu nabiegają do wartości, a przejścia zapewnia systemowa `Navigation`.

## W-2: telefon (po I-2)

- **Dashboard:**
  - **Główna karta:** pierścień (`DataPanel` albo `Gauge`) z wynikiem HES w środku, obok litera tieru na kolorowym znaczku, pod spodem dwa chipy: pokrycie i pewność. Komunikat typu „1 point to A” zajmuje jedną linię, pod nim przycisk „Why this tier”.
  - **Kafle metryk** w siatce 2 kolumn (`GridRow`/`GridCol`). Każdy kafel ma symbol z nazwą, dużą wartość z jednostką i słupki z 7 dni (zwykłe `Column` albo `Rect`, bez bibliotek). Zakres wyłączony w zgodzie to wyszarzony kafel „Off · missing evidence”.
  - **Status źródła:** jedna linia pod tytułem z kropką. Dotknięcie otwiera AD-3.
  - **Live card** jest wyraźnie oznaczona „Demo values”.
- **Why this tier:** sekcje „Strongest”, „To improve” i „Missing data”. Przy każdej pozycji stoi symbol metryki i pasek wkładu. Brakujące dane są pokazane jako chipy.
- **Wearable calendar:** dni jako kolorowe kropki w siatce. Szczegóły dnia otwierają się w arkuszu (sheet) z przyciskiem „Appeal this day”.
- **Share:** komponent `QRCode` i karta „What the partner sees” (tylko tier, okres i `kid`). Główny przycisk przypięty u dołu ekranu.
- **Widok partnera:** wynik weryfikacji jako duży status z symbolem (`checkmark_circle` albo błąd) i nazwą kroku, na którym weryfikacja się zatrzymała.
- **Tytuły:** duży tytuł `Navigation`, zwijany przy przewijaniu (sprawdź tryb tytułu w SDK).

## W-3: zegarek (po I-3)

- Czarne tło i jedna główna informacja na ekran. Kolejne ekrany przewijasz koroną albo przez `ArcList`.
- **Ekran główny:**
  - na środku duże cyfry tętna, nad nimi symbol serca w kolorze tętna;
  - na obrzeżu pierścień „worn today” w %;
  - pod cyframi krótki stan z symbolem: „On wrist”, „Not on wrist” albo „Charging”.
- Długie zdania znikają z tarczy. Zostaje co najwyżej jedna krótka linia „Demo”, a wyjaśnienia idą do README.
- Zamiast „— bpm” przy braku odczytu: mała linia „Waiting for heart rate” i delikatnie pulsujący symbol.
- Tarcza 24h z paczki (`DayDial`) dostaje te same kolory metryk co telefon.
- Zrzuty na emulatorze 466×466. Treść mieści się w bezpiecznym obszarze okręgu.

## W-4: karta 2×2 na ekranie głównym

Karta pokazuje:
- mały pierścień pokrycia;
- „Score ready” albo „Not yet”;
- status źródła z kropką.

Tieru nigdy nie pokazuje. Sprawdź, które komponenty są dozwolone w kartach ArkTS (`DataPanel`, `Progress`). Jeśli żadne nie są, narysuj pierścień przez `Circle` albo `Shape`.

## W-5: weryfikacja

- Zrzuty „przed” i „po” każdego ekranu, w motywie jasnym i ciemnym, z emulatorów telefonu i zegarka, w `docs/screenshots/design/`.
- Lint: 0 błędów. `tools/check-wording.sh`: 0 trafień, łącznie z enumami w UI.
- Ręczny przegląd: brak logo, ikon i układów HUAWEI Health. Nazwa „HUAWEI Health” pojawia się tylko jako tekst źródła danych.
- Sekcja „Design” w README: komponenty systemowe ArkUI, HM Symbol, zasoby systemowe, tryb ciemny i brak zewnętrznych bibliotek UI. Jury punktuje użycie platformy.

## Kolejność i czas

| Krok | Czas | Uwagi |
| --- | --- | --- |
| W-0 | 30 min | teraz |
| W-1 + W-2 | około 2 h | po I-2 |
| W-3 | około 1 h | po I-3 |
| W-4 | 30 min | |
| W-5 | na bieżąco | |

Jeśli czasu zabraknie, priorytet ma dashboard i ekran główny zegarka, bo to widać na nagraniu.

Po każdym kroku podaj zrzuty przed i po, listę zmienionych plików i wynik testów. Na koniec sesji zrób `/raport` i `/backup`.
