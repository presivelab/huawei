import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { common } from '@kit.AbilityKit';
import { REMINDER_HOUR, reminderMomentAhead } from 'common';
import { REMINDER_CONTENT, REMINDER_IN_APP, REMINDER_PAST, REMINDER_SET, REMINDER_TITLE } from './VisitTexts';

/*
 * The reminder for a follow-up visit: a system calendar reminder (reminderAgentManager) at 09:00 on the
 * day the follow-up is due. It is set only when that moment is still ahead of the device's own clock; the
 * demo dates are counted back from the demo day, so most of them are in the past and set nothing.
 * When the system refuses (no permission, notifications off, an emulator without the service) the date
 * is still shown in the app and the screen says "Reminder saved in app". The moment itself is worked out
 * in `common` (`reminderMomentAhead`), where a logic test checks it.
 */

export class ReminderOutcome {
  /** True when the system accepted the reminder. */
  set: boolean = false;
  /** What the screen says. */
  line: string = REMINDER_IN_APP;
}

export async function setFollowUpReminder(context: Context | undefined, dueDate: string): Promise<ReminderOutcome> {
  const outcome = new ReminderOutcome();
  const at = reminderMomentAhead(dueDate, Date.now());
  if (at < 0) {
    outcome.line = REMINDER_PAST;
    return outcome;
  }
  try {
    const ability = context as common.UIAbilityContext;
    const when = new Date(at);
    const request: reminderAgentManager.ReminderRequestCalendar = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
      dateTime: {
        year: when.getFullYear(),
        month: when.getMonth() + 1,
        day: when.getDate(),
        hour: REMINDER_HOUR,
        minute: 0,
        second: 0
      },
      title: REMINDER_TITLE,
      content: REMINDER_CONTENT,
      wantAgent: {
        pkgName: ability.abilityInfo.bundleName,
        abilityName: ability.abilityInfo.name
      }
    };
    await reminderAgentManager.publishReminder(request);
    outcome.set = true;
    outcome.line = REMINDER_SET;
  } catch (e) {
    outcome.set = false;
    outcome.line = REMINDER_IN_APP;
  }
  return outcome;
}
