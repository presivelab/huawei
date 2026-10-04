import { HesProfile, hesProfileLabel } from 'common';
import { CAPTION } from './Styles';

const OPTION_HEIGHT: number = 44;
const TRACK_PADDING: number = 4;

export interface ProfileSwitchParams {
  selected: HesProfile;
  note: string;           // the discount line for the profile on screen; empty: no line
  onPick: (profile: HesProfile) => void;
}

interface ProfileOptionParams {
  profile: HesProfile;
  selected: HesProfile;
  optionId: string;       // element id, for UI tests
  onPick: (profile: HesProfile) => void;
}

@Builder
function ProfileOption(p: ProfileOptionParams) {
  Text(hesProfileLabel(p.profile))
    .fontSize($r('sys.float.Body_M'))
    .fontWeight(p.selected === p.profile ? FontWeight.Medium : FontWeight.Regular)
    .fontColor(p.selected === p.profile ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
    .textAlign(TextAlign.Center)
    .maxLines(1)
    .layoutWeight(1)
    .height(OPTION_HEIGHT)
    .borderRadius(OPTION_HEIGHT / 2)
    .backgroundColor(p.selected === p.profile ? $r('sys.color.comp_background_primary') : Color.Transparent)
    .id(p.optionId)
    .accessibilityText(hesProfileLabel(p.profile) + (p.selected === p.profile ? ', selected' : ', not selected'))
    .onClick(() => {
      if (p.selected !== p.profile) {
        p.onPick(p.profile);
      }
    })
}

// The score profile of the Report tab: "Health insurance" | "Life insurance". The same completed days
// are scored with the weights of the chosen product; `note` is the discount line for it. The choice
// never reaches Share: the code for the partner is always made for health insurance.
// System colours only, so light and dark mode follow the system.
@Builder
export function ProfileSwitch(p: ProfileSwitchParams) {
  Column({ space: 8 }) {
    Row() {
      ProfileOption({
        profile: HesProfile.HEALTH_WELLNESS,
        selected: p.selected,
        optionId: 'fw_profile_health',
        onPick: p.onPick
      })
      ProfileOption({
        profile: HesProfile.LONGEVITY_WELLNESS,
        selected: p.selected,
        optionId: 'fw_profile_life',
        onPick: p.onPick
      })
    }
    .width('100%')
    .padding(TRACK_PADDING)
    .borderRadius(OPTION_HEIGHT / 2 + TRACK_PADDING)
    .backgroundColor($r('sys.color.comp_background_tertiary'))

    if (p.note.length > 0) {
      Text(p.note)
        .attributeModifier(CAPTION)
        .padding({ left: 4, right: 4 })
        .id('fw_profile_note')
    }
  }
  .width('100%')
  .alignItems(HorizontalAlign.Start)
}
