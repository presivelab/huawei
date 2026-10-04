// What exactly gets signed. A fixed list of lines joined with '\n': no JSON canonicalisation.
// The packet hash is base64url(SHA-256(signing string)); the next packet's `prev` is this hash.
import { AckPacket, BreakContext, DayPacket, PairPacket } from './WatchLinkTypes';
import { Hasher } from './WatchLinkPorts';

export const DAY_SIGNING_TAG: string = 'FWDAY1';
export const PAIR_SIGNING_TAG: string = 'FWPAIR1';
export const ACK_SIGNING_TAG: string = 'FWACK2';

function breakLine(b: BreakContext): string {
  return `${b.startMin}:${b.endMin}:${b.hrSlots24hBefore}:${b.rhr24hBefore}:${b.steps24hBefore}`;
}

export function daySigningString(p: DayPacket): string {
  const breaks: string[] = [];
  for (let i = 0; i < p.breaks.length; i++) {
    breaks.push(breakLine(p.breaks[i]));
  }
  const lines: string[] = [
    DAY_SIGNING_TAG,
    p.kid,
    `${p.seq}`,
    p.prev,
    p.date,
    `${p.tzOffsetMin}`,
    p.slots,
    p.stepsByHour.join(','),
    `${p.hrRestEst}`,
    `${p.hrSlotCount}`,
    `${p.nightWornMin}`,
    `${p.nightChargingMin}`,
    breaks.join(';'),
    p.wearSource,
    p.clock,
    `${p.iat}`
  ];
  return lines.join('\n');
}

export function pairSigningString(p: PairPacket): string {
  const lines: string[] = [
    PAIR_SIGNING_TAG,
    p.kid,
    p.pub,
    p.alg,
    `${p.iat}`
  ];
  return lines.join('\n');
}

// The reason is free text from the phone; the codec refuses line breaks in it, so every field stays on its line.
export function ackSigningString(p: AckPacket): string {
  const lines: string[] = [
    ACK_SIGNING_TAG,
    p.phoneKid,
    p.phonePub,
    p.watchKid,
    `${p.seq}`,
    p.status,
    p.reason,
    p.ref,
    `${p.iat}`
  ];
  return lines.join('\n');
}

export function dayPacketHash(p: DayPacket, hasher: Hasher): Promise<string> {
  return hasher.sha256B64url(daySigningString(p));
}

export function pairPacketHash(p: PairPacket, hasher: Hasher): Promise<string> {
  return hasher.sha256B64url(pairSigningString(p));
}
