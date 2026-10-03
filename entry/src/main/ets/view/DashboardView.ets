import { ALL_HEALTH_SCOPES, HealthScope, HealthStatus } from 'common';
import { AddonSession, KEY_REVISION, KEY_STATUS, NO_VALUE } from '../addon/AddonSession';
import { HES_NOT_CONNECTED, HES_NOT_CONNECTED_BODY, scopeLabel, signalsHeading } from '../addon/AddonTexts';
import { DataSourceCard, SourceStatusLine } from './SourceParts';
import { BODY, BODY_SECONDARY, CAPTION, CARD, LABEL, TITLE } from './Styles';

class SignalRow {
  label: string;
  value: string;

  constructor(label: string, value: string) {
    this.label = label;
    this.value = value;
  }
}

@Component
struct ValueRow {
  @Prop label: string = '';
  @Prop value: string = NO_VALUE;

  build() {
    Row() {
      Text(this.label).attributeModifier(BODY).layoutWeight(1)
      Text(this.value).attributeModifier(BODY_SECONDARY)
    }
    .width('100%')
    .constraintSize({ minHeight: 40 })
  }
}

// The result screen after consent: tier, the signals behind it and the data source (AD-3).
// Until HES-Lite is part of the build the tier, score and coverage are "—", never a number.
@Component
export struct DashboardView {
  @StorageProp(KEY_STATUS) status: string = HealthStatus.NOT_AUTHORIZED;
  @StorageProp(KEY_REVISION) revision: number = 0;

  // `revision` is a parameter so the rows are rebuilt whenever the session changes.
  private signalRows(revision: number): SignalRow[] {
    const session: AddonSession = AddonSession.shared();
    const rows: SignalRow[] = [];
    for (let i = 0; i < ALL_HEALTH_SCOPES.length; i++) {
      const scope: HealthScope = ALL_HEALTH_SCOPES[i];
      let value: string = NO_VALUE;
      if (!session.source().isScopeEnabled(scope)) {
        value = 'Off · missing evidence';
      } else if (session.recordCount(scope) > 0) {
        value = session.recordCount(scope) + ' records';
      }
      rows.push(new SignalRow(scopeLabel(scope), value));
    }
    return rows;
  }

  private noRecords(revision: number): boolean {
    return AddonSession.shared().totalRecordCount() === 0;
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        SourceStatusLine()

        Column({ space: 4 }) {
          Text('Your tier').attributeModifier(LABEL)
          Text(NO_VALUE)
            .fontSize($r('sys.float.Title_L'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .id('fw_tier')
          Text(HES_NOT_CONNECTED).attributeModifier(TITLE)
          Text(HES_NOT_CONNECTED_BODY).attributeModifier(BODY_SECONDARY)
          Divider().color($r('sys.color.comp_divider')).margin({ top: 8, bottom: 4 })
          ValueRow({ label: 'Health Evidence Score', value: NO_VALUE })
          ValueRow({ label: 'Coverage', value: NO_VALUE })
        }
        .attributeModifier(CARD)

        Column({ space: 4 }) {
          Text(signalsHeading(this.status)).attributeModifier(TITLE)
          ForEach(this.signalRows(this.revision), (row: SignalRow) => {
            ValueRow({ label: row.label, value: row.value })
          }, (row: SignalRow) => row.label + '|' + row.value)
          if (this.noRecords(this.revision)) {
            Text('No demo records are loaded in this build. A data type that is switched off counts as ' +
              'missing evidence, never as zero.')
              .attributeModifier(CAPTION)
          }
        }
        .attributeModifier(CARD)

        DataSourceCard()
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
}
