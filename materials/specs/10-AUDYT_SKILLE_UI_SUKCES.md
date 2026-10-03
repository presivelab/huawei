# 10: audyt (skille, stack, UI) i co jest potrzebne, żeby FairWear wygrał (stan 01:30)

Obowiązuje razem z wklejkami **8 (POPRAWKA FINAL)** i **9 (SECURITY)**. Nie zmienia ich rozstrzygnięć: claim ma 7 pól, reguła noszenia to `WearStateMachine`, zegarek nie zasila wyniku. Dokłada audyt i trzy brakujące rzeczy: dane, układ informacji i wspólny system UI.

## A. Stan faktyczny (sprawdzony w `C:\dev\FairWear`, `main` = `491bcb4`)

**Co jest mocne:**
- Testy: common 83/83, watch 6/6. Build entry, watch i common przechodzi. Lint: 0 błędów.
- Watch Link działa na emulatorach przez relay `hdc`: parowanie, podpis HUKS, łańcuch dni, „Invalid signature” po zmianie pakietu, „Missing 1 day”.
- Przepływ dodatku: połączenie, zgoda w dwóch krokach, odłączenie. Do tego karta 2×2, skrót i jedno wejście `fwTarget`.
- Higiena: brak sekretów w historii, `entry` bez uprawnień, minimum API 20.
- Uczciwe dokumenty: README, ARCHITECTURE, DEMO_SCRIPT, test-results.

**Co blokuje sukces:**
1. **Nie ma rdzenia produktu.** W `_incoming/` jest `HealthSim`, ale nadal nie ma `fairwear-ui.zip`, więc nie ma HES-Lite, person, tieru, „Why this tier”, Share ani widoku partnera. Dashboard pokazuje „—”. To blokada numer 1 od ponad godziny, a zdjąć ją może tylko człowiek: pobrać plik z czatu „Analiza arkusza”.
2. **Puste dane wszędzie.**
   - Telefon nie ma person.
   - Emulator zegarka wysyła tętno 0, więc dni z zegarka to „worn 0 h · not observed 24 h”, a tarcza pokazuje „— bpm”.

   Żaden wygląd nie obroni ekranu z zerami. Aplikacje zdrowotne to w 90% wizualizacja danych.
3. **Ekrany wyglądają jak konsola deweloperska.** Karta Watch link pokazuje użytkownikowi `#3 · Accepted`, `Chain #4 ✓`, `fd7c02b2`, surowe daty i czerwony tekst. To są dowody dla jury, a nie główny ekran dla użytkownika.
4. **UI nie ma warstwy wizualnej.** Pomiar kodu:

   | Moduł | Kolory i rozmiary systemowe | Wizualizacja danych | Inne |
   | --- | --- | --- | --- |
   | `entry` | 40 `sys.color`, 35 `sys.float` (dobra podstawa) | 0 (`DataPanel`, `Gauge`, `Progress`) | 0 `Grid`, 0 animacji, brak kolorów metryk |
   | `watch` | — | — | 530 linii w jednej stronie, 0 `SymbolGlyph`, 0 `ArcList`, 0 animacji, 5 kolorów hex |

5. **Za dużo równoległych strumieni.** Jest 10 wklejek, gałęzie `security-watch`, `health-sim-audit` i `integration`, sesje A i B oraz Health Sim. Wklejka Health Sim v2 zakłada stan, którego nie ma: „silnik HES jest w `common/.../hes/`”, repo w `Desktop/fairwear-staging`. Każda nowa sesja buduje na fikcji z raportu.

## B. Audyt stosu skilli i narzędzi

| Element | Stan | Ocena / co poprawić |
|---|---|---|
| 9 skilli hackathonu (`ohos-*`, `hmos-*`, `conductor-dev`) | DevEco CLI 1.3.4 jest, więc instalator przeszedł. Katalogu `~/.claude/skills` nie widzę (chroniony). | **Brak śladu użycia.** `AI_WORKFLOW.md` ma „[versions to be added]”, a w commitach i dokumentach nie pada żadna nazwa skilla. Agent ma potwierdzić listę (`ls ~/.claude/skills`), używać skilli jawnie i wpisać to do `AI_WORKFLOW`. Jury czyta ten plik. |
| `ohos-app-dev` (lint → build → run → log → screenshot) | Agent używa własnych `tools/deploy.sh` (`hvigorw` + `hdc`) i `tools/lint.sh` (`devecocli check lint`). | Działa, ale obok skilla. Zostaw skrypty, a w README dopisz, że to odpowiednik pętli `ohos-app-dev`. Przy problemach z buildem lub uruchomieniem sięgaj po skill. |
| `hmos-arkui-develop-skill`, `hmos-arkui-scenario-development` | W kodzie UI nie widać ich wpływu: 0 `DataPanel`/`Gauge`/`ArcList`/`Grid`. | **Główna dźwignia wyglądu.** Skille mają gotowe wzorce: `DataPanel`/`Gauge` (data display), `ArcList` (okrągły ekran), `SymbolGlyph`, `backgroundBlurStyle`, `Navigation`. Każda zmiana UI ma zaczynać się od nich. |
| `hmos-arkui-mvvm-pattern` | `watch/pages/Index.ets` ma 530 linii w jednym pliku. | Rozbij według skilla: View, ViewModel i komponenty. Bez tego W-3 będzie bolesne. |
| `hmos-arkts-knowledge-retriever` | Brak śladu. | Każde niepewne API (`formProvider`, `batteryInfo`, symbole) sprawdzaj nim, nie z pamięci. |
| `~/.agents/skills`: `apple-design`, `write-swift`, `animate-expo`, `pick-ui-library`, `ask-sonner`, `emil-design-eng`, `animate`, `prototype`, … | Zainstalowane na poziomie użytkownika. | **Nie dla tego projektu.** Celują w iOS i web i ciągną UI w złą stronę. W `AGENTS.md` dopisz, żeby z nich nie korzystać. |
| Skill projektu | Brak `.claude/skills/` w repo. | **Dodać** `fairwear-ui` (sekcja D). Każda sesja w każdym worktree dostaje te same zasady wyglądu, a to jedyny sposób na spójność przy wielu agentach. |
| Źródło prawdy | Raport HES-Lite opisuje kod, którego nie ma. Wklejki 1–9 i Health Sim v2 się wykluczają. | W `AGENTS.md` sekcja „Project state”: co jest w repo, co obowiązuje (8 + 9 + 10) i czego nie zakładać (HES jest dopiero po rozpakowaniu paczki). |

## C. Co jest potrzebne do sukcesu (pod kryteria jury)

| Kryterium (waga) | Dziś | Warunek dobrej oceny |
|---|---|---|
| Oryginalność (20%) | Mocny pomysł (podpisany tier zamiast danych, dowód noszenia z zegarka), ale na ekranie go nie widać | Pokazać w 90 s: Ania → A, Marek → oflagowany z dowodem, Ola → brak wyniku zamiast złego wyniku, partner weryfikuje podpis bez danych |
| Użyteczność (20%) | Słaba: brak wyniku | Persony z HES-Lite i jeden scenariusz klienta ubezpieczyciela |
| Wykonanie techniczne (20%) | Mocne: testy, podpisy, łańcuch, lint, uczciwe dokumenty | Rdzeń HES w kodzie, testy person, obsługa błędów pokazana w demo |
| Platforma (20%) | Dobre: HUKS, CryptoFramework, sensory, Form Kit, skróty, relay | Zostawić. Health Sim jako drugą aplikację (Want/openLink) dodać tylko, jeśli zmieści się w 1 h po HES |
| Demo (10%) | Słabe: puste ekrany i zera | Dane wszędzie, ekrany „konsumenckie”, dowody techniczne pod „Verification details” |
| Powtarzalność (10%) | Dobra | Uzupełnić `AI_WORKFLOW.md` (skille, prompty), podpisane `.hap`, publiczne repo |

**Kolejność ważności:** (1) rdzeń z danymi → (2) dane na zegarku → (3) układ informacji i wizualizacja → (4) oddanie. Bez (1) reszta nie podnosi oceny.

## D. Wklejka dla agenta (sesja A, od `main`)

```
DODATEK 10 (obowiązuje z wklejkami 8 i 9; ich rozstrzygnięć nie zmieniasz)

0. Skille i źródło prawdy (15 min)
   - Wypisz zainstalowane skille (ls ~/.claude/skills) i wpisz je z wersjami do AI_WORKFLOW.md (tabela Tools used).
   - AGENTS.md, nowa sekcja "Project state":
     * stan repo: HES-Lite NIE jest w repo, dopóki _incoming/fairwear-ui nie istnieje;
     * obowiązują wklejki 8, 9 i 10;
     * do UI używaj hmos-arkui-develop-skill, hmos-arkui-scenario-development,
       hmos-arkui-mvvm-pattern oraz skilla projektu fairwear-ui;
     * nie używaj apple-design, write-swift, animate-expo, pick-ui-library, ask-sonner,
       emil-design-eng (iOS/web).
   - Commit.

1. Skill projektu .claude/skills/fairwear-ui/SKILL.md (commit do repo, 20 min)
   Treść:
   - kiedy go używać: każda zmiana w entry/view, entry/widget, watch/pages;
   - tokeny: kolory metryk (kroki, tętno, sen, aktywność, VO2max, HRV, trening, noszenie,
     ładowanie, nieobserwowane), tier A/B/C i status jako app.color w base i dark;
     tło i tekst tylko z sys.color;
   - komponenty z UI kitu (punkt 2) zamiast ręcznych Row/Column;
   - zasady:
     * liczba zawsze z jednostką;
     * zero nigdy nie udaje braku danych (pusty stan albo "—" z wyjaśnieniem);
     * użytkownik nie widzi enumów, hashy, seq ani kid poza ekranem "Verification details";
     * jedna główna informacja na ekranie zegarka;
     * bez wyglądu, ikon i logo HUAWEI Health;
   - bramka: każdy zmieniony ekran ma zrzut "przed" i "po" w trybie jasnym i ciemnym
     w docs/screenshots/design/.

2. UI kit (entry/src/main/ets/ui/kit/, watch/src/main/ets/ui/kit/, około 1 h; wzorce ze skilli hmos-arkui)
   - ValueWithUnit;
   - MetricTile (symbol, nazwa, wartość z jednostką, mini-słupki 7 dni, stan "Off · missing evidence");
   - RingStat (DataPanel albo Gauge z animowanym wypełnieniem);
   - StatusPill;
   - SectionCard;
   - EmptyState (symbol i jedno zdanie);
   - DayStrip (7 dni jako małe pierścienie W/C/O/U).
   Watch: rozbij pages/Index.ets według hmos-arkui-mvvm-pattern (View, ViewModel, komponenty).

3. Dane demo na zegarku (45 min)
   Tryb "Demo feed", dostępny tylko przy zegarze demo i oznaczony na tarczy:
   - skryptowany strumień tętna i kroków (dzień z noszeniem, nocnym ładowaniem i jedną przerwą)
     podawany do tego samego rekordera co czujniki;
   - pakiet dnia oznacza to w polu clock (np. DEMO_X300_FEED);
   - README: wiersz w tabeli "real vs simulated".
   Efekt: tarcza i "Days from the watch" mają realne kształty zamiast zer.
   Prawdziwy czujnik dalej działa: Virtual sensor 70 → 0 → 70.

4. Układ informacji na telefonie (po I-2, razem z W-2; przed I-2 tylko Watch link)
   - Zakładki u dołu: Home | Evidence | Share.
   - Home: RingStat z HES, tier, pokrycie i pewność, siatka MetricTile, DayStrip "Watch evidence".
   - Evidence: kalendarz noszenia z personą, dni z zegarka jako karty
     (worn, charging, off, unobserved jako pasek), plakietka "Verified watch day".
   - Verification details (wejście z Evidence):
     * tu przenosisz z karty Watch link: kid, seq, chain, log synchronizacji, transport;
     * jury zobaczy to w demo, użytkownik nie ma tego na głównym ekranie.
   - Share: QRCode i "What the partner sees" (według P6 z wklejki 8).

5. Zegarek (W-3 z wklejki 7, na UI kicie)
   - na środku duże tętno z SymbolGlyph serca;
   - na obrzeżu pierścień slotów dnia (już jest, kolory z tokenów);
   - pod spodem jeden krótki stan;
   - footer co najwyżej "Demo";
   - Watch Link controls na ArcList.

Bramki:
 - 02:15: punkty 0–1 i Demo feed na emulatorze zegarka (zrzuty).
 - Po paczce: I-2 (8/P1, 8/P6, 9/S3–S4). Bramka 04:00 bez zmian.
 - Do 06:30: punkty 2 i 4 (Home, Evidence, Share) oraz 5.
 - Po 06:30 żadnych nowych funkcji. Tylko poprawki, dokumenty i oddanie.
 - Health Sim: integracja tylko, jeśli bramka 04:00 przeszła i zostaje ≥ 1 h. Inaczej
   README "Next steps".

Raport po każdym kroku: testy, zmienione pliki, zrzuty przed i po, rozbieżności.
Na koniec /raport i /backup.
```

## E. Człowiek, teraz (5 min)

1. **Pobierz `fairwear-ui.zip`** z czatu „Analiza arkusza” i rozpakuj do `C:\dev\FairWear\_incoming\fairwear-ui\`. To jest wąskie gardło całego projektu.
2. **Ogranicz liczbę sesji.** Pracują najwyżej dwie: A (rdzeń, dane i UI według D) oraz B (security z wklejki 9 albo Health Sim, nigdy obie naraz). Każda na swojej gałęzi. Merge robi jedna osoba.
3. **Emulator zegarka:** Virtual sensor → tętno 70. Bez tego zegarek nawet z kodem pokazuje „—”.
