# Visit transcription server (self-hosted, English)

`POST /v1/transcribe` takes the watch's recording format (raw 16 kHz mono S16LE PCM, 1 s to 15 min) and returns
`{ v, language: "en", speakersGuessed: true, segments: [{ id, speaker, startSec, text }] }`, the
`TranscriptSegment` shape the phone's rule-based notes extractor reads.

- Speech-to-text runs on our own server: whisper.cpp with `ggml-small.en-tdrz` (English, tinydiarize speaker turns).
  No third-party speech API.
- The audio exists only as a tmpfs file while whisper runs and is deleted right after. Logs counts only.
- Speakers alternate at each detected turn, starting with the doctor. That is a guess, and it can drift when
  a turn is missed.
- Limits: 4 per hour per address, 40 a day, one at a time, 15 minutes of audio.
- Speed on the demo server (4 ARM Neoverse-N1 cores): about 1 minute per 2 minutes of audio.

Live at `https://fairwear-130-61-179-157.sslip.io/v1/transcribe` (`/asr/health`).

Test: `curl -X POST --data-binary @visit.pcm https://fairwear-130-61-179-157.sslip.io/v1/transcribe`

`sample-primock57-day1-c01-2min.json` is the server's real output for the first 2 minutes of consultation
`day1_consultation01` of PriMock57 (Papadopoulos Korfiatis et al., ACL 2022, Babylon Health, CC BY 4.0,
https://github.com/babylonhealth/primock57), with doctor and patient channels mixed to mono.
