/**
 * Authenticated API client. Obtains a per-device session token from /api/session and attaches it
 * to every request (and to the WebSocket URL). Kept separate from UI code so transport/security
 * can evolve without touching screens.
 */
let configuredPeerId: string | null = null;
let tokenPromise: Promise<string> | null = null;

export function configureApi(peerId: string): void {
  if (configuredPeerId !== peerId) {
    configuredPeerId = peerId;
    tokenPromise = null;
  }
}

async function requestSession(): Promise<string> {
  if (!configuredPeerId) throw new Error('API client not configured.');
  const res = await fetch('/api/session', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ peerId: configuredPeerId }),
  });
  if (!res.ok) throw new Error(`Session request failed (${res.status}).`);
  const data = (await res.json()) as { token: string };
  return data.token;
}

export function getSessionToken(forceRefresh = false): Promise<string> {
  if (forceRefresh || !tokenPromise) {
    const p = requestSession();
    tokenPromise = p;
    p.catch(() => {
      if (tokenPromise === p) tokenPromise = null;
    });
  }
  return tokenPromise;
}

export async function apiFetch(input: string, init: RequestInit = {}): Promise<Response> {
  const send = async (forceRefresh: boolean) => {
    const token = await getSessionToken(forceRefresh);
    const headers = new Headers(init.headers);
    headers.set('Authorization', `Bearer ${token}`);
    return fetch(input, { ...init, headers });
  };
  const res = await send(false);
  if (res.status !== 401) return res;
  return send(true); // session expired or server restarted: renew once
}
