# WKLEJKA 6: scalenie gałęzi, wdrożenie HES-Lite z `fairwear-ui`, zegarek według raportu, oddanie

## Stan na 00:35 (analiza repo `C:\dev\FairWear`, wszystkie gałęzie)

- **Najpełniejsza gałąź to `feature/home-card`.** Zawiera `health-addon`, `entry-routing`, kartę 2×2 i skrót. `main` jest 18 commitów za nią. README jest tylko na `home-card`.
- **`feature/watch-link`** (Watch Link, faza 1: tylko logika) odchodzi od `health-addon` i nie jest scalona z `home-card`. Próbny merge daje dwa konflikty, oba do rozwiązania ręcznie: `AI_WORKFLOW.md` i `common/Index.ets`.
- **Testy (Node, TypeScript 5.6, uruchomione niezależnie od agenta):**
  - `home-card`: common 42/42, watch 6/6;
  - `watch-link`: common 60/60.
- **Nie ma HES-Lite na żadnej gałęzi.** Brakuje `common/src/main/ets/hes/`, `HesPersonas`, `EngineFairWearService` i ekranów z `fairwear-ui` (24h dial, Why this tier, Demo controls, Wearable calendar, Share QR, widok partnera). Nie ma też weryfikatora claimu. Ekran wyniku pokazuje „—”. `fairwear-ui.zip` nie został pobrany na ten komputer.
- **Claim nie zgadza się z raportem.** W repo: `v, period, tier, eligible, nonce, issuedAt, kid` (7 kluczy). W raporcie: `version, from, periodStart, periodEnd, tier, eligible, nonce, iat, kid`.
- **Zegarek nie zgadza się z raportem.**
  - `home-card`: stan „zdjęty” po 10 s, brak ładowania, brak tarczy 24h.
  - Raport: „Not on wrist” po > 60 s, ładowanie z `batteryInfo.pluggedType`, `ui/DayDial`.
  - `watch-link` ma 60 s i stan `C`, ale nie jest podpięty do ekranu.
- **Dokumenty nie zgadzają się z decyzjami właściciela.** VO₂max i HRV są autentyczne i wchodzą do HES (decyzja właściciela), a `ARCHITECTURE.md` pisze, że bez tabeli percentyli nie będą liczone. `HACKATHON_BRIEF.md` i `types.ets` (`'LLM'`) opisują funkcję AI, której w produkcie nie ma. `AI_WORKFLOW.md` ma niewypełnione sekcje szablonu.
- **Higiena jest w porządku.** W historii nie ma plików podpisu ani sekretów. Uprawnienia: `entry` nie ma żadnych, `watch` ma dwa. API: `compatibleSdkVersion 6.0.0(20)`, `targetSdkVersion 6.1.1(24)`, zgodnie z FAQ. Tego nie zmieniasz.

## Zasady (bez zmian)

- Pracuje jedna sesja. Inne sesje nie zakładają nowych gałęzi, dopóki nie skończy się krok I-1.
- Merge do `main` robi człowiek.
- Nie piszesz, że coś działa, jeśli tego nie uruchomiłeś.
- `types.ets` i `defaults.ets` zmieniasz tylko za zgodą człowieka.
- Reguł i HES nie nazywasz „AI”.

## I-0: człowiek

1. Otwórz czat „Analiza arkusza” w claude.ai, pobierz `fairwear-ui.zip` i rozpakuj go do `C:\dev\FairWear\_incoming\fairwear-ui\`. Katalog `_incoming/` jest w `.gitignore`.
2. Decyzje (domyślne odpowiedzi, jeśli człowiek nie odpowie w 10 min):
   - format claimu: **według raportu** (9 pól);
   - Watch Link: **faza 1 zostaje w repo; fazy 2+ tylko jeśli do 07:00 zostanie czas**;
   - zdanie o AI w `HACKATHON_BRIEF.md` i `'LLM'` w `types.ets`: **usunąć**.

## I-1: jedna baza

1. Utwórz gałąź `feature/integration` od `feature/home-card` i scal do niej `feature/watch-link`.
   - `common/Index.ets`: zostaw oba zestawy eksportów.
   - `AI_WORKFLOW.md`: zostaw oba wpisy w dzienniku.
2. Uruchom testy common i watch. Oczekiwane: common 60 + 14 (CardDigest i EntryTarget), watch 6. Podaj dokładne liczby. Zbuduj `entry` i `watch`.
3. Zgłoś człowiekowi gotowość do merge `feature/integration` → `main`. Od tej chwili wszystkie dalsze gałęzie odchodzą od `main`.

## I-2: HES-Lite i ekrany z `fairwear-ui` (najważniejsze)

Wykonaj kroki 1–6 z `_incoming/fairwear-ui/WKLEJKA_CLAUDE_CODE.md` z tymi zmianami:

- **Zgoda:** zostaje nasz przepływ dodatku (AD-1 Welcome, AD-2 dwa kroki, AD-3 status i odłączenie). Ekranu Consent z paczki nie dodajesz. Dashboard, 24h dial, Live card, Why this tier, Demo controls, Wearable calendar, Share i widok partnera bierzesz z paczki i wpinasz za AD-2.
- **Źródło:** `SyntheticHealthSource` ma `status() = DEMO` i daje historię z `HesPersonas` przez istniejącą `HealthConnection`. Wyłączony w AD-2 zakres daje `MISSING` w HES i niższe pokrycie. Dopisz na to test.
- **Podpis:** demo-signer FNV z paczki zastępujesz naszym `ProofSigner` (HUKS z zapasowym kluczem programowym). Plakietka w UI: „HUKS key” / „Software key (emulator)”.
- **Claim:** `TierClaimCodec` przechodzi na pola z raportu: `version, from, periodStart, periodEnd, tier, eligible, nonce, iat, kid`. Popraw `Claim.test.ets`.
- **Weryfikator** w kolejności z raportu: JSON decode (Invalid format) → kid (Unknown key) → ECDSA (Invalid signature) → nonce (Nonce mismatch) → replay (Already used) → Signature valid. Testy: podmieniony tier, podmieniony nonce, powtórka.
- **Karta 2×2:** `CardDigest` dostaje prawdziwe pokrycie i „Score ready”. Tier nadal nigdy nie trafia na kartę.
- **Wyniki person muszą się zgadzać z raportem:**

  | Persona | Tier / wynik | Pokrycie | Pewność | Uwagi |
  | --- | --- | --- | --- | --- |
  | Ania | A/92 | 100% | High | pełny benefit |
  | Marek | B/75 | 85% | High | oflagowany, bez benefitu |
  | Kasia | B/73 | 70% | Medium | częściowy benefit |
  | Tomek | B/79 | 90% | High | „1 point to A” |
  | Ewa | C/59 | 75% | Medium | bez benefitu |
  | Ola | brak wyniku | 43% | — | za mało danych |

  Każda rozbieżność to błąd do zgłoszenia, nie do „poprawienia” progów.
- **Na emulatorze telefonu:** AD-1 → AD-2 → Dashboard (Ania) → Why this tier → Share (QR) → widok partnera (Signature valid) → AD-3 odłącz → AD-2 → wynik. Zrzuty w jasnym i ciemnym motywie.

## I-3: zegarek według raportu

- Tarcza `ui/DayDial` i `ui/WatchModels` z paczki. Tętno na żywo w środku tarczy. Podpis „Before launch: demo data” na tarczy demo.
- Stan „Not on wrist” po > 60 s bez poprawnego tętna. Tryb demo może skracać ten czas tylko z widoczną etykietą (jak zegar demo w Watch Link).
- Ładowanie: `batteryInfo.pluggedType` → stan „Charging”. Bez dodatkowych uprawnień.
- Gdzie się da, użyj `WearStateMachine` z Watch Link, żeby nie mieć dwóch reguł noszenia.
- **Człowiek przy emulatorze zegarka:** Virtual sensor → tętno 70 → 0 → 70. Wynik i zrzuty idą do README. Bez tego zegarek na nagraniu pokazuje tylko „—”.

## I-4: dokumenty

- `README.md` i `docs/ARCHITECTURE.md`: VO₂max i HRV w demo pochodzą z person i wchodzą do HES. Prawdziwy adapter Health Service Kit opisz zgodnie z decyzją właściciela. Tabela „real vs simulated” obejmuje telefon, zegarek i Watch Link.
- `AI_WORKFLOW.md`: uzupełnij wszystkie sekcje szablonu, czyli narzędzia z wersjami, prompty (`C:\dev\fairwear-specs` → `docs/prompts/`, bez danych osobowych), przebieg pracy, weryfikację, nieudane podejścia, ograniczenia i wnioski. „AI feature disclosure: Not applicable”.
- `docs/DEMO_SCRIPT.md`: dopisz kroki HES (Dashboard → Why → Share → Partner) między krokami 5 i 6 oraz fragment o zegarku.
- `docs/REQUIREMENTS_CHECK.md` i tabela w README: zaktualizuj punkty B2–B18.

## I-5: oddanie (człowiek z pomocą agenta)

- **Podpis:** utwórz konfigurację w DevEco i zbuduj podpisane `.hap` dla telefonu i zegarka. Zmienionego przez DevEco `build-profile.json5` z hasłami i ścieżkami **nie commitujesz**. Sprawdź, że podpisane `.hap` instalują się na czystym emulatorze.
- **Publiczne repo:** adres e-mail w commitach stanie się publiczny. To decyzja właściciela. `.hap` dołącz jako GitHub Release.
- **Nagranie:** według `docs/DEMO_SCRIPT.md`. Na miejscu poproś mentora o uruchomienie `.hap` zegarka na prawdziwym zegarku Huawei.

## Watch Link, fazy 2+ (tylko jeśli do 07:00 zostanie czas)

Emulatory nie łączą zegarka z telefonem. Pakiet dnia na demo przenosi się skryptem `hdc file recv` / `hdc file send`, wyraźnie oznaczonym jako DEMO. W README opisz, jak to działa na urządzeniu.

## Harmonogram

| Godzina | Cel |
| --- | --- |
| 01:00 | I-1 gotowe, merge do `main` |
| 04:00 | I-2 na emulatorze telefonu, wyniki person zgodne z raportem |
| 06:00 | I-3 |
| 07:30 | I-4 |
| 08:30 | zamrożenie kodu |
| 08:30–10:00 | I-5 |
| do 10:30 | oddanie |

Po każdym kroku podaj liczby testów, listę zmienionych plików, zrzuty i rozbieżności z raportem. Na koniec sesji zrób `/raport` i `/backup`.
