/*
 * FairWear home-screen card, 2x2.
 * Values arrive from EntryFormAbility through LocalStorage. A tap opens the app on the dashboard
 * through the single entry parameter `fwTarget`.
 */

const storage: LocalStorage = new LocalStorage();

@Entry(storage)
@Component
struct FairWearCard {
  @LocalStorageProp('source') source: string = 'HUAWEI Health · not connected';
  @LocalStorageProp('coverage') coverage: string = '—';
  @LocalStorageProp('result') result: string = '—';

  build() {
    Column() {
      Text('FairWear')
        .fontSize($r('sys.float.Body_M'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)

      Blank()

      Text(this.coverage)
        .fontSize($r('sys.float.Title_L'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
      Text('Coverage')
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)

      Blank()

      Text(this.result)
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
      Text(this.source)
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
