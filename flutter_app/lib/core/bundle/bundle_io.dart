import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../services/platform_bridge.dart';
import '../security/safe_names.dart';
import 'vega_bundle.dart';

typedef SendFile = ({String path, String name, int size});

/// Glue between the bundle format and the app: packing for the sender, unpacking for
/// the receiver. Kept out of the transfer engine so the network path stays untouched.
class BundleIo {
  BundleIo._();

  static const String _dirName = 'vega_bundles';

  /// Cuts [n] to at most [maxBytes] UTF-8 bytes (whole characters), keeping the extension.
  static String _cap(String n, int maxBytes) {
    if (utf8.encode(n).length <= maxBytes) return n;
    final ext = p.extension(n);
    final keep = (ext.isNotEmpty && utf8.encode(ext).length <= 20) ? ext : '';
    final budget = maxBytes - utf8.encode(keep).length;
    final stem = keep.isEmpty ? n : n.substring(0, n.length - keep.length);
    final out = StringBuffer();
    var used = 0;
    for (final rune in stem.runes) {
      final ch = String.fromCharCode(rune);
      final len = utf8.encode(ch).length;
      if (used + len > budget) break;
      out.write(ch);
      used += len;
    }
    return '$out$keep';
  }

  /// A file name that is always legal inside a bundle.
  static String safeName(String raw) {
    var n = raw.replaceAll(RegExp(r'[\\/:\x00-\x1f\x7f]'), '_').trim();
    if (n.isEmpty || n == '.' || n == '..') n = 'file';
    return _cap(n, 200);
  }

  /// Unique, safe names for [files] ("a.jpg", "a (2).jpg", ...).
  static List<BundleItem> itemsFor(List<SendFile> files) {
    final used = <String>{};
    final items = <BundleItem>[];
    for (final f in files) {
      final base = safeName(f.name);
      var name = base;
      var i = 2;
      while (!used.add(name.toLowerCase())) {
        final ext = p.extension(base);
        final stem = base.substring(0, base.length - ext.length);
        name = _cap('$stem ($i)$ext', 240);
        i++;
      }
      items.add(BundleItem(relativePath: name, filePath: f.path, size: f.size));
    }
    return items;
  }

  /// Packs several files into one `.vegabundle` in the cache and returns it as one
  /// sendable file. Old bundles from earlier sends are removed first.
  static Future<SendFile> packForSend(List<SendFile> files) async {
    final cache = await getTemporaryDirectory();
    final root = Directory(p.join(cache.path, _dirName));
    await root.create(recursive: true);
    // Remove only OLD bundles: an earlier send may still be streaming or resuming.
    try {
      final cutoff = DateTime.now().subtract(const Duration(hours: 2));
      await for (final e in root.list()) {
        if (e is Directory && (await e.stat()).modified.isBefore(cutoff)) {
          try {
            await e.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}
    final dir = Directory(p.join(root.path, 'b${DateTime.now().microsecondsSinceEpoch}'));
    await dir.create(recursive: true);

    // Use the real on-disk sizes: the picker's number can be stale.
    final real = <SendFile>[
      for (final f in files) (path: f.path, name: f.name, size: await File(f.path).length()),
    ];
    final items = itemsFor(real);
    final out = File(p.join(dir.path, 'bundle_${DateTime.now().microsecondsSinceEpoch}.bin'));
    final sink = out.openWrite();
    try {
      await sink.addStream(VegaBundle.pack(items));
    } finally {
      await sink.close();
    }
    final size = await out.length();
    return (
      path: out.path,
      name: '${items.length} files${VegaBundle.suffix}',
      size: size,
    );
  }

  static bool isBundleName(String fileName) => fileName.endsWith(VegaBundle.suffix);

  /// Receiver: open a VERIFIED bundle, hand every file to the Downloads folder, and
  /// return a short summary for the history. Throws [BundleFormatException] on bad data.
  static Future<String> unpackAndSave(File bundleFile) async {
    final cache = await getTemporaryDirectory();
    final dir = Directory(p.join(cache.path, 'vega_unpack_${DateTime.now().microsecondsSinceEpoch}'));
    try {
      final size = await bundleFile.length();
      final names = await VegaBundle.extract(
        bundleFile.openRead(),
        dir,
        maxTotalBytes: size,
      );
      for (final name in names) {
        // Names are flat for now (see docs/DESIGN_BATCH_FOLDER.md); keep the last part only.
        final flat = name.split('/').join(' - ');
        await PlatformBridge.saveToDownloads(
          sourcePath: p.join(dir.path, name),
          fileName: sanitizeFileName(flat),
        );
      }
      return '${names.length} files, Downloads';
    } finally {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  }
}
