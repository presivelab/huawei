import { ALL_HEALTH_SCOPES, HealthStatus } from 'common';
import { KEY_REFUSED, KEY_STATUS, KEY_WAS_CONNECTED } from '../addon/AddonSession';
import {
  CONNECT_LABEL,
  DETAILS_LABEL,
  DISCONNECTED_BODY,
  DISCONNECTED_TITLE,
  LEAVES_SHORT,
  LEAVES_TITLE,
  NEVER_READS_SHORT,
  NEVER_READS_TITLE,
  PRIVACY_SETTINGS_SENTENCE,
  READS_SENTENCE,
  READS_SHORT,
  READS_TITLE,
  RECONNECT_LABEL,
  REFUSED_BODY,
  REFUSED_TITLE,
  ROUTE_PLATFORM_CONSENT,
  scopeLabel,
  VALUE_SENTENCE
} from '../addon/AddonTexts';
import { SourceStatusLine } from './SourceParts';
import { BODY_SECONDARY, CAPTION, CARD, TITLE } from './Styles';

// One fact about the data: a system symbol, a short title and one line.
@Component
struct FactRow {
  @Prop title: string = '';
  @Prop line: string = '';
  symbol: Resource = $r('sys.symbol.eye');

  build() {
    Row({ space: 12 }) {
      SymbolGlyph(this.symbol)
        .fontSize(24)
        .fontColor([$r('sys.color.icon_emphasize')])
        .width(40)
        .height(40)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .borderRadius(20)
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(this.line).attributeModifier(BODY_SECONDARY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}

// AD-1: the entry to the add-on while HUAWEI Health is not connected. No tier is shown here.
@Component
export struct WelcomeView {
  @Consume('fwNav') nav: NavPathStack;
  @StorageProp(KEY_STATUS) status: string = HealthStatus.NOT_AUTHORIZED;
  @StorageProp(KEY_REFUSED) refused: boolean = false;
  @StorageProp(KEY_WAS_CONNECTED) wasConnected: boolean = false;
  @State showDetails: boolean = false;

  private allDataTypes(): string {
    const names: string[] = [];
    for (let i = 0; i < ALL_HEALTH_SCOPES.length; i++) {
      names.push(scopeLabel(ALL_HEALTH_SCOPES[i]));
    }
    return names.join(' · ');
  }

  // Where the data goes: watch, HUAWEI Health history on the phone, a signed tier.
  @Builder
  flow() {
    Row() {
      SymbolGlyph($r('sys.symbol.watch'))
        .fontSize(32)
        .fontColor([$r('sys.color.icon_secondary')])
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([$r('sys.color.font_tertiary')])
        .margin({ left: 16, right: 16 })
      SymbolGlyph($r('sys.symbol.device_2'))
        .fontSize(32)
        .fontColor([$r('sys.color.icon_secondary')])
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([$r('sys.color.font_tertiary')])
        .margin({ left: 16, right: 16 })
      SymbolGlyph($r('sys.symbol.checkmark_shield'))
        .fontSize(40)
        .fontColor([$r('sys.color.icon_emphasize')])
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 24, bottom: 24 })
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 16 }) {
          SourceStatusLine()
          Text(VALUE_SENTENCE)
            .fontSize($r('sys.float.Title_S'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))

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

          Column({ space: 16 }) {
            FactRow({ title: READS_TITLE, line: READS_SHORT, symbol: $r('sys.symbol.eye') })
            FactRow({ title: NEVER_READS_TITLE, line: NEVER_READS_SHORT, symbol: $r('sys.symbol.eye_slash') })
            FactRow({ title: LEAVES_TITLE, line: LEAVES_SHORT, symbol: $r('sys.symbol.lock') })

            Row({ space: 4 }) {
              Text(DETAILS_LABEL)
                .fontSize($r('sys.float.Body_M'))
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_emphasize'))
              SymbolGlyph(this.showDetails ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'))
                .fontSize(14)
                .fontColor([$r('sys.color.font_emphasize')])
            }
            .constraintSize({ minHeight: 40 })
            .id('fw_details')
            .onClick(() => {
              this.showDetails = !this.showDetails;
            })

            if (this.showDetails) {
              Text(this.allDataTypes()).attributeModifier(BODY_SECONDARY)
              Text(READS_SENTENCE).attributeModifier(CAPTION)
            }
          }
          .attributeModifier(CARD)

          this.flow()
        }
        .alignItems(HorizontalAlign.Start)
        .padding({
          left: $r('sys.float.padding_level8'),
          right: $r('sys.float.padding_level8'),
          bottom: $r('sys.float.padding_level8')
        })
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)

      // The main action stays at the bottom edge.
      Column({ space: 8 }) {
        Button(this.wasConnected ? RECONNECT_LABEL : CONNECT_LABEL)
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .width('100%')
          .id('fw_connect')
          .onClick(() => {
            this.nav.pushPathByName(ROUTE_PLATFORM_CONSENT, null);
          })
        if (this.wasConnected) {
          Text(PRIVACY_SETTINGS_SENTENCE).attributeModifier(CAPTION)
        }
      }
      .width('100%')
      .padding({
        left: $r('sys.float.padding_level8'),
        right: $r('sys.float.padding_level8'),
        top: $r('sys.float.padding_level4'),
        bottom: $r('sys.float.padding_level12')
      })
    }
    .width('100%')
    .height('100%')
  }
}
