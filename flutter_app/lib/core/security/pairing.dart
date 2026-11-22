import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'safe_names.dart';
import 'session_crypto.dart';

String b64u(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

Uint8List fromB64u(String s) {
  final padded = s.padRight((s.length + 3) ~/ 4 * 4, '=');
  return Uint8List.fromList(base64Url.decode(padded));
}

/// What the receiver puts in its QR code: its per-session X25519 public key and a
/// random 128-bit pairing secret. Scanning it is what authenticates the receiver.
class PairingPayload {
  final Uint8List receiverPublicKey;
  final Uint8List psk;
  const PairingPayload({required this.receiverPublicKey, required this.psk});

  String toQuery() => 'v=2&rpk=${b64u(receiverPublicKey)}&psk=${b64u(psk)}';

  static PairingPayload? tryParse(Map<String, String> query) {
    try {
      if (query['v'] != '2') return null;
      final rpk = fromB64u(query['rpk'] ?? '');
      final psk = fromB64u(query['psk'] ?? '');
      if (rpk.length != 32 || psk.length != 16) return null;
      return PairingPayload(receiverPublicKey: rpk, psk: psk);
    } catch (_) {
      return null;
    }
  }
}

/// Receiver-side state behind the QR code. Expires, and is replaced on every new QR.
class PairingOffer {
  static const Duration lifetime = Duration(minutes: 10);
  final SimpleKeyPair keyPair;
  final PairingPayload payload;
  final DateTime expiresAt;
  const PairingOffer({
    required this.keyPair,
    required this.payload,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  static Future<PairingOffer> create() async {
    final kp = await LanV2Crypto.newKeyPair();
    final pub = await LanV2Crypto.publicBytes(kp);
    final psk = Uint8List.fromList(
      List<int>.generate(16, (_) => int.parse(randomHex(1), radix: 16)),
    );
    return PairingOffer(
      keyPair: kp,
      payload: PairingPayload(receiverPublicKey: pub, psk: psk),
      expiresAt: DateTime.now().add(lifetime),
    );
  }
}

/// Reported to the app after each handshake so a UI can show the match code
/// and whether the peer was authenticated by QR.
class HandshakeInfo {
  final String taskId;
  final String sas;
  final bool authenticated;

  /// True on the sending device, false on the receiving one.
  final bool outgoing;
  const HandshakeInfo({
    required this.taskId,
    required this.sas,
    required this.authenticated,
    this.outgoing = false,
  });
}
