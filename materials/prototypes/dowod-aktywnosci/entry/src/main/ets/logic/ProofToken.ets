import { AnomalyFlag, Assurance, Evaluation, FlagCode, LabeledValue, Severity } from '../model/Types';
import { addDays, isoSeconds, parseIsoDate, shortDate } from '../model/DateUtil';
import { b64urlDecode, b64urlEncode, utf8Decode, utf8Encode } from './Codec';
import { Labels } from './Labels';

/*
 * Token: PA1.<base64url(payload JSON)>.<base64url(podpis DER)>
 * Podpis: ECDSA P-256 / SHA-256 kluczem z HUKS, liczony po bajtach UTF-8 payloadu.
 * Klucz publiczny NIE jedzie w tokenie: urządzenie rejestruje go u ubezpieczyciela raz (kid).
 * Dzięki temu nikt nie podpisze raportu własnym kluczem, a token mieści się w QR (limit 512 znaków).
 *
 * Schemat payloadu v1 (krótkie klucze jak w JWT, bo liczy się każdy znak w QR):
 *   v     wersja schematu (1)
 *   pol   numer polisy
 *   from  pierwszy dzień okresu; okres ma zawsze 28 dni (4 tygodnie)
 *   cons  zakres zgód: steps[,hr][,sleep]
 *   lvl   poziom pewności: EXT (ruch + tętno) | BASIC (tylko ruch)
 *   met   tygodnie zaliczone, wk = tygodnie ocenione
 *   slp   tygodnie ze snem 7+ h (tylko przy zgodzie na sen)
 *   tier  ZLOTY | SREBRNY | BRAK
 *   st    OK | REVIEW (podejrzane dni, decyzja człowieka)
 *   flags kody podejrzanych dni z liczbą, np. "SWHR:5,SWNW:1" (bez dat i wartości)
 *   note  wyjaśnienie klienta (opcjonalne, maks. 40 znaków)
 *   nonce wyzwanie z żądania ubezpieczyciela (chroni przed ponownym użyciem raportu)
 *   iat   czas wystawienia (sekundy Unix)
 *   kid   identyfikator zarejestrowanego klucza urządzenia
 */

export class ProofPayload {
  v: number = 1;
  pol: string = '';
  from: string = '';
  cons: string = '';
  lvl: string = '';
  met: number = 0;
  wk: number = 0;
  slp?: number;
  tier: string = '';
  st: string = '';
  flags: string = '';
  note?: string;
  nonce: string = '';
  iat: number = 0;
  kid: string = '';
}

/** Kształt payloadu po stronie ubezpieczyciela (z JSON.parse). */
export interface ProofPayloadJson {
  v: number;
  pol: string;
  from: string;
  cons: string;
  lvl: string;
  met: number;
  wk: number;
  slp?: number;
  tier: string;
  st: string;
  flags: string;
  note?: string;
  nonce: string;
  iat: number;
  kid: string;
}

export class ParsedToken {
  ok: boolean = false;
  error: string = '';
  payload: ProofPayloadJson | null = null;
  payloadText: string = '';
  payloadBytes: Uint8Array = new Uint8Array(0);
  sigBytes: Uint8Array = new Uint8Array(0);
}

export class CheckItem {
  name: string;
  passed: boolean;
  detail: string;

  constructor(name: string, passed: boolean, detail: string) {
    this.name = name;
    this.passed = passed;
    this.detail = detail;
  }
}

export class VerificationResult {
  ok: boolean = false;
  items: CheckItem[] = [];
  payload: ProofPayloadJson | null = null;
}

export class ProofToken {
  static readonly PREFIX: string = 'PA1';
  static readonly QR_MAX_CHARS: number = 512;
  static readonly NOTE_MAX_CHARS: number = 40;
  static readonly POLICY_MAX_CHARS: number = 20;
  static readonly PERIOD_DAYS: number = 28;
  static readonly MAX_AGE_MS: number = 24 * 60 * 60 * 1000;
  static readonly CLOCK_SKEW_MS: number = 5 * 60 * 1000;

  static buildPayload(ev: Evaluation, policy: string, nonce: string, note: string, kid: string,
    issuedAtMs: number): ProofPayload {
    const p = new ProofPayload();
    p.pol = policy.trim().substring(0, ProofToken.POLICY_MAX_CHARS);
    p.from = ev.periodFrom;
    p.cons = ev.consents.join(',');
    p.lvl = ev.assurance === Assurance.ROZSZERZONY ? 'EXT' : 'BASIC';
    p.met = ev.weeksMet;
    p.wk = ev.weeks.length;
    if (ev.sleepWeeks >= 0) {
      p.slp = ev.sleepWeeks;
    }
    p.tier = ev.tier;
    p.st = ev.status;
    p.flags = ProofToken.summarizeFlags(ev.flags);
    const trimmed = note.trim();
    if (trimmed.length > 0) {
      p.note = trimmed.substring(0, ProofToken.NOTE_MAX_CHARS);
    }
    p.nonce = nonce;
    p.iat = Math.floor(issuedAtMs / 1000);
    p.kid = kid;
    return p;
  }

  static shortCode(code: FlagCode): string {
    if (code === FlagCode.STEPS_WITHOUT_HR) {
      return 'SWHR';
    }
    if (code === FlagCode.STEPS_WHILE_NOT_WORN) {
      return 'SWNW';
    }
    if (code === FlagCode.IMPOSSIBLE_VALUE) {
      return 'IMPV';
    }
    return 'NWRN';
  }

  /** Do ubezpieczyciela idą tylko kody i liczba podejrzanych dni, bez dat i wartości. */
  static summarizeFlags(flags: AnomalyFlag[]): string {
    const counts = new Map<string, number>();
    for (const f of flags) {
      if (f.severity === Severity.HIGH) {
        const key = ProofToken.shortCode(f.code);
        const prev = counts.get(key);
        counts.set(key, prev === undefined ? 1 : prev + 1);
      }
    }
    const out: string[] = [];
    counts.forEach((n: number, code: string) => {
      out.push(`${code}:${n}`);
    });
    out.sort();
    return out.join(',');
  }

  static payloadBytes(p: ProofPayload): Uint8Array {
    return utf8Encode(JSON.stringify(p));
  }

  static encode(payloadBytes: Uint8Array, signature: Uint8Array): string {
    return `${ProofToken.PREFIX}.${b64urlEncode(payloadBytes)}.${b64urlEncode(signature)}`;
  }

  static fitsQr(token: string): boolean {
    return token.length <= ProofToken.QR_MAX_CHARS;
  }

  static periodTo(from: string): string {
    return addDays(from, ProofToken.PERIOD_DAYS - 1);
  }

  static parse(token: string): ParsedToken {
    const r = new ParsedToken();
    const parts = token.trim().split('.');
    if (parts.length !== 3 || parts[0] !== ProofToken.PREFIX) {
      r.error = 'Nieznany format (oczekiwano PA1.<dane>.<podpis>)';
      return r;
    }
    try {
      r.payloadBytes = b64urlDecode(parts[1]);
      r.sigBytes = b64urlDecode(parts[2]);
    } catch (e) {
      r.error = 'Uszkodzone kodowanie base64url';
      return r;
    }
    r.payloadText = utf8Decode(r.payloadBytes);
    let obj: ProofPayloadJson | null = null;
    try {
      obj = JSON.parse(r.payloadText) as ProofPayloadJson;
    } catch (e) {
      r.error = 'Dane nie są poprawnym JSON';
      return r;
    }
    if (obj === null || typeof obj !== 'object') {
      r.error = 'Dane nie są obiektem JSON';
      return r;
    }
    const bad = ProofToken.invalidFields(obj);
    if (bad.length > 0) {
      r.error = `Brak lub zły typ pól: ${bad.join(', ')}`;
      return r;
    }
    r.payload = obj;
    r.ok = true;
    return r;
  }

  static invalidFields(o: ProofPayloadJson): string[] {
    const bad: string[] = [];
    if (typeof o.v !== 'number' || o.v !== 1) {
      bad.push('v');
    }
    if (typeof o.pol !== 'string') {
      bad.push('pol');
    }
    if (typeof o.from !== 'string' || !new RegExp('^\\d{4}-\\d{2}-\\d{2}$').test(o.from)) {
      bad.push('from');
    }
    if (typeof o.cons !== 'string') {
      bad.push('cons');
    }
    if (typeof o.lvl !== 'string') {
      bad.push('lvl');
    }
    if (typeof o.met !== 'number') {
      bad.push('met');
    }
    if (typeof o.wk !== 'number') {
      bad.push('wk');
    }
    if (o.slp !== undefined && typeof o.slp !== 'number') {
      bad.push('slp');
    }
    if (typeof o.tier !== 'string') {
      bad.push('tier');
    }
    if (typeof o.st !== 'string') {
      bad.push('st');
    }
    if (typeof o.flags !== 'string') {
      bad.push('flags');
    }
    if (o.note !== undefined && typeof o.note !== 'string') {
      bad.push('note');
    }
    if (typeof o.nonce !== 'string') {
      bad.push('nonce');
    }
    if (typeof o.iat !== 'number') {
      bad.push('iat');
    }
    if (typeof o.kid !== 'string') {
      bad.push('kid');
    }
    return bad;
  }

  /** sigValid i keyKnown liczy warstwa platformowa (cryptoFramework + rejestr kluczy). */
  static check(parsed: ParsedToken, keyKnown: boolean, sigValid: boolean, expectedNonce: string,
    nowMs: number): VerificationResult {
    const r = new VerificationResult();
    r.items.push(new CheckItem('Format tokenu', parsed.ok, parsed.ok ? 'PA1, JSON kompletny' : parsed.error));
    if (!parsed.ok || parsed.payload === null) {
      return r;
    }
    const p = parsed.payload;
    r.payload = p;
    r.items.push(new CheckItem('Klucz urządzenia zarejestrowany', keyKnown,
      keyKnown ? `kid ${p.kid}` : `nieznany kid ${p.kid} — urządzenie nie zostało zarejestrowane`));
    r.items.push(new CheckItem('Podpis cyfrowy', sigValid,
      sigValid ? 'ECDSA P-256 / SHA-256 poprawny' : 'Podpis nie pasuje — dane zmienione po podpisaniu'));
    const nonceOk = expectedNonce.length > 0 && p.nonce === expectedNonce;
    r.items.push(new CheckItem('Odpowiedź na nasze żądanie (nonce)', nonceOk,
      nonceOk ? p.nonce : `oczekiwano ${expectedNonce.length > 0 ? expectedNonce : '—'}, jest ${p.nonce}`));
    const issued = p.iat * 1000;
    const fresh = issued <= nowMs + ProofToken.CLOCK_SKEW_MS && nowMs - issued <= ProofToken.MAX_AGE_MS;
    r.items.push(new CheckItem('Świeżość (do 24 h)', fresh,
      fresh ? `wystawiono ${isoSeconds(issued)}` : `wystawiono ${isoSeconds(issued)} — za stary albo z przyszłości`));
    const fromOk = !isNaN(parseIsoDate(p.from));
    const periodOk = fromOk && p.wk === 4 && p.met >= 0 && p.met <= p.wk;
    r.items.push(new CheckItem('Okres 28 dni / 4 tygodnie', periodOk,
      periodOk ? `${p.from} – ${ProofToken.periodTo(p.from)}` : `tygodnie ${p.met}/${p.wk}, start ${p.from}`));
    let allPassed = true;
    for (const item of r.items) {
      if (!item.passed) {
        allPassed = false;
      }
    }
    r.ok = allPassed;
    return r;
  }

  /**
   * Symulacja oszustwa bez ponownego podpisu: podniesienie progu, statusu i wyczyszczenie flag.
   * Gdy raport już jest najlepszy możliwy (np. Złoty, OK), podmienia numer polisy
   * (próba użycia cudzego raportu) - zmiana treści musi wystąpić zawsze.
   */
  static tamper(token: string): string {
    const parsed = ProofToken.parse(token);
    if (!parsed.ok) {
      return token;
    }
    let forged = parsed.payloadText
      .replace(new RegExp('"tier":"[A-Z]+"'), '"tier":"ZLOTY"')
      .replace(new RegExp('"st":"[A-Z]+"'), '"st":"OK"')
      .replace(new RegExp('"met":\\d+'), '"met":4')
      .replace(new RegExp('"flags":"[^"]*"'), '"flags":""');
    if (forged === parsed.payloadText) {
      forged = forged.replace(new RegExp('"pol":"([^"]*)"'), '"pol":"$1-INNA"');
    }
    const parts = token.trim().split('.');
    return `${ProofToken.PREFIX}.${b64urlEncode(utf8Encode(forged))}.${parts[2]}`;
  }

  /** Czytelny podgląd tego, co dokładnie wychodzi z telefonu. */
  static describe(p: ProofPayloadJson): LabeledValue[] {
    const rows: LabeledValue[] = [];
    rows.push(new LabeledValue('Polisa', p.pol));
    rows.push(new LabeledValue('Okres (28 dni)',
      `${shortDate(p.from)} – ${shortDate(ProofToken.periodTo(p.from))}.${p.from.substring(0, 4)}`));
    rows.push(new LabeledValue('Zakres zgód', Labels.consents(p.cons.split(','))));
    rows.push(new LabeledValue('Poziom pewności', Labels.assurance(p.lvl)));
    rows.push(new LabeledValue('Tygodnie zaliczone', `${p.met} z ${p.wk}`));
    if (p.slp !== undefined) {
      rows.push(new LabeledValue('Tygodnie ze snem 7+ h', `${p.slp} z ${p.wk}`));
    }
    rows.push(new LabeledValue('Próg', Labels.tier(p.tier)));
    rows.push(new LabeledValue('Status', Labels.status(p.st)));
    rows.push(new LabeledValue('Podejrzane dni', p.flags.length > 0 ? Labels.flagSummary(p.flags) : 'brak'));
    if (p.note !== undefined) {
      rows.push(new LabeledValue('Wyjaśnienie klienta', p.note));
    }
    rows.push(new LabeledValue('Nonce żądania', p.nonce));
    rows.push(new LabeledValue('Wystawiono', isoSeconds(p.iat * 1000)));
    rows.push(new LabeledValue('Klucz urządzenia', p.kid));
    return rows;
  }
}
