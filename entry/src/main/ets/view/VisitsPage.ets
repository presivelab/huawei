import { LengthMetrics } from '@kit.ArkUI';
import {
  DemoVisits,
  followUpDoneOnTime,
  serviceTypeLabel,
  Visit,
  ADHERENCE_ON_TIME,
  visitAdherence,
  visitDateText
} from 'common';
import { DEFAULT_PERSONA_ID, KEY_PERSONA } from '../report/ServiceLocator';
import { EmptyState } from '../ui/kit/EmptyState';
import { InfoChip } from '../ui/kit/InfoChip';
import {
  COLOR_FLAG_TEXT,
  COLOR_FLAG_TINT,
  COLOR_NOTE_TEXT,
  COLOR_NOTE_TINT,
  COLOR_OK_TEXT,
  SYMBOL_FORWARD,
  SYMBOL_TAB_REPORT,
  tierTint
} from '../ui/kit/KitTokens';
import { KEY_VISITS_REVISION, VisitService } from '../visits/VisitService';
import {
  ADD_RECEIPT_LABEL,
  BADGE_FOLLOW_UP,
  BADGE_NOTES,
  BADGE_SHARED,
  isVerified,
  KEY_VISIT_SELECTED,
  NO_VISITS,
  proofBadge,
  ROUTE_ADD_RECEIPT,
  ROUTE_VISIT_DETAILS,
  VISITS_DEMO_NOTE,
  VISITS_INTRO,
  VISITS_OTHER_PERSON,
  VISITS_TITLE
} from '../visits/VisitTexts';
import { BODY_SECONDARY, CAPTION, CARD_LARGE } from './Styles';

const TIER_A: string = 'A';

// The list of visits (route ROUTE_VISITS), opened from the Report tab: date, kind, the state of the proof,
// and whether there are notes and a follow-up kept on time. Everything on this screen stays on the phone.
@Component
export struct VisitsPage {
  @Consume('fwNav') nav: NavPathStack;
  @StorageProp(KEY_PERSONA) @Watch('load') personaId: string = DEFAULT_PERSONA_ID;
  @StorageProp(KEY_VISITS_REVISION) @Watch('load') visitsRevision: number = 0;
  @State visits: Visit[] = [];

  aboutToAppear(): void {
    VisitService.shared().ready().then((): void => {
      this.load();
    });
  }

  load(): void {
    this.visits = VisitService.shared().visits(this.personaId);
  }

  private hasFollowUpBadge(visit: Visit): boolean {
    return visitAdherence(visit, this.visits) === ADHERENCE_ON_TIME || followUpDoneOnTime(visit, this.visits);
  }

  private open(visit: Visit): void {
    AppStorage.setOrCreate<string>(KEY_VISIT_SELECTED, visit.id);
    this.nav.pushPathByName(ROUTE_VISIT_DETAILS, null);
  }

  @Builder
  row(visit: Visit) {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Column({ space: 2 }) {
          Text(visit.receipt === undefined ? VISITS_TITLE : serviceTypeLabel(visit.receipt.serviceType))
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(600)
            .fontColor($r('sys.color.font_primary'))
          Text(visit.receipt === undefined ? '' : visitDateText(visit.receipt.issueDate))
            .attributeModifier(CAPTION)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        SymbolGlyph(SYMBOL_FORWARD)
          .fontSize(16)
          .fontColor([$r('sys.color.icon_tertiary')])
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(6), cross: LengthMetrics.vp(6) } }) {
        if (isVerified(visit)) {
          InfoChip({ text: proofBadge(visit), fill: tierTint(TIER_A), textColor: COLOR_OK_TEXT, strong: true })
        } else if (visit.receipt !== undefined) {
          InfoChip({ text: proofBadge(visit), fill: COLOR_FLAG_TINT, textColor: COLOR_FLAG_TEXT, strong: true })
        } else {
          InfoChip({ text: proofBadge(visit) })
        }
        if (visit.notes !== undefined && visit.notes.length > 0) {
          InfoChip({ text: BADGE_NOTES })
        }
        if (this.hasFollowUpBadge(visit)) {
          InfoChip({ text: BADGE_FOLLOW_UP, fill: tierTint(TIER_A), textColor: COLOR_OK_TEXT })
        }
        if (visit.claimed) {
          InfoChip({ text: BADGE_SHARED })
        }
      }
      .width('100%')
    }
    .attributeModifier(CARD_LARGE)
    .accessibilityGroup(true)
    .onClick(() => {
      this.open(visit);
    })
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 14 }) {
          Text(VISITS_INTRO)
            .attributeModifier(BODY_SECONDARY)
            .padding({ left: 4, right: 4 })
          InfoChip({ text: VISITS_DEMO_NOTE, fill: COLOR_NOTE_TINT, textColor: COLOR_NOTE_TEXT })

          if (this.visits.length === 0) {
            Column({ space: 10 }) {
              EmptyState({ symbol: SYMBOL_TAB_REPORT, sentence: NO_VISITS, textId: 'fw_visits_empty' })
              if (!DemoVisits.hasVisits(this.personaId)) {
                Text(VISITS_OTHER_PERSON).attributeModifier(CAPTION)
              }
            }
            .attributeModifier(CARD_LARGE)
          } else {
            ForEach(this.visits, (visit: Visit) => {
              this.row(visit)
            }, (visit: Visit) => `${visit.id}|${visit.receiptStatus}|${visit.claimed}|${visit.notes === undefined}|${this.visitsRevision}`)
          }

          if (DemoVisits.hasVisits(this.personaId)) {
            Button(ADD_RECEIPT_LABEL)
              .buttonStyle(ButtonStyleMode.NORMAL)
              .width('100%')
              .constraintSize({ minHeight: 48 })
              .id('fw_visits_add')
              .onClick(() => {
                this.nav.pushPathByName(ROUTE_ADD_RECEIPT, null);
              })
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
    .title(VISITS_TITLE)
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
