/*
 * Zbiera odczyty z czujników na żywo (krokomierz, tętno, wykrywanie noszenia)
 * i ocenia ostatnią minutę tymi samymi zasadami co detektor dzienny.
 * Czysta logika: SensorSource tylko wpycha tu zdarzenia, symulator w UI robi to samo na emulatorze.
 */

export class TimedValue {
  t: number;
  v: number;

  constructor(t: number, v: number) {
    this.t = t;
    this.v = v;
  }
}

export class LiveSnapshot {
  heartRate: number = 0;
  hrAvg60: number = 0;
  restingEstimate: number = 0;
  stepsSession: number = 0;
  stepsPerMinute: number = 0;
  /** -1 nieznane, 0 zdjęty, 1 na nadgarstku */
  worn: number = -1;
  suspicious: boolean = false;
  verdict: string = 'Czekam na dane z czujników';
  samples: number = 0;
}

export class LiveDayCollector {
  static readonly WINDOW_MS: number = 60000;
  static readonly KEEP_MS: number = 10 * 60000;
  static readonly WALKING_SPM: number = 60;
  static readonly MIN_HR_RISE: number = 10;

  private firstSteps: number = -1;
  private stepSamples: TimedValue[] = [];
  private hrSamples: TimedValue[] = [];
  private worn: number = -1;
  private minHr: number = 0;
  private hrCount: number = 0;

  reset(): void {
    this.firstSteps = -1;
    this.stepSamples = [];
    this.hrSamples = [];
    this.worn = -1;
    this.minHr = 0;
    this.hrCount = 0;
  }

  /** Krokomierz podaje sumę narastającą; liczymy przyrosty od startu sesji. */
  addPedometer(total: number, tMs: number): void {
    if (total < 0) {
      return;
    }
    if (this.firstSteps < 0) {
      this.firstSteps = total;
    }
    this.stepSamples.push(new TimedValue(tMs, total));
    this.prune(tMs);
  }

  addHeartRate(bpm: number, tMs: number): void {
    if (bpm < 30 || bpm > 220) {
      return;
    }
    this.hrSamples.push(new TimedValue(tMs, bpm));
    this.hrCount++;
    this.minHr = this.minHr === 0 ? bpm : Math.min(this.minHr, bpm);
    this.prune(tMs);
  }

  setWorn(value: number): void {
    this.worn = value >= 1 ? 1 : 0;
  }

  snapshot(nowMs: number): LiveSnapshot {
    const s = new LiveSnapshot();
    s.worn = this.worn;
    s.samples = this.stepSamples.length + this.hrSamples.length;
    const windowStart = nowMs - LiveDayCollector.WINDOW_MS;

    if (this.stepSamples.length > 0) {
      const last = this.stepSamples[this.stepSamples.length - 1];
      s.stepsSession = Math.round(last.v - this.firstSteps);
      let ref = this.stepSamples[0];
      for (const sample of this.stepSamples) {
        if (sample.t <= windowStart) {
          ref = sample;
        }
      }
      const span = last.t - ref.t;
      if (span >= 10000) {
        s.stepsPerMinute = Math.round((last.v - ref.v) / (span / 60000));
      }
    }

    let hrSum = 0;
    let hrN = 0;
    for (const h of this.hrSamples) {
      if (h.t >= windowStart) {
        hrSum += h.v;
        hrN++;
      }
    }
    if (this.hrSamples.length > 0) {
      s.heartRate = this.hrSamples[this.hrSamples.length - 1].v;
    }
    s.hrAvg60 = hrN > 0 ? Math.round(hrSum / hrN) : 0;
    s.restingEstimate = this.hrCount >= 5 ? this.minHr : 0;

    if (s.samples === 0) {
      s.verdict = 'Czekam na dane z czujników';
    } else if (s.worn === 0 && s.stepsPerMinute >= 20) {
      s.suspicious = true;
      s.verdict = 'Kroki przy zdjętym zegarku';
    } else if (s.stepsPerMinute >= LiveDayCollector.WALKING_SPM && s.hrAvg60 > 0 && s.restingEstimate > 0 &&
      s.hrAvg60 - s.restingEstimate < LiveDayCollector.MIN_HR_RISE) {
      s.suspicious = true;
      s.verdict = 'Chód bez wzrostu tętna';
    } else if (s.stepsPerMinute >= LiveDayCollector.WALKING_SPM) {
      s.verdict = s.hrAvg60 > 0 ? 'Ruch wiarygodny — tętno rośnie z wysiłkiem' : 'Ruch (bez tętna nie da się go potwierdzić)';
    } else {
      s.verdict = 'Spoczynek';
    }
    return s;
  }

  private prune(nowMs: number): void {
    const cutoff = nowMs - LiveDayCollector.KEEP_MS;
    while (this.stepSamples.length > 2 && this.stepSamples[0].t < cutoff) {
      this.stepSamples.shift();
    }
    while (this.hrSamples.length > 0 && this.hrSamples[0].t < cutoff) {
      this.hrSamples.shift();
    }
  }
}
