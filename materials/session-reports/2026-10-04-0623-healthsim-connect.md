---
title: "RAPORT fairwear: healthsim-connect"
subtitle: "2026-10-04T06:23:05+0200 · Tzpe0"
lang: pl-PL
---

## Maszyna

- System: Microsoft Windows 11 Pro 10.0.26100.9550, host Tzpe0
- Projekt: fairwear
- Konfig: .nadzor.yml
- Repo: `C:\dev\FairWear-share`
- Stamp: 10ae04d (git describe)
- Data: 2026-10-04T06:23:05+0200
- Folder raportów: `C:\Users\robac\nadzor\fairwear` (dysk lokalny)
- pandoc: pandoc 3.11
- Kopia .md w repo: `C:\dev\FairWear-share\docs\2026-10-04-0623-healthsim-connect.md`

## Git

- Gałąź: `feature/healthsim-connect`
- HEAD: `10ae04d`
- Zmienione i nowe pliki: 2

git status --short:

```
?? docs/2026-10-04-0352-share-partner.md
?? docs/2026-10-04-0435-share-partner-g3.md
```

git log --oneline -5:

```
10ae04d Health Sim connect: test record and three screenshots (consent in Health Sim, Report on its data, fallback without it)
51bbe09 C2: a way out while Health Sim does not answer - the system's own question about opening another app reports nothing back on Cancel, so the waiting page offers Ask again and the built-in demo data; a late or abandoned answer is ignored
ff8d817 Merge branch 'feature/engine-reports' into feature/healthsim-connect
0f17cae Watch: the long button label fits (less side padding); fallback without Health Sim checked on the wearable emulator
0eb6263 C2: consent through Health Sim - Connect asks Health Sim, its data waits for FairWear's own consent, then the reports use it with the switched-off types removed; refusal is Not connected; without Health Sim the built-in demo placeholder is shown as before, with a note; Disconnect forgets the Health Sim data; source line and explanation name Health Sim while its data is in use
```

## Gate'y

nie uruchomiono

- pominięto: brak bramek

## Decyzje

- D1: Runda 3 (Health Sim connect) wykonana na nowej gałęzi `feature/healthsim-connect` w `C:\dev\FairWear-share`: C1 klient `HealthSimClient.ets` (b7a7945), C2 przepływ zgody (0eb6263, 51bbe09), zapis testów i trzy zrzuty (10ae04d). Bez pusha, scalanie należy do agenta 1.
- D2: Pytanie do Health Sim wychodzi ze strony „Connect HUAWEI Health” w chwili jej otwarcia, a nie z przycisku. Powód: przycisk Connect jest w dwóch miejscach (Welcome i karta źródła w Settings), a karta źródła (`SourceParts.ets`) nie jest na liście moich plików; strona zgody jest wspólna dla obu wejść.
- D3: Klient ma dwie drogi: start po nazwie (kontrakt 1) i, tylko po błędzie 16000018, deep link `healthsim://authorize`. Na emulatorze (API 24) start po nazwie działa, więc druga droga nie była użyta. Zostawiłem ją, bo dokumentacja Ability Kit opisuje 16000018 jako zakaz przekierowania do cudzej aplikacji dla API > 11.
- D4: `clearHealthSim()` wołam także na ścieżce awaryjnej przy „Agree and continue”, a nie tylko przy Disconnect. Powód: baza przywraca `fwhs1.json` po restarcie aplikacji, więc bez tego raporty z Health Sim mogłyby zostać pod etykietą „HUAWEI Health · Demo data”.
- D5: System sam pyta „Allow FairWear to open Health Sim?” od drugiego przejścia. Po „Cancel” nie zwraca aplikacji niczego, więc dodałem na stronie oczekiwania przyciski „Ask Health Sim again” i „Continue with built-in demo data”; spóźniona odpowiedź jest ignorowana.
- D6: Ścieżki „bez Health Sim” nie testowałem przez odinstalowanie Health Sim (emulator jest wspólny, to aplikacja agenta 2), tylko jednorazowym HAP-em z nazwą pakietu, której nie ma (dwie stałe zmienione, niezacommitowane). Wynik: błąd 16000001 → placeholder DEMO z dopiskiem → Report jak dotąd.
- D7: Pigułka i karta źródła biorą etykietę z `reportSourceLabel()` przez `sourceLine()` w `AddonTexts.ets`; zdanie objaśnienia: „Health Sim stands in for HUAWEI Health on this emulator.” `check-wording` = 0.
- D8: `/qa-gate` pominięte jak poprzednio (bramka stron WWW). Bramki tej rundy: common 380/380, watch 6/6, build entry, lint 0 błędów, wording 0, przejście na emulatorze.

## Pytania do nadzoru

- P1: W skrypcie demo trzeba uprzedzić o systemowym pytaniu „Allow FairWear to open Health Sim?” (pojawia się od drugiego przejścia między aplikacjami). | domyślnie: przekazałem to agentowi 1 do `docs/DEMO_SCRIPT.md`; sam skryptu nie zmieniam (plik agenta 1).
- P2: Runda 2 („Unknown key” na ekranie partnera) została odłożona wklejką. | domyślnie: nie wracam do niej bez polecenia.
- P3: Tryb ciemny zmienionej strony zgody i przejście pozostałych pięciu person na danych z Health Sim nie były sprawdzane. | domyślnie: zostają jako „not run” w `docs/test-results.txt`; agent 1 przechodzi całość przy G2.

