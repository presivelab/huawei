import { parseReceipt } from './ReceiptCodec';
import { daysBetween, MedicalReceipt, ReceiptStatus } from './VisitTypes';

/*
 * Checking a receipt "at the source": the issuer's own record decides, not the text of the code.
 *
 * ReceiptVerifier is the port. MockReceiptVerifier answers from a small register held in the app and
 * stands in for the national e-receipt verification platform in the demo. A production verifier would
 * implement the same interface with a call to that platform (bill code, bill number and check code go
 * out, the issuer's record comes back); it is not part of this repository.
 */

/** A receipt older than this cannot be checked online any more. */
export const RECEIPT_MAX_AGE_DAYS: number = 365;

export interface ReceiptCheck {
  status: ReceiptStatus;
  /** The receipt as it stands after the check; the issuer's name and the payer are filled in only when VERIFIED. */
  receipt: MedicalReceipt | null;
}

export interface ReceiptVerifier {
  /** `today` is the date of the check, YYYY-MM-DD. */
  verify(receipt: MedicalReceipt, today: string): Promise<ReceiptCheck>;
}

function copyReceipt(r: MedicalReceipt): MedicalReceipt {
  const out: MedicalReceipt = {
    billCode: r.billCode,
    billNo: r.billNo,
    checkCode: r.checkCode,
    issueDate: r.issueDate,
    issuerName: r.issuerName,
    issuerId: r.issuerId,
    payerNameMasked: r.payerNameMasked,
    serviceType: r.serviceType,
    amount: r.amount
  };
  return out;
}

export class MockReceiptVerifier implements ReceiptVerifier {
  private register: MedicalReceipt[];

  /** `register`: the issuer's records, one per receipt that was really issued. */
  constructor(register: MedicalReceipt[]) {
    this.register = register;
  }

  /*
   * The order of the answers:
   *   no record with this bill code and bill number          NOT_FOUND
   *   a field of the code differs from the record            MISMATCH
   *   issued more than 365 days before today                 EXPIRED
   *   otherwise                                              VERIFIED
   * Only the seven fields a QR code carries are compared. The issuer's name and the payer's masked name
   * are taken from the record after VERIFIED, so a code without them verifies like any other.
   */
  verify(receipt: MedicalReceipt, today: string): Promise<ReceiptCheck> {
    let record: MedicalReceipt | null = null;
    for (let i = 0; i < this.register.length; i++) {
      if (this.register[i].billCode === receipt.billCode && this.register[i].billNo === receipt.billNo) {
        record = this.register[i];
        break;
      }
    }
    if (record === null) {
      const missing: ReceiptCheck = { status: 'NOT_FOUND', receipt: copyReceipt(receipt) };
      return Promise.resolve(missing);
    }
    if (record.checkCode !== receipt.checkCode || record.issueDate !== receipt.issueDate ||
      record.issuerId !== receipt.issuerId || record.serviceType !== receipt.serviceType ||
      record.amount !== receipt.amount) {
      const differs: ReceiptCheck = { status: 'MISMATCH', receipt: copyReceipt(receipt) };
      return Promise.resolve(differs);
    }
    const age = daysBetween(receipt.issueDate, today);
    if (isNaN(age) || age > RECEIPT_MAX_AGE_DAYS) {
      const old: ReceiptCheck = { status: 'EXPIRED', receipt: copyReceipt(receipt) };
      return Promise.resolve(old);
    }
    const good: ReceiptCheck = { status: 'VERIFIED', receipt: copyReceipt(record) };
    return Promise.resolve(good);
  }
}

/** A pasted or scanned QR text, checked: text that is not a receipt code never reaches the verifier. */
export async function checkReceiptText(text: string, verifier: ReceiptVerifier, today: string): Promise<ReceiptCheck> {
  const receipt = parseReceipt(text);
  if (receipt === null) {
    const bad: ReceiptCheck = { status: 'INVALID_FORMAT', receipt: null };
    return bad;
  }
  return verifier.verify(receipt, today);
}

/** What the user reads after a check. */
export function receiptStatusMessage(status: string): string {
  if (status === 'VERIFIED') {
    return 'Receipt verified at source (demo)';
  }
  if (status === 'MISMATCH') {
    return 'Receipt data doesn\'t match the issuer\'s record';
  }
  if (status === 'NOT_FOUND') {
    return 'Receipt not found';
  }
  if (status === 'EXPIRED') {
    return 'Older than 12 months, can\'t be checked online';
  }
  return 'Not a receipt code';
}
