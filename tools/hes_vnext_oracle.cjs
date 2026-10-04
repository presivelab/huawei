// HES vNext — reference oracle (Node, no deps). NOT shipped in the app.
// Purpose: cross-check the ArkTS engine and regenerate persona goldens.
// Run: node tools/hes_vnext_oracle.cjs
// Limits: windows are by array index (last 28/14 entries) and CRF/HRR use a fixed daysAgo, so it matches
// the calendar-date rules (D9) only for gap-free histories (all personas are gap-free). piecewise() does not
// guard non-finite x. Do NOT use the oracle for fuzz / non-finite tests — those assert the engine's own guards.
//
// PROVENANCE. The build prompt carried this file as its Appendix C, and the paste was cut by the
// 50,000-character limit in the middle of aggregate(). Everything down to the marker "END OF THE PART
// RECEIVED" is that appendix as it arrived, apart from line breaks and quote style changed by the
// workstation's code formatter on save. Everything below the marker was written in this repository from
// Appendix A (the specification), Appendix B (the persona recipe) and decisions D1-D23. So the lower half is
// a second implementation in another language with index-based windows, not the prompt author's original.
// The independent check of the engine is the table of golden values in the prompt, which the tests in
// common/src/test/HesPersonas.test.ets assert number by number; this oracle reproduces the same table.
// Replace the lower half with the original appendix when it is at hand and run tools/check-oracle.sh.
"use strict";

// ---- model definition (weights in per-mille, integers -> exact coverage) ----
const ORDER = [
  "crf",
  "rhr",
  "mvpa",
  "steps",
  "sleepRegularity",
  "sleepDuration",
  "hrv",
  "hrr",
];
const CORE = ["rhr", "mvpa", "steps", "sleepRegularity", "sleepDuration"];
const WEIGHTS_PM = {
  HEALTH_WELLNESS: {
    crf: 125,
    rhr: 125,
    mvpa: 200,
    steps: 150,
    sleepRegularity: 150,
    sleepDuration: 125,
    hrv: 75,
    hrr: 50,
  },
  LONGEVITY_WELLNESS: {
    crf: 225,
    rhr: 150,
    mvpa: 150,
    steps: 175,
    sleepRegularity: 100,
    sleepDuration: 75,
    hrv: 75,
    hrr: 50,
  },
};
const COUNTS = {
  steps: [14, 21],
  mvpa: [14, 21],
  rhr: [10, 14],
  sleepDuration: [14, 21],
  sleepRegularity: [14, 21],
  hrv: [7, 14],
  crf: [1, 2],
  hrr: [2, 3],
};
const CURVES = {
  crf: [
    [5, 10],
    [10, 20],
    [25, 45],
    [50, 70],
    [75, 88],
    [90, 97],
    [95, 100],
  ],
  rhr: [
    [40, 90],
    [45, 98],
    [50, 100],
    [55, 100],
    [60, 95],
    [65, 90],
    [70, 84],
    [75, 76],
    [80, 66],
    [90, 45],
    [100, 20],
    [110, 5],
  ],
  mvpa: [
    [0, 0],
    [30, 20],
    [60, 40],
    [100, 60],
    [150, 80],
    [250, 95],
    [300, 100],
  ],
  steps: [
    [1000, 0],
    [2000, 20],
    [4000, 50],
    [5000, 65],
    [6000, 80],
    [7000, 90],
    [8000, 95],
    [10000, 100],
  ],
  sleepRegularity: [
    [30, 100],
    [45, 90],
    [60, 80],
    [90, 60],
    [120, 40],
    [180, 15],
    [240, 0],
  ],
  sleepDuration: [
    [4.5, 0],
    [5.0, 25],
    [5.5, 45],
    [6.0, 65],
    [6.5, 82],
    [7.0, 95],
    [7.5, 100],
    [8.0, 100],
    [8.5, 100],
    [9.0, 100],
    [9.5, 95],
    [10.0, 90],
    [11.0, 80],
    [12.0, 65],
  ],
  hrv: [
    [5, 10],
    [10, 25],
    [25, 50],
    [50, 75],
    [75, 90],
    [90, 97],
    [95, 100],
  ],
  hrr: [
    [12, 10],
    [18, 30],
    [24, 55],
    [30, 70],
    [36, 82],
    [42, 92],
    [50, 100],
  ],
};
const EPS = 1e-9;
const HRV_PROTOCOL = "nocturnal";

const clamp = (v) => Math.min(100, Math.max(0, v));
function piecewise(pts, x) {
  if (x <= pts[0][0]) return clamp(pts[0][1]);
  if (x >= pts[pts.length - 1][0]) return clamp(pts[pts.length - 1][1]);
  for (let i = 0; i < pts.length - 1; i++) {
    const [x0, y0] = pts[i],
      [x1, y1] = pts[i + 1];
    if (x <= x1) return clamp(y0 + ((x - x0) / (x1 - x0)) * (y1 - y0));
  }
  return clamp(pts[pts.length - 1][1]);
}
const relMin = (m) => (m - 1080 + 1440) % 1440;
const mean = (xs) => xs.reduce((a, b) => a + b, 0) / xs.length;
const median = (xs) => {
  const a = [...xs].sort((x, y) => x - y);
  const m = a.length >> 1;
  return a.length % 2 ? a[m] : (a[m - 1] + a[m]) / 2;
};
const popSd = (xs) => {
  const m = mean(xs);
  return Math.sqrt(mean(xs.map((x) => (x - m) ** 2)));
};
const ok = (x) => typeof x === "number" && Number.isFinite(x) && x >= 0;

// history: { days: DayRecord[] (oldest..newest, completed only), crf: [{daysAgo,pct}], hrr: [{daysAgo,protocolId,peakHr,hr60}] }
function aggregate(hist) {
  const N = hist.days.length;
  const w28 = hist.days.slice(Math.max(0, N - 28));
  const w14 = hist.days.slice(Math.max(0, N - 14));
  const steps = w28.map((d) => d.steps).filter(ok);
  const eq = w28
    .filter((d) => ok(d.moderateMin) && ok(d.vigorousMin))
    .map((d) => d.moderateMin + 2 * d.vigorousMin);
  const rhr = w28.map((d) => d.restingHr).filter(ok);
  const nights = w28
    .map((d) => d.sleep)
    .filter((s) => s && ok(s.bedMin) && ok(s.wakeMin) && ok(s.totalSleepMin));
  const hrv = w14
    .map((d) => d.hrv)
    .filter((x) => x && x.protocol === HRV_PROTOCOL && ok(x.percentile))
    .map((x) => x.percentile);
  const crf = hist.crf
    .filter((e) => e.daysAgo >= 0 && e.daysAgo <= 89 && ok(e.pct))
    .sort((a, b) => a.daysAgo - b.daysAgo);
  const hrrIn = hist.hrr
    .filter(
      (e) =>
        e.daysAgo >= 0 &&
        e.daysAgo <= 59 &&
        ok(e.peakHr) &&
        ok(e.hr60) &&
        e.peakHr > e.hr60,
    )
    .sort((a, b) => a.daysAgo - b.daysAgo);
  // comparable = protocol with the most sessions in the window; tie -> protocol of the newest session
  const counts = new Map();
  hrrIn.forEach((e) =>
    counts.set(e.protocolId, (counts.get(e.protocolId) || 0) + 1),
  );
  let proto = null;
  for (const e of hrrIn)
    if (proto === null || counts.get(e.protocolId) > counts.get(proto))
      proto = e.protocolId;
  const hrr1 = hrrIn
    .filter((e) => e.protocolId === proto)
    .map((e) => e.peakHr - e.hr60);
  const r = (vals, f) => ({
    raw: vals.length ? f(vals) : undefined,
    valid: vals.length,
  });
  return {
    crf: { raw: crf.length ? crf[0].pct : undefined, valid: crf.length },
    rhr: r(rhr, median),
    mvpa: r(eq, (v) => mean(v) * 7),
    steps: r(steps, mean),
    // ---- END OF THE PART RECEIVED. The appendix was cut inside the next line, after
    // "popSd(nights.map((n) => relMin(n.wakeMin)))". From here on: completed in this repository. ----
    sleepRegularity: {
      raw: nights.length
        ? Math.sqrt(
            (popSd(nights.map((n) => relMin(n.bedMin))) ** 2 +
              popSd(nights.map((n) => relMin(n.wakeMin))) ** 2) /
              2,
          )
        : undefined,
      valid: nights.length,
    },
    sleepDuration: r(
      nights.map((n) => n.totalSleepMin),
      (v) => median(v) / 60,
    ),
    hrv: r(hrv, median),
    hrr: r(hrr1, median),
  };
}

// D3: halves up, with a tolerance for a float that landed a hair below .5
const roundHes = (observed) => Math.floor(observed + 0.5 + EPS);

function compute(profile, hist) {
  const agg = aggregate(hist);
  const weights = WEIGHTS_PM[profile];
  const components = {};
  let denominator = 0;
  let numerator = 0;
  let quality = 0;
  let coreComplete = true;
  for (const id of ORDER) {
    const [minimum, target] = COUNTS[id];
    const a = agg[id];
    const available = a.valid >= minimum && a.raw !== undefined;
    const q = Math.min(a.valid / target, 1);
    const score = available ? piecewise(CURVES[id], a.raw) : undefined;
    components[id] = {
      raw: available ? a.raw : undefined,
      valid: a.valid,
      available,
      quality: q,
      score,
      weightPm: weights[id],
    };
    if (available) {
      denominator += weights[id];
      numerator += weights[id] * score;
      quality += weights[id] * q;
    } else if (CORE.includes(id)) {
      coreComplete = false;
    }
  }
  const out = { profile, aggregates: agg, components, coveragePm: denominator };
  if (!coreComplete || denominator <= 0) {
    return Object.assign(out, {
      status: "INSUFFICIENT_DATA",
      tier: "NONE",
      confidence: "NOT_ENOUGH_DATA",
    });
  }
  const observed = numerator / denominator;
  const hes = roundHes(observed);
  const ci = quality / 1000; // coverage fraction x weighted quality
  const confidence =
    ci >= 0.8 - EPS ? "HIGH" : ci >= 0.6 - EPS ? "MEDIUM" : "LOW";
  const tier = hes >= 80 ? "A" : hes >= 60 ? "B" : "C";
  for (const id of ORDER) {
    if (components[id].available)
      components[id].effectiveWeight = weights[id] / denominator;
  }
  return Object.assign(out, {
    status: "OK",
    observed,
    hes,
    tier,
    ci,
    confidence,
  });
}

// ---- persona recipe (Appendix B): deterministic, no RNG ----
const pattern = (A, d, n) =>
  Array.from({ length: n }, (_, i) =>
    n % 2 === 1
      ? i === 0
        ? A
        : i % 2 === 1
          ? A - d
          : A + d
      : i % 2 === 0
        ? A - d
        : A + d,
  );
const wrap = (x) => ((x % 1440) + 1440) % 1440;
const at = (h, m) => h * 60 + m;
const D = { steps: 600, mvpa: 6, rhr: 2, sleepTotal: 18, hrv: 5 };
const WALK = "walk-3min";

// [days, steps A/n, mvpa A/n, rhr A/n, sleep n/bed/wake/shift/total, hrv A/n (A = null: no HRV), crf, hrr]
const PERSONAS = {
  ania: {
    days: 28,
    steps: [8800, 28],
    mvpa: [34, 28],
    rhr: [58, 28],
    sleep: [28, at(22, 45), at(6, 45), 45, 444],
    hrv: [60, 28],
    crf: [
      [120, 60],
      [70, 74],
      [12, 77],
    ],
    hrr: [
      [75, WALK, 150, 130],
      [45, WALK, 152, 122],
      [25, WALK, 154, 120],
      [4, WALK, 150, 118],
    ],
  },
  marek: {
    days: 28,
    steps: [6200, 28],
    mvpa: [17, 28],
    rhr: [68, 28],
    sleep: [28, at(23, 30), at(6, 50), 70, 396],
    hrv: [40, 28],
    crf: [],
    hrr: [
      [50, WALK, 140, 118],
      [30, WALK, 142, 116],
      [9, WALK, 141, 117],
    ],
  },
  kasia: {
    days: 28,
    steps: [6000, 20],
    mvpa: [14, 20],
    rhr: [72, 18],
    sleep: [16, at(23, 0), at(6, 30), 70, 384],
    hrv: [52, 4],
    crf: [],
    hrr: [],
  },
  tomek: {
    days: 28,
    steps: [7000, 28],
    mvpa: [21, 28],
    rhr: [62, 28],
    sleep: [28, at(0, 0), at(7, 0), 80, 390],
    hrv: [null, 0],
    crf: [
      [40, 48],
      [5, 50],
    ],
    hrr: [
      [55, WALK, 150, 125],
      [50, "interval-run", 178, 137],
      [33, WALK, 152, 123],
      [8, WALK, 151, 124],
    ],
  },
  ewa: {
    days: 28,
    steps: [4400, 20],
    mvpa: [10, 20],
    rhr: [76, 20],
    sleep: [16, at(23, 45), at(7, 15), 85, 372],
    hrv: [35, 3],
    crf: [],
    hrr: [
      [38, WALK, 135, 117],
      [6, WALK, 136, 114],
    ],
  },
  ola: {
    days: 16,
    steps: [6800, 16],
    mvpa: [16, 16],
    rhr: [68, 16],
    sleep: [6, at(23, 15), at(7, 0), 40, 420],
    hrv: [50, 6],
    crf: [],
    hrr: [],
  },
};

function history(spec) {
  const days = Array.from({ length: spec.days }, () => ({}));
  const put = (values, set) =>
    values.forEach((v, j) => set(days[spec.days - values.length + j], v, j));
  put(pattern(spec.steps[0], D.steps, spec.steps[1]), (d, v) => {
    d.steps = v;
  });
  put(pattern(spec.mvpa[0], D.mvpa, spec.mvpa[1]), (d, eq) => {
    d.vigorousMin = Math.floor(eq / 5);
    d.moderateMin = eq - 2 * d.vigorousMin;
  });
  put(pattern(spec.rhr[0], D.rhr, spec.rhr[1]), (d, v) => {
    d.restingHr = v;
  });
  const [n, bed, wake, shift, total] = spec.sleep;
  const totals = pattern(total, D.sleepTotal, n);
  put(pattern(0, shift, n), (d, s, j) => {
    d.sleep = {
      bedMin: wrap(bed + s),
      wakeMin: wrap(wake + s),
      totalSleepMin: totals[j],
    };
  });
  if (spec.hrv[0] !== null) {
    put(pattern(spec.hrv[0], D.hrv, spec.hrv[1]), (d, v) => {
      d.hrv = { percentile: v, protocol: HRV_PROTOCOL };
    });
  }
  return {
    days,
    crf: spec.crf.map(([daysAgo, pct]) => ({ daysAgo, pct })),
    hrr: spec.hrr.map(([daysAgo, protocolId, peakHr, hr60]) => ({
      daysAgo,
      protocolId,
      peakHr,
      hr60,
    })),
  };
}

// ---- output ----
const PROFILES = ["HEALTH_WELLNESS", "LONGEVITY_WELLNESS"];
const num = (x) => (x === undefined ? null : x);

function goldens() {
  const out = {};
  for (const id of Object.keys(PERSONAS)) {
    const hist = history(PERSONAS[id]);
    out[id] = {};
    for (const profile of PROFILES) {
      const r = compute(profile, hist);
      const components = {};
      for (const c of ORDER) {
        components[c] = {
          raw: num(r.components[c].raw),
          valid: r.components[c].valid,
          score: num(r.components[c].score),
          effectiveWeight: num(r.components[c].effectiveWeight),
        };
      }
      out[id][profile] = {
        status: r.status,
        hes: num(r.hes),
        observed: num(r.observed),
        tier: r.tier,
        coveragePm: r.coveragePm,
        confidence: r.confidence,
        ci: num(r.ci),
        components,
      };
    }
  }
  return out;
}

const pct = (pm) =>
  pm % 10 === 0 ? `${pm / 10}%` : `${Math.floor(pm / 10)}.${pm % 10}%`;

if (require.main === module) {
  const all = goldens();
  if (process.argv.includes("--json")) {
    process.stdout.write(JSON.stringify(all, null, 2) + "\n");
  } else {
    for (const id of Object.keys(all)) {
      const line = PROFILES.map((p) => {
        const r = all[id][p];
        return r.status === "OK"
          ? `${r.hes} ${r.tier} ${pct(r.coveragePm)} ${r.confidence} (observed ${r.observed.toFixed(3)}, CI ${r.ci.toFixed(3)})`
          : `no score ${pct(r.coveragePm)} ${r.confidence}`;
      }).join("  |  ");
      const raw = ORDER.map((c) => {
        const x = all[id].HEALTH_WELLNESS.components[c];
        return `${c} ${x.raw === null ? "-" : Math.round(x.raw * 1000) / 1000} (${x.valid})`;
      }).join(" · ");
      console.log(`${id.padEnd(6)} ${line}`);
      console.log(`       ${raw}`);
    }
  }
}

module.exports = { aggregate, compute, history, goldens, piecewise, PERSONAS };
