import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Keys and the human-comparable match code produced by one handshake.
class HandshakeKeys {
  final SecretKey sessionKey;
  final SecretKey confirmKey;
  final SecretKey resumeKey;
  final String sas;
  final Uint8List transcript;
  const HandshakeKeys({
    required this.sessionKey,
    required this.confirmKey,
    required this.resumeKey,
    required this.sas,
    required this.transcript,
  });
}

/// Transfer parameters that both sides must agree on; they are bound into the transcript,
/// so a man-in-the-middle cannot change them (for example downgrade to plaintext).
class HandshakeParams {
  final bool qr;
  final bool encrypted;
  final int totalBytes;
  final int chunkSize;
  final String fileName;
  final String taskId;
  const HandshakeParams({
    required this.qr,
    required this.encrypted,
    required this.totalBytes,
    required this.chunkSize,
    required this.fileName,
    required this.taskId,
  });
}

/// Vega LAN v2: X25519 (ephemeral on both sides, optional QR-pinned receiver key)
/// -> HKDF-SHA256 -> AES-256-GCM (hardware accelerated on Android 13+, so no speed loss).
/// Spec: docs/PROTOCOL_LAN_V2.md. Cross-checked against tools/lan_v2_vectors.mjs.
class LanV2Crypto {
  static const String label = 'VEGA-LAN-2';
  static final X25519 _x25519 = X25519();
  static final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static final Hmac _hmac = Hmac.sha256();
  static final AesGcm aes = AesGcm.with256bits();

  static Future<SimpleKeyPair> newKeyPair() => _x25519.newKeyPair();

  static Future<SimpleKeyPair> keyPairFromSeed(List<int> seed) =>
      _x25519.newKeyPairFromSeed(seed);

  static Future<Uint8List> publicBytes(SimpleKeyPair pair) async {
    final pub = await pair.extractPublicKey();
    return Uint8List.fromList(pub.bytes);
  }

  /// X25519 shared secret; rejects the all-zero result produced by low-order points.
  static Future<Uint8List> dh(SimpleKeyPair mine, List<int> theirPublic) async {
    if (theirPublic.length != 32) {
      throw ArgumentError('X25519 public key must be 32 bytes');
    }
    final secret = await _x25519.sharedSecretKey(
      keyPair: mine,
      remotePublicKey: SimplePublicKey(theirPublic, type: KeyPairType.x25519),
    );
    final bytes = Uint8List.fromList(await secret.extractBytes());
    if (bytes.every((b) => b == 0)) {
      throw StateError('Rejected low-order public key');
    }
    return bytes;
  }

  static Uint8List _u16(int n) =>
      (ByteData(2)..setUint16(0, n, Endian.big)).buffer.asUint8List();
  static Uint8List _u32(int n) =>
      (ByteData(4)..setUint32(0, n, Endian.big)).buffer.asUint8List();
  static Uint8List _u64(int n) =>
      (ByteData(8)..setUint64(0, n, Endian.big)).buffer.asUint8List();

  static Future<Uint8List> transcriptHash({
    required HandshakeParams params,
    required List<int> ephemeralSender,
    required List<int> ephemeralReceiver,
    List<int>? staticReceiver,
  }) async {
    final fn = utf8.encode(params.fileName);
    final id = utf8.encode(params.taskId);
    final b = BytesBuilder()
      ..add(utf8.encode(label))
      ..add([0, params.qr ? 1 : 0, params.encrypted ? 1 : 0])
      ..add(ephemeralSender)
      ..add(ephemeralReceiver);
    if (params.qr) {
      if (staticReceiver == null) {
        throw ArgumentError('QR mode requires the receiver static key');
      }
      b.add(staticReceiver);
    }
    b
      ..add(_u64(params.totalBytes))
      ..add(_u32(params.chunkSize))
      ..add(_u16(fn.length))
      ..add(fn)
      ..add(_u16(id.length))
      ..add(id);
    final hash = await Sha256().hash(b.toBytes());
    return Uint8List.fromList(hash.bytes);
  }

  static Future<HandshakeKeys> derive({
    required bool qr,
    required Uint8List dhEphemeral,
    Uint8List? dhStatic,
    Uint8List? psk,
    required Uint8List transcript,
  }) async {
    final ikm = BytesBuilder()..add(dhEphemeral);
    Uint8List salt = Uint8List(32);
    if (qr) {
      if (dhStatic == null || psk == null) {
        throw ArgumentError('QR mode requires the static DH secret and the pairing secret');
      }
      ikm.add(dhStatic);
      salt = psk;
    }
    final ikmKey = SecretKey(ikm.toBytes());
    Future<List<int>> k(String name) async {
      final info = BytesBuilder()
        ..add(utf8.encode('$label $name'))
        ..add(transcript);
      final out = await _hkdf.deriveKey(
        secretKey: ikmKey,
        nonce: salt,
        info: info.toBytes(),
      );
      return out.extractBytes();
    }

    final sessionKey = SecretKey(await k('key'));
    final confirmKey = SecretKey(await k('confirm'));
    final resumeKey = SecretKey(await k('resume'));
    final sasBytes = await k('sas');
    final sasInt = ByteData.sublistView(Uint8List.fromList(sasBytes), 0, 4)
        .getUint32(0, Endian.big);
    return HandshakeKeys(
      sessionKey: sessionKey,
      confirmKey: confirmKey,
      resumeKey: resumeKey,
      sas: (sasInt % 1000000).toString().padLeft(6, '0'),
      transcript: transcript,
    );
  }

  static Future<Uint8List> _mac(SecretKey key, List<int> message) async {
    final mac = await _hmac.calculateMac(message, secretKey: key);
    return Uint8List.fromList(mac.bytes);
  }

  static Future<Uint8List> acceptConfirm(SecretKey confirmKey, List<int> transcript) =>
      _mac(confirmKey, [...utf8.encode('accept'), ...transcript]);

  static Future<Uint8List> doneConfirm(
    SecretKey confirmKey, {
    required bool ok,
    required String sha256Hex,
    required int bytes,
  }) =>
      _mac(confirmKey, utf8.encode('done:${ok ? 1 : 0}:$sha256Hex:$bytes'));

  /// Proof (under the key of the interrupted session) that a reconnecting sender is the same
  /// sender. Bound to the NEW handshake transcript, so it cannot be replayed.
  static Future<Uint8List> resumeProof(SecretKey resumeKey, List<int> newTranscript) =>
      _mac(resumeKey, [...utf8.encode('resume'), ...newTranscript]);

  static Future<Uint8List> resumedConfirm(
    SecretKey confirmKey, {
    required int offset,
    required int index,
  }) =>
      _mac(confirmKey, utf8.encode('resumed:$offset:$index'));

  /// Associated data for one chunk: binds its position so chunks cannot be reordered,
  /// duplicated, replayed from another transfer or truncated without detection.
  static Uint8List chunkAad(int index, int offset, int plainSize) =>
      Uint8List.fromList(utf8.encode('$label chunk|$index|$offset|$plainSize'));

  /// Constant-time byte comparison.
  static bool bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
