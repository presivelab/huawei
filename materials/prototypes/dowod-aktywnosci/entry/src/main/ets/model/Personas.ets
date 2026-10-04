import { DaySample, Persona } from './Types';
import { addDays } from './DateUtil';

/*
 * Dane syntetyczne w tym samym kształcie co agregaty z czujników.
 * 56 dni na personę: dni 0-27 to baza (własna norma użytkownika), dni 28-55 to oceniany okres.
 * Generator jest deterministyczny (stałe ziarno), więc testy i demo zawsze dają ten sam wynik.
 */

const TOTAL_DAYS: number = 56;

class Rng {
  private s: number;

  constructor(seed: number) {
    this.s = seed % 4294967296;
  }

  next(): number {
    this.s = (this.s * 1664525 + 1013904223) % 4294967296;
    return this.s / 4294967296;
  }

  around(mean: number, spread: number): number {
    return mean + (this.next() * 2 - 1) * spread;
  }
}

class DayProfile {
  steps: number;
  stepsSpread: number;
  active: number;
  activeSpread: number;
  activeHr: number;
  resting: number;
  worn: number;
  sleep: number;

  constructor(steps: number, stepsSpread: number, active: number, activeSpread: number, activeHr: number,
    resting: number, worn: number, sleep: number) {
    this.steps = steps;
    this.stepsSpread = stepsSpread;
    this.active = active;
    this.activeSpread = activeSpread;
    this.activeHr = activeHr;
    this.resting = resting;
    this.worn = worn;
    this.sleep = sleep;
  }
}

function makeDay(rng: Rng, date: string, p: DayProfile): DaySample {
  const steps = Math.max(0, Math.round(rng.around(p.steps, p.stepsSpread)));
  const active = Math.max(0, Math.round(rng.around(p.active, p.activeSpread)));
  const activeHr = active > 0 ? Math.round(rng.around(p.activeHr, 4)) : 0;
  const resting = Math.round(rng.around(p.resting, 1.5));
  const worn = Math.min(1440, Math.max(0, Math.round(rng.around(p.worn, 30))));
  const sleep = Math.max(0, Math.round(rng.around(p.sleep, 20)));
  return new DaySample(date, steps, active, activeHr, resting, worn, sleep);
}

function dateFor(endIso: string, index: number): string {
  return addDays(endIso, index - (TOTAL_DAYS - 1));
}

export class Personas {
  static readonly ANNA: string = 'anna';
  static readonly MAREK: string = 'marek';
  static readonly ZOFIA: string = 'zofia';
  static readonly KAMIL: string = 'kamil';

  /** endIso = ostatni pełny dzień danych (zwykle wczoraj). */
  static all(endIso: string): Persona[] {
    return [Personas.anna(endIso), Personas.marek(endIso), Personas.zofia(endIso), Personas.kamil(endIso)];
  }

  static anna(endIso: string): Persona {
    const rng = new Rng(1001);
    const base = new DayProfile(8200, 1200, 30, 9, 118, 60, 1340, 445);
    const evalP = new DayProfile(9800, 1500, 36, 9, 120, 59, 1340, 448);
    const days: DaySample[] = [];
    for (let i = 0; i < TOTAL_DAYS; i++) {
      days.push(makeDay(rng, dateFor(endIso, i), i < 28 ? base : evalP));
    }
    return new Persona(Personas.ANNA, 'Anna, 34', 'Regularnie się rusza, śpi 7+ h',
      'Złoty próg, status OK', days);
  }

  static marek(endIso: string): Persona {
    const rng = new Rng(2002);
    const base = new DayProfile(8800, 1500, 28, 8, 122, 63, 1300, 430);
    const sick = new DayProfile(2200, 600, 2, 2, 95, 72, 1150, 520);
    const days: DaySample[] = [];
    for (let i = 0; i < TOTAL_DAYS; i++) {
      const p = (i >= 35 && i <= 41) ? sick : base;
      const d = makeDay(rng, dateFor(endIso, i), p);
      if (i >= 36 && i <= 38) {
        d.wornMinutes = 380;
      }
      days.push(d);
    }
    return new Persona(Personas.MAREK, 'Marek, 41', 'Tydzień grypy w środku okresu',
      'Złoty mimo choroby — liczą się 3 z 4 tygodni', days);
  }

  static zofia(endIso: string): Persona {
    const rng = new Rng(3003);
    const base = new DayProfile(2600, 250, 6, 3, 98, 72, 1300, 400);
    const weekMeans: number[] = [2650, 2740, 3020, 3230];
    const days: DaySample[] = [];
    for (let i = 0; i < TOTAL_DAYS; i++) {
      let p = base;
      if (i >= 28) {
        p = new DayProfile(weekMeans[Math.floor((i - 28) / 7)], 200, 7, 3, 98, 72, 1300, 400);
      }
      days.push(makeDay(rng, dateFor(endIso, i), p));
    }
    return new Persona(Personas.ZOFIA, 'Zofia, 67', 'Mało kroków, ale stała poprawa względem własnej normy',
      'Srebrny — cel liczony względem własnej bazy, nie 10 tys. kroków', days);
  }

  static kamil(endIso: string): Persona {
    const rng = new Rng(4004);
    const base = new DayProfile(4800, 800, 12, 5, 105, 64, 1250, 410);
    const fraudDays: number[] = [30, 33, 37, 41, 44];
    const days: DaySample[] = [];
    for (let i = 0; i < TOTAL_DAYS; i++) {
      const d = makeDay(rng, dateFor(endIso, i), base);
      if (fraudDays.indexOf(i) >= 0) {
        // Zegarek na wiertarce / psie: dużo "kroków", tętno właściciela w spoczynku.
        d.steps = Math.round(rng.around(26000, 2000));
        d.activeMinutes = Math.round(rng.around(190, 20));
        d.activeHrAvg = 67;
        d.restingHr = 63;
      }
      if (i === 47) {
        // Zegarek zdjęty, a krokomierz w telefonie na trzepaczce.
        d.steps = 26000;
        d.activeMinutes = 20;
        d.wornMinutes = 80;
      }
      days.push(d);
    }
    return new Persona(Personas.KAMIL, 'Kamil, 29 (test oszustwa)', 'Zegarek na wiertarce i na psie',
      'Do przeglądu przez człowieka — bez tętna prawie by przeszło', days);
  }
}
