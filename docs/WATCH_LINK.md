# Watch Link

On-wrist recorder → signed day packets → phone.

**The watch measures, the phone judges.** The watch records what its sensors saw and summarises it. Every verdict (compliant day, suspicious break, flag, tier) stays in the shared rule code on the phone. No rule is duplicated on the watch.

Status of this document: Phase 1 (data contract and pure logic in `common/src/main/ets/watchlink/`) is implemented and tested under Node. The watch module wiring, the transports, the relay and the phone import are described in the brief (`docs/briefs/WATCH_LINK_BRIEF.md`) and are not implemented yet.

## What leaves the watch

One signed day packet per day: about 1 KB, at most 3800 bytes. It holds a 288-character wear string, steps per hour, a few minute counts and the context of each off-wrist break. It never holds per-sample heart rate or raw sensor streams.

Retention on the watch: slot files for 3 days (`days/<date>.json`), packets until the phone acknowledges them (`outbox/<seq>.json`).

## Slot states

A day is 288 five-minute slots in local time.

| char | meaning                            |
| ---- | ---------------------------------- |
| `W`  | worn                               |
| `C`  | charging                           |
| `O`  | off-wrist, observed                |
| `U`  | unknown: the app was not observing |

**Fairness rule: `U` is never `O`.** An unobserved slot is never a break and never counts as worn. A slot observed for less than 150 s is `U`. Otherwise it takes the largest of charging, worn and off seconds; on a tie charging wins over worn, worn over off.

Time the recorder was not fed is not observed. Two ticks more than 5 real seconds apart leave the time between them as `U`. Nothing is extrapolated.

## Wear state

1. Charging → `C`.
2. Else the wear-detection sensor, when the watch has one and it has reported: 1 → `W`, 0 → `O`. `wearSource = SENSOR`.
3. Else the heart-rate signal: a valid reading (25–230 bpm; 0 is no reading) within the freshness window → `W`, otherwise `O`. `wearSource = HR_SIGNAL`.

Freshness is measured in real time, never in demo time: 60 s with the real clock, 3 s while the demo clock runs.

Until any sensor has reported there is no state at all, and the recorder is not fed (`U`).

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
| `clock`            | string      | `REAL`, or a demo label such as `DEMO_X300`                                                                                                                                    |
| `iat`              | int         | epoch seconds                                                                                                                                                                  |
| `sig`              | string      | ECDSA P-256 / SHA-256, ASN.1 DER, base64url                                                                                                                                    |

A break is a maximal run of `O` (never `C`, never `U`) longer than the break minimum from `defaults.ets` (`gapMinMinutes`, 120). It is reported in the packet of the day it **ends**; a break still running at the end of a day is carried into the next packet.

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

A pairing packet is checked for format, self-signature and the key-id rule, and pinned only after the user confirms the 8-hex code shown on both screens.

## Tests

`tools/run-logic-tests.sh common` runs `common/src/test/WatchLink.test.ets` with the other suites. The ports are implemented for the tests in `tools/logic-tests/node-ports.ts` (Node `crypto` and `fs`). These are logic tests under Node; they say nothing about a device or an emulator.

## Deviations from the brief

1. **The repository on this machine has no HES engine.** There is no `common/src/main/ets/hes/`, `HesSession`, `BreakRuleChecker`, `EngineFairWearService`, `ui/DayDial` or `ui/WatchModels` on any branch, and no 43 + 23 test suites. The branch was cut from `feature/health-addon` (28 common tests, 6 watch tests), which has the test runner and the watch sensor code. Phase 1 does not depend on the engine. The phone import (brief 4.2) does.
2. `TierClaim` here has `v, period, tier, eligible, nonce, issuedAt, kid`, not the field list in the brief. Not touched.
3. The break minimum is `DEFAULT_THRESHOLDS.gapMinMinutes` (120). "HR reading" for the break rule is taken as a worn 5-minute slot with at least one heart-rate sample, matching the 5-minute `Epoch` in `types.ets` and `minHrReadingsBeforeGap`.
4. `Hasher` has one more method, `keyId(pubB64)`, because the key-id rule hashes key bytes, not text.
5. `pub` is base64url (the encoding of the repo's `Bytes.ets` helpers), not padded base64. `b64urlDecode` accepts both.
6. The version check runs on `v` and `type` before the other fields are validated, so an unknown version reports `Unsupported version` and not `Invalid format`.
7. **Late days.** A packet whose seq was recorded as missing is accepted when it links to the neighbours the phone knows (`prev` equals the hash before it, and the packet after it names its hash). The brief only lists the gap; without this a dropped packet could never be delivered.
8. **Demo clock and dates.** Packets recorded on the demo clock carry simulated dates, which can lie in the future. The verifier takes a flag: a demo build accepts them (the future check is skipped, the order check is kept) and they stay labelled by `clock`; with the flag off they are rejected with `Demo clock not accepted`.
9. `WearStateMachine.hasSignal()` is added: before any sensor has reported, the recorder is not fed, so a missing permission or sensor gives `U`, never `O`.
10. `DayRecord` has `sealed` and `packed` flags, and `PacketSealer` (seq, prev, signature) lives in `common` so it is covered by the tests.
11. A break that reaches back past the start of the previous day's record reports `startMin = -1440`; its context then has no slots.
