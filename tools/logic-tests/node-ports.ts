// Node-backed implementations of the Watch Link ports (common/src/main/ets/watchlink/WatchLinkPorts.ets)
// for the logic tests: Node `crypto` for ECDSA P-256 / SHA-256 and `fs` for the text store.
// Test support only. The device implementations wrap HUKS, cryptoFramework and fileIo.
// The classes match the port interfaces by shape; the tests import them as '@fairwear/node-ports'.

// eslint-disable-next-line @typescript-eslint/no-explicit-any
declare const require: (name: string) => any;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
declare const Buffer: any;

const nodeCrypto = require("crypto");
const nodeFs = require("fs");
const nodeOs = require("os");
const nodePath = require("path");

function sha256(bytes: unknown): { toString(enc: string): string } {
  return nodeCrypto.createHash("sha256").update(bytes).digest();
}

// ECDSA P-256 key pair in memory. Signatures are ASN.1 DER, base64url: the encoding the phone's
// ProofSigner produces (HUKS and cryptoFramework 'ECC256|SHA256' both return DER).
export class NodeSigner {
  private privateKey: unknown;
  private spkiDer: unknown;

  constructor() {
    const pair = nodeCrypto.generateKeyPairSync("ec", {
      namedCurve: "prime256v1",
    });
    this.privateKey = pair.privateKey;
    this.spkiDer = pair.publicKey.export({ type: "spki", format: "der" });
  }

  kid(): string {
    return sha256(this.spkiDer).toString("hex").substring(0, 8);
  }

  publicKeySpkiB64(): string {
    return (this.spkiDer as { toString(enc: string): string }).toString(
      "base64url",
    );
  }

  sign(msg: string): Promise<string> {
    const sig = nodeCrypto.sign(
      "sha256",
      Buffer.from(msg, "utf8"),
      this.privateKey,
    );
    return Promise.resolve(sig.toString("base64url"));
  }
}

export class NodeSigVerifier {
  verify(pubB64: string, msg: string, sigB64: string): Promise<boolean> {
    try {
      const key = nodeCrypto.createPublicKey({
        key: Buffer.from(pubB64, "base64url"),
        format: "der",
        type: "spki",
      });
      const ok: boolean = nodeCrypto.verify(
        "sha256",
        Buffer.from(msg, "utf8"),
        key,
        Buffer.from(sigB64, "base64url"),
      );
      return Promise.resolve(ok);
    } catch (e) {
      return Promise.resolve(false);
    }
  }
}

export class NodeHasher {
  sha256B64url(msg: string): Promise<string> {
    return Promise.resolve(
      sha256(Buffer.from(msg, "utf8")).toString("base64url"),
    );
  }

  keyId(pubB64: string): Promise<string> {
    return Promise.resolve(
      sha256(Buffer.from(pubB64, "base64url")).toString("hex").substring(0, 8),
    );
  }
}

// Random bytes from the Node CSPRNG, for the partner verifier (RandomSource in claim/PartnerVerifier.ets).
export class NodeRandom {
  randomBytes(count: number): Promise<Uint8Array> {
    return Promise.resolve(new Uint8Array(nodeCrypto.randomBytes(count)));
  }
}

// Text files under one directory. writeAtomic writes a temporary file and renames it.
export class FsTextStore {
  private root: string;

  constructor(root: string) {
    this.root = root;
  }

  private full(path: string): string {
    return nodePath.join(this.root, path);
  }

  read(path: string): string | null {
    try {
      return nodeFs.readFileSync(this.full(path), "utf8");
    } catch (e) {
      return null;
    }
  }

  writeAtomic(path: string, text: string): void {
    const target = this.full(path);
    nodeFs.mkdirSync(nodePath.dirname(target), { recursive: true });
    const tmp = target + ".tmp";
    nodeFs.writeFileSync(tmp, text, "utf8");
    nodeFs.renameSync(tmp, target);
  }

  list(dir: string): string[] {
    try {
      const names: string[] = nodeFs.readdirSync(this.full(dir));
      return names.filter(function (name: string): boolean {
        return !name.endsWith(".tmp");
      });
    } catch (e) {
      return [];
    }
  }

  remove(path: string): void {
    try {
      nodeFs.unlinkSync(this.full(path));
    } catch (e) {
      // Already gone.
    }
  }
}

export function makeTempDir(): string {
  return nodeFs.mkdtempSync(nodePath.join(nodeOs.tmpdir(), "fairwear-wl-"));
}

export function removeDir(dir: string): void {
  try {
    nodeFs.rmSync(dir, { recursive: true, force: true });
  } catch (e) {
    // A leftover temporary directory is harmless.
  }
}

export function utf8ByteLength(text: string): number {
  return Buffer.byteLength(text, "utf8");
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
declare const process: any;

// A file of the repository as text, or null. The runner is started as
// `node runner.js <typescript dir> <repo root> <module> ...`, so the repository root is argv[3].
// Lets a test check that text shown in the app (the Watch Link tour's code lines) still exists in the code.
export function readRepoText(relativePath: string): string | null {
  const root: string = process.argv[3];
  try {
    return nodeFs.readFileSync(nodePath.join(root, relativePath), "utf8");
  } catch (e) {
    return null;
  }
}
