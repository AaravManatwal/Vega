import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../l10n/vega_strings.dart';
import '../models/transfer_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/heritage/heritage_page.dart';
import '../widgets/heritage/heritage_palette.dart';
import '../widgets/heritage/heritage_panel.dart';
import '../widgets/heritage/saffron_button.dart';
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
    final s = VegaStrings(state.settings.isHindi);
    final pal = HeritagePalette.of(context);
    final text = Theme.of(context).textTheme;
    final primaryIp =
        state.localIps.isNotEmpty ? state.localIps.first : '127.0.0.1';
    final port = state.receiverPort ?? 47890;
    final qrData =
        'vega://pair?ip=$primaryIp&port=$port&${state.pairingQuery}';

    final receiveTasks = state.tasks.values
        .where((t) => t.direction == TransferDirection.receive)
        .toList();

    return HeritagePage(
      title: s.t('Receive Files', 'फ़ाइलें प्राप्त करें'),
      subtitle: s.t('Show this QR to the sender', 'भेजने वाले को यह QR दिखाएँ'),
      trailing: state.isReceivingReady
          ? SaffronButton(
              label: s.t('Stop', 'रोकें'),
              expand: false,
              height: 38,
              fontSize: 13,
              onPressed: () async {
                await controller.stopReceivingSession();
                if (context.mounted) Navigator.pop(context);
              },
            )
          : null,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          HeritagePanel(
            radius: 28,
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: Colors.white,
                  activeTrackColor: VegaColors.saffron,
                  title: Text(
                    s.t('Local Wi-Fi Hotspot Mode', 'लोकल हॉटस्पॉट मोड'),
                    style: text.titleSmall?.copyWith(
                      color: pal.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    s.t(
                      'Enable if no common Wi-Fi router is available',
                      'जब कोई साझा Wi-Fi राउटर न हो तब चालू करें',
                    ),
                    style: text.bodySmall?.copyWith(color: pal.textMuted),
                  ),
                  value: _useHotspot,
                  onChanged: (value) async {
                    setState(() => _useHotspot = value);
                    await controller.startReceivingSession(withHotspot: value);
                  },
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: VegaColors.sandstoneGold, width: 2),
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
                    Clipboard.setData(ClipboardData(text: '$primaryIp:$port'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied $primaryIp:$port')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: pal.field,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: pal.softBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$primaryIp:$port',
                          style: TextStyle(
                            color: pal.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.copy_rounded, size: 16, color: pal.accentText),
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
                      color: pal.field,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: VegaColors.saffron.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      'Wi-Fi SSID: ${state.hotspotInfo!.ssid}\nPassword: ${state.hotspotInfo!.password}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: pal.accentText,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  s.t(
                    'Files save automatically into Downloads/Vega with SHA-256 verification.',
                    'फ़ाइलें अपने आप Downloads/Vega में सेव होती हैं और SHA-256 से जाँची जाती हैं।',
                  ),
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: pal.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SaffronButton(
            label: s.t('Open Browser / Windows Portal', 'ब्राउज़र / विंडोज़ पोर्टल खोलें'),
            icon: Icons.public_rounded,
            fontSize: 15,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BrowserShareScreen()),
              );
            },
          ),
          if (receiveTasks.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              s.t('Incoming Files', 'आने वाली फ़ाइलें'),
              style: text.titleMedium?.copyWith(color: pal.text, fontFamily: 'serif'),
            ),
            const SizedBox(height: 10),
            ...receiveTasks.map((task) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: HeritagePanel(
                  tile: true,
                  radius: 18,
                  padding: const EdgeInsets.all(14),
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
                              style: text.titleSmall?.copyWith(
                                color: pal.text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            task.status.name.toUpperCase(),
                            style: TextStyle(
                              color: pal.accentText,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: task.progress,
                        color: VegaColors.saffron,
                        backgroundColor: pal.softBorder,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${formatBytes(task.transferredBytes)} / ${formatBytes(task.totalBytes)} • ${formatSpeed(task.speedBytesPerSec)}',
                        style: text.bodySmall?.copyWith(color: pal.textMuted),
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
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
