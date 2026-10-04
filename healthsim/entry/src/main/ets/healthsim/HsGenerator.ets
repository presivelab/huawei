/**
 * Deterministic generator of Huawei-Health-shaped data for one persona.
 *
 * Same (persona, seed, anchor, days) -> byte-identical dataset on every device.
 * Each local day draws from its own PRNG stream keyed by the epoch day,
 * so one calendar day looks the same whatever the window length.
 *
 * Rules the FairWear engine depends on:
 *  - wear is never a data type; it only shows up as gaps in heart-rate samples;
 *  - heart rate rises with steps (HR_PER_SPM), so honest steps pass K20;
 *  - a sick episode lasts >= 2 consecutive days with elevated heart rate (K18);
 *  - padded steps (persona Wei) have no heart-rate rise.
 */
import {
  DAY_MS,
  HsDataset,
  HsDayTruth,
  HsEvent,
  HsEventKind,
  HsSleepStage,
  MAX_DAYS,
  MINUTE_MS,
  SLOT_MINUTES,
  SLOT_MS,
  SLOTS_PER_DAY
} from './HsTypes';
import { HsEpisode, HsPersona } from './HsPersonas';
import { clamp, hash32, HsRandom } from './HsRandom';

/** bpm added per step-per-minute while awake. Tunable; keep in sync with K20 thresholds. */
export const HR_PER_SPM: number = 0.2;
/** Max steps in one 5-minute slot (about 130 steps/min). */
export const MAX_STEPS_PER_SLOT: number = 650;

/** Fixed demo anchor: Sun 4 Oct 2026, 09:00 in Warsaw (07:00 UTC). */
export const DEMO_ANCHOR_MS: number = Date.UTC(2026, 9, 4, 7, 0, 0);

class DayPlan {
  dayIndex: number = 0;
  dayStartMs: number = 0;
  epochDay: number = 0;
  daysAgo: number = 0;
  weekday: number = 0;
  wakeMin: number = 410;
  bedMin: number = 1395;
  sick: boolean = false;
  afterSick: boolean = false;
  removal: boolean = false;
  charge: boolean = false;
  chargeStartMin: number = 0;
  stepsTarget: number = 0;
  restingHr: number = 60;
  morningOffMin: number = 0;
  eveningOffStartMin: number = 0;
  eveningOffLenMin: number = 0;
  shortGap: boolean = false;
  shortGapStartMin: number = 0;
  shortGapLenMin: number = 0;
  removalStartMin: number = 600;
  eveningWalk: boolean = false;
  /** The night after bedtime belongs to the next day (its resting HR, sickness, removal). */
  nextRestingHr: number = 60;
  nextSick: boolean = false;
  nextRemoval: boolean = false;
  rng: HsRandom = new HsRandom(1);
}

export function localDayStart(t: number, tzOffsetMin: number): number {
  const shift: number = tzOffsetMin * MINUTE_MS;
  return Math.floor((t + shift) / DAY_MS) * DAY_MS - shift;
}

export function floorToSlot(t: number): number {
  return Math.floor(t / SLOT_MS) * SLOT_MS;
}

function episodeIndexForDay(episodes: HsEpisode[], daysAgo: number): number {
  for (let i = 0; i < episodes.length; i++) {
    const e: HsEpisode = episodes[i];
    if (daysAgo <= e.startDaysAgo && daysAgo > e.startDaysAgo - e.lengthDays) {
      return e.startDaysAgo - daysAgo;
    }
  }
  return -1;
}

function isDayAfterEpisode(episodes: HsEpisode[], daysAgo: number): boolean {
  for (let i = 0; i < episodes.length; i++) {
    const e: HsEpisode = episodes[i];
    if (daysAgo === e.startDaysAgo - e.lengthDays) {
      return true;
    }
  }
  return false;
}

function planDay(persona: HsPersona, seed: number, dayIndex: number, dayStartMs: number, daysAgo: number): DayPlan {
  const p: DayPlan = new DayPlan();
  p.dayIndex = dayIndex;
  p.dayStartMs = dayStartMs;
  p.epochDay = Math.round((dayStartMs + persona.tzOffsetMin * MINUTE_MS) / DAY_MS);
  p.daysAgo = daysAgo;
  p.weekday = ((p.epochDay + 4) % 7 + 7) % 7;
  p.rng = new HsRandom(hash32(persona.id + '|' + String(seed) + '|' + String(p.epochDay)));
  const r: HsRandom = p.rng;

  // Fixed draw order: every value is drawn every day, then adjusted.
  const bedJitter: number = r.gauss(0, 20);
  const wakeJitter: number = r.gauss(0, 15);
  const stepsFactor: number = r.gauss(1, 0.18);
  const weekendFactor: number = r.range(0.8, 1.15);
  const sickFactor: number = r.range(0.4, 0.6);
  const rhrNoise: number = r.gauss(0, 1.2);
  const sickRise: number = r.range(6, 10);
  const chargeJitter: number = r.gauss(0, 15);
  const morningOff: number = r.int(25, 45);
  const eveningStartJitter: number = r.gauss(0, 20);
  const offScale: number = r.range(0.8, 1.2);
  const gapRoll: number = r.next();
  const gapStart: number = r.int(600, 1060);
  const gapLen: number = r.int(2, 6) * SLOT_MINUTES;
  const removalJitter: number = r.int(-30, 30);
  const walkRoll: number = r.next();

  const sickIndex: number = episodeIndexForDay(persona.sickEpisodes, daysAgo);
  p.sick = sickIndex >= 0;
  p.afterSick = isDayAfterEpisode(persona.sickEpisodes, daysAgo);
  p.removal = persona.selectiveRemovalAroundSick && ((p.sick && sickIndex >= 2) || p.afterSick);

  const weekendEvening: boolean = p.weekday === 5 || p.weekday === 6;
  const weekendMorning: boolean = p.weekday === 6 || p.weekday === 0;
  p.bedMin = Math.round(clamp(1395 + bedJitter + (weekendEvening ? 35 : 0) - (p.sick ? 30 : 0), 1320, 1435));
  p.wakeMin = Math.round(clamp(410 + wakeJitter + (weekendMorning ? 60 : 0) + (p.sick ? 30 : 0), 330, 560));

  let target: number = persona.stepsMean * clamp(stepsFactor, 0.5, 1.6);
  if (weekendMorning) {
    target = target * weekendFactor;
  }
  if (p.sick) {
    target = target * sickFactor;
  }
  p.stepsTarget = target;

  p.restingHr = persona.restingHrBase + rhrNoise + (p.sick ? sickRise : 0) + (p.afterSick ? 3 : 0);

  const every: number = Math.max(1, Math.round(persona.chargeEveryDays));
  p.charge = (p.epochDay % every + every) % every === 0;
  p.chargeStartMin = Math.round(clamp(persona.chargeHour * 60 + chargeJitter, 300, 1320));

  const chargeAvgMin: number = 60 / every;
  const offTotalMin: number = Math.max(0, (24 - persona.wearHoursMean) * 60) * offScale;
  p.morningOffMin = Math.min(morningOff, Math.round(offTotalMin));
  p.eveningOffLenMin = Math.max(0, Math.round(offTotalMin - p.morningOffMin - chargeAvgMin));
  p.eveningOffStartMin = Math.round(clamp(1170 + eveningStartJitter, 1080, 1260));

  p.shortGap = gapRoll < 0.5;
  p.shortGapStartMin = gapStart;
  p.shortGapLenMin = gapLen;
  p.removalStartMin = 600 + removalJitter;
  p.eveningWalk = walkRoll < 0.5;
  return p;
}

function inRange(m: number, start: number, end: number): boolean {
  return m >= start && m < end;
}

function isWorn(p: DayPlan, m: number): boolean {
  if (p.removal) {
    return inRange(m, p.removalStartMin, p.removalStartMin + 330);
  }
  if (p.nextRemoval && m >= p.bedMin) {
    return false;
  }
  if (inRange(m, p.wakeMin + 5, p.wakeMin + 5 + p.morningOffMin)) {
    return false;
  }
  if (p.eveningOffLenMin > 0 && inRange(m, p.eveningOffStartMin, p.eveningOffStartMin + p.eveningOffLenMin)) {
    return false;
  }
  if (p.charge && inRange(m, p.chargeStartMin, p.chargeStartMin + 60)) {
    return false;
  }
  if (p.shortGap && inRange(m, p.shortGapStartMin, p.shortGapStartMin + p.shortGapLenMin)) {
    return false;
  }
  return true;
}

function activityWeight(p: DayPlan, m: number): number {
  if (inRange(m, p.wakeMin + 45, p.wakeMin + 105)) {
    return 1.0;
  }
  if (inRange(m, 990, 1080)) {
    return 1.0;
  }
  if (inRange(m, 720, 780)) {
    return 0.6;
  }
  if (p.eveningWalk && inRange(m, 1140, 1230)) {
    return 0.8;
  }
  return 0.12;
}

function sleepStageAt(minutesSinceBed: number, r: HsRandom): number {
  const brief: boolean = r.chance(0.03);
  if (minutesSinceBed < 5) {
    return HsSleepStage.AWAKE;
  }
  if (brief) {
    return HsSleepStage.AWAKE;
  }
  const cycle: number = Math.floor(minutesSinceBed / 90);
  const pos: number = (minutesSinceBed % 90) / 90;
  const deepShare: number = cycle === 0 ? 0.35 : (cycle === 1 ? 0.25 : (cycle === 2 ? 0.12 : 0.04));
  const remShare: number = cycle === 0 ? 0.10 : (cycle === 1 ? 0.18 : (cycle === 2 ? 0.25 : 0.32));
  if (pos < 0.15) {
    return HsSleepStage.LIGHT;
  }
  if (pos < 0.15 + deepShare) {
    return HsSleepStage.DEEP;
  }
  if (pos < 1 - remShare) {
    return HsSleepStage.LIGHT;
  }
  return HsSleepStage.REM;
}

function percentile10(values: number[]): number {
  const sorted: number[] = values.slice(0);
  sorted.sort((a: number, b: number): number => a - b);
  const idx: number = Math.floor(0.1 * (sorted.length - 1));
  return sorted[idx];
}

export class HsGenerator {
  /**
   * Generates `days` full local days before the anchor day plus the anchor day up to anchorMs.
   * @param persona persona definition
   * @param seed integer seed
   * @param anchorMs simulated "now"; floored to 5 minutes
   * @param days number of full days of history (1..MAX_DAYS)
   */
  static generate(persona: HsPersona, seed: number, anchorMs: number, days: number): HsDataset {
    const nDays: number = Math.round(clamp(days, 1, MAX_DAYS));
    const tz: number = persona.tzOffsetMin;
    const anchor: number = floorToSlot(anchorMs);
    const anchorDayStart: number = localDayStart(anchor, tz);
    const startMs: number = anchorDayStart - nDays * DAY_MS;
    const totalDays: number = nDays + 1;
    const fullSlots: number = totalDays * SLOTS_PER_DAY;
    const slotCount: number = Math.round((anchor - startMs) / SLOT_MS);

    // Pass 1: day plans, plus the day before the window (for the first night's bedtime).
    const plans: DayPlan[] = [];
    for (let d = -1; d < totalDays; d++) {
      plans.push(planDay(persona, seed, d, startMs + d * DAY_MS, nDays - d));
    }
    for (let i = 0; i < plans.length; i++) {
      const next: DayPlan = i + 1 < plans.length ? plans[i + 1] : plans[i];
      plans[i].nextRestingHr = next.restingHr;
      plans[i].nextSick = next.sick;
      plans[i].nextRemoval = i + 1 < plans.length ? next.removal : false;
    }

    const steps: Uint16Array = new Uint16Array(fullSlots);
    const hrBpm: Uint8Array = new Uint8Array(fullSlots);
    const hrOffset: Uint8Array = new Uint8Array(fullSlots);
    const stage: Uint8Array = new Uint8Array(fullSlots);
    const worn: Uint8Array = new Uint8Array(fullSlots);
    const sleeping: Uint8Array = new Uint8Array(fullSlots);
    const padded: Uint8Array = new Uint8Array(fullSlots);
    const events: HsEvent[] = [];
    const truth: HsDayTruth[] = [];

    // Pass 2: slots, day by day.
    for (let d = 0; d < totalDays; d++) {
      const p: DayPlan = plans[d + 1];
      const prev: DayPlan = plans[d];
      const r: HsRandom = p.rng;
      const base: number = d * SLOTS_PER_DAY;

      // Wear and sleep masks, raw activity.
      const raw: number[] = [];
      let rawSum: number = 0;
      for (let s = 0; s < SLOTS_PER_DAY; s++) {
        const m: number = s * SLOT_MINUTES;
        const asleep: boolean = m < p.wakeMin || m >= p.bedMin;
        sleeping[base + s] = asleep ? 1 : 0;
        worn[base + s] = isWorn(p, m) ? 1 : 0;
        const w: number = activityWeight(p, m);
        const activeRoll: number = r.next();
        const amount: number = r.next();
        const fidgetRoll: number = r.next();
        let v: number = 0;
        if (!asleep) {
          if (activeRoll < 0.25 + 0.55 * w && w > 0.5) {
            v = (250 + 350 * amount) * (0.6 + 0.4 * w);
          } else if (fidgetRoll < 0.5) {
            v = 60 * amount;
          }
        }
        raw.push(v);
        rawSum += v;
      }

      // Scale to the day's target; steps are only recorded while worn.
      const scale: number = rawSum > 0 ? p.stepsTarget / rawSum : 0;
      for (let s = 0; s < SLOTS_PER_DAY; s++) {
        if (worn[base + s] === 1) {
          steps[base + s] = Math.round(Math.min(MAX_STEPS_PER_SLOT, raw[s] * scale));
        }
      }

      // Step padding: high steps at rest (12:00-23:00), heart rate stays at the sitting baseline.
      let paddedCount: number = 0;
      if (persona.padSlotsPerDay > 0) {
        let attempts: number = 0;
        while (paddedCount < persona.padSlotsPerDay && attempts < 400) {
          attempts++;
          const s: number = r.int(144, 275);
          const idx: number = base + s;
          if (worn[idx] === 1 && sleeping[idx] === 0 && padded[idx] === 0 && steps[idx] < 100) {
            padded[idx] = 1;
            steps[idx] = r.int(320, 420);
            paddedCount++;
          }
        }
      }

      // Heart rate, one sample per worn slot.
      for (let s = 0; s < SLOTS_PER_DAY; s++) {
        const noise: number = r.gauss(0, 1);
        const offset: number = r.int(90, 210);
        if (worn[base + s] === 0) {
          continue;
        }
        let bpm: number = 0;
        const nightRhr: number = s * SLOT_MINUTES >= p.bedMin ? p.nextRestingHr : p.restingHr;
        if (sleeping[base + s] === 1) {
          bpm = nightRhr + 3 + 2 * noise;
        } else if (padded[base + s] === 1) {
          bpm = Math.min(p.restingHr + 14 + 1.5 * noise, p.restingHr + 18);
        } else {
          bpm = p.restingHr + 14 + HR_PER_SPM * (steps[base + s] / SLOT_MINUTES) + 3 * noise;
        }
        hrBpm[base + s] = Math.round(clamp(bpm, 38, 195));
        hrOffset[base + s] = offset;
      }

      // Sleep stages (morning part belongs to the night that started on the previous day).
      for (let s = 0; s < SLOTS_PER_DAY; s++) {
        const m: number = s * SLOT_MINUTES;
        if (sleeping[base + s] === 0) {
          continue;
        }
        const sinceBed: number = m < p.wakeMin ? (1440 - prev.bedMin) + m : m - p.bedMin;
        const st: number = sleepStageAt(sinceBed, r);
        if (worn[base + s] === 1) {
          stage[base + s] = st;
        }
      }

      // Instant samples on the 30-minute grid.
      for (let s = 0; s < SLOTS_PER_DAY; s++) {
        const m: number = s * SLOT_MINUTES;
        const slotStart: number = p.dayStartMs + m * MINUTE_MS;
        const g1: number = r.gauss(0, 1);
        const g2: number = r.gauss(0, 1);
        const u: number = r.next();
        if (worn[base + s] === 0) {
          continue;
        }
        const sickNow: boolean = m >= p.bedMin ? p.nextSick : p.sick;
        if (sleeping[base + s] === 1 && m % 30 === 0) {
          const spo2: number = Math.round(clamp(97 + 0.9 * g1 - (sickNow ? 1.5 : 0), 90, 100));
          events.push(new HsEvent(HsEventKind.SPO2, slotStart + MINUTE_MS, slotStart + MINUTE_MS, spo2));
        }
        if (sleeping[base + s] === 1 && m % 30 === 15) {
          const tenths: number = Math.round(340 + 2 * g2 + (sickNow ? 4 + 4 * u : 0));
          events.push(new HsEvent(HsEventKind.SKIN_TEMP, slotStart + MINUTE_MS, slotStart + MINUTE_MS, tenths));
        }
        if (sleeping[base + s] === 0 && m % 30 === 0) {
          const load: number = Math.min(15, steps[base + s] / 40);
          const score: number = Math.round(clamp(28 + 8 * g1 + (p.sick ? 10 : 0) + load, 1, 99));
          events.push(new HsEvent(HsEventKind.STRESS, slotStart + 2 * MINUTE_MS, slotStart + 2 * MINUTE_MS, score));
        }
      }

      // VO2max: Mondays, an hour after waking, if worn then.
      const vo2Noise: number = r.gauss(0, 3);
      const vo2Slot: number = Math.floor((p.wakeMin + 60) / SLOT_MINUTES);
      if (p.weekday === 1 && vo2Slot < SLOTS_PER_DAY && worn[base + vo2Slot] === 1) {
        const t: number = p.dayStartMs + vo2Slot * SLOT_MS + MINUTE_MS;
        events.push(new HsEvent(HsEventKind.VO2MAX, t, t, Math.round(10 * persona.vo2maxBase + vo2Noise)));
      }

      const dt: HsDayTruth = new HsDayTruth();
      dt.dayStartMs = p.dayStartMs;
      dt.sick = p.sick;
      dt.removal = p.removal;
      dt.charged = p.charge;
      dt.paddedSlots = paddedCount;
      truth.push(dt);
    }

    // Resting HR: 10th percentile of the night's HR, stamped 30 min after waking.
    for (let d = 0; d < totalDays; d++) {
      const p: DayPlan = plans[d + 1];
      const prev: DayPlan = plans[d];
      const base: number = d * SLOTS_PER_DAY;
      const night: number[] = [];
      for (let s = base - SLOTS_PER_DAY; s < base + SLOTS_PER_DAY; s++) {
        if (s < 0) {
          continue;
        }
        const morningPart: boolean = s >= base && (s - base) * SLOT_MINUTES < p.wakeMin;
        const eveningPart: boolean = s < base && (s - base + SLOTS_PER_DAY) * SLOT_MINUTES >= prev.bedMin;
        if ((morningPart || eveningPart) && hrBpm[s] > 0) {
          night.push(hrBpm[s]);
        }
      }
      if (night.length >= 12) {
        const t: number = p.dayStartMs + (p.wakeMin + 30) * MINUTE_MS;
        const rhr: number = percentile10(night);
        events.push(new HsEvent(HsEventKind.RESTING_HR, t, t, rhr));
        truth[d].restingHr = rhr;
      }
    }

    // Sleep fragments: merge consecutive slots with the same stage.
    let runStage: number = 0;
    let runStart: number = 0;
    for (let s = 0; s <= fullSlots; s++) {
      const st: number = s < fullSlots ? stage[s] : 0;
      if (st !== runStage) {
        if (runStage !== 0) {
          events.push(new HsEvent(HsEventKind.SLEEP, startMs + runStart * SLOT_MS, startMs + s * SLOT_MS, runStage));
        }
        runStage = st;
        runStart = s;
      }
    }

    // Truncate at the anchor.
    const ds: HsDataset = new HsDataset();
    ds.personaId = persona.id;
    ds.seed = seed;
    ds.anchorMs = anchor;
    ds.startMs = startMs;
    ds.tzOffsetMin = tz;
    ds.slotCount = slotCount;
    ds.steps = steps.slice(0, slotCount);
    ds.hrBpm = hrBpm.slice(0, slotCount);
    ds.hrOffsetSec = hrOffset.slice(0, slotCount);
    ds.dataSourceId = 'healthsim:watch:' + persona.id;

    const kept: HsEvent[] = [];
    for (let i = 0; i < events.length; i++) {
      const e: HsEvent = events[i];
      if (e.startMs >= anchor) {
        continue;
      }
      if (e.endMs > anchor) {
        kept.push(new HsEvent(e.kind, e.startMs, anchor, e.value));
      } else {
        kept.push(e);
      }
    }
    kept.sort((a: HsEvent, b: HsEvent): number => {
      if (a.startMs !== b.startMs) {
        return a.startMs - b.startMs;
      }
      return a.kind - b.kind;
    });
    ds.events = kept;

    for (let d = 0; d < totalDays; d++) {
      const base: number = d * SLOTS_PER_DAY;
      let wornSlots: number = 0;
      let total: number = 0;
      for (let s = 0; s < SLOTS_PER_DAY; s++) {
        const idx: number = base + s;
        if (idx >= slotCount) {
          break;
        }
        wornSlots += worn[idx];
        total += steps[idx];
      }
      truth[d].wornMinutes = wornSlots * SLOT_MINUTES;
      truth[d].stepsTotal = total;
      truth[d].partial = d === totalDays - 1;
    }
    ds.truth = truth;
    return ds;
  }
}
