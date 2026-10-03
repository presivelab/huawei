/*
 * UTF-8, base64url and hex helpers with no system-kit dependency.
 */

const B64URL: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

export function utf8Encode(text: string): Uint8Array {
  const out: number[] = [];
  let i = 0;
  while (i < text.length) {
    const cp = text.codePointAt(i);
    const c: number = cp === undefined ? 0 : cp;
    i += c > 0xFFFF ? 2 : 1;
    if (c < 0x80) {
      out.push(c);
    } else if (c < 0x800) {
      out.push(0xC0 | (c >> 6), 0x80 | (c & 0x3F));
    } else if (c < 0x10000) {
      out.push(0xE0 | (c >> 12), 0x80 | ((c >> 6) & 0x3F), 0x80 | (c & 0x3F));
    } else {
      out.push(0xF0 | (c >> 18), 0x80 | ((c >> 12) & 0x3F), 0x80 | ((c >> 6) & 0x3F), 0x80 | (c & 0x3F));
    }
  }
  return new Uint8Array(out);
}

export function utf8Decode(bytes: Uint8Array): string {
  let out = '';
  let i = 0;
  while (i < bytes.length) {
    const b0 = bytes[i];
    let cp = 0xFFFD;
    let len = 1;
    if (b0 < 0x80) {
      cp = b0;
    } else if ((b0 & 0xE0) === 0xC0 && i + 1 < bytes.length) {
      cp = ((b0 & 0x1F) << 6) | (bytes[i + 1] & 0x3F);
      len = 2;
    } else if ((b0 & 0xF0) === 0xE0 && i + 2 < bytes.length) {
      cp = ((b0 & 0x0F) << 12) | ((bytes[i + 1] & 0x3F) << 6) | (bytes[i + 2] & 0x3F);
      len = 3;
    } else if ((b0 & 0xF8) === 0xF0 && i + 3 < bytes.length) {
      cp = ((b0 & 0x07) << 18) | ((bytes[i + 1] & 0x3F) << 12) | ((bytes[i + 2] & 0x3F) << 6) | (bytes[i + 3] & 0x3F);
      len = 4;
    }
    out += String.fromCodePoint(cp);
    i += len;
  }
  return out;
}

export function b64urlEncode(bytes: Uint8Array): string {
  let out = '';
  let i = 0;
  while (i + 2 < bytes.length) {
    const n = (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2];
    out += B64URL.charAt((n >> 18) & 63) + B64URL.charAt((n >> 12) & 63) +
      B64URL.charAt((n >> 6) & 63) + B64URL.charAt(n & 63);
    i += 3;
  }
  const rest = bytes.length - i;
  if (rest === 1) {
    const n = bytes[i] << 16;
    out += B64URL.charAt((n >> 18) & 63) + B64URL.charAt((n >> 12) & 63);
  } else if (rest === 2) {
    const n = (bytes[i] << 16) | (bytes[i + 1] << 8);
    out += B64URL.charAt((n >> 18) & 63) + B64URL.charAt((n >> 12) & 63) + B64URL.charAt((n >> 6) & 63);
  }
  return out;
}

/** Throws on illegal characters. Also accepts '+', '/' and '=' (plain base64). */
export function b64urlDecode(text: string): Uint8Array {
  const clean = text.trim().replace(new RegExp('=+$'), '');
  const out: number[] = [];
  let buffer = 0;
  let bits = 0;
  for (let i = 0; i < clean.length; i++) {
    const ch = clean.charAt(i);
    let v = B64URL.indexOf(ch);
    if (ch === '+') {
      v = 62;
    } else if (ch === '/') {
      v = 63;
    }
    if (v < 0) {
      throw new Error(`Illegal base64url character at position ${i}`);
    }
    buffer = (buffer << 6) | v;
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      out.push((buffer >> bits) & 0xFF);
    }
  }
  if (clean.length % 4 === 1) {
    throw new Error('Invalid base64url length');
  }
  return new Uint8Array(out);
}

export function toHex(bytes: Uint8Array): string {
  let out = '';
  for (let i = 0; i < bytes.length; i++) {
    const h = bytes[i].toString(16);
    out += h.length === 1 ? `0${h}` : h;
  }
  return out;
}
