import { Visit } from 'common';
import { DEFAULT_PERSONA_ID } from '../report/ServiceLocator';
import { SYMBOL_TAB_REPORT } from '../ui/kit/KitTokens';
import { TextLink } from '../ui/kit/TextLink';
import { KEY_VISITS_REVISION, VisitService } from '../visits/VisitService';
import {
  isVerified,
  NO_VISITS,
  ROUTE_VISITS,
  visitCountText,
  VISITS_CARD_BODY,
  VISITS_CARD_LINK,
  VISITS_CARD_TITLE
} from '../visits/VisitTexts';
import { CAPTION, CARD_LARGE, HEADING } from './Styles';

// The way into Visits from the Report tab. Shown for every persona: with visits it says how many there
// are and how many receipts verified; without any it says "No visits yet". Visits never enter the score.
@Component
export struct VisitsCard {
  @Consume('fwNav') nav: NavPathStack;
  @Prop @Watch('load') personaId: string = DEFAULT_PERSONA_ID;
  @StorageProp(KEY_VISITS_REVISION) @Watch('load') visitsRevision: number = 0;
  @State total: number = 0;
  @State verified: number = 0;

  aboutToAppear(): void {
    VisitService.shared().ready().then((): void => {
      this.load();
    });
  }

  load(): void {
    const visits: Visit[] = VisitService.shared().visits(this.personaId);
    let verified = 0;
    for (let i = 0; i < visits.length; i++) {
      if (isVerified(visits[i])) {
        verified++;
      }
    }
    this.total = visits.length;
    this.verified = verified;
  }

  private summary(): string {
    if (this.total === 0) {
      return NO_VISITS;
    }
    return `${visitCountText(this.total)} · ${this.verified} with a verified receipt`;
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        SymbolGlyph(SYMBOL_TAB_REPORT)
          .fontSize(22)
          .fontColor([$r('sys.color.icon_secondary')])
        Text(VISITS_CARD_TITLE)
          .attributeModifier(HEADING)
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.summary())
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_primary'))
        .id('fw_visits_summary')
      Text(VISITS_CARD_BODY).attributeModifier(CAPTION)

      TextLink({
        text: VISITS_CARD_LINK,
        linkId: 'fw_visits_link',
        onTap: () => {
          this.nav.pushPathByName(ROUTE_VISITS, null);
        }
      })
    }
    .attributeModifier(CARD_LARGE)
  }
}
