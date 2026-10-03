import { describe, it, expect } from '@ohos/hypium';
import { HealthStatus } from '../main/ets/health/HealthRecords';
import { healthSourceLabel, healthStatusLabel } from '../main/ets/health/HealthStatusLabel';

export default function healthStatusLabelTest() {
  describe('HealthStatusLabel', () => {
    it('each status has its label', 0, () => {
      expect(healthStatusLabel(HealthStatus.NOT_AUTHORIZED)).assertEqual('Not connected');
      expect(healthStatusLabel(HealthStatus.DEMO)).assertEqual('Demo data');
      expect(healthStatusLabel(HealthStatus.UNAVAILABLE)).assertEqual('Unavailable in this build');
      expect(healthStatusLabel(HealthStatus.CONNECTED)).assertEqual('Connected');
    });

    it('no label and no source line contains an enum name', 0, () => {
      const all: string[] = [HealthStatus.NOT_AUTHORIZED, HealthStatus.DEMO, HealthStatus.UNAVAILABLE,
        HealthStatus.CONNECTED];
      for (let i = 0; i < all.length; i++) {
        const line = healthSourceLabel(all[i]);
        expect(line.indexOf('HUAWEI Health · ')).assertEqual(0);
        for (let j = 0; j < all.length; j++) {
          expect(line.indexOf(all[j])).assertEqual(-1);
        }
      }
    });

    it('an unknown value reads as not connected', 0, () => {
      expect(healthStatusLabel('')).assertEqual('Not connected');
      expect(healthStatusLabel('SOMETHING_ELSE')).assertEqual('Not connected');
    });
  });
}
