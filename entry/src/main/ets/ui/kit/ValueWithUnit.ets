// Every number on screen: the value, then its unit smaller and quieter on the same baseline.
// A second pair is for durations, "19 h 20 min".
export const VALUE_SMALL: number = 0;
export const VALUE_MEDIUM: number = 1;
export const VALUE_LARGE: number = 2;

export interface ValueUnit {
  value: string;
  unit: string;
  extraValue?: string;
  extraUnit?: string;
  level?: number;
}

function valueSize(level: number | undefined): Resource {
  if (level === VALUE_LARGE) {
    return $r('sys.float.Title_M');
  }
  return level === VALUE_MEDIUM ? $r('sys.float.Subtitle_L') : $r('sys.float.Body_M');
}

function unitSize(level: number | undefined): Resource {
  if (level === VALUE_LARGE) {
    return $r('sys.float.Body_L');
  }
  return level === VALUE_MEDIUM ? $r('sys.float.Body_M') : $r('sys.float.Body_S');
}

function spaced(text: string | undefined): string {
  return text === undefined || text.length === 0 ? '' : ` ${text}`;
}

@Builder
export function ValueWithUnit(p: ValueUnit) {
  Text() {
    Span(p.value)
      .fontSize(valueSize(p.level))
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_primary'))
    Span(spaced(p.unit))
      .fontSize(unitSize(p.level))
      .fontColor($r('sys.color.font_secondary'))
    Span(spaced(p.extraValue))
      .fontSize(valueSize(p.level))
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_primary'))
    Span(spaced(p.extraUnit))
      .fontSize(unitSize(p.level))
      .fontColor($r('sys.color.font_secondary'))
  }
  .maxLines(1)
}
