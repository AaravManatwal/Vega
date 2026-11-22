import path from 'node:path';

/** Strict identifier for transfer/session ids: letters, digits, '_' and '-', 1-64 chars. */
const SAFE_ID = /^[A-Za-z0-9_-]{1,64}$/;

export function isSafeId(value: unknown): value is string {
  return typeof value === 'string' && SAFE_ID.test(value);
}

/**
 * Makes a user-supplied file name safe to use as a single path segment.
 * Never returns '', '.', '..' or a dot-leading name, and caps the length.
 */
export function sanitizeFilename(name: unknown, fallback = 'file'): string {
  if (typeof name !== 'string') return fallback;
  const base = path.basename(name.replace(/\\/g, '/')).replace(/[^a-zA-Z0-9._\-ऀ-ॿ ]/g, '_');
  const trimmed = base.replace(/^\.+/, '').replace(/[ .]+$/, '').slice(0, 120);
  return trimmed.length > 0 ? trimmed : fallback;
}

/** Joins `child` under `root` and guarantees the result stays strictly inside `root`. */
export function safeJoin(root: string, child: string): string {
  const resolvedRoot = path.resolve(root);
  const resolved = path.resolve(resolvedRoot, child);
  if (resolved === resolvedRoot || !resolved.startsWith(resolvedRoot + path.sep)) {
    throw new Error('Path escapes its root directory.');
  }
  return resolved;
}
