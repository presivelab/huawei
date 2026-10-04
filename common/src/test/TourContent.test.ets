import { describe, it, expect } from '@ohos/hypium';
import {
  CODE_ELLIPSIS,
  demoClockText,
  displayCode,
  elapsedText,
  notObservedMinutes,
  packetLine,
  probeLine,
  probeStepLabel,
  REAL_ROWS,
  slotRuns,
  slotStateLabel,
  TOUR_STEPS,
  VERIFY_ORDER,
  wearSourceText
} from '../main/ets/present/TourContent';
import { WEAR_CHARGING, WEAR_OFF, WEAR_UNOBSERVED, WEAR_WORN } from '../main/ets/present/WatchDayPresent';
import { ProbeStep, ReceivedPacketInfo } from '../main/ets/watchlink/LinkProbe';

export default function tourContentTest() {
  describe('TourContent', () => {
    it('slot runs merge equal neighbours and add up to the day', 0, () => {
      const slots = 'C'.repeat(66) + 'W'.repeat(78) + 'O'.repeat(36) + 'W'.repeat(96) + 'U'.repeat(12);
      const runs = slotRuns(slots);
      expect(runs.length).assertEqual(5);
      expect(runs[0].state).assertEqual(WEAR_CHARGING);
      expect(runs[1].state).assertEqual(WEAR_WORN);
      expect(runs[2].state).assertEqual(WEAR_OFF);
      expect(runs[2].count).assertEqual(36);
      expect(runs[4].state).assertEqual(WEAR_UNOBSERVED);
      let total = 0;
      for (let i = 0; i < runs.length; i++) {
        total += runs[i].count;
      }
      expect(total).assertEqual(288);
    });

    it('an unknown slot character is shown as not observed, never as off wrist', 0, () => {
      const runs = slotRuns('W?O');
      expect(runs.length).assertEqual(3);
      expect(runs[1].state).assertEqual(WEAR_UNOBSERVED);
      expect(slotStateLabel(runs[1].state)).assertEqual('Not observed');
      expect(slotRuns('').length).assertEqual(0);
    });

    it('code is shown without its common indentation and keeps the skipped parts', 0, () => {
      const shown = displayCode(['    a();', CODE_ELLIPSIS, '      b();', '']);
      expect(shown[0]).assertEqual('a();');
      expect(shown[1]).assertEqual(CODE_ELLIPSIS);
      expect(shown[2]).assertEqual('  b();');
      expect(shown[3]).assertEqual('');
    });

    it('result lines, timings and wear sources read as plain words', 0, () => {
      const step = new ProbeStep();
      step.message = 'Duplicate day';
      expect(probeLine(step)).assertEqual('Duplicate day');
      step.note = 'Acknowledged again, counted once';
      expect(probeLine(step)).assertEqual('Duplicate day · Acknowledged again, counted once');
      expect(elapsedText(0)).assertEqual('Checked on this phone in under 1 ms');
      expect(elapsedText(12.4)).assertEqual('Checked on this phone in 12 ms');
      expect(wearSourceText('HR_SIGNAL')).assertEqual('heart-rate signal');
      expect(wearSourceText('SENSOR')).assertEqual('wear sensor');
    });

    it('the newest day, its unobserved time and its clock in plain words, without ids', 0, () => {
      const info = new ReceivedPacketInfo();
      info.seq = 5;
      info.date = '2026-10-08';
      info.bytes = 812;
      info.firstOfChain = false;
      const line = packetLine(info);
      expect(line).assertEqual('Thu 8 Oct · 812 bytes · signed by your watch · linked to the day before');
      expect(line.indexOf('#')).assertEqual(-1);
      info.firstOfChain = true;
      expect(packetLine(info).endsWith('the first day from this watch')).assertTrue();
      expect(notObservedMinutes('UUWWO?')).assertEqual(15);
      expect(demoClockText('REAL')).assertEqual('');
      expect(demoClockText('DEMO_X300')).assertEqual('Demo clock: simulated time');
      expect(demoClockText('DEMO_X300_FEED')).assertEqual('Demo feed: scripted readings on the demo clock');
    });

    it('each check step says what was sent by date and wear state, never by sequence number', 0, () => {
      const changed = new ProbeStep();
      changed.action = 'CHANGED';
      changed.date = '2026-10-08';
      changed.fromSlot = 'C';
      changed.toSlot = 'W';
      expect(probeStepLabel(changed)).assertEqual('Thu 8 Oct, 00:00–00:05 changed from charging to worn');
      const again = new ProbeStep();
      again.action = 'SENT_AGAIN';
      again.date = '2026-10-08';
      expect(probeStepLabel(again)).assertEqual('Thu 8 Oct sent again, unchanged');
      const ahead = new ProbeStep();
      ahead.action = 'SENT_AHEAD';
      ahead.date = '2026-10-08';
      ahead.heldDate = '2026-10-07';
      expect(probeStepLabel(ahead)).assertEqual('Thu 8 Oct arrives while Wed 7 Oct is held back');
      const late = new ProbeStep();
      late.action = 'SENT_LATE';
      late.date = '2026-10-07';
      expect(probeStepLabel(late)).assertEqual('Wed 7 Oct arrives late');
    });

    it('six numbered steps and seven checks', 0, () => {
      expect(TOUR_STEPS.length).assertEqual(6);
      for (let i = 0; i < TOUR_STEPS.length; i++) {
        expect(TOUR_STEPS[i].num).assertEqual(i + 1);
        expect(TOUR_STEPS[i].code.length > 0).assertTrue();
        expect(TOUR_STEPS[i].provedBy.length > 0 || TOUR_STEPS[i].limit.length > 0).assertTrue();
      }
      expect(VERIFY_ORDER.length).assertEqual(7);
      expect(REAL_ROWS.length > 0).assertTrue();
    });
  });
}
