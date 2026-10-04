// Files carried by the dev relay can be seen while they are still being written: empty, or cut in the
// middle. Pure logic.
//
// Such a file is left for one more look. Only when the next look finds the very same text is it handed
// on, so a file that really is broken still gets its answer ("Invalid format") one look later, and a file
// that was only half written is read whole.
import { parseJsonObject } from './JsonRead';

export class SettleGate {
  private seen: Map<string, string> = new Map<string, string>();

  /** True when the file can be handled now; false when it should be left where it is for the next look. */
  ready(name: string, text: string | null): boolean {
    const now = text === null ? '' : text;
    if (parseJsonObject(now) !== null) {
      this.seen.delete(name);
      return true;
    }
    if (this.seen.has(name) && this.seen.get(name) === now) {
      this.seen.delete(name);
      return true;
    }
    this.seen.set(name, now);
    return false;
  }

  /** Forgets every file seen so far (the directory was emptied). */
  clear(): void {
    this.seen.clear();
  }
}
