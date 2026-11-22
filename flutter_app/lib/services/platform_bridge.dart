import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WifiDirectPeer {
  final String name;
  final String address;
  final String status;

  const WifiDirectPeer({
    required this.name,
    required this.address,
    required this.status,
  });
}

class HotspotInfo {
  final String ssid;
  final String password;
  final List<String> ips;

  const HotspotInfo({
    required this.ssid,
    required this.password,
    required this.ips,
  });
}

class PlatformBridge {
  static const MethodChannel _method =
      MethodChannel('com.manatwal.vega/wifi_direct');
  static const EventChannel _events =
      EventChannel('com.manatwal.vega/wifi_direct_events');
  static const MethodChannel _shareMethod =
      MethodChannel('com.manatwal.vega/share_intent');
  static const EventChannel _shareEvents =
      EventChannel('com.manatwal.vega/share_intent_events');

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  static Stream<Map<String, dynamic>> get events {
    if (!isAndroid) return const Stream.empty();
    return _events
        .receiveBroadcastStream()
        .map((dynamic e) => Map<String, dynamic>.from(e as Map));
  }

  static Stream<List<({String path, String name, int size})>> get shareIntentStream {
    if (!isAndroid) return const Stream.empty();
    return _shareEvents.receiveBroadcastStream().map(_parseSharedList);
  }

  static Future<List<({String path, String name, int size})>> getPendingSharedFiles() async {
    if (!isAndroid) return const [];
    final raw = await _shareMethod.invokeListMethod<dynamic>('getPendingSharedFiles');
    if (raw == null) return const [];
    return _parseSharedList(raw);
  }

  static List<({String path, String name, int size})> _parseSharedList(dynamic raw) {
    final list = (raw as List?) ?? const [];
    return list.map((item) {
      final m = Map<String, dynamic>.from(item as Map);
      return (
        path: m['path'] as String,
        name: m['name'] as String,
        size: (m['size'] as num).toInt(),
      );
    }).toList();
  }

  static Future<bool> discoverWifiDirectPeers() async {
    if (!isAndroid) return false;
    final res = await _method.invokeMethod<bool>('discoverPeers');
    return res ?? false;
  }

  static Future<void> stopWifiDirectDiscovery() async {
    if (!isAndroid) return;
    await _method.invokeMethod('stopDiscovery');
  }

  static Future<bool> connectWifiDirectPeer(String address) async {
    if (!isAndroid) return false;
    final res =
        await _method.invokeMethod<bool>('connectPeer', {'address': address});
    return res ?? false;
  }

  static Future<bool> createWifiDirectGroup() async {
    if (!isAndroid) return false;
    final res = await _method.invokeMethod<bool>('createGroup');
    return res ?? false;
  }

  static Future<void> removeWifiDirectGroup() async {
    if (!isAndroid) return;
    await _method.invokeMethod('removeGroup');
  }

  static Future<HotspotInfo?> startLocalHotspot() async {
    if (!isAndroid) return null;
    final raw =
        await _method.invokeMapMethod<String, dynamic>('startLocalHotspot');
    if (raw == null) return null;
    return HotspotInfo(
      ssid: (raw['ssid'] as String?) ?? 'Vega-AP',
      password: (raw['password'] as String?) ?? '',
      ips: List<String>.from((raw['ips'] as List?) ?? const <String>[]),
    );
  }

  static Future<void> stopLocalHotspot() async {
    if (!isAndroid) return;
    await _method.invokeMethod('stopLocalHotspot');
  }

  static Future<List<String>> getLocalIpv4Addresses() async {
    if (isAndroid) {
      try {
        final ips = await _method.invokeListMethod<String>('getLocalIps');
        if (ips != null && ips.isNotEmpty) return ips;
      } catch (_) {}
    }

    final ips = <String>[];
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
      includeLoopback: false,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (!addr.address.startsWith('169.254.')) {
          ips.add(addr.address);
        }
      }
    }
    return ips;
  }

  static Future<String> saveToDownloads({
    required String sourcePath,
    required String fileName,
    String mimeType = 'application/octet-stream',
  }) async {
    if (isAndroid) {
      final res = await _method.invokeMethod<String>('saveToDownloads', {
        'sourcePath': sourcePath,
        'fileName': fileName,
        'mimeType': mimeType,
      });
      if (res != null && res.isNotEmpty) return res;
    }
    return sourcePath;
  }
}
