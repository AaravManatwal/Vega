import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vega/core/bundle/vega_bundle.dart';

void main() {
  group('checkPath', () {
    test('accepts normal relative paths', () {
      expect(VegaBundle.checkPath('a.txt'), isNull);
      expect(VegaBundle.checkPath('Trip/Day 1/photo.jpg'), isNull);
    });

    test('refuses dangerous paths', () {
      for (final bad in [
        '',
        '/etc/passwd',
        '../x',
        'a/../x',
        'a/./b',
        'a//b',
        'a\\b',
        'C:evil',
        'a/\u0000b',
        'dir/',
      ]) {
        expect(VegaBundle.checkPath(bad), isNotNull, reason: bad);
      }
    });
  });

  group('pack and extract', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('vegab'));
    tearDown(() => tmp.deleteSync(recursive: true));

    BundleItem item(String rel, List<int> data) {
      final f = File('${tmp.path}/src_${rel.hashCode}')..writeAsBytesSync(data);
      return BundleItem(relativePath: rel, filePath: f.path, size: data.length);
    }

    test('round trip keeps names and bytes, size matches packedSize', () async {
      final items = [
        item('one.txt', [1, 2, 3]),
        item('sub/two.bin', List<int>.generate(100000, (i) => i % 251)),
        item('empty.txt', const []),
      ];
      final packed = <int>[];
      await for (final c in VegaBundle.pack(items)) {
        packed.addAll(c);
      }
      expect(packed.length, VegaBundle.packedSize(items));

      final out = Directory('${tmp.path}/out');
      // Feed in awkward small pieces to test chunk boundaries.
      Stream<List<int>> pieces() async* {
        for (var i = 0; i < packed.length; i += 7) {
          yield packed.sublist(i, i + 7 > packed.length ? packed.length : i + 7);
        }
      }

      final names = await VegaBundle.extract(pieces(), out, maxTotalBytes: packed.length);
      expect(names, ['one.txt', 'sub/two.bin', 'empty.txt']);
      expect(File('${out.path}/one.txt').readAsBytesSync(), [1, 2, 3]);
      expect(File('${out.path}/sub/two.bin').lengthSync(), 100000);
      expect(File('${out.path}/empty.txt').lengthSync(), 0);
    });

    test('a traversal name in the stream is refused and nothing escapes', () async {
      final evil = BytesBuilder()
        ..add('VEGB1\n'.codeUnits)
        ..add([0, 0, 0, 6])
        ..add('../evil'.codeUnits.sublist(0, 6)) // "../evi"
        ..add([0, 0, 0, 0, 0, 0, 0, 1])
        ..add([9])
        ..add([0, 0, 0, 0]);
      final out = Directory('${tmp.path}/out2');
      await expectLater(
        VegaBundle.extract(Stream.value(evil.toBytes()), out, maxTotalBytes: 1000),
        throwsA(isA<BundleFormatException>()),
      );
      expect(File('${tmp.path}/evi').existsSync(), isFalse);
    });

    test('truncated stream and wrong magic are refused', () async {
      final out = Directory('${tmp.path}/out3');
      await expectLater(
        VegaBundle.extract(Stream.value(Uint8List.fromList([1, 2, 3])), out, maxTotalBytes: 10),
        throwsA(isA<BundleFormatException>()),
      );
      await expectLater(
        VegaBundle.extract(
          Stream.value(Uint8List.fromList('VEGB1\n'.codeUnits + [0, 0, 0, 3, 97])),
          out,
          maxTotalBytes: 10,
        ),
        throwsA(isA<BundleFormatException>()),
      );
    });

    test('more data than announced is refused', () async {
      final big = item('big.bin', List<int>.filled(500, 1));
      final packed = <int>[];
      await for (final c in VegaBundle.pack([big])) {
        packed.addAll(c);
      }
      await expectLater(
        VegaBundle.extract(Stream.value(packed), Directory('${tmp.path}/o4'), maxTotalBytes: 100),
        throwsA(isA<BundleFormatException>()),
      );
    });
  });
}
