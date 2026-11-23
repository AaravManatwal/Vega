enum TransferDirection { send, receive }

enum TransferStatus {
  queued,
  connecting,
  transferring,
  paused,
  verifying,
  completed,
  failed,
  cancelled,
}

enum TransportMode {
  lanTcp,
  wifiDirect,
  localHotspot,
  browserPortal,
}

class PeerDevice {
  final String id;
  final String name;
  final String host;
  final int port;
  final String platform;
  final TransportMode transport;
  final String? p2pAddress;

  const PeerDevice({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.platform,
    this.transport = TransportMode.lanTcp,
    this.p2pAddress,
  });

  PeerDevice copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? platform,
    TransportMode? transport,
    String? p2pAddress,
  }) {
    return PeerDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      platform: platform ?? this.platform,
      transport: transport ?? this.transport,
      p2pAddress: p2pAddress ?? this.p2pAddress,
    );
  }
}

class TransferTask {
  final String id;
  final String fileName;
  final int totalBytes;
  final int transferredBytes;
  final double speedBytesPerSec;
  final TransferDirection direction;
  final TransferStatus status;
  final String peerName;
  final String? sha256Hex;
  final bool integrityVerified;
  final bool encrypted;
  final String? savedLocation;
  final String? errorMessage;
  final DateTime updatedAt;

  const TransferTask({
    required this.id,
    required this.fileName,
    required this.totalBytes,
    this.transferredBytes = 0,
    this.speedBytesPerSec = 0,
    required this.direction,
    required this.status,
    required this.peerName,
    this.sha256Hex,
    this.integrityVerified = false,
    this.encrypted = true,
    this.savedLocation,
    this.errorMessage,
    required this.updatedAt,
  });

  double get progress =>
      totalBytes > 0 ? (transferredBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  bool get isActive =>
      status == TransferStatus.queued ||
      status == TransferStatus.connecting ||
      status == TransferStatus.transferring ||
      status == TransferStatus.paused ||
      status == TransferStatus.verifying;

  TransferTask copyWith({
    int? transferredBytes,
    double? speedBytesPerSec,
    TransferStatus? status,
    String? peerName,
    String? sha256Hex,
    bool? integrityVerified,
    bool? encrypted,
    String? savedLocation,
    String? errorMessage,
    DateTime? updatedAt,
  }) {
    return TransferTask(
      id: id,
      fileName: fileName,
      totalBytes: totalBytes,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      direction: direction,
      status: status ?? this.status,
      peerName: peerName ?? this.peerName,
      sha256Hex: sha256Hex ?? this.sha256Hex,
      integrityVerified: integrityVerified ?? this.integrityVerified,
      encrypted: encrypted ?? this.encrypted,
      savedLocation: savedLocation ?? this.savedLocation,
      errorMessage: errorMessage ?? this.errorMessage,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

class AppSettings {
  final String deviceName;
  final int chunkSizeKb;
  final bool encryptTransfers;
  final bool darkMode;

  /// 'en' or 'hi'.
  final String language;

  /// Show a notification when a file arrives or finishes.
  final bool alerts;

  const AppSettings({
    required this.deviceName,
    this.chunkSizeKb = 1024,
    this.encryptTransfers = true,
    this.darkMode = true,
    this.language = 'en',
    this.alerts = true,
  });

  bool get isHindi => language == 'hi';

  AppSettings copyWith({
    String? deviceName,
    int? chunkSizeKb,
    bool? encryptTransfers,
    bool? darkMode,
    String? language,
    bool? alerts,
  }) {
    return AppSettings(
      deviceName: deviceName ?? this.deviceName,
      chunkSizeKb: chunkSizeKb ?? this.chunkSizeKb,
      encryptTransfers: encryptTransfers ?? this.encryptTransfers,
      darkMode: darkMode ?? this.darkMode,
      language: language ?? this.language,
      alerts: alerts ?? this.alerts,
    );
  }
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

String formatSpeed(double bytesPerSec) {
  if (bytesPerSec <= 0) return '0 MB/s';
  if (bytesPerSec < 1024 * 1024) {
    return '${(bytesPerSec / 1024).toStringAsFixed(0)} KB/s';
  }
  return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
}
