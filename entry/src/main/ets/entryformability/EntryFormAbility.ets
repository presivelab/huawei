import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { CardStore } from '../platform/CardStore';

const DOMAIN = 0x0000;
const TAG = 'FairWear';

/*
 * The FairWear home-screen card (2x2). It shows the digest the app last stored: data source,
 * coverage and whether a result is ready. It never computes anything and never shows the tier.
 */
export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const params = want.parameters;
    if (params !== undefined) {
      const id = params[formInfo.FormParam.IDENTITY_KEY];
      if (typeof id === 'string') {
        CardStore.addFormId(this.context, id as string);
      }
    }
    return CardStore.binding(this.context);
  }

  onUpdateForm(formId: string): void {
    formProvider.updateForm(formId, CardStore.binding(this.context)).catch((e: Error) => {
      hilog.warn(DOMAIN, TAG, 'card update failed: %{public}s', e.message);
    });
  }

  onRemoveForm(formId: string): void {
    CardStore.removeFormId(this.context, formId);
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }
}
