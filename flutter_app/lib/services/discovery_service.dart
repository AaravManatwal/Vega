import 'dart:async';
import 'dart:io';
import 'package:bonsoir/bonsoir.dart';
import '../models/transfer_models.dart';
import 'platform_bridge.dart';

class DiscoveryService {
  static const String serviceType = '_vega._tcp';

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription? _discoverySub;
  StreamSubscription? _p2pSub;

  final Map<String, PeerDevice> _lanPeers = {};
  final Map<String, PeerDevice> _p2pPeers = {};

  final _peersController = StreamController<List<PeerDevice>>.broadcast();
  Stream<List<PeerDevice>> get peersStream => _peersController.stream;

  Future<void> startBroadcast({
    required String deviceName,
    required int tcpPort,
    required String sessionId,
  }) async {
    await stopBroadcast();
    final service = BonsoirService(
      name: deviceName,
      type: serviceType,
      port: tcpPort,
      attributes: {
        'id': sessionId,
        'platform': Platform.operatingSystem,
        'v': '1',
      },
    );
    final broadcast = BonsoirBroadcast(service: service);
    await broadcast.ready;
    await broadcast.start();
    _broadcast = broadcast;
  }

  Future<void> stopBroadcast() async {
    await _broadcast?.stop();
    _broadcast = null;
  }

  Future<void> startDiscovery({required String selfSessionId}) async {
    await stopDiscovery();

    // 1. mDNS / LAN peer discovery (works across Android & Windows on same Wi-Fi/Hotspot)
    final discovery = BonsoirDiscovery(type: serviceType);
    await discovery.ready;
    _discovery = discovery;

    _discoverySub = discovery.eventStream?.listen((event) {
      final service = event.service;
      if (service == null) return;

      if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
        service.resolve(discovery.serviceResolver);
      } else if (event.type ==
          BonsoirDiscoveryEventType.discoveryServiceResolved) {
        if (service is ResolvedBonsoirService) {
          final id = service.attributes['id'] ?? service.name;
          if (id == selfSessionId) return;
          final host = service.host;
          if (host == null || host.isEmpty) return;
          _lanPeers[id] = PeerDevice(
            id: id,
            name: service.name,
            host: host,
            port: service.port,
            platform: service.attributes['platform'] ?? 'unknown',
            transport: TransportMode.lanTcp,
          );
          _emitCombinedPeers();
        }
      } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceLost) {
        final id = service.attributes['id'] ?? service.name;
        _lanPeers.remove(id);
        _emitCombinedPeers();
      }
    });
    await discovery.start();

    // 2. Android Wi-Fi Direct peer discovery (works with zero router/AP)
    if (PlatformBridge.isAndroid) {
      _p2pSub = PlatformBridge.events.listen((event) {
        if (event['type'] == 'peers') {
          _p2pPeers.clear();
          final rawPeers = (event['peers'] as List?) ?? const [];
          for (final item in rawPeers) {
            final map = Map<String, dynamic>.from(item as Map);
            final address = (map['address'] as String?) ?? '';
            if (address.isEmpty) continue;
            _p2pPeers[address] = PeerDevice(
              id: 'p2p-$address',
              name: (map['name'] as String?) ?? 'Android Peer',
              host: '192.168.49.1',
              port: 47890,
              platform: 'android',
              transport: TransportMode.wifiDirect,
              p2pAddress: address,
            );
          }
          _emitCombinedPeers();
        }
      });
      try {
        await PlatformBridge.discoverWifiDirectPeers();
      } catch (_) {}
    }
  }

  Future<void> stopDiscovery() async {
    await _discoverySub?.cancel();
    _discoverySub = null;
    await _discovery?.stop();
    _discovery = null;
    await _p2pSub?.cancel();
    _p2pSub = null;
    if (PlatformBridge.isAndroid) {
      try {
        await PlatformBridge.stopWifiDirectDiscovery();
      } catch (_) {}
    }
    _lanPeers.clear();
    _p2pPeers.clear();
    _emitCombinedPeers();
  }

  void _emitCombinedPeers() {
    if (_peersController.isClosed) return;
    _peersController.add([..._lanPeers.values, ..._p2pPeers.values]);
  }

  Future<void> dispose() async {
    await stopBroadcast();
    await stopDiscovery();
    await _peersController.close();
  }
}
