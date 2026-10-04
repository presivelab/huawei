import { AnomalyFlag, Consents, DaySample, FlagCode, Severity } from '../model/Types';

/*
 * Reguły antyoszustwa na agregatach dziennych. Celowo reguły, a nie model ML:
 * każdą decyzję da się wytłumaczyć klientowi i przetestować (AI Act, art. 22 RODO).
 */
export class AnomalyDetector {
  static readonly MIN_WORN_MINUTES: number = 600;
  static readonly MAX_STEPS_PER_WORN_MINUTE: number = 150;
  static readonly HR_CHECK_MIN_STEPS: number = 15000;
  static readonly HR_MIN_ELEVATION: number = 15;
  static readonly MAX_DAILY_STEPS: number = 60000;

  /** Nazwy reguł, które da się uruchomić przy danym zakresie zgód. */
  static rulesFor(consents: Consents): string[] {
    const rules: string[] = [
      'Wartości w zakresie fizjologicznym',
      'Zegarek noszony min. 10 h (inaczej dzień pomijany, bez kary)',
      'Kroki przy zdjętym zegarku'
    ];
    if (consents.heartRate) {
      rules.push('Kroki bez wzrostu tętna');
    }
    return rules;
  }

  static detect(d: DaySample, consents: Consents): AnomalyFlag[] {
    const out: AnomalyFlag[] = [];

    const badActivity = d.steps < 0 || d.steps > AnomalyDetector.MAX_DAILY_STEPS ||
      d.activeMinutes < 0 || d.activeMinutes > 1440 || d.wornMinutes < 0 || d.wornMinutes > 1440;
    if (badActivity) {
      out.push(new AnomalyFlag(FlagCode.IMPOSSIBLE_VALUE, Severity.HIGH, d.date,
        `Wartości poza zakresem: ${d.steps} kroków, ${d.activeMinutes} min aktywności`));
      return out;
    }
    if (consents.heartRate) {
      const badHr = (d.activeHrAvg > 0 && (d.activeHrAvg < 30 || d.activeHrAvg > 220)) ||
        (d.restingHr > 0 && (d.restingHr < 30 || d.restingHr > 120));
      if (badHr) {
        out.push(new AnomalyFlag(FlagCode.IMPOSSIBLE_VALUE, Severity.HIGH, d.date,
          `Tętno poza zakresem fizjologicznym: aktywne ${d.activeHrAvg}, spoczynkowe ${d.restingHr}`));
        return out;
      }
    }

    const stepsWhileOff = d.wornMinutes > 0 ?
      d.steps / d.wornMinutes > AnomalyDetector.MAX_STEPS_PER_WORN_MINUTE : d.steps > 500;
    if (stepsWhileOff) {
      out.push(new AnomalyFlag(FlagCode.STEPS_WHILE_NOT_WORN, Severity.HIGH, d.date,
        `${d.steps} kroków, a zegarek był na nadgarstku tylko ${d.wornMinutes} min`));
    } else if (consents.heartRate && d.steps >= AnomalyDetector.HR_CHECK_MIN_STEPS &&
      d.activeHrAvg > 0 && d.restingHr > 0 && d.activeHrAvg - d.restingHr < AnomalyDetector.HR_MIN_ELEVATION) {
      out.push(new AnomalyFlag(FlagCode.STEPS_WITHOUT_HR, Severity.HIGH, d.date,
        `${d.steps} kroków, a tętno w ruchu ${d.activeHrAvg} przy spoczynkowym ${d.restingHr} — brak wysiłku`));
    }

    if (out.length === 0 && d.wornMinutes < AnomalyDetector.MIN_WORN_MINUTES) {
      out.push(new AnomalyFlag(FlagCode.NOT_WORN, Severity.LOW, d.date,
        `Zegarek noszony ${Math.round(d.wornMinutes / 6) / 10} h — dzień pominięty, bez kary`));
    }
    return out;
  }
}
