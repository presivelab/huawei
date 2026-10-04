// FairWear report writer: turns a FairWear score summary into a short plain-language note with Gemini.
// The Gemini key stays on this server. Input is the score summary only (no raw health data, no name),
// checked against a fixed schema. Limits: per client IP, per day, output length. Nothing is logged but counts.
import http from 'node:http';

const PORT = 8791;
const KEY = process.env.VERTEX_API_KEY || '';   // Vertex AI express-mode key
const MODEL = process.env.FAIRWEAR_MODEL || 'gemini-2.5-flash';
const DAILY_CAP = Number(process.env.FAIRWEAR_DAILY_CAP || 300);
const IP_LIMIT = Number(process.env.FAIRWEAR_IP_LIMIT || 5);        // requests per IP window
const IP_WINDOW_MS = 10 * 60 * 1000;
const MAX_BODY = 4096;

const PROFILES = ['HEALTH_WELLNESS', 'LONGEVITY_WELLNESS'];
const TIERS = ['A', 'B', 'C', 'NONE'];
const CONFIDENCE = ['High', 'Medium', 'Low', 'Insufficient'];
const COMPONENTS = {
  steps: 'Daily steps', activeMinutes: 'Active minutes', restingHr: 'Resting heart rate', sleep: 'Sleep duration',
  sleepRegularity: 'Sleep timing regularity', vo2max: 'VO2max (fitness)', hrv: 'Heart-rate variability',
  hrRecovery: 'Heart-rate recovery'
};

let day = '';
let usedToday = 0;
const perIp = new Map();
const stats = { ok: 0, rejected: 0, limited: 0, failed: 0 };

function isInt(v, lo, hi) { return Number.isInteger(v) && v >= lo && v <= hi; }

// Exactly the fields below, nothing else. Returns the clean summary or null.
function clean(b) {
  if (!b || typeof b !== 'object' || Array.isArray(b)) return null;
  const keys = ['v', 'profile', 'tier', 'score', 'coveragePct', 'confidence', 'eligible', 'discountPct', 'components'];
  if (Object.keys(b).length !== keys.length || !keys.every(k => k in b)) return null;
  if (b.v !== 1 || !PROFILES.includes(b.profile) || !TIERS.includes(b.tier) || !CONFIDENCE.includes(b.confidence)) return null;
  if (!isInt(b.score, -1, 100) || !isInt(b.coveragePct, 0, 100) || !isInt(b.discountPct, 0, 100)) return null;
  if (typeof b.eligible !== 'boolean' || !Array.isArray(b.components) || b.components.length > 8) return null;
  const comps = [];
  for (const c of b.components) {
    if (!c || Object.keys(c).length !== 3 || !(c.id in COMPONENTS) || typeof c.available !== 'boolean'
      || !isInt(c.score, -1, 100)) return null;
    comps.push({ id: c.id, score: c.score, available: c.available });
  }
  return { profile: b.profile, tier: b.tier, score: b.score, coveragePct: b.coveragePct, confidence: b.confidence,
    eligible: b.eligible, discountPct: b.discountPct, components: comps };
}

function prompt(s) {
  const product = s.profile === 'LONGEVITY_WELLNESS' ? 'life insurance' : 'monthly health insurance';
  const lines = s.components.map(c => c.available
    ? `- ${COMPONENTS[c.id]}: ${c.score}/100` : `- ${COMPONENTS[c.id]}: not measured`).join('\n');
  const score = s.score >= 0 ? `${s.score}/100, tier ${s.tier}` : 'no score yet (not enough data)';
  return `You write a short monthly note for a person who uses FairWear, a wellness app that scores habits ` +
`measured by their watch for a ${product} discount programme.\n\n` +
`Their month: score ${score}; evidence coverage ${s.coveragePct}%; data confidence ${s.confidence}; ` +
`eligible for the discount: ${s.eligible ? 'yes' : 'no'}; discount ${s.discountPct}%.\nComponent scores:\n${lines}\n\n` +
`Write at most 110 words in plain English, second person, friendly and factual:\n` +
`1. one sentence on the overall picture;\n2. what is going well (highest scores);\n` +
`3. one or two concrete, everyday habits to improve the lowest measured scores.\n` +
`Rules: no diagnosis, no medical advice, no promises about prices or health outcomes, do not invent numbers, ` +
`treat "not measured" as missing (never as bad), no headings, no markdown.`;
}

async function gemini(text) {
  const url = `https://aiplatform.googleapis.com/v1/publishers/google/models/${MODEL}:generateContent`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-goog-api-key': KEY },
    body: JSON.stringify({
      contents: [{ role: 'user', parts: [{ text }] }],
      generationConfig: { temperature: 0.3, maxOutputTokens: 300, thinkingConfig: { thinkingBudget: 0 } }
    }),
    signal: AbortSignal.timeout(20000)
  });
  if (!res.ok) throw new Error(`gemini ${res.status}`);
  const data = await res.json();
  const out = data?.candidates?.[0]?.content?.parts?.map(p => p.text || '').join('').trim();
  if (!out) throw new Error('empty');
  return out.slice(0, 1200);
}

function send(res, code, body) {
  res.writeHead(code, { 'content-type': 'application/json', 'cache-control': 'no-store' });
  res.end(JSON.stringify(body));
}

function allowed(ip) {
  const now = Date.now();
  const today = new Date().toISOString().slice(0, 10);
  if (today !== day) { day = today; usedToday = 0; perIp.clear(); }
  if (usedToday >= DAILY_CAP) return false;
  const hits = (perIp.get(ip) || []).filter(t => now - t < IP_WINDOW_MS);
  if (hits.length >= IP_LIMIT) { perIp.set(ip, hits); return false; }
  hits.push(now); perIp.set(ip, hits); usedToday++;
  return true;
}

http.createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/health') return send(res, 200, { ok: true, usedToday, cap: DAILY_CAP });
  if (req.method !== 'POST' || req.url !== '/v1/report') return send(res, 404, { error: 'not_found' });
  let size = 0; const chunks = [];
  req.on('data', c => { size += c.length; if (size > MAX_BODY) { req.destroy(); } else chunks.push(c); });
  req.on('end', async () => {
    let summary = null;
    try { summary = clean(JSON.parse(Buffer.concat(chunks).toString('utf8'))); } catch { summary = null; }
    if (!summary) { stats.rejected++; return send(res, 400, { error: 'bad_request' }); }
    const ip = String(req.headers['x-forwarded-for'] || req.socket.remoteAddress || '').split(',')[0].trim();
    if (!allowed(ip)) { stats.limited++; return send(res, 429, { error: 'limit' }); }
    try { const text = await gemini(prompt(summary)); stats.ok++; send(res, 200, { text }); }
    catch { stats.failed++; send(res, 502, { error: 'unavailable' }); }
  });
}).listen(PORT, () => console.log(`fairwear-report on ${PORT}, cap ${DAILY_CAP}/day, ${IP_LIMIT}/10 min per IP`));

setInterval(() => console.log(`counts ${JSON.stringify(stats)} usedToday=${usedToday}`), 60 * 60 * 1000).unref();
