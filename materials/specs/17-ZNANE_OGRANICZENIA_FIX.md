# WKLEJKA 17 — Znane ograniczenia: tarcza 24h z sesji, kody wizyt w „What left this phone”, sprawdzenie na emulatorze

> Wklej całość do **nowej** sesji Claude Code w repo FairWear (`C:\dev\FairWear`). To polecenie do wykonania od razu, nie raport.
> **Twardy termin: 09:40** — commity + handoff. Oddanie projektu 10:30; o 09:40 Twoją gałąź merguje integrator (wklejka 16).

---

## 0. Zasady

1. **Worktree i gałąź (zrób najpierw):**
   ```
   git -C C:/dev/FairWear worktree add C:/dev/FairWear-limits -b fix/known-limits 9a582b6
   cd C:/dev/FairWear-limits && ohpm install
   ```
   `9a582b6` = `merge/final-into-main` (A1 zgoda + A2 tarcza/Visits + A3 docs). Przed pierwszą edycją: `git branch --show-current` → `fix/known-limits`.
2. **Równolegle pracują inni agenci** w `FairWear-main` (integrator), `FairWear-vnext2` (HES vNext), `FairWear-strings`. Nie edytuj ich worktree. Agent w `FairWear-vnext` jest zatrzymany — nie bierz stamtąd niczego.
3. **Nie ruszasz:** `common/src/main/ets/hes/*` (silnik HES zmienia inny agent), `common/src/main/ets/claim/*` poza **dopisaniem** jednej funkcji w `ShareFlow.ets` (pkt L2), `TierClaim`, `ProofSigner`/`CryptoUtil`/kolejności weryfikacji, reguł noszenia, danych person, Watch Link, UI Health Sim. W `ReportView.ets` nic (inny agent dodaje tam przełącznik profilu).
4. Nowe metody w interfejsach dopisuj **na końcu** (łatwiejszy merge). Kod, komentarze, UI i docs po angielsku. Bez "AI", "predicts", "validated", "risk", "healthy/unhealthy".
5. Commit po każdym punkcie. **Nie pushuj, nie merguj** — integrator weźmie gałąź lokalnie.
6. Po każdym punkcie zielone: `tools/run-logic-tests.sh common`, `tools/run-logic-tests.sh watch`, `tools/check-wording.sh`; po zmianach ArkTS `tools/lint.sh` (0 błędów) i build `entry` (`unset ELECTRON_RUN_AS_NODE` przed `hvigorw`, inaczej pada na „Cannot create a string longer than…”).
7. Emulator tylko z lockiem: utwórz `C:\dev\_emu-phone.lock` z treścią `A17 <godzina>`, max 10 min, potem usuń. Jeśli lock istnieje — czekaj.

---

## L1 (P0) — Tarcza 24h czyta bieżącą sesję, nie startową historię

**Teraz:** `entry/src/main/ets/view/DayDialCard.ets` → `newestDay()` robi `engineSession(personaId).history()` — nowa sesja ze startową historią persony. „Close the day”, dane z Health Sim i wyłączone zgody nie ruszają tarczy (opis w `docs/VISITS.md:34-35`).

**Zrób:**
- `entry/src/main/ets/report/ReportService.ets` — na końcu interfejsu `ReportService`:
  ```ts
  /** The completed days of the persona's session as it stands now (closed days, Health Sim data and consent included), oldest first. */
  dayHistory(id: string): HesDay[];
  ```
- `EngineReportService` → `return this.session(<rozwiązane id jak w report()>).history();` — ta sama sesja co `report()` (z `engineSessionFrom(person, scopes)`, gdy są dane z Health Sim).
- `PreviewReportService` (w tym samym pliku co interfejs) → `engineSession(id).history()` (jak dotąd).
- `ServiceLocator.ets` → `selectedDayHistory()` albo użyj `reportService().dayHistory(id)` — zgodnie ze stylem pliku.
- `DayDialCard.ets` → `newestDay()` bierze dni z `reportService().dayHistory(personaId)`; dodaj `@StorageProp(KEY_REPORT_REVISION) @Watch('reload') reportRevision: number = 0;`, żeby „Close the day”, „Reset demo” i podpięcie Health Sim przerysowały tarczę.
- Docs: usuń limit z `docs/VISITS.md` (linie 34–35) i z README „Known limits”, jeśli tam jest; jedno zdanie: „The dial shows the newest completed day of the session the score uses.”

**Sprawdź na emulatorze (lock):** Ania → data pod tarczą = ostatni dzień historii; „Close the day” ×1 → data przesuwa się o dzień; „Reset demo” → wraca. Zrzut `docs/screenshots/final/a7-dial-after-close-light.jpeg`.

Commit: `Day dial: the newest day of the session the score uses (Close the day and Health Sim move it)`.

---

## L2 (P0) — Kody wizyt w „What left this phone”

**Teraz:** `VisitSharePage.ets` pokazuje kod wizyty i tekst `SHARE_NOT_IN_LEDGER` („Demo: shown on this screen only.”); księga (`ShareService`, plik `share/ledger.json`) zna tylko kody tieru.

**Zrób:**
- `common/src/main/ets/claim/ShareFlow.ets` — **dopisz** obok `claimLedgerEntry` (nie zmieniaj jej):
  ```ts
  export const LEDGER_KIND_VISIT: string = 'VISIT';
  export function visitLedgerEntry(token: string, nowMs: number): LedgerEntry  // kind VISIT, payload = token, bytes = utf8Encode(token).length
  ```
  `destination`: istniejąca stała partnera albo nowa `LEDGER_DESTINATION_VISIT = 'Insurer (visit proof)'` — wybierz to, co pasuje do tekstów na ekranie Share. Eksport w `common/Index.ets` (dopisz na końcu bloku claim). Komentarz w `model/types.ets` przy `kind`: `'CLAIM' | 'VISIT'`.
- `entry/src/main/ets/share/ShareService.ets` — `recordVisitCode(token: string): void`: wpis do księgi **przed** pokazaniem kodu, zapis pliku, podbicie `KEY_SHARE_REVISION`. Idempotentnie: ten sam token drugi raz nie dopisuje linii (jedna wizyta = jedna linia, jak przy kodach tieru).
- `VisitSharePage.ets` — wołaj `ShareService.shared().recordVisitCode(token)` zanim pokażesz QR (zasada: „Every code that is shown is written to the ledger first”). Usuń tekst i stałą `SHARE_NOT_IN_LEDGER`.
- `LedgerPage.ets` — dla `kind === 'VISIT'` zamiast `claimText(...)` pokaż `Visit proof · <data wizyty z claimu wizyty>` (dekoder wizyty już jest w `common/visits`); nowe stałe tekstów w `ShareTexts.ets`.
- „Reset demo” **nie** czyści księgi (to zapis tego, co wyszło z telefonu) — tak jak dla kodów tieru.
- Testy (`common`, dopisz do istniejącego pliku testów ShareFlow albo nowy wpisany w `List.test.ets`): `visitLedgerEntry` → kind `VISIT`, payload = token, bytes = długość UTF-8; `claimLedgerEntry` bez zmian.
- Docs: `docs/VISITS.md:129` → „visit codes are written to the ledger before they are shown”; README, jeśli wspomina limit.

**Emulator (lock):** Ewa → Visits → wizyta → Share → wróć → Share → „What left this phone”: linia wizyty z bajtami, kod tieru nadal osobną linią. Zrzut `a7-ledger-visit-light.jpeg`.

Commit: `Visits: a visit code is written to "What left this phone" before it is shown`.

---

## L3 (P1) — Sprawdzenie na emulatorze: jednostki i przypomnienie

- **Jednostki (F5):** Why / Report persony z wierszami HRR i VO₂max → „1 workout” / „N workouts”, „estimates”. Zrzut `a7-units-light.jpeg`. Jeśli coś źle — popraw w `entry/src/main/ets/report/ReportTexts.ets` (`countUnit`).
- **Przypomnienie (B5):** przycisk jest tylko, gdy follow-up jeszcze się nie odbył (u Ewy się odbył). Poszukaj w demo drogi do wizyty z follow-upem w przyszłości (`DemoVisits.followUpOf`, `VisitBook`, `NotesExtractor`). Jeśli jest — kliknij, zrzut `a7-reminder-light.jpeg`. **Jeśli nie ma bez dopisywania nowych danych demo — nie dopisuj**: dodaj test `reminderMoment` (data w przyszłości → 09:00 tego dnia; przeszła / zła → brak) i zostaw w docs „Follow-up reminder: checked by a logic test, not run on the emulator”.
- Wpis do `docs/test-results.txt` (sekcja „A17 known limits”, godzina, co sprawdzone, czego nie).

Commit: `Emulator check: count units and the follow-up reminder`.

**Nie robisz:** Health Service Kit (dostęp do danych musi przyznać Huawei) ani Wear Engine (rejestracja w AGC, podpisana aplikacja, prawdziwe sparowane urządzenia) — przed 10:30 niewykonalne, zostają w „Known limits / real vs simulated” tak jak są.

---

## Cięcia (pierwsze wylatuje)

L3 przypomnienie → L3 jednostki → zrzuty L2 → zrzuty L1. **Nie wolno ciąć:** testów, buildu `entry`, handoffu.

## Handoff (do 09:40) — `C:\dev\_handoff\a17.md`, po polsku, krótko

Gałąź + HEAD (pełny SHA), tabela commitów, testy przed/po (`common`, `watch`, HealthSimCopies), lint, build, co zrobione / wycięte z powodem, **pliki wspólne z innymi gałęziami** (`ReportService.ets`, `ServiceLocator.ets`, `ShareService.ets`, `common/Index.ets`, `List.test.ets`) i jak je scalić. `git status` czysty.
