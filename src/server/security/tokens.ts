import crypto from 'node:crypto';

// Unambiguous uppercase alphabet (no 0/O/1/I): 32 symbols = 5 bits each.
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/** Short typeable pairing code `VEG-XXXXXXXX` (8 symbols = 40 bits, rate-limited server side). */
export function generatePairingToken(): string {
  let out = '';
  for (const b of crypto.randomBytes(8)) out += ALPHABET[b & 31];
  return `VEG-${out}`;
}

export function isPairingTokenShape(value: string): boolean {
  return /^VEG-[A-Z2-9]{8}$/.test(value);
}

/** 256-bit opaque bearer token (URL-safe). */
export function generateSessionToken(): string {
  return crypto.randomBytes(32).toString('base64url');
}

/** 128-bit random id for stored files. */
export function generateFileId(): string {
  return crypto.randomBytes(16).toString('hex');
}
