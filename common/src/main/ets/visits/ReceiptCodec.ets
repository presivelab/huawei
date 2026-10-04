import { isIsoDate, isServiceType, MedicalReceipt, ServiceType } from './VisitTypes';

/*
 * The text of a receipt's QR code, as this demo writes it:
 *
 *   FWRCPT1|billCode|billNo|checkCode|issueDate|issuerId|serviceType|amount
 *
 * Eight fields, seven separators. The issuer's name and the payer's masked name are not in the code:
 * they come from the issuer's record once the receipt has been verified there. Parsing is strict and
 * repairs nothing; a text that does not parse is "Not a receipt code".
 */

export const RECEIPT_QR_PREFIX: string = 'FWRCPT1';
const SEPARATOR: string = '|';
const FIELD_COUNT: number = 8;
const MAX_QR_CHARS: number = 256;
const AMOUNT_PATTERN: RegExp = new RegExp('^\\d{1,7}\\.\\d{2}$');
const CODE_PATTERN: RegExp = new RegExp('^[A-Za-z0-9-]{1,32}$');

export function serializeReceipt(receipt: MedicalReceipt): string {
  return [RECEIPT_QR_PREFIX, receipt.billCode, receipt.billNo, receipt.checkCode, receipt.issueDate,
    receipt.issuerId, receipt.serviceType, receipt.amount].join(SEPARATOR);
}

/** The receipt a QR text carries, or null: wrong prefix, wrong number of fields, bad date, unknown type. */
export function parseReceipt(text: string): MedicalReceipt | null {
  const clean = text.trim();
  if (clean.length === 0 || clean.length > MAX_QR_CHARS) {
    return null;
  }
  const parts = clean.split(SEPARATOR);
  if (parts.length !== FIELD_COUNT || parts[0] !== RECEIPT_QR_PREFIX) {
    return null;
  }
  const billCode = parts[1];
  const billNo = parts[2];
  const checkCode = parts[3];
  const issueDate = parts[4];
  const issuerId = parts[5];
  const serviceType = parts[6];
  const amount = parts[7];
  if (!CODE_PATTERN.test(billCode) || !CODE_PATTERN.test(billNo) || !CODE_PATTERN.test(checkCode) ||
    !CODE_PATTERN.test(issuerId)) {
    return null;
  }
  if (!isIsoDate(issueDate) || !isServiceType(serviceType) || !AMOUNT_PATTERN.test(amount)) {
    return null;
  }
  const receipt: MedicalReceipt = {
    billCode: billCode,
    billNo: billNo,
    checkCode: checkCode,
    issueDate: issueDate,
    issuerName: '',
    issuerId: issuerId,
    payerNameMasked: '',
    serviceType: serviceType as ServiceType,
    amount: amount
  };
  return receipt;
}
