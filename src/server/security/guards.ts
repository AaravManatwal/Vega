import type { NextFunction, Request, Response } from 'express';
import { isLocalAddress, isSameOrigin } from './network.ts';
import { RateLimiter } from './rateLimit.ts';
import { extractBearer, type SessionInfo, SessionRegistry } from './sessions.ts';

export const sessions = new SessionRegistry();
const sessionIssueLimiter = new RateLimiter(30, 60_000);
export const pairingLookupLimiter = new RateLimiter(10, 60_000);

const LAN_ONLY = process.env.VEGA_LAN_ONLY === '1';

export function clientIp(req: Request): string {
  return req.socket.remoteAddress || 'unknown';
}

export type AuthedRequest = Request & { session: SessionInfo };

/** Rejects cross-site browser requests and (optionally, VEGA_LAN_ONLY=1) non-local clients. */
export function baseGuard(req: Request, res: Response, next: NextFunction): void {
  if (LAN_ONLY && !isLocalAddress(clientIp(req))) {
    res.status(403).json({ error: 'Only local-network clients are allowed.' });
    return;
  }
  if (!isSameOrigin(req.headers.origin, req.headers.host)) {
    res.status(403).json({ error: 'Cross-origin request blocked.' });
    return;
  }
  next();
}

/** POST /api/session handler: issues a bearer token bound to the caller's peerId. */
export function issueSessionHandler(req: Request, res: Response): void {
  if (!sessionIssueLimiter.allow(clientIp(req))) {
    res.status(429).json({ error: 'Too many session requests.' });
    return;
  }
  const peerId = (req.body as { peerId?: unknown } | undefined)?.peerId;
  if (typeof peerId !== 'string' || !/^[A-Za-z0-9_.:-]{6,96}$/.test(peerId)) {
    res.status(400).json({ error: 'A valid peerId is required.' });
    return;
  }
  const info = sessions.issue(peerId, clientIp(req));
  res.status(201).json({ token: info.token, peerId: info.peerId });
}

/** Requires `Authorization: Bearer <session token>`; attaches `req.session`. */
export function requireSession(req: Request, res: Response, next: NextFunction): void {
  const info = sessions.verify(extractBearer(req.headers.authorization));
  if (!info) {
    res.status(401).json({ error: 'Missing or invalid session.' });
    return;
  }
  (req as AuthedRequest).session = info;
  next();
}
