> Public-safe copy of a team brief (in Polish) that was handed to a coding-agent session as its standing instruction during HackYeah 2026. Kept as written; which briefs are still in force is listed in `docs/prompts/README.md`.

# WKLEJKA: telefon według HMOS Code Workshop + zgodność z wytycznymi hackathonu (telefon i zegarek)

## Kontekst

Ta wklejka uzupełnia `WKLEJKA_ADDON_HUAWEI_HEALTH.md` i dopisek „wzorce z HMOS Code Workshop”. Część A dotyczy telefonu (`entry`). Część B obowiązuje oba moduły (`entry` i `watch`) do końca prac. Przed każdym commitem sprawdzasz zmianę z listą z części B. Na koniec każdego kroku podajesz, które punkty B są spełnione i czym to udowodniono.

Źródła:

- wytyczne hackathonu: repo `onirodeveloper/hackyeah2026-challenge`, pliki `hackathon_challenge.md` i `FAQ.md`;
- wzorzec kodu: `onirodeveloper/harmonyos_samples` (HMOS Code Workshop, Apache 2.0), moduł `products/phone`.

Nazwy API sprawdzasz w SDK albo skillem `hmos-arkts-knowledge-retriever`. Uprawnień ani konfiguracji z Code Workshop nie kopiujesz w ciemno, tylko to, czego FairWear naprawdę potrzebuje.

## Część A: telefon

### TA-1: karta FairWear na ekranie głównym (rozwinięcie AD-5)

Wzorzec: `products/phone/src/main/ets/phoneformability/PhoneFormAbility.ets`, `resources/base/profile/form_config.json`, `common/src/main/ets/widget/ActionUtils.ets`.

- `module.json5` (entry): `extensionAbilities` z `type: "form"`, `exported: false` i metadanymi `ohos.extension.form` → `$profile:form_config`.
- `form_config.json`: jedna karta 2×2, `uiSyntax: "arkts"`, `colorMode: "auto"`, `isDynamic: true`, `updateEnabled: true`. Kart na ekran blokady nie robisz: wynik oparty na danych zdrowotnych nie może być widoczny na zablokowanym telefonie.
- Treść karty: status źródła (`HUAWEI Health · DEMO`), pokrycie w % i „Wynik gotowy” albo „—”. Domyślnie karta nie pokazuje litery tieru, bo ekran główny widzą też inni. Jeśli zostanie czas, dodaj w ustawieniach przełącznik „Pokazuj wynik na karcie”, domyślnie wyłączony.
- Przepływ danych:
  - aplikacja po każdym przeliczeniu zapisuje skrót (status, pokrycie, gotowość wyniku) w `preferences`;
  - aplikacja aktualizuje zapisane karty przez `formProvider.updateForm` z `formBindingData`;
  - `onAddForm` zapisuje `formId` i zwraca bieżący skrót;
  - `onRemoveForm` usuwa `formId`.
- Dotknięcie karty: `postCardAction` z `action: 'router'`, `abilityName: 'EntryAbility'` i parametrem `fwTarget: 'dashboard'`.
- W README napisz, że emulator DevEco obsługuje widżety (tabela w README wyzwania), i dodaj zrzut karty.

### TA-2: skróty pod ikoną i jedno wejście do aplikacji

Wzorzec: `resources/base/profile/shortcuts_config.json` i metadane `ohos.ability.shortcuts` w `EntryAbility`.

- Dwa skróty, nie więcej:
  - „Pokaż kod dla ubezpieczyciela” (`fwTarget: 'share'`), czyli szybkie otwarcie ekranu QR przy okienku ubezpieczyciela;
  - „Źródło danych” (`fwTarget: 'source'`), czyli AD-3.
- `EntryAbility` czyta `want.parameters?.['fwTarget']` w `onCreate` i `onNewWant`, a jedna funkcja `routeFromWant` przełącza ekran w `pages/Index`. Z tej samej funkcji korzystają karta (TA-1) i skróty. To jest „jedno wejście” z dopisku: gospodarz mógłby otworzyć FairWear tym samym `want`.
- Nieznana albo pusta wartość `fwTarget` otwiera dashboard i nigdy nie powoduje błędu. Dopisz na to test.

### TA-3: prawdziwa ścieżka „Połącz z HUAWEI Health” (tylko dokumentacja)

Code Workshop loguje użytkownika przez Account Kit (`authentication.HuaweiIDProvider`). Prawdziwe połączenie z HUAWEI Health zaczyna się od zalogowania Huawei ID, potem Huawei pokazuje ekran autoryzacji Health Service Kit. Wymaga to `client_id` z AppGallery Connect i zatwierdzenia przez Huawei.

- Nie implementujesz Account Kit dziś w nocy.
- W `docs/ARCHITECTURE.md` opisujesz sekwencję prawdziwej ścieżki: Huawei ID → autoryzacja zakresów → odczyt → odłączenie. Obok niej opisujesz, co w demo ją zastępuje (AD-1 do AD-3).
- W stubie `HuaweiHealthSource` (krok 2B POPRAWKI) dopisz komentarz z tą sekwencją.

### TA-4: czego nie przenosić z Code Workshop

- Karty na ekran blokady i karty „live 3D”: prywatność i brak uzasadnienia.
- Intencje dla asystenta Xiaoyi (`insight_intent.json`, `@InsightIntentEntry`). Dodaj je tylko, jeśli potwierdzisz, że da się je wywołać na emulatorze. Inaczej trafiają do „Dalszych kroków” w README. Jury odejmuje punkty za integracje dodane na pokaz.
- Uprawnienia z Code Workshop (`INTERNET`, `GET_NETWORK_INFO`, `VIBRATE`, `GYROSCOPE`).

## Część B: zgodność z wytycznymi hackathonu (telefon i zegarek)

Dla każdego punktu podajesz dowód: plik, test, log albo zrzut. Wyniki zbierasz w README w sekcji „Hackathon requirements → where to verify”: tabela z kolumnami wymaganie | gdzie to sprawdzić.

### Wymagania techniczne

- **B1. API.** W głównym `build-profile.json5` sprawdź i zgłoś `runtimeOS`, `compileSdkVersion`, `compatibleSdkVersion` i `targetSdkVersion`, a potem to samo w modułach. FAQ zaleca `compatibleSdkVersion: "6.0.0(20)"` oraz kompilację i target na API 24. Jeśli dziś minimum to 24, wypisz API nowsze niż 20, których używacie bez obejścia. **Niczego nie zmieniasz bez zgody człowieka.** W README ma być zdanie, jakie jest minimum i dlaczego.
- **B2. Działa na emulatorze, nie tylko w Previewerze.** Telefon działa na emulatorze telefonu (wymaga regionu Chiny w DevEco), zegarek na emulatorze zegarka. Dowód: zrzuty w `docs/screenshots/` z obu emulatorów.
- **B3. Powtarzalne instrukcje.** README zawiera:
  - wersję DevEco Studio i SDK;
  - przełączenie regionu na Chiny (dla emulatora telefonu);
  - ręczne pobranie obrazów emulatorów w Device Manager;
  - build obu modułów;
  - instalację obu `.hap` przez `hdc install`;
  - uruchomienie;
  - testy (`tools/run-logic-tests.sh`).

  Sprawdź, czy da się to zrobić z samego README, bez pytania zespołu.

- **B4. Co najmniej jedna funkcja platformy, opisana per moduł.**
  - Telefon: HUKS (podpis), CryptoFramework, FormKit (jeśli TA-1 powstanie), Health Service Kit jako stub z opisaną prawdziwą ścieżką.
  - Zegarek: Sensor (HEART_RATE, PEDOMETER) i bateria.

  Dla każdej funkcji podaj, gdzie jest w kodzie.

- **B5. FairWear jako komponent** (`hackathon_challenge.md`, wiersze 48–50). Sekcja README odpowiada na cztery pytania: co robi, jak integruje się z platformą i z HUAWEI Health, jak go zainstalować (dwa `.hap`) i jak sprawdzić ulepszenie (scenariusz AD-4 i testy).

### Wymagane materiały

- **B6. Publiczne repo.** Dziś repo nie ma zdalnego (remote). Przed pierwszym pushem przeszukaj całą historię, nie tylko bieżące pliki, pod kątem `.p12`, `.cer`, `.p7b`, haseł, kluczy API i danych osobowych. Uzupełnij `.gitignore` o materiał podpisu. Jeśli coś takiego jest w historii, zatrzymaj się i zgłoś. Remote zakłada człowiek.
- **B7. Działające `.hap` dla telefonu i zegarka.** Build z Run/Debug podpisuje się automatycznie tylko na wasz emulator. Plik do oddania wymaga konfiguracji podpisu z konta Huawei (FAQ, sekcja „Signing”). Materiału podpisu nigdy nie commitujesz. Profil debug HarmonyOS wygasa po około 14 dniach, więc dopisz to w README. `.hap` dołącz jako GitHub Release, nie jako commit.
- **B8. Nagranie demo.** Nagrywa człowiek. Przygotuj `docs/DEMO_SCRIPT.md` w trzech częściach:
  - telefon według AD-4;
  - zegarek: tętno 70 → 0 → 70 i stan noszenia;
  - jedno zdanie o tym, czego emulator nie pokaże i jak to działa na urządzeniu.

  Zaznacz w nim, co powstało w trakcie hackathonu.

- **B9. Opis architektury.** `docs/ARCHITECTURE.md`: przepływ danych HUAWEI Health → `HealthSource` → HES → podpisany claim, osobno ścieżka zegarka, TA-3 i to, co jest DEMO.
- **B10. `AI_WORKFLOW.md`.** Dokument zawiera:
  - narzędzia: Claude Code, claude.ai, skille z repo wyzwania, `devecocli`;
  - główne prompty: te wklejki w `docs/prompts/`, bez danych osobowych, adresów e-mail i ścieżek z nazwą użytkownika;
  - przebieg pracy;
  - sposób weryfikacji: testy i sprawdzanie na emulatorze;
  - ograniczenia;
  - nieudane podejścia: kierunek „osobna aplikacja” porzucony na rzecz dodatku, mock HH zastąpiony przez `common/health/`.
- **B11. Funkcje AI w produkcie.** Sprawdź, czy w produkcie została jakakolwiek funkcja AI, np. objaśnienia z modelu językowego. Jeśli tak, zgłoś to. Wtedy trzeba ją usunąć albo opisać jako dodatkowy materiał (punkt 7 listy wymaganych materiałów). Jeśli nie, napisz w README, że HES to deterministyczne reguły, bez AI.

### Kryteria oceny

- **B12. Każde zdanie z README ma pokrycie** w kodzie, teście, logu albo zrzucie. Tabela „real vs simulated” zostaje i obejmuje oba moduły.
- **B13. Obsługa błędów jest pokazana i przetestowana:**
  - `NOT_AUTHORIZED` i `UNAVAILABLE`;
  - brakujące dane (`MISSING`, spadek pokrycia);
  - brak czujnika na urządzeniu;
  - zapasowy klucz programowy zamiast HUKS;
  - błędny lub podrobiony QR i claim (`verifyClaim`);
  - nieznany `fwTarget`.
- **B14. Higiena:**
  - tabela uprawnień per moduł z uzasadnieniem każdego uprawnienia; usuń nieużywane;
  - brak sekretów;
  - walidacja wejścia (QR, parametry `want`);
  - brak ryzykownych zależności.

  Uruchom lint z `devecocli` dla obu modułów i zapisz wynik w `docs/test-results.txt`. Repo może przejść automatyczny przegląd techniczny przed oceną jury.

- **B15. Integracje są uzasadnione, a nie dodane na pokaz.** Każda funkcja platformy w README ma jedno zdanie, po co jest użytkownikowi.
- **B16. Obszar Human-Centric Technology widać w działaniu, nie tylko w opisie:** zgoda, minimalizacja danych, odwołanie dnia i podpisany wynik zamiast surowych danych.
- **B17. Demo na emulatorze, nie makiety.** Czego emulator nie umie (prawdziwe dane z HUAWEI Health, czujnik założenia, synchronizacja zegarka z telefonem), to opisujesz, jak działa na urządzeniu. Na miejscu mentorzy mają urządzenia. W `docs/DEMO_SCRIPT.md` dopisz zadanie dla człowieka: „poprosić mentora o uruchomienie `.hap` zegarka na prawdziwym zegarku Huawei i nagrać prawdziwe tętno”.
- **B18. Historia commitów pokazuje postęp.** Nie robisz squash. Commity mają opisowe wiadomości, a gałęzie z worktree wchodzą przez merge.

## Kolejność i cięcia

- **Teraz, równolegle z resztą:** B1 (tylko raport), B6 (skan historii), B11, B14 (tabela uprawnień) i TA-2.
- **Musi być przed oddaniem:** B2, B3, B5, B7, B8, B9, B10, B12, B13 i tabela „Hackathon requirements → where to verify”.
- **Powinno być:** TA-1 i TA-3 w dokumentacji.
- **Jeśli zostanie czas:** przełącznik tieru na karcie (TA-1) i B17 z prawdziwym zegarkiem.

Po każdym kroku podaj wynik testów, listę zmienionych plików, stan punktów B (spełniony / brak / wymaga człowieka) i wszystko, co odbiega od tej wklejki. Na koniec sesji zrób `/raport` i `/backup`.
