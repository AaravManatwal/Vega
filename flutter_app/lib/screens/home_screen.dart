import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/platform_bridge.dart';
import '../state/app_state.dart';
import '../widgets/approval/vega_header.dart';
import '../widgets/home/action_tile.dart';
import '../widgets/home/live_transfer_card.dart';
import '../widgets/home/radar_card.dart';
import 'browser_share_screen.dart';
import 'history_settings_screens.dart';
import 'receive_screen.dart';
import 'send_screen.dart';
import 'transfer_progress_screen.dart';

/// Home: nearby-device radar, Send / Receive, browser share, live transfer, nav bar.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  StreamSubscription? _shareSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pending = await PlatformBridge.getPendingSharedFiles();
      if (pending.isNotEmpty && mounted) {
        _openSharedFiles(pending);
      }
      // Fill the radar; this asks for no permission.
      if (mounted) ref.read(vegaProvider.notifier).startQuietDiscovery();
    });
    _shareSub = PlatformBridge.shareIntentStream.listen((files) {
      if (files.isNotEmpty && mounted) {
        _openSharedFiles(files);
      }
    });
  }

  void _openSharedFiles(List<({String path, String name, int size})> files) {
    _push(SendScreen(initialFiles: files));
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vegaProvider);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final active = state.activeTasks;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const VegaHeader(mode: 'Ready'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aapka device',
                        style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      Text(
                        state.settings.deviceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.headlineSmall?.copyWith(color: cs.onSurface),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Vega kaise kaam karta hai',
                  icon: const Icon(Icons.help_outline_rounded),
                  onPressed: () => _push(const AboutPrivacyScreen()),
                ),
              ],
            ),
            const SizedBox(height: 14),
            RadarCard(
              peers: state.nearbyPeers,
              onTap: () => _push(const SendScreen()),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ActionTile(
                    title: 'Send',
                    subtitle: 'Files chuniye, device chuniye',
                    icon: Icons.arrow_upward_rounded,
                    onTap: () => _push(const SendScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ActionTile(
                    title: 'Receive',
                    subtitle: 'QR dikhaiye, Accept kijiye',
                    icon: Icons.arrow_downward_rounded,
                    style: ActionTileStyle.outlined,
                    onTap: () => _push(const ReceiveScreen()),
                  ),
                ),
              ],
            ),
            if (active.isNotEmpty) ...[
              const SizedBox(height: 14),
              LiveTransferCard(
                task: active.first,
                onTap: () => _push(TransferProgressScreen(taskId: active.first.id)),
              ),
            ],
            const SizedBox(height: 14),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(64, 60),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                side: BorderSide(color: cs.outlineVariant),
              ),
              onPressed: () => _push(const BrowserShareScreen()),
              child: Row(
                children: [
                  const Icon(Icons.public, color: Color(0xFF7DB7FF)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Browser aur Windows Share',
                      style: text.titleSmall?.copyWith(color: cs.onSurface),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (i) {
          if (i == 1) _push(const HistoryScreen());
          if (i == 2) _push(const SettingsScreen());
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.history_rounded), label: 'History'),
          NavigationDestination(icon: Icon(Icons.tune_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}
