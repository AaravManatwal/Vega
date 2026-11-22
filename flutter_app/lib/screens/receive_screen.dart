import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/transfer_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'browser_share_screen.dart';

class ReceiveScreen extends ConsumerStatefulWidget {
  const ReceiveScreen({super.key});

  @override
  ConsumerState<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends ConsumerState<ReceiveScreen> {
  bool _useHotspot = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(vegaProvider.notifier).startReceivingSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vegaProvider);
    final controller = ref.read(vegaProvider.notifier);
    final primaryIp =
        state.localIps.isNotEmpty ? state.localIps.first : '127.0.0.1';
    final port = state.receiverPort ?? 47890;
    final qrData =
        'vega://pair?ip=$primaryIp&port=$port&${state.pairingQuery}';

    final receiveTasks = state.tasks.values
        .where((t) => t.direction == TransferDirection.receive)
        .toList();

    return Scaffold(
      backgroundColor: VegaColors.deepCanvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    VegaColors.deepNavy,
                    VegaColors.midnightBlue,
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: VegaColors.sandstoneGold.withValues(alpha: 0.55),
                  width: 1.4,
                ),
              ),
              child: Column(
                children: [
                  // Integrated Header inside the Receive Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: VegaColors.deepCanvas.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: VegaColors.sandstoneGold.withValues(alpha: 0.40),
                      ),
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: VegaColors.midnightBlue,
                              border: Border.all(
                                color: VegaColors.sandstoneGold.withValues(alpha: 0.55),
                              ),
                            ),
                            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Receive Files · प्राप्त करें',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Show QR to Android or Windows sender',
                                style: TextStyle(
                                  color: VegaColors.goldHighlight,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (state.isReceivingReady)
                          TextButton(
                            onPressed: () async {
                              await controller.stopReceivingSession();
                              if (context.mounted) Navigator.pop(context);
                            },
                            child: const Text(
                              'Stop',
                              style: TextStyle(
                                color: VegaColors.goldHighlight,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: VegaColors.electricBlue,
                    title: const Text(
                      'Local Wi-Fi Hotspot Mode',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: const Text(
                      'Enable if no common Wi-Fi router is available',
                      style: TextStyle(
                        color: VegaColors.lightSky,
                        fontSize: 12.5,
                      ),
                    ),
                    value: _useHotspot,
                    onChanged: (value) async {
                      setState(() => _useHotspot = value);
                      await controller.startReceivingSession(
                        withHotspot: value,
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: VegaColors.sandstoneGold,
                        width: 2,
                      ),
                    ),
                    child: QrImageView(
                      data: qrData,
                      size: 205,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(text: '$primaryIp:$port'),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Copied $primaryIp:$port'),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: VegaColors.deepCanvas,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: VegaColors.borderMidnight,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$primaryIp:$port',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.copy_rounded,
                            size: 16,
                            color: VegaColors.lightSky,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (state.hotspotInfo != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: VegaColors.deepCanvas,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: VegaColors.electricBlue
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        'Wi-Fi SSID: ${state.hotspotInfo!.ssid}\nPassword: ${state.hotspotInfo!.password}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: VegaColors.skyAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'Files save automatically into Downloads/Vega with SHA-256 verification.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: VegaColors.lightSky,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: VegaColors.electricBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BrowserShareScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.public),
                label: const Text(
                  'Open Browser / Windows Portal',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            if (receiveTasks.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'Incoming Files',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              ...receiveTasks.map((task) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: VegaColors.deepNavy,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: task.integrityVerified
                          ? VegaColors.success
                          : VegaColors.sandstoneGold,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.fileName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            task.status.name.toUpperCase(),
                            style: const TextStyle(
                              color: VegaColors.goldHighlight,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: task.progress,
                        color: VegaColors.electricBlue,
                        backgroundColor: VegaColors.borderMidnight,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${formatBytes(task.transferredBytes)} / ${formatBytes(task.totalBytes)} • ${formatSpeed(task.speedBytesPerSec)}',
                        style: const TextStyle(
                          color: VegaColors.lightSky,
                          fontSize: 12,
                        ),
                      ),
                      if (task.savedLocation != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Saved to ${task.savedLocation}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: VegaColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
