import { describe, it, expect } from '@ohos/hypium';
import {
  Consents, DaySample, Evaluation, FlagCode, LabeledValue, Persona, ReportStatus, Severity, Tier, WeekStatus
} from '../main/ets/model/Types';
import { Personas } from '../main/ets/model/Personas';
import { addDays } from '../main/ets/model/DateUtil';
import { Evaluator } from '../main/ets/logic/Evaluator';
import { AnomalyDetector } from '../main/ets/logic/AnomalyDetector';
import { b64urlDecode, b64urlEncode, utf8Decode, utf8Encode } from '../main/ets/logic/Codec';
import { ProofToken } from '../main/ets/logic/ProofToken';
import { LiveDayCollector } from '../main/ets/logic/LiveDayCollector';

/*
 * Testy lokalne (bez urządzenia): DevEco Studio -> prawy klik na entry/src/test -> Run 'Local Test'.
 * Te same pliki uruchamia tools/run-logic-tests.sh w Node (CI / bez DevEco).
 */

const END: string = '2026-10-02';
const NOW_MS: number = Date.UTC(2026, 9, 3, 16, 0, 0);

function evalOf(p: Persona, hr: boolean, sleep: boolean): Evaluation {
  return Evaluator.evaluate(p.days, new Consents(hr, sleep));
}

function countFlags(ev: Evaluation, code: FlagCode): number {
  let n = 0;
  for (const f of ev.flags) {
    if (f.code === code) {
      n++;
    }
  }
  return n;
}

/** Podpis ECDSA P-256 w DER ma 70-72 bajty; do testów rozmiaru bierzemy najgorszy przypadek. */
function fakeSignature(): Uint8Array {
  const sig = new Uint8Array(72);
  for (let i = 0; i < sig.length; i++) {
    sig[i] = (i * 37 + 11) % 256;
  }
  return sig;
}

function tokenFor(ev: Evaluation, nonce: string, note: string, issuedAtMs: number): string {
  const payload = ProofToken.buildPayload(ev, 'NNW-2026-004213', nonce, note, 'a1b2c3d4', issuedAtMs);
  return ProofToken.encode(ProofToken.payloadBytes(payload), fakeSignature());
}

export default function logicTest() {
  describe('Codec', () => {
    it('utf8_roundtrip_polish_and_emoji', 0, () => {
      const text = 'Zażółć gęślą jaźń — chorowałem 🤒';
      expect(utf8Decode(utf8Encode(text))).assertEqual(text);
      expect(utf8Encode('ą').length).assertEqual(2);
    });
    it('b64url_roundtrip_all_lengths', 0, () => {
      for (let len = 0; len < 12; len++) {
        const bytes = new Uint8Array(len);
        for (let i = 0; i < len; i++) {
          bytes[i] = (i * 97 + len * 13) % 256;
        }
        const enc = b64urlEncode(bytes);
        expect(enc.indexOf('+') < 0 && enc.indexOf('/') < 0 && enc.indexOf('=') < 0).assertTrue();
        const dec = b64urlDecode(enc);
        expect(dec.length).assertEqual(len);
        for (let i = 0; i < len; i++) {
          expect(dec[i]).assertEqual(bytes[i]);
        }
      }
    });
    it('b64url_rejects_garbage', 0, () => {
      let threw = false;
      try {
        b64urlDecode('ab$c');
      } catch (e) {
        threw = true;
      }
      expect(threw).assertTrue();
    });
  });

  describe('Personas', () => {
    it('each_persona_has_56_consecutive_days', 0, () => {
      for (const p of Personas.all(END)) {
        expect(p.days.length).assertEqual(56);
        expect(p.days[55].date).assertEqual(END);
        expect(p.days[0].date).assertEqual(addDays(END, -55));
      }
    });
  });

  describe('Evaluator', () => {
    it('anna_active_gets_gold', 0, () => {
      const ev = evalOf(Personas.anna(END), true, false);
      expect(ev.weeksMet).assertEqual(4);
      expect(ev.tier).assertEqual(Tier.ZLOTY);
      expect(ev.status).assertEqual(ReportStatus.OK);
      expect(ev.flags.length).assertEqual(0);
    });
    it('marek_sick_week_still_gold', 0, () => {
      const ev = evalOf(Personas.marek(END), true, false);
      expect(ev.weeksMet).assertEqual(3);
      expect(ev.tier).assertEqual(Tier.ZLOTY);
      expect(ev.status).assertEqual(ReportStatus.OK);
      expect(ev.weeks[1].status === WeekStatus.MET).assertFalse();
      expect(countFlags(ev, FlagCode.NOT_WORN)).assertEqual(3);
    });
    it('zofia_improves_against_own_baseline', 0, () => {
      const ev = evalOf(Personas.zofia(END), true, false);
      expect(ev.tier).assertEqual(Tier.SREBRNY);
      expect(ev.weeks[2].status).assertEqual(WeekStatus.MET);
      expect(ev.weeks[3].status).assertEqual(WeekStatus.MET);
      expect(ev.weeks[3].weeklyActiveMinutes).assertLess(150);
      expect(ev.weeks[3].baselineDeltaPct).assertLarger(9);
    });
    it('kamil_with_hr_goes_to_human_review', 0, () => {
      const ev = evalOf(Personas.kamil(END), true, false);
      expect(ev.status).assertEqual(ReportStatus.REVIEW);
      expect(ev.tier).assertEqual(Tier.BRAK);
      expect(countFlags(ev, FlagCode.STEPS_WITHOUT_HR)).assertEqual(5);
      expect(countFlags(ev, FlagCode.STEPS_WHILE_NOT_WORN)).assertEqual(1);
    });
    it('kamil_without_hr_is_caught_only_by_wear_detection', 0, () => {
      const ev = evalOf(Personas.kamil(END), false, false);
      expect(countFlags(ev, FlagCode.STEPS_WITHOUT_HR)).assertEqual(0);
      expect(countFlags(ev, FlagCode.STEPS_WHILE_NOT_WORN)).assertEqual(1);
      expect(ev.status).assertEqual(ReportStatus.REVIEW);
      expect(ev.tier).assertEqual(Tier.SREBRNY);
    });
    it('without_hr_gold_is_capped_to_silver', 0, () => {
      const ev = evalOf(Personas.anna(END), false, false);
      expect(ev.tierBeforeCap).assertEqual(Tier.ZLOTY);
      expect(ev.tier).assertEqual(Tier.SREBRNY);
    });
    it('sleep_only_reported_with_consent', 0, () => {
      expect(evalOf(Personas.anna(END), true, true).sleepWeeks).assertEqual(4);
      expect(evalOf(Personas.anna(END), true, false).sleepWeeks).assertEqual(-1);
    });
    it('empty_input_does_not_crash', 0, () => {
      const ev = Evaluator.evaluate([], new Consents(true, true));
      expect(ev.weeks.length).assertEqual(0);
      expect(ev.tier).assertEqual(Tier.BRAK);
    });
  });

  describe('AnomalyDetector', () => {
    it('impossible_values_are_high', 0, () => {
      const flags = AnomalyDetector.detect(new DaySample(END, 90000, 30, 120, 60, 1300, 400), new Consents(true, false));
      expect(flags.length).assertEqual(1);
      expect(flags[0].code).assertEqual(FlagCode.IMPOSSIBLE_VALUE);
      expect(flags[0].severity).assertEqual(Severity.HIGH);
    });
    it('watch_off_all_day_is_skipped_not_punished', 0, () => {
      const flags = AnomalyDetector.detect(new DaySample(END, 0, 0, 0, 0, 0, 0), new Consents(true, false));
      expect(flags.length).assertEqual(1);
      expect(flags[0].severity).assertEqual(Severity.LOW);
    });
    it('steps_with_watch_off_are_high', 0, () => {
      const flags = AnomalyDetector.detect(new DaySample(END, 5000, 10, 0, 0, 0, 0), new Consents(false, false));
      expect(flags[0].code).assertEqual(FlagCode.STEPS_WHILE_NOT_WORN);
    });
  });

  describe('ProofToken', () => {
    it('roundtrip_and_all_checks_pass', 0, () => {
      const ev = evalOf(Personas.anna(END), true, true);
      const token = tokenFor(ev, '7f3a9c21', '', NOW_MS - 30 * 60000);
      const parsed = ProofToken.parse(token);
      expect(parsed.ok).assertTrue();
      expect(parsed.payload !== null && parsed.payload.tier === 'ZLOTY').assertTrue();
      expect(parsed.payload !== null && parsed.payload.slp === 4).assertTrue();
      expect(parsed.sigBytes.length).assertEqual(72);
      const result = ProofToken.check(parsed, true, true, '7f3a9c21', NOW_MS);
      expect(result.ok).assertTrue();
    });
    it('no_sleep_consent_means_no_sleep_field', 0, () => {
      const ev = evalOf(Personas.anna(END), true, false);
      const parsed = ProofToken.parse(tokenFor(ev, '7f3a9c21', '', NOW_MS));
      expect(parsed.payloadText.indexOf('"slp"')).assertEqual(-1);
    });
    it('worst_case_token_fits_qr', 0, () => {
      const ev = evalOf(Personas.kamil(END), true, true);
      const note = 'Jeździłem rowerem, zegarek miałem w kieszeni i to dłużej';
      const token = tokenFor(ev, '7f3a9c21', note, NOW_MS);
      expect(token.length).assertLess(ProofToken.QR_MAX_CHARS + 1);
      expect(ProofToken.fitsQr(token)).assertTrue();
    });
    it('wrong_nonce_old_report_bad_signature_fail', 0, () => {
      const ev = evalOf(Personas.anna(END), true, false);
      const parsed = ProofToken.parse(tokenFor(ev, 'aaaa1111', '', NOW_MS - 3 * 24 * 3600000));
      const r = ProofToken.check(parsed, true, false, 'bbbb2222', NOW_MS);
      expect(r.ok).assertFalse();
      let failed = 0;
      for (const item of r.items) {
        if (!item.passed) {
          failed++;
        }
      }
      expect(failed).assertEqual(3);
    });
    it('tamper_changes_signed_bytes', 0, () => {
      const ev = evalOf(Personas.kamil(END), true, false);
      const token = tokenFor(ev, '7f3a9c21', '', NOW_MS);
      const forged = ProofToken.tamper(token);
      const a = ProofToken.parse(token);
      const b = ProofToken.parse(forged);
      expect(a.payload !== null && a.payload.st === 'REVIEW' && a.payload.flags === 'SWHR:5,SWNW:1').assertTrue();
      expect(b.ok).assertTrue();
      expect(b.payload !== null && b.payload.tier === 'ZLOTY' && b.payload.st === 'OK' && b.payload.flags === '')
        .assertTrue();
      expect(a.payloadText === b.payloadText).assertFalse();
      expect(b.sigBytes.length).assertEqual(a.sigBytes.length);
    });
    it('tamper_always_changes_content_even_for_best_report', 0, () => {
      const ev = evalOf(Personas.anna(END), true, false);
      const token = tokenFor(ev, '7f3a9c21', '', NOW_MS);
      const a = ProofToken.parse(token);
      const b = ProofToken.parse(ProofToken.tamper(token));
      expect(a.payload !== null && a.payload.tier === 'ZLOTY' && a.payload.flags === '').assertTrue();
      expect(b.ok).assertTrue();
      expect(a.payloadText === b.payloadText).assertFalse();
      expect(b.payload !== null && b.payload.pol === 'NNW-2026-004213-INNA').assertTrue();
    });
    it('describe_is_human_readable', 0, () => {
      const ev = evalOf(Personas.kamil(END), true, false);
      const parsed = ProofToken.parse(tokenFor(ev, '7f3a9c21', '', NOW_MS));
      const rows: LabeledValue[] = parsed.payload !== null ? ProofToken.describe(parsed.payload) : [];
      let flagsRow = '';
      for (const row of rows) {
        if (row.label === 'Podejrzane dni') {
          flagsRow = row.value;
        }
      }
      expect(flagsRow).assertEqual('Kroki bez wzrostu tętna: 5 dni, Kroki przy zdjętym zegarku: 1 dzień');
    });
    it('garbage_is_rejected', 0, () => {
      expect(ProofToken.parse('hello').ok).assertFalse();
      expect(ProofToken.parse('PA1.$$$.abc').ok).assertFalse();
      expect(ProofToken.parse(`PA1.${b64urlEncode(utf8Encode('{"v":1}'))}.AAAA`).ok).assertFalse();
    });
  });

  describe('LiveDayCollector', () => {
    it('walking_without_heart_rate_rise_is_suspicious', 0, () => {
      const c = new LiveDayCollector();
      c.setWorn(1);
      for (let s = 0; s <= 90; s++) {
        c.addPedometer(1000 + s * 2, s * 1000);
        c.addHeartRate(63, s * 1000);
      }
      const snap = c.snapshot(90000);
      expect(snap.stepsPerMinute).assertLarger(100);
      expect(snap.suspicious).assertTrue();
    });
    it('real_walk_is_plausible', 0, () => {
      const c = new LiveDayCollector();
      c.setWorn(1);
      for (let s = 0; s <= 90; s++) {
        c.addPedometer(500 + s * 2, s * 1000);
        c.addHeartRate(s < 10 ? 68 : 108, s * 1000);
      }
      expect(c.snapshot(90000).suspicious).assertFalse();
    });
    it('steps_with_watch_off_are_suspicious', 0, () => {
      const c = new LiveDayCollector();
      c.setWorn(0);
      for (let s = 0; s <= 60; s++) {
        c.addPedometer(s * 2, s * 1000);
      }
      expect(c.snapshot(60000).verdict).assertEqual('Kroki przy zdjętym zegarku');
    });
  });
}
