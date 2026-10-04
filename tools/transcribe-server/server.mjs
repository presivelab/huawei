// FairWear visit transcription: raw 16 kHz mono S16LE PCM in (the watch's recording format), English
// transcript segments out. Runs whisper.cpp (small.en + tinydiarize) on our own server: no third-party API.
// The audio lives in a tmpfs file only while whisper runs and is deleted right after. Logs counts only.
import http from 'node:http';
import { spawn } from 'node:child_process';
import { writeFileSync, unlinkSync } from 'node:fs';
import { randomUUID } from 'node:crypto';

const PORT = 8792;
const MODEL = process.env.FAIRWEAR_ASR_MODEL || '/models/ggml-small.en-tdrz.bin';
const MAX_BYTES = 16000 * 2 * 60 * 15;            // 15 minutes
const DAILY_CAP = Number(process.env.FAIRWEAR_ASR_DAILY_CAP || 40);
const IP_LIMIT = Number(process.env.FAIRWEAR_ASR_IP_LIMIT || 4);   // per hour
let day = ''; let usedToday = 0; let busy = false;
const perIp = new Map();
const stats = { ok: 0, rejected: 0, limited: 0, failed: 0 };

function wav(pcm) {
  const h = Buffer.alloc(44);
  h.write('RIFF', 0); h.writeUInt32LE(36 + pcm.length, 4); h.write('WAVE', 8); h.write('fmt ', 12);
  h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22); h.writeUInt32LE(16000, 24);
  h.writeUInt32LE(32000, 28); h.writeUInt16LE(2, 32); h.writeUInt16LE(16, 34); h.write('data', 36);
  h.writeUInt32LE(pcm.length, 40);
  return Buffer.concat([h, pcm]);
}

// "[00:01:26.880 --> 00:01:30.640]   text [SPEAKER_TURN]" -> segments; speakers alternate at each turn,
// starting with the doctor (the doctor opens the visit). Speaker labels are a guess and say so.
function segmentsOf(out) {
  const segs = []; let speaker = 'DOCTOR'; let n = 0;
  for (const line of out.split('\n')) {
    const m = line.match(/^\[(\d+):(\d+):(\d+)\.(\d+) --> [^\]]+\]\s+(.*)$/);
    if (!m) continue;
    let text = m[5]; const turn = text.includes('[SPEAKER_TURN]');
    text = text.replace(/\[SPEAKER_TURN\]/g, '').replace(/\s+/g, ' ').trim();
    if (text.length > 0 && !/^\[.*\]$/.test(text)) {
      n++;
      segs.push({ id: `s${String(n).padStart(3, '0')}`, speaker,
        startSec: Number(m[1]) * 3600 + Number(m[2]) * 60 + Number(m[3]), text: text.slice(0, 600) });
    }
    if (turn) speaker = speaker === 'DOCTOR' ? 'PATIENT' : 'DOCTOR';
  }
  return segs;
}

function whisper(file) {
  return new Promise((resolve, reject) => {
    const p = spawn('whisper-cli', ['-m', MODEL, '-tdrz', '-t', '4', '-l', 'en', '-np', '-f', file]);
    let out = '';
    p.stdout.on('data', d => { out += d; });
    p.on('error', reject);
    p.on('close', code => code === 0 ? resolve(out) : reject(new Error(`whisper ${code}`)));
    setTimeout(() => p.kill('SIGKILL'), 15 * 60 * 1000).unref();
  });
}

function allowed(ip) {
  const now = Date.now(); const today = new Date().toISOString().slice(0, 10);
  if (today !== day) { day = today; usedToday = 0; perIp.clear(); }
  if (usedToday >= DAILY_CAP) return false;
  const hits = (perIp.get(ip) || []).filter(t => now - t < 3600 * 1000);
  if (hits.length >= IP_LIMIT) { perIp.set(ip, hits); return false; }
  hits.push(now); perIp.set(ip, hits); usedToday++; return true;
}

function send(res, code, body) {
  res.writeHead(code, { 'content-type': 'application/json', 'cache-control': 'no-store' });
  res.end(JSON.stringify(body));
}

http.createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/asr/health') return send(res, 200, { ok: true, usedToday, cap: DAILY_CAP, busy });
  if (req.method !== 'POST' || req.url !== '/v1/transcribe') return send(res, 404, { error: 'not_found' });
  const chunks = []; let size = 0; let tooBig = false;
  req.on('data', c => { size += c.length; if (size > MAX_BYTES) { tooBig = true; req.destroy(); } else chunks.push(c); });
  req.on('end', async () => {
    const pcm = Buffer.concat(chunks);
    if (tooBig || pcm.length < 32000 || pcm.length % 2 !== 0) { stats.rejected++; return send(res, 400, { error: 'bad_audio' }); }
    const ip = String(req.headers['x-forwarded-for'] || req.socket.remoteAddress || '').split(',')[0].trim();
    if (busy) { stats.limited++; return send(res, 503, { error: 'busy' }); }
    if (!allowed(ip)) { stats.limited++; return send(res, 429, { error: 'limit' }); }
    busy = true;
    const file = `/tmp/${randomUUID()}.wav`;
    try {
      writeFileSync(file, wav(pcm));
      const segments = segmentsOf(await whisper(file));
      stats.ok++;
      send(res, 200, { v: 1, language: 'en', speakersGuessed: true, segments });
    } catch { stats.failed++; send(res, 502, { error: 'unavailable' }); }
    finally { try { unlinkSync(file); } catch {} busy = false; }
  });
}).listen(PORT, () => console.log(`fairwear-transcribe on ${PORT}, cap ${DAILY_CAP}/day, ${IP_LIMIT}/hour per IP`));
setInterval(() => console.log(`counts ${JSON.stringify(stats)} usedToday=${usedToday}`), 3600 * 1000).unref();
