import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { baseGuard, issueSessionHandler, requireSession, sessions } from '../src/server/security/guards.ts';
import { isSafeId, safeJoin, sanitizeFilename } from '../src/server/security/ids.ts';
import { isLocalAddress, isSameOrigin } from '../src/server/security/network.ts';
import { RateLimiter } from '../src/server/security/rateLimit.ts';
import { extractBearer, SessionRegistry } from '../src/server/security/sessions.ts';
import { generateFileId, generatePairingToken, generateSessionToken, isPairingTokenShape } from '../src/server/security/tokens.ts';

function fakeRes() {
  const r: { code: number; body: unknown; status(c: number): typeof r; json(b: unknown): typeof r } = {
    code: 200,
    body: undefined,
    status(c) { r.code = c; return r; },
    json(b) { r.body = b; return r; },
  };
  return r;
}

test('sanitizeFilename never yields ., .. or empty', () => {
  for (const bad of ['..', '.', '', '...', '../..', 'a/../..', '..\\..', ' .. ', undefined, 42, null]) {
    const out = sanitizeFilename(bad);
    assert.notEqual(out, '..');
    assert.notEqual(out, '.');
    assert.ok(out.length > 0);
    assert.ok(!out.includes('/') && !out.includes('\\'));
  }
  assert.equal(sanitizeFilename('../etc/passwd'), 'passwd');
  assert.equal(sanitizeFilename('फोटो 1.jpg'), 'फोटो 1.jpg');
  assert.equal(sanitizeFilename('.hidden'), 'hidden');
  assert.ok(sanitizeFilename('x'.repeat(500)).length <= 120);
});

test('isSafeId is strict', () => {
  assert.ok(isSafeId('tx_123-ABC'));
  for (const bad of ['..', '.', '', 'a/b', 'a b', 'x'.repeat(65), '../x', 5, null]) assert.ok(!isSafeId(bad));
});

test('safeJoin keeps paths strictly inside root (the original vault bug)', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'vega-sec-'));
  const chunks = path.join(root, 'chunks');
  fs.mkdirSync(chunks);
  fs.writeFileSync(path.join(root, 'db.json'), '{}');
  for (const bad of ['..', '.', '', '../x', '/etc', 'a/../..', '../chunks2']) {
    assert.throws(() => safeJoin(chunks, bad), /escapes/);
  }
  assert.equal(safeJoin(chunks, 'tx1'), path.join(chunks, 'tx1'));
  // Old behaviour would have rm -rf'd `root`; the new code refuses before touching disk.
  assert.throws(() => safeJoin(chunks, '..'));
  assert.ok(fs.existsSync(path.join(root, 'db.json')));
  fs.rmSync(root, { recursive: true, force: true });
});

test('tokens: shape, entropy source, uniqueness', () => {
  const seen = new Set<string>();
  for (let i = 0; i < 2000; i++) {
    const t = generatePairingToken();
    assert.ok(isPairingTokenShape(t), t);
    seen.add(t);
  }
  assert.ok(seen.size > 1990);
  assert.ok(generateSessionToken().length >= 43);
  assert.match(generateFileId(), /^[a-f0-9]{32}$/);
  assert.ok(!isPairingTokenShape('VEG-0OI1abcd'));
});

test('sessions: issue, verify, expire, bearer parsing', () => {
  let now = 1_000;
  const reg = new SessionRegistry(() => now);
  const s = reg.issue('peer-aaaaaa', '192.168.1.5');
  assert.equal(reg.verify(s.token)?.peerId, 'peer-aaaaaa');
  assert.equal(reg.verify('nope'), null);
  assert.equal(reg.verify(undefined), null);
  now += 25 * 3600_000;
  assert.equal(reg.verify(s.token), null);
  assert.equal(extractBearer(`Bearer ${s.token}`), s.token);
  assert.equal(extractBearer('Basic abc'), null);
  assert.equal(extractBearer('Bearer short'), null);
});

test('rate limiter blocks after limit and recovers', () => {
  let now = 0;
  const rl = new RateLimiter(3, 1000, () => now);
  assert.ok(rl.allow('a') && rl.allow('a') && rl.allow('a'));
  assert.ok(!rl.allow('a'));
  assert.ok(rl.allow('b'));
  now += 1001;
  assert.ok(rl.allow('a'));
});

test('network helpers', () => {
  for (const ip of ['127.0.0.1', '::1', '10.0.0.4', '192.168.43.2', '172.16.0.1', '172.31.9.9', '::ffff:192.168.1.7', 'fd12:3::1']) {
    assert.ok(isLocalAddress(ip), ip);
  }
  for (const ip of ['8.8.8.8', '172.32.0.1', '172.15.0.1', '::ffff:1.2.3.4', undefined]) assert.ok(!isLocalAddress(ip as string), String(ip));
  assert.ok(isSameOrigin(undefined, 'x:3000'));
  assert.ok(isSameOrigin('http://192.168.1.2:3000', '192.168.1.2:3000'));
  assert.ok(!isSameOrigin('http://evil.example', '192.168.1.2:3000'));
  assert.ok(!isSameOrigin('not a url', '192.168.1.2:3000'));
});

test('guards: no token => 401, valid token => next, cross-origin => 403', () => {
  const noAuth = fakeRes();
  let called = false;
  requireSession({ headers: {} } as never, noAuth as never, () => { called = true; });
  assert.equal(noAuth.code, 401);
  assert.ok(!called);

  const info = sessions.issue('peer-zzzzzz', '127.0.0.1');
  const req = { headers: { authorization: `Bearer ${info.token}` } } as never;
  requireSession(req, fakeRes() as never, () => { called = true; });
  assert.ok(called);
  assert.equal((req as { session: { peerId: string } }).session.peerId, 'peer-zzzzzz');

  const cross = fakeRes();
  baseGuard({ headers: { origin: 'http://evil.example', host: 'h:3000' }, socket: { remoteAddress: '10.0.0.2' } } as never, cross as never, () => { throw new Error('must not pass'); });
  assert.equal(cross.code, 403);
});

test('session issue validates peerId and rate-limits', () => {
  const bad = fakeRes();
  issueSessionHandler({ body: { peerId: '../x' }, socket: { remoteAddress: '10.9.9.9' } } as never, bad as never);
  assert.equal(bad.code, 400);
  const ok = fakeRes();
  issueSessionHandler({ body: { peerId: 'peer-abcdef' }, socket: { remoteAddress: '10.9.9.8' } } as never, ok as never);
  assert.equal(ok.code, 201);
  let last = 201;
  for (let i = 0; i < 40; i++) {
    const r = fakeRes();
    issueSessionHandler({ body: { peerId: 'peer-abcdef' }, socket: { remoteAddress: '10.9.9.7' } } as never, r as never);
    last = r.code;
  }
  assert.equal(last, 429);
});
