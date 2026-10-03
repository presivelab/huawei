import claimTest from './Claim.test';
import healthTest from './Health.test';
import entryTargetTest from './EntryTarget.test';
import cardDigestTest from './CardDigest.test';

export default function testsuite() {
  claimTest();
  healthTest();
  entryTargetTest();
  cardDigestTest();
}
