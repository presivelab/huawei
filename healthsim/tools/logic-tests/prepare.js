// Copies the pure-logic .ets files (no platform imports) to src/*.ts so Node can run them.
const fs = require('fs');
const path = require('path');
const from = path.join(__dirname, '..', '..', 'entry', 'src', 'main', 'ets', 'healthsim');
const to = path.join(__dirname, 'src');
fs.rmSync(to, { recursive: true, force: true });
fs.mkdirSync(to, { recursive: true });
for (const f of fs.readdirSync(from)) {
  if (!f.endsWith('.ets') || f === 'HealthSimClient.ets') continue;
  fs.copyFileSync(path.join(from, f), path.join(to, f.replace(/\.ets$/, '.ts')));
}
console.log('copied logic files to src/');
