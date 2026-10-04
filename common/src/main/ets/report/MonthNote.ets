/*
 * The month note: a few sentences about the month on screen, written by the FairWear server from the
 * report's summary. Pure logic: what is sent, how the answer is read, and the ledger line.
 *
 * What is sent is the summary the Report screen already shows: profile, tier, score, coverage, confidence,
 * eligibility, discount and the eight component scores (a missing component is -1). No name, no persona id,
 * no period, no daily readings, no free text. The server checks the same fixed schema.
 */
import { LedgerEntry } from '../model/types';
import { utf8Encode } from '../platform/Bytes';
import { parseJsonObject, readString } from '../watchlink/JsonRead';
import { ComponentRow, hasScore, PersonaReport } from './ReportModels';

export const MONTH_NOTE_URL: string = 'https://fairwear-130-61-179-157.sslip.io/v1/report';
export const LEDGER_KIND_NOTE: string = 'NOTE';
export const LEDGER_DESTINATION_NOTE: string = 'FairWear server · month note';
/** The longest note a screen shows; a longer answer is cut. */
export const MONTH_NOTE_MAX_CHARS: number = 3000;

interface NoteComponent {
  id: string;
  score: number;
  available: boolean;
}

interface NoteRequest {
  v: number;
  profile: string;
  tier: string;
  score: number;
  coveragePct: number;
  confidence: string;
  eligible: boolean;
  discountPct: number;
  components: NoteComponent[];
}

function clampInt(value: number, lo: number, hi: number): number {
  if (!Number.isFinite(value)) {
    return lo;
  }
  return Math.max(lo, Math.min(hi, Math.round(value)));
}

function noteComponent(row: ComponentRow): NoteComponent {
  const available: boolean = row.available && row.score >= 0;
  return { id: row.id, score: available ? clampInt(row.score, 0, 100) : -1, available: available };
}

/** The request body for a report: exactly the nine keys the server accepts. */
export function monthNoteRequest(report: PersonaReport): string {
  const scored: boolean = hasScore(report);
  const components: NoteComponent[] = [];
  for (let i = 0; i < report.components.length && i < 8; i++) {
    components.push(noteComponent(report.components[i]));
  }
  const body: NoteRequest = {
    v: 1,
    profile: report.profile,
    tier: report.tier,
    score: scored ? clampInt(report.hes, 0, 100) : -1,
    coveragePct: clampInt(report.coveragePct, 0, 100),
    confidence: report.confidence,
    eligible: report.eligible,
    discountPct: clampInt(report.discountPct, 0, 100),
    components: components
  };
  return JSON.stringify(body);
}

/** The note from the server's answer; empty when the answer is not a note. Never throws. */
export function monthNoteText(answer: string): string {
  const parsed: Record<string, Object> | null = parseJsonObject(answer);
  if (parsed === null) {
    return '';
  }
  const text: string | null = readString(parsed, 'text');
  return text === null ? '' : text.trim().slice(0, MONTH_NOTE_MAX_CHARS);
}

/** The ledger line of one sent summary: the exact text that left the phone and its size. */
export function monthNoteLedgerEntry(body: string, nowMs: number): LedgerEntry {
  const entry: LedgerEntry = {
    t: nowMs,
    kind: LEDGER_KIND_NOTE,
    destination: LEDGER_DESTINATION_NOTE,
    payload: body,
    bytes: utf8Encode(body).length
  };
  return entry;
}
