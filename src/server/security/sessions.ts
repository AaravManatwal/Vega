import { generateSessionToken } from './tokens.ts';

export interface SessionInfo {
  token: string;
  peerId: string;
  ip: string;
  createdAt: number;
  lastUsedAt: number;
}

const TTL_MS = 24 * 3600_000;
const MAX_SESSIONS = 5000;

/** In-memory bearer sessions, each bound to exactly one peerId. */
export class SessionRegistry {
  private readonly sessions = new Map<string, SessionInfo>();
  private readonly now: () => number;

  constructor(now: () => number = Date.now) {
    this.now = now;
  }

  issue(peerId: string, ip: string): SessionInfo {
    this.prune();
    if (this.sessions.size >= MAX_SESSIONS) {
      const oldest = this.sessions.keys().next().value;
      if (oldest) this.sessions.delete(oldest);
    }
    const t = this.now();
    const info: SessionInfo = { token: generateSessionToken(), peerId, ip, createdAt: t, lastUsedAt: t };
    this.sessions.set(info.token, info);
    return info;
  }

  verify(token: string | undefined | null): SessionInfo | null {
    if (!token) return null;
    const info = this.sessions.get(token);
    if (!info) return null;
    const t = this.now();
    if (t - info.lastUsedAt > TTL_MS) {
      this.sessions.delete(token);
      return null;
    }
    info.lastUsedAt = t;
    return info;
  }

  revoke(token: string): void {
    this.sessions.delete(token);
  }

  private prune(): void {
    const t = this.now();
    for (const [token, info] of this.sessions) {
      if (t - info.lastUsedAt > TTL_MS) this.sessions.delete(token);
    }
  }
}

export function extractBearer(header: string | undefined): string | null {
  if (!header) return null;
  const m = /^Bearer\s+([A-Za-z0-9_-]{20,128})$/.exec(header.trim());
  return m ? m[1] : null;
}
