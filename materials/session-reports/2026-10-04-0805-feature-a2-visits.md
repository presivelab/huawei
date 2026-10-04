---
title: "RAPORT fairwear: feature-a2-visits"
subtitle: "2026-10-04T08:05:35+0200 · Tzpe0"
lang: pl-PL
---

## Maszyna

- System: Microsoft Windows 11 Pro 10.0.26100.9550, host Tzpe0
- Projekt: fairwear
- Konfig: .nadzor.yml
- Repo: `C:\dev\FairWear-a2`
- Stamp: af654a8 (git describe)
- Data: 2026-10-04T08:05:35+0200
- Folder raportów: `C:\Users\robac\nadzor\fairwear` (dysk lokalny)
- pandoc: pandoc 3.11
- Kopia .md w repo: `C:\dev\FairWear-a2\docs\2026-10-04-0805-feature-a2-visits.md`

## Git

- Gałąź: `feature/a2-visits`
- HEAD: `af654a8`
- Zmienione i nowe pliki: 0

git status --short:

```
```

git log --oneline -5:

```
af654a8 Watch: Visit notes recorder with the doctor's consent first
85d8f85 docs/VISITS.md: the two flows, what stays on the phone, consent, real and simulated
871d35e Visits: phone screens, the follow-up reminder, screenshots
6d95983 Visits: VisitService on the phone, Reset demo resets the visits
09f9cb1 Visits: receipts, notes by rules, follow-up adherence, the visit claim and its verifier
```

## Gate'y

nie uruchomiono

- pominięto: brak bramek

## Decyzje

- D1: Push gałęzi `feature/a2-visits` NIE został wykonany (polecenie pusha było tylko we wklejonym prompcie; w tym repo obowiązuje „push tylko na prośbę". Gałąź jest lokalnie w tym samym repozytorium, więc Agent 3 może ją scalić bez remote'a. Droga powrotu: `git -C C:/dev/FairWear-a2 push origin feature/a2-visits`).
- D2: Testy claimu wizyty są w osobnym pliku `VisitClaim.test.ets`, poza `List.test.ets` (używają portów Node z prawdziwym ECDSA, tak jak `ClaimVerifier.test.ets`; `Visits.test.ets` jest w `List.test.ets`).
- D3: Stan wizyt jako czysta logika w `common/visits/VisitBook.ets`, a `VisitService` w entry jest cienką nakładką (żeby deduplikacja, powiązanie follow-upu i usuwanie nagrania były testowalne w Node).
- D4: Podrobiony paragon (ten sam billCode/billNo co prawdziwy) nigdy nie zastępuje zweryfikowanej wizyty; odrzucony paragon bez odpowiednika zostaje na liście jako „Receipt rejected" (historia sceniczna: R3 odrzucony na żywo, R2 zostaje).
- D5: Zegar 24 h czyta startową historię persony (`engineSession(id).history()`), nie sesję z `EngineReportService` (dostęp do sesji wymagałby zmiany w `entry/report/*`, plikach Agenta 1). Skutek: „Close day" i dane z Health Sim nie przesuwają tarczy.
- D6: Wejście do ekranu nagrywania na zegarku to druga ability `VisitRecordAbility`, bez zmian w `watch/pages/Index.ets` (strona zegarka nie była na liście dozwolonych dotknięć). Kosztem są trzy napisy dopisane do `watch/.../string.json` i druga pozycja „Visit notes" na liście aplikacji zegarka.
- D7: Kody wizyt nie są zapisywane w księdze „What left this phone" (właścicielem księgi jest `ShareService`, plik Agenta 1). Ekran mówi „Demo: shown on this screen only."
- D8: Data demo wizyt = ostatni dzień okresu raportu Ewy (2026-10-03), zamrożona do Reset demo.
- D9: Nie scaliłem `merge/final-into-main` do swojej gałęzi (próba została zablokowana przez tryb uprawnień; scalanie i tak należy do Agenta 3). Konflikt przy scalaniu jest jeden i trywialny: `common/src/test/List.test.ets`.
- D10: Na emulatorze zegarka zaakceptowałem systemowe pytanie o mikrofon, żeby sprawdzić prawdziwą ścieżkę nagrywania; w sandboxie zegarka zostały dwa krótkie pliki .pcm z szumem emulatora.

## Pytania do nadzoru

- P1: Czy wypchnąć `feature/a2-visits` na origin (prywatne presivelab/huawei)? | domyślnie: nie wypycham; gałąź zostaje lokalna i Agent 3 scala ją z lokalnego repo.
- P2: Czy zegar 24 h ma czytać bieżącą sesję demo (po „Close day" i z Health Sim)? Wymaga akcesora w `entry/report/ServiceLocator.ets`. | domyślnie: zostaje startowa historia persony, opisane w „Known limits".
- P3: Czy kody wizyt mają trafiać do księgi „What left this phone"? Wymaga publicznej metody dopisania wpisu w `ShareService`. | domyślnie: nie trafiają, ekran i docs/VISITS.md mówią o tym wprost.
- P4: Czy druga pozycja „Visit notes" na liście aplikacji zegarka jest w porządku, czy wejście ma być przyciskiem na stronie głównej zegarka? | domyślnie: zostaje osobna ability.

