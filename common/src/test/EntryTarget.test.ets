import { describe, it, expect } from '@ohos/hypium';
import {
  FwTarget,
  FW_TAB_EVIDENCE,
  FW_TAB_REPORT,
  FW_TAB_SHARE,
  FW_TARGET_PARAM,
  fwTargetOpensSettings,
  fwTargetTab,
  resolveFwTarget,
  resolveFwTargetFromWant
} from '../main/ets/nav/EntryTarget';

export default function entryTargetTest() {
  describe('EntryTarget', () => {
    it('known targets resolve to themselves', 0, () => {
      expect(resolveFwTarget('dashboard')).assertEqual(FwTarget.DASHBOARD);
      expect(resolveFwTarget('share')).assertEqual(FwTarget.SHARE);
      expect(resolveFwTarget('source')).assertEqual(FwTarget.SOURCE);
      expect(FW_TARGET_PARAM).assertEqual('fwTarget');
    });

    it('case and surrounding spaces do not matter', 0, () => {
      expect(resolveFwTarget(' Share ')).assertEqual(FwTarget.SHARE);
      expect(resolveFwTarget('SOURCE')).assertEqual(FwTarget.SOURCE);
    });

    it('missing, empty or unknown value opens the dashboard', 0, () => {
      expect(resolveFwTarget(undefined)).assertEqual(FwTarget.DASHBOARD);
      expect(resolveFwTarget(null)).assertEqual(FwTarget.DASHBOARD);
      expect(resolveFwTarget('')).assertEqual(FwTarget.DASHBOARD);
      expect(resolveFwTarget('   ')).assertEqual(FwTarget.DASHBOARD);
      expect(resolveFwTarget('settings')).assertEqual(FwTarget.DASHBOARD);
      expect(resolveFwTarget('share/../../etc')).assertEqual(FwTarget.DASHBOARD);
    });

    it('a non-string value opens the dashboard and never throws', 0, () => {
      const asNumber: Object = 42;
      const asBoolean: Object = true;
      const asArray: Object = ['share'];
      const asRecord: Object = new Map<string, string>();
      expect(resolveFwTarget(asNumber)).assertEqual(FwTarget.DASHBOARD);
      expect(resolveFwTarget(asBoolean)).assertEqual(FwTarget.DASHBOARD);
      expect(resolveFwTarget(asArray)).assertEqual(FwTarget.DASHBOARD);
      expect(resolveFwTarget(asRecord)).assertEqual(FwTarget.DASHBOARD);
    });

    it('a card tap delivers the target inside a JSON string', 0, () => {
      expect(resolveFwTargetFromWant(undefined, '{"fwTarget":"source"}')).assertEqual(FwTarget.SOURCE);
      expect(resolveFwTargetFromWant(undefined, '{"fwTarget":"dashboard"}')).assertEqual(FwTarget.DASHBOARD);
      expect(resolveFwTargetFromWant('share', '{"fwTarget":"source"}')).assertEqual(FwTarget.SHARE);
    });

    it('malformed card parameters open the dashboard and never throw', 0, () => {
      const asNumber: Object = 7;
      expect(resolveFwTargetFromWant(undefined, undefined)).assertEqual(FwTarget.DASHBOARD);
      expect(resolveFwTargetFromWant(undefined, '')).assertEqual(FwTarget.DASHBOARD);
      expect(resolveFwTargetFromWant(undefined, '{not json')).assertEqual(FwTarget.DASHBOARD);
      expect(resolveFwTargetFromWant(undefined, 'null')).assertEqual(FwTarget.DASHBOARD);
      expect(resolveFwTargetFromWant(undefined, '"source"')).assertEqual(FwTarget.DASHBOARD);
      expect(resolveFwTargetFromWant(undefined, '{"fwTarget":{"x":1}}')).assertEqual(FwTarget.DASHBOARD);
      expect(resolveFwTargetFromWant(undefined, '{"other":"source"}')).assertEqual(FwTarget.DASHBOARD);
      expect(resolveFwTargetFromWant(undefined, asNumber)).assertEqual(FwTarget.DASHBOARD);
      expect(resolveFwTargetFromWant(asNumber, '{"fwTarget":"source"}')).assertEqual(FwTarget.SOURCE);
    });

    it('an oversized value opens the dashboard', 0, () => {
      let long = 'share';
      for (let i = 0; i < 12; i++) {
        long += long;
      }
      expect(resolveFwTarget(long)).assertEqual(FwTarget.DASHBOARD);
    });

    it('evidence is a known target, from a shortcut and from a card', 0, () => {
      expect(resolveFwTarget('evidence')).assertEqual(FwTarget.EVIDENCE);
      expect(resolveFwTarget(' Evidence ')).assertEqual(FwTarget.EVIDENCE);
      expect(resolveFwTargetFromWant('evidence', undefined)).assertEqual(FwTarget.EVIDENCE);
      expect(resolveFwTargetFromWant(undefined, '{"fwTarget":"evidence"}')).assertEqual(FwTarget.EVIDENCE);
      expect(resolveFwTarget('evidence/calendar')).assertEqual(FwTarget.DASHBOARD);
    });

    it('each target maps to its tab: dashboard Report, evidence Evidence, share Share', 0, () => {
      expect(fwTargetTab(FwTarget.DASHBOARD)).assertEqual(FW_TAB_REPORT);
      expect(fwTargetTab(FwTarget.EVIDENCE)).assertEqual(FW_TAB_EVIDENCE);
      expect(fwTargetTab(FwTarget.SHARE)).assertEqual(FW_TAB_SHARE);
      expect(FW_TAB_REPORT).assertEqual(0);
      expect(FW_TAB_EVIDENCE).assertEqual(1);
      expect(FW_TAB_SHARE).assertEqual(2);
    });

    it('source opens Settings above the Report tab; no other target opens Settings', 0, () => {
      expect(fwTargetOpensSettings(FwTarget.SOURCE)).assertTrue();
      expect(fwTargetTab(FwTarget.SOURCE)).assertEqual(FW_TAB_REPORT);
      expect(fwTargetOpensSettings(FwTarget.DASHBOARD)).assertFalse();
      expect(fwTargetOpensSettings(FwTarget.EVIDENCE)).assertFalse();
      expect(fwTargetOpensSettings(FwTarget.SHARE)).assertFalse();
    });

    it('an unresolved or unknown text never selects a tab other than Report', 0, () => {
      expect(fwTargetTab('settings')).assertEqual(FW_TAB_REPORT);
      expect(fwTargetTab('')).assertEqual(FW_TAB_REPORT);
      expect(fwTargetTab(resolveFwTarget('SHARE '))).assertEqual(FW_TAB_SHARE);
      expect(fwTargetOpensSettings('settings')).assertFalse();
    });
  });
}
