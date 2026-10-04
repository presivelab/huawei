import { common, OpenLinkOptions, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { decodeHealthSimPayload, HEALTH_SIM_PARAM, HealthScope, HealthSimPayload } from 'common';

/*
 * Asks Health Sim for health data. Health Sim (com.fairwear.healthsim) is a separate app that stands in
 * for HUAWEI Health on the emulators: it shows its own consent screen and hands the data back as one text.
 *
 * The request never throws and never rejects: every outcome is a HealthSimAnswer. When Health Sim is not
 * installed, or anything else goes wrong, FairWear falls back to its built-in demo data.
 *
 * The log carries counters and the length of the text only, never its content.
 */

const DOMAIN = 0x0000;
const TAG = 'FairWear';

const HEALTH_SIM_BUNDLE: string = 'com.fairwear.healthsim';
const HEALTH_SIM_MODULE: string = 'entry';
const HEALTH_SIM_ABILITY: string = 'AuthAbility';
// The same consent screen as a deep link, for systems that do not let an app start another app's ability
// by name (error 16000018).
const HEALTH_SIM_LINK: string = 'healthsim://authorize';
const SCOPES_PARAM: string = 'fwScopes';
const RESULT_GRANTED: number = 0;

// Ability Kit error codes (UIAbilityContext.startAbilityForResult, openLink).
const ERR_ABILITY_NOT_FOUND: number = 16000001;
const ERR_THIRD_PARTY_REDIRECT: number = 16000018;
const ERR_NO_MATCHING_ABILITY: number = 16000019;

export class HealthSimAnswerKind {
  static readonly OK: string = 'OK';
  static readonly REFUSED: string = 'REFUSED';
  static readonly NOT_INSTALLED: string = 'NOT_INSTALLED';
  static readonly ERROR: string = 'ERROR';
  // Not an answer of Health Sim: the request was given up before this answer came (see AddonSession).
  static readonly STALE: string = 'STALE';
}

export interface HealthSimAnswer {
  kind: string;          // HealthSimAnswerKind
  text: string;          // OK: the data as Health Sim sent it; otherwise one sentence for the screen
  payload: HealthSimPayload | null;   // the decoded data, set for OK only
}

export const HEALTH_SIM_REFUSED_TEXT: string = 'Health Sim did not allow access.';
export const HEALTH_SIM_NOT_INSTALLED_TEXT: string = 'Health Sim is not installed: built-in demo data';
export const HEALTH_SIM_ERROR_TEXT: string = 'Health Sim did not answer: built-in demo data';
export const HEALTH_SIM_UNREADABLE_TEXT: string = 'Health Sim sent data FairWear cannot read: built-in demo data';

function answer(kind: string, text: string): HealthSimAnswer {
  const out: HealthSimAnswer = { kind: kind, text: text, payload: null };
  return out;
}

function logAnswer(path: string, out: HealthSimAnswer, code: number): HealthSimAnswer {
  hilog.info(DOMAIN, TAG, 'healthsim answer: path=%{public}s kind=%{public}s chars=%{public}d code=%{public}d',
    path, out.kind, out.kind === HealthSimAnswerKind.OK ? out.text.length : 0, code);
  return out;
}

// Result code 0 with the data text is consent; result code 0 without it is an error; anything else
// (1 from "Don't allow", or the screen closed without an answer) is a refusal.
function answerFrom(path: string, result: common.AbilityResult): HealthSimAnswer {
  if (result.resultCode !== RESULT_GRANTED) {
    return logAnswer(path, answer(HealthSimAnswerKind.REFUSED, HEALTH_SIM_REFUSED_TEXT), result.resultCode);
  }
  const params: Record<string, Object> | undefined = result.want === undefined ? undefined : result.want.parameters;
  const payload: Object | undefined = params === undefined ? undefined : params[HEALTH_SIM_PARAM];
  if (payload === undefined || typeof payload !== 'string' || (payload as string).length === 0) {
    return logAnswer(path, answer(HealthSimAnswerKind.ERROR, HEALTH_SIM_ERROR_TEXT), result.resultCode);
  }
  // Strict decode: anything FairWear cannot read in full is refused as a whole and the demo data is used.
  const decoded: HealthSimPayload | null = decodeHealthSimPayload(payload as string);
  if (decoded === null) {
    hilog.warn(DOMAIN, TAG, 'healthsim answer: unreadable, chars=%{public}d', (payload as string).length);
    return logAnswer(path, answer(HealthSimAnswerKind.ERROR, HEALTH_SIM_UNREADABLE_TEXT), result.resultCode);
  }
  const out: HealthSimAnswer = { kind: HealthSimAnswerKind.OK, text: payload as string, payload: decoded };
  return logAnswer(path, out, result.resultCode);
}

function failure(path: string, code: number): HealthSimAnswer {
  if (code === ERR_ABILITY_NOT_FOUND || code === ERR_NO_MATCHING_ABILITY) {
    return logAnswer(path, answer(HealthSimAnswerKind.NOT_INSTALLED, HEALTH_SIM_NOT_INSTALLED_TEXT), code);
  }
  return logAnswer(path, answer(HealthSimAnswerKind.ERROR, HEALTH_SIM_ERROR_TEXT), code);
}

function errorCode(e: Object | null | undefined): number {
  if (e === undefined || e === null) {
    return -1;
  }
  const code: number | undefined = (e as BusinessError).code;
  return code === undefined ? -1 : code;
}

export class HealthSimClient {
  /** Opens Health Sim's consent screen for these data types and resolves with its answer. */
  static request(context: common.UIAbilityContext, scopes: HealthScope[]): Promise<HealthSimAnswer> {
    const names: string[] = [];
    for (let i = 0; i < scopes.length; i++) {
      names.push(scopes[i]);
    }
    const params: Record<string, Object> = {};
    params[SCOPES_PARAM] = names;
    hilog.info(DOMAIN, TAG, 'healthsim request: scopes=%{public}d', names.length);
    const want: Want = {
      bundleName: HEALTH_SIM_BUNDLE,
      moduleName: HEALTH_SIM_MODULE,
      abilityName: HEALTH_SIM_ABILITY,
      parameters: params
    };
    return new Promise<HealthSimAnswer>((resolve: (value: HealthSimAnswer) => void) => {
      try {
        context.startAbilityForResult(want).then((result: common.AbilityResult) => {
          resolve(answerFrom('ability', result));
        }).catch((err: BusinessError) => {
          if (errorCode(err) === ERR_THIRD_PARTY_REDIRECT) {
            HealthSimClient.requestByLink(context, params).then((out: HealthSimAnswer) => {
              resolve(out);
            });
            return;
          }
          resolve(failure('ability', errorCode(err)));
        });
      } catch (e) {
        resolve(failure('ability', errorCode(e as BusinessError)));
      }
    });
  }

  // The same request through Health Sim's deep link, with the answer delivered to the callback.
  private static requestByLink(context: common.UIAbilityContext,
    params: Record<string, Object>): Promise<HealthSimAnswer> {
    const options: OpenLinkOptions = { appLinkingOnly: false, parameters: params };
    return new Promise<HealthSimAnswer>((resolve: (value: HealthSimAnswer) => void) => {
      try {
        context.openLink(HEALTH_SIM_LINK, options, (err: BusinessError, result: common.AbilityResult) => {
          if (err !== undefined && err !== null && err.code) {
            resolve(failure('link', errorCode(err)));
            return;
          }
          resolve(answerFrom('link', result));
        }).catch((err: BusinessError) => {
          resolve(failure('link', errorCode(err)));
        });
      } catch (e) {
        resolve(failure('link', errorCode(e as BusinessError)));
      }
    });
  }
}
