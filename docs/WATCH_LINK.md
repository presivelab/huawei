# Watch Link

On-wrist recorder → signed day packets → phone.

**The watch measures, the phone judges.** The watch records what its sensors saw and summarises it. Every verdict (compliant day, suspicious break, flag, tier) stays in the shared rule code on the phone. No rule is duplicated on the watch.

```
WATCH (wearable .hap)                                         PHONE (entry .hap)
LiveSensors (HR, steps, wear, charging)                       Receivers
  → WearStateMachine (real-time freshness)                      ├─ WearEngineReceiver (paired devices only)
  → SlotRecorder (288 × 5-min slots/day, files)                 └─ inbox/ scan (emulator relay)
  → DayBuilder (measurements, no verdicts)                    → DayPacketVerifier (format → key → sig → chain → date)
  → DayPacket signed with the WATCH key, hash-chained         → ChainLedger (seq/prev, gaps, duplicates)
  → outbox/ ─┬─ WearEngineTransport (paired devices only)     → WatchDayFacts (timeline) → rules / HES  [not wired, see Status]
             └─ files for the dev relay (emulator)            → Watch link card, Days from the watch
                         tools/watch-phone-relay.mjs (hdc) ────┘   ACK → back to the watch → the watch deletes the packet
```

Why the chain matters: detecting selective non-wear is pointless if a day can be removed on the way. Each day packet carries `seq` and the hash of the packet before it, signed by a key that never leaves the watch. A removed or edited day shows up as a gap or an invalid signature.

## Status

| Part                                                                  | State                                                                                                                                                                                                                                       |
| --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Data contract and logic (`common/src/main/ets/watchlink/`)            | Done. Tests under Node: `WatchLink.test.ets` 32, `WatchLinkFlow.test.ets` 8, `WatchLinkFeed.test.ets` 6, `DemoFeed.test.ets` 7, `LinkProbe.test.ets` 7, `WatchDayPresent.test.ets` 11, `TourContent.test.ets` 7, `TourSnippets.test.ets` 2. |
| Watch: recorder, signing, dial ring, controls, outbox                 | Done. Run on the wearable emulator (see "Checked on the emulators").                                                                                                                                                                        |
| Dev relay `tools/watch-phone-relay.mjs`                               | Done. Run between the two emulators, including `--tamper` and `--drop`.                                                                                                                                                                     |
| Phone: pairing, verification, chain, ACKs, Watch link card, days list | Done. Run on the phone emulator.                                                                                                                                                                                                            |
| Wear Engine transport (watch) and receiver (phone)                    | Send path present behind guards; the watch does not start a receiver for ACKs and does not resend its outbox. **Not run**: needs paired devices and Wear Engine approval for the app.                                                       |
| Import of watch days into HES                                         | **Not done, by decision.** Verified watch days are shown, not scored; HES-Lite (`common/src/main/ets/hes/`) runs on the persona histories. The seam is `PhoneLinkEngine.timeline()` (`WatchDayFacts[]`).                                    |
| "Ring fills green" with a simulated heart rate                        | **Not run**: the heart rate has to be set by hand in the emulator's Virtual sensor panel.                                                                                                                                                   |
| Dark mode of the phone cards                                          | Watch link cards and Verification details checked in dark mode (`docs/screenshots/design/after-watchlink-dark.jpeg`).                                                                                                                       |

## What leaves the watch

One signed day packet per day: about 0.8 KB on the emulator, at most 3800 bytes. It holds a 288-character wear string, steps per hour, a few minute counts and the context of each off-wrist break. It never holds per-sample heart rate or raw sensor streams.

Retention on the watch: slot files for 3 days (`days/<date>.json`), packets until the phone acknowledges them (`outbox/<seq>.json`, at most 30).

What leaves the phone is unchanged: only the signed tier claim.

## Slot states

A day is 288 five-minute slots in local time.

| char | meaning                            |
| ---- | ---------------------------------- |
| `W`  | worn                               |
| `C`  | charging                           |
| `O`  | off-wrist, observed                |
| `U`  | unknown: the app was not observing |

**Fairness rule: `U` is never `O`.** An unobserved slot is never a break and never counts as worn. A slot observed for less than 150 s is `U`. Otherwise it takes the largest of charging, worn and off seconds; on a tie charging wins over worn, worn over off.

Time the recorder was not fed is not observed. Two ticks more than 5 real seconds apart leave the time between them as `U`. Nothing is extrapolated. Until any sensor has reported, the recorder is not fed at all, so a missing permission or sensor gives `U`.

## Wear state

1. Charging → `C`.
2. Else the wear-detection sensor, when the watch has one and it has reported: 1 → `W`, 0 → `O`. `wearSource = SENSOR`.
3. Else the heart-rate signal: a valid reading (25–230 bpm; 0 is no reading) within the freshness window → `W`, otherwise `O`. `wearSource = HR_SIGNAL`.

Freshness is measured in real time, never in demo time: 60 s with the real clock, 3 s while the demo clock runs.

## Day packet

| field              | type        | notes                                                                                                                                                                          |
| ------------------ | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `v`                | int         | 1                                                                                                                                                                              |
| `type`             | string      | `DAY`                                                                                                                                                                          |
| `kid`              | string      | watch key id, 8 hex                                                                                                                                                            |
| `seq`              | int         | 1, 2, 3…                                                                                                                                                                       |
| `prev`             | string      | `GENESIS` for seq 1, else the hash of the previous packet                                                                                                                      |
| `date`             | string      | `YYYY-MM-DD`, local                                                                                                                                                            |
| `tzOffsetMin`      | int         | minutes east of UTC                                                                                                                                                            |
| `slots`            | string      | exactly 288 characters of `W` / `C` / `O` / `U`                                                                                                                                |
| `stepsByHour`      | int[24]     |                                                                                                                                                                                |
| `hrRestEst`        | int         | median of per-slot mean heart rate over `W` slots 07:00–23:00 with 0 steps; needs 6 such slots, else −1. Break context only. **Never used as the score's resting heart rate.** |
| `hrSlotCount`      | int         | `W` slots with at least one heart-rate sample                                                                                                                                  |
| `nightWornMin`     | int         | `W` slots 0–71 (00:00–06:00) × 5                                                                                                                                               |
| `nightChargingMin` | int         | `C` slots 0–71 × 5                                                                                                                                                             |
| `breaks`           | array, ≤ 12 | see below                                                                                                                                                                      |
| `wearSource`       | string      | `SENSOR` or `HR_SIGNAL`                                                                                                                                                        |
| `clock`            | string      | `REAL`, `DEMO_X300` (fast demo clock), `DEMO_X300_FEED` (fast demo clock with the scripted feed) or `DEMO_OFFSET` (real speed, shifted by earlier demo time)                   |
| `iat`              | int         | epoch seconds                                                                                                                                                                  |
| `sig`              | string      | ECDSA P-256 / SHA-256, ASN.1 DER, base64url                                                                                                                                    |

A break is a maximal run of `O` (never `C`, never `U`) of at least the break minimum from `defaults.ets` (`gapMinMinutes`, 120), the same limit the phone's break rule counts with. It is reported in the packet of the day it **ends**; a break still running at the end of a day is carried into the next packet.

| break field          | notes                                                                                           |
| -------------------- | ----------------------------------------------------------------------------------------------- |
| `startMin`, `endMin` | minutes from the packet day's 00:00; `startMin` is negative when the break began the day before |
| `hrSlots24hBefore`   | `W` slots with at least one heart-rate sample in the 24 h before the start                      |
| `rhr24hBefore`       | median of per-slot mean heart rate over `W`, zero-step slots in those 24 h; −1 if none          |
| `steps24hBefore`     | steps in those 24 h                                                                             |

These are inputs for the phone's break rule. The packet has no "suspicious", no "compliant", no tier.

## Signing string

No JSON canonicalisation. The signed message is these lines joined with `\n`:

```
FWDAY1
kid
seq
prev
date
tzOffsetMin
slots
stepsByHour joined with ','
hrRestEst
hrSlotCount
nightWornMin
nightChargingMin
breaks as startMin:endMin:hrSlots24hBefore:rhr24hBefore:steps24hBefore joined with ';'
wearSource
clock
iat
```

Packet hash = base64url(SHA-256(signing string)). The next packet's `prev` is this hash.

The pairing packet (`v`, `type = PAIR`, `kid`, `pub`, `alg = ECDSA_P256_SHA256`, `iat`, `sig`) is self-signed over `FWPAIR1`, `kid`, `pub`, `alg`, `iat`. `kid` is the first 4 bytes of SHA-256 over the public key as 8 hex characters, the same rule as the phone's `kid`.

The ACK packet (phone → watch): `v`, `type = ACK`, `seq`, `status` (`ACCEPTED`, `DUPLICATE`, `REJECTED`), `reason`. `seq = 0` answers the pairing request.

## Keys

The watch signs with its own key, alias `fairwear.watch.day.v1`, separate from the phone's claim key (`fairwear_claim_ecc_p256_v1`, unchanged). Both go through `ProofSigner`: HUKS first, a software key in app memory if HUKS fails. On the wearable emulator the key was created in HUKS.

## Verify order on the phone

| step | check                         | message                                                                                                                                                      |
| ---- | ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1    | decodes and validates         | `Invalid format`                                                                                                                                             |
| 2    | `v` and `type`                | `Unsupported version`                                                                                                                                        |
| 3    | `kid` is the pinned watch     | `Unknown watch key`                                                                                                                                          |
| 4    | ECDSA over the signing string | `Invalid signature`                                                                                                                                          |
| 5    | chain                         | `Duplicate day` (same seq, same hash; acknowledged again) · `Chain conflict` (same seq with another hash, or the next seq whose `prev` is not the last hash) |
| 6    | date                          | `Date in the future` · `Date out of order`                                                                                                                   |
| 7    |                               | `Accepted`, with the note `Missing N day(s)` when the packet skipped sequence numbers                                                                        |

A pairing packet is checked for format, self-signature and the key-id rule, and pinned only after the user confirms the 8-hex code shown on both screens. A second watch cannot replace a pinned one; `Forget watch` comes first.

A missing day appears in the days list as `#N · not received` with `No data received from watch (#N)`: zero worn minutes, no breaks.

## Files

Watch sandbox (`filesDir`, on the emulator `/data/storage/el2/base/files`): `days/<date>.json`, `outbox/<seq>.json`, `pair.json`, `acks/<seq>.json` (incoming), `state.json` (`kid`, `seq`, `lastHash`, `paired`), `clock.json` (recorder-clock offset).

Phone sandbox: `inbox/` (incoming, removed once processed), `acks/<seq>.json` (outgoing), `watchlink/ledger.json`, `watchlink/pending-pair.json`, `watchlink/days/<seq>.json`, `watchlink/log.json`.

## Dev relay

```
node tools/watch-phone-relay.mjs                 # once: watch -> phone, then phone ACKs -> watch
node tools/watch-phone-relay.mjs --watch         # repeat every 2 s
node tools/watch-phone-relay.mjs --dry-run       # print the hdc commands only
node tools/watch-phone-relay.mjs pull | push     # one side at a time
node tools/watch-phone-relay.mjs once --tamper   # demo only: one slots character changed -> "Invalid signature"
node tools/watch-phone-relay.mjs once --drop 3   # demo only: packet 3 held back -> "Missing 1 day(s)"
```

It needs debug builds started on both emulators (`tools/deploy.sh watch`, `tools/deploy.sh entry`): `hdc ... -b com.fairwear.app` reaches the sandbox of a debug app only. It finds `hdc` through `HDC`, `PATH` or DevEco Studio's default folder, and the two targets by device type (`WATCH_T` / `PHONE_T` override). It never deletes app data. Working copies go to `_relay/` (not in git). Runs on Node 18 and newer.

The phone app reads its inbox when it comes to the foreground, every 2 s while it stays there, and on `Sync now`.

## Demo script (about 60 s)

1. Watch, third page (swipe up twice): `Pair phone` → run the relay → the phone shows `Pair watch <code>?` with the code on the watch → `Confirm` → run the relay.
2. Watch, second page: `Demo clock ×300`. In the emulator menu → Virtual sensor set a heart rate: the ring fills green.
3. Set the heart rate to 0 for about 40 s (about 3 h of recorder time): the ring turns red, `not on wrist`. Set it back.
4. `Close day (demo)` → relay → phone: `Chain #1 ✓` and the day with `Source: FairWear watch · #1 · Signature valid` and the break with its context.
5. `Close day (demo)` again, relay with `--tamper` → phone log: `Invalid signature`, day not taken in. Relay again → `Accepted`.
6. Close two more days, relay with `--drop 3` → phone: `1 day missing`, `#3 · not received`. Relay again → the gap is filled.

**With the demo feed (no Virtual sensor panel).** Steps 2 to 4 become: watch, second page: `Demo clock ×300`, then `Demo feed: off` → `on`. The dial reads `DEMO ×300 · FEED · hh:mm`, heart rate and steps are scripted, and from 12:00 to 15:00 of recorder time (36 s) the ring turns red, `not on wrist`. The watch closes the day by itself at midnight of recorder time, 4 min 48 s after the previous one: `1 to sync` → relay → the phone shows the day with worn, charging and off-wrist time, steps and `Off wrist 12:05–15:00`. `Demo clock ×300` again stops the feed. Start from a fresh pair (see "Known limitations", stale ACK files) so the list holds feed days only. Tap `Close day (demo)` once right after switching the feed on: a feed started around midday gives a first day whose break has too little heart-rate context to be judged; full days always carry one judged break (12:10–14:55).

Line for the jury: "The watch measures, the phone judges with the same open rules, the partner sees only a signed tier. Every day is signed on the wrist and chained, so a day can't be quietly deleted or edited."

## Checked on the emulators (2026-10-04, agent-run, not yet confirmed by a team member)

Wearable emulator 127.0.0.1:5555 and phone emulator 127.0.0.1:5557, API 24, unsigned debug HAPs. Taps were sent with `uitest uiInput`. The `watchlink-NN` files named below were re-shot in the demo-feed run described in the next section; the values in this list are those of the first run.

- Watch: key `source=HUKS`; sensor ids without WEAR_DETECTION (280), so `HR_SIGNAL`; heart-rate events arrive with value 0, so the state is `not on wrist`.
- Watch: `Demo clock ×300` → the ring fills (red, because the emulator's heart rate is 0), label `DEMO ×300 · hh:mm` (`watchlink-03`).
- Watch: `Close day (demo)` → `outbox/1.json`, seq 1, `prev = GENESIS`, `clock = DEMO_X300`, 797 bytes, one break.
- Relay: pair + packet carried; before pairing the phone answered `#1 REJECTED (Unknown watch key)`.
- Phone: `Pair watch fd7c02b2?`, the code the watch shows (`watchlink-07`, `watchlink-09`); after `Confirm` and a relay run `#0 ACCEPTED (Paired)`, `#1 ACCEPTED`, `Chain #1 ✓`, source line, break with context (`watchlink-08`); watch `Synced ✓` (`watchlink-10`).
- `--tamper` → `#2 REJECTED (Invalid signature)`, then a clean run → `#2 ACCEPTED` (`watchlink-11`).
- `--drop 3` → `#4 ACCEPTED (Accepted · Missing 1 day(s))`, `1 day missing`, `#3 · not received` (`watchlink-12`); a clean run → `#3 ACCEPTED`.

Not run on the emulators: a non-zero heart rate (worn, green ring, the 60 s limit with the real clock), a denied permission with the new dial, `Reset watch data`, `Forget watch`, an app restart of either side, a real midnight.

## Checked on the emulators with the demo feed (2026-10-04 03:35–04:00 CEDT, agent-run, not yet confirmed by a team member)

Same two emulators, unsigned debug HAPs built in the `feature/watch-link-tour` worktree: watch from `b9ce4b2`; phone from `b9ce4b2` for pairing (`watchlink-05`, `-07`) and from `7213345` (the engine build) from `watchlink-11` on. `watchlink-08` was taken while another session was installing its own engine build on the shared phone emulator, so its build is one of the two; the Watch link code is the same in all of them. Taps with `uitest uiInput`, values read from the layout dump and from the packets in the watch outbox.

- Fresh start: `Forget watch` on the phone, `Reset watch data` on the watch, `Pair phone` → relay → `Pair watch fd7c02b2?` (`watchlink-07`) → `Confirm` → relay → `#0 ACCEPTED (Paired)` (`watchlink-05`, `watchlink-09`).
- Watch: `Demo clock ×300` and `Demo feed: on` (`watchlink-02`, `watchlink-03`); dial `worn` with a scripted heart rate (`watchlink-01`), `not on wrist` during the scripted break (`watchlink-15`), the ring with the red break stretch during the workout hour (`watchlink-16`).
- The watch sealed four days by itself, one every 4 min 48 s, without `Close day (demo)`: `1 to sync` (`watchlink-13`, `watchlink-04`), after the relay `Synced ✓` (`watchlink-10`). Every packet has `clock = DEMO_X300_FEED` and one break; packets 3 and 4 are 877 and 876 bytes.

| day       | seq | worn        | charging   | off wrist  | not observed | steps  | break       | heart-rate slots in the 24 h before |
| --------- | --- | ----------- | ---------- | ---------- | ------------ | ------ | ----------- | ----------------------------------- |
| Sun 4 Oct | 1   | 10 h 25 min | 1 h 5 min  | 2 h 45 min | 9 h 45 min   | 7,626  | 12:10–14:55 | 27                                  |
| Mon 5 Oct | 2   | 14 h 30 min | 6 h 35 min | 2 h 55 min | 0            | 12,068 | 12:05–15:00 | 171                                 |
| Tue 6 Oct | 3   | 14 h 40 min | 6 h 30 min | 2 h 50 min | 0            | 12,138 | 12:10–15:00 | 171                                 |
| Wed 7 Oct | 4   | 14 h 35 min | 6 h 30 min | 2 h 55 min | 0            | 12,119 | 12:05–15:00 | 172                                 |

- The first day starts at 09:45 because the recorder started then; the hours before are `not observed`. The scripted break is 12:00–15:00 (3 h); the watch records it as 2 h 45 min to 2 h 55 min, because the wear rule waits for the last heart rate to go stale and a slot takes its majority state. `WatchLinkFeed.test.ets` allows exactly this range.
- Phone, Evidence tab: day 1 `1 day verified` with worn, charging and off-wrist time, steps and `Off wrist 12:10–14:55` (`watchlink-08`); the full day 2 (`watchlink-17`).
- `--tamper` on packet 2 → `#2 REJECTED (Invalid signature)`, sync log `#2 · Invalid signature`, still one day (`watchlink-11`); a clean run → `#2 ACCEPTED`.
- `--drop 3` with packets 3 and 4 waiting → `#4 ACCEPTED (Accepted · Missing 1 day(s))`, `3 of 4 days verified`, `1 day never reached this phone`, a dashed `Missing` ring between Mon and Wed (`watchlink-12`); a clean run → `#3 ACCEPTED`, `All 4 days verified` (`watchlink-14`, `watchlink-18`).
- Tour (`How Watch Link works` on the Watch link card): step 1 draws the slot timeline of the newest received day, `Wed 7 Oct · wear source: heart-rate signal`, with the demo-feed label (`tour-01`); `Show the code` opens the code panel (`tour-02`). The three checks ran on the received days (`tour-03`): `Change five minutes of one day` → `Invalid signature · Not taken in`; `Send the same day again` → `Duplicate day · Acknowledged again, counted once`; `Hold a day back` → `Accepted · Missing 1 day(s)`, then `Accepted · Fills the gap`; each reported 2 ms and `Your stored days were not changed`. After the checks the card still read `All 4 days verified` and `watchlink/days/` still held `1.json` to `4.json`. The last two cards are in `tour-04`.

Not run: the tour in dark mode, the tour with no day received, the code panels of steps 2 to 6, `watchlink-06` (unchanged, the screen is the one in `watchlink-09`), Wear Engine on paired devices, a real heart rate.

Seen during the run, not changed: on the watch's second page the title and the `Phone: #N` line sit at y = 24 and y = 449 of 466 when the demo feed is on, which a round screen cuts (`watchlink-04`).

## Known limitations

- **Old ACKs after `Forget watch`: fixed, in two places.** Until the audit fixes `PhoneLinkEngine.forget()` left `acks/<seq>.json` behind, and the dev relay carried those files to a watch that was reset and paired again: the watch marked itself paired before the phone confirmed. `forget()` now removes the phone's ACK files, and the relay drops its own kept copy (`_relay/phone/acks/<seq>.json`) when it pushes a new pairing request or a packet the phone has not seen. Checked on the emulators after the change: reset the watch, `Forget watch` twice, `Pair phone`, relay → `no new ACK`; `Confirm` on the phone, relay → `#0 ACCEPTED (Paired)`; `Close day (demo)`, relay → `#1 ACCEPTED`. Before the relay change the same sequence printed `#0 ACCEPTED (Paired)` before `Confirm`. Wear Engine sends ACKs as messages, so this concerns the relay only.
- **The phone can read a relayed file while it is still arriving.** The phone looks into `inbox/` every 2 s and removes what it reads; `hdc file send` creates the file before its content is there. A file read in that moment is answered `REJECTED (Invalid format)` although nothing is wrong with it. Seen 3 times in about 12 sends on 2026-10-04 (once on a day packet, twice on a pairing request); the same day packet sent again was accepted. **Fixed in the app** (`SettleGate.ets`, used by `PhoneLinkEngine.scanInbox()` and by `WatchLinkEngine.processAcks()` for incoming ACK files): a file that is empty or not a JSON object is left where it is for the next look, and is answered only when the next look finds the very same text. A file that really is broken still gets `Invalid format`, one look (2 s) later; `--tamper` is not affected, because a tampered packet is whole JSON. Checked on the emulators after the change: the same pairing request sent 13 times and the same day packet sent 12 times with `hdc file send`, no `Invalid format` in the sync log (`Pairing request received` each time; `Accepted` once, then `Duplicate day`). Four flow tests cover it. `hdc shell -b … mv` is not permitted in the app sandbox, so the relay cannot deliver under a temporary name. Wear Engine delivers whole messages, so this concerns the relay only.

- The watch records **while the app is open**. No continuous task is requested: none of the continuous-task types (data transfer, audio, location, Bluetooth, multi-device…) matches health logging, and the system suspends apps whose task type does not match what they do. Time in the background is `U`. In the product the full-day history comes from HUAWEI Health; the watch app adds signed wear evidence while it runs.
- The demo clock shifts recorder time for good. After any demo time the recorder runs on `DEMO_OFFSET` and its packets are labelled as simulated time. `Reset watch data` returns to the real clock and starts a new chain; the phone then has to `Forget watch` and pair again.
- Time zone: the offset of the device at app start is used for the whole run; a change of offset (travel, daylight saving) during a run is not handled.
- If HUKS fails and the software key is used, the key lives in app memory: a restart creates a new key and a new chain.
- Days are listed under Evidence › Watch days in packet order; they are not placed on the persona's Evidence calendar.

## Deviations from the brief

1. **(Written on the Watch Link branch, before HES-Lite was rebuilt.)** **This checkout has no HES engine.** There is no `common/src/main/ets/hes/`, `HesSession`, `BreakRuleChecker`, `EngineFairWearService`, `ui/DayDial` or `ui/WatchModels` on any branch, and no 43 + 23 test suites. The branch was cut from `feature/health-addon` (28 common tests, 6 watch tests). Consequence: brief 4.2 "Import" stops at `WatchDayFacts`; nothing is appended to a score, no persona result can change, and "persona results identical to the report" could not be checked here.
2. `TierClaim` here has `v, period, tier, eligible, nonce, issuedAt, kid`, not the field list in the brief. Not touched.
3. Name mapping: `SensorHub` → the existing `LiveSensors` (extended); `InboxScanner` → `PhoneLinkEngine.scanInbox()`; `DayImporter` → `factsOfPacket` / `timeline()`; `OutboxTransport` → the outbox write inside `WatchLinkEngine`; `DemoClock` → `RecorderClock`; `WatchLinkService` keeps its name. The watch and phone logic sits in `common` (`WatchLinkEngine`, `PhoneLinkEngine`) so it runs in the Node tests; the modules hold only platform glue.
4. `ProofSigner`, `CryptoUtil` and `Bytes` moved from `entry/platform` to `common/platform` so the watch can use them; `entry/platform/*` re-export them. `ProofSigner.forAlias(alias)` was added; `ProofSigner.shared()`, the phone's alias and its behaviour are unchanged.
5. The break minimum is `DEFAULT_THRESHOLDS.gapMinMinutes` (120). "HR reading" for the break rule is taken as a worn 5-minute slot with at least one heart-rate sample, matching the 5-minute `Epoch` in `types.ets` and `minHrReadingsBeforeGap`.
6. `Hasher` has one more method, `keyId(pubB64)`, because the key-id rule hashes key bytes, not text.
7. `pub` is base64url (the encoding of the repo's `Bytes.ets` helpers), not padded base64. `b64urlDecode` accepts both.
8. The version check runs on `v` and `type` before the other fields are checked, so an unknown version reports `Unsupported version` and not `Invalid format`.
9. **Late days.** A packet whose seq was recorded as missing is accepted when it links to the neighbours the phone knows. The brief only lists the gap; without this a held-back packet could never be delivered, and the watch keeps it in its outbox until it is acknowledged.
10. **Demo clock and dates.** Packets recorded on the demo clock carry simulated dates, which can lie in the future. The verifier takes a flag: this demo build accepts them (the future check is skipped, the order check is kept) and they stay labelled by `clock`; with the flag off they are rejected with `Demo clock not accepted`.
11. `WearStateMachine.hasSignal()` is added: before any sensor has reported, the recorder is not fed.
12. A rejected packet stays in the watch's outbox (the copy the phone saw may have been damaged on the way); only `ACCEPTED` and `DUPLICATE` remove it.
13. The pinned watch and the ledger are stored as files in the phone sandbox (`watchlink/ledger.json`), not in Preferences `watchlink`: one storage port for everything, covered by the tests.
14. Watch pages are stacked vertically (dial, demo page, phone page) and do not scroll: on a watch a swipe to the right leaves the app. The dial keeps the existing centre (heart rate, steps, wear state); the three-line note under it gave way to the status line.
15. (Watch Link branch, before the Evidence calendar existed.) The phone has no calendar here, so "calendar day details" is the card `Days from the watch`. `resetDemo()` does not exist here; nothing removes received days except `Forget watch`.
16. The relay runs on Node 18 and newer (the brief says 22), because DevEco Studio bundles Node 18.
17. A break that reaches back past the start of the previous day's record reports `startMin = -1440`; its context then has no slots.
18. `local.json` for Wear Engine also exists on the phone side (`entry/src/main/resources/rawfile/local.json`, the watch app's fingerprint); both are ignored by git, the `local.example.json` files are committed.
