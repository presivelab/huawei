import { HesProfile, PARTNER_HES_PROFILE } from 'common';
import { selectProfile } from '../report/ServiceLocator';
import {
  PROFILE_OPTIONS,
  PROFILE_SWITCH_SPOKEN,
  profileExplainLine,
  profileOptionLabel
} from '../report/ReportTexts';
import { CAPTION } from './Styles';

// The two-segment switch of the weight profile, on the Report tab and on the Why page (one shared state:
// KEY_PROFILE, which the screen passes in as `profile`). It explains the score in another profile; sharing and
// benefits stay in the partner's profile, and the line under the switch says so whenever the profile on
// screen is not the partner's.
// Ids: fw_profile_HEALTH_WELLNESS, fw_profile_LONGEVITY_WELLNESS, and fw_profile_note for the line.
@Builder
function profileSegment(option: HesProfile, profile: string) {
  Button({ type: ButtonType.Normal, stateEffect: true }) {
    Text(profileOptionLabel(option))
      .fontSize($r('sys.float.Body_M'))
      .fontWeight(profile === option ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(profile === option ? $r('sys.color.font_on_primary') : $r('sys.color.font_secondary'))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }
  .layoutWeight(1)
  .height(44)
  .borderRadius(20)
  .backgroundColor(profile === option ? $r('sys.color.comp_background_emphasize') : Color.Transparent)
  .id(`fw_profile_${option}`)
  .accessibilityText(`${profileOptionLabel(option)}, ${profile === option ? 'selected' : 'not selected'}`)
  .onClick(() => {
    selectProfile(option);
  })
}

@Builder
export function profileSwitch(profile: string) {
  Column({ space: 6 }) {
    Row({ space: 4 }) {
      ForEach(PROFILE_OPTIONS, (option: HesProfile) => {
        profileSegment(option, profile)
      }, (option: HesProfile) => `${option}|${profile === option}`)
    }
    .width('100%')
    .padding(2)
    .borderRadius(22)
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .accessibilityText(PROFILE_SWITCH_SPOKEN)

    if (profile !== PARTNER_HES_PROFILE) {
      Text(profileExplainLine())
        .attributeModifier(CAPTION)
        .padding({ left: 4, right: 4 })
        .id('fw_profile_note')
    }
  }
  .width('100%')
  .alignItems(HorizontalAlign.Start)
}
