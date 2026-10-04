import { ReceiptStatus, Visit } from 'common';

/*
 * Routes and texts of the Visits screens. One place, so the wording can be read and checked as a whole.
 * Notes and receipt checks are fixed rules and a demo register; the texts say so and nothing more.
 */

export const ROUTE_VISITS: string = 'visits';
export const ROUTE_VISIT_DETAILS: string = 'visit-details';
export const ROUTE_ADD_RECEIPT: string = 'visit-add-receipt';
export const ROUTE_VISIT_SHARE: string = 'visit-share';
export const ROUTE_VISIT_CHECK: string = 'visit-check';

/** AppStorage: the id of the visit the pushed pages show. */
export const KEY_VISIT_SELECTED: string = 'fwVisitSelected';

// The card on the Report tab.
export const VISITS_CARD_TITLE: string = 'Visits';
export const VISITS_CARD_BODY: string = 'Receipts, visit notes and follow-ups. They stay on this phone.';
export const VISITS_CARD_LINK: string = 'Open visits';
export const NO_VISITS: string = 'No visits yet';

// The list.
export const VISITS_TITLE: string = 'Visits';
export const VISITS_INTRO: string =
  'Each visit keeps its receipt and, when the doctor agreed to a recording, the notes. A partner can only ever get a signed line: the kind of visit, its date and whether a follow-up was on time.';
export const VISITS_DEMO_NOTE: string = 'Demo data · fictional clinic and receipts';
export const VISITS_OTHER_PERSON: string = 'The demo receipts belong to Ewa. Choose Ewa to try them.';
export const ADD_RECEIPT_LABEL: string = 'Add receipt';
export const BADGE_VERIFIED: string = 'Verified receipt';
export const BADGE_REJECTED: string = 'Receipt rejected';
export const BADGE_NO_RECEIPT: string = 'No receipt';
export const BADGE_NOTES: string = 'Notes';
export const BADGE_FOLLOW_UP: string = 'Follow-up on time';
export const BADGE_SHARED: string = 'Accepted by partner';

// Add receipt.
export const ADD_TITLE: string = 'Add receipt';
export const ADD_INTRO: string =
  'A receipt is checked at its source before it counts. In this demo the source is a register inside the app.';
export const ADD_DEMO_TITLE: string = 'Demo receipts';
export const ADD_PASTE_TITLE: string = 'Paste QR text';
export const ADD_PASTE_HINT: string = 'FWRCPT1|…';
export const ADD_PASTE_BUTTON: string = 'Check receipt';
export const ADD_ALREADY: string = 'Already in your visits';
export const ADD_ADDED: string = 'Added to your visits';
export const ADD_NOT_ADDED: string = 'Nothing was added';
export const ADD_REJECTED_KEPT: string = 'Kept in your visits as a rejected receipt';

// Details.
export const DETAILS_TITLE: string = 'Visit';
export const PROOF_TITLE: string = 'Proof';
export const PROOF_ONLY_YOU: string = 'Only you see this';
export const PROOF_CLINIC: string = 'Clinic';
export const PROOF_DATE: string = 'Date';
export const PROOF_TYPE: string = 'Type';
export const PROOF_AMOUNT: string = 'Amount';
export const AMOUNT_UNIT: string = 'CNY';
export const PARTNER_SEES_TITLE: string = 'What the partner will see';
export const SHARE_VISIT_LABEL: string = 'Share with partner';
export const NOTES_TITLE: string = 'Visit notes';
export const NOTES_RECOMMENDATIONS: string = 'Recommendations';
export const NOTES_MEDICATIONS: string = 'Medications (as said in the visit)';
export const NOTES_TESTS: string = 'Tests ordered';
export const NOTES_FOLLOW_UP: string = 'Follow-up';
export const NOTES_QUESTIONS: string = 'Questions for next visit';
export const NOTES_FOOTER: string =
  'Summary of what was said in your visit. Check with your doctor if anything is unclear.';
export const NOTES_RULES: string = 'Taken from the transcript by fixed rules. Tap a note to see what was said.';
export const NOTES_NONE: string = 'No recording for this visit, so there are no notes.';
export const NOTES_DELETED: string = 'Recording and transcript deleted. The receipt and the follow-up date stay.';
export const FOLLOW_UP_DONE: string = 'Follow-up done on time';
export const FOLLOW_UP_DUE_PREFIX: string = 'Due by ';
export const FOLLOW_UP_OF_PREFIX: string = 'Follow-up of the visit on ';
export const TRANSCRIPT_LABEL: string = 'Full transcript';
export const TRANSCRIPT_BANNER: string = 'Demo transcript';
export const DELETE_LABEL: string = 'Delete recording and transcript';
export const DELETE_CONFIRM: string = 'Delete the recording and its notes? This cannot be undone.';
export const DELETE_YES: string = 'Delete';
export const DELETE_NO: string = 'Keep';
export const REMINDER_LABEL: string = 'Remind me on the follow-up day';
export const REMINDER_SET: string = 'Reminder set for 09:00 on the follow-up day';
export const REMINDER_IN_APP: string = 'Reminder saved in app';
export const REMINDER_PAST: string = 'The follow-up day has passed, so no reminder is set';
export const REMINDER_TITLE: string = 'FairWear: follow-up visit';
export const REMINDER_CONTENT: string = 'Your follow-up visit is due today.';
export const SPEAKER_DOCTOR: string = 'Doctor';
export const SPEAKER_YOU: string = 'You';

// Share.
export const SHARE_TITLE: string = 'Share visit';
export const SHARE_INTRO: string =
  'The partner gets this code and nothing else: the kind of visit, its date and the follow-up.';
export const SHARE_SIGNING: string = 'Signing with the device key…';
export const SHARE_FAILED: string = 'The code could not be made: ';
export const SHARE_USED: string = 'This code was used';
export const SHARE_NEW_CODE: string = 'New code';
export const SHARE_OPEN_CHECK: string = 'Open partner check';
export const SHARE_QR_SPOKEN: string = 'QR code with the signed visit claim';
export const SHARE_DISABLED_LABEL: string = 'Sharing is off for this visit';

// Partner check.
export const CHECK_TITLE: string = 'Partner check · visit';
export const CHECK_BAND: string = 'Demo partner';
export const CHECK_BAND_NOTE: string = 'Plays the other side: it only has the code and the public key.';
export const CHECK_USE_CODE: string = 'Use the code from this phone';
export const CHECK_NOTHING: string = 'Nothing checked yet';
export const CHECK_NO_CODE: string = 'There is no visit code on this phone yet. Open a visit and share it first.';
export const CHECKS_TITLE: string = 'Checks, in order';
export const CHECK_NOT_RUN: string = 'not run';
export const CHEAT_TITLE: string = 'Try to cheat';
export const CHEAT_NEEDS_CODE: string = 'Take the code first.';
export const CHECK_AGAIN: string = 'Show the same code again';
export const CHECK_CHANGE_DATE: string = 'Change visit date';
export const CHECK_NEW_FROM_RECEIPT: string = 'New code from the same receipt';
export const ATTEMPT_FIRST: string = 'The code from this phone';
export const ATTEMPT_AGAIN: string = 'The same code, shown again';
export const ATTEMPT_DATE: string = 'The same code with another visit date';
export const ATTEMPT_NEW: string = 'A new code made from the same receipt';
export const KEY_PREFIX: string = 'Key: ';
export const REGISTRY_SUFFIX: string = ' · from the partner\'s registry';

/** The badge of a visit's proof. */
export function proofBadge(visit: Visit): string {
  if (visit.receipt === undefined) {
    return BADGE_NO_RECEIPT;
  }
  return visit.receiptStatus === 'VERIFIED' ? BADGE_VERIFIED : BADGE_REJECTED;
}

export function isVerified(visit: Visit): boolean {
  return visit.receipt !== undefined && visit.receiptStatus === 'VERIFIED';
}

/** What the add screen says after a check, under the status sentence. */
export function addOutcome(status: ReceiptStatus, kept: boolean, duplicate: boolean): string {
  if (!kept) {
    return ADD_NOT_ADDED;
  }
  if (duplicate) {
    return status === 'VERIFIED' ? ADD_ALREADY : ADD_NOT_ADDED;
  }
  return status === 'VERIFIED' ? ADD_ADDED : ADD_REJECTED_KEPT;
}

/** "2 visits", "1 visit". */
export function visitCountText(n: number): string {
  return n === 1 ? '1 visit' : `${n} visits`;
}
