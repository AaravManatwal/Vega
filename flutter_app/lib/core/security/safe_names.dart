import 'dart:math';

final RegExp _safeId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
final Random _rng = Random.secure();

/// Task ids arrive from remote peers and end up in file names: allow only a strict charset.
bool isSafeTaskId(String? value) => value != null && _safeId.hasMatch(value);

/// Cryptographically random lowercase hex string of [bytes] bytes.
String randomHex(int bytes) {
  final sb = StringBuffer();
  for (var i = 0; i < bytes; i++) {
    sb.write(_rng.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

/// Turns a peer-supplied name into one safe path segment: no separators, no control
/// characters, never '.', '..' or dot-leading, length-capped (extension preserved).
String sanitizeFileName(String? raw, {String fallback = 'incoming_file'}) {
  if (raw == null) return fallback;
  var name = raw.replaceAll('\\', '/');
  final slash = name.lastIndexOf('/');
  if (slash >= 0) name = name.substring(slash + 1);
  name = name.replaceAll(RegExp(r'[\x00-\x1F\x7F<>:"|?*]'), '_');
  name = name.replaceAll(RegExp(r'^\.+'), '').replaceAll(RegExp(r'[ .]+$'), '');
  if (name.runes.length > 120) {
    final dot = name.lastIndexOf('.');
    final hasExt = dot > 0 && name.length - dot <= 16;
    final ext = hasExt ? name.substring(dot) : '';
    final stem = hasExt ? name.substring(0, dot) : name;
    name = String.fromCharCodes(stem.runes.take(120 - ext.runes.length)) + ext;
  }
  return name.isEmpty ? fallback : name;
}
