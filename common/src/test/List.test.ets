import claimTest from './Claim.test';
import healthTest from './Health.test';
import liveWearTest from './LiveWear.test';
import entryTargetTest from './EntryTarget.test';
import cardDigestTest from './CardDigest.test';
import healthStatusLabelTest from './HealthStatusLabel.test';
import demoFeedTest from './DemoFeed.test';
import claimHardeningTest from './ClaimHardening.test';
import watchDayPresentTest from './WatchDayPresent.test';
import reportTest from './Report.test';

export default function testsuite() {
  claimTest();
  healthTest();
  liveWearTest();
  entryTargetTest();
  cardDigestTest();
  healthStatusLabelTest();
  demoFeedTest();
  claimHardeningTest();
  watchDayPresentTest();
  reportTest();
}
