import { str } from '../ui/Strings';

// UI copy of the Share tab and the partner view, kept in string resources (base = English).
// A constant is the resource; a function returns the text.

export const SHARE_INTRO: Resource = $r('app.string.share_intro');
export const SHARE_INTRO_NO_SCORE: Resource = $r('app.string.share_intro_no_score');
export const PARTNER_SEES_TITLE: Resource = $r('app.string.share_partner_sees_title');
export const TECHNICAL_LABEL: Resource = $r('app.string.share_technical_label');
export const TECH_KEY_ID: Resource = $r('app.string.share_tech_key_id');
export const TECH_NONCE: Resource = $r('app.string.share_tech_nonce');
export const TECH_ISSUED: Resource = $r('app.string.share_tech_issued');
export const NOT_IN_CODE: Resource = $r('app.string.share_not_in_code');
export const TRY_AGAIN_LABEL: Resource = $r('app.string.share_try_again_label');
export const LEDGER_LINK: Resource = $r('app.string.share_ledger_link');
export const LEDGER_TITLE: Resource = $r('app.string.ledger_title');
export const LEDGER_NOTE: Resource = $r('app.string.ledger_note');
export const LEDGER_EMPTY: Resource = $r('app.string.ledger_empty');

export function ledgerBytesLine(bytes: number): string {
  return str($r('app.string.ledger_bytes_line'), bytes);
}
export const TIER_FROM_PREVIEW: Resource = $r('app.string.share_tier_from_preview');
export const CODE_USED: Resource = $r('app.string.share_code_used');
export const NEW_CODE_LABEL: Resource = $r('app.string.share_new_code_label');
export const SIGNING: Resource = $r('app.string.share_signing');
export const NO_CODE_SENTENCE: Resource = $r('app.string.share_no_code_sentence');
export const OPEN_PARTNER_LABEL: Resource = $r('app.string.share_open_partner_label');
export const QR_SPOKEN: Resource = $r('app.string.share_qr_spoken');

export const PARTNER_TITLE: Resource = $r('app.string.partner_title');
export const PARTNER_BAND: Resource = $r('app.string.partner_band');
export const PARTNER_BAND_NOTE: Resource = $r('app.string.partner_band_note');
export const USE_CODE_LABEL: Resource = $r('app.string.partner_use_code_label');
export const NO_CODE_ON_PHONE: Resource = $r('app.string.partner_no_code_on_phone');
export const NOTHING_CHECKED: Resource = $r('app.string.partner_nothing_checked');
export const CHECKS_TITLE: Resource = $r('app.string.partner_checks_title');
export const CHEAT_TITLE: Resource = $r('app.string.partner_cheat_title');
export const VERIFY_AGAIN_LABEL: Resource = $r('app.string.partner_verify_again_label');
export const CHEAT_NEEDS_CODE: Resource = $r('app.string.partner_cheat_needs_code');
export const CHECK_NOT_RUN: Resource = $r('app.string.partner_check_not_run');

export const ATTEMPT_FIRST: Resource = $r('app.string.partner_attempt_first');
export const ATTEMPT_AGAIN: Resource = $r('app.string.partner_attempt_again');

export function tamperLabel(tier: string): string {
  return str($r('app.string.partner_tamper_label'), tier);
}

export function attemptTampered(tier: string): string {
  return str($r('app.string.partner_attempt_tampered'), tier);
}
