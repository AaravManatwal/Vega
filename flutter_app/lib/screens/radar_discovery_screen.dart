import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/heritage/wavy_progress.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/security/pairing.dart';
import '../models/transfer_models.dart';
import '../l10n/vega_strings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/heritage/heritage_page.dart';
import '../widgets/heritage/heritage_palette.dart';
import '../widgets/heritage/heritage_panel.dart';
import '../widgets/heritage/saffron_button.dart';

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
    final scanTitle = VegaStrings(ref.read(vegaProvider).settings.isHindi)
        .t('Scan Receiver QR', 'प्राप्तकर्ता का QR स्कैन करें');
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => _RadarQrScannerPage(title: scanTitle)),
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
    final s = VegaStrings(ref.read(vegaProvider).settings.isHindi);
    final peer = await showDialog<PeerDevice>(
      context: context,
      builder: (ctx) {
        final pal = HeritagePalette.of(ctx);
        InputDecoration deco(String label) => InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: pal.textMuted),
              filled: true,
              fillColor: pal.field,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: pal.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: pal.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: VegaColors.saffron),
              ),
            );
        return AlertDialog(
          backgroundColor: pal.dark ? VegaColors.cardMidnight : VegaColors.ivory,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: pal.border),
          ),
          title: Text(
            s.t('Connect by IP Address', 'IP पते से जुड़ें'),
            style: TextStyle(color: pal.text, fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ipCtrl,
                style: TextStyle(color: pal.text),
                decoration: deco(
                  s.t('Receiver IP (e.g. 192.168.43.1)',
                      'प्राप्तकर्ता का IP (जैसे 192.168.43.1)'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: portCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: pal.text),
                decoration: deco(s.t('Port', 'पोर्ट')),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                s.t('Cancel', 'रद्द करें'),
                style: TextStyle(color: pal.accentText),
              ),
            ),
            SaffronButton(
              label: s.t('Connect & Send', 'जोड़ें और भेजें'),
              expand: false,
              height: 42,
              fontSize: 14,
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
            ),
          ],
        );
      },
    );
    if (peer != null) {
      await _sendToPeer(peer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vegaProvider);
    final controller = ref.read(vegaProvider.notifier);
    final s = VegaStrings(state.settings.isHindi);
    final pal = HeritagePalette.of(context);
    final peers = state.nearbyPeers;
    final sendTasks = state.tasks.values
        .where((t) => t.direction == TransferDirection.send)
        .toList();

    return HeritagePage(
      title: s.t('Searching Nearby', 'आसपास खोज रहे हैं'),
      subtitle: s.t(
        "Make sure receiver's visibility is turned on",
        'पक्का करें कि प्राप्तकर्ता की दृश्यता चालू है',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HeritageRoundButton(
            icon: Icons.qr_code_scanner,
            tooltip: s.t('Scan Receiver QR', 'प्राप्तकर्ता का QR स्कैन करें'),
            size: 40,
            onTap: _scanQr,
          ),
          const SizedBox(width: 8),
          HeritageRoundButton(
            icon: Icons.lan_outlined,
            tooltip: s.t('Manual IP', 'मैन्युअल IP'),
            size: 40,
            onTap: _promptManualIp,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Animated sweeping saffron radar
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
                        // Center saffron + gold-leaf send beacon
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: VegaColors.saffron,
                            border: Border.all(
                              color: VegaColors.sandstoneGold,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    VegaColors.saffron.withValues(alpha: 0.55),
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
                                  color: pal.panel,
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
                                  color: pal.accentText,
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

          // Discovered devices nearby / live transfer panel
          Expanded(
            flex: 4,
            child: HeritagePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    sendTasks.isNotEmpty
                        ? s.t('Active Transfers', 'चालू ट्रांसफ़र')
                        : s.t('Discovered devices nearby',
                            'आसपास मिले डिवाइस'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: pal.text,
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
                              return HeritagePanel(
                                tile: true,
                                highlight: true,
                                radius: 14,
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            task.fileName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: pal.text,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          task.status.name.toUpperCase(),
                                          style: const TextStyle(
                                            color: VegaColors.saffron,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    WavyProgress(value: task.progress),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            '${formatBytes(task.transferredBytes)} / ${formatBytes(task.totalBytes)} • ${formatSpeed(task.speedBytesPerSec)}',
                                            style: TextStyle(
                                              color: pal.textMuted,
                                              fontSize: 11.5,
                                            ),
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
                                                          TransferStatus.paused
                                                      ? Icons.play_arrow
                                                      : Icons.pause,
                                                  color: pal.text,
                                                  size: 18,
                                                ),
                                                onPressed: () {
                                                  if (task.status ==
                                                      TransferStatus.paused) {
                                                    controller.engine
                                                        .resumeTransfer(
                                                            task.id);
                                                  } else {
                                                    controller.engine
                                                        .pauseTransfer(task.id);
                                                  }
                                                },
                                              ),
                                              IconButton(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                icon: Icon(
                                                  Icons.close,
                                                  color: pal.textMuted,
                                                  size: 18,
                                                ),
                                                onPressed: () => controller
                                                    .engine
                                                    .cancelTransfer(task.id),
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
                            ? Center(
                                child: Text(
                                  s.t(
                                    'Scanning Wi-Fi Direct & LAN mDNS...\nOr tap QR / IP icon above.',
                                    'Wi-Fi Direct और LAN mDNS स्कैन हो रहा है...\nया ऊपर QR / IP आइकन दबाएँ।',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: pal.textMuted,
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
                                  return HeritagePanel(
                                    tile: true,
                                    radius: 14,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    onTap: () => _sendToPeer(peer),
                                    child: Row(
                                      children: [
                                        Icon(
                                          peer.platform == 'windows' ||
                                                  peer.platform == 'macos'
                                              ? Icons.laptop_mac
                                              : Icons.smartphone,
                                          color: VegaColors.saffron,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            peer.name,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: pal.text,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: pal.field,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            peer.transport ==
                                                    TransportMode.wifiDirect
                                                ? s.t('Direct', 'डायरेक्ट')
                                                : 'LAN',
                                            style: TextStyle(
                                              color: pal.textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
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
        ..color = VegaColors.saffron.withValues(alpha: 0.45),
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
          VegaColors.saffron.withValues(alpha: 0.45),
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
  final String title;

  const _RadarQrScannerPage({required this.title});

  @override
  State<_RadarQrScannerPage> createState() => _RadarQrScannerPageState();
}

class _RadarQrScannerPageState extends State<_RadarQrScannerPage> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
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
