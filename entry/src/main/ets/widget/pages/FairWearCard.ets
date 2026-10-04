/*
 * FairWear home-screen card, 2x2.
 * Values arrive from EntryFormAbility through LocalStorage; until they do, the card shows the texts of
 * an unconnected source from the card's string resources. A tap opens the app on the dashboard
 * through the single entry parameter `fwTarget`.
 */

const storage: LocalStorage = new LocalStorage();

@Entry(storage)
@Component
struct FairWearCard {
  @LocalStorageProp('source') source: string = '';
  @LocalStorageProp('coverage') coverage: string = '';
  @LocalStorageProp('result') result: string = '';

  build() {
    Column() {
      Text($r('app.string.card_title'))
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)

      Blank()

      Text(this.coverage.length > 0 ? this.coverage : $r('app.string.card_coverage_none'))
        .fontSize($r('sys.float.Title_L'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
      Text($r('app.string.card_coverage_label'))
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)

      Blank()

      Text(this.result.length > 0 ? this.result : $r('app.string.card_result_none'))
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
      Text(this.source.length > 0 ? this.source : $r('app.string.card_source_none'))
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: {
          fwTarget: 'dashboard'
        }
      });
    })
  }
}
