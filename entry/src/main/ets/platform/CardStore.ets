import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { formBindingData, formProvider } from '@kit.FormKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  CardDigest,
  cardCoverageText,
  cardResultText,
  decodeCardDigest,
  emptyCardDigest,
  encodeCardDigest
} from 'common';

/*
 * Keeps what the home-screen card shows.
 *
 * The app stores a digest (source, coverage, result ready) after each recalculation and pushes it to
 * every card the user has placed. The card ability reads the same digest when a card is added.
 * Stored in Preferences, inside the app sandbox. The digest holds no tier and no score.
 */

const DOMAIN = 0x0000;
const TAG = 'FairWear';
const STORE_NAME = 'fairwear_card';
const KEY_DIGEST = 'digest';
const KEY_FORM_IDS = 'formIds';
const MAX_FORMS = 16;

/** The fields bound to the card page through LocalStorage. */
export class CardView {
  source: string;
  coverage: string;
  result: string;

  constructor(digest: CardDigest) {
    this.source = digest.sourceLabel;
    this.coverage = cardCoverageText(digest);
    this.result = cardResultText(digest);
  }
}

export class CardStore {
  static loadDigest(context: common.Context): CardDigest {
    try {
      const store = preferences.getPreferencesSync(context, { name: STORE_NAME });
      const raw = store.getSync(KEY_DIGEST, '');
      if (typeof raw !== 'string') {
        return emptyCardDigest();
      }
      return decodeCardDigest(raw as string);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'card digest could not be read: %{public}s', (e as Error).message);
      return emptyCardDigest();
    }
  }

  static binding(context: common.Context): formBindingData.FormBindingData {
    return formBindingData.createFormBindingData(new CardView(CardStore.loadDigest(context)));
  }

  /** Called by the app after each recalculation: saves the digest and refreshes every placed card. */
  static async publish(context: common.Context, digest: CardDigest): Promise<void> {
    try {
      const store = preferences.getPreferencesSync(context, { name: STORE_NAME });
      store.putSync(KEY_DIGEST, encodeCardDigest(digest));
      await store.flush();
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'card digest could not be saved: %{public}s', (e as Error).message);
      return;
    }
    const data = formBindingData.createFormBindingData(new CardView(digest));
    const ids = CardStore.formIds(context);
    for (let i = 0; i < ids.length; i++) {
      try {
        await formProvider.updateForm(ids[i], data);
      } catch (e) {
        // The card was removed without a callback, or the form service is busy: skip it.
        hilog.warn(DOMAIN, TAG, 'card %{public}s was not updated: %{public}s', ids[i], (e as Error).message);
      }
    }
  }

  static formIds(context: common.Context): string[] {
    try {
      const store = preferences.getPreferencesSync(context, { name: STORE_NAME });
      const raw = store.getSync(KEY_FORM_IDS, '');
      if (typeof raw !== 'string' || (raw as string).length === 0) {
        return [];
      }
      return (raw as string).split(',').filter((id: string) => CardStore.isFormId(id));
    } catch (e) {
      return [];
    }
  }

  static addFormId(context: common.Context, formId: string): void {
    if (!CardStore.isFormId(formId)) {
      return;
    }
    const ids = CardStore.formIds(context);
    if (ids.indexOf(formId) >= 0) {
      return;
    }
    ids.push(formId);
    while (ids.length > MAX_FORMS) {
      ids.shift();
    }
    CardStore.saveFormIds(context, ids);
  }

  static removeFormId(context: common.Context, formId: string): void {
    const ids = CardStore.formIds(context).filter((id: string) => id !== formId);
    CardStore.saveFormIds(context, ids);
  }

  private static saveFormIds(context: common.Context, ids: string[]): void {
    try {
      const store = preferences.getPreferencesSync(context, { name: STORE_NAME });
      store.putSync(KEY_FORM_IDS, ids.join(','));
      store.flushSync();
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'card ids could not be saved: %{public}s', (e as Error).message);
    }
  }

  /** Form ids come from the system as decimal strings; anything else is ignored. */
  private static isFormId(id: string): boolean {
    if (id.length === 0 || id.length > 32) {
      return false;
    }
    for (let i = 0; i < id.length; i++) {
      const c = id.charCodeAt(i);
      if (c < 48 || c > 57) {
        return false;
      }
    }
    return true;
  }
}
