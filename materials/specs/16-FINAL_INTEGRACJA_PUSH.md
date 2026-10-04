# WKLEJKA 16 — Finał: najnowszy HES + poprawki bezpieczeństwa + znane ograniczenia → 4 HAP-y → push do prywatnego repo

> Wklej całość do **nowej** sesji Claude Code w `C:\dev\FairWear-main`. To polecenie do wykonania od razu, nie raport.
> **Link do wideo demo:** `<WKLEJ TUTAJ URL — albo zostaw puste>`
> **Terminy:** push do 10:15, oddanie 10:30. Fazy mają godziny — pilnuj ich, a gdy nie zdążasz, tnij wg §8.

---

## 0. Zasady

1. Pracujesz w `C:\dev\FairWear-main`, gałąź **`merge/final-into-main`** (`git branch --show-current` przed pierwszą edycją; start `9a582b6`, czysty `git status`). Najpierw `git fetch origin`.
2. **Co wchodzi do finału (tylko to):**
   | Gałąź | Co | Skąd |
   |---|---|---|
   | `origin/fix/review-findings` (8e71941) | podpisane ACK w Watch Link, `kid` partnera, sen ~18:00, przerwa 2 h (S-17), dekoder Health Sim, martwy kod | origin |
   | `fix/known-limits` | tarcza 24h z sesji, kody wizyt w księdze, sprawdzenie jednostek/przypomnienia (wklejka 17) | lokalnie, worktree `C:\dev\FairWear-limits` |
   | `feature/hes-vnext-fix` | **najnowszy HES** — vNext z profilami (wklejka 14: exact coverage, brak NaN/Infinity, kopie w Health Sim, przełącznik profilu, docs) | lokalnie, worktree `C:\dev\FairWear-vnext2` |
   | `feature/string-resources` | teksty UI w zasobach | **opcjonalnie**, §5 |
3. **Nigdy nie merguj `feature/hes-vnext`** (worktree `C:\dev\FairWear-vnext`) — to przepisanie silnika od zera wg starej `WKLEJKA_HES_VNEXT.md`, którą wklejka 14 unieważniła (zmienia dane person i może zepsuć `PartnerVerifier`). Nie bierz też `origin/feature/hes-vnext-profiles` osobno — jest już w `feature/hes-vnext-fix`.
4. **Nie zmieniaj:** `TierClaim` (7 kluczy, `v` = `TIER_CLAIM_VERSION`), `ProofSigner` / `CryptoUtil` / kolejności `verifyClaim`, reguł noszenia, danych person (`HesPersonas.ets`, `WearPersonas.ets`), krzywych, wag, okien, liczności min/target. **Nie dostrajaj testów do kodu ani kodu do testów.** Jeśli oczekiwanie w teście wzięło się z liczb HES-Lite, a silnik vNext daje inną wartość — wpisz wartość silnika i dopisz tę zmianę do raportu (§9). Jeśli silnik daje coś innego niż złote wartości z §4 — to błąd: szukaj w kodzie, a gdy nie znajdziesz w 10 min, zatrzymaj się i zapytaj.
5. **Push jest zatwierdzony przez właściciela** dla tej sesji, tylko tak: `git push origin merge/final-into-main` (fast-forward), PR `merge/final-into-main → main`, merge PR, GitHub Release. **Zakazane:** `--force`, zmiana widoczności repo (zostaje **prywatne**), usuwanie gałęzi, push innych gałęzi.
6. Inni agenci pracują równolegle w `FairWear-vnext2`, `FairWear-limits`, `FairWear-strings` — nie edytuj ich worktree; bierzesz tylko **zacommitowane** stany ich gałęzi.
7. Bramki po każdej fazie: `tools/run-logic-tests.sh common`, `tools/run-logic-tests.sh watch`, `HealthSimCopies` (Node), `tools/check-wording.sh` (0), `tools/lint.sh` (0 błędów). Build: `unset ELECTRON_RUN_AS_NODE`, potem `tools/deploy.sh` / `hvigorw assembleHap` (FairWear) i wg `healthsim/README.md` (Health Sim).
8. Emulatory tylko z lockiem: `C:\dev\_emu-phone.lock` / `C:\dev\_emu-watch.lock`, treść `A16 <godzina>`, max 10 min, potem usuń.
9. Kod, komentarze, UI, docs po angielsku. Wording: bez "AI", "predicts", "validated", "risk", "healthy/unhealthy". Commit po każdej fazie.

---

## 1. Faza F1 (teraz → 09:20) — merge `origin/fix/review-findings`

`git merge --no-ff origin/fix/review-findings`. Konflikty spodziewane w ~10 plikach: `AGENTS.md`, `AI_WORKFLOW.md`, `HACKATHON_BRIEF.md`, `README.md`, `docs/DEMO_SCRIPT.md`, `docs/prompts/README.md`, `docs/test-results.txt`, `common/src/main/ets/claim/PartnerVerifier.ets`, `common/src/main/ets/report/EngineReports.ets`, `entry/src/main/ets/share/ShareService.ets`.

- **Kod:** zachowaj zachowanie obu stron. W `PartnerVerifier` spotykają się dwie poprawki tego samego: A1/F6 (S-10b: inny klucz pod tym samym `kid` → `false`, stary klucz dalej weryfikuje; użyte nonce w osobnej mapie z limitem 512, S-15b) i review-findings `faee973` (kid należący do innego klucza odrzucony, nigdy cicho podmieniony; enrolment wylicza kid). Po scaleniu **oba zestawy testów zielone**, kolejność kroków `verifyClaim` i teksty bez zmian.
- **Kopie Health Sim:** review-findings zmienia `healthsim/entry/src/main/ets/fw/health/HealthSimPayload.ets` i `fw/wear/WearMonth.ets`, A1 też `HealthSimPayload`. Po scaleniu skopiuj 1:1 z `common/src/main/ets/` do `healthsim/*/src/main/ets/fw/`, aż `HealthSimCopies` będzie zielony.
- **Docs:** zostaw obie strony; liczby testów poprawisz w F5.

Bramki §0.7. Commit: `Merge fix/review-findings: signed Watch Link ACKs, partner kid, sleep around 18:00, one break limit, Health Sim decoder`.

---

## 2. Faza F2 (09:40) — merge `fix/known-limits`

Gdy `C:\dev\_handoff\a17.md` istnieje i `git -C C:/dev/FairWear-limits status` jest czysty: `git merge --no-ff fix/known-limits`. Wspólne pliki (handoff je wymienia): `ReportService.ets`, `ServiceLocator.ets`, `ShareService.ets`, `common/Index.ets`, `List.test.ets` — zostaw obie strony.
**O 09:45 nie ma handoffu → pomiń** i zostaw te ograniczenia w docs tak, jak są.
Commit: `Merge fix/known-limits: day dial from the session, visit codes in the ledger, emulator checks`.

---

## 3. Faza F3 (09:45 → 10:00) — merge najnowszego HES: `feature/hes-vnext-fix`

1. Sprawdź `git -C C:/dev/FairWear-vnext2 status` i `git log -3 feature/hes-vnext-fix`. Agent wklejki 14 kończy P0+P1 do 09:45. Jeśli jeszcze pracuje — czekaj **najdłużej do 09:50**, potem bierz ostatni commit gałęzi (niezacommitowane zmiany nie wchodzą).
2. `git merge --no-ff feature/hes-vnext-fix`. Konflikty:
   - `common/src/main/ets/hes/*` i ich kopie w `healthsim/*/fw/hes/*` → **wersja z `feature/hes-vnext-fix`** (to najnowszy HES). Poprawka snu ~18:00 z review-findings (`e6ed915`) jest już w vNext (kotwica 18:00) — jej test zostaje, jeśli jest zielony; jeśli nie, opisz w raporcie.
   - `common/src/main/ets/claim/*` → wersja z finału (F1).
   - `ReportService.ets` / `EngineReportService` / `ServiceLocator.ets` → zostaw `reportFor(...)` z vNext **i** `dayHistory(...)` z F2.
   - docs → obie strony.
3. Testy z A1/A2/F2, które sprawdzają liczby z HES (`ConsentScopes`, `CardDigest`, `DayDial`, `EngineReports`, `WhySections`, `Report`, `HealthSimPayload`, `EvidenceCalendar`) → popraw tylko oczekiwane liczby na wynik silnika vNext, każdą zmianę wpisz do raportu. Np. A1 „Ania bez HRV: A / 93, 90%” → vNext: **A / 93, 92.5%, High**.
4. Kopie Health Sim zsynchronizowane, `HealthSimCopies` zielony.

### 4. Złote wartości (wklejka 14, §8) — muszą wyjść z silnika i z aplikacji

| Persona | Health insurance (Share, benefit) | Life insurance |
|---|---|---|
| Ania | 92 · A · 100% · High | 91 · A · 100% · High |
| Marek | 75 · B · 87.5% · High, flagged → bez benefitu | 75 · B · 87.5% · High |
| Kasia | 71 · B · 75% · Medium | 71 · B · 65% · Medium |
| Tomek | 79 · B · 92.5% · High · "1 point to A" | 80 · A · 92.5% · High |
| Ewa | 58 · C · 80% · High | 59 · C · 70% · Medium |
| Ola | No score · 47.5% · Insufficient data | No score · 47.5% |

Share, partner, benefit, karta na ekranie głównym, mowa — **zawsze Health insurance**. Claim bez zmian.

5. **Docs z nowymi liczbami** (grep: `73`, `59`, `88%`, `93%`, `48%`, `43%`, `coverage 90%`, `HES-Lite`, `458`): `README.md` (tabela „For the jury”: „HES vNext, two profiles”, liczba testów), `docs/DEMO_SCRIPT.md`, `docs/REQUIREMENTS_CHECK.md`, `HACKATHON_BRIEF.md`, `docs/HES.md` (sekcje conformance/deviations z vNext zostają). Opisy zrzutów w README muszą zgadzać się z liczbami na zrzutach.

Bramki §0.7. Commit: `Merge feature/hes-vnext-fix: HES vNext with health and life insurance profiles, exact coverage, never NaN or Infinity`.

---

## 5. Faza F4 (opcjonalna) — `feature/string-resources`

Tylko gdy **o 09:55** F1–F3 są zielone **i** gałąź `feature/string-resources` ma czysty `git status` w `C:\dev\FairWear-strings`, zielone testy i lint, a próbny merge (`git merge --no-commit --no-ff`) ma konflikty w ≤ 5 plikach do rozwiązania w 5 min. W każdym innym przypadku `git merge --abort` / pomiń i wpisz do raportu. Nie czekaj na tego agenta.

---

## 6. Faza F5 (→ 10:05) — bramki, buildy, emulator

1. `common`, `watch`, `HealthSimCopies`, wording, lint — wszystko zielone; liczby do `docs/test-results.txt` (sekcja „Final integration”, godzina, commit).
2. Buildy z **ostatniego commita**: FairWear `entry` + `watch`, Health Sim `entry` + `watch`. Wszystkie cztery muszą przejść.
3. Emulator (locki), świeża instalacja 4 HAP-ów (`hdc -t <target> install -r`):
   - Report dla 6 person = tabela §4 (Health insurance); Tomek w Life insurance → 80 · A;
   - Share: linia „For: Health insurance”, QR, partner weryfikuje kod; zmieniony tier → odrzucony;
   - „Close the day” → tarcza przesuwa się o dzień (jeśli F2 weszło);
   - Ewa → Visits → Share → „What left this phone” ma linię wizyty (jeśli F2 weszło);
   - Health Sim → zgoda → FairWear liczy na danych Health Sim; zegarek: tarcza / tętno.
   - Wyniki do `docs/test-results.txt`. Jeśli na czterech zrzutach z góry README zmieniły się liczby — zrób je od nowa (te same nazwy plików); jeśli nie — zostaw.
4. Commit: `Final integration: test results, emulator regression, documents`.

---

## 7. Faza F6 (→ 10:15) — HAP-y, push, PR, release

1. **Folder wydania:** przenieś stare pliki z `C:\dev\FairWear-release` do `C:\dev\FairWear-release\old-9a582b6\`, włóż cztery nowe HAP-y z nazwami `fairwear-entry-<sha7>.hap`, `fairwear-watch-<sha7>.hap`, `healthsim-entry-<sha7>.hap`, `healthsim-watch-<sha7>.hap`, `SHA256SUMS.txt` i `BUILD_INFO.txt` w tym samym formacie co dotychczasowy (commit, data, SDK, „unsigned debug builds, accepted by the emulators”, jak zainstalować).
2. **README, linia 17:** `**HAP packages:** [GitHub release hackyeah-2026-final](https://github.com/presivelab/huawei/releases/tag/hackyeah-2026-final)` (opis: cztery HAP-y + SHA256SUMS). **Demo video:** link z nagłówka tej wklejki; jeśli pusty — zostaw `(link before submission)` i wpisz jako krok dla właściciela w raporcie. Commit: `README: HAP release link`.
3. `git push origin merge/final-into-main` (bez `--force`; odrzucony → `git fetch`, `git merge origin/merge/final-into-main`, bramki, ponów).
4. `gh auth status`. Jeśli `gh` działa:
   ```
   gh pr create --repo presivelab/huawei --base main --head merge/final-into-main \
     --title "Final: HES vNext, security fixes, known limits, four HAPs" --body-file <plik z opisem>
   gh pr merge <nr> --repo presivelab/huawei --merge
   gh release create hackyeah-2026-final --repo presivelab/huawei --target main \
     --title "FairWear - HackYeah 2026" --notes-file <BUILD_INFO.txt> <4 HAP-y> SHA256SUMS.txt BUILD_INFO.txt
   ```
   Opis PR: co weszło (tabela gałęzi z §0.2), liczby testów, tabela person, czego nie ma. Merge PR **tylko gdy F5 było całe zielone**; jeśli coś było czerwone — PR zostaje otwarty, napisz dlaczego.
   Jeśli `gh` nie działa — tylko push; w raporcie podaj gotowe linki: `https://github.com/presivelab/huawei/compare/main...merge/final-into-main` i `https://github.com/presivelab/huawei/releases/new`.
5. Po merge: `git fetch origin` i sprawdź, że `origin/main` = Twój ostatni commit (albo merge commit PR-a nad nim).

---

## 8. Cięcia (pierwsze wylatuje)

F4 strings → zrzuty README → sprawdzenia Life insurance na emulatorze → F2 known-limits → `gh release` (wtedy HAP-y zostają w `C:\dev\FairWear-release`, link w README podaje właściciel).
**Nie wolno ciąć:** F1, F3, zielonych testów, przebudowy wszystkich czterech HAP-ów z ostatniego commita, pushu.

---

## 9. Raport końcowy (po polsku, krótko)

- Tabela faza | status | commit.
- Tabela person: aplikacja vs §4.
- Testy (`common`, `watch`, HealthSimCopies), lint, wording, 4 buildy.
- Lista testów, w których zmieniono oczekiwaną liczbę (stara → nowa, dlaczego).
- Co pominięto i dlaczego (F2/F4/zrzuty).
- Linki: PR, release, `origin/main` SHA, ścieżka `C:\dev\FairWear-release`.
- Kroki dla właściciela: link do wideo (jeśli brak), dostęp jury do prywatnego repo (dodanie kont jury jako collaborators / zgodnie z formularzem HackYeah), ewentualny ręczny merge PR.
