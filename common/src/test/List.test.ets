import claimTest from './Claim.test';
import healthTest from './Health.test';
import liveWearTest from './LiveWear.test';

export default function testsuite() {
  claimTest();
  healthTest();
  liveWearTest();
}
