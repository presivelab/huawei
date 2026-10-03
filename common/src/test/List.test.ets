import claimTest from './Claim.test';
import healthTest from './Health.test';
import liveWearTest from './LiveWear.test';
import entryTargetTest from './EntryTarget.test';
import cardDigestTest from './CardDigest.test';

export default function testsuite() {
  claimTest();
  healthTest();
  liveWearTest();
  entryTargetTest();
  cardDigestTest();
}
