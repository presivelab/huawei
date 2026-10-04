import { DayState, hasScore, PersonaReport } from './ReportModels';

/*
 * What a screen reader says for the parts of the report that are drawn rather than written:
 * the score ring, a metric tile, the month bar. Plain sentences, units spelled out.
 */

/** "9,412" -> "9412": digit grouping is for the eye only. */
function ungrouped(raw: string): string {
  return raw.split(',').join('');
}

function spokenUnit(unit: string): string {
  if (unit === '/day') {
    return 'per day';
  }
  if (unit === 'min/week') {
    return 'minutes per week';
  }
  if (unit === 'bpm') {
    return 'beats per minute';
  }
  if (unit === 'min') {
    return 'minutes';
  }
  if (unit === 'ms') {
    return 'milliseconds';
  }
  if (unit === 'ml/kg/min') {
    return 'millilitres per kilogram per minute';
  }
  if (unit === 'bpm in 60 s') {
    return 'beats per minute in 60 seconds';
  }
  return unit;
}

function spokenRaw(raw: string): string {
  let text = ungrouped(raw);
  if (text.indexOf('±') === 0) {
    text = 'plus or minus ' + text.substring(1);
  }
  return text.split(' h ').join(' hours ');
}

/** "Score 92, tier A, coverage 100 percent"; without a score: "No score yet, coverage 47.5 percent". */
export function scoreSpoken(report: PersonaReport): string {
  if (!hasScore(report)) {
    return `No score yet, coverage ${report.coveragePct} percent`;
  }
  return `Score ${report.hes}, tier ${report.tier}, coverage ${report.coveragePct} percent`;
}

/** "Steps, 9412 per day". A component without a value says so and never reads as zero. */
export function metricSpoken(name: string, raw: string, unit: string, available: boolean): string {
  if (!available || raw.length === 0) {
    return `${name}, not measured`;
  }
  return `${name}, ${spokenRaw(raw)} ${spokenUnit(unit)}`;
}

export function dayStateLabel(state: string): string {
  if (state === DayState.COMPLIANT) {
    return 'Compliant';
  }
  if (state === DayState.SHORT) {
    return 'Short';
  }
  if (state === DayState.SUSPICIOUS) {
    return 'Suspicious break';
  }
  if (state === DayState.SICK) {
    return 'Sick day';
  }
  return 'No data';
}

/** "28 of 30 days compliant, 2 short" for the month bar. */
export function wearSpoken(report: PersonaReport): string {
  const order: string[] = [DayState.SHORT, DayState.SUSPICIOUS, DayState.SICK, DayState.UNKNOWN];
  const words: string[] = ['short', 'with a suspicious break', 'marked as sick days', 'without data'];
  let text = `${report.wear.compliantDays} of ${report.wear.totalDays} days compliant`;
  for (let s = 0; s < order.length; s++) {
    let n = 0;
    for (let d = 0; d < report.wear.days.length; d++) {
      if (report.wear.days[d].state === order[s]) {
        n++;
      }
    }
    if (n > 0) {
      text += `, ${n} ${words[s]}`;
    }
  }
  return text;
}
