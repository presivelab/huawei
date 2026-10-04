import { DemoVisits, DEMO_RECEIPT_IDS, DEMO_R3, emptyVisit } from './DemoVisits';
import { followUpDueDateOf, NotesExtractor } from './NotesExtractor';
import { parseReceipt } from './ReceiptCodec';
import { ReceiptVerifier } from './ReceiptVerifier';
import { MedicalReceipt, ReceiptStatus, Visit } from './VisitTypes';

/*
 * The visits of the demo, in memory: which receipts the user added, what the check at the source said,
 * the transcript and the notes of a visit, and which visit is the follow-up of which.
 *
 * Pure logic over three parts given from outside: the demo data, the receipt verifier and the notes
 * extractor. The phone's VisitService wraps one VisitBook; the tests use it directly.
 */

export interface AddReceiptResult {
  status: ReceiptStatus;
  /** The visit this receipt belongs to after the call; null when nothing was kept. */
  visit: Visit | null;
  /** True when a visit with this bill code and bill number was already there. */
  duplicate: boolean;
}

function sameReceipt(a: MedicalReceipt, b: MedicalReceipt): boolean {
  return a.billCode === b.billCode && a.billNo === b.billNo;
}

export class VisitBook {
  private demo: DemoVisits;
  private verifier: ReceiptVerifier;
  private extractor: NotesExtractor;
  private all: Visit[] = [];

  constructor(demo: DemoVisits, verifier: ReceiptVerifier, extractor: NotesExtractor) {
    this.demo = demo;
    this.verifier = verifier;
    this.extractor = extractor;
  }

  /** The demo date every check runs on. */
  today(): string {
    return this.demo.today;
  }

  /** The visits of one persona, newest first; a visit without a receipt comes last. */
  visits(personaId: string): Visit[] {
    const out: Visit[] = [];
    for (let i = 0; i < this.all.length; i++) {
      if (this.all[i].personaId === personaId) {
        out.push(this.all[i]);
      }
    }
    out.sort((a: Visit, b: Visit): number => {
      const da = a.receipt === undefined ? '' : a.receipt.issueDate;
      const db = b.receipt === undefined ? '' : b.receipt.issueDate;
      if (da === db) {
        return 0;
      }
      return da < db ? 1 : -1;
    });
    return out;
  }

  visit(id: string): Visit | null {
    for (let i = 0; i < this.all.length; i++) {
      if (this.all[i].id === id) {
        return this.all[i];
      }
    }
    return null;
  }

  /**
   * A scanned or pasted QR text. The receipt is checked at the source first. A text that is not a receipt
   * code keeps nothing. A receipt whose bill code and number are already in the list never replaces a
   * verified visit: the tampered copy of a real receipt is refused and the real one stays.
   */
  async addReceiptFromQr(personaId: string, text: string): Promise<AddReceiptResult> {
    const parsed = parseReceipt(text);
    if (parsed === null) {
      const bad: AddReceiptResult = { status: 'INVALID_FORMAT', visit: null, duplicate: false };
      return bad;
    }
    const check = await this.verifier.verify(parsed, this.demo.today);
    const receipt = check.receipt === null ? parsed : check.receipt;
    const have = this.find(personaId, receipt);
    if (have !== null && (have.receiptStatus === 'VERIFIED' || check.status !== 'VERIFIED')) {
      const kept: AddReceiptResult = { status: check.status, visit: have, duplicate: true };
      return kept;
    }
    const visit = have === null ? emptyVisit(`${personaId}-${receipt.billCode}-${receipt.billNo}`, personaId) : have;
    visit.receipt = receipt;
    visit.receiptStatus = check.status;
    if (have === null) {
      this.all.push(visit);
    }
    if (check.status === 'VERIFIED') {
      this.attachDemoParts(visit, receipt);
    }
    this.relink(personaId);
    const added: AddReceiptResult = { status: check.status, visit: visit, duplicate: have !== null };
    return added;
  }

  /** One of the demo receipts, added through the same path as a scanned code. */
  addDemoReceipt(personaId: string, demoId: string): Promise<AddReceiptResult> {
    return this.addReceiptFromQr(personaId, this.demo.qrText(demoId));
  }

  /**
   * Deletes the recording of a visit: the transcript and the notes taken from it. The receipt, the due
   * date of the follow-up and the link between visits stay, so adherence does not change.
   */
  deleteTranscript(visitId: string): boolean {
    const visit = this.visit(visitId);
    if (visit === null || visit.transcript === undefined) {
      return false;
    }
    visit.transcript = undefined;
    visit.notes = undefined;
    return true;
  }

  /** A partner accepted a claim made from this visit's receipt. */
  markClaimed(visitId: string): void {
    const visit = this.visit(visitId);
    if (visit !== null) {
      visit.claimed = true;
    }
  }

  private find(personaId: string, receipt: MedicalReceipt): Visit | null {
    for (let i = 0; i < this.all.length; i++) {
      const r = this.all[i].receipt;
      if (this.all[i].personaId === personaId && r !== undefined && sameReceipt(r, receipt)) {
        return this.all[i];
      }
    }
    return null;
  }

  // The demo receipt a verified receipt is, by bill code and bill number; empty for any other receipt.
  private demoIdOf(receipt: MedicalReceipt): string {
    for (let i = 0; i < DEMO_RECEIPT_IDS.length; i++) {
      const id = DEMO_RECEIPT_IDS[i];
      const record = id === DEMO_R3 ? null : this.demo.record(id);
      if (record !== null && sameReceipt(record, receipt)) {
        return id;
      }
    }
    return '';
  }

  // The recording that belongs to a demo receipt, and the notes taken from it by the rules.
  private attachDemoParts(visit: Visit, receipt: MedicalReceipt): void {
    const demoId = this.demoIdOf(receipt);
    const transcript = demoId.length === 0 ? [] : this.demo.transcript(demoId);
    if (transcript.length === 0) {
      return;
    }
    const notes = this.extractor.extract(transcript, receipt.issueDate);
    visit.transcript = transcript;
    visit.notes = notes;
    const due = followUpDueDateOf(notes);
    if (due.length > 0) {
      visit.followUpDueDate = due;
    }
  }

  // Follow-up links between the persona's verified visits, whichever was added first.
  private relink(personaId: string): void {
    for (let i = 0; i < this.all.length; i++) {
      const visit = this.all[i];
      const receipt = visit.receipt;
      if (visit.personaId !== personaId || receipt === undefined || visit.receiptStatus !== 'VERIFIED') {
        continue;
      }
      const earlierId = this.demo.followUpOf(this.demoIdOf(receipt));
      const earlierRecord = earlierId.length === 0 ? null : this.demo.record(earlierId);
      const earlier = earlierRecord === null ? null : this.find(personaId, earlierRecord);
      if (earlier !== null && earlier.receiptStatus === 'VERIFIED') {
        visit.followUpOfVisitId = earlier.id;
      }
    }
  }
}
