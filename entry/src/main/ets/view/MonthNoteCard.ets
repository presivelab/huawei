import { monthNoteRequest, PersonaReport } from 'common';
import { fetchMonthNote } from '../platform/MonthNoteClient';
import { ShareService } from '../share/ShareService';
import { CAPTION, CARD_LARGE, HEADING } from './Styles';

const NOTE_TITLE: string = 'Your month';
const NOTE_BUTTON: string = 'Write my month note';
const NOTE_WAIT: string = 'Writing…';
const NOTE_SENDS: string = 'Sends the summary above (no raw data) to the FairWear server.';
const NOTE_CAPTION: string = 'Written automatically · may contain mistakes.';
const NOTE_FAILED: string = 'No note right now. Try again later.';

// A few sentences about the month on screen, written on request. The summary that is sent is recorded in
// "What left this phone" before it leaves. A new persona or profile clears the note.
@Component
export struct MonthNoteCard {
  @Prop @Watch('clear') report: PersonaReport;
  @State note: string = '';
  @State waiting: boolean = false;
  @State failed: boolean = false;

  clear(): void {
    this.note = '';
    this.failed = false;
  }

  private write(): void {
    if (this.waiting) {
      return;
    }
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      ShareService.shared().attach(context.filesDir);
    }
    const body: string = monthNoteRequest(this.report);
    ShareService.shared().recordNoteSummary(body);
    this.waiting = true;
    this.failed = false;
    fetchMonthNote(body).then((text: string): void => {
      this.waiting = false;
      this.note = text;
      this.failed = text.length === 0;
    });
  }

  build() {
    Column({ space: 8 }) {
      Text(NOTE_TITLE).attributeModifier(HEADING)
      if (this.note.length > 0) {
        Text(this.note)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_primary'))
          .id('fw_month_note')
        Text(NOTE_CAPTION).attributeModifier(CAPTION)
      } else {
        if (this.failed) {
          Text(NOTE_FAILED).attributeModifier(CAPTION)
        }
        Button(this.waiting ? NOTE_WAIT : NOTE_BUTTON)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .height(40)
          .enabled(!this.waiting)
          .id('fw_month_note_write')
          .onClick(() => {
            this.write();
          })
        Text(NOTE_SENDS).attributeModifier(CAPTION)
      }
    }
    .attributeModifier(CARD_LARGE)
    .alignItems(HorizontalAlign.Start)
  }
}
