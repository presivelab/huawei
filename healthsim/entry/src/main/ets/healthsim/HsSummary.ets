/**
 * View models for the simulator screens, computed from a dataset.
 * Pure logic; the UI only formats and draws these numbers.
 */
import {
  DAY_MS,
  HsDataset,
  HsDayTruth,
  HsEvent,
  HsEventKind,
  HsSleepStage,
  MINUTE_MS,
  SLOT_MS,
  SLOTS_PER_DAY
} from './HsTypes';

export class TodayModel {
  dateLabel: string = '';
  weekday: number = 0;
  timeLabel: string = '';
  stepsToday: number = 0;
  hourlySteps: number[] = [];
  /** Last 24 h, one value per 5-minute slot, 0 = no sample (watch off). */
  hr24h: number[] = [];
  hrLatest: number = 0;
  hrMin: number = 0;
  hrMax: number = 0;
  hrCoverageTodayPct: number = 0;
  restingHr: number = 0;
  restingHrAvg7: number = 0;
  /** Last night, one stage code per 5-minute slot from first to last fragment (0 = no data). */
  sleepSlots: number[] = [];
  sleepStartLabel: string = '';
  sleepEndLabel: string = '';
  sleepMinutes: number = 0;
  deepMinutes: number = 0;
  lightMinutes: number = 0;
  remMinutes: number = 0;
  awakeMinutes: number = 0;
  spo2Avg: number = 0;
  spo2Min: number = 0;
  skinTempDelta: number = 0;
  hasSkinTemp: boolean = false;
  stressLatest: number = 0;
  stressAvgToday: number = 0;
  vo2max: number = 0;
}

export class DayRow {
  dayStartMs: number = 0;
  dateLabel: string = '';
  weekday: number = 0;
  steps: number = 0;
  restingHr: number = 0;
  sleepMinutes: number = 0;
  hrCoveragePct: number = 0;
  sick: boolean = false;
  removal: boolean = false;
  charged: boolean = false;
  paddedSlots: number = 0;
  partial: boolean = false;
}

function pad2(n: number): string {
  return n < 10 ? '0' + String(n) : String(n);
}

/** HH:mm in the dataset's fixed UTC offset. */
export function formatTime(t: number, tzOffsetMin: number): string {
  const d: Date = new Date(t + tzOffsetMin * MINUTE_MS);
  return pad2(d.getUTCHours()) + ':' + pad2(d.getUTCMinutes());
}

/** MM-DD in the dataset's fixed UTC offset. */
export function formatDate(t: number, tzOffsetMin: number): string {
  const d: Date = new Date(t + tzOffsetMin * MINUTE_MS);
  return pad2(d.getUTCMonth() + 1) + '-' + pad2(d.getUTCDate());
}

export function weekdayOf(t: number, tzOffsetMin: number): number {
  const d: Date = new Date(t + tzOffsetMin * MINUTE_MS);
  return d.getUTCDay();
}

function eventsOfKind(ds: HsDataset, kind: number, from: number, to: number): HsEvent[] {
  const out: HsEvent[] = [];
  for (let i = 0; i < ds.events.length; i++) {
    const e: HsEvent = ds.events[i];
    if (e.kind === kind && e.startMs >= from && e.startMs < to) {
      out.push(e);
    }
  }
  return out;
}

export class HsSummary {
  static today(ds: HsDataset): TodayModel {
    const m: TodayModel = new TodayModel();
    const tz: number = ds.tzOffsetMin;
    const dayStart: number = ds.startMs + Math.floor((ds.anchorMs - ds.startMs) / DAY_MS) * DAY_MS;
    m.dateLabel = formatDate(ds.anchorMs, tz);
    m.weekday = weekdayOf(ds.anchorMs, tz);
    m.timeLabel = formatTime(ds.anchorMs, tz);

    // Steps today, per hour.
    const firstToday: number = Math.round((dayStart - ds.startMs) / SLOT_MS);
    const hourly: number[] = [];
    for (let h = 0; h < 24; h++) {
      hourly.push(0);
    }
    let withHr: number = 0;
    for (let i = firstToday; i < ds.slotCount; i++) {
      const h: number = Math.floor((i - firstToday) / 12);
      hourly[h] = hourly[h] + ds.steps[i];
      m.stepsToday += ds.steps[i];
      if (ds.hrBpm[i] > 0) {
        withHr++;
      }
    }
    m.hourlySteps = hourly;
    const todaySlots: number = ds.slotCount - firstToday;
    m.hrCoverageTodayPct = todaySlots > 0 ? Math.round(100 * withHr / todaySlots) : 0;

    // Heart rate, last 24 h.
    const from: number = ds.slotCount - SLOTS_PER_DAY;
    let minV: number = 999;
    let maxV: number = 0;
    const hr: number[] = [];
    for (let i = from; i < ds.slotCount; i++) {
      const v: number = i >= 0 ? ds.hrBpm[i] : 0;
      hr.push(v);
      if (v > 0) {
        m.hrLatest = v;
        minV = Math.min(minV, v);
        maxV = Math.max(maxV, v);
      }
    }
    m.hr24h = hr;
    m.hrMin = maxV > 0 ? minV : 0;
    m.hrMax = maxV;

    // Resting HR today and 7-day average.
    const rhrToday: HsEvent[] = eventsOfKind(ds, HsEventKind.RESTING_HR, dayStart, ds.anchorMs);
    m.restingHr = rhrToday.length > 0 ? rhrToday[0].value : 0;
    const rhr7: HsEvent[] = eventsOfKind(ds, HsEventKind.RESTING_HR, dayStart - 7 * DAY_MS, dayStart);
    let sum: number = 0;
    for (let i = 0; i < rhr7.length; i++) {
      sum += rhr7[i].value;
    }
    m.restingHrAvg7 = rhr7.length > 0 ? Math.round(sum / rhr7.length) : 0;

    // Last night: fragments between 18:00 yesterday and the anchor.
    const nightFrom: number = dayStart - 6 * 60 * MINUTE_MS;
    const frags: HsEvent[] = eventsOfKind(ds, HsEventKind.SLEEP, nightFrom, ds.anchorMs);
    if (frags.length > 0) {
      const first: number = frags[0].startMs;
      const last: number = frags[frags.length - 1].endMs;
      m.sleepStartLabel = formatTime(first, tz);
      m.sleepEndLabel = formatTime(last, tz);
      const n: number = Math.round((last - first) / SLOT_MS);
      const slots: number[] = [];
      for (let i = 0; i < n; i++) {
        slots.push(0);
      }
      for (let i = 0; i < frags.length; i++) {
        const f: HsEvent = frags[i];
        const minutes: number = Math.round((f.endMs - f.startMs) / MINUTE_MS);
        const a: number = Math.round((f.startMs - first) / SLOT_MS);
        const b: number = Math.round((f.endMs - first) / SLOT_MS);
        for (let s = a; s < b && s < n; s++) {
          slots[s] = f.value;
        }
        if (f.value === HsSleepStage.DEEP) {
          m.deepMinutes += minutes;
        } else if (f.value === HsSleepStage.LIGHT) {
          m.lightMinutes += minutes;
        } else if (f.value === HsSleepStage.REM) {
          m.remMinutes += minutes;
        } else {
          m.awakeMinutes += minutes;
        }
      }
      m.sleepSlots = slots;
      m.sleepMinutes = m.deepMinutes + m.lightMinutes + m.remMinutes;
    }

    // SpO2 last night.
    const spo2: HsEvent[] = eventsOfKind(ds, HsEventKind.SPO2, nightFrom, ds.anchorMs);
    if (spo2.length > 0) {
      let s2: number = 0;
      let mn: number = 100;
      for (let i = 0; i < spo2.length; i++) {
        s2 += spo2[i].value;
        mn = Math.min(mn, spo2[i].value);
      }
      m.spo2Avg = Math.round(s2 / spo2.length);
      m.spo2Min = mn;
    }

    // Skin temperature: last night vs the 14 nights before.
    const tNight: HsEvent[] = eventsOfKind(ds, HsEventKind.SKIN_TEMP, nightFrom, ds.anchorMs);
    const tBase: HsEvent[] = eventsOfKind(ds, HsEventKind.SKIN_TEMP, nightFrom - 14 * DAY_MS, nightFrom);
    if (tNight.length > 0 && tBase.length > 0) {
      let a: number = 0;
      for (let i = 0; i < tNight.length; i++) {
        a += tNight[i].value;
      }
      let b: number = 0;
      for (let i = 0; i < tBase.length; i++) {
        b += tBase[i].value;
      }
      m.skinTempDelta = Math.round((a / tNight.length - b / tBase.length)) / 10;
      m.hasSkinTemp = true;
    }

    // Stress today.
    const stress: HsEvent[] = eventsOfKind(ds, HsEventKind.STRESS, dayStart, ds.anchorMs);
    if (stress.length > 0) {
      let s3: number = 0;
      for (let i = 0; i < stress.length; i++) {
        s3 += stress[i].value;
      }
      m.stressAvgToday = Math.round(s3 / stress.length);
      m.stressLatest = stress[stress.length - 1].value;
    }

    // Latest VO2max.
    const vo2: HsEvent[] = eventsOfKind(ds, HsEventKind.VO2MAX, ds.startMs, ds.anchorMs);
    if (vo2.length > 0) {
      m.vo2max = vo2[vo2.length - 1].value / 10;
    }
    return m;
  }

  /** One row per local day, newest first. */
  static days(ds: HsDataset): DayRow[] {
    const rows: DayRow[] = [];
    const tz: number = ds.tzOffsetMin;
    for (let d = 0; d < ds.truth.length; d++) {
      const t: HsDayTruth = ds.truth[d];
      const r: DayRow = new DayRow();
      r.dayStartMs = t.dayStartMs;
      r.dateLabel = formatDate(t.dayStartMs + 12 * 60 * MINUTE_MS, tz);
      r.weekday = weekdayOf(t.dayStartMs + 12 * 60 * MINUTE_MS, tz);
      r.sick = t.sick;
      r.removal = t.removal;
      r.charged = t.charged;
      r.paddedSlots = t.paddedSlots;
      r.partial = t.partial;
      r.restingHr = t.restingHr;
      const first: number = d * SLOTS_PER_DAY;
      let slots: number = 0;
      let withHr: number = 0;
      for (let i = first; i < first + SLOTS_PER_DAY && i < ds.slotCount; i++) {
        r.steps += ds.steps[i];
        slots++;
        if (ds.hrBpm[i] > 0) {
          withHr++;
        }
      }
      r.hrCoveragePct = slots > 0 ? Math.round(100 * withHr / slots) : 0;
      // Sleep that ended on this day (the night before it).
      const frags: HsEvent[] = eventsOfKind(ds, HsEventKind.SLEEP, t.dayStartMs - 6 * 60 * MINUTE_MS,
        t.dayStartMs + 14 * 60 * MINUTE_MS);
      for (let i = 0; i < frags.length; i++) {
        if (frags[i].value !== HsSleepStage.AWAKE) {
          r.sleepMinutes += Math.round((frags[i].endMs - frags[i].startMs) / MINUTE_MS);
        }
      }
      rows.push(r);
    }
    rows.reverse();
    return rows;
  }
}
