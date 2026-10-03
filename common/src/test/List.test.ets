import claimTest from './Claim.test';
import healthTest from './Health.test';
import entryTargetTest from './EntryTarget.test';

export default function testsuite() {
  claimTest();
  healthTest();
  entryTargetTest();
}
