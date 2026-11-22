import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// One file that goes into a bundle.
class BundleItem {
  const BundleItem({required this.relativePath, required this.filePath, required this.size});

  /// Path inside the bundle, always with `/` (for example `Trip/photo1.jpg`).
  final String relativePath;
  final String filePath;
  final int size;
}

class BundleFormatException implements Exception {
  const BundleFormatException(this.message);
  final String message;
  @override
  String toString() => 'Bundle error: $message';
}

/// Plain (uncompressed) container for many files / a folder, sent as ONE transfer.
///
/// Layout: magic `VEGB1\n`, then per file `[u32 BE nameLen][name UTF-8][u64 BE size][bytes]`,
/// then `[u32 0]`. It is only ever opened AFTER the transfer's authenticated `done`.
class VegaBundle {
  VegaBundle._();

  static const String suffix = '.vegabundle';
  static final Uint8List _magic = Uint8List.fromList(utf8.encode('VEGB1\n'));

  static const int maxEntries = 20000;
  static const int maxNameBytes = 1024;
  static const int maxSegmentBytes = 255;

  /// Returns null when [name] is safe, otherwise the reason it is refused.
  static String? checkPath(String name) {
    if (name.isEmpty) return 'empty name';
    if (utf8.encode(name).length > maxNameBytes) return 'name too long';
    if (name.startsWith('/')) return 'absolute path';
    for (final unit in name.codeUnits) {
      if (unit < 0x20 || unit == 0x7f) return 'control character';
      if (unit == 0x5c) return 'backslash'; // \
      if (unit == 0x3a) return 'colon'; // :
    }
    for (final seg in name.split('/')) {
      if (seg.isEmpty) return 'empty segment';
      if (seg == '.' || seg == '..') return 'dot segment';
      if (utf8.encode(seg).length > maxSegmentBytes) return 'segment too long';
    }
    return null;
  }

  /// Exact number of bytes [pack] will produce for [items].
  static int packedSize(List<BundleItem> items) {
    var total = _magic.length + 4;
    for (final it in items) {
      total += 4 + utf8.encode(it.relativePath).length + 8 + it.size;
    }
    return total;
  }

  /// Streams the bundle. Fails if a file changed size while packing.
  static Stream<List<int>> pack(List<BundleItem> items) async* {
    if (items.length > maxEntries) {
      throw const BundleFormatException('too many files');
    }
    final seen = <String>{};
    for (final it in items) {
      final bad = checkPath(it.relativePath);
      if (bad != null) throw BundleFormatException('${it.relativePath}: $bad');
      if (!seen.add(it.relativePath)) {
        throw BundleFormatException('duplicate ${it.relativePath}');
      }
    }
    yield _magic;
    for (final it in items) {
      final nameBytes = utf8.encode(it.relativePath);
      final head = ByteData(4 + nameBytes.length + 8);
      head.setUint32(0, nameBytes.length);
      final bytes = head.buffer.asUint8List();
      bytes.setRange(4, 4 + nameBytes.length, nameBytes);
      head.setUint64(4 + nameBytes.length, it.size);
      yield bytes;

      var sent = 0;
      await for (final chunk in File(it.filePath).openRead()) {
        sent += chunk.length;
        if (sent > it.size) {
          throw BundleFormatException('${it.relativePath} grew while packing');
        }
        yield chunk;
      }
      if (sent != it.size) {
        throw BundleFormatException('${it.relativePath} changed size while packing');
      }
    }
    yield Uint8List(4); // end marker: nameLen = 0
  }

  /// Unpacks [source] into [outDir]. Every name is checked first; nothing outside
  /// [outDir] is ever touched. Returns the relative paths that were written.
  static Future<List<String>> extract(
    Stream<List<int>> source,
    Directory outDir, {
    required int maxTotalBytes,
  }) async {
    final pull = _Pull(StreamIterator<List<int>>(source));
    final written = <String>[];
    final seen = <String>{};
    var total = 0;
    try {
      final magic = await pull.take(_magic.length);
      for (var i = 0; i < _magic.length; i++) {
        if (magic[i] != _magic[i]) throw const BundleFormatException('not a Vega bundle');
      }
      await outDir.create(recursive: true);
      final root = outDir.absolute.path;

      while (true) {
        final nameLen = ByteData.sublistView(await pull.take(4)).getUint32(0);
        if (nameLen == 0) break;
        if (nameLen > maxNameBytes) throw const BundleFormatException('name too long');
        if (written.length >= maxEntries) throw const BundleFormatException('too many files');

        final String name;
        try {
          name = utf8.decode(await pull.take(nameLen));
        } on FormatException {
          throw const BundleFormatException('bad file name');
        }
        final bad = checkPath(name);
        if (bad != null) throw BundleFormatException('$name: $bad');
        if (!seen.add(name)) throw BundleFormatException('duplicate $name');

        final size = ByteData.sublistView(await pull.take(8)).getUint64(0);
        total += size;
        if (size < 0 || total > maxTotalBytes) {
          throw const BundleFormatException('bundle larger than announced');
        }

        final target = File('$root/$name');
        await target.parent.create(recursive: true);
        final sink = target.openWrite();
        try {
          var left = size;
          while (left > 0) {
            final part = await pull.takeUpTo(left);
            sink.add(part);
            left -= part.length;
          }
        } finally {
          await sink.close();
        }
        written.add(name);
      }
      return written;
    } finally {
      await pull.close();
    }
  }
}

/// Pulls exact byte counts out of a stream of chunks.
class _Pull {
  _Pull(this._it);
  final StreamIterator<List<int>> _it;
  List<int> _buf = const [];
  int _pos = 0;

  Future<bool> _fill() async {
    while (_pos >= _buf.length) {
      if (!await _it.moveNext()) return false;
      _buf = _it.current;
      _pos = 0;
    }
    return true;
  }

  Future<Uint8List> take(int n) async {
    final out = BytesBuilder(copy: false);
    var need = n;
    while (need > 0) {
      final part = await takeUpTo(need);
      out.add(part);
      need -= part.length;
    }
    return out.takeBytes();
  }

  /// 1..[max] bytes; throws when the stream ended early.
  Future<Uint8List> takeUpTo(int max) async {
    if (!await _fill()) throw const BundleFormatException('file ended early');
    final k = max < _buf.length - _pos ? max : _buf.length - _pos;
    final part = Uint8List.fromList(_buf.sublist(_pos, _pos + k));
    _pos += k;
    return part;
  }

  Future<void> close() => _it.cancel();
}
