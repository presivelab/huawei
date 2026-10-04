import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { resourceManager } from '@kit.LocalizationKit';

// Turns a string resource into text for code outside build(): state fields, sentences with a value,
// texts that are compared. A component takes a resource without values as it is: Text($r('app.string.…')).
// Every text with a value goes through str(): a Text built from $r('…', value) leaves "%%" as two signs.

const DOMAIN = 0x0000;
const TAG = 'FairWear';

let manager: resourceManager.ResourceManager | undefined = undefined;

// Called once by the ability, before any page is built.
export function initStrings(context: common.Context): void {
  manager = context.resourceManager;
}

// The text of a string resource in the current language. `args` fill the pattern in the order given:
// %s takes a string, %d a whole number. A wrong kind of value fails; the log then names the resource.
export function str(res: Resource, ...args: Array<string | number>): string {
  if (manager === undefined) {
    return '';
  }
  try {
    return args.length > 0 ? manager.getStringSync(res.id, ...args) : manager.getStringSync(res.id);
  } catch (e) {
    hilog.warn(DOMAIN, TAG, 'string resource %{public}d could not be read', res.id);
    return '';
  }
}

// A text that is either a string already or a resource without values.
export function textOf(value: ResourceStr): string {
  return typeof value === 'string' ? value : str(value);
}
