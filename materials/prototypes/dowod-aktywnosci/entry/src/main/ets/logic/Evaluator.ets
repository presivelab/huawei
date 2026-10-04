import {
  AnomalyFlag, Assurance, Consents, DaySample, DayState, DayView, Evaluation, ReportStatus, Severity, Tier,
  WeekStatus, WeekSummary
} from '../model/Types';
import { AnomalyDetector } from './AnomalyDetector';

/*
 * Liczy wynik z 28 ostatnich dni na urządzeniu.
 * Zasady (pod pitch "tylko zniżka, nigdy podwyżka"):
 *  - tydzień zaliczony: >=150 min aktywności (WHO) ALBO >=10% więcej kroków niż własna baza z 28 dni wcześniej;
 *  - dni z niskim noszeniem są pomijane, a minuty skalowane na pełny tydzień (bez kary);
 *  - tydzień z podejrzanym dniem idzie do człowieka, nie jest automatycznie odrzucany;
 *  - ZŁOTY = 3 z 4 tygodni (tolerancja na chorobę/urlop), SREBRNY = 2 z 4;
 *  - bez zgody na tętno poziom pewności jest PODSTAWOWY i próg ograniczony do SREBRNEGO.
 */
export class Evaluator {
  static readonly EVAL_DAYS: number = 28;
  static readonly BASELINE_DAYS: number = 28;
  static readonly BASELINE_MIN_VALID_DAYS: number = 7;
  static readonly WEEKLY_ACTIVE_GOAL: number = 150;
  static readonly IMPROVEMENT_RATIO: number = 0.10;
  static readonly MIN_VALID_DAYS_PER_WEEK: number = 4;
  static readonly SLEEP_GOAL_MINUTES: number = 420;

  static evaluate(daysIn: DaySample[], consents: Consents): Evaluation {
    const days: DaySample[] = daysIn.slice();
    days.sort((a: DaySample, b: DaySample) => a.date < b.date ? -1 : (a.date > b.date ? 1 : 0));

    const ev = new Evaluation();
    ev.consents = consents.codes();
    ev.rulesRun = AnomalyDetector.rulesFor(consents);
    ev.assurance = consents.heartRate ? Assurance.ROZSZERZONY : Assurance.PODSTAWOWY;
    ev.daysOnDevice = days.length;
    let wornTotal = 0;
    for (const d of days) {
      wornTotal += Math.max(0, d.wornMinutes);
    }
    ev.hrReadingsOnDevice = consents.heartRate ? Math.round(wornTotal / 5) : 0;

    const evalStart = Math.max(0, days.length - Evaluator.EVAL_DAYS);
    const baselineDays = days.slice(Math.max(0, evalStart - Evaluator.BASELINE_DAYS), evalStart);
    const evalDays = days.slice(evalStart);

    let baseSum = 0;
    let baseCount = 0;
    for (const d of baselineDays) {
      if (AnomalyDetector.detect(d, consents).length === 0) {
        baseSum += d.steps;
        baseCount++;
      }
    }
    ev.baselineDays = baseCount;
    ev.baselineAvgSteps = baseCount >= Evaluator.BASELINE_MIN_VALID_DAYS ? Math.round(baseSum / baseCount) : 0;

    if (evalDays.length > 0) {
      ev.periodFrom = evalDays[0].date;
      ev.periodTo = evalDays[evalDays.length - 1].date;
    }

    for (let w = 0; w * 7 < evalDays.length; w++) {
      const chunk = evalDays.slice(w * 7, w * 7 + 7);
      ev.weeks.push(Evaluator.summarizeWeek(w + 1, chunk, consents, ev.baselineAvgSteps));
    }

    let anyHigh = false;
    let sleepWeeks = 0;
    for (const week of ev.weeks) {
      if (week.status === WeekStatus.MET) {
        ev.weeksMet++;
      }
      if (week.status !== WeekStatus.REVIEW && week.sleepGoalMet) {
        sleepWeeks++;
      }
      for (const f of week.flags) {
        ev.flags.push(f);
        if (f.severity === Severity.HIGH) {
          anyHigh = true;
        }
      }
    }
    ev.sleepWeeks = consents.sleep ? sleepWeeks : -1;
    ev.tierBeforeCap = Evaluator.tierFor(ev.weeksMet);
    ev.tier = (ev.assurance === Assurance.PODSTAWOWY && ev.tierBeforeCap === Tier.ZLOTY) ? Tier.SREBRNY :
      ev.tierBeforeCap;
    ev.status = anyHigh ? ReportStatus.REVIEW : ReportStatus.OK;
    return ev;
  }

  static tierFor(weeksMet: number): Tier {
    if (weeksMet >= 3) {
      return Tier.ZLOTY;
    }
    if (weeksMet === 2) {
      return Tier.SREBRNY;
    }
    return Tier.BRAK;
  }

  static summarizeWeek(index: number, chunk: DaySample[], consents: Consents, baseline: number): WeekSummary {
    const week = new WeekSummary(index, chunk.length > 0 ? chunk[0].date : '',
      chunk.length > 0 ? chunk[chunk.length - 1].date : '');
    let stepsSum = 0;
    let activeSum = 0;
    let sleepSum = 0;
    let sleepCount = 0;
    let hasHigh = false;

    for (const d of chunk) {
      const flags: AnomalyFlag[] = AnomalyDetector.detect(d, consents);
      let state = DayState.OK;
      for (const f of flags) {
        week.flags.push(f);
        if (f.severity === Severity.HIGH) {
          state = DayState.FLAGGED;
          hasHigh = true;
        } else if (state === DayState.OK) {
          state = DayState.SKIPPED;
        }
      }
      week.days.push(new DayView(d.date, d.steps, state));
      if (state === DayState.OK) {
        week.validDays++;
        stepsSum += d.steps;
        activeSum += d.activeMinutes;
        if (consents.sleep && d.sleepMinutes > 0) {
          sleepSum += d.sleepMinutes;
          sleepCount++;
        }
      }
    }

    let ratio = 0;
    if (week.validDays > 0) {
      week.avgSteps = Math.round(stepsSum / week.validDays);
      week.weeklyActiveMinutes = Math.round(activeSum * 7 / week.validDays);
      if (baseline > 0) {
        week.hasBaseline = true;
        ratio = (stepsSum / week.validDays - baseline) / baseline;
        week.baselineDeltaPct = Math.round(ratio * 100);
      }
    }
    if (sleepCount > 0) {
      week.avgSleepMinutes = Math.round(sleepSum / sleepCount);
      week.sleepGoalMet = week.avgSleepMinutes >= Evaluator.SLEEP_GOAL_MINUTES;
    }

    const deltaText = week.hasBaseline ?
      `${week.baselineDeltaPct >= 0 ? '+' : ''}${week.baselineDeltaPct}% kroków vs twoja baza` : 'brak bazy';
    if (hasHigh) {
      week.status = WeekStatus.REVIEW;
      week.reason = 'Podejrzany dzień — tydzień czeka na decyzję człowieka';
    } else if (week.validDays < Evaluator.MIN_VALID_DAYS_PER_WEEK) {
      week.status = WeekStatus.NO_DATA;
      week.reason = `Za mało danych (${week.validDays}/7 dni) — tydzień się nie liczy, bez kary`;
    } else if (week.weeklyActiveMinutes >= Evaluator.WEEKLY_ACTIVE_GOAL) {
      week.status = WeekStatus.MET;
      week.reason = `${week.weeklyActiveMinutes} min aktywności (cel 150)`;
    } else if (week.hasBaseline && ratio >= Evaluator.IMPROVEMENT_RATIO) {
      week.status = WeekStatus.MET;
      week.reason = `${deltaText} (cel +10%)`;
    } else {
      week.status = WeekStatus.NOT_MET;
      week.reason = `${week.weeklyActiveMinutes} min aktywności, ${deltaText}`;
    }
    return week;
  }
}
