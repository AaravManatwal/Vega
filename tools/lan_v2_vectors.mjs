// Reference implementation + test-vector generator for the Vega LAN v2 handshake.
// Uses only node:crypto, so it independently checks the Dart implementation (same JSON is read by Dart tests).
import crypto from 'node:crypto';
import fs from 'node:fs';

const LABEL = 'VEGA-LAN-2';
const hex = (b) => Buffer.from(b).toString('hex');
const unhex = (h) => Buffer.from(h, 'hex');

const PKCS8_X25519 = Buffer.from('302e020100300506032b656e04220420', 'hex');
export function privFromSeed(seed) {
  return crypto.createPrivateKey({ key: Buffer.concat([PKCS8_X25519, seed]), format: 'der', type: 'pkcs8' });
}
export function pubRaw(priv) {
  return crypto.createPublicKey(priv).export({ format: 'der', type: 'spki' }).subarray(-32);
}
export function dh(priv, pubBytes) {
  const pub = crypto.createPublicKey({ key: Buffer.concat([Buffer.from('302a300506032b656e032100', 'hex'), pubBytes]), format: 'der', type: 'spki' });
  const out = crypto.diffieHellman({ privateKey: priv, publicKey: pub });
  if (out.every((b) => b === 0)) throw new Error('all-zero shared secret');
  return out;
}
const u16 = (n) => { const b = Buffer.alloc(2); b.writeUInt16BE(n); return b; };
const u32 = (n) => { const b = Buffer.alloc(4); b.writeUInt32BE(n); return b; };
const u64 = (n) => { const b = Buffer.alloc(8); b.writeBigUInt64BE(BigInt(n)); return b; };

export function transcript({ qr, encrypted, e, f, r, totalBytes, chunkSize, fileName, taskId }) {
  const fn = Buffer.from(fileName, 'utf8');
  const id = Buffer.from(taskId, 'utf8');
  return crypto.createHash('sha256').update(Buffer.concat([
    Buffer.from(LABEL, 'utf8'), Buffer.from([0, qr ? 1 : 0, encrypted ? 1 : 0]),
    e, f, qr ? r : Buffer.alloc(0),
    u64(totalBytes), u32(chunkSize), u16(fn.length), fn, u16(id.length), id,
  ])).digest();
}

export function derive({ qr, dhEF, dhER, psk, transcriptHash }) {
  const ikm = qr ? Buffer.concat([dhEF, dhER]) : dhEF;
  const salt = qr ? psk : Buffer.alloc(32);
  const k = (label, len = 32) => Buffer.from(crypto.hkdfSync('sha256', ikm, salt, Buffer.concat([Buffer.from(`${LABEL} ${label}`, 'utf8'), transcriptHash]), len));
  const sasBytes = k('sas');
  const sas = String(sasBytes.readUInt32BE(0) % 1000000).padStart(6, '0');
  return { sessionKey: k('key'), confirmKey: k('confirm'), resumeKey: k('resume'), sas };
}
export const hmac = (key, msg) => crypto.createHmac('sha256', key).update(msg).digest();
export const acceptConfirm = (confirmKey, th) => hmac(confirmKey, Buffer.concat([Buffer.from('accept'), th]));
export const doneConfirm = (confirmKey, ok, sha256Hex, bytes) => hmac(confirmKey, Buffer.from(`done:${ok ? 1 : 0}:${sha256Hex}:${bytes}`, 'utf8'));
export const resumeProof = (resumeKey, th) => hmac(resumeKey, Buffer.concat([Buffer.from('resume'), th]));
export const resumedConfirm = (confirmKey, offset, index) => hmac(confirmKey, Buffer.from(`resumed:${offset}:${index}`, 'utf8'));
export const chunkAad = (index, offset, plainSize) => Buffer.from(`${LABEL} chunk|${index}|${offset}|${plainSize}`, 'utf8');

export function aesGcmSeal(key, nonce, aad, plain) {
  const c = crypto.createCipheriv('aes-256-gcm', key, nonce);
  c.setAAD(aad);
  const ct = Buffer.concat([c.update(plain), c.final()]);
  return { ct, tag: c.getAuthTag() };
}

if (process.argv[1] && process.argv[1].endsWith('lan_v2_vectors.mjs')) {
  // RFC 7748 section 6.1 keys (known-good X25519), plus a fixed third key for R.
  const aSeed = unhex('77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a');
  const bSeed = unhex('5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb');
  const rSeed = Buffer.from(Array.from({ length: 32 }, (_, i) => (i * 7 + 3) & 255));
  const E = privFromSeed(aSeed), F = privFromSeed(bSeed), R = privFromSeed(rSeed);
  const e = pubRaw(E), f = pubRaw(F), r = pubRaw(R);

  // RFC 7748 check: shared(a, B) must be 4a5d9d5b...
  const rfc = hex(dh(E, f));
  if (rfc !== '4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742') throw new Error('RFC 7748 vector mismatch: ' + rfc);
  if (hex(f) !== 'de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f') throw new Error('RFC 7748 public key mismatch');

  const psk = unhex('00112233445566778899aabbccddeeff');
  const params = { totalBytes: 123456789, chunkSize: 1048576, fileName: 'फोटो 1.jpg', taskId: 'task_0123-ABC' };
  const out = { label: LABEL, rfc7748: { sharedHex: rfc }, cases: [] };

  for (const qr of [true, false]) {
    for (const encrypted of [true, false]) {
      const th = transcript({ qr, encrypted, e, f, r, ...params });
      // Both roles must derive identical keys.
      const senderEF = dh(E, f), receiverEF = dh(F, e);
      const senderER = dh(E, r), receiverER = dh(R, e);
      if (!senderEF.equals(receiverEF) || !senderER.equals(receiverER)) throw new Error('DH asymmetry');
      const ks = derive({ qr, dhEF: senderEF, dhER: senderER, psk, transcriptHash: th });
      const kr = derive({ qr, dhEF: receiverEF, dhER: receiverER, psk, transcriptHash: th });
      if (!ks.sessionKey.equals(kr.sessionKey) || ks.sas !== kr.sas) throw new Error('role mismatch');
      const plain = Buffer.from('Vega test chunk ✓'.repeat(5), 'utf8');
      const nonce = Buffer.from('000102030405060708090a0b', 'hex');
      const aad = chunkAad(3, 3145728, plain.length);
      const sealed = aesGcmSeal(ks.sessionKey, nonce, aad, plain);
      const sha = crypto.createHash('sha256').update(plain).digest('hex');
      out.cases.push({
        qr, encrypted, params,
        ephemeralSender: { seed: hex(aSeed), pub: hex(e) },
        ephemeralReceiver: { seed: hex(bSeed), pub: hex(f) },
        staticReceiver: { seed: hex(rSeed), pub: hex(r) },
        psk: hex(psk),
        dhEF: hex(senderEF), dhER: hex(senderER),
        transcript: hex(th),
        sessionKey: hex(ks.sessionKey), confirmKey: hex(ks.confirmKey), resumeKey: hex(ks.resumeKey), sas: ks.sas,
        resumeProof: hex(resumeProof(ks.resumeKey, th)),
        resumedConfirm: hex(resumedConfirm(ks.confirmKey, 3145728, 3)),
        acceptConfirm: hex(acceptConfirm(ks.confirmKey, th)),
        doneConfirm: hex(doneConfirm(ks.confirmKey, true, sha, plain.length)),
        doneArgs: { ok: true, sha256Hex: sha, bytes: plain.length },
        chunk: { index: 3, offset: 3145728, nonce: hex(nonce), plain: hex(plain), aad: hex(aad), cipherText: hex(sealed.ct), mac: hex(sealed.tag) },
      });
    }
  }
  // Tamper checks (must fail): flipped transcript field => different keys.
  const a = transcript({ qr: true, encrypted: true, e, f, r, ...params });
  const b = transcript({ qr: true, encrypted: false, e, f, r, ...params });
  if (a.equals(b)) throw new Error('transcript must bind the encrypted flag');
  fs.writeFileSync(new URL('../flutter_app/test/vectors/lan_v2.json', import.meta.url), JSON.stringify(out, null, 2));
  console.log('ok: wrote', out.cases.length, 'cases; RFC 7748 verified; role symmetry verified; sas sample', out.cases[0].sas);
}
