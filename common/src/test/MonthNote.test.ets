import { describe, it, expect } from '@ohos/hypium';
import { HesProfile } from '../main/ets/hes/HesTypes';
import { engineReportOf, engineSession } from '../main/ets/report/EngineReports';
import {
  LEDGER_KIND_NOTE,
  MONTH_NOTE_MAX_CHARS,
  monthNoteLedgerEntry,
  monthNoteRequest,
  monthNoteText
} from '../main/ets/report/MonthNote';
import { PersonaReport } from '../main/ets/report/ReportModels';

function reportOf(id: string, profile: HesProfile): PersonaReport {
  const session = engineSession(id);
  session.setProfile(profile);
  return engineReportOf(id, session);
}

const KEYS: string[] = ['v', 'profile', 'tier', 'score', 'coveragePct', 'confidence', 'eligible', 'discountPct',
  'components'];

export default function monthNoteTest() {
  describe('Month note: what is sent', () => {
    it('exactly the nine keys the server accepts, with the report values', 0, () => {
      const r = reportOf('kasia', HesProfile.HEALTH_WELLNESS);
      const body = JSON.parse(monthNoteRequest(r)) as Record<string, Object>;
      expect(Object.keys(body)).assertDeepEquals(KEYS);
      expect(body['profile'] as string).assertEqual('HEALTH_WELLNESS');
      expect(body['tier'] as string).assertEqual('B');
      expect(body['score'] as number).assertEqual(71);
      expect(body['discountPct'] as number).assertEqual(8);
      expect(body['eligible'] as boolean).assertTrue();
    });

    it('no name, no persona id, no period, no raw values', 0, () => {
      const r = reportOf('kasia', HesProfile.LONGEVITY_WELLNESS);
      const text = monthNoteRequest(r);
      expect(text.indexOf('Kasia')).assertEqual(-1);
      expect(text.indexOf('kasia')).assertEqual(-1);
      expect(text.indexOf(r.periodIso)).assertEqual(-1);
      // Raw values with a unit or separator ("6,950", "6 h 55") cannot be confused with a 0..100 score.
      for (let i = 0; i < r.components.length; i++) {
        const raw = r.components[i].raw;
        if (raw.length > 0 && !/^[0-9]+$/.test(raw)) {
          expect(text.indexOf(raw)).assertEqual(-1);
        }
      }
    });

    it('a missing component is -1 and not available; scores are whole numbers 0..100', 0, () => {
      const r = reportOf('kasia', HesProfile.HEALTH_WELLNESS);
      const body = JSON.parse(monthNoteRequest(r)) as Record<string, Object>;
      const comps = body['components'] as Record<string, Object>[];
      expect(comps.length).assertEqual(8);
      for (let i = 0; i < comps.length; i++) {
        expect(Object.keys(comps[i])).assertDeepEquals(['id', 'score', 'available']);
        const score = comps[i]['score'] as number;
        if (comps[i]['available'] as boolean) {
          expect(Number.isInteger(score) && score >= 0 && score <= 100).assertTrue();
        } else {
          expect(score).assertEqual(-1);
        }
      }
    });

    it('no score is sent as -1', 0, () => {
      const r = reportOf('ola', HesProfile.HEALTH_WELLNESS);
      const body = JSON.parse(monthNoteRequest(r)) as Record<string, Object>;
      expect(body['score'] as number).assertEqual(-1);
      expect(body['tier'] as string).assertEqual('NONE');
    });
  });

  describe('Month note: the answer and the ledger', () => {
    it('reads the text of a good answer and nothing else', 0, () => {
      expect(monthNoteText('{"text":"  A good month.  "}')).assertEqual('A good month.');
      expect(monthNoteText('{"error":"limit"}')).assertEqual('');
      expect(monthNoteText('not json')).assertEqual('');
      expect(monthNoteText('{"text":5}')).assertEqual('');
      expect(monthNoteText('[]')).assertEqual('');
      const long = 'x'.repeat(MONTH_NOTE_MAX_CHARS + 50);
      expect(monthNoteText(JSON.stringify({ text: long })).length).assertEqual(MONTH_NOTE_MAX_CHARS);
    });

    it('the ledger line holds the exact body and its size', 0, () => {
      const body = monthNoteRequest(reportOf('ania', HesProfile.HEALTH_WELLNESS));
      const e = monthNoteLedgerEntry(body, 1000);
      expect(e.kind).assertEqual(LEDGER_KIND_NOTE);
      expect(e.payload).assertEqual(body);
      expect(e.bytes).assertEqual(body.length);
      expect(e.t).assertEqual(1000);
    });
  });
}
