import { LengthMetrics } from '@kit.ArkUI';
import {
  BenefitLevel,
  benefitLabel,
  ComponentRow,
  dayOfMonth,
  DayState,
  dayStateLabel,
  dayTitle,
  DEFAULT_THRESHOLDS,
  FW_TAB_EVIDENCE,
  FW_TAB_REPORT,
  hasScore,
  HealthStatus,
  HesProfile,
  metricSpoken,
  periodDayIso,
  PersonaReport,
  profileNote,
  ReportTier,
  SCORE_TO,
  scoreSpoken,
  STRIP_DAYS,
  wearSpoken,
  weekdayShort
} from 'common';
import { KEY_STATUS } from '../addon/AddonSession';
import { ROUTE_SETTINGS, ROUTE_WHY } from '../addon/AddonTexts';
import { KEY_TAB } from '../nav/EntryRouter';
import {
  DEFAULT_PERSONA_ID,
  KEY_PERSONA,
  KEY_REPORT_PROFILE,
  KEY_REPORT_REVISION,
  NO_PROFILE_CHOICE,
  profileOf,
  reportService,
  reportsFromHealthSim,
  reportSourceLabel,
  selectedProfileReport,
  selectProfile
} from '../report/ServiceLocator';
import {
  countUnit,
  DISCLAIMER,
  EVIDENCE_LABEL,
  EVIDENCE_NOTE,
  EVIDENCE_TITLE,
  NO_SCORE_BODY,
  NO_SCORE_HEADLINE,
  NOT_MEASURED,
  NOT_MEASURED_NOTE,
  PREVIEW_LINE,
  reportSourceLine,
  SCORE_UNIT,
  SHARE_NEEDS_SCORE,
  tierHeadline,
  tileName,
  unlockSteps,
  UNLOCK_TITLE,
  WEAR_TITLE,
  WHY_LABEL,
  WHY_NO_SCORE_LABEL
} from '../report/ReportTexts';
import { CountBar } from '../ui/kit/CountBar';
import { str } from '../ui/Strings';
import { DayStrip, DayStripItem } from '../ui/kit/DayStrip';
import { InfoChip } from '../ui/kit/InfoChip';
import {
  COLOR_FLAG_TEXT,
  COLOR_OFF,
  COLOR_OK_TEXT,
  componentColor,
  componentSymbol,
  dayStateColor,
  SYMBOL_BENEFIT_FULL,
  SYMBOL_BENEFIT_NONE,
  SYMBOL_BENEFIT_PARTIAL,
  SYMBOL_CHECK,
  SYMBOL_FORWARD,
  SYMBOL_INFO,
  tierColor,
  tierTextColor
} from '../ui/kit/KitTokens';
import { MetricTile } from '../ui/kit/MetricTile';
import { DayStateLegend, MonthBar } from '../ui/kit/MonthBar';
import { RingStat } from '../ui/kit/RingStat';
import { StatusPill } from '../ui/kit/StatusPill';
import { TextLink } from '../ui/kit/TextLink';
import { TierBadge } from '../ui/kit/TierBadge';
import { DayDialCard } from './DayDialCard';
import { VisitsCard } from './VisitsCard';
import { DemoLiveCard } from './DemoLiveCard';
import { ProfileSwitch } from './ProfileSwitch';
import { CAPTION, CARD_LARGE, HEADING, statusDotColor } from './Styles';

const CARD_GAP: number = 14;
const TILE_GAP: number = 10;
const DAY_MIN: number = 1440;
const BAR_TOP: number = 100;    // the seven-day bars of a component are levels from 0 to 100
const HOURS_MARK: string = ' h ';

function dayStates(report: PersonaReport): string[] {
  const out: string[] = [];
  for (let i = 0; i < report.wear.days.length; i++) {
    out.push(report.wear.days[i].state);
  }
  return out;
}

// The states the legend names: compliant and short always, the others only when the month has them.
function legendStates(report: PersonaReport): string[] {
  const out: string[] = [DayState.COMPLIANT, DayState.SHORT];
  const optional: string[] = [DayState.SUSPICIOUS, DayState.SICK, DayState.UNKNOWN];
  const states = dayStates(report);
  for (let i = 0; i < optional.length; i++) {
    if (states.indexOf(optional[i]) >= 0) {
      out.push(optional[i]);
    }
  }
  return out;
}

// The last seven days as rings: the worn share of the day in the colour of the day's state. A sick day
// or a day without data is a grey ring, never an empty one.
function weekItems(report: PersonaReport): DayStripItem[] {
  const days = report.wear.days;
  const out: DayStripItem[] = [];
  for (let i = Math.max(0, days.length - STRIP_DAYS); i < days.length; i++) {
    const day = days[i];
    const date = periodDayIso(report.periodIso, day.n);
    const item = new DayStripItem();
    item.key = `${report.id}|${day.n}|${day.state}`;
    item.top = weekdayShort(date);
    item.bottom = dayOfMonth(date);
    item.spoken = str($r('app.string.report_view_day_spoken'), dayTitle(date), dayStateLabel(day.state));
    if (day.state === DayState.SICK || day.state === DayState.UNKNOWN) {
      item.unobserved = DAY_MIN;
    } else {
      item.worn = Math.round(DAY_MIN * day.wornPct / 100);
      item.tint = dayStateColor(day.state);
    }
    out.push(item);
  }
  return out;
}

function wearPasses(report: PersonaReport): boolean {
  return report.wear.totalDays > 0 &&
    report.wear.compliantDays * 100 >= DEFAULT_THRESHOLDS.minMonthlyPct * report.wear.totalDays;
}

function breaksLine(report: PersonaReport): string {
  const n = report.wear.suspicious;
  if (n === 0) {
    return str($r('app.string.report_view_breaks_none'));
  }
  if (report.wear.flagged) {
    return str($r('app.string.report_view_breaks_flagged'), n);
  }
  return n === 1 ? str($r('app.string.report_view_breaks_one')) :
    str($r('app.string.report_view_breaks_not_flagged'), n);
}

function benefitSymbol(report: PersonaReport): Resource {
  if (report.benefit === BenefitLevel.FULL) {
    return SYMBOL_BENEFIT_FULL;
  }
  return report.benefit === BenefitLevel.PARTIAL ? SYMBOL_BENEFIT_PARTIAL : SYMBOL_BENEFIT_NONE;
}

function benefitColor(report: PersonaReport): Resource {
  if (report.benefit === BenefitLevel.FULL) {
    return COLOR_OK_TEXT;
  }
  if (report.benefit === BenefitLevel.PARTIAL) {
    return tierTextColor(ReportTier.B);
  }
  return report.wear.flagged ? COLOR_FLAG_TEXT : $r('sys.color.font_secondary');
}

// "7 h 24" with the unit "min" is drawn as two pairs: 7 h 24 min.
function tileValue(row: ComponentRow): string {
  const cut = row.raw.indexOf(HOURS_MARK);
  return cut > 0 ? row.raw.substring(0, cut) : row.raw;
}

function tileUnit(row: ComponentRow): string {
  return row.raw.indexOf(HOURS_MARK) > 0 ? str($r('app.string.report_view_hours_unit')) : row.unit;
}

function tileExtraValue(row: ComponentRow): string {
  const cut = row.raw.indexOf(HOURS_MARK);
  return cut > 0 ? row.raw.substring(cut + HOURS_MARK.length) : '';
}

function tileExtraUnit(row: ComponentRow): string {
  return row.raw.indexOf(HOURS_MARK) > 0 ? row.unit : '';
}

// The counters behind a missing score: required components only, the ones still short of data first.
function unlockRows(report: PersonaReport): ComponentRow[] {
  const open: ComponentRow[] = [];
  const done: ComponentRow[] = [];
  for (let i = 0; i < report.components.length; i++) {
    const row = report.components[i];
    if (row.minCount <= 0) {
      continue;
    }
    if (row.validCount < row.minCount) {
      open.push(row);
    } else {
      done.push(row);
    }
  }
  return open.concat(done);
}

// The Report tab: the month of the selected persona. With a score: the score card, wear, the eight
// components, the live readings and the demo controls. Without one: how much evidence there is, what is
// still needed, and the same demo controls.
// While the report comes from the fixed preview, the source pill and a line under the score card say so.
@Component
export struct ReportView {
  @Consume('fwNav') nav: NavPathStack;
  @StorageProp(KEY_STATUS) status: string = HealthStatus.NOT_AUTHORIZED;
  @StorageProp(KEY_PERSONA) @Watch('reload') personaId: string = DEFAULT_PERSONA_ID;
  @StorageProp(KEY_REPORT_REVISION) @Watch('reload') reportRevision: number = 0;
  @StorageProp(KEY_REPORT_PROFILE) @Watch('reload') profileChoice: string = NO_PROFILE_CHOICE;
  @StorageLink(KEY_TAB) tab: number = FW_TAB_REPORT;
  @State report: PersonaReport = selectedProfileReport();
  private preview: boolean = reportService().isPreview();
  private scroller: Scroller = new Scroller();

  // The profile on screen: the one chosen for this persona, health insurance for any other persona.
  private profile(): HesProfile {
    return profileOf(this.profileChoice, this.personaId);
  }

  // Another persona (or new live readings, or another profile): take the report again; a new persona is
  // shown from the top.
  reload(): void {
    const next: PersonaReport = reportService().reportFor(this.personaId, this.profile());
    if (next.id !== this.report.id) {
      this.scroller.scrollEdge(Edge.Top);
    }
    this.report = next;
  }

  // The source pill: "Health Sim · Simulated data" once Health Sim sent its data, otherwise the status of
  // the HUAWEI Health connection. It reads the report revision, so it follows Connect and Disconnect.
  private sourceLine(): string {
    return this.reportRevision >= 0 && reportsFromHealthSim() ? reportSourceLabel() :
      reportSourceLine(this.status, this.preview);
  }

  @Builder
  sourceRows() {
    Column({ space: 6 }) {
      Row() {
        StatusPill({
          text: this.sourceLine(),
          dot: statusDotColor(this.status),
          textId: 'fw_report_source'
        })
      }
      .accessibilityText(str($r('app.string.report_view_source_spoken'), this.sourceLine()))
      .onClick(() => {
        this.nav.pushPathByName(ROUTE_SETTINGS, null);
      })

      Text(this.report.period.indexOf(SCORE_TO) >= 0 ? this.report.period :
        str($r('app.string.report_view_period_last_30'), this.report.period))
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
        .margin({ left: 4 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  previewLine() {
    if (this.preview) {
      Row({ space: 6 }) {
        SymbolGlyph(SYMBOL_INFO)
          .fontSize(16)
          .fontColor([$r('sys.color.icon_secondary')])
        Text(PREVIEW_LINE)
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
          .layoutWeight(1)
          .id('fw_preview_line')
      }
      .width('100%')
      .padding({ left: 4, right: 4 })
      .alignItems(VerticalAlign.Center)
    }
  }

  // Under the score card: the product the score is calculated for, and this month's discount for it.
  @Builder
  profileSwitch() {
    ProfileSwitch({
      selected: profileOf(this.profileChoice, this.personaId),
      note: profileNote(this.report),
      onPick: (profile: HesProfile) => {
        selectProfile(profile);
      }
    })
  }

  @Builder
  scoreCard() {
    Column({ space: 16 }) {
      Row({ space: 20 }) {
        RingStat({
          value: this.report.hes,
          total: 100,
          valueText: this.report.hes.toString(),
          unit: SCORE_UNIT,
          ringColor: tierColor(this.report.tier),
          spoken: scoreSpoken(this.report),
          diameter: 124,
          stroke: 11,
          stacked: true,
          valueFont: 40
        })
        Column({ space: 10 }) {
          Row({ space: 10 }) {
            TierBadge({ tier: this.report.tier })
            Text(tierHeadline(this.report))
              .fontSize($r('sys.float.Body_L'))
              .fontWeight(600)
              .fontColor($r('sys.color.font_primary'))
              .maxLines(2)
              .layoutWeight(1)
              .id('fw_tier_headline')
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(6), cross: LengthMetrics.vp(6) } }) {
            InfoChip({ text: str($r('app.string.report_view_coverage_chip'), this.report.coveragePct) })
            InfoChip({ text: str($r('app.string.report_view_confidence_chip'), this.report.confidence) })
          }
          .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Divider()
        .color($r('sys.color.comp_divider'))

      Row({ space: 8 }) {
        SymbolGlyph(benefitSymbol(this.report))
          .fontSize(22)
          .fontColor([benefitColor(this.report)])
        Column({ space: 2 }) {
          Text(benefitLabel(this.report.benefit))
            .fontSize($r('sys.float.Body_M'))
            .fontWeight(600)
            .fontColor(benefitColor(this.report))
            .id('fw_benefit')
          Text(this.report.benefitReason)
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .accessibilityGroup(true)

        TextLink({
          text: WHY_LABEL,
          linkId: 'fw_why_link',
          onTap: () => {
            this.nav.pushPathByName(ROUTE_WHY, null);
          }
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .attributeModifier(CARD_LARGE)
  }

  @Builder
  wearCard() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text(WEAR_TITLE)
          .attributeModifier(HEADING)
          .layoutWeight(1)
        Text(str($r('app.string.report_view_wear_days'), this.report.wear.compliantDays, this.report.wear.totalDays))
          .fontSize($r('sys.float.Body_M'))
          .fontWeight(600)
          .fontColor(wearPasses(this.report) ? COLOR_OK_TEXT : $r('sys.color.font_secondary'))
        if (wearPasses(this.report)) {
          SymbolGlyph(SYMBOL_CHECK)
            .fontSize(16)
            .fontColor([COLOR_OK_TEXT])
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      MonthBar({ states: dayStates(this.report), spoken: wearSpoken(this.report) })
      DayStateLegend({
        states: legendStates(this.report),
        note: str($r('app.string.report_view_wear_needed'), DEFAULT_THRESHOLDS.minMonthlyPct.toString())
      })

      Divider()
        .color($r('sys.color.comp_divider'))

      DayStrip({ items: weekItems(this.report) })

      Row({ space: 8 }) {
        Column({ space: 4 }) {
          Text(str($r('app.string.report_view_nights_worn'), this.report.wear.nightsWorn, this.report.wear.totalDays))
            .attributeModifier(CAPTION)
          Row({ space: 6 }) {
            if (this.report.wear.suspicious > 0) {
              Circle()
                .width(8)
                .height(8)
                .fill(COLOR_OFF)
            }
            Text(breaksLine(this.report))
              .fontSize($r('sys.float.Body_S'))
              .fontWeight(this.report.wear.flagged ? FontWeight.Medium : FontWeight.Regular)
              .fontColor(this.report.wear.flagged ? COLOR_FLAG_TEXT : $r('sys.color.font_secondary'))
              .id('fw_breaks')
          }
          .alignItems(VerticalAlign.Center)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        TextLink({
          text: EVIDENCE_LABEL,
          linkId: 'fw_evidence_link',
          onTap: () => {
            this.tab = FW_TAB_EVIDENCE;
          }
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .attributeModifier(CARD_LARGE)
  }

  @Builder
  tiles() {
    Row() {
      Text(EVIDENCE_TITLE)
        .attributeModifier(HEADING)
        .layoutWeight(1)
      Text(EVIDENCE_NOTE)
        .attributeModifier(CAPTION)
    }
    .width('100%')
    .padding({ left: 4, right: 4, top: 6 })
    .alignItems(VerticalAlign.Bottom)

    Grid() {
      ForEach(this.report.components, (row: ComponentRow) => {
        GridItem() {
          MetricTile({
            symbol: componentSymbol(row.id),
            name: tileName(row.id),
            tint: componentColor(row.id),
            value: row.available ? tileValue(row) : '',
            unit: tileUnit(row),
            extraValue: tileExtraValue(row),
            extraUnit: tileExtraUnit(row),
            bars: row.bars7,
            barsTop: BAR_TOP,
            emptyText: NOT_MEASURED,
            source: row.available ? row.source : NOT_MEASURED_NOTE,
            spoken: metricSpoken(tileName(row.id), row.raw, row.unit, row.available)
          })
        }
      }, (row: ComponentRow) => `${this.report.id}|${row.id}|${row.available}|${row.raw}|${row.unit}|${row.bars7.join(',')}`)
    }
    .columnsTemplate('1fr 1fr')
    .columnsGap(TILE_GAP)
    .rowsGap(TILE_GAP)
    .scrollBar(BarState.Off)
    .enableScrollInteraction(false)
    .width('100%')
  }

  @Builder
  noScoreCard() {
    Row({ space: 18 }) {
      RingStat({
        value: this.report.coveragePct,
        total: 100,
        valueText: str($r('app.string.report_view_evidence_pct'), this.report.coveragePct),
        unit: $r('app.string.report_view_evidence_unit'),
        ringColor: $r('sys.color.icon_secondary'),
        spoken: scoreSpoken(this.report),
        diameter: 104,
        stroke: 10,
        stacked: true,
        valueFont: 22,   // "47.5%" has five characters and must stay inside the ring
        dashed: true
      })
      Column({ space: 6 }) {
        Text(NO_SCORE_HEADLINE)
          .fontSize($r('sys.float.Title_S'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .id('fw_no_score')
        Text(NO_SCORE_BODY)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({
      left: 20,
      right: 20,
      top: 18,
      bottom: 18
    })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(24)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  unlockCard() {
    Column({ space: 10 }) {
      Text(UNLOCK_TITLE)
        .attributeModifier(HEADING)
      ForEach(unlockRows(this.report), (row: ComponentRow) => {
        CountBar({
          name: row.label,
          have: row.validCount,
          need: row.minCount,
          unit: countUnit(row.id),
          tint: componentColor(row.id)
        })
      }, (row: ComponentRow) => `${this.report.id}|${row.id}|${row.validCount}`)

      Divider()
        .color($r('sys.color.comp_divider'))

      Column({ space: 6 }) {
        ForEach(unlockSteps(), (step: string) => {
          Row({ space: 8 }) {
            SymbolGlyph(SYMBOL_FORWARD)
              .fontSize(14)
              .fontColor([$r('sys.color.icon_emphasize')])
              .margin({ top: 3 })
            Text(step)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_primary'))
              .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }, (step: string) => step)
      }
      .width('100%')

      TextLink({
        text: WHY_NO_SCORE_LABEL,
        linkId: 'fw_why_link_no_score',
        onTap: () => {
          this.nav.pushPathByName(ROUTE_WHY, null);
        }
      })
    }
    .attributeModifier(CARD_LARGE)
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: CARD_GAP }) {
        this.sourceRows()
        if (hasScore(this.report)) {
          this.scoreCard()
          this.profileSwitch()
          this.previewLine()
          DayDialCard({ personaId: this.report.id })
          this.wearCard()
          this.tiles()
          VisitsCard({ personaId: this.report.id })
          DemoLiveCard({ hr: this.report.live.hr, steps: this.report.live.steps, personaId: this.report.id })
          Text(DISCLAIMER)
            .attributeModifier(CAPTION)
            .padding({ left: 4, right: 4 })
        } else {
          this.noScoreCard()
          this.profileSwitch()
          this.previewLine()
          DayDialCard({ personaId: this.report.id })
          this.unlockCard()
          VisitsCard({ personaId: this.report.id })
          DemoLiveCard({ hr: this.report.live.hr, steps: this.report.live.steps, personaId: this.report.id })
          Text(SHARE_NEEDS_SCORE)
            .attributeModifier(CAPTION)
            .padding({ left: 4, right: 4 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .padding({
        left: 16,
        right: 16,
        top: 0,
        bottom: 24
      })
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
  }
}
