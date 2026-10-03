// Shared look of the add-on screens. System resources only, so light and dark mode follow the system.

export class CardStyle implements AttributeModifier<ColumnAttribute> {
  applyNormalAttribute(instance: ColumnAttribute): void {
    instance
      .width('100%')
      .padding($r('sys.float.padding_level8'))
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius($r('sys.float.corner_radius_level8'))
      .alignItems(HorizontalAlign.Start);
  }
}

export class TextStyle implements AttributeModifier<TextAttribute> {
  private size: Resource;
  private color: Resource;
  private weight: FontWeight;

  constructor(size: Resource, color: Resource, weight: FontWeight) {
    this.size = size;
    this.color = color;
    this.weight = weight;
  }

  applyNormalAttribute(instance: TextAttribute): void {
    instance.fontSize(this.size).fontColor(this.color).fontWeight(this.weight);
  }
}

export const CARD: CardStyle = new CardStyle();
export const TITLE: TextStyle =
  new TextStyle($r('sys.float.Subtitle_L'), $r('sys.color.font_primary'), FontWeight.Bold);
export const BODY: TextStyle =
  new TextStyle($r('sys.float.Body_L'), $r('sys.color.font_primary'), FontWeight.Regular);
export const BODY_SECONDARY: TextStyle =
  new TextStyle($r('sys.float.Body_M'), $r('sys.color.font_secondary'), FontWeight.Regular);
export const CAPTION: TextStyle =
  new TextStyle($r('sys.float.Body_S'), $r('sys.color.font_secondary'), FontWeight.Regular);
export const LABEL: TextStyle =
  new TextStyle($r('sys.float.Body_S'), $r('sys.color.font_secondary'), FontWeight.Medium);
