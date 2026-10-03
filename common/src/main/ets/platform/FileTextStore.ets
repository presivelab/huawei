import { fileIo as fs } from '@kit.CoreFileKit';
import { TextStore } from '../watchlink/WatchLinkPorts';

const TMP_SUFFIX: string = '.tmp';

/*
 * Small text files under one directory of the app sandbox (the app's filesDir).
 * writeAtomic writes a temporary file and renames it, so a reader never sees half a file.
 */
export class FileTextStore implements TextStore {
  private root: string;

  constructor(root: string) {
    this.root = root;
  }

  rootDir(): string {
    return this.root;
  }

  read(path: string): string | null {
    const full = this.full(path);
    try {
      if (!fs.accessSync(full)) {
        return null;
      }
      return fs.readTextSync(full);
    } catch (e) {
      return null;
    }
  }

  writeAtomic(path: string, text: string): void {
    const full = this.full(path);
    const slash = full.lastIndexOf('/');
    const dir = full.substring(0, slash);
    if (!fs.accessSync(dir)) {
      fs.mkdirSync(dir, true);
    }
    const tmp = full + TMP_SUFFIX;
    const file = fs.openSync(tmp, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.WRITE_ONLY);
    try {
      fs.writeSync(file.fd, text);
      fs.fsyncSync(file.fd);
    } finally {
      fs.closeSync(file);
    }
    fs.renameSync(tmp, full);
  }

  list(dir: string): string[] {
    const full = this.full(dir);
    const out: string[] = [];
    try {
      if (!fs.accessSync(full)) {
        return out;
      }
      const names = fs.listFileSync(full);
      for (let i = 0; i < names.length; i++) {
        if (!names[i].endsWith(TMP_SUFFIX)) {
          out.push(names[i]);
        }
      }
    } catch (e) {
      return [];
    }
    return out;
  }

  remove(path: string): void {
    try {
      fs.unlinkSync(this.full(path));
    } catch (e) {
      // Already gone.
    }
  }

  private full(path: string): string {
    return `${this.root}/${path}`;
  }
}
