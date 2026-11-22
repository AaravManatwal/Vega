export interface DeviceIdentityKeys {
  publicKey: CryptoKey;
  privateKey: CryptoKey;
  publicKeyJwk: JsonWebKey;
  fingerprint: string;
}

export async function generateDeviceIdentityKeys(): Promise<DeviceIdentityKeys> {
  const keyPair = await crypto.subtle.generateKey(
    { name: 'ECDH', namedCurve: 'P-256' },
    true,
    ['deriveKey']
  );

  const publicKeyJwk = await crypto.subtle.exportKey('jwk', keyPair.publicKey);
  const canonical = JSON.stringify({
    crv: publicKeyJwk.crv,
    kty: publicKeyJwk.kty,
    x: publicKeyJwk.x,
    y: publicKeyJwk.y,
  });
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(canonical));
  const hex = bufferToHex(digest).toUpperCase();
  const fingerprint = `${hex.slice(0, 4)} · ${hex.slice(4, 8)} · ${hex.slice(8, 12)} · ${hex.slice(12, 16)}`;

  return {
    publicKey: keyPair.publicKey,
    privateKey: keyPair.privateKey,
    publicKeyJwk,
    fingerprint,
  };
}

export async function deriveSharedSessionKey(
  localPrivateKey: CryptoKey,
  remotePublicKeyJwk: JsonWebKey
): Promise<CryptoKey> {
  const remotePublicKey = await crypto.subtle.importKey(
    'jwk',
    remotePublicKeyJwk,
    { name: 'ECDH', namedCurve: 'P-256' },
    false,
    []
  );

  return crypto.subtle.deriveKey(
    { name: 'ECDH', public: remotePublicKey },
    localPrivateKey,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt']
  );
}

function toArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  if (
    bytes.buffer instanceof ArrayBuffer &&
    bytes.byteOffset === 0 &&
    bytes.byteLength === bytes.buffer.byteLength
  ) {
    return bytes.buffer;
  }
  return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
}

export async function encryptChunk(
  sessionKey: CryptoKey,
  plainBytes: Uint8Array
): Promise<{ ivBase64: string; cipherBase64: string }> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const cipherBuffer = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    sessionKey,
    toArrayBuffer(plainBytes)
  );
  return {
    ivBase64: bytesToBase64(iv),
    cipherBase64: bytesToBase64(new Uint8Array(cipherBuffer)),
  };
}

export async function decryptChunk(
  sessionKey: CryptoKey,
  ivBase64: string,
  cipherBase64: string
): Promise<Uint8Array> {
  const iv = base64ToBytes(ivBase64);
  const cipherBytes = base64ToBytes(cipherBase64);
  const plainBuffer = await crypto.subtle.decrypt(
    {
      name: 'AES-GCM',
      iv: toArrayBuffer(iv),
    },
    sessionKey,
    toArrayBuffer(cipherBytes)
  );
  return new Uint8Array(plainBuffer);
}

export async function encryptChunkBinary(
  sessionKey: CryptoKey,
  plainBytes: Uint8Array
): Promise<{ iv: Uint8Array; cipherBytes: Uint8Array }> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const cipherBuffer = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    sessionKey,
    toArrayBuffer(plainBytes)
  );
  return {
    iv,
    cipherBytes: new Uint8Array(cipherBuffer),
  };
}

export async function decryptChunkBinary(
  sessionKey: CryptoKey,
  iv: Uint8Array,
  cipherBytes: Uint8Array
): Promise<Uint8Array> {
  const plainBuffer = await crypto.subtle.decrypt(
    {
      name: 'AES-GCM',
      iv: toArrayBuffer(iv),
    },
    sessionKey,
    toArrayBuffer(cipherBytes)
  );
  return new Uint8Array(plainBuffer);
}

export async function computeSha256Hex(buffer: ArrayBuffer): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', buffer);
  return bufferToHex(digest);
}

const SHA256_K = new Uint32Array([
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
]);

/**
 * Incremental FIPS 180-4 SHA-256 hasher that processes arbitrary-sized files
 * and incoming chunk streams in constant RAM without allocating a multi-GB ArrayBuffer.
 */
export class StreamingSha256 {
  private h0 = 0x6a09e667;
  private h1 = 0xbb67ae85;
  private h2 = 0x3c6ef372;
  private h3 = 0xa54ff53a;
  private h4 = 0x510e527f;
  private h5 = 0x9b05688c;
  private h6 = 0x1f83d9ab;
  private h7 = 0x5be0cd19;

  private block = new Uint8Array(64);
  private blockView = new DataView(this.block.buffer);
  private w = new Uint32Array(64);
  private blockLen = 0;
  private totalBytes = 0;

  public update(data: Uint8Array): this {
    let offset = 0;
    const len = data.byteLength;
    this.totalBytes += len;

    while (offset < len) {
      const take = Math.min(64 - this.blockLen, len - offset);
      this.block.set(data.subarray(offset, offset + take), this.blockLen);
      this.blockLen += take;
      offset += take;

      if (this.blockLen === 64) {
        this.compressBlock(this.blockView, 0);
        this.blockLen = 0;
      }
    }
    return this;
  }

  private compressBlock(view: DataView, byteOffset: number): void {
    const w = this.w;
    for (let i = 0; i < 16; i++) {
      w[i] = view.getUint32(byteOffset + i * 4, false);
    }
    for (let i = 16; i < 64; i++) {
      const v0 = w[i - 15];
      const s0 = ((v0 >>> 7) | (v0 << 25)) ^ ((v0 >>> 18) | (v0 << 14)) ^ (v0 >>> 3);
      const v1 = w[i - 2];
      const s1 = ((v1 >>> 17) | (v1 << 15)) ^ ((v1 >>> 19) | (v1 << 13)) ^ (v1 >>> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) >>> 0;
    }

    let a = this.h0;
    let b = this.h1;
    let c = this.h2;
    let d = this.h3;
    let e = this.h4;
    let f = this.h5;
    let g = this.h6;
    let h = this.h7;

    for (let i = 0; i < 64; i++) {
      const S1 = ((e >>> 6) | (e << 26)) ^ ((e >>> 11) | (e << 21)) ^ ((e >>> 25) | (e << 7));
      const ch = (e & f) ^ (~e & g);
      const temp1 = (h + S1 + ch + SHA256_K[i] + w[i]) >>> 0;
      const S0 = ((a >>> 2) | (a << 30)) ^ ((a >>> 13) | (a << 19)) ^ ((a >>> 22) | (a << 10));
      const maj = (a & b) ^ (a & c) ^ (b & c);
      const temp2 = (S0 + maj) >>> 0;

      h = g;
      g = f;
      f = e;
      e = (d + temp1) >>> 0;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) >>> 0;
    }

    this.h0 = (this.h0 + a) >>> 0;
    this.h1 = (this.h1 + b) >>> 0;
    this.h2 = (this.h2 + c) >>> 0;
    this.h3 = (this.h3 + d) >>> 0;
    this.h4 = (this.h4 + e) >>> 0;
    this.h5 = (this.h5 + f) >>> 0;
    this.h6 = (this.h6 + g) >>> 0;
    this.h7 = (this.h7 + h) >>> 0;
  }

  public digestHex(): string {
    this.block[this.blockLen++] = 0x80;
    if (this.blockLen > 56) {
      this.block.fill(0, this.blockLen, 64);
      this.compressBlock(this.blockView, 0);
      this.blockLen = 0;
    }
    this.block.fill(0, this.blockLen, 56);

    const totalBits = this.totalBytes * 8;
    const highBits = Math.floor(totalBits / 0x100000000);
    const lowBits = totalBits >>> 0;
    this.blockView.setUint32(56, highBits, false);
    this.blockView.setUint32(60, lowBits, false);
    this.compressBlock(this.blockView, 0);

    const out = new ArrayBuffer(32);
    const outView = new DataView(out);
    outView.setUint32(0, this.h0, false);
    outView.setUint32(4, this.h1, false);
    outView.setUint32(8, this.h2, false);
    outView.setUint32(12, this.h3, false);
    outView.setUint32(16, this.h4, false);
    outView.setUint32(20, this.h5, false);
    outView.setUint32(24, this.h6, false);
    outView.setUint32(28, this.h7, false);
    return bufferToHex(out);
  }
}

const STREAM_HASH_THRESHOLD_BYTES = 128 * 1024 * 1024; // 128 MB native hardware WebCrypto threshold
const STREAM_HASH_SLICE_BYTES = 8 * 1024 * 1024; // 8 MB slices for multi-GB streaming hash

/**
 * Computes SHA-256 hex for any Blob or File without exhausting browser RAM on multi-GB files.
 */
export async function computeBlobSha256Streaming(blob: Blob): Promise<string> {
  if (blob.size <= STREAM_HASH_THRESHOLD_BYTES) {
    const buffer = await blob.arrayBuffer();
    return computeSha256Hex(buffer);
  }

  const hasher = new StreamingSha256();
  let offset = 0;
  let slicesProcessed = 0;

  while (offset < blob.size) {
    const end = Math.min(offset + STREAM_HASH_SLICE_BYTES, blob.size);
    const sliceBuf = await blob.slice(offset, end).arrayBuffer();
    hasher.update(new Uint8Array(sliceBuf));
    offset = end;
    slicesProcessed += 1;

    if (slicesProcessed % 8 === 0) {
      await new Promise((r) => setTimeout(r, 0));
    }
  }

  return hasher.digestHex();
}

export function bufferToHex(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let hex = '';
  for (let i = 0; i < bytes.length; i++) {
    hex += bytes[i].toString(16).padStart(2, '0');
  }
  return hex;
}

export function bytesToBase64(bytes: Uint8Array): string {
  let binary = '';
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

export function base64ToBytes(base64: string): Uint8Array {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}
