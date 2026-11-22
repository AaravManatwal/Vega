import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../core/browser_share_server.dart';
import '../core/bundle/bundle_io.dart';
import '../core/security/pairing.dart';
import '../core/transfer_engine.dart';
import '../models/transfer_models.dart';
import '../services/discovery_service.dart';
import '../services/foreground_service.dart';
import '../services/history_db.dart';
import '../services/platform_bridge.dart';

class VegaState {
  final AppSettings settings;
  final List<PeerDevice> nearbyPeers;
  final Map<String, TransferTask> tasks;
  final List<TransferTask> history;
  final List<String> localIps;
  final int? receiverPort;
  final HotspotInfo? hotspotInfo;
  final bool isReceivingReady;
  final bool isBrowserPortalRunning;
  final int? browserPortalPort;
  /// Query part of the receiver's QR code (`v=2&rpk=..&psk=..`); empty until a session starts.
  final String pairingQuery;

  const VegaState({
    required this.settings,
    this.nearbyPeers = const [],
    this.tasks = const {},
    this.history = const [],
    this.localIps = const [],
    this.receiverPort,
    this.hotspotInfo,
    this.isReceivingReady = false,
    this.isBrowserPortalRunning = false,
    this.browserPortalPort,
    this.pairingQuery = '',
  });

  List<TransferTask> get activeTasks =>
      tasks.values.where((t) => t.isActive).toList();

  VegaState copyWith({
    AppSettings? settings,
    List<PeerDevice>? nearbyPeers,
    Map<String, TransferTask>? tasks,
    List<TransferTask>? history,
    List<String>? localIps,
    int? receiverPort,
    HotspotInfo? hotspotInfo,
    bool clearHotspot = false,
    bool? isReceivingReady,
    bool? isBrowserPortalRunning,
    int? browserPortalPort,
    String? pairingQuery,
  }) {
    return VegaState(
      settings: settings ?? this.settings,
      nearbyPeers: nearbyPeers ?? this.nearbyPeers,
      tasks: tasks ?? this.tasks,
      history: history ?? this.history,
      localIps: localIps ?? this.localIps,
      receiverPort: receiverPort ?? this.receiverPort,
      hotspotInfo: clearHotspot ? null : (hotspotInfo ?? this.hotspotInfo),
      isReceivingReady: isReceivingReady ?? this.isReceivingReady,
      isBrowserPortalRunning:
          isBrowserPortalRunning ?? this.isBrowserPortalRunning,
      browserPortalPort: browserPortalPort ?? this.browserPortalPort,
      pairingQuery: pairingQuery ?? this.pairingQuery,
    );
  }
}

class VegaController extends StateNotifier<VegaState> {
  final TransferEngine engine = TransferEngine();
  final DiscoveryService discovery = DiscoveryService();
  final BrowserShareServer browserServer = BrowserShareServer();
  final String _sessionId = const Uuid().v4();

  StreamSubscription? _peersSub;
  StreamSubscription? _taskSub;
  StreamSubscription? _browserSub;

  VegaController()
      : super(
          const VegaState(
            settings: AppSettings(deviceName: 'Vega Device'),
          ),
        ) {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('device_name') ?? await _detectDeviceName();
    final chunkKb = prefs.getInt('chunk_kb') ?? 1024;
    final encrypt = prefs.getBool('encrypt_transfers') ?? true;
    final dark = prefs.getBool('dark_mode') ?? true;

    final history = await HistoryDb.loadRecent();
    final ips = await PlatformBridge.getLocalIpv4Addresses();

    state = state.copyWith(
      settings: AppSettings(
        deviceName: savedName,
        chunkSizeKb: chunkKb,
        encryptTransfers: encrypt,
        darkMode: dark,
      ),
      history: history,
      localIps: ips,
    );

    _peersSub = discovery.peersStream.listen((peers) {
      state = state.copyWith(nearbyPeers: peers);
    });

    _taskSub = engine.taskUpdates.listen((task) async {
      final updated = Map<String, TransferTask>.from(state.tasks);
      updated[task.id] = task;
      state = state.copyWith(tasks: updated);

      final active = updated.values.where((t) => t.isActive).toList();
      if (active.isNotEmpty) {
        final pct = (active.first.progress * 100).toStringAsFixed(0);
        await ForegroundTransferService.startOrUpdate(
          title: 'Vega • ${active.length} active transfer(s)',
          body: '${active.first.fileName} ($pct% • ${formatSpeed(active.first.speedBytesPerSec)})',
        );
      } else {
        await ForegroundTransferService.stop();
      }

      if (task.status == TransferStatus.completed ||
          task.status == TransferStatus.failed ||
          task.status == TransferStatus.cancelled) {
        await HistoryDb.upsertTask(task);
        final refreshed = await HistoryDb.loadRecent();
        state = state.copyWith(history: refreshed);
      }
    });

    _browserSub = browserServer.receivedFilesStream.listen((task) async {
      await HistoryDb.upsertTask(task);
      final refreshed = await HistoryDb.loadRecent();
      state = state.copyWith(history: refreshed);
    });
  }

  Future<String> _detectDeviceName() async {
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      return '${android.manufacturer} ${android.model}'.trim();
    }
    if (Platform.isWindows) {
      final win = await info.windowsInfo;
      return win.computerName;
    }
    return Platform.localHostname;
  }

  Future<void> ensureNetworkPermissions() async {
    if (!PlatformBridge.isAndroid) return;
    await [
      Permission.nearbyWifiDevices,
      Permission.camera,
      Permission.notification,
    ].request();
  }

  Future<void> startDiscoveringPeers() async {
    await ensureNetworkPermissions();
    final ips = await PlatformBridge.getLocalIpv4Addresses();
    state = state.copyWith(localIps: ips);
    await discovery.startDiscovery(selfSessionId: _sessionId);
  }

  /// Looks for nearby devices without asking for any permission (used by the Home
  /// radar). The Send screen still uses [startDiscoveringPeers], which asks first.
  Future<void> startQuietDiscovery() async {
    try {
      await discovery.startDiscovery(selfSessionId: _sessionId);
    } catch (_) {
      // Discovery is a nice-to-have on Home; Send screen reports real errors.
    }
  }

  Future<void> stopDiscoveringPeers() async {
    await discovery.stopDiscovery();
  }

  Future<void> startReceivingSession({bool withHotspot = false}) async {
    await ensureNetworkPermissions();
    final port = await engine.startTcpReceiver(
      localDeviceName: state.settings.deviceName,
    );
    await discovery.startBroadcast(
      deviceName: state.settings.deviceName,
      tcpPort: port,
      sessionId: _sessionId,
    );

    HotspotInfo? hotspot;
    if (withHotspot && PlatformBridge.isAndroid) {
      try {
        hotspot = await PlatformBridge.startLocalHotspot();
      } catch (_) {}
    }

    final ips = hotspot != null && hotspot.ips.isNotEmpty
        ? hotspot.ips
        : await PlatformBridge.getLocalIpv4Addresses();

    // Fresh X25519 key + random secret for this session's QR code (valid 10 minutes).
    final pairing = await engine.createPairingOffer();

    state = state.copyWith(
      pairingQuery: pairing.toQuery(),
      isReceivingReady: true,
      receiverPort: port,
      hotspotInfo: hotspot,
      localIps: ips,
    );
  }

  Future<void> stopReceivingSession() async {
    await engine.stopTcpReceiver();
    await discovery.stopBroadcast();
    if (state.hotspotInfo != null) {
      await PlatformBridge.stopLocalHotspot();
    }
    state = state.copyWith(
      isReceivingReady: false,
      clearHotspot: true,
    );
  }

  Future<void> sendFilesToPeer({
    required PeerDevice peer,
    required List<({String path, String name, int size})> files,
    PairingPayload? pairing,
  }) async {
    PeerDevice resolvedPeer = peer;
    if (peer.transport == TransportMode.wifiDirect &&
        peer.p2pAddress != null &&
        PlatformBridge.isAndroid) {
      await PlatformBridge.connectWifiDirectPeer(peer.p2pAddress!);
      try {
        final connectedEvent = await PlatformBridge.events
            .firstWhere(
              (e) =>
                  e['type'] == 'connected' &&
                  ((e['groupOwnerAddress'] as String?)?.isNotEmpty ?? false),
            )
            .timeout(const Duration(seconds: 8));
        final goIp = connectedEvent['groupOwnerAddress'] as String;
        resolvedPeer = peer.copyWith(host: goIp);
      } catch (_) {
        // Fallback to default Wi-Fi Direct Group Owner IP (192.168.49.1)
      }
    }

    // Several files go as ONE bundle so the receiver approves once, not per file.
    final toSend = files.length > 1 ? [await BundleIo.packForSend(files)] : files;

    for (final file in toSend) {
      final taskId = const Uuid().v4();
      final initialTask = TransferTask(
        id: taskId,
        fileName: file.name,
        totalBytes: file.size,
        direction: TransferDirection.send,
        status: TransferStatus.queued,
        peerName: resolvedPeer.name,
        encrypted: state.settings.encryptTransfers,
        updatedAt: DateTime.now(),
      );
      final updated = Map<String, TransferTask>.from(state.tasks);
      updated[taskId] = initialTask;
      state = state.copyWith(tasks: updated);

      await engine.sendFile(
        taskId: taskId,
        filePath: file.path,
        fileName: file.name,
        totalBytes: file.size,
        targetPeer: resolvedPeer,
        senderName: state.settings.deviceName,
        chunkSizeKb: state.settings.chunkSizeKb,
        encrypted: state.settings.encryptTransfers,
        pairing: pairing,
      );
    }
  }

  Future<void> toggleBrowserPortal(List<SharedBrowserFile> files) async {
    browserServer.setSharedFiles(files);
    if (state.isBrowserPortalRunning) {
      await browserServer.stop();
      state = state.copyWith(isBrowserPortalRunning: false);
    } else {
      final port = await browserServer.start();
      final ips = await PlatformBridge.getLocalIpv4Addresses();
      state = state.copyWith(
        isBrowserPortalRunning: true,
        browserPortalPort: port,
        localIps: ips,
      );
    }
  }

  void updateSharedBrowserFiles(List<SharedBrowserFile> files) {
    browserServer.setSharedFiles(files);
  }

  Future<void> updateSettings(AppSettings next) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_name', next.deviceName);
    await prefs.setInt('chunk_kb', next.chunkSizeKb);
    await prefs.setBool('encrypt_transfers', next.encryptTransfers);
    await prefs.setBool('dark_mode', next.darkMode);
    state = state.copyWith(settings: next);
  }

  Future<void> clearHistory() async {
    await HistoryDb.clearAll();
    state = state.copyWith(history: const []);
  }

  @override
  void dispose() {
    _peersSub?.cancel();
    _taskSub?.cancel();
    _browserSub?.cancel();
    engine.dispose();
    discovery.dispose();
    browserServer.dispose();
    super.dispose();
  }
}

final vegaProvider =
    StateNotifierProvider<VegaController, VegaState>(
  (ref) => VegaController(),
);
