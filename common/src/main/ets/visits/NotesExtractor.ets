import { addDays, NoteItem, NoteKind, TranscriptSegment } from './VisitTypes';

/*
 * Visit notes from a transcript, by fixed rules. No model and no network: the same transcript always
 * gives the same notes, and every note points at the sentence it was taken from.
 *
 * The transcript is read sentence by sentence. A sentence of the doctor becomes at most one note, the
 * first of these that fits:
 *
 *   MEDICATION       <name> <number> (mg | IU | mcg) and how often; the sentence is kept word for word
 *   TEST             a term from the list below; one test per sentence, the more specific term wins
 *   FOLLOW_UP        "come back / see you / follow-up in N days | weeks | months"; the due date is the
 *                    visit date plus N (a month is 30 days)
 *   RECOMMENDATION   a sentence with try to, you should, I recommend, please, keep, avoid, reduce or walk
 *
 * A sentence of the patient that ends with a question mark is a QUESTION. Nothing else is taken from
 * what the patient says. The notes repeat what was said; they add no judgement of their own.
 */

export interface NotesExtractor {
  /** `visitDate` (YYYY-MM-DD) is what a follow-up is counted from. */
  extract(transcript: TranscriptSegment[], visitDate: string): NoteItem[];
}

class TestTerm {
  pattern: RegExp;
  label: string;

  constructor(pattern: string, label: string) {
    this.pattern = new RegExp(pattern, 'i');
    this.label = label;
  }
}

// The more specific terms first: "a blood test, the lipid panel" is one test, the lipid panel.
const TEST_TERMS: TestTerm[] = [
  new TestTerm('\\blipid panel\\b', 'Lipid panel'),
  new TestTerm('\\burine test\\b', 'Urine test'),
  new TestTerm('\\bultrasound\\b', 'Ultrasound'),
  new TestTerm('\\bx-ray\\b', 'X-ray'),
  new TestTerm('\\becg\\b', 'ECG'),
  new TestTerm('\\bblood test\\b', 'Blood test')
];

const DOSE_PATTERN: RegExp = new RegExp('[A-Za-z][A-Za-z-]*\\s+\\d+(?:\\.\\d+)?\\s?(?:mg|IU|mcg)\\b');
const FREQUENCY_PATTERN: RegExp = new RegExp(
  '\\b(?:once|twice|three times|\\d+ times) (?:a|per) day\\b|\\bdaily\\b|' +
    '\\bevery (?:day|morning|evening|night|\\d+ hours)\\b', 'i');
const FOLLOW_UP_PATTERN: RegExp = new RegExp(
  '\\b(?:come back|see you|follow-up|follow up)\\b[^.!?]*?\\bin (\\d{1,3}) (day|week|month)s?\\b', 'i');
const RECOMMENDATION_PATTERN: RegExp = new RegExp(
  '\\b(?:try to|you should|i recommend|please|keep|avoid|reduce|walk)\\b', 'i');

const DAYS_PER_WEEK: number = 7;
const DAYS_PER_MONTH: number = 30;

/** A text as its sentences: cut after '.', '!' or '?' followed by a space or the end. */
export function sentencesOf(text: string): string[] {
  const out: string[] = [];
  let start = 0;
  for (let i = 0; i < text.length; i++) {
    const c = text.charAt(i);
    if ((c === '.' || c === '!' || c === '?') && (i + 1 === text.length || text.charAt(i + 1) === ' ')) {
      const sentence = text.substring(start, i + 1).trim();
      if (sentence.length > 0) {
        out.push(sentence);
      }
      start = i + 1;
    }
  }
  const rest = text.substring(start).trim();
  if (rest.length > 0) {
    out.push(rest);
  }
  return out;
}

function testLabel(sentence: string): string {
  for (let i = 0; i < TEST_TERMS.length; i++) {
    if (TEST_TERMS[i].pattern.test(sentence)) {
      return TEST_TERMS[i].label;
    }
  }
  return '';
}

/** The number of days a follow-up sentence names, or -1 when the sentence names none. */
export function followUpDays(sentence: string): number {
  const m = FOLLOW_UP_PATTERN.exec(sentence);
  if (m === null) {
    return -1;
  }
  const n = Number.parseInt(m[1], 10);
  const unit = m[2].toLowerCase();
  if (isNaN(n) || n <= 0) {
    return -1;
  }
  if (unit === 'week') {
    return n * DAYS_PER_WEEK;
  }
  return unit === 'month' ? n * DAYS_PER_MONTH : n;
}

function note(kind: NoteKind, text: string, segmentId: string): NoteItem {
  const item: NoteItem = { kind: kind, text: text, sourceSegmentIds: [segmentId] };
  return item;
}

// One sentence of the doctor: the first rule that fits, or null.
function doctorNote(sentence: string, segmentId: string, visitDate: string): NoteItem | null {
  if (DOSE_PATTERN.test(sentence) && FREQUENCY_PATTERN.test(sentence)) {
    return note('MEDICATION', sentence, segmentId);
  }
  const test = testLabel(sentence);
  if (test.length > 0) {
    return note('TEST', test, segmentId);
  }
  const days = followUpDays(sentence);
  if (days > 0) {
    const item = note('FOLLOW_UP', sentence, segmentId);
    const due = addDays(visitDate, days);
    if (due.length > 0) {
      item.dueDate = due;
    }
    return item;
  }
  if (RECOMMENDATION_PATTERN.test(sentence)) {
    return note('RECOMMENDATION', sentence, segmentId);
  }
  return null;
}

// The same note said twice is one note with both sources.
function addMerged(out: NoteItem[], item: NoteItem): void {
  const key = item.text.trim().toLowerCase();
  for (let i = 0; i < out.length; i++) {
    if (out[i].kind === item.kind && out[i].text.trim().toLowerCase() === key) {
      for (let k = 0; k < item.sourceSegmentIds.length; k++) {
        if (out[i].sourceSegmentIds.indexOf(item.sourceSegmentIds[k]) < 0) {
          out[i].sourceSegmentIds.push(item.sourceSegmentIds[k]);
        }
      }
      return;
    }
  }
  out.push(item);
}

export class RuleBasedNotesExtractor implements NotesExtractor {
  extract(transcript: TranscriptSegment[], visitDate: string): NoteItem[] {
    const out: NoteItem[] = [];
    for (let i = 0; i < transcript.length; i++) {
      const segment = transcript[i];
      const sentences = sentencesOf(segment.text);
      for (let s = 0; s < sentences.length; s++) {
        const sentence = sentences[s];
        if (segment.speaker === 'DOCTOR') {
          const item = doctorNote(sentence, segment.id, visitDate);
          if (item !== null) {
            addMerged(out, item);
          }
        } else if (segment.speaker === 'PATIENT' && sentence.endsWith('?')) {
          addMerged(out, note('QUESTION', sentence, segment.id));
        }
      }
    }
    return out;
  }
}

/** The notes of one kind, in the order they were said. */
export function notesOfKind(notes: NoteItem[], kind: string): NoteItem[] {
  const out: NoteItem[] = [];
  for (let i = 0; i < notes.length; i++) {
    if (notes[i].kind === kind) {
      out.push(notes[i]);
    }
  }
  return out;
}

/** The due date of the first follow-up among the notes; empty when the doctor named none. */
export function followUpDueDateOf(notes: NoteItem[]): string {
  for (let i = 0; i < notes.length; i++) {
    const due = notes[i].dueDate;
    if (notes[i].kind === 'FOLLOW_UP' && due !== undefined && due.length > 0) {
      return due;
    }
  }
  return '';
}

/** 76 seconds as "1:16". */
export function transcriptTimeText(startSec: number): string {
  const total = startSec > 0 ? Math.floor(startSec) : 0;
  const s = total % 60;
  return `${Math.floor(total / 60)}:${s < 10 ? '0' : ''}${s}`;
}

/** The sentence a note was taken from, with who said it and when: 'Doctor · 1:16 · "Take ..."'. */
export function sourceQuote(segment: TranscriptSegment): string {
  const who = segment.speaker === 'DOCTOR' ? 'Doctor' : 'You';
  return `${who} · ${transcriptTimeText(segment.startSec)} · "${segment.text}"`;
}

export function segmentById(transcript: TranscriptSegment[], id: string): TranscriptSegment | null {
  for (let i = 0; i < transcript.length; i++) {
    if (transcript[i].id === id) {
      return transcript[i];
    }
  }
  return null;
}
