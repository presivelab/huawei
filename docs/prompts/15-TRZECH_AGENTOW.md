> Public-safe copy of a team brief (in Polish) that was handed to a coding-agent session as its standing instruction during HackYeah 2026. Kept as written; which briefs are still in force is listed in `docs/prompts/README.md`.

# WKLEJKA 15: trzech agentów równolegle — wszystko, czego jeszcze brakuje (stan 07:30)

Zebrane z: audytu HackYeah (raport + fixy), audytu "co zbudowane" (Wklejka 14, NIE wykonana — brak gałęzi
`fix/final-audit`, F1 i F3 dalej otwarte), porównania Health Sim z HUAWEI Health, braków względem raportu
HES-Lite (zegar 24 h na telefonie, wizyty u lekarza) i raportu sesji `github-main-0703` (PR #2 otwarty).

Baza dla wszystkich: `merge/final-into-main` @ `908b9d9` (= main + feature/engine-reports + docs/final-polish,
380/380 + 6/6, buildy entry/watch zielone). PR #2 → `main` czeka na kliknięcie właściciela.

Każdy blok niżej wklejasz do osobnego okna Claude Code. Agenci pracują jednocześnie na rozłącznych plikach;
Agent 3 na końcu wszystko scala, buduje HAPy i wypycha.

---
---

## AGENT 1 — zgoda i poprawki logiki (Wklejka 14, część kodowa)

```
Jesteś AGENTEM 1 z trzech sesji Claude Code pracujących RÓWNOLEGLE w repo FairWear (C:\dev\FairWear, Git Bash).
To jest polecenie do wykonania od razu, nie do raportowania planu. Nie czekaj na potwierdzenia.
Kod, komentarze, dokumenty i teksty UI po angielsku. Raport końcowy po polsku.

## Start (5 min)
git -C C:/dev/FairWear worktree add C:/dev/FairWear-a1 -b fix/a1-consent merge/final-into-main
cd C:/dev/FairWear-a1 && source tools/env.sh && ohpm.bat install --all
tools/run-logic-tests.sh common  → musi być 380/380;  tools/run-logic-tests.sh watch → 6/6. Inaczej: stop, napisz co widzisz.
Przeczytaj AGENTS.md ("Project state"), .claude/skills/fairwear-ui/SKILL.md (przed zmianą UI)
oraz C:\dev\fairwear-specs\14-FIXY_PO_AUDYCIE.md SEKCJE 1–4 — to Twoja szczegółowa specyfikacja (kod F1 jest tam rozpisany).
Sekcji 5, 6, 7 z pliku 14 NIE robisz (dokumenty, wydanie i git przejmuje Agent 3; baza to teraz merge/final-into-main, nie feature/engine-reports).

## Twoje pliki (tylko te)
- common/src/main/ets/health/HealthSimPayload.ets (+ identyczna kopia w healthsim/entry/src/main/ets/fw/health/ i wszędzie, gdzie ten plik występuje w healthsim/*/fw/)
- common/src/main/ets/report/EngineReports.ets, card/CardDigest.ets, claim/PartnerVerifier.ets,
  claim/ClaimValidation.ets (tylko F7, z kopiami), wear/WearMonth.ets (tylko F8, z kopiami)
- entry/src/main/ets/report/* (EngineReportService, ServiceLocator, ReportTexts), nav/CardSync.ets,
  addon/AddonSession.ets, view/DataConsentPage.ets, share/ShareService.ets (F6), platform/Bytes.ets i CryptoUtil.ets (usunięcie, F7)
- testy: common/src/test/ConsentScopes.test.ets (nowy), CardDigest.test.ets, testy partnera (ClaimVerifier/ClaimHardening)
- common/Index.ets: JEDNA linia eksportu dayWithScopes, tuż obok istniejącego eksportu z HealthSimPayload (koniec pliku należy do Agenta 2)
- common/src/test/List.test.ets: Twój wpis tuż po wpisie HealthSimPayload (koniec pliku należy do Agenta 2)
- healthsim/WKLEJKA_HEALTH_SIM.md: git rm (F3)
NIE ruszasz: README.md, AGENTS.md, AI_WORKFLOW.md, HACKATHON_BRIEF.md, docs/*.md, docs/test-results.txt, .claude/ (Agent 3),
ReportView.ets, pages/Index.ets, DemoActions.ets, nic w common/visits ani present/DayDial* (Agent 2),
healthsim/*/pages, ui, data (Agent 3). Innych worktree (FairWear-hes, -card, -share, -tour, -main) nie dotykasz.

## Zadania (kolejność = priorytet; szczegóły w pliku 14)
F1 (P0, gotowe do 08:15) Przełączniki zgody działają na obu ścieżkach i po "Close the day":
   dayWithScopes eksportowane; ScopedPersonaDays w EngineReports; engineSession/engineSessionFrom(…, scopes);
   EngineReportService.useScopes; ServiceLocator.useBuiltIn + zakresy w sandboxie healthsim/scopes.json (odtwarzane po restarcie,
   ALL przy błędzie lub rozłączeniu); AddonSession.confirmDataConsent → useHealthSim(withScopes(...), scopes) albo useBuiltIn(scopes).
   Testy ConsentScopes: bez zakresów 6 person jak w tabeli niżej, Ewa po 1 closeDay B/64; Ania bez HRV A/93, 90%, High na OBU ścieżkach;
   Ania tylko STEPS, RESTING_HEART_RATE, SLEEP, ACTIVITY_MINUTES: A/96, 70%, Medium i po 8 closeDay nadal 70%, validCount vo2max/hrv/hrRecovery = 0;
   Ania bez SLEEP: brak wyniku, 73%; każdy typ wyłączony → 3 ostatnie dni po 3 closeDay mają HES_MISSING w jego polach. HealthSimCopies 2/2.
   Jeśli F1 nie jest zielony o 08:15: wycofaj F1 i zapisz to w handoffie (Agent 3 opisze ograniczenie uczciwie w docs).
F2 (P0) Karta na ekranie głównym: przy danych z Health Sim etykieta reportSourceLabel() ("Health Sim · Simulated data");
   buildCardDigest(…, label?: string) tylko przy statusie połączonym; limit 48 znaków; test w CardDigest.test.ets.
F3 (P0) git rm healthsim/WKLEJKA_HEALTH_SIM.md (nieaktualny, wskrzeszony merge'em).
F4 (P0, wariant 1) DataConsentPage: zdanie CAPTION pod "A data type you switch off…":
   "The wear check always uses when the watch was on the wrist and, around each break, the resting heart rate and steps of the 24 h before it. It decides eligibility, not the score."
   Zrzut: docs/screenshots/final/a5-consent-wear-note-light.jpeg (zrzuty możesz dodawać — to nowe pliki).
F5 (P1) countUnit: HR_RECOVERY → 'workouts', VO2MAX → 'estimates' ("1 workout", "1 estimate").
F6 (P1) PartnerVerifier: użyte nonce w osobnej mapie do końca TTL; przy przepełnieniu usuwaj najstarszy NIEUŻYTY;
   test 600 + użycie + 600 + ten sam token → "Already used". registerKey: inny klucz pod tym samym kid → odmowa (obsłużona w ShareService); ten sam klucz ponownie → OK.
   Kolejność weryfikacji i teksty statusów bez zmian.
F7 (P1) Martwe teksty i pośredniki (grep przed usunięciem). ClaimValidation.isValidNonceText tylko jeśli zdążysz z kopiami.
F8 (P2, tylko jeśli czas) WearMonth: dzień ≥20 h z podejrzaną przerwą — ujednolicić licznik; inaczej wpisz zdanie do handoffu ("Known limits").

## Zasady
- Nie zmieniaj: TierClaim (7 kluczy: v, period, tier, eligible, nonce, issuedAt, kid), kolejności weryfikacji i jej tekstów,
  progów w defaults.ets i HesCurves.ets, parametrów person (HesPersonas, WearPersonas), formatu fwhs1.
- Kopie common → healthsim/*/fw/ bajt w bajt (cp + HealthSimCopies.test.ets). Zmieniasz plik kopii → zbuduj healthsim entry (cd healthsim, ohpm install --all, assembleHap entry).
- Słownictwo: wynik deterministyczny, nigdy "AI"; bez "predicts", "validated", "risk", "healthy/unhealthy". tools/check-wording.sh = 0 po każdej zmianie tekstu.
- Dni z zegarka są pokazywane, nie liczone. Logi bez wartości tętna/kroków w %{public}.
- Commit po każdym F (opisowy). Przed commitem: common + watch zielone, wording 0. ArkTS: bez any, bez destrukturyzacji, jawne typy.
- Emulatory dzielone z Agentem 2 i 3: przed użyciem C:\dev\_emu-phone.lock (treść: "A1 PHONE <godzina> F1 walk, up to 10 min"),
  max 10 min, usuń po pracy; lock młodszy niż 15 min → czekaj. Po instalacji swojej wersji (install -r) zrób świeży start (Reset demo),
  nie zakładaj stanu po innej sesji.
- Zakazy: merge do main, zmiana widoczności repo, push --force, przepisywanie historii.

## Wyniki person (regresja, wszystkie typy włączone)
Ania A/92 100% High FULL · Marek B/75 85% High flagged NONE (3 podejrzane przerwy; kalendarz 3 SUSPICIOUS + 1 SHORT) ·
Kasia B/73 70% Medium PARTIAL · Tomek B/79 90% High PARTIAL "1 point to A" · Ewa C/59 75% Medium NONE · Ola brak wyniku 43% Insufficient.
Close the day: Ewa C/59 → B/64; Tomek A/80 na 4. dniu; Ania zostaje A/92.

## Emulator (z lockiem, do 08:30)
assembleHap entry; install -r na telefon. Sprawdź: Health Sim + HRV wyłączone → Ania A/93, 90%; Close the day ×5 → nadal 90%, HRV w "Missing data"
(zrzut docs/screenshots/final/a5-close-day-hrv-off-light.jpeg); bez Health Sim ("built-in demo data") z HRV wyłączonym → A/93, 90%;
karta na ekranie głównym → "Health Sim · Simulated data" (zrzut a5-home-card-healthsim-light.jpeg); ekran zgody z F4;
Share → partner "Signature valid" → ponownie "Already used" → "Change tier" → "Invalid signature".
Health Sim zachowuje się tak samo (F1 to tylko eksport funkcji) — nie musisz go przeinstalowywać.

## Koniec (najpóźniej 08:45)
git status czysty; git push origin fix/a1-consent (bez --force). NIE merguj nigdzie — scala Agent 3.
Zapisz C:\dev\_handoff\a1.md (utwórz folder; po polsku, z blokami po angielsku do wklejenia):
1) gałąź + hash HEAD, czy push się udał; 2) testy przed/po, wording, lint; 3) tabela F1–F8 → zrobione/wycięte/zablokowane + 1 zdanie dowodu;
4) wyniki z emulatora + ścieżki zrzutów; 5) GOTOWE ZDANIA PO ANGIELSKU dla Agenta 3 do: README ("What is real…", "Security & privacy"),
docs/HES.md (zgoda filtruje też dni z "Close the day", zdanie z F4, ewentualnie Known limits z F8), docs/DEMO_SCRIPT.md (wiersze z HRV wyłączonym: A/93, 90% na obu ścieżkach),
docs/ARCHITECTURE.md (przepływ zgody: zakresy w EngineReportService, healthsim/scopes.json), docs/test-results.txt (linia z liczbami);
6) czego nie zrobiłeś i dlaczego.
```

---
---

## AGENT 2 — brakujące funkcje: zegar 24 h na telefonie + Wizyty (dowód wizyty i notatki)

```
Jesteś AGENTEM 2 z trzech sesji Claude Code pracujących RÓWNOLEGLE w repo FairWear (C:\dev\FairWear, Git Bash).
To jest polecenie do wykonania od razu. Nie czekaj na potwierdzenia, nie pisz planu do akceptacji.
Kod, komentarze, dokumenty i teksty UI po angielsku. Raport końcowy po polsku.
Budujesz DWIE brakujące rzeczy z raportu HES-Lite: (A) zegar 24 h na telefonie, (B) funkcję "Visits".
Obie są osobnymi ścieżkami: NIE zmieniają silnika HES, TierClaim, PartnerVerifier ani istniejących testów.

## Start (5 min)
git -C C:/dev/FairWear worktree add C:/dev/FairWear-a2 -b feature/a2-visits merge/final-into-main
cd C:/dev/FairWear-a2 && source tools/env.sh && ohpm.bat install --all
tools/run-logic-tests.sh common → 380/380; watch → 6/6. Inaczej: stop, napisz co widzisz.
Przeczytaj AGENTS.md ("Project state") i .claude/skills/fairwear-ui/SKILL.md. Rozpoznaj (bez zmian, max 10 min):
ProofSigner (common/platform, sign(data), ensureKey → DeviceKey.kid), Signer/SigVerifier/RandomSource/Clock używane przez
claim/PartnerVerifier.ets i claim/ShareFlow.ets (mintClaimToken), claim/SignedClaimToken.ets (marker 'fw1'), TierClaimCodec (ręczna kanonikalizacja),
funkcję SHA-256 używaną do kid (common/platform/CryptoUtil / DeviceCrypto) i jej shim w tools/logic-tests/node-ports.ts,
nawigację: pages/Index.ets (NavPathStack 'fwNav', ROUTE_* + builder routes), view/ReportView.ets, view/DemoActions.ets (Reset demo),
report/ReportDates.ets (data demo "today"), present/WatchDayPresent.ets i ui/kit/SlotTimeline.ets / RingStat.ets.

## Twoje pliki
NOWE (Twoje w całości): common/src/main/ets/visits/*, common/src/main/ets/present/DayDialModel.ets,
common/src/test/Visits.test.ets, common/src/test/DayDial.test.ets, entry/src/main/ets/visits/* (VisitService, VisitTexts),
entry/src/main/ets/view/DayDialCard.ets, VisitsPage.ets, VisitDetailsPage.ets, AddReceiptPage.ets, VisitSharePage.ets, VisitCheckPage.ets,
docs/VISITS.md, watch/src/main/ets/pages/VisitRecord.ets (tylko P3), nowe zrzuty w docs/screenshots/final/.
MINIMALNE dotknięcia istniejących: common/Index.ets (blok "// Visits and day dial" NA KOŃCU pliku), common/src/test/List.test.ets (wpisy NA KOŃCU),
pages/Index.ets (nowe ROUTE_* i gałęzie w builderze), view/ReportView.ets (wstawienie DayDialCard i karty "Visits"),
view/DemoActions.ets (jedna linia: Reset demo resetuje też wizyty), entry/src/main/module.json5 (uprawnienie remindera, P2),
watch module.json5 + main_pages.json (tylko P3).
NIE ruszasz: plików Agenta 1 (HealthSimPayload, EngineReports, CardDigest, PartnerVerifier, ClaimValidation, WearMonth, entry/report/*,
CardSync, AddonSession, DataConsentPage, ShareService, platform/Bytes|CryptoUtil w entry), healthsim/ (Agent 3),
README.md, AGENTS.md, AI_WORKFLOW.md, HACKATHON_BRIEF.md, docs/*.md poza docs/VISITS.md, docs/test-results.txt, .claude/ (Agent 3).
Teksty UI trzymaj w swoich plikach *Texts.ets (jak reszta repo), kolory z istniejących zasobów/tokenów (KitTokens, fw_color w base i dark).

## A. Zegar 24 h na telefonie (P0, time-box 30 min, gotowe do 08:05)
- common/present/DayDialModel.ets (czysta logika, testowalna w Node): wejście = najnowszy zamknięty dzień raportu (HesDay: sleepStartMin, sleepEndMin,
  sleepMinutes, steps), opcjonalne segmenty noszenia z dzisiejszego dnia zegarka, jeśli telefon je ma (WatchDayPresent / odebrane pakiety), oraz
  bieżąca minuta lokalna. Wyjście: łuki (startDeg, sweepDeg, kind: SLEEP | WORN | CHARGING | OFF), kąt znacznika "now", tekst środka.
- Sen przez północ (np. 23:30 → 07:10) daje poprawny łuk przez 00:00 (jeden ciągły albo dwa sklejone). Brak snu (HES_MISSING) → brak łuku i podpis "Sleep not measured".
- NIE wymyślaj godzinowych kroków: środek pokazuje kroki dnia ("7,954 steps"), a nie rozkład. Brak segmentów zegarka → podpis "Wear segments appear when the watch sends a day".
- DayDialCard.ets na Report pod podsumowaniem: tarcza 24 h (kreski 00/06/12/18), łuki, znacznik "now", legenda, podpis "Before launch: demo data". Działa w dark mode. Wartości na żywo NIE trafiają do HES.
- Testy DayDial.test.ets: łuk przez północ; znacznik now dla 00:00, 12:00, 23:59; Ola/brak snu → brak łuku; segmenty WORN/CHARGING/OFF mapują się na kąty.

## B. Visits (P0 logika i testy do 08:40, P1 ekrany do 09:00, P2/P3 tylko jeśli czas)
Historia na scenę: Ewa (tier C, bez benefitu) idzie na kontrolę; notatki z rozmowy zostają na telefonie z przypomnieniem o kontroli;
przychodzi w terminie; paragon weryfikuje się "u źródła" (demo); partner dostaje podpisany fakt "kontrola odbyta w terminie" bez słowa z gabinetu;
podrobiony paragon zostaje odrzucony na żywo.

### B1. common/src/main/ets/visits/ (P0) — bez importów z entry i @kit.*; daty i hash wstrzykiwane
- VisitTypes: ServiceType 'OUTPATIENT'|'CHECKUP'|'EMERGENCY'|'INPATIENT'; MedicalReceipt {billCode, billNo, checkCode, issueDate YYYY-MM-DD, issuerName, issuerId,
  payerNameMasked, serviceType, amount (string, CNY)} — model chińskiego e-paragonu medycznego (医疗收费电子票据), dane fikcyjne;
  ReceiptStatus 'VERIFIED'|'MISMATCH'|'NOT_FOUND'|'EXPIRED'|'INVALID_FORMAT'; TranscriptSegment {id, speaker 'DOCTOR'|'PATIENT', startSec, text};
  NoteItem {kind 'RECOMMENDATION'|'MEDICATION'|'TEST'|'FOLLOW_UP'|'QUESTION', text, sourceSegmentIds: string[], dueDate?};
  Visit {id, personaId, receipt?, receiptStatus?, transcript?, notes?, followUpDueDate?, followUpOfVisitId?, claimed: boolean}.
  followUpDueDate trzymaj w Visit NIEZALEŻNIE od notatek (usunięcie nagrania nie może zmienić adherence).
- ReceiptCodec: QR "FWRCPT1|billCode|billNo|checkCode|issueDate|issuerId|serviceType|amount"; parse → MedicalReceipt|null (zły prefiks, liczba pól, data, serviceType → INVALID_FORMAT); serialize.
- ReceiptVerifier (interfejs) + MockReceiptVerifier (rejestr z DemoVisits): brak (billCode,billNo) → NOT_FOUND; porównuj TYLKO pola obecne w QR
  (billCode, billNo, checkCode, issueDate, issuerId, serviceType, amount) → różnica = MISMATCH; issueDate > 365 dni przed today → EXPIRED; inaczej VERIFIED.
  issuerName i payerNameMasked uzupełniaj z rejestru dopiero po VERIFIED. Produkcyjny weryfikator: sam interfejs + komentarz.
- DemoVisits(today: string) — today podawany parametrem (data demo z raportu), zamrażany przy resetVisits(). Dane tylko dla Ewy:
  R1 Check-up CHECKUP today−30 "Hangzhou Demo Community Health Centre" (fikcyjna) 120.00 z transkryptem T1; R2 Follow-up OUTPATIENT today−3, ta sama placówka, follow-up R1;
  R3 Tampered = R2 ze zmienioną datą → MISMATCH; R4 Old CHECKUP today−400 → EXPIRED; R5 Emergency EMERGENCY today−60 → VERIFIED, ale bez prawa do claimu.
  T1: angielski, 12–18 segmentów; lekarz: 30 min spaceru dziennie, mniej soli, "lipid panel" (TYLKO ten test, bez "blood test"), "vitamin D 2000 IU once a day",
  "come back in 4 weeks"; pacjent zadaje dokładnie 2 pytania. Bez diagnoz i bez słów: AI, predict, validated, risk, healthy, unhealthy, diagnos (test to sprawdza).
- NotesExtractor (RuleBasedNotesExtractor, bez modelu i sieci): klasyfikacja PER ZDANIE z priorytetem MEDICATION > TEST > FOLLOW_UP > RECOMMENDATION;
  jeden TEST na zdanie (wygrywa bardziej szczegółowy termin); MEDICATION = <nazwa> <liczba> (mg|IU|mcg) + częstotliwość, tekst dosłowny;
  TEST ze słownika (lipid panel, blood test, ECG, X-ray, urine test, ultrasound); FOLLOW_UP "come back/see you/follow-up in N days|weeks|months" → dueDate = visitDate + N (miesiąc = 30 dni);
  RECOMMENDATION = zdania lekarza z try to/you should/I recommend/please/keep/avoid/reduce/walk, niezłapane wyżej; QUESTION = zdania PATIENT kończące się "?".
  Tylko segmenty DOCTOR dla czterech pierwszych typów. Każdy item ≥1 sourceSegmentId; duplikaty scalane; pusty transkrypt → pusta lista.
- FollowUp.adherence(dueDate, followUpVisitDate) → 'FOLLOW_UP_ON_TIME' gdy data ≤ dueDate, inaczej 'NONE'; brak powiązania → 'NONE'.
- VisitClaim — DOKŁADNIE 9 kluczy w stylu TierClaim: v, type ('visit'), visitDate, visitType, receiptRef, adherence, nonce, issuedAt, kid.
  Bez kwoty, placówki, issuerId, transkryptu, notatek. receiptRef = hex pierwszych 8 bajtów SHA-256(billCode|billNo|checkCode) (ta sama funkcja hash co dla kid).
  Claim tylko z VERIFIED i tylko CHECKUP/OUTPATIENT; EMERGENCY/INPATIENT → błąd "This visit type is never shared with partners".
  Ręczna kanonikalizacja jak w TierClaimCodec; token z własnym markerem 'fv1' (nie 'fw1'), ≤ 512 znaków.
  Podpis: ten sam klucz urządzenia i ten sam interfejs Signer co mintClaimToken (ProofSigner.sign). NIE kopiuj kodu krypto i NIE zmieniaj PartnerVerifier.
- VisitVerifier (nowa klasa w visits/, wzorowana na PartnerVerifier, z tymi samymi interfejsami SigVerifier/RandomSource/Clock i rejestracją klucza po kid):
  kolejność i komunikaty: Invalid format → Wrong claim type (np. token fw1/TierClaim) → Unknown key → Invalid signature → Nonce mismatch → Already used →
  Receipt already claimed → Signature valid. claimed = true dopiero po udanej weryfikacji; drugi token z tego samego paragonu da się wygenerować (żeby test "Receipt already claimed" był możliwy).

### B2. Testy common/src/test/Visits.test.ets (P0)
Codec (poprawny / zły prefiks / 7 pól / zła data / zły typ); Verifier (R1 VERIFIED, R3 MISMATCH, nieznany NOT_FOUND, R4 EXPIRED, QR R1 bez issuerName → nadal VERIFIED);
Extractor na T1 (dokładnie 1 MEDICATION, 1 TEST lipid panel, 1 FOLLOW_UP z dueDate = R1+28, ≥2 RECOMMENDATION, 2 QUESTION, każdy item ma źródło; pusty → 0);
T1 bez słów zakazanych; adherence (R2 today−3 ≤ today−2 → ON_TIME; później → NONE; brak linku → NONE; usunięcie transkryptu nie zmienia adherence);
claim (zbiór kluczy == lista 9; serializacja bez kwoty/placówki/tekstu T1; receiptRef deterministyczny; R5 i niezweryfikowany odrzucone; token ≤ 512);
VisitVerifier (poprawny → Signature valid; zmieniony visitType → Invalid signature; zmieniony nonce w tokenie → Invalid signature; inny oczekiwany nonce → Nonce mismatch;
ten sam token 2× → Already used; nowy token z tego samego paragonu → Receipt already claimed; token fw1 → Wrong claim type; śmieci → Invalid format).
Podpinasz w List.test.ets na końcu. Stare 380 + 6 zostają zielone.

### B3. Serwis entry/src/main/ets/visits/VisitService.ets (P0)
Stan w pamięci jak sesje raportów: visits(personaId), addReceiptFromQr(personaId, text), addDemoReceipt(personaId, demoId) (deduplikacja po (billCode,billNo)),
visit(id), buildVisitClaim(visitId, nonce), verifyVisitClaim(token) (z nonce wydanym przez VisitVerifier.issueNonce), deleteTranscript(visitId), resetVisits().
Reset demo w DemoActions resetuje też wizyty i rejestry użytych receiptRef/nonce. Dla Ewy R1 i R2 wgrane i powiązane domyślnie.

### B4. Ekrany telefonu (P1) — przez NavPathStack, nowe ROUTE_*; light i dark; tokeny z ui/kit
- Wejście: karta "Visits" na Report (widoczna dla każdej persony; u innych niż Ewa pusty stan "No visits yet").
- VisitsPage: data, typ, badge dowodu (Verified receipt / Receipt rejected / No receipt), badge Notes, badge "Follow-up on time".
- AddReceiptPage: lista demo (Check-up, Follow-up, Tampered, Old, Emergency) + pole "Paste QR text"; komunikaty: VERIFIED "Receipt verified at source (demo)";
  MISMATCH "Receipt data doesn't match the issuer's record"; NOT_FOUND "Receipt not found"; EXPIRED "Older than 12 months, can't be checked online"; INVALID_FORMAT "Not a receipt code".
- VisitDetailsPage: Proof (placówka, data, typ, kwota — tylko dla użytkownika) + "What the partner will see" (pola claimu po ludzku) + "Never shared: amount, clinic name, transcript, notes".
  Visit notes: Recommendations, Medications (as said in the visit), Tests ordered, Follow-up (data; dla R1 z podpiętym R2: "Follow-up done on time"), Questions for next visit;
  tap na item → cytat źródłowy z czasem. Stopka "Summary of what was said in your visit. Check with your doctor if anything is unclear."
  "Full transcript" rozwijany z banerem "Demo transcript"; "Delete recording and transcript" z potwierdzeniem w UI (bez systemowych alertów blokujących).
- VisitSharePage: QR z tokenem fv1 (nonce z VisitVerifier); EMERGENCY/INPATIENT → przycisk wyłączony z wyjaśnieniem. Wzoruj się na ShareView (bez jego modyfikacji).
- VisitCheckPage ("Partner check · visit"): weryfikacja pokazanego tokenu krok po kroku jak PartnerPage (bez modyfikacji PartnerPage), przycisk "Change visit date" → Invalid signature,
  ponowne pokazanie → Already used. Przy poprawnym: typ wizyty, data, adherence.
### B5. (P2) Przypomnienie: reminderAgentManager (ReminderRequestCalendar) na followUpDueDate 09:00 TYLKO gdy data jest w przyszłości względem zegara urządzenia;
  ohos.permission.PUBLISH_AGENT_REMINDER w module.json5; try/catch, przy błędzie "Reminder saved in app".
### B6. (P3, tylko jeśli wszystko wyżej zielone przed 08:50) Zegarek VisitRecord: Idle "Record visit notes" → Consent ("Ask your doctor: OK to record for your personal notes?"
  "Doctor agreed"/"Cancel") → Recording (kropka, mm:ss, "Stays on this watch", Stop) → Saved ("Saved. Notes appear on your phone (demo)").
  canIUse('SystemCapability.Multimedia.Audio.Capturer') + MICROPHONE przez requestPermissionsFromUser; brak → tryb "Demo recording" z etykietą. Bez transferu zegarek→telefon.
  Jeśli nie zdążysz: pomiń, wpisz w handoffie "watch recording: next step".

## Zasady
- Nie zmieniaj: TierClaim (7 kluczy), PartnerVerifier, kolejności weryfikacji tier claimu, progów, person, fwhs1, plików kopii healthsim/*/fw/ (nie dodawaj visits do kopii).
- Słownictwo: notatki i weryfikacja to deterministyczne reguły, nigdy "AI"; bez "predicts", "validated", "risk", "healthy/unhealthy", "diagnosis" o tym, co robi aplikacja.
  tools/check-wording.sh = 0.
- Commit po każdym punkcie (A, B1+B2, B3, B4, B5, B6). Przed commitem: common + watch zielone, wording 0, lint 0 nowych błędów. ArkTS: bez any, bez destrukturyzacji, jawne typy.
- Emulatory dzielone: C:\dev\_emu-phone.lock / _emu-watch.lock ("A2 PHONE <godzina> visits screenshots, up to 10 min"), max 10 min, lock < 15 min → czekaj.
  Po install -r swojej wersji: świeży start / Reset demo.
- Zakazy: merge do main, zmiana widoczności repo, push --force, przepisywanie historii, dotykanie innych worktree.

## Emulator i zrzuty (09:00–09:10, z lockiem)
assembleHap entry (i watch, jeśli B6). Zrzuty do docs/screenshots/final/: a6-day-dial-light.jpeg, a6-day-dial-dark.jpeg, a6-visits-list-light.jpeg,
a6-visit-notes-light.jpeg, a6-visit-notes-dark.jpeg, a6-add-receipt-mismatch-light.jpeg, a6-visit-share-light.jpeg, a6-visit-check-valid-light.jpeg (+ a6-watch-visit-record.jpeg przy B6).
docs/VISITS.md: oba przepływy, tabela "stays on this phone" vs "partner sees", zgoda lekarza na nagranie, dlaczego EMERGENCY/INPATIENT nigdy nie są udostępniane, real vs simulated.

## Koniec (najpóźniej 09:10)
git status czysty; git push origin feature/a2-visits (bez --force). NIE merguj — scala Agent 3.
Zapisz C:\dev\_handoff\a2.md (po polsku, bloki do wklejenia po angielsku): gałąź + hash, push; testy przed/po (ile nowych), wording, lint;
tabela A/B1–B6 → zrobione/wycięte; ścieżki zrzutów; GOTOWE WIERSZE PO ANGIELSKU dla Agenta 3:
README tabela "real vs simulated": Receipt verification — simulated (demo registry standing in for the national e-receipt verification platform);
VisitClaim signing and verification — real (same device key as tier claims); Visit notes — real rule-based code on the phone, demo transcript;
Follow-up reminder — real system reminder when permitted (albo "not in this build"); Watch recording — demo mode on the emulator (albo "next step");
Day dial — real drawing from the newest completed day, demo data before launch.
Do tego: wiersze do docs/DEMO_SCRIPT.md (5 kroków Ewy + 1 krok tarczy), docs/ARCHITECTURE.md (moduł visits, DayDialModel), AGENTS.md "Project state", docs/test-results.txt.
```

---
---

## AGENT 3 — Health Sim jak HUAWEI Health, wszystkie dokumenty, scalenie, HAPy, push

```
Jesteś AGENTEM 3 z trzech sesji Claude Code pracujących RÓWNOLEGLE w repo FairWear (C:\dev\FairWear, Git Bash).
To jest polecenie do wykonania od razu. Nie czekaj na potwierdzenia.
Kod, komentarze, dokumenty i teksty UI po angielsku. Raport końcowy po polsku.
Masz trzy części: (1) Health Sim bliżej układu HUAWEI Health, bez kopiowania marki, (2) wszystkie wspólne dokumenty,
(3) o 09:10 scalasz swoją gałąź i gałęzie Agentów 1 i 2, budujesz, robisz regresję, HAPy i push. Oddanie zgłoszenia o 10:30; kończysz do 09:45.

## Start (5 min)
git -C C:/dev/FairWear worktree add C:/dev/FairWear-a3 -b feature/a3-healthsim-docs merge/final-into-main
cd C:/dev/FairWear-a3 && source tools/env.sh && ohpm.bat install --all && (cd healthsim && ohpm.bat install --all)
tools/run-logic-tests.sh common → 380/380; watch → 6/6. Przeczytaj AGENTS.md, .claude/skills/fairwear-ui/SKILL.md, healthsim/README.md,
docs/DEMO_SCRIPT.md oraz C:\dev\fairwear-specs\14-FIXY_PO_AUDYCIE.md SEKCJA 5 (lista poprawek dokumentów — robisz ją Ty).

## Twoje pliki
healthsim/entry/src/main/ets/pages/*, ui/*, data/SimTexts.ets, data/SimData.ets (tylko pomocnicze funkcje prezentacji), healthsim/watch/src/main/ets/pages/* (+ nowe strony),
zasoby healthsim (resources, main_pages.json); README.md, AGENTS.md, AI_WORKFLOW.md, HACKATHON_BRIEF.md, docs/ARCHITECTURE.md, docs/DEMO_SCRIPT.md, docs/HES.md,
docs/REQUIREMENTS_CHECK.md, docs/WATCH_LINK.md, docs/test-results.txt, docs/prompts/*, .claude/skills/fairwear-ui/SKILL.md, zrzuty Health Sim.
NIE ruszasz: healthsim/*/src/main/ets/fw/* (kopie common; jedną zmienia Agent 1), healthsim AuthAbility i WatchExportAbility (kontrakt fwScopes/fwhs1 bez zmian),
healthsim/WKLEJKA_HEALTH_SIM.md (usuwa Agent 1), kodu common/ i entry/ i watch/ (Agenci 1 i 2), docs/VISITS.md (Agent 2).

## 1. Health Sim jak HUAWEI Health (do 08:30)
Cel: sędzia z Huawei od razu widzi, co Health Sim udaje — ale bez logo, nazw, kolorów marki i ikon Huawei. Baner "SIMULATED DATA · stands in for HUAWEI Health"
i zdanie "Health Sim is not a HUAWEI app" zostają.
Telefon (healthsim/entry):
- Dolne zakładki: "Health" i "Me" zamiast Today / History / Apps.
- Health, góra: karta "Activity records" z DWOMA koncentrycznymi pierścieniami: Steps (cel 10,000) i Exercise (moderate + vigorous, cel 30 min), wartości obok.
  Trzeciego pierścienia ("active hours") NIE wymyślaj — Health Sim tych danych nie ma.
- Pod spodem osobne karty metryk, każda z własnym akcentem (kolory w zasobach base i dark, neutralne, nie paleta Huawei): Heart rate (resting, bpm), Sleep (h min),
  Steps. Kafelek z VO₂max / HRV tylko jeśli dzień je ma, inaczej "—" (nigdy 0).
- Historia po stuknięciu w kartę: strona szczegółów metryki z paskami 30 dni (przenieś obecną listę History; "—" = nie zmierzono).
- Nazewnictwo: "Exercise" zamiast "Activity minutes" w Health Sim (ekran autoryzacji AuthPage też, jeśli etykiety są w SimTexts; kontraktu nie zmieniaj).
- "Watch worn" znika z metryk zdrowia. W "Me → Connected apps → FairWear" dopisz: "Shared with FairWear when you allow it: wear time per day (used by FairWear's wear check)."
- Karta FairWear w "Me → Connected apps" z podpisem "Simulated integration point · real HUAWEI Health has no such card; sharing with other apps is in its privacy settings."
  Przycisk "Open FairWear" działa jak dziś.
- Wybór osoby (6 imion) przenieś do "Me" jako "Demo person" (albo mały chip na górze Health z tą etykietą) — to element tylko na demo, ma być tak opisany.
Zegarek (healthsim/watch), okrągły czarny ekran:
- Strona 1 (start): pierścienie Steps i Exercise z wartościami — jak "Activity records".
- Przesunięcie w górę: strona 2 = obecny skrypt dnia (pierścień Worn / Charging / Off wrist) z tytułem "Wear today · for FairWear". Eksport do FairWear bez zmian.
  Swiper pionowy z loop(false) (stary HealthDemo miał pętlę stron — nie powtarzaj).
- Build: cd healthsim && hvigorw assembleHap dla entry i watch; zrzuty (z lockiem): docs/screenshots/final/a7-healthsim-health-light.jpeg, -dark.jpeg,
  a7-healthsim-metric-detail-light.jpeg, a7-healthsim-me-fairwear-light.jpeg, a7-healthsim-watch-rings.jpeg, a7-healthsim-watch-wear.jpeg.
- Przejdź połączenie: Health Sim → Open FairWear → zgoda → raport na danych Health Sim (Ania A/92) i ścieżkę odmowy ("Don't allow" → FairWear pokazuje fallback). Commit.

## 2. Dokumenty (08:30–09:10) — sprawdzaj każde zdanie z kodem, nie z listą
- Wszystkie wiersze sekcji 5 z pliku 14 (README "healthy habits" i "Two HAPs" → dwa projekty, cztery HAPy; HACKATHON_BRIEF:15 i :9; REQUIREMENTS_CHECK odwołanie i liczby;
  WATCH_LINK liczby testów z runnera; AGENTS "Project state" (ServiceLocator jest w repo, "0 or outside 25–230 bpm", healthsim/ i tools/watch-phone-relay.mjs);
  SKILL.md ścieżki zegarka (watch/src/main/ets/pages/ i watchlink/SlotRing.ets); ARCHITECTURE tabela Modules + healthsim/ jako osobny projekt).
- README "What is real and what is simulated": VO₂max i HRV są używane w HES; w prawdziwym produkcie to pomiary zegarka z HUAWEI Health, w tym demo pochodzą z Health Sim
  (symulowane). Ostatnie pole tokenu (HUKS/SOFTWARE) nie jest podpisane i jest informacyjne. 32-bitowy kid i token na okaziciela — jedno zdanie w "Security & privacy".
  Health Sim: układ zbliżony do HUAWEI Health, karta FairWear to symulowany punkt integracji.
- docs/HES.md: zdanie "All weights, curves, thresholds and minimum counts are prototype product assumptions, not clinically validated." ma być (to jedyne dozwolone użycie słowa — sprawdź, czy check-wording je przepuszcza; jeśli nie, zostaw istniejące brzmienie).
- AI_WORKFLOW.md: wiersze work logu dla rundy 3 agentów (A1 zgoda i logika, A2 tarcza i wizyty, A3 Health Sim, dokumenty, scalenie) i dla audytów claude.ai; "Lessons learned":
  merge może wskrzesić usunięty plik. Sprawdź grepem, że nigdzie nie ma "ChatGPT".
- docs/prompts/: dodaj oczyszczone kopie C:\dev\fairwear-specs\14-FIXY_PO_AUDYCIE.md i 15-TRZECH_AGENTOW.md (bez wulgaryzmów, e-maili, C:\Users\…, tokenów),
  zaktualizuj docs/prompts/README.md (kolejność, co zastąpiło co: 15 zastąpiło sekcje 5–7 z 14).
- Od 09:00 czytaj C:\dev\_handoff\a1.md i a2.md i wklej ich gotowe zdania (README, HES.md, DEMO_SCRIPT, ARCHITECTURE, AGENTS) — w swojej gałęzi, zanim zaczniesz scalanie,
  albo jako ostatni commit po scaleniu. DEMO_SCRIPT: start od nowego Health Sim (zakładka Health → Me → Open FairWear), plan B bez Health Sim, wiersze z HRV wyłączonym A/93 90%,
  5 kroków Ewy z wizytami i krok tarczy 24 h (tylko to, co Agent 2 zrobił).
- tools/check-wording.sh = 0. Commit.

## 3. Scalenie (09:10–09:30) w C:\dev\FairWear-main (tam jest wyrejestrowana merge/final-into-main)
- git -C C:/dev/FairWear-main status --short → ma być pusto (pliki raportów sesji w innych worktree ignoruj). Jeśli nie — stop i napisz.
- Jeśli handoff a1/a2 nie istnieje o 09:10: sprawdź git log -1 origin/fix/a1-consent i origin/feature/a2-visits; scal tylko gałąź, której testy przechodzą.
- Kolejność, każda z --no-ff i testami common + watch po każdej:
  git merge --no-ff feature/a3-healthsim-docs; git merge --no-ff fix/a1-consent; git merge --no-ff feature/a2-visits
  Konflikty w common/Index.ets i common/src/test/List.test.ets: zachowaj OBIE strony. Gałąź, która psuje testy albo build i nie da się jej naprawić w 10 min → git merge --abort,
  zostaje nie scalona, opisujesz to w docs (uczciwie, bez obietnic).
- Po scaleniu: tools/run-logic-tests.sh common i watch, tools/check-wording.sh, tools/lint.sh (0 błędów), assembleHap entry i watch, Health Sim entry i watch.
  HealthSimCopies musi przejść.

## 4. Regresja na emulatorach (09:30–09:40, z lockami, świeża instalacja wszystkich 4 HAPów)
Sześć person (tabela niżej) w light i dark; zgoda z HRV wyłączonym → Ania A/93 90% na obu ścieżkach; Close the day: Ewa B/64; Share → "Signature valid" → "Already used" →
"Change tier" → "Invalid signature"; odmowa w Health Sim → fallback; karta na ekranie głównym "Health Sim · Simulated data"; Ewa: Visits → notatki → Share visit proof → check valid → tamper;
tarcza 24 h; zegarek FairWear: start, tarcza, "Get today from Health Sim"; zegarek Health Sim: pierścienie i strona wear. Wpisz wynik do docs/test-results.txt (nowy wpis na górze:
gałąź, commity, liczby testów, lint, wording, buildy, przejście). Commit.

## 5. HAPy i push (do 09:45)
- C:\dev\FairWear-release\: fairwear-entry-<hash>.hap, fairwear-watch-<hash>.hap, healthsim-entry-<hash>.hap, healthsim-watch-<hash>.hap, SHA256SUMS.txt,
  BUILD_INFO.txt (commit, data, wersje SDK, "unsigned debug builds, accepted by the emulators; install with hdc -t <target> install -r <hap>").
- git push origin merge/final-into-main feature/a3-healthsim-docs — to aktualizuje otwarty PR #2. Bez --force. NIE mergujesz do main (klika właściciel). Widoczność repo bez zmian.

## Zasady
- Nie zmieniaj: TierClaim (7 kluczy), kolejności weryfikacji i jej tekstów, progów, person, fwhs1, kontraktu Health Sim (fwScopes/fwhs1, kody wyników).
- Słownictwo: bez "AI" przy wyniku, bez "predicts", "validated", "risk", "healthy/unhealthy". Dni z zegarka pokazywane, nie liczone — nigdzie nie pisz inaczej.
- Commit po każdej części. Emulatory: C:\dev\_emu-phone.lock / _emu-watch.lock ("A3 … up to 10 min"), max 10 min, lock < 15 min → czekaj; po instalacji świeży start.
- Zakazy: merge do main, gh repo edit --visibility, push --force, przepisywanie historii, praca w cudzych worktree (poza FairWear-main w kroku 3).

## Wyniki person (regresja)
Ania A/92 100% High FULL · Marek B/75 85% High flagged NONE · Kasia B/73 70% Medium PARTIAL · Tomek B/79 90% High PARTIAL "1 point to A" ·
Ewa C/59 75% Medium NONE · Ola brak wyniku 43% Insufficient. Close the day: Ewa → B/64, Tomek A/80 na 4. dniu, Ania A/92.

## Raport końcowy (po polsku, krótko)
Hash merge/final-into-main i czy push przeszedł; które gałęzie scalone, które nie i dlaczego; liczby testów przed/po, lint, wording; wynik regresji (tabela);
ścieżki zrzutów; ścieżka HAPów i SHA-256; lista dla człowieka: kliknąć merge PR #2, nagrać demo, decyzja repo prywatne vs wymóg "public source code repository",
e-mail w metadanych commitów, gdzie wrzucić HAPy (repo jest prywatne, więc release na GitHubie nie będzie widoczny dla jury).
```

---

## Dla człowieka (nie dla agentów)

- Kolejność wklejania: dowolna, wszyscy startują od razu. Agent 3 sam czeka na handoffy o 09:00–09:10.
- Decyzje, których agenci nie podejmą: merge PR #2 do `main`, nagranie demo, prywatne repo vs regulamin
  ("public source code repository"), gdzie udostępnić HAPy jury.
