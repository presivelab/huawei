import { HealthStatus } from 'common';
import { KEY_REFUSED, KEY_STATUS, KEY_WAS_CONNECTED } from '../addon/AddonSession';
import {
  ADDON_SENTENCE,
  CONNECT_LABEL,
  DISCONNECTED_BODY,
  DISCONNECTED_TITLE,
  PRIVACY_SETTINGS_SENTENCE,
  READS_SENTENCE,
  RECONNECT_LABEL,
  REFUSED_BODY,
  REFUSED_TITLE,
  ROUTE_PLATFORM_CONSENT
} from '../addon/AddonTexts';
import { SourceStatusLine } from './SourceParts';
import { BODY, BODY_SECONDARY, CAPTION, CARD, TITLE } from './Styles';

// AD-1: the entry to the add-on while HUAWEI Health is not connected. No tier is shown here.
@Component
export struct WelcomeView {
  @Consume('fwNav') nav: NavPathStack;
  @StorageProp(KEY_STATUS) status: string = HealthStatus.NOT_AUTHORIZED;
  @StorageProp(KEY_REFUSED) refused: boolean = false;
  @StorageProp(KEY_WAS_CONNECTED) wasConnected: boolean = false;

  build() {
    Scroll() {
      Column({ space: 16 }) {
        SourceStatusLine()
        Text(ADDON_SENTENCE).attributeModifier(BODY)

        if (this.refused) {
          Column({ space: 8 }) {
            Text(REFUSED_TITLE).attributeModifier(TITLE)
            Text(REFUSED_BODY).attributeModifier(BODY_SECONDARY)
          }
          .attributeModifier(CARD)
          .id('fw_refused_notice')
        } else if (this.wasConnected) {
          Column({ space: 8 }) {
            Text(DISCONNECTED_TITLE).attributeModifier(TITLE)
            Text(DISCONNECTED_BODY).attributeModifier(BODY_SECONDARY)
          }
          .attributeModifier(CARD)
          .id('fw_disconnected_notice')
        }

        Button(this.wasConnected ? RECONNECT_LABEL : CONNECT_LABEL)
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .width('100%')
          .id('fw_connect')
          .onClick(() => {
            this.nav.pushPathByName(ROUTE_PLATFORM_CONSENT, null);
          })
        Text(READS_SENTENCE).attributeModifier(CAPTION)
        if (this.wasConnected) {
          Text(PRIVACY_SETTINGS_SENTENCE).attributeModifier(CAPTION)
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
}
