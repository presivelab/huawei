---
title: "RAPORT fairwear: watch-link-tour-g3"
subtitle: "2026-10-04T04:27:50+0200 · Tzpe0"
lang: pl-PL
---

## Maszyna

- System: Microsoft Windows 11 Pro 10.0.26100.9550, host Tzpe0
- Projekt: fairwear
- Konfig: .nadzor.yml
- Repo: `C:\dev\FairWear-tour`
- Stamp: ef36a9a (git describe)
- Data: 2026-10-04T04:27:50+0200
- Folder raportów: `C:\Users\robac\nadzor\fairwear` (dysk lokalny)
- pandoc: pandoc 3.11

## Git

- Gałąź: `feature/watch-link-tour`
- HEAD: `ef36a9a`
- Zmienione i nowe pliki: 0

git status --short:

```
```

git log --oneline -5:

```
ef36a9a G3 record, agent 3: watch to phone on the merged build, fifth demo-feed day verified
e991ad1 G2 record: merge results in test-results, work log rows for screens, watch tour, share and the merge, current numbers in REQUIREMENTS_CHECK
1ec3f81 G2: merge feature/share-partner (Share with the signed claim as a QR code, partner view, ledger) into feature/engine-reports
9e282ce G2: merge feature/watch-link-tour (watch to phone demo run, tour screenshots, test record) into feature/engine-reports
5630173 G2: merge feature/phone-screens (Evidence calendar with appeal, Why this tier, Live card with demo controls) into feature/engine-reports
```

## Gate'y

nie uruchomiono

- pominięto: brak bramek

## Decyzje

- D1: G3 zrobione na prośbę agenta 1: `feature/watch-link-tour` przesunięta fast-forwardem na scalone `e991ad1`, oba HAP-y zbudowane i wgrane z tej gałęzi, przepływ zegarek → telefon puszczony jeszcze raz. Wynik: `ef36a9a` (wpis w `docs/test-results.txt` + jeden zrzut, bez zmian w kodzie), common 362/362, watch 6/6. Poprawki nie były potrzebne.
- D2: Piąty dzień demo (#5, 8.10) nagrany na istniejącym łańcuchu, bez nowego parowania. (Cztery dni z G2 miały zostać na telefonie do pokazu.) Telefon: „All 5 days verified".
- D3: `--tamper` i `--drop` nie były powtarzane na G3. (Przeszły na G2 na tym samym kodzie zegarka i weryfikatora; G3 to „fixes only".)
- D4: Po instalacji na zegarku na pierwszym planie była aplikacja `com.fairwear.healthdemo` (prototyp, uruchomiony ok. 02:00), nie FairWear. Uruchomiłem FairWear ponownie przez `aa start`; prototypu nie zamykałem ani nie odinstalowałem. (Nie wiem, czyja to aplikacja w tej chwili; FairWear nagrywa tylko, gdy jest otwarty.)
- D5: Nic nie wypchnąłem. Bundle: `D:\backup-git\FairWear\FairWear-2026-10-04-0427-all.bundle` (zweryfikowany).

## Pytania do nadzoru

- P1: Odinstalować `com.fairwear.healthdemo` i `com.fairwear.sensorprobe` z emulatora zegarka przed pokazem, żeby nie wskoczyły na pierwszy plan? | domyślnie: zostają; przed pokazem sprawdzić tarczę FairWear i w razie czego uruchomić aplikację ponownie.
- P2: Dzień 8.10 ma „Off wrist 3 h 10 min" (o 20 min więcej niż pozostałe, bo między przebiegami zegarek nagrywał na zwykłym zegarze z tętnem 0). Zostawić go na liście do pokazu? | domyślnie: zostaje; to nie jest przerwa (poniżej 120 min) i jest opisane w test-results.

