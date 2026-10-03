// Everything the Watch Link logic needs from the platform, as interfaces.
// The device implementations wrap HUKS / cryptoFramework / fileIo; the test implementations use Node.
// No system-kit imports here.

export interface Clock {
  nowMs(): number;
}

// Signs with a key that never leaves the device. The signature is ECDSA P-256 / SHA-256 over the UTF-8
// bytes of the message, ASN.1 DER, base64url: the same encoding as the phone's claim signature.
export interface Signer {
  kid(): string;
  publicKeySpkiB64(): string;
  sign(msg: string): Promise<string>;
}

export interface SigVerifier {
  verify(pubB64: string, msg: string, sigB64: string): Promise<boolean>;
}

export interface Hasher {
  // base64url of SHA-256 over the UTF-8 bytes of the message.
  sha256B64url(msg: string): Promise<string>;
  // Key id of a public key (SubjectPublicKeyInfo DER, base64url): 8 hex characters, the first 4 bytes of
  // SHA-256 over the key bytes. The same rule as the phone's kid.
  keyId(pubB64: string): Promise<string>;
}

// Small text files in the app sandbox. Paths are relative to the app's files directory, with '/'.
export interface TextStore {
  read(path: string): string | null;
  writeAtomic(path: string, text: string): void;   // temporary file, then rename
  list(dir: string): string[];                     // file names in the directory, no path
  remove(path: string): void;
}
