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
import { BODY, BODY_SECONDARY, CAPTION, CARD, TITLE } from './Styles';

// The source status, shown on every screen that shows data: "HUAWEI Health · DEMO · last sync —".
@Component
export struct SourceStatusLine {
  @StorageProp(KEY_STATUS) status: string = HealthStatus.NOT_AUTHORIZED;
  @StorageProp(KEY_LAST_SYNC) lastSync: string = NO_VALUE;

  build() {
    Text(sourceLine(this.status, this.lastSync))
      .fontSize($r('sys.float.Body_M'))
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_primary'))
      .padding({
        left: $r('sys.float.padding_level6'),
        right: $r('sys.float.padding_level6'),
        top: $r('sys.float.padding_level3'),
        bottom: $r('sys.float.padding_level3')
      })
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius($r('sys.float.corner_radius_level8'))
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
      Text('Data source').attributeModifier(TITLE)
      Text(sourceLine(this.status, this.lastSync)).attributeModifier(BODY)
      Text(statusExplanation(this.status)).attributeModifier(BODY_SECONDARY)
      if (this.status !== HealthStatus.NOT_AUTHORIZED) {
        Text('Data types allowed: ' + this.scopesOn + ' of 7').attributeModifier(BODY_SECONDARY)
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
