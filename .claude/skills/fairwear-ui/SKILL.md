---
name: fairwear-ui
description: Visual and information rules for every FairWear screen. Use before any change under entry/src/main/ets/view, entry/src/main/ets/ui, entry/src/main/ets/widget or watch/src/main/ets/pages and watch/src/main/ets/ui, and whenever a screen, card, watch face, colour, icon or UI text is added or changed.
---

# FairWear UI

One look for the phone, the watch and the home-screen card, whichever session or worktree does the work.
FairWear is an add-on for HUAWEI Health users. It must look native to HarmonyOS and must not look like
HUAWEI Health.

## When to use

Any change in:

- `entry/src/main/ets/view/`, `entry/src/main/ets/ui/`, `entry/src/main/ets/pages/`
- `entry/src/main/ets/widget/` (home-screen card)
- `watch/src/main/ets/pages/`, `watch/src/main/ets/ui/`
- resource colours and strings of `entry` and `watch`

Read this file first, then use the HarmonyOS skills from the challenge repository for the code itself:
`hmos-arkui-develop-skill` (rules and quick API cards), `hmos-arkui-scenario-development`,
`hmos-arkui-mvvm-pattern`. Check every component, symbol and resource name in the SDK or with
`hmos-arkts-knowledge-retriever`; do not write an API from memory.

Do not use skills written for iOS or the web here (`apple-design`, `write-swift`, `animate-expo`,
`pick-ui-library`, `ask-sonner`, `emil-design-eng`). They pull the UI the wrong way.

## Tokens

Backgrounds and text come from system resources only, so light and dark mode follow the system:
`sys.color.background_secondary`, `sys.color.comp_background_primary`, `sys.color.comp_background_tertiary`,
`sys.color.font_primary`, `sys.color.font_secondary`, `sys.color.font_tertiary`, `sys.float.*`.

FairWear's own colours are `app.color` resources, defined in both `base` and `dark`
(`resources/base/element/fw_tokens.json`, `resources/dark/element/fw_tokens.json`), the same names in
`entry` and `watch`:

| Meaning                        | Resource                                                                                                                        |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------- |
| Steps                          | `fw_metric_steps`                                                                                                               |
| Heart rate, resting heart rate | `fw_metric_heart`                                                                                                               |
| Sleep                          | `fw_metric_sleep`                                                                                                               |
| Activity minutes               | `fw_metric_activity`                                                                                                            |
| VO₂max                         | `fw_metric_vo2max`                                                                                                              |
| HRV                            | `fw_metric_hrv`                                                                                                                 |
| Workouts                       | `fw_metric_workout`                                                                                                             |
| Watch worn                     | `fw_wear_worn`                                                                                                                  |
| Watch charging                 | `fw_wear_charging`                                                                                                              |
| Watch off the wrist            | `fw_wear_off`                                                                                                                   |
| Not observed                   | `fw_wear_unobserved`                                                                                                            |
| Tier A, B, C                   | `fw_tier_a`, `fw_tier_b`, `fw_tier_c`                                                                                           |
| Tier tint and text (phone)     | `fw_tier_a_tint`, `fw_tier_a_text` (and `_b_`, `_c_`): the tint behind a tier letter and the text colour on white or on the tint |
| Flag (phone)                   | `fw_flag_tint`, `fw_flag_text`                                                                                                    |
| Day of the month               | compliant `fw_wear_worn`, short `fw_wear_charging`, suspicious break `fw_wear_off`, sick or no data `fw_wear_unobserved`         |
| Source status                  | `sys.color.confirm` connected, `sys.color.brand` demo, `sys.color.warning` unavailable, `sys.color.font_tertiary` not connected |

No hex colour in an `.ets` file. One accent colour per card. Each metric has one `SymbolGlyph`
(`sys.symbol.*`) in its colour, the same one on every screen.

## Components

Build screens from the UI kit, not from hand-made rows and columns:

- phone: `entry/src/main/ets/ui/kit/`
- watch: `watch/src/main/ets/ui/kit/`

| Component       | Use                                                                                                     |
| --------------- | ------------------------------------------------------------------------------------------------------- |
| `ValueWithUnit` | every number: large value, smaller unit on the same baseline                                            |
| `MetricTile`    | one metric: symbol, name, value with unit, seven small bars, or the state "Off · missing evidence"      |
| `RingStat`      | a ring with a value in the middle (system `Gauge` / `DataPanel` / `Progress`), filled with an animation |
| `StatusPill`    | a dot and a readable status                                                                             |
| `SectionCard`   | a rounded card with a title, no border                                                                  |
| `EmptyState`    | a symbol and one sentence                                                                               |
| `DayStrip`      | seven days as small rings: worn, charging, off, not observed                                            |
| `WearBar`       | one day as a bar of worn, charging, off, not observed; `WearLegend` names the four colours              |
| `TierBadge`     | the tier letter on a square tinted in the tier colour; in the app only, never on the home-screen card   |
| `InfoChip`      | a small label without a dot ("Coverage 100%"); with a tint it states a condition ("Preview · not scored") |
| `MonthBar`      | a month as one bar, a segment per day in the colour of its state; `DayStateLegend` names the colours     |
| `CountBar`      | evidence against what is needed: a name, "9 of 14 nights" and a bar (system `Progress`)                  |
| `TextLink`      | a link to another screen: text and a forward chevron in the accent colour, at least 44 vp high           |
| `SlotTimeline`  | one day in time order, slot by slot (`WearBar` shows the totals, this shows when)                       |
| `KitTokens`     | the colour and symbol constants (`COLOR_*`, `SYMBOL_*`, `wearColor`, `tierColor`, `dayStateColor`, `componentColor`, `componentSymbol`); import them, do not repeat `$r` |

Spacing grid: 4, 8, 12, 16, 24. Cards are rounded and have no border. Navigation is the system
`Navigation`. Motion: rings fill in 300–600 ms; nothing else moves on its own.
No chart or UI library from ohpm.

## Rules

1. A number is always shown with its unit.
2. Zero never stands in for missing data. Missing data is an empty state, or "—" with an explanation.
3. The user never sees an enum name, a hash, a sequence number or a key id, except on the screen
   "Verification details" and, by the project owner's decision, inside the collapsed "Show the code"
   panels of the screen "How Watch Link works": those panels show source code word for word, and source
   code has field names and constants. Outside those panels that screen follows the rule like any other.
4. The watch shows one main piece of information per screen.
5. The home-screen card never shows the tier or the score.
6. Demo and simulated data are labelled where they are shown.
7. No HUAWEI Health look: no logo, icons, colours or layouts copied from it. The name "HUAWEI Health"
   appears only as text naming the data source.
8. Rules and the score are never called AI. No wording from `tools/check-wording.sh`.

## Gate

A changed screen is not done until:

- it has a "before" and an "after" screenshot from the emulator, in light and in dark mode, in
  `docs/screenshots/design/`;
- `tools/lint.sh` reports 0 errors and `tools/check-wording.sh` reports 0 hits;
- on the watch (466×466, round) the content sits inside the safe circle.
