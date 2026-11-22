import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vega/core/security/frame_codec.dart';
import 'package:vega/core/security/pairing.dart';
import 'package:vega/core/security/session_crypto.dart';

Uint8List h(String hex) {
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

String toHex(List<int> b) =>
    b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

void main() {
  // Vectors are produced by tools/lan_v2_vectors.mjs using node:crypto only, so this test
  // checks the Dart implementation against an independent one (and against RFC 7748).
  final vectors =
      jsonDecode(File('test/vectors/lan_v2.json').readAsStringSync()) as Map<String, dynamic>;

  test('X25519 matches RFC 7748 section 6.1', () async {
    final alice = await LanV2Crypto.keyPairFromSeed(
      h('77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a'),
    );
    final bobPub = h('de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f');
    final shared = await LanV2Crypto.dh(alice, bobPub);
    expect(toHex(shared), (vectors['rfc7748'] as Map)['sharedHex']);
  });

  for (final raw in vectors['cases'] as List) {
    final c = raw as Map<String, dynamic>;
    final qr = c['qr'] as bool;
    final encrypted = c['encrypted'] as bool;
    test('key schedule and chunk AEAD match reference (qr=$qr encrypted=$encrypted)', () async {
      final p = c['params'] as Map<String, dynamic>;
      final params = HandshakeParams(
        qr: qr,
        encrypted: encrypted,
        totalBytes: p['totalBytes'] as int,
        chunkSize: p['chunkSize'] as int,
        fileName: p['fileName'] as String,
        taskId: p['taskId'] as String,
      );
      final e = await LanV2Crypto.keyPairFromSeed(h((c['ephemeralSender'] as Map)['seed'] as String));
      final f = await LanV2Crypto.keyPairFromSeed(h((c['ephemeralReceiver'] as Map)['seed'] as String));
      final r = await LanV2Crypto.keyPairFromSeed(h((c['staticReceiver'] as Map)['seed'] as String));
      final ePub = await LanV2Crypto.publicBytes(e);
      final fPub = await LanV2Crypto.publicBytes(f);
      final rPub = await LanV2Crypto.publicBytes(r);
      expect(toHex(ePub), (c['ephemeralSender'] as Map)['pub']);
      expect(toHex(rPub), (c['staticReceiver'] as Map)['pub']);

      final th = await LanV2Crypto.transcriptHash(
        params: params,
        ephemeralSender: ePub,
        ephemeralReceiver: fPub,
        staticReceiver: rPub,
      );
      expect(toHex(th), c['transcript']);

      // Both roles must derive the same keys.
      final senderKeys = await LanV2Crypto.derive(
        qr: qr,
        dhEphemeral: await LanV2Crypto.dh(e, fPub),
        dhStatic: qr ? await LanV2Crypto.dh(e, rPub) : null,
        psk: qr ? h(c['psk'] as String) : null,
        transcript: th,
      );
      final receiverKeys = await LanV2Crypto.derive(
        qr: qr,
        dhEphemeral: await LanV2Crypto.dh(f, ePub),
        dhStatic: qr ? await LanV2Crypto.dh(r, ePub) : null,
        psk: qr ? h(c['psk'] as String) : null,
        transcript: th,
      );
      expect(toHex(await senderKeys.sessionKey.extractBytes()), c['sessionKey']);
      expect(toHex(await receiverKeys.sessionKey.extractBytes()), c['sessionKey']);
      expect(toHex(await senderKeys.confirmKey.extractBytes()), c['confirmKey']);
      expect(toHex(await senderKeys.resumeKey.extractBytes()), c['resumeKey']);
      expect(toHex(await receiverKeys.resumeKey.extractBytes()), c['resumeKey']);
      expect(toHex(await LanV2Crypto.resumeProof(senderKeys.resumeKey, th)), c['resumeProof']);
      expect(
        toHex(await LanV2Crypto.resumedConfirm(senderKeys.confirmKey, offset: 3145728, index: 3)),
        c['resumedConfirm'],
      );
      expect(senderKeys.sas, c['sas']);
      expect(receiverKeys.sas, c['sas']);

      expect(
        toHex(await LanV2Crypto.acceptConfirm(senderKeys.confirmKey, th)),
        c['acceptConfirm'],
      );
      final d = c['doneArgs'] as Map<String, dynamic>;
      expect(
        toHex(await LanV2Crypto.doneConfirm(
          senderKeys.confirmKey,
          ok: d['ok'] as bool,
          sha256Hex: d['sha256Hex'] as String,
          bytes: d['bytes'] as int,
        )),
        c['doneConfirm'],
      );

      final ch = c['chunk'] as Map<String, dynamic>;
      final aad = LanV2Crypto.chunkAad(ch['index'] as int, ch['offset'] as int, h(ch['plain'] as String).length);
      expect(toHex(aad), ch['aad']);
      final box = SecretBox(
        h(ch['cipherText'] as String),
        nonce: h(ch['nonce'] as String),
        mac: Mac(h(ch['mac'] as String)),
      );
      final clear = await LanV2Crypto.aes.decrypt(box, secretKey: senderKeys.sessionKey, aad: aad);
      expect(toHex(clear), ch['plain']);

      // Wrong AAD (reordered/replayed chunk) must fail authentication.
      expect(
        () => LanV2Crypto.aes.decrypt(
          box,
          secretKey: senderKeys.sessionKey,
          aad: LanV2Crypto.chunkAad(4, ch['offset'] as int, h(ch['plain'] as String).length),
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });
  }

  test('transcript binds the encrypted flag and file name (downgrade protection)', () async {
    final e = await LanV2Crypto.newKeyPair();
    final f = await LanV2Crypto.newKeyPair();
    final ePub = await LanV2Crypto.publicBytes(e);
    final fPub = await LanV2Crypto.publicBytes(f);
    HandshakeParams mk({bool enc = true, String name = 'a.bin'}) => HandshakeParams(
          qr: false, encrypted: enc, totalBytes: 10, chunkSize: 1024, fileName: name, taskId: 't1');
    Future<String> th(HandshakeParams p) async => toHex(await LanV2Crypto.transcriptHash(
        params: p, ephemeralSender: ePub, ephemeralReceiver: fPub));
    final base = await th(mk());
    expect(await th(mk(enc: false)), isNot(base));
    expect(await th(mk(name: 'b.bin')), isNot(base));
  });

  test('low-order public key is rejected', () async {
    final k = await LanV2Crypto.newKeyPair();
    expect(() => LanV2Crypto.dh(k, Uint8List(32)), throwsA(anything));
  });

  test('pairing payload round-trips and rejects malformed input', () async {
    final offer = await PairingOffer.create();
    final uri = Uri.parse('vega://pair?ip=10.0.0.2&port=47890&${offer.payload.toQuery()}');
    final back = PairingPayload.tryParse(uri.queryParameters);
    expect(back, isNotNull);
    expect(back!.receiverPublicKey, offer.payload.receiverPublicKey);
    expect(back.psk, offer.payload.psk);
    expect(PairingPayload.tryParse({'v': '1'}), isNull);
    expect(PairingPayload.tryParse({'v': '2', 'rpk': 'AAAA', 'psk': 'AAAA'}), isNull);
    expect(offer.isExpired, isFalse);
  });

  test('FrameInbox delivers frames and reports close', () async {
    Uint8List fb(Map<String, dynamic> hdr) {
      final hh = Map<String, dynamic>.from(hdr)..['payloadLen'] = 0;
      final hb = utf8.encode(jsonEncode(hh));
      return Uint8List.fromList([
        ...(ByteData(4)..setUint32(0, hb.length, Endian.big)).buffer.asUint8List(),
        ...hb,
      ]);
    }

    final ctl = Stream<List<int>>.fromIterable([fb({'type': 'accept'})]);
    final inbox = FrameInbox(ctl);
    final first = await inbox.next();
    expect(first.header['type'], 'accept');
    expect(() => inbox.next(timeout: const Duration(milliseconds: 200)),
        throwsA(isA<FrameFormatException>()));
  });
}
