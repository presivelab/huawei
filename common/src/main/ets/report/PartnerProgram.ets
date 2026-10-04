// The demo partner's programme settings that concern the score.
//
// The weight profile is the partner's choice, not the user's: the tier that is shared, eligibility and the
// benefit are always calculated in this profile. The profile switch on the Report and Why screens only
// explains how the score would read in the other profile.
import { hesPartnerProfileText } from '../hes/HesFormat';
import { HesProfile } from '../hes/HesTypes';

export const PARTNER_HES_PROFILE: HesProfile = HesProfile.HEALTH_WELLNESS;

/** "Profile: Health & wellness (set by partner)", as the Share screen writes it. */
export const PARTNER_PROFILE_LINE: string = `Profile: ${hesPartnerProfileText(PARTNER_HES_PROFILE)}`;
