// UI copy of the Share tab and the partner view. English only.

export const SHARE_INTRO: string = 'Show this code to your partner';
export const SHARE_INTRO_NO_SCORE: string = 'There is no code to show yet';
export const PARTNER_SEES_TITLE: string = 'What the partner sees';
export const PERIOD_PREFIX: string = 'Period ';
export const TECHNICAL_LABEL: string = 'Technical details';
export const TECH_KEY_ID: string = 'Key ID';
export const TECH_NONCE: string = 'One-time number';
export const TECH_ISSUED: string = 'Signed at';
export const NOT_IN_CODE: string =
  'Not in this code: your score, coverage, flags, sick days or any health data. Valid once, for this ' +
    'request only.';
export const TIER_FROM_PREVIEW: string = 'Tier from preview data';
export const CODE_USED: string = 'Used once · no longer valid';
export const NEW_CODE_LABEL: string = 'Make a new code';
export const SIGNING: string = 'Signing the code…';
export const SIGN_FAILED: string = 'The code could not be signed: ';
export const NO_CODE_SENTENCE: string =
  'No code yet. Without a score nothing is signed and nothing leaves this phone.';
export const OPEN_PARTNER_LABEL: string = 'Open partner view (demo)';
export const QR_SPOKEN: string = 'Code for your partner';

export const PARTNER_TITLE: string = 'Partner view · demo';
export const PARTNER_BAND: string = 'PARTNER · demo';
export const PARTNER_BAND_NOTE: string =
  'This screen plays the partner. The emulator has no camera, so the code is handed over inside the app.';
export const USE_CODE_LABEL: string = 'Use the code from this phone';
export const NO_CODE_ON_PHONE: string = 'No code has been shown on this phone yet. Open Share first.';
export const NOTHING_CHECKED: string = 'No code checked yet.';
export const CHECKS_TITLE: string = 'Checks, in order';
export const CHEAT_TITLE: string = 'Try to cheat';
export const VERIFY_AGAIN_LABEL: string = 'Verify the same code again';
export const CHEAT_NEEDS_CODE: string = 'Use the code from this phone first.';
export const REGISTRY_SUFFIX: string = ' (from the partner\'s key registry)';
export const KEY_PREFIX: string = 'Key: ';
export const NO_REASON_IN_CODE: string = 'The code does not say why.';
export const CHECK_NOT_RUN: string = 'Not run';

export const ATTEMPT_FIRST: string = 'The code from this phone';
export const ATTEMPT_AGAIN: string = 'The same code, a second time';

export function tamperLabel(tier: string): string {
  return `Change tier to ${tier} and verify`;
}

export function attemptTampered(tier: string): string {
  return `The same code with the tier changed to ${tier}`;
}
