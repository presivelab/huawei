import { tierTextColor, tierTint } from './KitTokens';

export interface TierBadgeParams {
  tier: string;       // ReportTier A, B or C
  size?: number;      // side of the square, 44 by default
}

function side(p: TierBadgeParams): number {
  return p.size ?? 44;
}

// The tier letter on a rounded square tinted in the tier colour. In the app only: the home-screen card
// never shows it.
@Builder
export function TierBadge(p: TierBadgeParams) {
  Text(p.tier)
    .fontSize(side(p) * 0.6)
    .fontWeight(FontWeight.Bold)
    .fontColor(tierTextColor(p.tier))
    .textAlign(TextAlign.Center)
    .width(side(p))
    .height(side(p))
    .backgroundColor(tierTint(p.tier))
    .borderRadius(side(p) * 0.32)
    .accessibilityText(`Tier ${p.tier}`)
}
