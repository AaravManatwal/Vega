import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/security/pairing.dart';
import '../models/transfer_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class RadarDiscoveryScreen extends ConsumerStatefulWidget {
  final List<({String path, String name, int size})> filesToSend;

  const RadarDiscoveryScreen({super.key, required this.filesToSend});

  @override
  ConsumerState<RadarDiscoveryScreen> createState() =>
      _RadarDiscoveryScreenState();
}

class _RadarDiscoveryScreenState extends ConsumerState<RadarDiscoveryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radarController;
  PairingPayload? _scannedPairing;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(vegaProvider.notifier).startDiscoveringPeers();
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _scanQr() async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _RadarQrScannerPage()),
    );
    if (scanned == null) return;
    final uri = Uri.tryParse(scanned);
    if (uri != null && uri.scheme == 'vega') {
      final ip = uri.queryParameters['ip'] ?? '';
      final port = int.tryParse(uri.queryParameters['port'] ?? '') ?? 47890;
      _scannedPairing = PairingPayload.tryParse(uri.queryParameters);
      if (ip.isNotEmpty) {
        await _sendToPeer(
          PeerDevice(
            id: 'qr-$ip',
            name: 'QR Peer ($ip)',
            host: ip,
            port: port,
            platform: 'android',
          ),
        );
      }
    }
  }

  Future<void> _sendToPeer(PeerDevice peer) async {
    HapticFeedback.mediumImpact();
    await ref.read(vegaProvider.notifier).sendFilesToPeer(
          peer: peer,
          files: widget.filesToSend,
          pairing: _scannedPairing,
        );
  }

  Future<void> _promptManualIp() async {
    final ipCtrl = TextEditingController();
    final portCtrl = TextEditingController(text: '47890');
    final peer = await showDialog<PeerDevice>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VegaColors.cardMidnight,
        title: const Text(
          'Connect by IP Address',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Receiver IP (e.g. 192.168.43.1)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: portCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Port',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: VegaColors.vibrantOrange,
            ),
            onPressed: () {
              final host = ipCtrl.text.trim();
              final port = int.tryParse(portCtrl.text) ?? 47890;
              if (host.isEmpty) return;
              Navigator.pop(
                ctx,
                PeerDevice(
                  id: 'manual-$host',
                  name: host,
                  host: host,
                  port: port,
                  platform: 'direct',
                ),
              );
            },
            child: const Text('Connect & Send'),
          ),
        ],
      ),
    );
    if (peer != null) {
      await _sendToPeer(peer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vegaProvider);
    final controller = ref.read(vegaProvider.notifier);
    final peers = state.nearbyPeers;
    final sendTasks = state.tasks.values
        .where((t) => t.direction == TransferDirection.send)
        .toList();

    return Scaffold(
      backgroundColor: VegaColors.deepCanvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Decorative Header with Gold-Leaf #C5A059 Trim
              Container(
                padding: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: VegaColors.sandstoneGold.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: VegaColors.midnightBlue,
                          border: Border.all(
                            color: VegaColors.sandstoneGold.withValues(alpha: 0.55),
                          ),
                        ),
                        child: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Searching Nearby',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            "Make sure receiver's visibility is turned on",
                            style: TextStyle(
                              color: VegaColors.goldHighlight,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Scan Receiver QR',
                      icon: const Icon(
                        Icons.qr_code_scanner,
                        color: VegaColors.goldHighlight,
                      ),
                      onPressed: _scanQr,
                    ),
                    IconButton(
                      tooltip: 'Manual IP',
                      icon: const Icon(Icons.lan_outlined, color: Colors.white),
                      onPressed: _promptManualIp,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Animated Sweeping Orange Radar matching Photo 3
              Expanded(
                flex: 5,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = math.min(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    return Center(
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _radarController,
                              builder: (_, __) => CustomPaint(
                                size: Size(size, size),
                                painter: _OrangeRadarPainter(
                                  angle: _radarController.value * 2 * math.pi,
                                ),
                              ),
                            ),
                            // Center Electric Blue + Gold-Leaf Send Beacon
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: VegaColors.electricBlue,
                                border: Border.all(
                                  color: VegaColors.sandstoneGold,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: VegaColors.electricBlue
                                        .withValues(alpha: 0.55),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.arrow_upward_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            // Plot discovered peer icons on radar rings
                            ...peers.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final peer = entry.value;
                              final theta = (idx / math.max(peers.length, 1)) *
                                      2 *
                                      math.pi -
                                  math.pi * 0.7;
                              final radius = size * 0.30;
                              return Transform.translate(
                                offset: Offset(
                                  math.cos(theta) * radius,
                                  math.sin(theta) * radius,
                                ),
                                child: GestureDetector(
                                  onTap: () => _sendToPeer(peer),
                                  child: Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: VegaColors.deepNavy,
                                      border: Border.all(
                                        color: VegaColors.sandstoneGold,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      peer.platform == 'windows' ||
                                              peer.platform == 'macos'
                                          ? Icons.laptop_mac
                                          : Icons.smartphone,
                                      color: VegaColors.goldHighlight,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Discovered Devices Nearby / Live Transfer Panel
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: VegaColors.deepNavy,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: VegaColors.sandstoneGold.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        sendTasks.isNotEmpty
                            ? 'Active Transfers'
                            : 'Discovered devices nearby',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: sendTasks.isNotEmpty
                            ? ListView.separated(
                                itemCount: sendTasks.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final task = sendTasks[i];
                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: VegaColors.deepCanvas,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: VegaColors.vibrantOrange
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                task.fileName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              task.status.name.toUpperCase(),
                                              style: const TextStyle(
                                                color: VegaColors
                                                    .vibrantOrange,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        LinearProgressIndicator(
                                          value: task.progress,
                                          color: VegaColors.vibrantOrange,
                                          backgroundColor:
                                              VegaColors.borderMidnight,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${formatBytes(task.transferredBytes)} / ${formatBytes(task.totalBytes)} • ${formatSpeed(task.speedBytesPerSec)}',
                                              style: const TextStyle(
                                                color:
                                                    VegaColors.lightSky,
                                                fontSize: 11.5,
                                              ),
                                            ),
                                            if (task.isActive)
                                              Row(
                                                children: [
                                                  IconButton(
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    icon: Icon(
                                                      task.status ==
                                                              TransferStatus
                                                                  .paused
                                                          ? Icons.play_arrow
                                                          : Icons.pause,
                                                      color: Colors.white,
                                                      size: 18,
                                                    ),
                                                    onPressed: () {
                                                      if (task.status ==
                                                          TransferStatus
                                                              .paused) {
                                                        controller.engine
                                                            .resumeTransfer(
                                                                task.id);
                                                      } else {
                                                        controller.engine
                                                            .pauseTransfer(
                                                                task.id);
                                                      }
                                                    },
                                                  ),
                                                  IconButton(
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    icon: const Icon(
                                                      Icons.close,
                                                      color: Colors.white70,
                                                      size: 18,
                                                    ),
                                                    onPressed: () => controller
                                                        .engine
                                                        .cancelTransfer(
                                                            task.id),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              )
                            : peers.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Scanning Wi-Fi Direct & LAN mDNS...\nOr tap QR / IP icon above.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: VegaColors.lightSky,
                                        fontSize: 13,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: peers.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (_, i) {
                                      final peer = peers[i];
                                      return InkWell(
                                        onTap: () => _sendToPeer(peer),
                                        borderRadius: BorderRadius.circular(14),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: VegaColors.deepCanvas,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                              color: VegaColors
                                                  .borderMidnight,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                peer.platform == 'windows' ||
                                                        peer.platform == 'macos'
                                                    ? Icons.laptop_mac
                                                    : Icons.smartphone,
                                                color: VegaColors
                                                    .vibrantOrange,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  peer.name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: VegaColors
                                                      .cardMidnight,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  peer.transport ==
                                                          TransportMode
                                                              .wifiDirect
                                                      ? 'Direct'
                                                      : 'LAN',
                                                  style: const TextStyle(
                                                    color: VegaColors
                                                        .lightSky,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrangeRadarPainter extends CustomPainter {
  final double angle;

  _OrangeRadarPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width * 0.46;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = VegaColors.sandstoneGold.withValues(alpha: 0.42);

    canvas.drawCircle(center, maxR * 0.42, ringPaint);
    canvas.drawCircle(center, maxR * 0.72, ringPaint);
    canvas.drawCircle(
      center,
      maxR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = VegaColors.electricBlue.withValues(alpha: 0.45),
    );

    // Crosshairs
    final linePaint = Paint()
      ..strokeWidth = 1
      ..color = VegaColors.sandstoneGold.withValues(alpha: 0.22);
    canvas.drawLine(
      Offset(center.dx - maxR, center.dy),
      Offset(center.dx + maxR, center.dy),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxR),
      Offset(center.dx, center.dy + maxR),
      linePaint,
    );

    // Sweeping Electric Blue Cone
    final sweepRect = Rect.fromCircle(center: center, radius: maxR);
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 0.35,
        colors: [
          Colors.transparent,
          VegaColors.electricBlue.withValues(alpha: 0.45),
        ],
        transform: GradientRotation(angle),
      ).createShader(sweepRect);

    canvas.drawCircle(center, maxR, sweepPaint);

    // Gold-Leaf sweep edge line
    final edgeAngle = angle + math.pi * 0.35;
    final edgeEnd = Offset(
      center.dx + math.cos(edgeAngle) * maxR,
      center.dy + math.sin(edgeAngle) * maxR,
    );
    canvas.drawLine(
      center,
      edgeEnd,
      Paint()
        ..color = VegaColors.goldHighlight
        ..strokeWidth = 2.2,
    );
  }

  @override
  bool shouldRepaint(covariant _OrangeRadarPainter oldDelegate) =>
      oldDelegate.angle != angle;
}

class _RadarQrScannerPage extends StatefulWidget {
  const _RadarQrScannerPage();

  @override
  State<_RadarQrScannerPage> createState() => _RadarQrScannerPageState();
}

class _RadarQrScannerPageState extends State<_RadarQrScannerPage> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Receiver QR')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_handled) return;
          for (final barcode in capture.barcodes) {
            final raw = barcode.rawValue;
            if (raw != null && raw.startsWith('vega://')) {
              _handled = true;
              Navigator.pop(context, raw);
              break;
            }
          }
        },
      ),
    );
  }
}
