import { describe, it, expect } from '@ohos/hypium';
import { HealthStatus } from '../main/ets/health/HealthRecords';
import {
  buildCardDigest,
  cardCoverageText,
  cardResultText,
  cardSourceLabel,
  CARD_COVERAGE_NONE,
  CARD_NO_VALUE,
  decodeCardDigest,
  emptyCardDigest,
  encodeCardDigest
} from '../main/ets/card/CardDigest';

export default function cardDigestTest() {
  describe('CardDigest', () => {
    it('demo source with a result shows the label, the coverage and that a score is ready', 0, () => {
      const digest = buildCardDigest(HealthStatus.DEMO, 85, true);
      expect(digest.sourceLabel).assertEqual('HUAWEI Health · Demo data');
      expect(cardCoverageText(digest)).assertEqual('85%');
      expect(cardResultText(digest)).assertEqual('Score ready');
    });

    it('not connected or unavailable never shows coverage or a result', 0, () => {
      const refused = buildCardDigest(HealthStatus.NOT_AUTHORIZED, 85, true);
      expect(cardCoverageText(refused)).assertEqual(CARD_NO_VALUE);
      expect(cardResultText(refused)).assertEqual(CARD_NO_VALUE);
      const unavailable = buildCardDigest(HealthStatus.UNAVAILABLE, 85, true);
      expect(unavailable.sourceLabel).assertEqual('HUAWEI Health · Unavailable in this build');
      expect(cardCoverageText(unavailable)).assertEqual(CARD_NO_VALUE);
      expect(cardResultText(unavailable)).assertEqual(CARD_NO_VALUE);
    });

    it('zero coverage is shown as 0%, missing coverage as a dash', 0, () => {
      expect(cardCoverageText(buildCardDigest(HealthStatus.DEMO, 0, false))).assertEqual('0%');
      expect(cardCoverageText(buildCardDigest(HealthStatus.DEMO, CARD_COVERAGE_NONE, false)))
        .assertEqual(CARD_NO_VALUE);
    });

    it('the stored digest has exactly three keys and no tier or score', 0, () => {
      const json = encodeCardDigest(buildCardDigest(HealthStatus.DEMO, 70, true));
      const keys = Object.keys(JSON.parse(json) as Record<string, Object>).sort();
      expect(keys.length).assertEqual(3);
      expect(keys[0]).assertEqual('coveragePct');
      expect(keys[1]).assertEqual('resultReady');
      expect(keys[2]).assertEqual('sourceLabel');
      const lower = json.toLowerCase();
      expect(lower.indexOf('tier')).assertEqual(-1);
      expect(lower.indexOf('hes')).assertEqual(-1);
    });

    it('encode and decode round-trip', 0, () => {
      const back = decodeCardDigest(encodeCardDigest(buildCardDigest(HealthStatus.DEMO, 43, false)));
      expect(back.sourceLabel).assertEqual(cardSourceLabel(HealthStatus.DEMO));
      expect(back.coveragePct).assertEqual(43);
      expect(back.resultReady).assertFalse();
    });

    it('a malformed stored value gives the empty digest and never throws', 0, () => {
      const empty = emptyCardDigest();
      const bad = ['', '{not json', 'null', '42', '{"sourceLabel":7,"coveragePct":1,"resultReady":true}',
        '{"sourceLabel":"","coveragePct":1,"resultReady":true}', '{"coveragePct":1,"resultReady":true}'];
      for (let i = 0; i < bad.length; i++) {
        const digest = decodeCardDigest(bad[i]);
        expect(digest.sourceLabel).assertEqual(empty.sourceLabel);
        expect(digest.coveragePct).assertEqual(CARD_COVERAGE_NONE);
        expect(digest.resultReady).assertFalse();
      }
    });

    it('while connected the card names the source the reports come from', 0, () => {
      const digest = buildCardDigest(HealthStatus.DEMO, 90, true, 'Health Sim · Simulated data');
      expect(digest.sourceLabel).assertEqual('Health Sim · Simulated data');
      expect(cardCoverageText(digest)).assertEqual('90%');
      expect(cardResultText(digest)).assertEqual('Score ready');
      // The label survives the stored form the card reads.
      expect(decodeCardDigest(encodeCardDigest(digest)).sourceLabel).assertEqual('Health Sim · Simulated data');
    });

    it('a source label never replaces "Not connected" and never brings coverage with it', 0, () => {
      const refused = buildCardDigest(HealthStatus.NOT_AUTHORIZED, 90, true, 'Health Sim · Simulated data');
      expect(refused.sourceLabel).assertEqual('HUAWEI Health · Not connected');
      expect(cardCoverageText(refused)).assertEqual(CARD_NO_VALUE);
      expect(cardResultText(refused)).assertEqual(CARD_NO_VALUE);
      const unavailable = buildCardDigest(HealthStatus.UNAVAILABLE, 90, true, 'Health Sim · Simulated data');
      expect(unavailable.sourceLabel).assertEqual('HUAWEI Health · Unavailable in this build');
    });

    it('an empty label or one longer than 48 characters gives the label of the status', 0, () => {
      expect(buildCardDigest(HealthStatus.DEMO, 90, true, '').sourceLabel).assertEqual('HUAWEI Health · Demo data');
      const long = 'Health Sim · Simulated data · and a remark that does not fit';
      expect(long.length > 48).assertTrue();
      expect(buildCardDigest(HealthStatus.DEMO, 90, true, long).sourceLabel).assertEqual('HUAWEI Health · Demo data');
    });

    it('coverage outside 0..100 is clamped or dropped', 0, () => {
      expect(buildCardDigest(HealthStatus.DEMO, 140, true).coveragePct).assertEqual(100);
      expect(buildCardDigest(HealthStatus.DEMO, -5, true).coveragePct).assertEqual(CARD_COVERAGE_NONE);
      expect(buildCardDigest(HealthStatus.DEMO, 84.6, true).coveragePct).assertEqual(85);
    });
  });
}
