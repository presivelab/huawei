> Public-safe copy of a team brief (in Polish) that was handed to a coding-agent session as its standing instruction during HackYeah 2026. Kept as written; which briefs are still in force is listed in `docs/prompts/README.md`.

# WKLEJKA 8: POPRAWKA FINAL — jedna wersja prawdy (stan 01:00)

**Pierwszeństwo:** tam, gdzie wklejki 1–7 albo DECYZJE 00:25/00:40 mówią co innego, obowiązuje ta wklejka. Wklejka 9 (security) obowiązuje przy każdym commicie.

**Zanim zaczniesz:** sprawdź gałąź (`git branch --show-current`). Na jednej gałęzi pracuje tylko jedna sesja. Merge do `main` robi człowiek.

## Stan sprawdzony w repo (01:00)

- **`feature/integration`** (`f1709ca`) = `home-card` + `watch-link`. I-1 jest zrobione. `main` (`98e4fd3`) czeka na merge przez człowieka.
- **Bloker:** w `_incoming/` nadal nie ma `fairwear-ui.zip`, więc na żadnej gałęzi nie ma HES-Lite. Bez tego nie ma produktu ani bramki.
- **Watch Link działa na emulatorach przez relay `hdc`.** Wynik testów: common 66/66, watch 6/6. Dowody:
  - podpis HUKS na emulatorze zegarka;
  - zmiana pakietu daje `Invalid signature`;
  - pominięty pakiet daje „Missing 1 day”.

  To mocna część demo, a nie opcjonalny dodatek.
- **Claim w repo:** 7 pól, kanoniczne kodowanie, ścisły decode. Nie ma weryfikatora claimu ani widoku partnera.
- **Dwie reguły noszenia:**
  - `LiveWearState` (`health-addon`, 10 s);
  - `WearStateMachine` (`watch-link`, 60 s, ładowanie, stan C).
- **Do poprawki w kodzie:**
  - `types.ets` dalej ma `'LLM'`;
  - `watch/.../LiveSensors.ets` (`logSummary`) loguje surowe tętno i kroki jako `%{public}`.
- **W porządku:**
  - `entry` nie ma uprawnień ani kodu sieciowego;
  - `watch` ma 2 uprawnienia;
  - `compatibleSdkVersion` 20, `targetSdkVersion` 24;
  - `.gitignore` obejmuje `local.json`, `_relay/` i materiał podpisu.

## Rozstrzygnięcia

### P1. TierClaim: 7 pól z repo
Wygrywa DECYZJE 00:40, a nie wklejka 6 (I-0, I-2). Obowiązuje claim z repo:

```
v, period, tier, eligible, nonce, issuedAt, kid
```

`types.ets` i `TierClaimCodec` zostają bez zmian. Kod z `fairwear-ui` dostosowujesz do repo.

Powód: 7-polowy claim jest przetestowany i podpisany na emulatorze. Pole `from` niczego partnerowi nie daje, a przebudowa o 1:00 to ryzyko bez punktów.

W README i w raporcie dodaj jedną linię mapowania nazw z raportu HES-Lite:

| Raport HES-Lite | Repo |
|---|---|
| `version` | `v` |
| `periodStart` + `periodEnd` | `period` |
| `iat` | `issuedAt` |
| `from` | celowo pominięte |

Testy UiService z paczki mogą się zmienić przy adaptacji. Każdą zmienioną asercję wypisz w raporcie. Wyniki person z raportu HES-Lite **nie mogą** się zmienić.

### P2. Podział pracy między sesje (sprzeczność 6 ↔ 7)
- **Sesja A** (od `main` po merge integration): I-3 i wklejka 9 bloki S0–S2, dopóki nie ma paczki. Potem I-2 → I-4.
- **Sesja B** (gałąź `feature/look-w0` od `main`): tylko W-0, wyłącznie w plikach, których A nie rusza:
  - ikona aplikacji (`AppScope` i media modułów);
  - czysta funkcja `statusLabel(HealthStatus): string` w `common` z testem;
  - `tools/check-wording.sh`;
  - ekran powitalny AD-1.

  Sesja B nie dotyka `pages/Index`, nawigacji, Dashboard, Share, widoku partnera ani modułu `watch`.
- **W-1…W-4** robicie dopiero po bramce I-2 (wyniki person zgodne z raportem).

### P3. Jedna reguła noszenia: `WearStateMachine`
- `WearStateMachine` z Watch Link jest jedyną regułą noszenia na zegarku.
- `LiveWearState` zamieniasz w cienki adapter na `WearStateMachine` albo usuwasz po przeniesieniu testów. Przed usunięciem pytasz.
- Próg to 60 s. Krótszy wolno ustawić tylko w trybie demo, z widoczną etykietą „Demo clock”.
- Odczyt ≤ 0 bpm oznacza brak odczytu.
- Stan „Charging” bierzesz z `batteryInfo.pluggedType`.
- `DayDial` z paczki tylko rysuje stany z `WearStateMachine` i nie liczy własnych.

### P4. Zegarek a HES: jedno zdanie prawdy
Dni z zegarka są podpisywane i weryfikowane na telefonie. W tym buildzie HES liczy się jednak na historii person.

Zdanie do README: *"In production, verified watch days are the wear evidence for the break rules; in this build the score uses persona history and verified watch days are shown, not scored."*

Nigdzie nie piszesz, że zegarek zasila wynik.

- **P4b** (opcjonalne, po I-3, około 45 min): w „Wearable calendar” zweryfikowany dzień z zegarka dostaje plakietkę „Verified watch day”. Na wynik nie wpływa.

### P5. VO₂max i HRV
- **Demo:** wartości są percentylami z person i wchodzą do HES (decyzja właściciela).
- **Prawdziwy adapter** (nie budujemy):
  - VO₂max z HUAWEI Health przychodzi w ml/kg/min i wymaga przeliczenia na percentyl tabelą z podanym źródłem;
  - HRV: sprawdź w `.d.ts` Health Service Kit, czy taki typ danych istnieje. Jeśli nie, README mówi „HRV where the data source provides it”.
- Tekst „Not scored yet: needs a reference table” pokazujesz wyłącznie przy statusie `CONNECTED`, który w tym buildzie nie występuje.

### P6. Widok partnera = weryfikator claimu
Powstaje w I-2 według wklejki 9 (S4):
- nonce wydaje partner;
- kolejność statusów jak w wklejce 9;
- powtórki rozpoznajesz po nonce.

Karta „What the partner sees” (W-2) pokazuje dokładnie `tier`, `eligible` i `period`. Pod „Technical” są `kid`, `nonce` i `issuedAt`. Nic więcej.

### P7. AI
- `'LLM'` w `types.ets`: usuwasz. To zmiana `types.ets`, więc idzie osobnym commitem po potwierdzeniu człowieka. Domyślna decyzja z wklejki 6 to „usunąć”.
- Zdanie o AI w `HACKATHON_BRIEF.md`: usuwasz.
- README: *"HES is deterministic rules, not AI. AI feature disclosure: not applicable."*

### P8. Logi
`LiveSensors.logSummary` loguje tylko liczniki: `hrEvents`, `hrValid`, `stepEvents`. Wartości `hrRaw`, `hrShown`, `steps` usuwasz z logu albo oznaczasz `%{private}`. Pełna reguła jest w wklejce 9 (S2).

## Demo (zastępuje wcześniejsze skrypty; I-4 wpisuje to do `docs/DEMO_SCRIPT.md`)

1. AD-1 → AD-2 (zgoda) → Dashboard Ania A/92 → Why this tier.
2. Suwak tętna na żywo: wynik stoi („Demo values, not scored”).
3. Marek: czerwone dni w kalendarzu → szczegóły dnia → „Appeal this day”.
4. Ola: „no score yet” zamiast złego wyniku.
5. Zegarek:
   - tętno 70 → 0 → 70 i stan „Not on wrist”;
   - „Close day” → relay → telefon pokazuje „Chain ✓ · Signature valid”;
   - `--tamper` → „Invalid signature”.

   Wszystko z etykietą DEMO relay.
6. Share QR → widok partnera:
   - „Signature valid”;
   - ten sam token drugi raz → „Already used”;
   - zmieniony tier → „Invalid signature”.
7. AD-3: odłącz → połącz ponownie → wynik wraca.

## Harmonogram (zastępuje tabelę z wklejki 6)

| Godzina | Kto | Co |
|---|---|---|
| teraz | człowiek | pobrać `fairwear-ui.zip` z czatu „Analiza arkusza” do `_incoming/`; merge `feature/integration` → `main` |
| 01:00–01:45 | A | I-3 (`WearStateMachine` na ekranie zegarka), wklejka 9 S0–S2 |
| 01:00–01:45 | B | W-0 według P2 |
| po paczce – 04:00 | A | I-2 z P1, P6 i wklejką 9 S3–S4 |
| 04:00 | bramka | persony zgodne z raportem i przejście na emulatorze. Jeśli nie przeszła, wszystko idzie na I-2, a z W-1/W-2 zostaje tylko Dashboard |
| 04:00–06:00 | A/B | W-1, W-2 (Dashboard, Share, partner), P4b jeśli jest czas |
| 06:00–07:00 | | W-3 (zegarek) |
| 07:00–08:00 | | I-4 i wklejka 9 S6–S7 (SECURITY.md, README) |
| 08:30 | | zamrożenie kodu |
| 08:30–10:00 | | I-5 |
| do 10:30 | | oddanie |

## Raport po każdym kroku

- liczby testów (common, watch, UiService, security);
- zmienione pliki;
- zrzuty;
- każda rozbieżność z raportem HES-Lite albo z tą wklejką.

Na koniec sesji `/raport` i `/backup`.
