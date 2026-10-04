// Node test runner for the HealthSim logic layer (same source files as the app, copied from .ets).
import { HsGenerator, DEMO_ANCHOR_MS, HR_PER_SPM } from '../src/HsGenerator';
import { HsPersonas, HsPersona } from '../src/HsPersonas';
import { HsCodec, base64Encode, base64Decode } from '../src/HsCodec';
import { HsSimStore } from '../src/HsStore';
import { HsSummary } from '../src/HsSummary';
import { HsDataType, HsEventKind, DAY_MS, SLOTS_PER_DAY, HsDataset, HsError } from '../src/HsTypes';

let failures = 0;
let passes = 0;
function check(name: string, ok: boolean, detail: string = ''): void {
  if (ok) { passes++; console.log('PASS ' + name + (detail ? '  (' + detail + ')' : '')); }
  else { failures++; console.log('FAIL ' + name + (detail ? '  (' + detail + ')' : '')); }
}

const personas = HsPersonas.all();
const gen = (p: HsPersona, seed = 42, days = 30, anchor = DEMO_ANCHOR_MS): HsDataset =>
  HsGenerator.generate(p, seed, anchor, days);

// 1. Determinism
for (const p of personas) {
  const a = gen(p), b = gen(p);
  check('deterministic ' + p.id, HsCodec.datasetId(a) === HsCodec.datasetId(b), HsCodec.datasetId(a));
}
check('seed changes data', HsCodec.datasetId(gen(personas[0], 42)) !== HsCodec.datasetId(gen(personas[0], 43)));

// 2. Calendar-day stability across window length
{
  const p = personas[1];
  const a = gen(p, 42, 30), b = gen(p, 42, 20);
  const off = (a.startMs - b.startMs) / (5 * 60000); // negative: a starts earlier
  let same = true;
  for (let i = 0; i < b.slotCount; i++) {
    if (a.steps[i - off] !== b.steps[i] || a.hrBpm[i - off] !== b.hrBpm[i]) { same = false; break; }
  }
  check('same calendar day, same data (30 vs 20 days)', same);
}

// 3. Shape and size
for (const p of personas) {
  const ds = gen(p);
  check('slot count ' + p.id, ds.slotCount === 30 * 288 + Math.floor(((DEMO_ANCHOR_MS - (ds.startMs + 30 * DAY_MS)) / 300000)), String(ds.slotCount));
  const payload = HsCodec.encode(ds, HsDataType.all(), false);
  const json = HsCodec.toJson(payload);
  check('payload < 90 KB ' + p.id, json.length < 90 * 1024, (json.length / 1024).toFixed(1) + ' KB');
}

// 4. HR rises with steps (honest personas), awake worn slots
function stats(ds: HsDataset, rhrBase: number) {
  let n = 0, sx = 0, sy = 0, sxx = 0, syy = 0, sxy = 0;
  let walkSum = 0, walkN = 0;
  for (let i = 0; i < ds.slotCount; i++) {
    const t = ds.truth[Math.floor(i / 288)];
    if (t.sick || t.removal) continue;
    const s = ds.steps[i], h = ds.hrBpm[i];
    if (h === 0 || s === 0) continue;
    const x = s / 5, y = h;
    n++; sx += x; sy += y; sxx += x * x; syy += y * y; sxy += x * y;
    if (s >= 300) { walkSum += h; walkN++; }
  }
  const corr = (n * sxy - sx * sy) / Math.sqrt((n * sxx - sx * sx) * (n * syy - sy * sy));
  return { corr, walkMean: walkSum / Math.max(1, walkN), walkN };
}
for (const id of ['ania', 'kasia', 'marek']) {
  const p = HsPersonas.byId(id);
  const st = stats(gen(p), p.restingHrBase);
  check('HR~steps correlation ' + id, st.corr > 0.5, 'r=' + st.corr.toFixed(2));
  check('walking HR >= rhr+20 ' + id, st.walkMean >= p.restingHrBase + 20, 'walk mean ' + st.walkMean.toFixed(1) + ' vs rhr ' + p.restingHrBase + ', n=' + st.walkN);
}

// 5. Wei padding: steps >= 300 with HR near sitting baseline
{
  const p = HsPersonas.byId('wei');
  const ds = gen(p);
  let padded = 0;
  for (const t of ds.truth) padded += t.paddedSlots;
  check('wei padded slots ~6/day', padded >= 6 * 28, String(padded));
  // honest walking slots for Wei still rise
  let lowHrHighSteps = 0;
  for (let i = 0; i < ds.slotCount; i++) {
    if (ds.steps[i] >= 300 && ds.hrBpm[i] > 0 && ds.hrBpm[i] <= p.restingHrBase + 20 + 2) lowHrHighSteps++;
  }
  check('wei has high-step/low-HR slots', lowHrHighSteps >= padded * 0.8, String(lowHrHighSteps));
  for (const id of ['ania', 'kasia']) {
    const q = HsPersonas.byId(id);
    const d2 = gen(q);
    let c = 0;
    for (let i = 0; i < d2.slotCount; i++) {
      if (d2.steps[i] >= 300 && d2.hrBpm[i] > 0 && d2.hrBpm[i] <= q.restingHrBase + 18 + 3) c++;
    }
    check('honest ' + id + ' rarely looks padded', c <= 15, String(c));
  }
}

// 6. Sick episodes: >= 2 consecutive elevated RHR days; Marek removes the watch afterwards
function rhrByDay(ds: HsDataset): number[] { return ds.truth.map(t => t.restingHr); }
for (const id of ['kasia', 'marek']) {
  const p = HsPersonas.byId(id);
  const ds = gen(p);
  const r = rhrByDay(ds);
  const sorted = r.filter(v => v > 0).slice().sort((a, b) => a - b);
  const median = sorted[Math.floor(sorted.length / 2)];
  for (const ep of p.sickEpisodes) {
    const d0 = 30 - ep.startDaysAgo;
    const elevated = [r[d0], r[d0 + 1]];
    check(id + ' episode ' + ep.startDaysAgo + 'd ago: 2 elevated days', elevated.every(v => v >= median + 5), 'rhr ' + elevated.join(',') + ' median ' + median);
  }
  if (id === 'marek') {
    const removal = ds.truth.filter(t => t.removal);
    check('marek removal days present', removal.length === 6, String(removal.length));
    check('marek removal days mostly off', removal.every(t => t.wornMinutes <= 360), removal.map(t => t.wornMinutes).join(','));
    check('marek removal days have no RHR', removal.every(t => t.restingHr === 0));
  } else {
    const sick = ds.truth.filter(t => t.sick);
    check('kasia keeps wearing when sick', sick.every(t => t.wornMinutes >= 17 * 60), sick.map(t => t.wornMinutes).join(','));
  }
}

// 7. Wear hours vs persona knob
for (const p of personas) {
  const ds = gen(p);
  const full = ds.truth.filter(t => !t.partial && !t.removal);
  const avgH = full.reduce((a, t) => a + t.wornMinutes, 0) / full.length / 60;
  check('wear hours ' + p.id, Math.abs(avgH - p.wearHoursMean) < 2.2, avgH.toFixed(1) + 'h vs ' + p.wearHoursMean);
  const avgSteps = full.reduce((a, t) => a + t.stepsTotal - t.paddedSlots * 370, 0) / full.length;
  check('steps level ' + p.id, avgSteps > p.stepsMean * 0.6 && avgSteps < p.stepsMean * 1.2, Math.round(avgSteps) + ' vs ' + p.stepsMean);
}
{
  const k = gen(HsPersonas.byId('kasia')).truth.filter(t => !t.partial);
  const m = gen(HsPersonas.byId('marek')).truth.filter(t => !t.partial);
  const kh = k.reduce((a, t) => a + t.wornMinutes, 0) / k.length / 60;
  const mh = m.reduce((a, t) => a + t.wornMinutes, 0) / m.length / 60;
  check('kasia and marek wear about equally', Math.abs(kh - mh) < 1.5, kh.toFixed(1) + 'h vs ' + mh.toFixed(1) + 'h');
}

// 8. Codec round trip and store reads
for (const p of personas) {
  const ds = gen(p);
  const json = HsCodec.toJson(HsCodec.encode(ds, HsDataType.all(), false));
  const back = HsCodec.decode(HsCodec.fromJson(json));
  check('round trip id ' + p.id, HsCodec.datasetId(back) === HsCodec.datasetId(ds));
  const store = HsSimStore.fromPayloadJson(json);
  const hr = store.readSync(HsDataType.HEART_RATE, ds.startMs, ds.anchorMs + 1);
  let hrN = 0; for (let i = 0; i < ds.slotCount; i++) if (ds.hrBpm[i] > 0) hrN++;
  check('store HR count ' + p.id, hr.length === hrN, hr.length + '/' + hrN);
  const sleep = store.readSync(HsDataType.SLEEP_FRAGMENT, ds.startMs, ds.anchorMs + 1);
  const sleepN = ds.events.filter(e => e.kind === HsEventKind.SLEEP).length;
  check('store sleep count ' + p.id, sleep.length === sleepN, sleep.length + '/' + sleepN);
  let sorted = true;
  for (let i = 1; i < hr.length; i++) if (hr[i].startTime < hr[i - 1].startTime) sorted = false;
  check('HR sorted, instants ' + p.id, sorted && hr.every(s => s.startTime === s.endTime));
  const spo2 = store.readSync(HsDataType.SPO2, ds.startMs, ds.anchorMs + 1);
  let overlap = false;
  for (let i = 1; i < spo2.length; i++) if (spo2[i].startTime <= spo2[i - 1].endTime && spo2[i].startTime === spo2[i - 1].startTime) overlap = true;
  check('SpO2 in (0,100], no overlap ' + p.id, !overlap && spo2.every(s => (s.fields.spo2 as number) > 0 && (s.fields.spo2 as number) <= 100));
}

// 9. Grants and sync delay
async function asyncChecks(): Promise<void> {
  const ds = gen(personas[0]);
  const json = HsCodec.toJson(HsCodec.encode(ds, [HsDataType.STEPS, HsDataType.SLEEP_FRAGMENT], true));
  const store = HsSimStore.fromPayloadJson(json);
  let code = 0;
  try { await store.readData({ samplePointDataType: HsDataType.HEART_RATE, startTime: ds.startMs, endTime: ds.anchorMs }); }
  catch (e) { code = (e as HsError).code; }
  check('ungranted type rejects with 201', code === 201, String(code));
  const steps = await store.readData({ samplePointDataType: HsDataType.STEPS, startTime: ds.startMs, endTime: ds.anchorMs + 1 });
  check('sync delay hides recent steps', steps.every(s => s.endTime <= store.lastSyncTime(HsDataType.STEPS)), 'last sync ' + new Date(store.lastSyncTime(HsDataType.STEPS)).toISOString());
  const p2 = HsCodec.fromJson(json);
  check('ungranted sections empty', p2.heartRate === '' && p2.granted.length === 2);
  check('small payload when few grants', json.length < 40 * 1024, (json.length / 1024).toFixed(1) + ' KB');
}

// 10. base64
{
  let ok = true;
  for (let n = 0; n < 50; n++) {
    const b = new Uint8Array(n);
    for (let i = 0; i < n; i++) b[i] = (i * 37 + n) & 0xff;
    const enc = base64Encode(b);
    if (enc !== Buffer.from(b).toString('base64')) ok = false;
    const dec = base64Decode(enc);
    if (dec.length !== n || dec.some((v, i) => v !== b[i])) ok = false;
  }
  check('base64 matches Node and round-trips', ok);
}

// 11. Summary sanity
for (const p of personas) {
  const ds = gen(p);
  const t = HsSummary.today(ds);
  const rows = HsSummary.days(ds);
  check('summary ' + p.id, rows.length === 31 && t.hr24h.length === SLOTS_PER_DAY,
    `today ${t.dateLabel} ${t.timeLabel} steps ${t.stepsToday} rhr ${t.restingHr} sleep ${t.sleepMinutes}m (${t.sleepStartLabel}-${t.sleepEndLabel}) spo2 ${t.spo2Avg} vo2 ${t.vo2max} cov ${t.hrCoverageTodayPct}%`);
}

// Info: per-day table for Marek
{
  const rows = HsSummary.days(gen(HsPersonas.byId('marek')));
  console.log('\nmarek days (newest first): date steps rhr sleep cov flags');
  for (const r of rows.slice(0, 31)) {
    console.log(`  ${r.dateLabel} ${String(r.steps).padStart(6)} ${String(r.restingHr).padStart(3)} ${String(r.sleepMinutes).padStart(4)} ${String(r.hrCoveragePct).padStart(3)}% ${r.sick ? 'SICK ' : ''}${r.removal ? 'REMOVAL ' : ''}${r.charged ? 'chg' : ''}`);
  }
}

asyncChecks().then(() => {
  console.log(`\n${passes} passed, ${failures} failed (HR_PER_SPM=${HR_PER_SPM})`);
  process.exit(failures > 0 ? 1 : 0);
});
