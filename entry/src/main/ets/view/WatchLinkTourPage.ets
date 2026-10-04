import {
  dayTitle,
  demoClockText,
  displayCode,
  durationText,
  elapsedText,
  LEAVES_PHONE,
  notObservedMinutes,
  packetLine,
  PhoneLinkView,
  probeLine,
  ProbeKind,
  ProbeResult,
  ProbeStep,
  probeStepLabel,
  probeTitle,
  REAL_ROWS,
  ReceivedPacketInfo,
  ReviewRow,
  SlotRun,
  slotRuns,
  STORED_UNCHANGED,
  TOUR_INTRO,
  TOUR_STEPS,
  TOUR_TITLE,
  TourStep,
  transportLabel,
  VERIFY_ORDER,
  wearSourceText
} from 'common';
import { EmptyState } from '../ui/kit/EmptyState';
import { SYMBOL_VERIFIED, SYMBOL_WATCH } from '../ui/kit/KitTokens';
import { SectionCard } from '../ui/kit/SectionCard';
import { SlotTimeline } from '../ui/kit/SlotTimeline';
import { WearLegend } from '../ui/kit/WearBar';
import { KEY_LINK_REVISION, WatchLinkService } from '../watchlink/WatchLinkService';
import { BODY, BODY_SECONDARY, CAPTION, LABEL } from './Styles';

const NO_DAY_SENTENCE: string =
  'No day from the watch yet. Pair the watch, close a day on it and sync; this page then shows that day.';
const SHOW_CODE: string = 'Show the code';
const HIDE_CODE: string = 'Hide the code';
const PROVED_BY: string = 'Proved by these logic tests:';
const CHECKS_TITLE: string = 'Test the checks on this phone';
const CHECKS_SENTENCE: string =
  'Each button sends a changed or repeated day through the same checks this phone uses for real days. ' +
    'It works on a copy, so nothing you received is changed.';
const REAL_TITLE: string = 'Real and simulated in this build';
const PROBE_KINDS: ProbeKind[] = ['TAMPER', 'REPLAY', 'LATE'];

// "How Watch Link works": the watch-to-phone flow explained on the phone itself, with live values from the
// days the watch sent, the real code behind each step, and checks that run on this phone.
// Opened from the Watch link card, the app shortcut, or `aa start ... --ps fwTarget tour`.
// No key id, hash or sequence number is shown here (UI rule 3); they stay on "Verification details".
@Component
export struct WatchLinkTourPage {
  @StorageProp(KEY_LINK_REVISION) revision: number = 0;
  @State openStep: number = 0;                       // the step whose code is shown, 0 = none
  @State running: string = '';                       // the check that is running, '' = none
  @State tamper: ProbeResult = new ProbeResult('TAMPER');
  @State replay: ProbeResult = new ProbeResult('REPLAY');
  @State late: ProbeResult = new ProbeResult('LATE');
  @State tried: string[] = [];                       // checks run at least once on this page
  private infoRevision: number = -1;
  private infoCache: ReceivedPacketInfo | null = null;

  private view(revision: number): PhoneLinkView {
    return WatchLinkService.shared().view();
  }

  // The stored packet is read from a file, so one read serves a whole build.
  private info(revision: number): ReceivedPacketInfo | null {
    if (this.infoRevision !== revision) {
      this.infoCache = WatchLinkService.shared().latestReceived();
      this.infoRevision = revision;
    }
    return this.infoCache;
  }

  private hasDay(revision: number): boolean {
    return this.info(revision) !== null;
  }

  private dayText(revision: number): string {
    const info = this.info(revision);
    return info === null ? '' : dayTitle(info.date);
  }

  private runs(revision: number): SlotRun[] {
    const info = this.info(revision);
    return info === null ? [] : slotRuns(info.slots);
  }

  private result(kind: ProbeKind): ProbeResult {
    if (kind === 'TAMPER') {
      return this.tamper;
    }
    return kind === 'REPLAY' ? this.replay : this.late;
  }

  private async run(kind: ProbeKind): Promise<void> {
    if (this.running.length > 0) {
      return;
    }
    this.running = kind;
    const result = await WatchLinkService.shared().probe(kind);
    if (kind === 'TAMPER') {
      this.tamper = result;
    } else if (kind === 'REPLAY') {
      this.replay = result;
    } else {
      this.late = result;
    }
    if (this.tried.indexOf(kind) < 0) {
      this.tried = this.tried.concat([kind]);
    }
    this.running = '';
  }

  private statusColor(step: ProbeStep): ResourceColor {
    if (step.status === 'ACCEPTED') {
      return $r('sys.color.confirm');
    }
    return step.status === 'DUPLICATE' ? $r('sys.color.font_secondary') : $r('sys.color.warning');
  }

  @Builder
  codeBlock(step: TourStep) {
    Column({ space: 8 }) {
      Text(step.file).attributeModifier(LABEL)
      Scroll() {
        Text(displayCode(step.code).join('\n'))
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_primary'))
          .padding(12)
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius($r('sys.float.corner_radius_level4'))
      if (step.provedBy.length > 0) {
        Text(PROVED_BY).attributeModifier(CAPTION)
        ForEach(step.provedBy, (name: string) => {
          Text(`· ${name}`).attributeModifier(CAPTION)
        }, (name: string) => name)
      }
      if (step.limit.length > 0) {
        Text(step.limit)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.warning'))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // What is live on this phone for each step: values from the newest received day and the link state.
  @Builder
  liveFacts(step: TourStep) {
    if (step.num === 1 && this.hasDay(this.revision)) {
      SlotTimeline({ runs: this.runs(this.revision) })
      WearLegend()
      Text(`${this.dayText(this.revision)} · wear source: ${wearSourceText(this.info(this.revision)?.wearSource ?? '')}`)
        .attributeModifier(BODY_SECONDARY)
      if (demoClockText(this.info(this.revision)?.clock ?? '').length > 0) {
        Text(demoClockText(this.info(this.revision)?.clock ?? '')).attributeModifier(CAPTION)
      }
    } else if (step.num === 2 && this.hasDay(this.revision)) {
      Text(`Not observed on ${this.dayText(this.revision)}: ` +
        `${durationText(notObservedMinutes(this.info(this.revision)?.slots ?? ''))}. ` +
        'Shown as not observed, never as off wrist.')
        .attributeModifier(BODY_SECONDARY)
    } else if (step.num === 3 && this.hasDay(this.revision)) {
      Text(packetLine(this.info(this.revision) as ReceivedPacketInfo)).attributeModifier(BODY_SECONDARY)
    } else if (step.num === 4) {
      Text(`Transport now: ${transportLabel(this.view(this.revision).transport)}`).attributeModifier(BODY_SECONDARY)
    } else if (step.num === 5) {
      ForEach(VERIFY_ORDER, (label: string, index: number) => {
        Row({ space: 8 }) {
          Text(`${index + 1}`).attributeModifier(LABEL).width(20)
          Text(label).attributeModifier(BODY_SECONDARY).layoutWeight(1)
          if (this.hasDay(this.revision)) {
            SymbolGlyph(SYMBOL_VERIFIED)
              .fontSize(16)
              .fontColor([$r('sys.color.confirm')])
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }, (label: string) => label)
      if (this.hasDay(this.revision)) {
        Text(`${this.dayText(this.revision)} passed every check.`).attributeModifier(CAPTION)
      }
    } else if (step.num === 6) {
      if (this.view(this.revision).missingCount > 0) {
        Text(this.view(this.revision).missingCount === 1 ? '1 day is missing and shown as missing.' :
          `${this.view(this.revision).missingCount} days are missing and shown as missing.`)
          .attributeModifier(BODY_SECONDARY)
      } else if (this.hasDay(this.revision)) {
        Text('No day is missing.').attributeModifier(BODY_SECONDARY)
      }
    }
  }

  @Builder
  stepCard(step: TourStep) {
    SectionCard({ title: `${step.num} · ${step.title}` }) {
      Text(step.sentence).attributeModifier(BODY)
      this.liveFacts(step)
      Button(this.openStep === step.num ? HIDE_CODE : SHOW_CODE)
        .buttonStyle(ButtonStyleMode.TEXTUAL)
        .id(`fw_tour_code_${step.num}`)
        .onClick(() => {
          this.openStep = this.openStep === step.num ? 0 : step.num;
        })
      if (this.openStep === step.num) {
        this.codeBlock(step)
      }
    }
  }

  @Builder
  probeBlock(kind: ProbeKind) {
    Column({ space: 8 }) {
      Button(this.running === kind ? 'Checking…' : probeTitle(kind))
        .buttonStyle(ButtonStyleMode.NORMAL)
        .width('100%')
        .enabled(this.running.length === 0 && this.hasDay(this.revision))
        .id(`fw_tour_probe_${kind}`)
        .onClick(() => {
          this.run(kind);
        })
      if (this.tried.indexOf(kind) >= 0) {
        if (!this.result(kind).ran) {
          Text(this.result(kind).reason).attributeModifier(CAPTION)
        } else {
          ForEach(this.result(kind).steps, (step: ProbeStep) => {
            Column({ space: 4 }) {
              Text(probeStepLabel(step)).attributeModifier(CAPTION)
              Row({ space: 8 }) {
                Circle()
                  .width(8)
                  .height(8)
                  .fill(this.statusColor(step))
                Text(probeLine(step)).attributeModifier(BODY).layoutWeight(1)
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }, (step: ProbeStep, index: number) => `${kind}|${index}|${step.message}`)
          Text(elapsedText(this.result(kind).elapsedMs)).attributeModifier(CAPTION)
          if (this.result(kind).storedUnchanged) {
            Text(STORED_UNCHANGED).attributeModifier(CAPTION)
          }
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  reviewRow(row: ReviewRow) {
    Column({ space: 2 }) {
      Text(row.left).attributeModifier(LABEL)
      Text(row.right).attributeModifier(BODY_SECONDARY)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          Text(TOUR_INTRO).attributeModifier(BODY_SECONDARY)

          if (!this.hasDay(this.revision)) {
            SectionCard({ title: 'Watch link' }) {
              EmptyState({ symbol: SYMBOL_WATCH, sentence: NO_DAY_SENTENCE })
            }
          }

          ForEach(TOUR_STEPS, (step: TourStep) => {
            this.stepCard(step)
          }, (step: TourStep) => `${step.num}`)

          SectionCard({ title: CHECKS_TITLE }) {
            Text(CHECKS_SENTENCE).attributeModifier(BODY_SECONDARY)
            ForEach(PROBE_KINDS, (kind: ProbeKind) => {
              this.probeBlock(kind)
            }, (kind: ProbeKind) => kind)
          }

          SectionCard({ title: 'What leaves this phone' }) {
            Text(LEAVES_PHONE).attributeModifier(BODY)
          }

          SectionCard({ title: REAL_TITLE }) {
            ForEach(REAL_ROWS, (row: ReviewRow) => {
              this.reviewRow(row)
            }, (row: ReviewRow) => row.left)
          }
        }
        .alignItems(HorizontalAlign.Start)
        .padding({
          left: $r('sys.float.padding_level8'),
          right: $r('sys.float.padding_level8'),
          bottom: $r('sys.float.padding_level12')
        })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .title(TOUR_TITLE)
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
