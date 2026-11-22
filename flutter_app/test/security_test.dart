import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vega/core/security/access_key.dart';
import 'package:vega/core/security/frame_codec.dart';
import 'package:vega/core/security/safe_names.dart';

Uint8List frameBytes(Map<String, dynamic> header, [List<int> payload = const []]) {
  final h = Map<String, dynamic>.from(header)..['payloadLen'] = payload.length;
  final hb = utf8.encode(jsonEncode(h));
  final out = BytesBuilder();
  out.add((ByteData(4)..setUint32(0, hb.length, Endian.big)).buffer.asUint8List());
  out.add(hb);
  out.add(payload);
  return out.toBytes();
}

void main() {
  group('FrameReader', () {
    test('parses frames split at arbitrary byte boundaries', () {
      final payload = List<int>.generate(5000, (i) => i % 251);
      final all = BytesBuilder()
        ..add(frameBytes({'type': 'init', 'id': 'a'}))
        ..add(frameBytes({'type': 'chunk', 'index': 0}, payload))
        ..add(frameBytes({'type': 'complete'}));
      final bytes = all.toBytes();
      for (final step in [1, 3, 7, 64, 1000, bytes.length]) {
        final r = FrameReader();
        final got = <WireFrame>[];
        for (var i = 0; i < bytes.length; i += step) {
          r.add(bytes.sublist(i, (i + step).clamp(0, bytes.length)));
          for (WireFrame? f = r.next(); f != null; f = r.next()) {
            got.add(f);
          }
        }
        expect(got.map((f) => f.header['type']), ['init', 'chunk', 'complete']);
        expect(got[1].payload, payload);
        expect(r.bufferedBytes, 0);
      }
    });

    test('rejects oversized header length', () {
      final r = FrameReader()..add([0x7f, 0xff, 0xff, 0xff, 1, 2, 3]);
      expect(() => r.next(), throwsA(isA<FrameFormatException>()));
    });

    test('rejects oversized or negative payload length', () {
      final hb = utf8.encode(jsonEncode({'type': 'chunk', 'payloadLen': 1 << 30}));
      final b = BytesBuilder()
        ..add((ByteData(4)..setUint32(0, hb.length, Endian.big)).buffer.asUint8List())
        ..add(hb);
      final r = FrameReader()..add(b.toBytes());
      expect(() => r.next(), throwsA(isA<FrameFormatException>()));
    });

    test('rejects non-JSON and non-object headers', () {
      final hb = utf8.encode('[1,2,3]');
      final b = BytesBuilder()
        ..add((ByteData(4)..setUint32(0, hb.length, Endian.big)).buffer.asUint8List())
        ..add(hb);
      expect(() => (FrameReader()..add(b.toBytes())).next(), throwsA(isA<FrameFormatException>()));
      final junk = utf8.encode('{not json');
      final c = BytesBuilder()
        ..add((ByteData(4)..setUint32(0, junk.length, Endian.big)).buffer.asUint8List())
        ..add(junk);
      expect(() => (FrameReader()..add(c.toBytes())).next(), throwsA(isA<FrameFormatException>()));
    });

    test('handles many 1 MB frames without quadratic slowdown', () {
      final payload = Uint8List(1024 * 1024);
      final bytes = frameBytes({'type': 'chunk'}, payload);
      final r = FrameReader();
      final sw = Stopwatch()..start();
      var count = 0;
      for (var n = 0; n < 50; n++) {
        for (var i = 0; i < bytes.length; i += 16 * 1024) {
          r.add(bytes.sublist(i, (i + 16 * 1024).clamp(0, bytes.length)));
          for (WireFrame? f = r.next(); f != null; f = r.next()) {
            count++;
          }
        }
      }
      expect(count, 50);
      expect(sw.elapsedMilliseconds, lessThan(5000));
    });
  });

  group('names', () {
    test('sanitizeFileName never returns dot names or separators', () {
      for (final bad in ['..', '.', '', '...', '../..', 'a/../..', r'..\..', ' .. ', null]) {
        final out = sanitizeFileName(bad);
        expect(out, isNot('..'));
        expect(out, isNot('.'));
        expect(out, isNotEmpty);
        expect(out.contains('/'), isFalse);
        expect(out.contains(r'\'), isFalse);
      }
      expect(sanitizeFileName('../etc/passwd'), 'passwd');
      expect(sanitizeFileName('फोटो 1.jpg'), 'फोटो 1.jpg');
      expect(sanitizeFileName('${'x' * 300}.jpg').endsWith('.jpg'), isTrue);
      expect(sanitizeFileName('${'x' * 300}.jpg').runes.length <= 120, isTrue);
    });

    test('isSafeTaskId is strict', () {
      expect(isSafeTaskId('task_1-A'), isTrue);
      for (final bad in ['..', '', 'a/b', 'a b', '../x', 'x' * 65, null]) {
        expect(isSafeTaskId(bad), isFalse);
      }
    });

    test('randomHex and access keys', () {
      expect(randomHex(8).length, 16);
      expect(randomHex(8), isNot(randomHex(8)));
      final k = generateAccessKey();
      expect(RegExp(r'^[A-HJ-NP-Z2-9]{10}$').hasMatch(k), isTrue);
      expect(constantTimeEquals(k, k), isTrue);
      expect(constantTimeEquals(k, '${k.substring(0, 9)}Z'), k.endsWith('Z'));
      expect(constantTimeEquals('a', 'ab'), isFalse);
    });
  });
}
