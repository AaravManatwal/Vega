import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/transfer_models.dart';

class HistoryDb {
  static Database? _db;

  static bool get _useSqflite => Platform.isAndroid || Platform.isIOS;

  static Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'vega_history.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transfers (
            id TEXT PRIMARY KEY,
            fileName TEXT NOT NULL,
            totalBytes INTEGER NOT NULL,
            direction TEXT NOT NULL,
            status TEXT NOT NULL,
            peerName TEXT NOT NULL,
            sha256Hex TEXT,
            integrityVerified INTEGER NOT NULL,
            encrypted INTEGER NOT NULL,
            savedLocation TEXT,
            updatedAt INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  static Future<File> _desktopFile() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);
    return File(p.join(dir.path, 'vega_history.json'));
  }

  static Future<void> upsertTask(TransferTask task) async {
    if (!_useSqflite) {
      final list = await loadRecent(limit: 200);
      final filtered = list.where((e) => e.id != task.id).toList();
      filtered.insert(0, task);
      final file = await _desktopFile();
      final payload = filtered.take(200).map(_toRow).toList();
      await file.writeAsString(jsonEncode(payload));
      return;
    }

    final db = await _open();
    await db.insert(
      'transfers',
      _toRow(task),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<TransferTask>> loadRecent({int limit = 50}) async {
    if (!_useSqflite) {
      final file = await _desktopFile();
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .take(limit)
          .map((e) => _fromRow(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    final db = await _open();
    final rows = await db.query(
      'transfers',
      orderBy: 'updatedAt DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  static Future<void> clearAll() async {
    if (!_useSqflite) {
      final file = await _desktopFile();
      if (await file.exists()) await file.delete();
      return;
    }
    final db = await _open();
    await db.delete('transfers');
  }

  static Map<String, Object?> _toRow(TransferTask task) => {
        'id': task.id,
        'fileName': task.fileName,
        'totalBytes': task.totalBytes,
        'direction': task.direction.name,
        'status': task.status.name,
        'peerName': task.peerName,
        'sha256Hex': task.sha256Hex,
        'integrityVerified': task.integrityVerified ? 1 : 0,
        'encrypted': task.encrypted ? 1 : 0,
        'savedLocation': task.savedLocation,
        'updatedAt': task.updatedAt.millisecondsSinceEpoch,
      };

  static TransferTask _fromRow(Map<String, dynamic> row) {
    return TransferTask(
      id: row['id'] as String,
      fileName: row['fileName'] as String,
      totalBytes: row['totalBytes'] as int,
      transferredBytes: row['totalBytes'] as int,
      direction: TransferDirection.values.firstWhere(
        (e) => e.name == row['direction'],
        orElse: () => TransferDirection.send,
      ),
      status: TransferStatus.values.firstWhere(
        (e) => e.name == row['status'],
        orElse: () => TransferStatus.completed,
      ),
      peerName: row['peerName'] as String,
      sha256Hex: row['sha256Hex'] as String?,
      integrityVerified: (row['integrityVerified'] as int) == 1,
      encrypted: (row['encrypted'] as int) == 1,
      savedLocation: row['savedLocation'] as String?,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updatedAt'] as int),
    );
  }
}
