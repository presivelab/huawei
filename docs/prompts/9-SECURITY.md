> Public-safe copy of a team brief (in Polish) that was handed to a coding-agent session as its standing instruction during HackYeah 2026. Kept as written; which briefs are still in force is listed in `docs/prompts/README.md`.

# WKLEJKA 9: SECURITY — higiena i model zaufania na oddanie (dopasowane do repo, stan 01:00)

**Cel:** na kryterium „Technical execution” nie stracić punktów za higienę (sekrety, walidacja wejścia, zbędne uprawnienia, ryzykowne zależności). Model zaufania ma być opisany uczciwie, z testami jako dowodem.

Obowiązuje razem z wklejką 8. Bloki S0–S2 nie zależą od HES i możesz je robić od razu. S3–S4 robisz w ramach I-2.

## Zasady

1. **Po każdym bloku:**
   - build `entry` i `watch`;
   - `tools/run-logic-tests.sh common` i `tools/run-logic-tests.sh watch`.

   Jeśli coś jest czerwone, cofasz blok i raportujesz.
2. **Kontrakt claimu się nie zmienia.** `TierClaim` ma 7 pól: `v, period, tier, eligible, nonce, issuedAt, kid`. Statusy weryfikacji, zawsze w tej kolejności i z tymi tekstami:
   1. `Invalid format`
   2. `Unknown key`
   3. `Invalid signature`
   4. `Nonce mismatch`
   5. `Already used`
   6. `Signature valid`

   Nowe sprawdzenia mapujesz na te statusy.
3. **Zmiana w `types.ets` albo `defaults.ets`** wymaga zgody człowieka.
4. **Przed operacją nieodwracalną pytasz.** Dotyczy to przepisania historii, usunięcia pliku, nowego materiału podpisu i odinstalowania aplikacji.
5. **Każdy blok to osobny commit** z prefiksem `security:`. Daty commitów zostają prawdziwe.
6. **Kod ma pierwszeństwo przed wklejką.** Jeśli coś tu nie pasuje do kodu, dopasowujesz się do kodu i zgłaszasz rozbieżność.

## Co już jest dobre (sprawdzone 01:00, nie psuć)

- `entry` nie ma uprawnień ani kodu sieciowego.
- `watch` ma tylko `READ_HEALTH_DATA` i `ACTIVITY_MOTION`.
- `compatibleSdkVersion` 20, `targetSdkVersion` 24.
- `.gitignore` obejmuje:
  - materiał podpisu (`*.p12`, `*.cer`, `*.p7b`, `*.csr`, `*.jks`, `*.pem`, `*.pfx`, `*.keystore`);
  - `*.hap`;
  - `_incoming/`;
  - oba `rawfile/local.json` (Wear Engine);
  - `_relay/`.
- `local.example.json` ma tylko placeholdery.
- `TierClaimCodec`: kanoniczne kodowanie (stała kolejność kluczy) i ścisły decode (dokładny zestaw kluczy i typy).
- `SignedClaim.claimJson` niesie dokładnie te bajty, które były podpisane.
- `DayPacketCodec`: limit 512 znaków i zakresy wartości. Powtórki pakietów łapie łańcuch (`DUPLICATE`).
- Klucz software na emulatorze żyje tylko w pamięci aplikacji.
- Karta 2×2 nie pokazuje tieru.
- `routeFromWant` ma testy dla nieznanego celu.

## S0. Repo przed pierwszym pushem (około 15 min)

1. **Skan sekretów po całej historii i wszystkich gałęziach.**
   - Jeśli jest `gitleaks`: `gitleaks git -v .`. Starsza wersja: `gitleaks detect --source . -v --log-opts="--all"`.
   - Fallback:
     ```sh
     git log -p --all | grep -n -i -E "BEGIN [A-Z ]*PRIVATE KEY|storePassword|keyPassword|password\s*[:=]|secret\s*[:=]|api[_-]?key|AKIA[0-9A-Z]{16}"
     git log --all --name-only --pretty=format: | sort -u | grep -i -E "\.(p12|p7b|cer|csr|jks|keystore|pem|pfx|key)$|local\.json$"
     ```
   - Jeśli coś znajdziesz: **STOP**, pokaż wynik i nic nie pushuj.
2. **`build-profile.json5`.** Commitowana wersja nie może zawierać `storePassword`, `keyPassword` ani ścieżek do materiału podpisu. Przed I-5 DevEco dopisze je lokalnie. Wtedy plik nie trafia do commitu, a README opisuje krok **File → Project Structure → Signing Configs → Automatically generate signature**.
3. **Hook pre-commit.** Zapisz poniższy skrypt jako `tools/hooks/pre-commit`, skopiuj do `.git/hooks/pre-commit` i opisz w README jedną linią:
   ```sh
   #!/bin/sh
   # Blocks commits that stage signing material, local Wear Engine config or secret-looking lines.
   staged=$(git diff --cached --name-only --diff-filter=ACM)
   if echo "$staged" | grep -i -E '\.(p12|p7b|cer|csr|jks|keystore|pem|pfx)$|rawfile/local\.json$'; then
     echo "pre-commit: signing material or local config staged - commit blocked"; exit 1
   fi
   if git diff --cached -U0 | grep -i -E '^\+.*(storePassword|keyPassword|BEGIN [A-Z ]*PRIVATE KEY)'; then
     echo "pre-commit: secret-looking line staged - commit blocked"; exit 1
   fi
   exit 0
   ```
4. **Zależności.** Wypisz `dependencies` ze wszystkich `oh-package.json5`. Jeśli nie ma zależności zewnętrznych, zapisz to w SECURITY.md jako argument. Jeśli są, każda dostaje jedno zdanie uzasadnienia, a `oh-package-lock.json5` trzeba zdjąć z `.gitignore` i commitować (powtarzalny build).

## S1. Uprawnienia i punkty wejścia (około 10 min, głównie weryfikacja)

1. **`entry` zostaje bez uprawnień.** Wear Engine, HUKS, cryptoFramework, Form i preferences niczego tu nie wymagają. Jeśli I-2 albo W-x spróbuje dodać `INTERNET` albo inne uprawnienie: **STOP** i pytasz.
2. **`watch`:**
   - każde uprawnienie ma `reason` (`$string`) i `usedScene` z `"when": "inuse"`;
   - odmowa daje stan „Heart rate permission needed” z ponowieniem i bez wymyślonych wartości;
   - `sensor.off` przy ukryciu strony i przy zamknięciu.

   Wypisz, co już jest.
3. **`module.json5`:** `exported: true` mają tylko abilities startowe. Forma zostaje `exported: false`.
4. **Zdanie do README** (tylko jeśli punkt 1 dalej jest prawdą): *"The phone app declares no permissions and has no network code: health history and the score never leave the phone; the only output is the signed tier claim the user chooses to show as a QR code."*

## S2. Logi (około 15 min)

```sh
git grep -n "%{public}" -- common entry watch
git grep -n -E "console\.(log|info|debug|warn|error)" -- common/src/main entry/src/main watch/src/main
```

- `%{public}` wolno używać tylko dla danych niewrażliwych: nazw ekranów, kodów błędów, liczników, `kid`, ścieżek sandboxu.
- **Zakazane w `%{public}`:** tętno, kroki, RHR, VO₂max, HRV, sen, HES, wartości person, tokeny, nonce, podpisy, klucze.
- **Konkretna poprawka:** `watch/src/main/ets/sensors/LiveSensors.ets`, `logSummary()`. Usuwasz `hrRaw`, `hrShown`, `stepsRaw` i `stepsToday`, a zostawiasz `hrLink`, `hrEvents`, `hrValid`, `stepLink`, `stepEvents` i `wear`. Alternatywnie wartości idą przez `%{private}`.
- `JSON.stringify(err)` w logach jest OK, o ile obiekt błędu nie zawiera danych zdrowia.
- W raporcie podaj liczbę poprawionych linii.

## S3. Twardszy decode claimu (`common/src/main/ets/claim/TierClaimCodec.ets`, około 30 min)

Wszystko poniżej daje `Invalid format` i działa przed lookupem `kid`.

1. **Długość.** `claimJson` ma 1–256 znaków, a cały token (QR) najwyżej 512. Dłuższe wejście odrzucasz przed `JSON.parse`.
2. **Forma kanoniczna.** Po udanym decode sprawdzasz `encodeTierClaim(decoded) === claimJson`. Inaczej `null`.

   To ważne, bo `JSON.parse` przy powtórzonym kluczu bierze ostatnią wartość, a `Object.keys` zwraca 7 kluczy. Obecne sprawdzenie liczby kluczy przepuści więc `{"tier":"C",…,"tier":"A"}`. Porównanie z formą kanoniczną zamyka ten przypadek oraz różnice w spacjach i kolejności kluczy.
3. **Wartości:**
   - `v === TIER_CLAIM_VERSION`;
   - `tier` należy do zbioru z `types.ets`/`defaults.ets` (A/B/C plus wartość „brak wyniku”, jeśli istnieje);
   - `period` ma format, który produkuje kod (sprawdź i wpisz regex);
   - `nonce` pasuje do `/^[A-Za-z0-9_-]{22}$/`;
   - `kid` pasuje do `/^[0-9a-f]{8}$/`;
   - `issuedAt` jest liczbą całkowitą > 0, nie więcej niż 5 min w przyszłości;
   - `eligible === true` przy tierze „brak wyniku” daje `Invalid format`.
4. **`SignedClaim`.**
   - `kid` poza claimem musi być równy `kid` wewnątrz `claimJson`. Inaczej `Invalid format`.
   - `sigB64` po zdekodowaniu ma długość zgodną z formatem z `CryptoUtil` (DER: najwyżej 72 B).
   - **`keySource` w tokenie NIE jest podpisane**, więc partner nigdy mu nie ufa (patrz S4).

## S4. Widok partnera = weryfikator (w ramach I-2, około 45 min razem z testami)

Klasa `PartnerVerifier` w `common`, z czystą logiką i testami w Node. Ekran partnera tylko ją wywołuje.

1. **Nonce wydaje partner.**
   - `issueNonce()` → `cryptoFramework.createRandom().generateRandomSync(16)` → base64url bez paddingu (22 znaki).
   - Partner zapisuje `issued: Map<nonce, issuedAt>`.
   - Ekran Share podpisuje nonce wydany przez partnera w chwili otwarcia Share, a nie przy starcie aplikacji.
   - `Math.random` w ścieżce podpisu jest zabronione.
2. **Rejestr kluczy partnera.** `kid → { publicKeyDer, source }`, zapisany przy zgodzie (AD-2) jako „zapis do programu”. Źródło klucza (`HUKS` albo `SOFTWARE`) w UI partnera pochodzi **z rejestru, nie z tokenu**.

   Klucz software na emulatorze żyje w pamięci, więc `kid` zmienia się po restarcie aplikacji. Rejestr odświeżasz przy starcie sesji i opisujesz to w README.
3. **Kolejność weryfikacji:**
   1. format (S3);
   2. `kid` w rejestrze, inaczej `Unknown key`;
   3. ECDSA nad dokładnymi bajtami `claimJson`, inaczej `Invalid signature`;
   4. nonce w `issued` i, jeśli jeszcze nieużyty, nie starszy niż TTL = 10 min, inaczej `Nonce mismatch`;
   5. nonce w `used`, inaczej `Already used`;
   6. dodanie nonce do `used` i wynik `Signature valid`.
4. **Powtórki rozpoznajesz po nonce, nigdy po podpisie ani hashu tokenu.** Podpis ECDSA jest plastyczny: z (r, s) da się zrobić drugi ważny podpis (r, n−s), więc rejestr kluczowany podpisem przepuściłby ten sam QR drugi raz.
5. **Wynik w UI:** duży status, nazwa kroku, na którym weryfikacja się zatrzymała, i plakietka klucza z rejestru („HUKS key” albo „Software key (emulator)”).

## S5. Watch Link (około 10 min, weryfikacja)

- Plik ze skrzynki `inbox/` to niezaufane wejście. Potwierdź, że każda ścieżka wejścia przechodzi przez `DayPacketCodec.fromJson` (limit 512) i `PairVerifier`. Dopisz limit, jeśli gdzieś go brakuje.
- Relay `tools/watch-phone-relay.mjs` jest narzędziem dev. W UI i README nosi etykietę „DEMO relay (hdc)”. Nigdzie nie piszesz, że Wear Engine działa: kod jest, ale nie był uruchomiony.

## S6. Testy bezpieczeństwa

Nowe testy dopisujesz, istniejących nie zmieniasz. Wyniki to dokładnie istniejące statusy.

| # | Scenariusz | Oczekiwany wynik |
|---|---|---|
| S-1 | pusty string | `Invalid format` |
| S-2 | token 513 znaków (parse nie jest nawet uruchamiany) | `Invalid format` |
| S-3 | nie-JSON / emoji | `Invalid format` |
| S-4 | brak każdego z 7 kluczy (7 przypadków) | `Invalid format` |
| S-5 | dodatkowy klucz | `Invalid format` |
| S-6 | **powtórzony klucz `tier`** | `Invalid format` |
| S-7 | niekanoniczne spacje / kolejność kluczy | `Invalid format` |
| S-8 | `tier: "S"`, zły `nonce`, zły `kid`, `issuedAt` w przyszłości | `Invalid format` |
| S-9 | `kid` w `SignedClaim` ≠ `kid` w `claimJson` | `Invalid format` |
| S-10 | poprawny format, nieznany `kid` | `Unknown key` |
| S-11 | zmieniony tier | `Invalid signature` |
| S-12 | zmieniony nonce | `Invalid signature` |
| S-13 | poprawny podpis nad nonce'em niewydanym przez partnera | `Nonce mismatch` |
| S-14 | nonce starszy niż TTL, nieużyty | `Nonce mismatch` |
| S-15 | ten sam token drugi raz | `Already used` |
| S-16 | **powtórka z podpisem (r, n−s)** | `Already used` |
| S-17 | token nie zawiera HES, pokrycia, flag ani wartości zdrowia | pass |
| S-18 | 1000 nonce'ów: unikalne, 22 znaki, alfabet base64url | pass |
| S-19 | `setLive(HR=200, steps=99999)` nie zmienia HES | pass |
| S-20 | `keySource: "HUKS"` w tokenie przy kluczu `SOFTWARE` w rejestrze; UI pokazuje „Software key” | pass |

**Test S-16.** Rząd krzywej P-256:
```
n = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551
```
1. Weź ważny token i zweryfikuj go raz (`Signature valid`).
2. W formacie podpisu z `CryptoUtil` zamień `s` na `n − s`:
   - **DER:** sparsuj `30 len 02 lenR R 02 lenS S`, policz BigInt i zakoduj z powrotem, z wiodącym `0x00`, jeśli ustawiony jest najstarszy bit;
   - **raw r‖s:** podmień ostatnie 32 bajty.
3. Zweryfikuj ponownie. Oczekiwany wynik: `Already used`.

Po testach zaktualizuj `docs/test-results.txt`: liczby pass/fail, datę i komendę.

## S7. Dokumentacja (w I-4)

**`docs/SECURITY.md`** (po angielsku) zawiera:
1. **Scope:** prototyp, historia syntetyczna, brak serwera.
2. **Assets:** historia zdrowia, HES, klucze, claimy, nonce'y, pakiety dnia.
3. **Actors:** ubezpieczony, który chce oszukać; ktoś, kto sfotografował QR; złośliwa aplikacja; partner zbierający za dużo; osoba klonująca repo.
4. **Threat table:** Threat | Mitigation | Status (`implemented + tested (S-x)` / `implemented` / `production plan` / `out of scope`). Wiersze:
   - raw health data to partner → only signed tier, phone has no permissions or network (S-17, `module.json5`);
   - forged or edited claim → ECDSA P-256 over exact bytes, canonical-form check (S-6, S-7, S-11, S-12);
   - replayed QR → partner-issued single-use nonce with TTL, replay keyed by nonce (S-13 – S-16);
   - edited or dropped watch days → signed, hash-chained day packets (testy Watch Link);
   - selective non-wear → break rules + appeal (testy HES);
   - spoofed key type in token → key source from partner registry (S-20);
   - **modified app or rooted device signs any tier → NOT protected in the prototype.** Production: anonymous HUKS key attestation at enrollment (`huks.anonAttestKeyItem`; it needs network once, so it is not in this build; `attestKeyItem` needs the `system_basic` permission `ATTEST_KEY`) plus a device integrity check;
   - private key extraction → HUKS keys are non-exportable; emulator software key in memory, labelled;
   - health data in logs → hilog private by default, no health values in `%{public}`;
   - leaked signing material → `.gitignore`, pre-commit hook, full-history scan;
   - unfair automated decision → deterministic rules, "Why this tier", appeal, "no score yet" instead of a low score, reward-only.
5. **Out of scope / production notes:**
   - urządzenia z rootem;
   - serwerowy weryfikator;
   - blokada zrzutów (`setWindowPrivacyMode` zablokowałaby nagranie demo);
   - jeden klucz dla wszystkich partnerów pozwala im połączyć claimy jednej osoby przez `kid`: produkcyjnie osobny klucz per partner;
   - `kid` ma 32 bity, więc przy dużej skali rejestr mapuje `kid` na listę kluczy.
6. **How to verify:** komendy testów, grep po uprawnieniach i `%{public}`, skan sekretów.

**README, sekcja „Security & privacy”:** 4–5 zdań, każde sprawdzalne, i link do SECURITY.md. Znane ograniczenie (brak atestacji) piszesz wprost.

**Tabela „Hackathon requirements → where to verify”:** wiersz *Basic hygiene* → `docs/SECURITY.md`, testy S-1 – S-20, `tools/hooks/pre-commit`.

## S8. Checklista przed pushem i raport

- [ ] skan sekretów po `--all` jest czysty
- [ ] `git ls-files` nie zawiera materiału podpisu, `local.json`, `build/` ani `oh_modules/`
- [ ] commitowany `build-profile.json5` nie zawiera haseł ani ścieżek do materiału
- [ ] `entry` dalej bez uprawnień; `watch` ma dwa uprawnienia z `reason`
- [ ] wszystkie testy zielone, `docs/test-results.txt` zaktualizowany
- [ ] świeży klon do katalogu tymczasowego buduje się według README

Raport: tabela blok | zrobione / pominięte / rozbieżność | commit | testy. Na koniec sesji `/raport` i `/backup`.
