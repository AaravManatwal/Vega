import 'dart:async';
import 'dart:io';
import 'package:cryptography/cryptography.dart';

/// A receive that was interrupted by a dropped connection and is waiting for the same
/// sender to reconnect. Kept in memory only; expires, and its temp file is deleted then.
class PartialTransfer {
  static const Duration lifetime = Duration(minutes: 10);
  static const int maxParked = 4;

  final String taskId;
  final String rawFileName;
  final String fileName;
  final String senderName;
  final int totalBytes;
  final int chunkSize;
  final bool encrypted;
  final File file;

  /// Bytes already written (always a whole number of verified chunks).
  final int bytes;
  final int nextIndex;

  /// Key of the interrupted session; a reconnecting sender must prove it holds it.
  final SecretKey resumeKey;
  Timer? timer;

  PartialTransfer({
    required this.taskId,
    required this.rawFileName,
    required this.fileName,
    required this.senderName,
    required this.totalBytes,
    required this.chunkSize,
    required this.encrypted,
    required this.file,
    required this.bytes,
    required this.nextIndex,
    required this.resumeKey,
  });

  /// The reconnecting sender must describe exactly the same transfer.
  bool matches({
    required String rawFileName,
    required int totalBytes,
    required int chunkSize,
    required bool encrypted,
  }) =>
      this.rawFileName == rawFileName &&
      this.totalBytes == totalBytes &&
      this.chunkSize == chunkSize &&
      this.encrypted == encrypted;

  Future<void> deleteFile() async {
    timer?.cancel();
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
