# Month note server

One Node file, no dependencies. It takes the month-note summary from the phone (`common/src/main/ets/report/MonthNote.ets`),
checks it against a fixed schema, asks Gemini 2.5 Flash on Google Vertex AI for a few sentences and returns `{ "text": ... }`.

- The model key stays on the server (`VERTEX_API_KEY`, a Vertex AI express-mode key). It is never in the app or this repository.
- Limits: `FAIRWEAR_IP_LIMIT` notes per 10 minutes per address (5), `FAIRWEAR_DAILY_CAP` per day (300), 300 output tokens, 4 KB requests.
- Logs counts only, never a summary or a note.

Run locally: `VERTEX_API_KEY=... node tools/report-server/server.mjs`, then `POST http://localhost:8791/v1/report`.

Deployed for the demo as a hardened container (`node:22-alpine`, read-only, no capabilities, 128 MB) behind Caddy at
`https://fairwear-130-61-179-157.sslip.io` (`/v1/report`, `/health`).
