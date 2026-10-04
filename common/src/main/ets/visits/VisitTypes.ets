/*
 * Visits: the types.
 *
 * A visit is a medical appointment the user keeps on the phone: the receipt that proves it took place,
 * the transcript of what was said (when the doctor agreed to a recording) and the notes taken from it by
 * fixed rules. Everything here stays on the phone. The one thing a partner can ever receive is the
 * VisitClaim (VisitClaim.ets): that a visit of a shareable kind took place and whether a follow-up was
 * kept on time.
 *
 * MedicalReceipt models the Chinese electronic medical receipt (医疗收费电子票据): bill code, bill number
 * and check code identify it and let anyone check it at the issuing platform. All data in this repository
 * is fictional.
 */

export type ServiceType = 'OUTPATIENT' | 'CHECKUP' | 'EMERGENCY' | 'INPATIENT';
export const SERVICE_TYPES: string[] = ['OUTPATIENT', 'CHECKUP', 'EMERGENCY', 'INPATIENT'];
/** The only kinds of visit a claim can be made from. Emergency and inpatient care are never shared. */
export const SHAREABLE_SERVICE_TYPES: string[] = ['CHECKUP', 'OUTPATIENT'];

export interface MedicalReceipt {
  billCode: string;           // 票据代码
  billNo: string;             // 票据号码
  checkCode: string;          // 校验码
  issueDate: string;          // YYYY-MM-DD
  issuerName: string;         // empty until the receipt is verified at the source
  issuerId: string;
  payerNameMasked: string;    // empty until the receipt is verified at the source
  serviceType: ServiceType;
  amount: string;             // CNY, two decimals, as text: never a float
}

export type ReceiptStatus = 'VERIFIED' | 'MISMATCH' | 'NOT_FOUND' | 'EXPIRED' | 'INVALID_FORMAT';

export type Speaker = 'DOCTOR' | 'PATIENT';

export interface TranscriptSegment {
  id: string;
  speaker: Speaker;
  startSec: number;
  text: string;
}

export type NoteKind = 'RECOMMENDATION' | 'MEDICATION' | 'TEST' | 'FOLLOW_UP' | 'QUESTION';

export interface NoteItem {
  kind: NoteKind;
  text: string;
  sourceSegmentIds: string[];   // at least one: every note points at what was said
  dueDate?: string;             // FOLLOW_UP only, YYYY-MM-DD
}

export interface Visit {
  id: string;
  personaId: string;
  receipt?: MedicalReceipt;
  receiptStatus?: ReceiptStatus;
  transcript?: TranscriptSegment[];
  notes?: NoteItem[];
  // Kept on the visit itself, not read from the notes: deleting the recording must not change adherence.
  followUpDueDate?: string;
  followUpOfVisitId?: string;
  claimed: boolean;             // true once a partner has accepted a claim made from this receipt
}

export type Adherence = 'FOLLOW_UP_ON_TIME' | 'NONE';
export const ADHERENCE_ON_TIME: Adherence = 'FOLLOW_UP_ON_TIME';
export const ADHERENCE_NONE: Adherence = 'NONE';
export const ADHERENCE_VALUES: string[] = ['FOLLOW_UP_ON_TIME', 'NONE'];

export function isServiceType(text: string): boolean {
  return SERVICE_TYPES.indexOf(text) >= 0;
}

export function isShareableServiceType(text: string): boolean {
  return SHAREABLE_SERVICE_TYPES.indexOf(text) >= 0;
}

/** The kind of visit as the user reads it. */
export function serviceTypeLabel(type: string): string {
  if (type === 'CHECKUP') {
    return 'Check-up';
  }
  if (type === 'OUTPATIENT') {
    return 'Outpatient visit';
  }
  if (type === 'EMERGENCY') {
    return 'Emergency care';
  }
  return type === 'INPATIENT' ? 'Hospital stay' : 'Visit';
}

// ---- Dates: "YYYY-MM-DD" text and UTC arithmetic, so nothing depends on the phone's time zone. ----

const DAY_MS: number = 86400000;
const MONTHS_SHORT: string[] = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

/** UTC milliseconds of a "YYYY-MM-DD" date, or -1 when the text is not a real calendar date. */
export function isoDateMs(date: string): number {
  if (date.length !== 10 || date.charAt(4) !== '-' || date.charAt(7) !== '-') {
    return -1;
  }
  for (let i = 0; i < date.length; i++) {
    const c = date.charCodeAt(i);
    if (i !== 4 && i !== 7 && (c < 48 || c > 57)) {
      return -1;
    }
  }
  const y = Number.parseInt(date.substring(0, 4), 10);
  const m = Number.parseInt(date.substring(5, 7), 10);
  const d = Number.parseInt(date.substring(8, 10), 10);
  if (m < 1 || m > 12 || d < 1 || d > 31) {
    return -1;
  }
  const ms = Date.UTC(y, m - 1, d);
  const back = new Date(ms);
  // 2026-02-31 would roll over into March: not a date.
  if (back.getUTCFullYear() !== y || back.getUTCMonth() !== m - 1 || back.getUTCDate() !== d) {
    return -1;
  }
  return ms;
}

export function isIsoDate(date: string): boolean {
  return isoDateMs(date) >= 0;
}

/** The date `days` later (earlier when negative). Empty when `date` is not a date. */
export function addDays(date: string, days: number): string {
  const ms = isoDateMs(date);
  if (ms < 0) {
    return '';
  }
  const d = new Date(ms + Math.round(days) * DAY_MS);
  return `${d.getUTCFullYear()}-${pad2(d.getUTCMonth() + 1)}-${pad2(d.getUTCDate())}`;
}

/** Whole days from `from` to `to` (positive when `to` is later). NaN when either is not a date. */
export function daysBetween(from: string, to: string): number {
  const a = isoDateMs(from);
  const b = isoDateMs(to);
  if (a < 0 || b < 0) {
    return NaN;
  }
  return Math.round((b - a) / DAY_MS);
}

/** "2026-09-04" as "4 Sep 2026". Text that is not a date is returned as it is. */
export function visitDateText(date: string): string {
  const ms = isoDateMs(date);
  if (ms < 0) {
    return date;
  }
  const d = new Date(ms);
  return `${d.getUTCDate()} ${MONTHS_SHORT[d.getUTCMonth()]} ${d.getUTCFullYear()}`;
}
