import { HealthStatus } from '../health/HealthRecords';
import { healthSourceLabel } from '../health/HealthStatusLabel';

/*
 * What the home-screen card may show.
 *
 * The home screen is seen by other people, so the digest deliberately has no tier letter and no score:
 * only where the data comes from, how much of the evidence is covered, and whether a result exists.
 */

export const CARD_NO_VALUE: string = '—';
export const CARD_COVERAGE_NONE: number = -1;
const HALF_STEPS: number = 2;

const MAX_LABEL_LENGTH: number = 48;

export class CardDigest {
  sourceLabel: string;
  coveragePct: number;   // 0..100, or CARD_COVERAGE_NONE when there is no coverage figure yet
  resultReady: boolean;

  constructor(sourceLabel: string, coveragePct: number, resultReady: boolean) {
    this.sourceLabel = sourceLabel;
    this.coveragePct = coveragePct;
    this.resultReady = resultReady;
  }
}

/** The source line of the card. Text only: the brand name as a partner writes it, no logo. */
export function cardSourceLabel(status: HealthStatus): string {
  return healthSourceLabel(status);
}

/** Before the app has computed anything: not connected, no coverage, no result. */
export function emptyCardDigest(): CardDigest {
  return new CardDigest(cardSourceLabel(HealthStatus.NOT_AUTHORIZED), CARD_COVERAGE_NONE, false);
}

/** Builds a digest from app state. Without a connection there is never a coverage figure or a result. */
export function buildCardDigest(status: HealthStatus, coveragePct: number, resultReady: boolean): CardDigest {
  if (status === HealthStatus.NOT_AUTHORIZED || status === HealthStatus.UNAVAILABLE) {
    return new CardDigest(cardSourceLabel(status), CARD_COVERAGE_NONE, false);
  }
  return new CardDigest(cardSourceLabel(status), normaliseCoverage(coveragePct), resultReady);
}

export function cardCoverageText(digest: CardDigest): string {
  if (digest.coveragePct < 0) {
    return CARD_NO_VALUE;
  }
  return digest.coveragePct.toString() + '%';
}

export function cardResultText(digest: CardDigest): string {
  return digest.resultReady ? 'Score ready' : CARD_NO_VALUE;
}

export function encodeCardDigest(digest: CardDigest): string {
  return '{"sourceLabel":' + JSON.stringify(digest.sourceLabel) +
    ',"coveragePct":' + digest.coveragePct.toString() +
    ',"resultReady":' + (digest.resultReady ? 'true' : 'false') + '}';
}

/** Reads a stored digest. Anything malformed gives the empty digest; it never throws. */
export function decodeCardDigest(json: string): CardDigest {
  let parsed: Record<string, Object>;
  try {
    parsed = JSON.parse(json) as Record<string, Object>;
  } catch (e) {
    return emptyCardDigest();
  }
  if (parsed === null || typeof parsed !== 'object') {
    return emptyCardDigest();
  }
  const label = parsed['sourceLabel'];
  const coverage = parsed['coveragePct'];
  const ready = parsed['resultReady'];
  if (typeof label !== 'string' || typeof coverage !== 'number' || typeof ready !== 'boolean') {
    return emptyCardDigest();
  }
  const text: string = label as string;
  if (text.length === 0 || text.length > MAX_LABEL_LENGTH) {
    return emptyCardDigest();
  }
  return new CardDigest(text, normaliseCoverage(coverage as number), ready as boolean);
}

function normaliseCoverage(value: number): number {
  if (isNaN(value) || value < 0) {
    return CARD_COVERAGE_NONE;
  }
  if (value > 100) {
    return 100;
  }
  // The engine's coverage is a multiple of 0.5 and is shown exactly (87.5%); any other value is rounded.
  if (Math.round(value * HALF_STEPS) === value * HALF_STEPS) {
    return value;
  }
  return Math.round(value);
}
