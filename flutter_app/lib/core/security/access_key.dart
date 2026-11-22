import 'dart:math';

const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
final Random _rng = Random.secure();

/// Random access key for the browser portal (10 symbols x 5 bits = 50 bits).
String generateAccessKey() {
  final sb = StringBuffer();
  for (var i = 0; i < 10; i++) {
    sb.write(_alphabet[_rng.nextInt(_alphabet.length)]);
  }
  return sb.toString();
}

/// Comparison whose duration does not depend on where the strings first differ.
bool constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
