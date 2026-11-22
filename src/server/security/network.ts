/** True for loopback / RFC1918 / link-local / IPv6 ULA addresses (a local network peer). */
export function isLocalAddress(addr: string | undefined): boolean {
  if (!addr) return false;
  const a = addr.startsWith('::ffff:') ? addr.slice(7) : addr;
  if (a === '::1' || a === '127.0.0.1') return true;
  if (/^127\./.test(a) || /^10\./.test(a) || /^192\.168\./.test(a) || /^169\.254\./.test(a)) return true;
  const m = /^172\.(\d+)\./.exec(a);
  if (m && Number(m[1]) >= 16 && Number(m[1]) <= 31) return true;
  return /^(fc|fd)[0-9a-f]{2}:/i.test(a) || /^fe80:/i.test(a);
}

/** Same-origin check for browser requests: an Origin header, when present, must match Host. */
export function isSameOrigin(origin: string | undefined, host: string | undefined): boolean {
  if (!origin) return true; // non-browser clients (native app) send no Origin
  if (!host) return false;
  try {
    return new URL(origin).host === host;
  } catch {
    return false;
  }
}
