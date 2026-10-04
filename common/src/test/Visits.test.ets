// Visits, the part that needs no signature: the receipt code, the check at the source, the notes taken
// from the demo transcript by rules, and follow-up adherence. The claim and its verifier are in
// VisitClaim.test.ets (they need the Node ports).
import { describe, it, expect } from '@ohos/hypium';
import {
  DEMO_FOLLOW_UP_DAYS,
  DEMO_ISSUER_NAME,
  DEMO_R1,
  DEMO_R2,
  DEMO_R3,
  DEMO_R4,
  DEMO_R5,
  demoTranscriptT1,
  DemoVisits,
  VISITS_PERSONA_ID
} from '../main/ets/visits/DemoVisits';
import {
  adherence,
  followUpDoneOnTime,
  REMINDER_HOUR,
  reminderMoment,
  reminderMomentAhead,
  visitAdherence
} from '../main/ets/visits/FollowUp';
import {
  followUpDays,
  notesOfKind,
  RuleBasedNotesExtractor,
  segmentById,
  sentencesOf,
  sourceQuote
} from '../main/ets/visits/NotesExtractor';
import { parseReceipt, serializeReceipt } from '../main/ets/visits/ReceiptCodec';
import { checkReceiptText, MockReceiptVerifier, receiptStatusMessage } from '../main/ets/visits/ReceiptVerifier';
import { VisitBook } from '../main/ets/visits/VisitBook';
import {
  ADHERENCE_NONE,
  ADHERENCE_ON_TIME,
  addDays,
  daysBetween,
  isIsoDate,
  NoteItem,
  TranscriptSegment,
  Visit,
  visitDateText
} from '../main/ets/visits/VisitTypes';

const TODAY = '2026-10-03';
const GOOD_QR = 'FWRCPT1|33060126|0026100301|c41f07|2026-09-03|DEMO-HZ-0001|CHECKUP|120.00';

function book(): VisitBook {
  const demo = new DemoVisits(TODAY);
  return new VisitBook(demo, new MockReceiptVerifier(demo.register()), new RuleBasedNotesExtractor());
}

async function ewaBook(): Promise<VisitBook> {
  const b = book();
  await b.addDemoReceipt(VISITS_PERSONA_ID, DEMO_R1);
  await b.addDemoReceipt(VISITS_PERSONA_ID, DEMO_R2);
  return b;
}

function visitOf(b: VisitBook, demoId: string): Visit {
  const record = new DemoVisits(TODAY).record(demoId);
  const all = b.visits(VISITS_PERSONA_ID);
  for (let i = 0; i < all.length; i++) {
    const r = all[i].receipt;
    if (record !== null && r !== undefined && r.billNo === record.billNo) {
      return all[i];
    }
  }
  throw new Error(`no visit for ${demoId}`);
}

function t1Notes(): NoteItem[] {
  return new RuleBasedNotesExtractor().extract(demoTranscriptT1(), addDays(TODAY, -30));
}

export default function visitsTest() {
  describe('Visits: dates', () => {
    it('adds days across a month and a year, and refuses what is not a date', 0, () => {
      expect(addDays('2026-10-03', -30)).assertEqual('2026-09-03');
      expect(addDays('2026-09-03', 28)).assertEqual('2026-10-01');
      expect(addDays('2026-12-31', 1)).assertEqual('2027-01-01');
      expect(daysBetween('2026-09-03', '2026-10-03')).assertEqual(30);
      expect(isIsoDate('2026-02-31')).assertFalse();
      expect(isIsoDate('2026-13-01')).assertFalse();
      expect(isIsoDate('03-10-2026')).assertFalse();
      expect(visitDateText('2026-09-03')).assertEqual('3 Sep 2026');
    });
  });

  describe('Visits: receipt code', () => {
    it('a correct code parses and serializes back to the same text', 0, () => {
      const r = parseReceipt(GOOD_QR);
      expect(r === null).assertFalse();
      if (r !== null) {
        expect(r.billCode).assertEqual('33060126');
        expect(r.billNo).assertEqual('0026100301');
        expect(r.checkCode).assertEqual('c41f07');
        expect(r.issueDate).assertEqual('2026-09-03');
        expect(r.issuerId).assertEqual('DEMO-HZ-0001');
        expect(r.serviceType).assertEqual('CHECKUP');
        expect(r.amount).assertEqual('120.00');
        expect(r.issuerName).assertEqual('');
        expect(r.payerNameMasked).assertEqual('');
        expect(serializeReceipt(r)).assertEqual(GOOD_QR);
      }
    });

    it('a wrong prefix is not a receipt code', 0, () => {
      expect(parseReceipt(GOOD_QR.replace('FWRCPT1', 'FWRCPT2'))).assertNull();
      expect(parseReceipt('hello')).assertNull();
      expect(parseReceipt('')).assertNull();
    });

    it('seven fields instead of eight are refused', 0, () => {
      expect(parseReceipt('FWRCPT1|33060126|0026100301|c41f07|2026-09-03|DEMO-HZ-0001|CHECKUP')).assertNull();
      expect(parseReceipt(GOOD_QR + '|extra')).assertNull();
    });

    it('a date that is not a date is refused', 0, () => {
      expect(parseReceipt(GOOD_QR.replace('2026-09-03', '2026-02-31'))).assertNull();
      expect(parseReceipt(GOOD_QR.replace('2026-09-03', '03.09.2026'))).assertNull();
    });

    it('an unknown service type is refused', 0, () => {
      expect(parseReceipt(GOOD_QR.replace('CHECKUP', 'DENTAL'))).assertNull();
      expect(parseReceipt(GOOD_QR.replace('CHECKUP', 'checkup'))).assertNull();
    });
  });

  describe('Visits: receipt check at the source (demo register)', () => {
    it('R1 is verified and the issuer name comes from the record', 0, async () => {
      const demo = new DemoVisits(TODAY);
      const check = await checkReceiptText(demo.qrText(DEMO_R1), new MockReceiptVerifier(demo.register()), TODAY);
      expect(check.status).assertEqual('VERIFIED');
      const r = check.receipt;
      expect(r === null).assertFalse();
      if (r !== null) {
        expect(r.issuerName).assertEqual(DEMO_ISSUER_NAME);
        expect(r.payerNameMasked.length > 0).assertTrue();
        expect(r.issueDate).assertEqual('2026-09-03');
      }
    });

    it('the QR text of R1 carries no issuer name and still verifies', 0, async () => {
      const demo = new DemoVisits(TODAY);
      const qr = demo.qrText(DEMO_R1);
      expect(qr).assertEqual(GOOD_QR);
      expect(qr.indexOf(DEMO_ISSUER_NAME)).assertEqual(-1);
      const parsed = parseReceipt(qr);
      expect(parsed === null).assertFalse();
      if (parsed !== null) {
        expect(parsed.issuerName).assertEqual('');
        const check = await new MockReceiptVerifier(demo.register()).verify(parsed, TODAY);
        expect(check.status).assertEqual('VERIFIED');
      }
    });

    it('R3, the follow-up receipt with a changed date, does not match the record', 0, async () => {
      const demo = new DemoVisits(TODAY);
      expect(demo.qrText(DEMO_R3) === demo.qrText(DEMO_R2)).assertFalse();
      const check = await checkReceiptText(demo.qrText(DEMO_R3), new MockReceiptVerifier(demo.register()), TODAY);
      expect(check.status).assertEqual('MISMATCH');
      const r = check.receipt;
      if (r !== null) {
        expect(r.issuerName).assertEqual('');
      }
    });

    it('a receipt the issuer never issued is not found', 0, async () => {
      const demo = new DemoVisits(TODAY);
      const unknown = GOOD_QR.replace('0026100301', '0099999999');
      const check = await checkReceiptText(unknown, new MockReceiptVerifier(demo.register()), TODAY);
      expect(check.status).assertEqual('NOT_FOUND');
    });

    it('R4, issued 400 days ago, is too old to be checked online', 0, async () => {
      const demo = new DemoVisits(TODAY);
      const check = await checkReceiptText(demo.qrText(DEMO_R4), new MockReceiptVerifier(demo.register()), TODAY);
      expect(check.status).assertEqual('EXPIRED');
    });

    it('R5, the emergency receipt, verifies', 0, async () => {
      const demo = new DemoVisits(TODAY);
      const check = await checkReceiptText(demo.qrText(DEMO_R5), new MockReceiptVerifier(demo.register()), TODAY);
      expect(check.status).assertEqual('VERIFIED');
    });

    it('text that is not a receipt code never reaches the verifier', 0, async () => {
      const demo = new DemoVisits(TODAY);
      const check = await checkReceiptText('not a code', new MockReceiptVerifier(demo.register()), TODAY);
      expect(check.status).assertEqual('INVALID_FORMAT');
      expect(check.receipt).assertNull();
    });

    it('every status has its sentence', 0, () => {
      expect(receiptStatusMessage('VERIFIED')).assertEqual('Receipt verified at source (demo)');
      expect(receiptStatusMessage('MISMATCH')).assertEqual('Receipt data doesn\'t match the issuer\'s record');
      expect(receiptStatusMessage('NOT_FOUND')).assertEqual('Receipt not found');
      expect(receiptStatusMessage('EXPIRED')).assertEqual('Older than 12 months, can\'t be checked online');
      expect(receiptStatusMessage('INVALID_FORMAT')).assertEqual('Not a receipt code');
    });
  });

  describe('Visits: notes by rules', () => {
    it('T1 has 12 to 18 segments and the patient asks exactly two questions', 0, () => {
      const t = demoTranscriptT1();
      expect(t.length >= 12 && t.length <= 18).assertTrue();
      let questions = 0;
      for (let i = 0; i < t.length; i++) {
        if (t[i].speaker === 'PATIENT' && t[i].text.indexOf('?') >= 0) {
          questions++;
        }
      }
      expect(questions).assertEqual(2);
    });

    it('T1 gives exactly one medication, word for word', 0, () => {
      const meds = notesOfKind(t1Notes(), 'MEDICATION');
      expect(meds.length).assertEqual(1);
      expect(meds[0].text).assertEqual('Take vitamin D 2000 IU once a day with breakfast.');
    });

    it('T1 gives exactly one test, the lipid panel', 0, () => {
      const tests = notesOfKind(t1Notes(), 'TEST');
      expect(tests.length).assertEqual(1);
      expect(tests[0].text).assertEqual('Lipid panel');
    });

    it('T1 gives one follow-up, due 28 days after the visit', 0, () => {
      const follow = notesOfKind(t1Notes(), 'FOLLOW_UP');
      expect(follow.length).assertEqual(1);
      expect(follow[0].dueDate).assertEqual(addDays(addDays(TODAY, -30), 28));
      expect(follow[0].dueDate).assertEqual('2026-10-01');
      expect(DEMO_FOLLOW_UP_DAYS).assertEqual(28);
    });

    it('T1 gives at least two recommendations and two questions', 0, () => {
      const notes = t1Notes();
      expect(notesOfKind(notes, 'RECOMMENDATION').length >= 2).assertTrue();
      expect(notesOfKind(notes, 'QUESTION').length).assertEqual(2);
    });

    it('every note points at a segment that exists, and questions come from the patient', 0, () => {
      const t = demoTranscriptT1();
      const notes = t1Notes();
      expect(notes.length > 0).assertTrue();
      for (let i = 0; i < notes.length; i++) {
        expect(notes[i].sourceSegmentIds.length >= 1).assertTrue();
        for (let k = 0; k < notes[i].sourceSegmentIds.length; k++) {
          const segment = segmentById(t, notes[i].sourceSegmentIds[k]);
          expect(segment === null).assertFalse();
          if (segment !== null) {
            expect(segment.speaker).assertEqual(notes[i].kind === 'QUESTION' ? 'PATIENT' : 'DOCTOR');
          }
        }
      }
    });

    it('an empty transcript gives no notes', 0, () => {
      expect(new RuleBasedNotesExtractor().extract([], TODAY).length).assertEqual(0);
    });

    it('one note per sentence: medication before test before follow-up before recommendation', 0, () => {
      const said: TranscriptSegment[] = [
        { id: 'a', speaker: 'DOCTOR', startSec: 0, text: 'Please take metformin 500 mg twice a day and come back in 2 weeks.' },
        { id: 'b', speaker: 'DOCTOR', startSec: 5, text: 'We will do a blood test, the lipid panel, and please come back in 1 month.' },
        { id: 'c', speaker: 'DOCTOR', startSec: 9, text: 'Please see you in 10 days.' },
        { id: 'd', speaker: 'PATIENT', startSec: 12, text: 'I should walk more. Try to keep it short?' }
      ];
      const notes = new RuleBasedNotesExtractor().extract(said, '2026-09-03');
      expect(notes.length).assertEqual(4);
      expect(notes[0].kind).assertEqual('MEDICATION');
      expect(notes[1].kind).assertEqual('TEST');
      expect(notes[1].text).assertEqual('Lipid panel');
      expect(notes[2].kind).assertEqual('FOLLOW_UP');
      expect(notes[2].dueDate).assertEqual('2026-09-13');
      // The patient's sentences give a question and nothing else.
      expect(notes[3].kind).assertEqual('QUESTION');
      expect(notes[3].text).assertEqual('Try to keep it short?');
    });

    it('the same thing said twice is one note with both sources', 0, () => {
      const said: TranscriptSegment[] = [
        { id: 'a', speaker: 'DOCTOR', startSec: 0, text: 'Please avoid salty snacks.' },
        { id: 'b', speaker: 'DOCTOR', startSec: 30, text: 'Please avoid salty snacks.' }
      ];
      const notes = new RuleBasedNotesExtractor().extract(said, '2026-09-03');
      expect(notes.length).assertEqual(1);
      expect(notes[0].sourceSegmentIds.join(',')).assertEqual('a,b');
    });

    it('follow-up wording: days, weeks, months of 30 days', 0, () => {
      expect(followUpDays('Come back in 4 weeks.')).assertEqual(28);
      expect(followUpDays('See you in 10 days.')).assertEqual(10);
      expect(followUpDays('Book a follow-up in 2 months.')).assertEqual(60);
      expect(followUpDays('See you then.')).assertEqual(-1);
      expect(sentencesOf('One. Two? Three').length).assertEqual(3);
      expect(sourceQuote(demoTranscriptT1()[10]))
        .assertEqual('Doctor · 1:16 · "Take vitamin D 2000 IU once a day with breakfast."');
    });

    it('T1 has none of the words the app never uses about itself', 0, () => {
      const t = demoTranscriptT1();
      const banned: string[] = ['predict', 'validated', 'risk', 'healthy', 'unhealthy', 'diagnos', 'blood test'];
      const upperAi = new RegExp('\\bAI\\b');
      for (let i = 0; i < t.length; i++) {
        const lower = t[i].text.toLowerCase();
        for (let k = 0; k < banned.length; k++) {
          expect(lower.indexOf(banned[k])).assertEqual(-1);
        }
        expect(upperAi.test(t[i].text)).assertFalse();
      }
      const notes = t1Notes();
      for (let i = 0; i < notes.length; i++) {
        expect(upperAi.test(notes[i].text)).assertFalse();
      }
    });
  });

  describe('Visits: follow-up adherence', () => {
    it('the reminder is set for 09:00 on the due day, only while that is still ahead', 0, () => {
      const at = reminderMoment('2026-10-29');
      const when = new Date(at);
      expect(REMINDER_HOUR).assertEqual(9);
      expect(when.getFullYear()).assertEqual(2026);
      expect(when.getMonth()).assertEqual(9);
      expect(when.getDate()).assertEqual(29);
      expect(when.getHours()).assertEqual(9);
      expect(when.getMinutes()).assertEqual(0);
      // A due day ahead of now: 09:00 of that day.
      expect(reminderMomentAhead('2026-10-29', new Date(2026, 9, 4, 12, 0, 0).getTime())).assertEqual(at);
      expect(reminderMomentAhead('2026-10-29', at - 1)).assertEqual(at);
      // The moment itself and anything after it: no reminder.
      expect(reminderMomentAhead('2026-10-29', at)).assertEqual(-1);
      expect(reminderMomentAhead('2026-10-01', new Date(2026, 9, 4, 12, 0, 0).getTime())).assertEqual(-1);
      // Not a date: no reminder.
      expect(reminderMoment('')).assertEqual(-1);
      expect(reminderMoment('29 Oct 2026')).assertEqual(-1);
      expect(reminderMoment('2026-13-40')).assertEqual(-1);
      expect(reminderMomentAhead('soon', 0)).assertEqual(-1);
    });

    it('a follow-up on or before the due date is on time; later is not', 0, () => {
      // R2 is today-3, R1 was due today-2.
      expect(adherence(addDays(TODAY, -2), addDays(TODAY, -3))).assertEqual(ADHERENCE_ON_TIME);
      expect(adherence('2026-10-01', '2026-10-01')).assertEqual(ADHERENCE_ON_TIME);
      expect(adherence('2026-10-01', '2026-10-02')).assertEqual(ADHERENCE_NONE);
      expect(adherence(undefined, '2026-10-01')).assertEqual(ADHERENCE_NONE);
      expect(adherence('2026-10-01', undefined)).assertEqual(ADHERENCE_NONE);
      expect(adherence('soon', '2026-10-01')).assertEqual(ADHERENCE_NONE);
    });

    it('Ewa: R2 is linked to R1 and was kept on time', 0, async () => {
      const b = await ewaBook();
      const all = b.visits(VISITS_PERSONA_ID);
      expect(all.length).assertEqual(2);
      const r1 = visitOf(b, DEMO_R1);
      const r2 = visitOf(b, DEMO_R2);
      expect(all[0].id).assertEqual(r2.id);
      expect(r1.followUpDueDate).assertEqual('2026-10-01');
      expect(r2.followUpOfVisitId).assertEqual(r1.id);
      expect(visitAdherence(r2, all)).assertEqual(ADHERENCE_ON_TIME);
      expect(followUpDoneOnTime(r1, all)).assertTrue();
      // R1 itself is not a follow-up of anything.
      expect(visitAdherence(r1, all)).assertEqual(ADHERENCE_NONE);
    });

    it('the order the receipts are added in does not matter', 0, async () => {
      const b = book();
      await b.addDemoReceipt(VISITS_PERSONA_ID, DEMO_R2);
      expect(visitAdherence(visitOf(b, DEMO_R2), b.visits(VISITS_PERSONA_ID))).assertEqual(ADHERENCE_NONE);
      await b.addDemoReceipt(VISITS_PERSONA_ID, DEMO_R1);
      expect(visitAdherence(visitOf(b, DEMO_R2), b.visits(VISITS_PERSONA_ID))).assertEqual(ADHERENCE_ON_TIME);
    });

    it('a visit without a link states no adherence', 0, async () => {
      const b = book();
      await b.addDemoReceipt(VISITS_PERSONA_ID, DEMO_R5);
      const r5 = visitOf(b, DEMO_R5);
      expect(r5.followUpOfVisitId).assertUndefined();
      expect(visitAdherence(r5, b.visits(VISITS_PERSONA_ID))).assertEqual(ADHERENCE_NONE);
    });

    it('deleting the recording removes transcript and notes and does not change adherence', 0, async () => {
      const b = await ewaBook();
      const r1 = visitOf(b, DEMO_R1);
      const notes = r1.notes;
      expect(notes !== undefined && notes.length > 0).assertTrue();
      expect(b.deleteTranscript(r1.id)).assertTrue();
      expect(r1.transcript).assertUndefined();
      expect(r1.notes).assertUndefined();
      expect(r1.followUpDueDate).assertEqual('2026-10-01');
      const all = b.visits(VISITS_PERSONA_ID);
      expect(visitAdherence(visitOf(b, DEMO_R2), all)).assertEqual(ADHERENCE_ON_TIME);
      expect(followUpDoneOnTime(r1, all)).assertTrue();
      expect(b.deleteTranscript(r1.id)).assertFalse();
    });
  });

  describe('Visits: the list of visits', () => {
    it('adding the same receipt twice keeps one visit', 0, async () => {
      const b = await ewaBook();
      const again = await b.addDemoReceipt(VISITS_PERSONA_ID, DEMO_R1);
      expect(again.status).assertEqual('VERIFIED');
      expect(again.duplicate).assertTrue();
      expect(b.visits(VISITS_PERSONA_ID).length).assertEqual(2);
    });

    it('the tampered receipt is refused and the real visit stays verified', 0, async () => {
      const b = await ewaBook();
      const result = await b.addDemoReceipt(VISITS_PERSONA_ID, DEMO_R3);
      expect(result.status).assertEqual('MISMATCH');
      expect(b.visits(VISITS_PERSONA_ID).length).assertEqual(2);
      const r2 = visitOf(b, DEMO_R2);
      expect(r2.receiptStatus).assertEqual('VERIFIED');
      const receipt = r2.receipt;
      if (receipt !== undefined) {
        expect(receipt.issueDate).assertEqual(addDays(TODAY, -3));
      }
    });

    it('an old receipt is kept as a visit with a rejected receipt', 0, async () => {
      const b = await ewaBook();
      const result = await b.addDemoReceipt(VISITS_PERSONA_ID, DEMO_R4);
      expect(result.status).assertEqual('EXPIRED');
      expect(b.visits(VISITS_PERSONA_ID).length).assertEqual(3);
      expect(visitOf(b, DEMO_R4).receiptStatus).assertEqual('EXPIRED');
    });

    it('text that is not a code adds nothing, and other people have no visits', 0, async () => {
      const b = await ewaBook();
      const result = await b.addReceiptFromQr(VISITS_PERSONA_ID, 'FWRCPT1|x');
      expect(result.status).assertEqual('INVALID_FORMAT');
      expect(result.visit).assertNull();
      expect(b.visits(VISITS_PERSONA_ID).length).assertEqual(2);
      expect(b.visits('ania').length).assertEqual(0);
      expect(DemoVisits.hasVisits('ania')).assertFalse();
      expect(DemoVisits.hasVisits(VISITS_PERSONA_ID)).assertTrue();
    });
  });
}
