> Kopia publiczna: brief przygotowany przez Claude (claude.ai, sesja przeglądu 4 października), do wklejenia w lokalną sesję Claude Code z DevEco Studio. Jeszcze nie uruchomiony.

# Teksty UI do zasobów (`$r('app.string.…')`)

## Kontekst

Pracujesz w repo FairWear (`presivelab/huawei`), projekt DevEco, HarmonyOS, API 24 (minimum 20). Moduły: `entry` (telefon), `watch` (zegarek), `common` (HAR, czysta logika). Przeczytaj najpierw `AGENTS.md`, `.claude/skills/fairwear-ui/SKILL.md` i `AI_WORKFLOW.md`.

Dziś żaden ekran nie używa `$r('app.string.…')`. Wszystkie teksty są literałami w plikach `.ets` albo stałymi w `entry/src/main/ets/addon/AddonTexts.ets`, `entry/src/main/ets/report/ReportTexts.ets` i `entry/src/main/ets/share/ShareTexts.ets`. `entry/src/main/resources/base/element/card_string.json` istnieje, ale karta (`entry/src/main/ets/widget/pages/FairWearCard.ets`) go nie czyta. Bez zasobów aplikacji nie da się przetłumaczyć, a celujemy też w rynek chiński.

## Cel tego kroku

Każdy tekst widoczny dla użytkownika w warstwie UI `entry`, `watch` i karty ma pochodzić z zasobów. Angielski zostaje w `resources/base/element/string.json` dokładnie w obecnym brzmieniu. Wygląd ani działanie się nie zmieniają.

## Zakres

W zakresie:

- `entry/src/main/ets/view/**`, `entry/src/main/ets/ui/**`, `entry/src/main/ets/widget/**` i `entry/src/main/ets/pages/**`;
- stałe z `AddonTexts.ets`, `ReportTexts.ets` i `ShareTexts.ets`;
- `watch/src/main/ets/pages/**` i `watch/src/main/ets/ui/**`;
- teksty `accessibilityText` i `accessibilityDescription`;
- treści toastów i dialogów.

Poza zakresem (to następny krok, nie ten):

- Zdania składane w `common`, m.in. w `report/EngineReports.ets`, `report/WhySections.ets`, `report/EvidenceCalendar.ets`, `report/Benefit.ets`, `health/HealthStatusLabel.ets`, `watchlink/LinkProbe.ets` i w komunikatach weryfikatorów (`Invalid signature`, `Accepted`…).
  - To przetestowana logika uruchamiana pod Node, która nie ma dostępu do `$r`.
  - Wypisz je w `docs/ARCHITECTURE.md` jako „faza 2: identyfikatory komunikatów + argumenty, rozwiązywane w UI”.
  - Nie zmieniaj w nich ani znaku.
- Aplikacja Health Sim (`healthsim/`).
- Tłumaczenie na chiński. Folder `zh_CN` dodajemy dopiero po decyzji zespołu i z przeglądem przez osobę, która zna język.

## Zasady

1. **Nazwy kluczy:** `ekran_element` w snake_case, np. `report_live_title`, `share_partner_verify_again`, `watch_dial_not_on_wrist`, `card_source_label`. Jeden klucz na jedno znaczenie. Te same słowa w różnych rolach dostają osobne klucze.
2. **Komponenty:** `Text($r('app.string.report_live_title'))`. Teksty z liczbą lub nazwą idą przez format w `string.json` (`%s`, `%d`) i `$r('app.string.x', arg)`. Nie składaj zdań z kawałków: cały wzorzec ma być jednym zasobem.
3. **Kod spoza `build()`** (stałe w `*Texts.ets`, toasty, `promptAction`):
   - zrób jeden mały helper w `entry/src/main/ets/ui/Strings.ets`, który zamienia `Resource` na `string` przez `resourceManager` kontekstu (`getStringSync` lub `getStringByNameSync`, z argumentami);
   - nazwę i sygnaturę API sprawdź w `hmos-arkts-knowledge-retriever` i w plikach `.d.ts` SDK, nie z pamięci;
   - na zegarku zrób to samo w `watch/src/main/ets/ui/Strings.ets`.
4. **Karta:** użyj istniejącego `card_string.json` (w karcie działa `$r`). Nic nie wypadnie, bo na karcie i tak nie ma tieru.
5. **Brzmienie:** angielski ma się zgadzać co do znaku z obecnym tekstem. Obowiązują reguły z `fairwear-ui` i `tools/check-wording.sh`: zero trafień przed i po zmianie.
6. **Zakazy:** nie zmieniaj logiki, układu, kolorów, rozmiarów ani kolejności elementów. Nie ruszaj `common`, claimu (siedem kluczy), progów ani wyników bohaterów demo.
7. **Gałąź i commity:** `feature/string-resources` od aktualnego `main`, a jeśli `fix/review-findings` nie jest jeszcze zmergowany, to od niego. Commit po każdym ekranie albo grupie ekranów. Merge do `main` robi człowiek.

## Bramki (po każdym ekranie lub grupie)

- `hvigorw assembleHap` dla `entry` i dla `watch`: BUILD SUCCESSFUL, bez nowych ostrzeżeń ArkTS w zmienionych plikach.
- `tools/lint.sh`: 0 błędów. `tools/check-wording.sh`: 0 trafień. `tools/run-logic-tests.sh common` i `watch` bez zmian.
- Screenshot ekranu przed zmianą i po niej (jasny motyw), porównany: tekst identyczny, nic się nie przesunęło. Na koniec jeden przebieg całego demo na obu emulatorach, w jasnym i ciemnym motywie, według `docs/DEMO_SCRIPT.md`.
- Na koniec dodaj `tools/check-ui-literals.sh`: grep po `entry/src/main/ets/{view,ui,widget,pages}` i `watch/src/main/ets/{pages,ui}` za `Text('`, `Text("`, `` Text(` ``, `Button('`, `accessibilityText('` i `message: '`. Ma zwracać 0 trafień i być wpisany do `README.md` obok `check-wording.sh`.

## Na koniec

- `docs/test-results.txt`: sekcja z wynikami bramek.
- `AI_WORKFLOW.md`: wiersz w dzienniku pracy (co zmieniono, co sprawdzono, czego nie sprawdzono).
- `README.md`: jedna linia, że teksty UI są w zasobach (`base` = angielski), a zdania z `common` czekają na fazę 2.
- Raport dla zespołu:
  - liczba przeniesionych tekstów na moduł;
  - lista tekstów, których nie dało się przenieść, z powodem;
  - lista zdań z `common` na fazę 2.
