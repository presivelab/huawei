# Visits and the day dial

Two additions next to the score. Neither changes HES-Lite, the tier claim (`TierClaim`, seven keys) or
`PartnerVerifier`: they are separate paths with their own code and their own tests.

- **Day dial** — a 24-hour picture of the newest completed day on the Report tab.
- **Visits** — a medical visit proved by its receipt, notes taken from the conversation by fixed rules,
  and one signed fact for a partner: a visit of a shareable kind took place and the follow-up was kept
  on time.

All data is fictional: the clinic ("Hangzhou Demo Community Health Centre"), the receipts and the
conversation were written for this repository.

## Day dial

`common/src/main/ets/present/DayDialModel.ets` (pure logic) and `entry/src/main/ets/view/DayDialCard.ets`.

| Input                                         | Where it comes from                                                |
| --------------------------------------------- | ------------------------------------------------------------------ |
| Sleep start, sleep end, sleep minutes, steps  | the newest completed day of the persona's history (`HesDay`)       |
| Wear segments (worn, charging, off the wrist) | the newest day the watch sent, when the phone has one (Watch Link) |
| Now                                           | the phone's local clock, refreshed every minute                    |

Output: arcs in degrees (0° is 00:00 at the top, clockwise, 15° per hour), the angle of the "now" marker
and the text in the middle.

- A night across midnight (23:30 to 07:10) is one arc that starts at 352.5° and runs 115° through 0°.
- A day without a measured night has no sleep arc and the card says "Sleep not measured".
- The middle shows the steps of the day ("7,954 steps"). There is no hourly distribution of steps,
  because the app does not have one.
- Without a day from the watch the card says "Wear segments appear when the watch sends a day".
- The marker and the arcs are shown and never scored. The card is labelled "Before launch: demo data".

The dial shows the newest completed day of the session the score uses.

## Visits: the two flows

### 1. A visit is kept on the phone

1. The user adds a receipt: one of the five demo receipts, or the text of a receipt's QR code
   (`FWRCPT1|billCode|billNo|checkCode|issueDate|issuerId|serviceType|amount`). The model follows the
   Chinese electronic medical receipt (医疗收费电子票据): bill code, bill number and check code identify it.
2. The receipt is checked at its source (`ReceiptVerifier`). The answer is one of:

   | Status           | Shown as                                       | When                                           |
   | ---------------- | ---------------------------------------------- | ---------------------------------------------- |
   | `VERIFIED`       | Receipt verified at source (demo)              | the issuer's record has the same seven fields  |
   | `MISMATCH`       | Receipt data doesn't match the issuer's record | a field of the code differs from the record    |
   | `NOT_FOUND`      | Receipt not found                              | no record with this bill code and bill number  |
   | `EXPIRED`        | Older than 12 months, can't be checked online  | issued more than 365 days before the demo date |
   | `INVALID_FORMAT` | Not a receipt code                             | the text does not parse                        |

   The issuer's name and the payer's masked name are not in the QR code; they are filled in from the
   record only after `VERIFIED`. A tampered copy of a real receipt never replaces the verified visit.

3. When the visit has a recording, the notes are taken from the transcript by `RuleBasedNotesExtractor`:
   sentence by sentence, one note per sentence, in this order of precedence — medication (name, dose in
   mg / IU / mcg and how often, kept word for word), test (from a fixed list; the more specific term
   wins), follow-up ("come back in N days / weeks / months", due date = visit date + N, a month is 30
   days), recommendation. A patient's sentence that ends with a question mark is a question for the next
   visit. Every note points at the sentence it came from; tapping a note shows that sentence with its
   time. No model and no network are involved, and the same transcript always gives the same notes.
4. The follow-up date is stored on the visit itself. "Delete recording and transcript" removes the
   transcript and the notes; the receipt, the follow-up date and the link between the two visits stay,
   so adherence does not change.

### 2. One signed fact goes to a partner

1. The partner issues a nonce (`VisitVerifier.issueNonce`).
2. The phone builds a `VisitClaim` with exactly nine keys and signs its canonical JSON with the device
   key — the same key and the same `Signer` port as a tier claim (`ProofSigner`, HUKS or the labelled
   software fallback).
3. The token is `fv1.<claim>.<sig>.<kid>.<source>`, at most 512 characters, shown as a QR code.
4. The partner checks it, in this order: `Invalid format` → `Wrong claim type` (a tier token `fw1` lands
   here) → `Unknown key` → `Invalid signature` → `Nonce mismatch` → `Already used` →
   `Receipt already claimed` → `Signature valid`. A receipt counts as claimed only after a successful
   check; a second token from the same receipt can be made and is refused at the seventh check.

`VisitClaim` keys: `v`, `type` (`visit`), `visitDate`, `visitType`, `receiptRef`, `adherence`, `nonce`,
`issuedAt`, `kid`. `receiptRef` is the hex of the first 8 bytes of SHA-256 over
`billCode|billNo|checkCode` (the same SHA-256 the key id is made with), so the partner can tell two
claims of one receipt apart without learning which receipt it is. `adherence` is `FOLLOW_UP_ON_TIME`
when the visit is the follow-up of an earlier one and took place on or before that visit's due date,
otherwise `NONE`.

## What stays on this phone and what the partner sees

|                                                        | Stays on this phone                 | Partner sees                                     |
| ------------------------------------------------------ | ----------------------------------- | ------------------------------------------------ |
| Kind of visit (check-up or outpatient)                 | yes                                 | yes                                              |
| Date of the visit                                      | yes                                 | yes                                              |
| Follow-up kept on time                                 | yes                                 | yes, as `FOLLOW_UP_ON_TIME` or `NONE`            |
| Receipt                                                | bill code, bill number, check code  | a 16-character reference, not the receipt number |
| Amount                                                 | yes                                 | never                                            |
| Clinic name and issuer id                              | yes                                 | never                                            |
| Payer name                                             | yes (masked)                        | never                                            |
| Transcript of the conversation                         | yes, until deleted                  | never                                            |
| Notes (recommendations, medications, tests, questions) | yes, until the recording is deleted | never                                            |
| Reason for the visit                                   | not recorded as such                | never                                            |

## The doctor's consent to a recording

A conversation is recorded only when the doctor agrees. The watch flow is written as: "Record visit
notes" → "Ask your doctor: OK to record for your personal notes?" → "Doctor agreed" or "Cancel" → the
recording, which stays on the watch. The recording is for the patient's own notes: nothing from it is
part of a claim, and the user can delete it at any time. In this build the transcript on the phone is a
demo transcript and is labelled "Demo transcript": the watch records, and nothing is sent from the watch to the phone yet.

## Why emergency and inpatient visits are never shared

A check-up or an outpatient visit says that someone looks after themselves. An emergency visit or a
hospital stay says that something went wrong, and a partner who learned of it could hold it against the
person. So the rule is in the code, not in a setting: `buildVisitClaim` refuses a visit of type
`EMERGENCY` or `INPATIENT` with "This visit type is never shared with partners", the share screen shows
no code for it, and `VisitVerifier` treats a token that names such a type as an invalid format, whoever
signed it. The receipt of such a visit can still be verified and kept on the phone.

## Real and simulated

| Part                                | State                                                                                                                                                                                     |
| ----------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Receipt verification                | simulated: a demo register in the app stands in for the national e-receipt verification platform (`MockReceiptVerifier`); the production verifier is the `ReceiptVerifier` interface only |
| VisitClaim signing and verification | real: ECDSA P-256 with the same device key as tier claims; checked by `VisitVerifier`                                                                                                     |
| Visit notes                         | real rule-based code on the phone; the transcript is a demo transcript                                                                                                                    |
| Follow-up reminder                  | real system reminder (`reminderAgentManager`, 09:00 on the due day) when the system permits it and the day is still ahead; the demo dates are in the past, so the demo sets none          |
| Watch recording | real microphone capture on the watch after the doctor agreed (`VisitRecord.ets`, app "Visit notes"), kept in the watch sandbox; "Demo recording" where there is no capture or no permission; no transfer from the watch to the phone, so the notes on the phone come from the demo transcript |
| Day dial                            | real drawing from the newest completed day; demo data before launch                                                                                                                       |
| Ledger "What left this phone"       | visit codes are written to the ledger before they are shown                                                                                                                                   |

## Code and tests

- Logic: `common/src/main/ets/visits/` (`VisitTypes`, `ReceiptCodec`, `ReceiptVerifier`, `DemoVisits`,
  `NotesExtractor`, `FollowUp`, `VisitClaim`, `VisitVerifier`, `VisitBook`) and
  `common/src/main/ets/present/DayDialModel.ets`. No system-kit imports; dates and the hash come in from
  outside.
- Phone: `entry/src/main/ets/visits/` (`VisitService`, `VisitReminder`, `VisitTexts`) and
  `entry/src/main/ets/view/` (`DayDialCard`, `VisitsCard`, `VisitsPage`, `AddReceiptPage`,
  `VisitDetailsPage`, `VisitSharePage`, `VisitCheckPage`).
- Tests: `common/src/test/DayDial.test.ets` (10), `Visits.test.ets` (34), `VisitClaim.test.ets` (21, real
  ECDSA from Node, not part of `List.test.ets`, like `ClaimVerifier.test.ets`). Run with
  `tools/run-logic-tests.sh common`.
