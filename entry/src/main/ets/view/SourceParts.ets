import { HealthStatus } from 'common';
import {
  AddonSession,
  KEY_LAST_SYNC,
  KEY_SCOPES_ON,
  KEY_STATUS,
  KEY_WAS_CONNECTED,
  NO_VALUE
} from '../addon/AddonSession';
import {
  CONNECT_LABEL,
  DISCONNECT_LABEL,
  PRIVACY_SETTINGS_SENTENCE,
  RECONNECT_LABEL,
  ROUTE_PLATFORM_CONSENT,
  sourceLine,
  statusExplanation
} from '../addon/AddonTexts';
import { StatusPill } from '../ui/kit/StatusPill';
import { str } from '../ui/Strings';
import { BODY, BODY_SECONDARY, CAPTION, CARD, statusDotColor, TITLE } from './Styles';

// A status dot and the source line, for example a blue dot and the brand followed by "Demo data".
@Component
struct SourceLineRow {
  @Prop status: string = HealthStatus.NOT_AUTHORIZED;
  @Prop lastSync: string = NO_VALUE;

  build() {
    Row({ space: 8 }) {
      Circle()
        .width(8)
        .height(8)
        .fill(statusDotColor(this.status))
      Text(sourceLine(this.status, this.lastSync))
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
    }
    .alignItems(VerticalAlign.Center)
  }
}

// The source status, shown on every screen that shows data.
@Component
export struct SourceStatusLine {
  @StorageProp(KEY_STATUS) status: string = HealthStatus.NOT_AUTHORIZED;
  @StorageProp(KEY_LAST_SYNC) lastSync: string = NO_VALUE;

  build() {
    Row() {
      StatusPill({ text: sourceLine(this.status, this.lastSync), dot: statusDotColor(this.status) })
    }
    .id('fw_source_status')
  }
}

// AD-3: the "Data source" card with status, last sync, disconnect and reconnect.
@Component
export struct DataSourceCard {
  @Consume('fwNav') nav: NavPathStack;
  @StorageProp(KEY_STATUS) status: string = HealthStatus.NOT_AUTHORIZED;
  @StorageProp(KEY_LAST_SYNC) lastSync: string = NO_VALUE;
  @StorageProp(KEY_SCOPES_ON) scopesOn: number = 0;
  @StorageProp(KEY_WAS_CONNECTED) wasConnected: boolean = false;

  build() {
    Column({ space: 8 }) {
      Text($r('app.string.source_card_title')).attributeModifier(TITLE)
      SourceLineRow({ status: this.status, lastSync: this.lastSync })
      Text(statusExplanation(this.status)).attributeModifier(BODY_SECONDARY)
      if (this.status !== HealthStatus.NOT_AUTHORIZED) {
        Text(str($r('app.string.source_types_allowed'), this.scopesOn)).attributeModifier(BODY_SECONDARY)
        Button(DISCONNECT_LABEL)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .width('100%')
          .margin({ top: $r('sys.float.padding_level4') })
          .id('fw_disconnect')
          .onClick(() => {
            AddonSession.shared().disconnect();
            this.nav.clear();
          })
      } else {
        Button(this.wasConnected ? RECONNECT_LABEL : CONNECT_LABEL)
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .width('100%')
          .margin({ top: $r('sys.float.padding_level4') })
          .id('fw_connect_card')
          .onClick(() => {
            this.nav.pushPathByName(ROUTE_PLATFORM_CONSENT, null);
          })
      }
      Text(PRIVACY_SETTINGS_SENTENCE).attributeModifier(CAPTION)
    }
    .attributeModifier(CARD)
  }
}
