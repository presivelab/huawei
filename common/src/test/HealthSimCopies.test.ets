// The Health Sim app (healthsim/) carries copies of FairWear's pure logic, so both apps generate, write and
// read the very same data. A copy is never edited in Health Sim: change the file in common/ and copy it
// again. Reads repository files, so it runs only under Node (not part of List.test.ets).
import { describe, it, expect } from '@ohos/hypium';
import { readRepoText } from '@fairwear/node-ports';

const COMMON: string = 'common/src/main/ets/';
const PHONE_COPIES: string = 'healthsim/entry/src/main/ets/fw/';
const WATCH_COPIES: string = 'healthsim/watch/src/main/ets/fw/';

// Everything HealthSimPayload.ets needs, by its imports.
const PHONE_FILES: string[] = [
  'claim/ClaimValidation.ets', 'claim/TierClaimCodec.ets',
  'health/HealthConnection.ets', 'health/HealthRecords.ets', 'health/HealthSimPayload.ets',
  'health/HealthSource.ets',
  'hes/HesComponents.ets', 'hes/HesComposite.ets', 'hes/HesConfidence.ets', 'hes/HesCurves.ets',
  'hes/HesEngine.ets', 'hes/HesMath.ets', 'hes/HesPersonas.ets', 'hes/HesPiecewise.ets', 'hes/HesPrng.ets',
  'hes/HesSession.ets', 'hes/HesSufficiency.ets', 'hes/HesTier.ets', 'hes/HesTypes.ets',
  'model/defaults.ets', 'model/types.ets',
  'platform/Bytes.ets',
  'rules/SelectiveNonWear.ets',
  'watchlink/JsonRead.ets', 'watchlink/WatchLinkTypes.ets',
  'wear/WearMonth.ets', 'wear/WearPersonas.ets'
];
// Everything DemoFeed.ets needs.
const WATCH_FILES: string[] = ['watchlink/DemoFeed.ets', 'watchlink/JsonRead.ets'];

function normalised(text: string): string {
  return text.split('\r').join('');
}

// The files of one copy set that differ from common/ or are missing. An absent copy set (the marker file
// is not there) is not checked: the Health Sim module may not be in this branch yet.
function differences(copies: string, files: string[], marker: string): string[] {
  if (readRepoText(copies + marker) === null) {
    return [];
  }
  const out: string[] = [];
  for (let i = 0; i < files.length; i++) {
    const original = readRepoText(COMMON + files[i]);
    const copy = readRepoText(copies + files[i]);
    if (original === null || copy === null || normalised(original) !== normalised(copy)) {
      out.push(copies + files[i]);
    }
  }
  return out;
}

export default function healthSimCopiesTest() {
  describe('Health Sim copies of the shared logic', () => {
    it('the phone module carries an unchanged copy of every file the payload needs', 0, () => {
      expect(differences(PHONE_COPIES, PHONE_FILES, 'health/HealthSimPayload.ets')).assertDeepEquals([]);
    });

    it('the watch module carries an unchanged copy of the demo feed', 0, () => {
      expect(differences(WATCH_COPIES, WATCH_FILES, 'watchlink/DemoFeed.ets')).assertDeepEquals([]);
    });
  });
}
