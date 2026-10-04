// Typed reads from parsed JSON. Every packet that arrives from outside goes through these:
// nothing is trusted to have the right shape.

export function parseJsonObject(text: string): Record<string, Object> | null {
  try {
    const parsed: Object | null = JSON.parse(text) as Object | null;
    if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
      return null;
    }
    return parsed as Record<string, Object>;
  } catch (e) {
    return null;
  }
}

export function readNumber(o: Record<string, Object>, key: string): number | null {
  const v: Object | undefined = o[key];
  if (typeof v !== 'number' || !Number.isFinite(v as number)) {
    return null;
  }
  return v as number;
}

export function readInt(o: Record<string, Object>, key: string): number | null {
  const v = readNumber(o, key);
  if (v === null || !Number.isInteger(v)) {
    return null;
  }
  return v;
}

export function readString(o: Record<string, Object>, key: string): string | null {
  const v: Object | undefined = o[key];
  if (typeof v !== 'string') {
    return null;
  }
  return v as string;
}

export function readBoolean(o: Record<string, Object>, key: string): boolean | null {
  const v: Object | undefined = o[key];
  if (typeof v !== 'boolean') {
    return null;
  }
  return v as boolean;
}

export function readArray(o: Record<string, Object>, key: string): Object[] | null {
  const v: Object | undefined = o[key];
  if (v === undefined || v === null || !Array.isArray(v)) {
    return null;
  }
  return v as Object[];
}

export function asObject(v: Object): Record<string, Object> | null {
  if (v === undefined || v === null || typeof v !== 'object' || Array.isArray(v)) {
    return null;
  }
  return v as Record<string, Object>;
}

// An array of integers, each within [min, max]; null when anything else is in it.
export function readIntArray(o: Record<string, Object>, key: string, min: number, max: number): number[] | null {
  const raw = readArray(o, key);
  if (raw === null) {
    return null;
  }
  const out: number[] = [];
  for (let i = 0; i < raw.length; i++) {
    const v: Object = raw[i];
    if (typeof v !== 'number' || !Number.isInteger(v as number)) {
      return null;
    }
    const n = v as number;
    if (n < min || n > max) {
      return null;
    }
    out.push(n);
  }
  return out;
}
