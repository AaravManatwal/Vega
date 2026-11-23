import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/vega_strings.dart';
import '../services/platform_bridge.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/heritage/heritage_drawer.dart';
import '../widgets/heritage/heritage_page.dart';
import '../widgets/heritage/heritage_palette.dart';
import '../widgets/heritage/home_stage.dart';
import '../widgets/heritage/jali_background.dart';
import '../widgets/heritage/saffron_button.dart';
import '../widgets/home/live_transfer_card.dart';
import '../widgets/vega_logo.dart';
import 'browser_share_screen.dart';
import 'files_screen.dart';
import 'help_screen.dart';
import 'history_settings_screens.dart';
import 'receive_screen.dart';
import 'send_screen.dart';
import 'transfer_progress_screen.dart';

/// Home, as in the web design: logo bar, arch stage with Send (upper left) and
/// Receive (lower right) medallions, and a History button.
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
    final settings = state.settings;
    final s = VegaStrings(settings.isHindi);
    final p = HeritagePalette.of(context);
    final text = Theme.of(context).textTheme;
    final active = state.activeTasks;
    final controller = ref.read(vegaProvider.notifier);

    return Scaffold(
      backgroundColor: p.pageGradient.first,
      drawer: HeritageDrawer(
        strings: s,
        sharing: [
          DrawerEntry(
            icon: Icons.grid_view_rounded,
            label: s.t('Home', 'होम'),
            active: true,
            onTap: () {},
          ),
          DrawerEntry(
            icon: Icons.north_east_rounded,
            label: s.t('Send', 'भेजें'),
            onTap: () => _push(const SendScreen()),
          ),
          DrawerEntry(
            icon: Icons.south_west_rounded,
            label: s.t('Receive', 'प्राप्त करें'),
            onTap: () => _push(const ReceiveScreen()),
          ),
          DrawerEntry(
            icon: Icons.public_rounded,
            label: s.t('Browser & Windows Share', 'ब्राउज़र और विंडोज़ शेयर'),
            onTap: () => _push(const BrowserShareScreen()),
          ),
        ],
        files: [
          DrawerEntry(
            icon: Icons.folder_open_rounded,
            label: s.t('Files', 'फ़ाइलें'),
            onTap: () => _push(const FilesScreen()),
          ),
          DrawerEntry(
            icon: Icons.history_rounded,
            label: s.t('History', 'इतिहास'),
            onTap: () => _push(const HistoryScreen()),
          ),
          DrawerEntry(
            icon: Icons.settings_outlined,
            label: s.t('Settings', 'सेटिंग्स'),
            onTap: () => _push(const SettingsScreen()),
          ),
          DrawerEntry(
            icon: Icons.help_outline_rounded,
            label: s.t('Help & Guide', 'सहायता'),
            onTap: () => _push(const HelpScreen()),
          ),
          DrawerEntry(
            icon: Icons.shield_outlined,
            label: s.t('About & Privacy', 'गोपनीयता'),
            onTap: () => _push(const AboutPrivacyScreen()),
          ),
        ],
      ),
      body: JaliBackground(
        arch: false,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                _TopBar(
                  strings: s,
                  isDark: settings.darkMode,
                  isHindi: settings.isHindi,
                  onLanguage: () => controller.updateSettings(
                    settings.copyWith(language: settings.isHindi ? 'en' : 'hi'),
                  ),
                  onTheme: () => controller.updateSettings(
                    settings.copyWith(darkMode: !settings.darkMode),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: HomeStage(
                    child: LayoutBuilder(
                      builder: (context, box) => SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: box.maxHeight),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      s.t('Offline File Sharing', 'ऑफ़लाइन फ़ाइल शेयरिंग'),
                                      textAlign: TextAlign.center,
                                      style: text.headlineSmall?.copyWith(
                                        color: p.text,
                                        fontSize: 25,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _HelpButton(
                                      label: s.t('How it works', 'कैसे उपयोग करें'),
                                      onTap: () => _push(const HelpScreen()),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                Column(
                                  children: [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: MedallionButton(
                                        kind: MedallionKind.send,
                                        label: s.t('Send', 'भेजें'),
                                        onTap: () => _push(const SendScreen()),
                                      ),
                                    ),
                                    const SizedBox(height: 26),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: MedallionButton(
                                        kind: MedallionKind.receive,
                                        label: s.t('Receive', 'प्राप्त करें'),
                                        onTap: () => _push(const ReceiveScreen()),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                Column(
                                  children: [
                                    if (active.isNotEmpty) ...[
                                      LiveTransferCard(
                                        task: active.first,
                                        onTap: () => _push(
                                          TransferProgressScreen(taskId: active.first.id),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                    ],
                                    SaffronButton(
                                      label: s.t('History', 'इतिहास'),
                                      icon: Icons.history_rounded,
                                      expand: false,
                                      height: 46,
                                      fontSize: 14.5,
                                      onPressed: () => _push(const HistoryScreen()),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.strings,
    required this.isDark,
    required this.isHindi,
    required this.onLanguage,
    required this.onTheme,
  });

  final VegaStrings strings;
  final bool isDark;
  final bool isHindi;
  final VoidCallback onLanguage;
  final VoidCallback onTheme;

  @override
  Widget build(BuildContext context) {
    final p = HeritagePalette.of(context);
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        Builder(
          builder: (ctx) => IconButton(
            tooltip: strings.t('Open navigation menu', 'मेन्यू खोलें'),
            icon: Icon(Icons.menu_rounded, color: p.text),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        const VegaLogo(size: 32),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Vega',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleLarge?.copyWith(color: p.text, fontSize: 19, letterSpacing: 0.8),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'वेग',
          style: TextStyle(
            color: p.dark ? VegaColors.sandstoneGold : VegaColors.brownMuted,
            fontSize: 13,
            fontFamily: 'serif',
          ),
        ),
        const Spacer(),
        _Chip(
          label: isHindi ? 'EN' : 'हिन्दी',
          onTap: onLanguage,
          tooltip: strings.t('Switch language', 'भाषा बदलें'),
        ),
        const SizedBox(width: 8),
        HeritageRoundButton(
          size: 40,
          icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          iconColor: isDark ? VegaColors.goldHighlight : VegaColors.brownMuted,
          tooltip: isDark
              ? strings.t('Switch to Light theme', 'लाइट थीम')
              : strings.t('Switch to Dark theme', 'डार्क थीम'),
          onTap: onTheme,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap, required this.tooltip});
  final String label;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final p = HeritagePalette.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: p.dark ? const Color(0xE60D2148) : const Color(0xE6FFFFFF),
        shape: StadiumBorder(
          side: BorderSide(color: VegaColors.sandstoneGold.withValues(alpha: 0.55)),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: p.dark ? VegaColors.goldHighlight : VegaColors.deepNavy,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HelpButton extends StatelessWidget {
  const _HelpButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = HeritagePalette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.dark ? const Color(0xE60D2148) : const Color(0xE6FFF5E6),
                border: Border.all(color: VegaColors.sandstoneGold.withValues(alpha: 0.8)),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [VegaColors.saffron, VegaColors.saffronDark],
                  ),
                  border: Border.all(color: VegaColors.goldBorder.withValues(alpha: 0.85)),
                ),
                child: const Icon(Icons.help_outline_rounded, size: 17, color: Colors.white),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: p.dark ? VegaColors.goldHighlight : VegaColors.saffronDark,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
