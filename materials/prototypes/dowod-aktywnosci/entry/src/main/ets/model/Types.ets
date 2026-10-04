/*
 * Model danych "Dowodu aktywności".
 * Czysty ArkTS bez importów kitów systemowych: kompiluje się w DevEco Studio
 * i jest testowany lokalnie (entry/src/test) oraz w Node (tools/run-logic-tests.sh).
 */

export enum WeekStatus {
  MET = 'MET',
  NOT_MET = 'NOT_MET',
  NO_DATA = 'NO_DATA',
  REVIEW = 'REVIEW'
}

export enum Tier {
  ZLOTY = 'ZLOTY',
  SREBRNY = 'SREBRNY',
  BRAK = 'BRAK'
}

/** Poziom pewności zależy od zakresu zgód: bez tętna nie da się wykluczyć części oszustw. */
export enum Assurance {
  PODSTAWOWY = 'PODSTAWOWY',
  ROZSZERZONY = 'ROZSZERZONY'
}

export enum ReportStatus {
  OK = 'OK',
  REVIEW = 'REVIEW'
}

export enum Severity {
  HIGH = 'HIGH',
  LOW = 'LOW'
}

export enum FlagCode {
  NOT_WORN = 'NOT_WORN',
  IMPOSSIBLE_VALUE = 'IMPOSSIBLE_VALUE',
  STEPS_WHILE_NOT_WORN = 'STEPS_WHILE_NOT_WORN',
  STEPS_WITHOUT_HR = 'STEPS_WITHOUT_HR'
}

export enum DayState {
  OK = 'OK',
  SKIPPED = 'SKIPPED',
  FLAGGED = 'FLAGGED'
}

/** Dzienny agregat liczony na urządzeniu. Surowe odczyty nigdy nie opuszczają telefonu. */
export class DaySample {
  date: string;
  steps: number;
  activeMinutes: number;
  /** Średnie tętno w minutach aktywnych; 0 = brak pomiaru. */
  activeHrAvg: number;
  /** Tętno spoczynkowe; 0 = brak pomiaru. */
  restingHr: number;
  /** Ile minut zegarek był na nadgarstku (czujnik WEAR_DETECTION). */
  wornMinutes: number;
  /** 0 = brak pomiaru snu. */
  sleepMinutes: number;

  constructor(date: string, steps: number, activeMinutes: number, activeHrAvg: number,
    restingHr: number, wornMinutes: number, sleepMinutes: number) {
    this.date = date;
    this.steps = steps;
    this.activeMinutes = activeMinutes;
    this.activeHrAvg = activeHrAvg;
    this.restingHr = restingHr;
    this.wornMinutes = wornMinutes;
    this.sleepMinutes = sleepMinutes;
  }
}

/**
 * Zgody użytkownika. Kroki są wymagane, reszta opcjonalna.
 * Cyklu menstruacyjnego i tras GPS celowo nie ma w modelu: nie są potrzebne,
 * a cykl pozwalałby różnicować składkę ze względu na płeć.
 */
export class Consents {
  steps: boolean = true;
  heartRate: boolean;
  sleep: boolean;

  constructor(heartRate: boolean, sleep: boolean) {
    this.heartRate = heartRate;
    this.sleep = sleep;
  }

  codes(): string[] {
    const out: string[] = ['steps'];
    if (this.heartRate) {
      out.push('hr');
    }
    if (this.sleep) {
      out.push('sleep');
    }
    return out;
  }
}

export class AnomalyFlag {
  code: FlagCode;
  severity: Severity;
  date: string;
  detail: string;

  constructor(code: FlagCode, severity: Severity, date: string, detail: string) {
    this.code = code;
    this.severity = severity;
    this.date = date;
    this.detail = detail;
  }
}

export class DayView {
  date: string;
  steps: number;
  state: DayState;

  constructor(date: string, steps: number, state: DayState) {
    this.date = date;
    this.steps = steps;
    this.state = state;
  }
}

export class WeekSummary {
  index: number;
  from: string;
  to: string;
  days: DayView[] = [];
  validDays: number = 0;
  avgSteps: number = 0;
  /** Minuty aktywności przeskalowane na pełny tydzień (brakujące dni nie karzą). */
  weeklyActiveMinutes: number = 0;
  hasBaseline: boolean = false;
  baselineDeltaPct: number = 0;
  avgSleepMinutes: number = 0;
  sleepGoalMet: boolean = false;
  status: WeekStatus = WeekStatus.NO_DATA;
  reason: string = '';
  flags: AnomalyFlag[] = [];

  constructor(index: number, from: string, to: string) {
    this.index = index;
    this.from = from;
    this.to = to;
  }
}

export class Evaluation {
  periodFrom: string = '';
  periodTo: string = '';
  baselineAvgSteps: number = 0;
  baselineDays: number = 0;
  weeks: WeekSummary[] = [];
  flags: AnomalyFlag[] = [];
  weeksMet: number = 0;
  assurance: Assurance = Assurance.PODSTAWOWY;
  tierBeforeCap: Tier = Tier.BRAK;
  tier: Tier = Tier.BRAK;
  status: ReportStatus = ReportStatus.OK;
  /** -1 = brak zgody na sen (pole nie trafia do raportu). */
  sleepWeeks: number = -1;
  consents: string[] = [];
  rulesRun: string[] = [];
  /** Ile dni pomiarów zostaje na telefonie. */
  daysOnDevice: number = 0;
  /** Szacunkowa liczba odczytów tętna, które zostają na telefonie. */
  hrReadingsOnDevice: number = 0;
}

export class Persona {
  id: string;
  name: string;
  tagline: string;
  expectation: string;
  days: DaySample[];

  constructor(id: string, name: string, tagline: string, expectation: string, days: DaySample[]) {
    this.id = id;
    this.name = name;
    this.tagline = tagline;
    this.expectation = expectation;
    this.days = days;
  }
}

export class LabeledValue {
  label: string;
  value: string;

  constructor(label: string, value: string) {
    this.label = label;
    this.value = value;
  }
}
