// Executable model of the Vega LAN v2 resume logic (sender + receiver state machines over an
// in-memory link, using the same crypto as the Dart code). Proves the design before/alongside Dart.
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import { privFromSeed, pubRaw, dh, transcript, derive, acceptConfirm, resumeProof, resumedConfirm, chunkAad, aesGcmSeal, doneConfirm } from './lan_v2_vectors.mjs';

const CHUNK = 1024;
const file = crypto.randomBytes(CHUNK * 10 + 300);
const sha = (b) => crypto.createHash('sha256').update(b).digest('hex');
const eqb = (a, b) => a.length === b.length && crypto.timingSafeEqual(a, b);
const newPair = () => { const priv = privFromSeed(crypto.randomBytes(32)); return { priv, pub: pubRaw(priv) }; };

class Receiver {
  constructor() { this.partials = new Map(); this.saved = null; }
  // returns a connection object
  connect(init) {
    const F = newPair();
    const params = { qr: false, encrypted: true, e: init.epk, f: F.pub, r: Buffer.alloc(0), totalBytes: init.totalBytes, chunkSize: init.chunkSize, fileName: init.fileName, taskId: init.id };
    const th = transcript(params);
    const keys = derive({ qr: false, dhEF: dh(F.priv, init.epk), dhER: null, psk: null, transcriptHash: th });
    const conn = { th, keys, bytes: Buffer.alloc(0), index: 0, ready: !init.resume, finished: false, init };
    return { conn, accept: { fpk: F.pub, confirm: acceptConfirm(keys.confirmKey, th) } };
  }
  resume(conn, proof) {
    const cand = this.partials.get(conn.init.id);
    if (cand && cand.fileName === conn.init.fileName && cand.totalBytes === conn.init.totalBytes && cand.chunkSize === conn.init.chunkSize) {
      if (!eqb(resumeProof(cand.resumeKey, conn.th), proof)) throw new Error('reject: Resume proof invalid');
      this.partials.delete(conn.init.id);
      conn.bytes = cand.bytes; conn.index = cand.index;
    }
    conn.ready = true;
    return { offset: conn.bytes.length, index: conn.index, confirm: resumedConfirm(conn.keys.confirmKey, conn.bytes.length, conn.index) };
  }
  chunk(conn, h, ct, tag) {
    if (!conn.ready) throw new Error('chunk before ready');
    if (h.index !== conn.index || h.offset !== conn.bytes.length) throw new Error('chunk out of order');
    const d = crypto.createDecipheriv('aes-256-gcm', conn.keys.sessionKey, h.nonce);
    d.setAAD(chunkAad(h.index, h.offset, h.plainSize)); d.setAuthTag(tag);
    const plain = Buffer.concat([d.update(ct), d.final()]);
    conn.bytes = Buffer.concat([conn.bytes, plain]); conn.index++;
  }
  drop(conn) { // connection lost: park
    if (conn.finished) return;
    this.partials.set(conn.init.id, { ...conn.init, fileName: conn.init.fileName, bytes: conn.bytes, index: conn.index, resumeKey: conn.keys.resumeKey });
  }
  complete(conn, shaHex) {
    const ok = sha(conn.bytes) === shaHex && conn.bytes.length === conn.init.totalBytes;
    conn.finished = true; if (ok) this.saved = conn.bytes;
    return { ok, sha: sha(conn.bytes), bytes: conn.bytes.length, confirm: doneConfirm(conn.keys.confirmKey, ok, sha(conn.bytes), conn.bytes.length) };
  }
}

function runSender(rx, { dropAfter = [], tamperResumeKey = false } = {}) {
  const id = 'task_sim_1';
  let offset = 0, index = 0, resumeKey = null, attempts = 0;
  const drops = [...dropAfter];
  for (;;) {
    const E = newPair();
    const init = { id, fileName: 'a.bin', totalBytes: file.length, chunkSize: CHUNK, epk: E.pub, resume: resumeKey !== null };
    const { conn, accept } = rx.connect(init);
    const th = transcript({ qr: false, encrypted: true, e: E.pub, f: accept.fpk, r: Buffer.alloc(0), totalBytes: file.length, chunkSize: CHUNK, fileName: 'a.bin', taskId: id });
    const keys = derive({ qr: false, dhEF: dh(E.priv, accept.fpk), dhER: null, psk: null, transcriptHash: th });
    assert.ok(eqb(acceptConfirm(keys.confirmKey, th), accept.confirm), 'accept confirm');
    if (resumeKey) {
      const proofKey = tamperResumeKey ? crypto.randomBytes(32) : resumeKey;
      const r = rx.resume(conn, resumeProof(proofKey, th));
      assert.ok(eqb(resumedConfirm(keys.confirmKey, r.offset, r.index), r.confirm), 'resumed confirm');
      assert.ok(r.offset <= offset && r.index <= index);
      offset = r.offset; index = r.index;
    }
    resumeKey = keys.resumeKey;
    let dropped = false;
    while (offset < file.length) {
      if (drops.length && index === drops[0]) { drops.shift(); rx.drop(conn); dropped = true; break; }
      const plain = file.subarray(offset, Math.min(offset + CHUNK, file.length));
      const nonce = crypto.randomBytes(12);
      const { ct, tag } = aesGcmSeal(keys.sessionKey, nonce, chunkAad(index, offset, plain.length), plain);
      rx.chunk(conn, { index, offset, plainSize: plain.length, nonce }, ct, tag);
      offset += plain.length; index++;
    }
    if (dropped) { attempts++; assert.ok(attempts <= 5); continue; }
    const done = rx.complete(conn, sha(file));
    assert.ok(eqb(doneConfirm(keys.confirmKey, done.ok, done.sha, done.bytes), done.confirm));
    return { done, attempts };
  }
}

// 1) Normal run.
{ const rx = new Receiver(); const r = runSender(rx); assert.ok(r.done.ok); assert.equal(sha(rx.saved), sha(file)); }
// 2) Three drops in a row, still byte-exact.
{ const rx = new Receiver(); const r = runSender(rx, { dropAfter: [2, 2, 7] }); assert.ok(r.done.ok); assert.equal(r.attempts, 3); assert.equal(sha(rx.saved), sha(file)); }
// 3) Drop before any chunk (index 0) still resumes.
{ const rx = new Receiver(); const r = runSender(rx, { dropAfter: [0] }); assert.ok(r.done.ok); assert.equal(sha(rx.saved), sha(file)); }
// 4) An attacker without the resume key cannot continue someone else's partial transfer.
{ const rx = new Receiver(); assert.throws(() => runSender(rx, { dropAfter: [3], tamperResumeKey: true }), /Resume proof invalid/); }
// 5) A proof captured from one handshake cannot be replayed in another (bound to the transcript).
{ const rx = new Receiver(); const a = newPair(); const b = newPair();
  const rk = crypto.randomBytes(32);
  const t1 = crypto.randomBytes(32), t2 = crypto.randomBytes(32);
  assert.ok(!eqb(resumeProof(rk, t1), resumeProof(rk, t2))); void rx; void a; void b; }
console.log('ok: resume model passed (normal, 3 drops, drop at 0, forged proof rejected, proof not replayable)');
