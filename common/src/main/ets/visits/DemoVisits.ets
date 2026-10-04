import { serializeReceipt } from './ReceiptCodec';
import { addDays, MedicalReceipt, ServiceType, Speaker, TranscriptSegment, Visit } from './VisitTypes';

/*
 * The demo data of Visits. Everything is fictional: the clinic, the receipts and the conversation.
 *
 * All dates are counted back from `today`, the demo date of the report, so the story reads the same on
 * any day it is shown. Only Ewa has visits.
 *
 *   R1  Check-up        today-30   the visit with the transcript T1; the doctor asks her back in 4 weeks
 *   R2  Follow-up       today-3    the same clinic; the follow-up of R1, inside the 4 weeks
 *   R3  Tampered        R2 with another date on the code: the issuer's record says otherwise
 *   R4  Old             today-400  too old to be checked online
 *   R5  Emergency       today-60   verifies, and is never shared with a partner
 */

export const VISITS_PERSONA_ID: string = 'ewa';

export const DEMO_R1: string = 'R1';
export const DEMO_R2: string = 'R2';
export const DEMO_R3: string = 'R3';
export const DEMO_R4: string = 'R4';
export const DEMO_R5: string = 'R5';
export const DEMO_RECEIPT_IDS: string[] = [DEMO_R1, DEMO_R2, DEMO_R3, DEMO_R4, DEMO_R5];

export const DEMO_ISSUER_NAME: string = 'Hangzhou Demo Community Health Centre';
export const DEMO_ISSUER_ID: string = 'DEMO-HZ-0001';
const DEMO_PAYER: string = 'Ewa K***';
const DEMO_BILL_CODE: string = '33060126';

const R1_DAYS_AGO: number = 30;
const R2_DAYS_AGO: number = 3;
const R3_DAYS_AGO: number = 10;
const R4_DAYS_AGO: number = 400;
const R5_DAYS_AGO: number = 60;
/** What the doctor says in T1: "Come back in 4 weeks". */
export const DEMO_FOLLOW_UP_DAYS: number = 28;

/** The name of a demo receipt on the "Add receipt" screen. */
export function demoReceiptLabel(demoId: string): string {
  if (demoId === DEMO_R1) {
    return 'Check-up';
  }
  if (demoId === DEMO_R2) {
    return 'Follow-up';
  }
  if (demoId === DEMO_R3) {
    return 'Tampered';
  }
  if (demoId === DEMO_R4) {
    return 'Old';
  }
  return demoId === DEMO_R5 ? 'Emergency' : demoId;
}

/** One line under the name: what this demo receipt shows. */
export function demoReceiptHint(demoId: string): string {
  if (demoId === DEMO_R1) {
    return 'The check-up with the visit notes';
  }
  if (demoId === DEMO_R2) {
    return 'The follow-up, kept inside 4 weeks';
  }
  if (demoId === DEMO_R3) {
    return 'The follow-up receipt with a changed date';
  }
  if (demoId === DEMO_R4) {
    return 'A check-up from more than a year ago';
  }
  return demoId === DEMO_R5 ? 'Verifies, and is never shared' : '';
}

function line(id: string, speaker: Speaker, startSec: number, text: string): TranscriptSegment {
  const segment: TranscriptSegment = { id: id, speaker: speaker, startSec: startSec, text: text };
  return segment;
}

/** T1: the conversation of the check-up R1. A demo transcript, written for this repository. */
export function demoTranscriptT1(): TranscriptSegment[] {
  return [
    line('t1-01', 'DOCTOR', 0, 'Good morning, Ewa. Thanks for coming in for your check-up.'),
    line('t1-02', 'PATIENT', 6, 'Good morning. I have been feeling tired in the afternoons lately.'),
    line('t1-03', 'DOCTOR', 14, 'Thank you for telling me. Let us go through your routine.'),
    line('t1-04', 'PATIENT', 21, 'I sit most of the day at work and I rarely move in the evenings.'),
    line('t1-05', 'DOCTOR', 30, 'Try to walk for 30 minutes every day, at a pace where you can still talk.'),
    line('t1-06', 'PATIENT', 40, 'Does it have to be 30 minutes in one go?'),
    line('t1-07', 'DOCTOR', 46, 'No, three walks of ten minutes are fine.'),
    line('t1-08', 'DOCTOR', 52, 'You should reduce salt, so please cook with less of it and avoid salty snacks.'),
    line('t1-09', 'PATIENT', 62, 'All right, I can do that.'),
    line('t1-10', 'DOCTOR', 66, 'I am ordering a lipid panel, and the lab will take the sample this week.'),
    line('t1-11', 'DOCTOR', 76, 'Take vitamin D 2000 IU once a day with breakfast.'),
    line('t1-12', 'PATIENT', 86, 'Should I take it in the morning or in the evening?'),
    line('t1-13', 'DOCTOR', 92, 'In the morning, with food.'),
    line('t1-14', 'DOCTOR', 98, 'Keep a regular bedtime as well.'),
    line('t1-15', 'DOCTOR', 106, 'Come back in 4 weeks and we will look at the results together.'),
    line('t1-16', 'PATIENT', 114, 'Thank you, doctor. I will book the visit today.'),
    line('t1-17', 'DOCTOR', 120, 'You are welcome. See you then.')
  ];
}

export class DemoVisits {
  /** The demo date everything is counted from, YYYY-MM-DD. Fixed for the life of this object. */
  readonly today: string;

  constructor(today: string) {
    this.today = today;
  }

  private make(billNo: string, checkCode: string, daysAgo: number, serviceType: ServiceType,
    amount: string): MedicalReceipt {
    const receipt: MedicalReceipt = {
      billCode: DEMO_BILL_CODE,
      billNo: billNo,
      checkCode: checkCode,
      issueDate: addDays(this.today, -daysAgo),
      issuerName: DEMO_ISSUER_NAME,
      issuerId: DEMO_ISSUER_ID,
      payerNameMasked: DEMO_PAYER,
      serviceType: serviceType,
      amount: amount
    };
    return receipt;
  }

  /** The receipt as the issuer holds it. R3 has no record of its own: it is R2 with a changed date. */
  record(demoId: string): MedicalReceipt | null {
    if (demoId === DEMO_R1) {
      return this.make('0026100301', 'c41f07', R1_DAYS_AGO, 'CHECKUP', '120.00');
    }
    if (demoId === DEMO_R2 || demoId === DEMO_R3) {
      return this.make('0026100302', '9be2d5', R2_DAYS_AGO, 'OUTPATIENT', '60.00');
    }
    if (demoId === DEMO_R4) {
      return this.make('0025083004', '57aa10', R4_DAYS_AGO, 'CHECKUP', '95.00');
    }
    if (demoId === DEMO_R5) {
      return this.make('0026080505', 'e0346b', R5_DAYS_AGO, 'EMERGENCY', '480.00');
    }
    return null;
  }

  /** The issuer's register: the four receipts that were really issued. */
  register(): MedicalReceipt[] {
    const out: MedicalReceipt[] = [];
    const ids: string[] = [DEMO_R1, DEMO_R2, DEMO_R4, DEMO_R5];
    for (let i = 0; i < ids.length; i++) {
      const record = this.record(ids[i]);
      if (record !== null) {
        out.push(record);
      }
    }
    return out;
  }

  /** The QR text of a demo receipt, as a camera would read it. Empty for an unknown id. */
  qrText(demoId: string): string {
    const record = this.record(demoId);
    if (record === null) {
      return '';
    }
    if (demoId === DEMO_R3) {
      record.issueDate = addDays(this.today, -R3_DAYS_AGO);
    }
    return serializeReceipt(record);
  }

  transcript(demoId: string): TranscriptSegment[] {
    return demoId === DEMO_R1 ? demoTranscriptT1() : [];
  }

  /** The demo receipt this one is the follow-up of; empty when it is not a follow-up. */
  followUpOf(demoId: string): string {
    return demoId === DEMO_R2 ? DEMO_R1 : '';
  }

  /** The id of the visit a demo receipt becomes. */
  static visitId(personaId: string, demoId: string): string {
    return `${personaId}-${demoId}`;
  }

  /** True for the persona the demo visits belong to. Everyone else starts with no visits. */
  static hasVisits(personaId: string): boolean {
    return personaId === VISITS_PERSONA_ID;
  }
}

/** A visit as it is before anything is attached to it. */
export function emptyVisit(id: string, personaId: string): Visit {
  const visit: Visit = { id: id, personaId: personaId, claimed: false };
  return visit;
}
