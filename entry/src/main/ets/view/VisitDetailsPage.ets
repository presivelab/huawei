import {
  ADHERENCE_ON_TIME,
  adherenceLabel,
  ClaimLine,
  followUpDoneOnTime,
  MedicalReceipt,
  NoteItem,
  notesOfKind,
  receiptStatusMessage,
  segmentById,
  serviceTypeLabel,
  sourceQuote,
  TranscriptSegment,
  Visit,
  VISIT_NEVER_SHARED,
  visitAdherence,
  visitById,
  visitDateOf,
  visitDateText,
  visitShareBlock
} from 'common';
import { InfoChip } from '../ui/kit/InfoChip';
import {
  COLOR_FLAG_TEXT,
  COLOR_FLAG_TINT,
  COLOR_NOTE_TEXT,
  COLOR_NOTE_TINT,
  COLOR_OK_TEXT,
  SYMBOL_CHECK,
  SYMBOL_EXPAND,
  SYMBOL_INFO,
  tierTint
} from '../ui/kit/KitTokens';
import { ReminderOutcome, setFollowUpReminder } from '../visits/VisitReminder';
import { KEY_VISITS_REVISION, VisitService } from '../visits/VisitService';
import {
  AMOUNT_UNIT,
  BADGE_NO_RECEIPT,
  BADGE_SHARED,
  DELETE_CONFIRM,
  DELETE_LABEL,
  DELETE_NO,
  DELETE_YES,
  DETAILS_TITLE,
  FOLLOW_UP_DONE,
  FOLLOW_UP_DUE_PREFIX,
  FOLLOW_UP_OF_PREFIX,
  KEY_VISIT_SELECTED,
  NOTES_DELETED,
  NOTES_FOLLOW_UP,
  NOTES_FOOTER,
  NOTES_MEDICATIONS,
  NOTES_NONE,
  NOTES_QUESTIONS,
  NOTES_RECOMMENDATIONS,
  NOTES_RULES,
  NOTES_TESTS,
  NOTES_TITLE,
  PARTNER_SEES_TITLE,
  PROOF_AMOUNT,
  PROOF_CLINIC,
  PROOF_DATE,
  PROOF_ONLY_YOU,
  PROOF_TITLE,
  PROOF_TYPE,
  REMINDER_LABEL,
  ROUTE_VISIT_SHARE,
  SHARE_VISIT_LABEL,
  TRANSCRIPT_BANNER,
  TRANSCRIPT_LABEL,
  transcriptSpeakerLine
} from '../visits/VisitTexts';
import { BODY_SECONDARY, CAPTION, CARD_LARGE, HEADING, LABEL } from './Styles';

const TIER_A: string = 'A';

interface FactParams {
  label: string;
  value: string;
}

interface NoteSectionParams {
  title: string;
  kind: string;
}

// One visit (route ROUTE_VISIT_DETAILS): the proof, which only the user sees; what a partner would see;
// the notes taken from the recording by fixed rules, each with the sentence it came from; the transcript;
// and the way to delete the recording. The id of the visit comes from AppStorage (KEY_VISIT_SELECTED).
@Component
export struct VisitDetailsPage {
  @Consume('fwNav') nav: NavPathStack;
  @StorageProp(KEY_VISIT_SELECTED) @Watch('load') visitId: string = '';
  @StorageProp(KEY_VISITS_REVISION) @Watch('load') visitsRevision: number = 0;
  @State receipt: MedicalReceipt | null = null;
  @State status: string = '';
  @State verified: boolean = false;
  @State claimed: boolean = false;
  @State notes: NoteItem[] = [];
  @State transcript: TranscriptSegment[] = [];
  @State dueDate: string = '';
  @State followUpDone: boolean = false;
  @State earlierDate: string = '';
  @State onTime: boolean = false;
  @State partnerLines: ClaimLine[] = [];
  @State block: string = '';
  @State openNote: string = '';
  @State showTranscript: boolean = false;
  @State confirmDelete: boolean = false;
  @State deleted: boolean = false;
  @State reminderLine: string = '';

  aboutToAppear(): void {
    VisitService.shared().ready().then((): void => {
      this.load();
    });
  }

  load(): void {
    const service = VisitService.shared();
    const visit: Visit | null = service.visit(this.visitId);
    if (visit === null) {
      this.receipt = null;
      this.notes = [];
      this.transcript = [];
      return;
    }
    const all = service.visits(visit.personaId);
    const receipt = visit.receipt;
    this.receipt = receipt === undefined ? null : receipt;
    this.status = visit.receiptStatus === undefined ? '' : visit.receiptStatus;
    this.verified = receipt !== undefined && visit.receiptStatus === 'VERIFIED';
    this.claimed = visit.claimed;
    this.notes = visit.notes === undefined ? [] : visit.notes.slice();
    this.transcript = visit.transcript === undefined ? [] : visit.transcript.slice();
    this.dueDate = visit.followUpDueDate === undefined ? '' : visit.followUpDueDate;
    this.followUpDone = followUpDoneOnTime(visit, all);
    const earlier = visitById(all, visit.followUpOfVisitId);
    const earlierDate = earlier === null ? undefined : visitDateOf(earlier);
    this.earlierDate = earlierDate === undefined ? '' : earlierDate;
    this.block = visitShareBlock(visit);
    const adherence = visitAdherence(visit, all);
    this.onTime = adherence === ADHERENCE_ON_TIME;
    this.partnerLines = receipt === undefined ? [] : [
      { label: PROOF_TYPE, value: serviceTypeLabel(receipt.serviceType) },
      { label: PROOF_DATE, value: visitDateText(receipt.issueDate) },
      { label: NOTES_FOLLOW_UP, value: adherenceLabel(adherence) }
    ];
    if (this.transcript.length === 0) {
      this.showTranscript = false;
    }
  }

  private deleteRecording(): void {
    this.confirmDelete = false;
    if (VisitService.shared().deleteTranscript(this.visitId)) {
      this.deleted = true;
      this.openNote = '';
    }
  }

  private remind(): void {
    const context = this.getUIContext().getHostContext();
    setFollowUpReminder(context, this.dueDate).then((outcome: ReminderOutcome): void => {
      this.reminderLine = outcome.line;
    });
  }

  @Builder
  fact(p: FactParams) {
    Row({ space: 12 }) {
      Text(p.label).attributeModifier(CAPTION)
      Text(p.value)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.End)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  proofCard() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(PROOF_TITLE)
          .attributeModifier(HEADING)
          .layoutWeight(1)
        InfoChip({ text: PROOF_ONLY_YOU })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.receipt !== null) {
        Row({ space: 8 }) {
          if (this.verified) {
            InfoChip({
              text: receiptStatusMessage(this.status),
              fill: tierTint(TIER_A),
              textColor: COLOR_OK_TEXT,
              strong: true
            })
          } else {
            InfoChip({
              text: receiptStatusMessage(this.status),
              fill: COLOR_FLAG_TINT,
              textColor: COLOR_FLAG_TEXT,
              strong: true
            })
          }
        }
        .width('100%')

        if (this.receipt.issuerName.length > 0) {
          this.fact({ label: PROOF_CLINIC, value: this.receipt.issuerName })
        }
        this.fact({ label: PROOF_DATE, value: visitDateText(this.receipt.issueDate) })
        this.fact({ label: PROOF_TYPE, value: serviceTypeLabel(this.receipt.serviceType) })
        this.fact({ label: PROOF_AMOUNT, value: `${this.receipt.amount} ${AMOUNT_UNIT}` })
      } else {
        Text(BADGE_NO_RECEIPT).attributeModifier(BODY_SECONDARY)
      }
    }
    .attributeModifier(CARD_LARGE)
  }

  @Builder
  partnerCard() {
    Column({ space: 10 }) {
      Text(PARTNER_SEES_TITLE).attributeModifier(HEADING)
      if (this.block.length > 0) {
        Row({ space: 8 }) {
          SymbolGlyph(SYMBOL_INFO)
            .fontSize(18)
            .fontColor([$r('sys.color.icon_secondary')])
          Text(this.block)
            .attributeModifier(BODY_SECONDARY)
            .layoutWeight(1)
            .id('fw_visit_block')
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      } else {
        ForEach(this.partnerLines, (line: ClaimLine) => {
          this.fact({ label: line.label, value: line.value })
        }, (line: ClaimLine) => `${line.label}|${line.value}`)
      }
      Text(VISIT_NEVER_SHARED)
        .attributeModifier(CAPTION)
        .id('fw_visit_never_shared')
      if (this.claimed) {
        InfoChip({ text: BADGE_SHARED })
      }
      Button(SHARE_VISIT_LABEL)
        .buttonStyle(ButtonStyleMode.NORMAL)
        .width('100%')
        .constraintSize({ minHeight: 48 })
        .enabled(this.receipt !== null)
        .id('fw_visit_share')
        .onClick(() => {
          this.nav.pushPathByName(ROUTE_VISIT_SHARE, null);
        })
    }
    .attributeModifier(CARD_LARGE)
  }

  @Builder
  quotes(item: NoteItem) {
    Column({ space: 4 }) {
      ForEach(item.sourceSegmentIds, (id: string) => {
        Text(this.quoteOf(id))
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
          .fontStyle(FontStyle.Italic)
      }, (id: string) => id)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 12 })
    .border({ width: { left: 2 }, color: $r('sys.color.comp_divider') })
  }

  private quoteOf(segmentId: string): string {
    const segment = segmentById(this.transcript, segmentId);
    return segment === null ? '' : sourceQuote(segment);
  }

  @Builder
  noteRow(item: NoteItem, key: string) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Text(item.text)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
        SymbolGlyph(SYMBOL_EXPAND)
          .fontSize(12)
          .fontColor([$r('sys.color.icon_tertiary')])
          .rotate({ angle: this.openNote === key ? 180 : 0 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (item.dueDate !== undefined) {
        Text(FOLLOW_UP_DUE_PREFIX + visitDateText(item.dueDate)).attributeModifier(CAPTION)
      }
      if (this.openNote === key) {
        this.quotes(item)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .constraintSize({ minHeight: 32 })
    .onClick(() => {
      this.openNote = this.openNote === key ? '' : key;
    })
  }

  @Builder
  noteSection(p: NoteSectionParams) {
    if (notesOfKind(this.notes, p.kind).length > 0) {
      Column({ space: 6 }) {
        Text(p.title).attributeModifier(LABEL)
        ForEach(notesOfKind(this.notes, p.kind), (item: NoteItem, index: number) => {
          this.noteRow(item, `${p.kind}|${index}`)
        }, (item: NoteItem, index: number) => `${p.kind}|${index}|${item.text}|${this.openNote}`)
        if (p.kind === 'FOLLOW_UP') {
          this.followUpState()
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  // Whether the follow-up was kept, and the reminder for it. Reads the visit, not the notes.
  @Builder
  followUpState() {
    if (this.followUpDone) {
      Row({ space: 6 }) {
        SymbolGlyph(SYMBOL_CHECK)
          .fontSize(16)
          .fontColor([COLOR_OK_TEXT])
        Text(FOLLOW_UP_DONE)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_OK_TEXT)
          .id('fw_visit_follow_up_done')
      }
      .alignItems(VerticalAlign.Center)
    } else if (this.dueDate.length > 0) {
      Button(REMINDER_LABEL)
        .buttonStyle(ButtonStyleMode.TEXTUAL)
        .constraintSize({ minHeight: 44 })
        .id('fw_visit_remind')
        .onClick(() => {
          this.remind();
        })
    }
    if (this.reminderLine.length > 0) {
      Text(this.reminderLine)
        .attributeModifier(CAPTION)
        .id('fw_visit_reminder_line')
    }
  }

  @Builder
  notesCard() {
    Column({ space: 14 }) {
      Text(NOTES_TITLE).attributeModifier(HEADING)
      if (this.notes.length > 0) {
        Text(NOTES_RULES).attributeModifier(CAPTION)
        this.noteSection({ title: NOTES_RECOMMENDATIONS, kind: 'RECOMMENDATION' })
        this.noteSection({ title: NOTES_MEDICATIONS, kind: 'MEDICATION' })
        this.noteSection({ title: NOTES_TESTS, kind: 'TEST' })
        this.noteSection({ title: NOTES_FOLLOW_UP, kind: 'FOLLOW_UP' })
        this.noteSection({ title: NOTES_QUESTIONS, kind: 'QUESTION' })
        Divider().color($r('sys.color.comp_divider'))
        Text(NOTES_FOOTER)
          .attributeModifier(CAPTION)
          .id('fw_visit_notes_footer')
      } else {
        Text(this.deleted ? NOTES_DELETED : NOTES_NONE)
          .attributeModifier(BODY_SECONDARY)
          .id('fw_visit_no_notes')
        if (this.dueDate.length > 0) {
          Column({ space: 6 }) {
            Text(NOTES_FOLLOW_UP).attributeModifier(LABEL)
            Text(FOLLOW_UP_DUE_PREFIX + visitDateText(this.dueDate))
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_primary'))
            this.followUpState()
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
      }
      if (this.earlierDate.length > 0) {
        Column({ space: 4 }) {
          Text(NOTES_FOLLOW_UP).attributeModifier(LABEL)
          Text(FOLLOW_UP_OF_PREFIX + visitDateText(this.earlierDate))
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_primary'))
          if (this.onTime) {
            Text(adherenceLabel(ADHERENCE_ON_TIME))
              .fontSize($r('sys.float.Body_M'))
              .fontWeight(FontWeight.Medium)
              .fontColor(COLOR_OK_TEXT)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .attributeModifier(CARD_LARGE)
  }

  @Builder
  transcriptCard() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(TRANSCRIPT_LABEL)
          .attributeModifier(HEADING)
          .layoutWeight(1)
        SymbolGlyph(SYMBOL_EXPAND)
          .fontSize(16)
          .fontColor([$r('sys.color.icon_secondary')])
          .rotate({ angle: this.showTranscript ? 180 : 0 })
      }
      .width('100%')
      .constraintSize({ minHeight: 44 })
      .alignItems(VerticalAlign.Center)
      .id('fw_visit_transcript_toggle')
      .onClick(() => {
        this.showTranscript = !this.showTranscript;
      })

      if (this.showTranscript) {
        InfoChip({ text: TRANSCRIPT_BANNER, fill: COLOR_NOTE_TINT, textColor: COLOR_NOTE_TEXT, strong: true })
        ForEach(this.transcript, (segment: TranscriptSegment) => {
          Column({ space: 2 }) {
            Text(transcriptSpeakerLine(segment))
              .attributeModifier(CAPTION)
            Text(segment.text)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_primary'))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }, (segment: TranscriptSegment) => segment.id)
      }

      Divider().color($r('sys.color.comp_divider'))

      if (this.confirmDelete) {
        Text(DELETE_CONFIRM)
          .attributeModifier(BODY_SECONDARY)
          .id('fw_visit_delete_confirm')
        Row({ space: 12 }) {
          Button(DELETE_NO)
            .buttonStyle(ButtonStyleMode.NORMAL)
            .layoutWeight(1)
            .constraintSize({ minHeight: 44 })
            .id('fw_visit_delete_no')
            .onClick(() => {
              this.confirmDelete = false;
            })
          Button(DELETE_YES)
            .buttonStyle(ButtonStyleMode.NORMAL)
            .role(ButtonRole.ERROR)
            .layoutWeight(1)
            .constraintSize({ minHeight: 44 })
            .id('fw_visit_delete_yes')
            .onClick(() => {
              this.deleteRecording();
            })
        }
        .width('100%')
      } else {
        Button(DELETE_LABEL)
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .role(ButtonRole.ERROR)
          .constraintSize({ minHeight: 44 })
          .id('fw_visit_delete')
          .onClick(() => {
            this.confirmDelete = true;
          })
      }
    }
    .attributeModifier(CARD_LARGE)
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 14 }) {
          this.proofCard()
          this.partnerCard()
          this.notesCard()
          if (this.transcript.length > 0) {
            this.transcriptCard()
          }
        }
        .alignItems(HorizontalAlign.Start)
        .padding({
          left: 16,
          right: 16,
          top: 4,
          bottom: 24
        })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .title(this.receipt === null ? DETAILS_TITLE : serviceTypeLabel(this.receipt.serviceType))
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
