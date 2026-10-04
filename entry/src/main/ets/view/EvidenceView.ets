import { ItemRestriction, SegmentButton, SegmentButtonOptions, SegmentButtonTextItem } from '@kit.ArkUI';
import {
  appealsIn,
  CALENDAR_WEEKDAYS,
  calendarCells,
  CalendarCell,
  calendarDaySpoken,
  canAppeal,
  clockText,
  DayState,
  dayStateLabel,
  dayTitle,
  DEFAULT_THRESHOLDS,
  flagRuleText,
  isAppealed,
  minutesText,
  periodDaySpoken,
  PersonaReport,
  withAppeal
} from 'common';
import { ROUTE_VERIFICATION, VERIFICATION_HINT, VERIFICATION_LABEL } from '../addon/AddonTexts';
import {
  APPEAL_LABEL,
  APPEAL_MARK_SPOKEN,
  APPEAL_NOTE,
  APPEAL_SENT,
  BREAKS_LABEL,
  CALENDAR_HINT,
  CALENDAR_TITLE,
  DAY_CHARGING,
  DAY_NIGHT,
  DAY_NIGHT_NO,
  DAY_NIGHT_YES,
  DAY_WORN,
  DAYS_LABEL,
  dayStateNote,
  EVIDENCE_SEGMENT_CALENDAR,
  EVIDENCE_SEGMENT_WATCH,
  FLAG_CHIP,
  FLAG_LINE,
  NIGHTS_LABEL
} from '../report/ReportTexts';
import {
  DEFAULT_PERSONA_ID,
  KEY_PERSONA,
  KEY_REPORT_REVISION,
  reportService,
  selectedReport
} from '../report/ServiceLocator';
import { InfoChip } from '../ui/kit/InfoChip';
import {
  COLOR_FLAG_TEXT,
  COLOR_FLAG_TINT,
  dayStateColor,
  SYMBOL_CHECK
} from '../ui/kit/KitTokens';
import { DayStateLegend } from '../ui/kit/MonthBar';
import { WearBar } from '../ui/kit/WearBar';
import { EvidenceBreak, EvidenceDay, evidenceDay, KEY_APPEALS, noEvidenceDay } from './EvidenceDayData';
import { CAPTION, CARD_LARGE, HEADING } from './Styles';
import { WatchDaysCard, WatchLinkCard } from './WatchLinkCard';

const CARD_GAP: number = 14;
const WEEK: number = 7;
const CELL_GAP: number = 6;
const CELL_HEIGHT: number = 52;
const DAY_MIN: number = 1440;
const SEGMENT_CALENDAR: number = 0;

// The weeks of the calendar: seven cells each.
function weeksOf(cells: CalendarCell[]): CalendarCell[][] {
  const out: CalendarCell[][] = [];
  for (let i = 0; i < cells.length; i += WEEK) {
    out.push(cells.slice(i, i + WEEK));
  }
  return out;
}

// The states the legend names: compliant always, the others only when the month has them.
function legendStates(report: PersonaReport): string[] {
  const out: string[] = [DayState.COMPLIANT];
  const optional: string[] = [DayState.SHORT, DayState.SUSPICIOUS, DayState.SICK, DayState.UNKNOWN];
  for (let s = 0; s < optional.length; s++) {
    for (let d = 0; d < report.wear.days.length; d++) {
      if (report.wear.days[d].state === optional[s]) {
        out.push(optional[s]);
        break;
      }
    }
  }
  return out;
}

function breakLine(b: EvidenceBreak): string {
  return `Off the wrist ${clockText(b.startMin)} · ${minutesText(b.minutes)}`;
}

function breakTag(b: EvidenceBreak): string {
  if (b.suspicious) {
    return 'Suspicious';
  }
  return b.judged ? 'Not suspicious' : 'Not judged';
}

// The Evidence tab: the calendar of the month with a sheet per day, and the days received from the watch.
// The calendar reads the report of the selected persona; the day sheet shows what the report service says
// about the day and lets the person appeal a day that counts against them.
@Component
export struct EvidenceView {
  @Consume('fwNav') nav: NavPathStack;
  @StorageProp(KEY_PERSONA) @Watch('reload') personaId: string = DEFAULT_PERSONA_ID;
  @StorageProp(KEY_REPORT_REVISION) @Watch('reload') reportRevision: number = 0;
  @StorageLink(KEY_APPEALS) appeals: string[] = [];
  @State report: PersonaReport = selectedReport();
  @State segmentOptions: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [{ text: EVIDENCE_SEGMENT_CALENDAR }, { text: EVIDENCE_SEGMENT_WATCH }] as
    ItemRestriction<SegmentButtonTextItem>
  });
  @State segment: number[] = [SEGMENT_CALENDAR];
  @State day: EvidenceDay = noEvidenceDay();
  @State sheetOpen: boolean = false;

  // Another persona, or a closed day: take the report again; an open sheet follows its day.
  reload(): void {
    const next: PersonaReport = reportService().report(this.personaId);
    if (next.id !== this.report.id) {
      this.sheetOpen = false;
      this.day = noEvidenceDay();
    } else if (this.day.n > 0) {
      this.day = evidenceDay(next, this.day.n);
    }
    this.report = next;
  }

  private appealed(date: string): boolean {
    return isAppealed(this.appeals, this.report.id, date);
  }

  private openDay(n: number): void {
    this.day = evidenceDay(this.report, n);
    this.sheetOpen = true;
  }

  @Builder
  stat(value: string, label: string, strong: boolean) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize($r('sys.float.Subtitle_L'))
        .fontWeight(FontWeight.Bold)
        .fontColor(strong ? COLOR_FLAG_TEXT : $r('sys.color.font_primary'))
        .maxLines(1)
      Text(label)
        .attributeModifier(CAPTION)
        .maxLines(2)
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .accessibilityGroup(true)
    .accessibilityText(`${label}, ${value}`)
  }

  @Builder
  summaryCard() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text(CALENDAR_TITLE)
          .attributeModifier(HEADING)
          .layoutWeight(1)
        if (this.report.wear.flagged) {
          InfoChip({
            text: FLAG_CHIP,
            fill: COLOR_FLAG_TINT,
            textColor: COLOR_FLAG_TEXT,
            strong: true
          })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 12 }) {
        this.stat(`${this.report.wear.compliantDays} of ${this.report.wear.totalDays}`, DAYS_LABEL, false)
        this.stat(`${this.report.wear.nightsWorn} of ${this.report.wear.totalDays}`, NIGHTS_LABEL, false)
        this.stat(`${this.report.wear.suspicious}`, BREAKS_LABEL, this.report.wear.suspicious > 0)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .id('fw_evidence_summary')

      if (this.report.wear.flagged) {
        Text(FLAG_LINE)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_FLAG_TEXT)
          .width('100%')
          .padding({
            left: 12,
            right: 12,
            top: 8,
            bottom: 8
          })
          .backgroundColor(COLOR_FLAG_TINT)
          .borderRadius(12)
          .id('fw_evidence_flag')
      }
      if (this.report.wear.suspicious > 0) {
        Text(flagRuleText(DEFAULT_THRESHOLDS))
          .attributeModifier(CAPTION)
      }
    }
    .attributeModifier(CARD_LARGE)
  }

  @Builder
  dayCell(cell: CalendarCell) {
    if (cell.n === 0) {
      Row()
        .layoutWeight(1)
        .height(CELL_HEIGHT)
    } else {
      Column({ space: 4 }) {
        Text(cell.label)
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
        Row({ space: 2 }) {
          Circle()
            .width(8)
            .height(8)
            .fill(dayStateColor(cell.state))
          if (this.appealed(cell.date)) {
            SymbolGlyph(SYMBOL_CHECK)
              .fontSize(10)
              .fontColor([$r('sys.color.icon_emphasize')])
          }
        }
        .height(10)
        .alignItems(VerticalAlign.Center)
      }
      .layoutWeight(1)
      .height(CELL_HEIGHT)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(12)
      .id(`fw_day_${cell.n}`)
      .accessibilityGroup(true)
      .accessibilityText(calendarDaySpoken(
        periodDaySpoken(this.report.periodIso, cell.n, cell.state), this.appealed(cell.date)))
      .onClick(() => {
        this.openDay(cell.n);
      })
    }
  }

  @Builder
  calendarCard() {
    Column({ space: 10 }) {
      Row({ space: CELL_GAP }) {
        ForEach(CALENDAR_WEEKDAYS, (name: string) => {
          Text(name)
            .attributeModifier(CAPTION)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
        }, (name: string) => name)
      }
      .width('100%')
      .accessibilityLevel('no-hide-descendants')

      Column({ space: CELL_GAP }) {
        ForEach(weeksOf(calendarCells(this.report)), (week: CalendarCell[]) => {
          Row({ space: CELL_GAP }) {
            ForEach(week, (cell: CalendarCell) => {
              this.dayCell(cell)
            }, (cell: CalendarCell, index: number) =>
            `${this.report.id}|${index}|${cell.n}|${cell.state}|${this.appealed(cell.date)}`)
          }
          .width('100%')
        }, (week: CalendarCell[], index: number) =>
        `${this.report.id}|${index}|${week[0].n}|${this.appeals.length}|${this.reportRevision}`)
      }
      .width('100%')

      DayStateLegend({ states: legendStates(this.report) })
      if (appealsIn(this.report, this.appeals) > 0) {
        Row({ space: 6 }) {
          SymbolGlyph(SYMBOL_CHECK)
            .fontSize(12)
            .fontColor([$r('sys.color.icon_emphasize')])
          Text(APPEAL_SENT)
            .attributeModifier(CAPTION)
        }
        .alignItems(VerticalAlign.Center)
      }
      Text(CALENDAR_HINT)
        .attributeModifier(CAPTION)
    }
    .attributeModifier(CARD_LARGE)
  }

  @Builder
  fact(value: string, label: string) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize($r('sys.float.Subtitle_M'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
      Text(label)
        .attributeModifier(CAPTION)
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .accessibilityGroup(true)
    .accessibilityText(`${value} ${label}`)
  }

  @Builder
  dayFacts() {
    Column({ space: 12 }) {
      WearBar({
        worn: this.day.wornMin,
        charging: this.day.chargingMin,
        off: Math.max(0, DAY_MIN - this.day.wornMin - this.day.chargingMin),
        unobserved: 0
      })
      Row({ space: 12 }) {
        this.fact(minutesText(this.day.wornMin), DAY_WORN)
        this.fact(minutesText(this.day.chargingMin), DAY_CHARGING)
        this.fact(this.day.nightWorn ? DAY_NIGHT_YES : DAY_NIGHT_NO, DAY_NIGHT)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (this.day.breaks.length > 0) {
        Column({ space: 6 }) {
          ForEach(this.day.breaks, (b: EvidenceBreak) => {
            Row({ space: 8 }) {
              Text(breakLine(b))
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_primary'))
                .layoutWeight(1)
              Text(breakTag(b))
                .fontSize($r('sys.float.Body_S'))
                .fontWeight(b.suspicious ? FontWeight.Medium : FontWeight.Regular)
                .fontColor(b.suspicious ? COLOR_FLAG_TEXT : $r('sys.color.font_secondary'))
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .accessibilityGroup(true)
          }, (b: EvidenceBreak, index: number) => `${this.day.date}|${index}|${b.startMin}|${b.minutes}`)
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  daySheet() {
    Column({ space: 16 }) {
      Column({ space: 14 }) {
        Row({ space: 8 }) {
          Circle()
            .width(10)
            .height(10)
            .fill(dayStateColor(this.day.state))
          Text(dayStateLabel(this.day.state))
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .layoutWeight(1)
            .id('fw_day_state')
          if (this.appealed(this.day.date)) {
            InfoChip({ text: APPEAL_SENT, strong: true })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .accessibilityGroup(true)
        .accessibilityText(dayStateLabel(this.day.state) +
          (this.appealed(this.day.date) ? `, ${APPEAL_MARK_SPOKEN}` : ''))

        if (this.day.detailed && this.day.state !== DayState.UNKNOWN) {
          this.dayFacts()
        }

        Text(this.day.detailed && this.day.reason.length > 0 ? `${this.day.reason}.` :
          dayStateNote(this.day.state))
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
          .id('fw_day_reason')
      }
      .attributeModifier(CARD_LARGE)

      if (canAppeal(this.day.state)) {
        Column({ space: 8 }) {
          Button(this.appealed(this.day.date) ? APPEAL_SENT : APPEAL_LABEL)
            .buttonStyle(this.appealed(this.day.date) ? ButtonStyleMode.NORMAL : ButtonStyleMode.EMPHASIZED)
            .enabled(!this.appealed(this.day.date))
            .width('100%')
            .height(48)
            .id('fw_day_appeal')
            .onClick(() => {
              this.appeals = withAppeal(this.appeals, this.report.id, this.day.date);
            })
          Text(APPEAL_NOTE)
            .attributeModifier(CAPTION)
            .padding({ left: 4, right: 4 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .padding({
      left: 16,
      right: 16,
      top: 8,
      bottom: 32
    })
  }

  @Builder
  watchDays() {
    WatchLinkCard()

    WatchDaysCard()

    // Everything technical about the watch link sits behind this one button.
    Column({ space: 8 }) {
      Button(VERIFICATION_LABEL)
        .buttonStyle(ButtonStyleMode.NORMAL)
        .width('100%')
        .id('fw_link_details')
        .onClick(() => {
          this.nav.pushPathByName(ROUTE_VERIFICATION, null);
        })
      Text(VERIFICATION_HINT).attributeModifier(CAPTION)
    }
    .width('100%')
  }

  build() {
    Scroll() {
      Column({ space: CARD_GAP }) {
        SegmentButton({ options: this.segmentOptions, selectedIndexes: $segment })
          .id('fw_evidence_segment')

        if (this.segment[0] === SEGMENT_CALENDAR) {
          this.summaryCard()
          this.calendarCard()
        } else {
          this.watchDays()
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
    .bindSheet($$this.sheetOpen, this.daySheet(), {
      height: SheetSize.FIT_CONTENT,
      title: { title: dayTitle(this.day.date), subtitle: this.report.name },
      showClose: true,
      backgroundColor: $r('sys.color.background_secondary')
    })
  }
}
