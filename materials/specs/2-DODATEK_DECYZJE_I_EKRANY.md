# WKLEJKA: FairWear jako dodatek do HUAWEI Health — decyzje i ekrany dodatku

## Odpowiedzi na Twoje 4 pytania

1. **Kto robi:** ta sesja. Załóż osobny worktree z gałęzią `feature/health-addon` od aktualnego `main`. Druga sesja zostaje na `main`, a merge robi człowiek.
2. **Kolejność:**
   - najpierw warstwa `common/health/` z `WKLEJKA_POPRAWKA_HUAWEI_HEALTH.md` (krok 1 i stub z kroku 2B);
   - potem ekrany dodatku z tej wklejki (AD-1 do AD-5);
   - na końcu zegarek (AD-6).

   Kroków HH-1 do HH-4 nie robisz jako osobnej warstwy.
3. **Nazwy:** `common/health/` oraz `HealthSource`, `SyntheticHealthSource` i `HealthStatus`. Tam, gdzie `WKLEJKA_MOCKUP_HUAWEI_HEALTH.md` i `WKLEJKA_ZEGAREK_HH.md` różnią się od POPRAWKI, wygrywa POPRAWKA. Z ZW bierzesz tylko regułę „tętno ≤ 0 = brak odczytu” i wzorzec subskrypcji czujników.
4. **Tier:** czekasz na HES-Lite. Wszystko inne robisz teraz. Tam, gdzie w UI ma być tier, wyświetlasz „—” i status „HES-Lite niepodłączony”. HES-Lite i `HesPersonas` są w `fairwear-ui.zip`. Człowiek rozpakuje go do `C:\dev\FairWear\_incoming\fairwear-ui\`. Gdy to zrobi, wykonaj punkt 1 z kroku 0 POPRAWKI, a potem części kroku 1 zależne od HES (mapper, `SyntheticHealthSource`).

## Czym jest dodatek

FairWear nie jest osobnym produktem z własnymi danymi. U Huawei dodatek działa tak:

- partner ma swoją aplikację;
- użytkownik łączy ją z HUAWEI Health („Połącz z HUAWEI Health”);
- Huawei pokazuje własny ekran zgody z listą zakresów;
- dane płyną z HUAWEI Health do aplikacji partnera;
- połączenie można zerwać w aplikacji albo w ustawieniach prywatności HUAWEI Health.

Tak działają np. Keep i Codoon. Partner nie ma własnych ekranów wewnątrz HUAWEI Health, bo to wymagałoby umowy z Huawei. Ten temat należy do pitchu, nie do kodu.

W repo moduł `entry` jest nośnikiem dodatku. Każdy ekran ma pokazywać, że dane przychodzą z HUAWEI Health, a FairWear dokłada tylko wynik i podpisany claim.

## Zasady

- Nie odtwarzasz ekranów HUAWEI Health ani ekranu zgody czy logowania Huawei ID. W miejscu ekranu zgody Huawei stoi neutralna plansza „DEMO: tutaj Huawei wyświetla swój ekran zgody”.
- W UI piszemy nazwę „HUAWEI Health”, bo tego Huawei wymaga od partnerów. Logo Huawei Health dodajesz tylko z oficjalnego pakietu marki, jeśli zespół go ma. Inaczej zostaje sam tekst. Logo nie rysujesz.
- Lista zakazanych sformułowań z POPRAWKI obowiązuje. Dopisz do niej: „certyfikowany”, „Works with HUAWEI Health” i „wtyczka HUAWEI Health”.
- Styl ma być natywny dla HarmonyOS. Używasz komponentów ArkUI i zasobów systemowych (`$r('sys.color.…')`, `$r('sys.float.…')`) zamiast własnych kolorów i rozmiarów, tam gdzie się da. Dzięki temu dodatek wygląda jak część systemu i działa w trybie ciemnym. Nazwy zasobów sprawdzasz w SDK.
- Status źródła jest widoczny na każdym ekranie z danymi: `DEMO`, `NOT_AUTHORIZED`, `UNAVAILABLE` albo `CONNECTED`.

## AD-1: wejście „Połącz z HUAWEI Health” (telefon)

- Na ekranie powitalnym i w ustawieniach jest przycisk „Połącz z HUAWEI Health”. Pod nim jedno zdanie: co czytamy, czego nie czytamy i co wychodzi z telefonu (tylko podpisany wynik A/B/C).
- Przed połączeniem status to `NOT_AUTHORIZED`, a tier jest ukryty.

## AD-2: zgoda w dwóch krokach

1. Plansza DEMO zamiast ekranu Huawei. Pokazuje zakresy dokładnie tych typów, których używa HES, według listy z kroku 0 POPRAWKI. Ma dwa przyciski: „Symuluj zgodę” i „Symuluj odmowę”.
2. Nasz osobny ekran zgody RODO art. 9 (już w POPRAWCE). Pozwala wyłączyć pojedyncze zakresy. Wyłączony zakres daje `MISSING` w HES i niższe pokrycie.

Przy odmowie status zostaje `NOT_AUTHORIZED`, a ekran mówi, czego bez zgody nie policzymy.

## AD-3: status i odłączenie

- Karta „Źródło danych” pokazuje `HUAWEI Health · DEMO · ostatnia synchronizacja <stała godzina z SyntheticHealthSource>`.
- Przycisk „Odłącz HUAWEI Health” ustawia `NOT_AUTHORIZED`, czyści dane w pamięci i ukrywa tier. Przycisk „Połącz ponownie” wraca do AD-2. Huawei wymaga takiego wejścia od każdej zintegrowanej aplikacji.
- Pod przyciskiem tekst: „Połączenie możesz też zerwać w ustawieniach prywatności HUAWEI Health.” Nie podajesz dokładnej ścieżki menu, bo różni się między wersjami.

## AD-4: scenariusz demo zgodny z weryfikacją Huawei

Huawei weryfikuje integrację na nagraniu. Musi na nim być: wejście do pierwszej autoryzacji, pełna lista uprawnień zgodna z wnioskiem, działanie po autoryzacji, odłączenie, ponowna prośba o zgodę i działanie po niej. Nasze nagranie demo idzie tą samą ścieżką:

AD-1 → AD-2 (zgoda) → wynik → AD-3 (odłącz) → AD-2 (ponowna zgoda) → wynik.

Wpisz ten scenariusz do skryptu demo w `docs/` i oznacz go jako „ścieżka zgodna z wymaganiami weryfikacji Huawei, dane DEMO”.

## AD-5: karta FairWear na ekranie głównym telefonu (jeśli zostanie czas)

Widżet (karta usługi) pokazuje: HES (albo „—”), pokrycie w % i `HUAWEI Health · DEMO`. Sprawdź w SDK `FormExtensionAbility` i to, czy emulator telefonu wyświetla widżety.

## AD-6: zegarek

- Rola zegarka zgodnie z POPRAWKĄ: tętno na żywo i stan noszenia. Te dane nie wchodzą do HES.
- Stronę „Hello World” zastępujesz ekranem z trzema wartościami: tętno na żywo, kroki dziś i stan noszenia (noszony / zdjęty / brak danych). Na dole mały podpis „FairWear · dodatek do HUAWEI Health · DEMO”.
- Czujniki obsługujesz według wzorca z `HealthDemo` (HEART_RATE i PEDOMETER, oba uprawnienia).
- Emulator przy tętnie 0 wysyła zdarzenia z wartością 0. Każdy odczyt ≤ 0 traktujesz więc jako brak odczytu. Stan „zdjęty” to brak poprawnego odczytu tętna przez N sekund. N jest parametrem, w demo 10 s.
- Logikę stanu noszenia (`LiveWearState`) piszesz w `common`, bez importu czujników, żeby dało się ją testować.
- Sprawdź przejście 70 → 0 → 70 w panelu emulatora i opisz wynik w README. Na prawdziwym zegarku można dodać czujnik założenia, ale emulator go nie ma.
- Jeśli zostanie czas, dodaj widżet zegarka z tymi samymi trzema wartościami.
- Emulatory nie synchronizują zegarka z telefonem, więc nie udawaj synchronizacji.

## Testy (Node, `tools/run-logic-tests.sh`)

1. Przejścia `HealthStatus`: `NOT_AUTHORIZED` → zgoda → `DEMO` → odłączenie → `NOT_AUTHORIZED`. Odmowa zostawia `NOT_AUTHORIZED`. Po odłączeniu źródło zwraca puste listy.
2. Zakres wyłączony w zgodzie RODO: odpowiednia metoda `HealthSource` zwraca pustą listę albo `-1`, nigdy zero.
3. `LiveWearState`: strumień 70, 70, 0 przez N s, 70 daje kolejno noszony → zdjęty → noszony. Odczyt ≤ 0 nigdy nie trafia do tętna.
4. Teksty: grep zakazanych sformułowań w `entry`, `watch`, `common`, `README*` i `docs/` daje 0 trafień.

Wyniki zapisujesz do `docs/test-results.txt`.

## Kolejność i cięcia

- **Musi być:**
  - worktree i nazwy według odpowiedzi 1–4;
  - z kroku 1 POPRAWKI to, co nie zależy od HES-Lite (`HealthRecords`, `HealthStatus`, `HealthSource`), plus stub z kroku 2B;
  - AD-1, AD-2, AD-3;
  - AD-6 bez widżetu;
  - testy 1–4.
- **Po rozpakowaniu `fairwear-ui`:** HES-Lite, `SyntheticHealthSource`, mapper i tier na ekranach.
- **Powinno być:** AD-4 w skrypcie demo.
- **Jeśli zostanie czas:** AD-5 i widżet zegarka.

Po każdym kroku podaj wynik testów, listę zmienionych plików i wszystko, co odbiega od tej wklejki. Na koniec sesji zrób `/raport` i `/backup`.DOPISEK — wzorce z HMOS Code Workshop (github.com/onirodeveloper/harmonyos_samples, Apache 2.0)

1. README/pitch: sekcja „FairWear jako komponent” według hackathon_challenge.md (wiersze 48–50):
   co robi, jak integruje się z platformą (HUAWEI Health przez Health Service Kit, dziś DEMO),
   jak zainstalować (.hap telefon + zegarek), jak sprawdzić ulepszenie (scenariusz AD-4).
2. (Powinno być) Dane demo HUAWEI Health jak MockRequest z Code Workshop:
   rekordy HealthRecords w entry/src/main/resources/rawfile/mockdata/huawei-health/<persona>.json,
   wygenerowane z HesPersonas skryptem w tools/, czytane przez resourceManager.getRawFileContentSync
   w SyntheticHealthSource. Tylko na ekranach pokazujących dane z HUAWEI Health. HES dalej z HesPersonas.
3. AD-5: form_config.json i FormExtensionAbility wzoruj na products/phone z Code Workshop (karta 2×2, colorMode auto).
4. Jedno wejście do FairWear (jedna ability/strona startowa), żeby gospodarz mógł je uruchomić jak
   Code Workshop uruchamia moduły (startAbility z abilityName). Nie przenoś teraz kodu do osobnego modułu.
   Opisz ten mechanizm w docs/ARCHITECTURE.md jako drogę do wbudowania w HUAWEI Health (wymaga Huawei).
5. Skopiowane fragmenty: zachowaj nagłówek Apache 2.0 i dopisz źródło do AI_WORKFLOW.md.
