import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/vega_strings.dart';
import '../services/platform_bridge.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/heritage/heritage_drawer.dart';
import '../widgets/heritage/glass_dock.dart';
import '../widgets/heritage/scallop_badge.dart';
import '../widgets/heritage/heritage_palette.dart';
import '../widgets/heritage/mini_transfer_bar.dart';
import '../widgets/heritage/jali_background.dart';
import '../widgets/home/live_transfer_card.dart';
import '../widgets/vega_logo.dart';
import 'browser_share_screen.dart';
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
    final active = state.activeTasks;
    final controller = ref.read(vegaProvider.notifier);

    return SuppressMiniBar(child: Scaffold(
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
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _ReadyPill(
                            ready: state.localIps.isNotEmpty,
                            text: state.localIps.isNotEmpty
                                ? s.t('Ready on Wi-Fi · ${state.localIps.first}',
                                    'Wi-Fi पर तैयार · ${state.localIps.first}')
                                : s.t('Not on Wi-Fi yet', 'अभी Wi-Fi से नहीं जुड़ा'),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _HeroCard(
                                send: true,
                                title: s.t('Send', 'भेजें'),
                                subtitle: s.t('Pick files, find a phone', 'फ़ाइल चुनें, फ़ोन खोजें'),
                                onTap: () => _push(const SendScreen()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _HeroCard(
                                send: false,
                                title: s.t('Receive', 'प्राप्त करें'),
                                subtitle: s.t('Show QR to the sender', 'भेजने वाले को QR दिखाएँ'),
                                onTap: () => _push(const ReceiveScreen()),
                              ),
                            ),
                          ],
                        ),
                        if (active.isNotEmpty) ...[
                          const SizedBox(height: 22),
                          LiveTransferCard(
                            task: active.first,
                            onTap: () => _push(
                              TransferProgressScreen(taskId: active.first.id),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GlassDock(
                  items: [
                    DockItem(
                      icon: Icons.home_rounded,
                      label: s.t('Home', 'होम'),
                      onTap: () {},
                    ),
                    DockItem(
                      icon: Icons.history_rounded,
                      label: s.t('History', 'इतिहास'),
                      onTap: () => _push(const HistoryScreen()),
                    ),
                    DockItem(
                      icon: Icons.settings_rounded,
                      label: s.t('Settings', 'सेटिंग्स'),
                      onTap: () => _push(const SettingsScreen()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ));
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
            fontFamily: 'Cinzel', fontFamilyFallback: const ['NotoSansDevanagari'],
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

class _ReadyPill extends StatelessWidget {
  const _ReadyPill({required this.ready, required this.text});
  final bool ready;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = HeritagePalette.of(context);
    final dot = ready ? const Color(0xFF00E676) : const Color(0xFFFFB300);
    return Container(
      height: 40,
      padding: const EdgeInsets.fromLTRB(14, 0, 16, 0),
      decoration: BoxDecoration(
        color: p.tile,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: p.softBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: dot.withValues(alpha: 0.8), blurRadius: 8)],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.text, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Big Send / Receive card: Send is solid saffron, Receive is navy with a gold edge.
class _HeroCard extends StatefulWidget {
  const _HeroCard({
    required this.send,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final bool send;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = HeritagePalette.of(context);
    final send = widget.send;
    final fg = send ? Colors.white : p.text;
    final sub = send ? Colors.white.withValues(alpha: 0.9) : p.textMuted;
    return Semantics(
      button: true,
      label: widget.title,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: send
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF8A24), Color(0xFFD96B08), Color(0xFFB84E00)],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: p.dark
                          ? const [Color(0xFF12306B), Color(0xFF0D2148)]
                          : const [Colors.white, Color(0xFFFAF6EC)],
                    ),
              border: send
                  ? null
                  : Border.all(color: const Color(0xFFF5D08A).withValues(alpha: 0.6), width: 1.5),
              boxShadow: send
                  ? [BoxShadow(color: const Color(0xFFD96B08).withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 14))]
                  : null,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(32),
              onHighlightChanged: (v) => setState(() => _down = v),
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onTap();
              },
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ScallopBadge(
                      icon: send ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      size: 64,
                      spin: true,
                      color: send
                          ? Colors.white.withValues(alpha: 0.22)
                          : const Color(0xFFF5D08A).withValues(alpha: 0.2),
                      iconColor: send ? Colors.white : p.accentText,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontFamily: 'Cinzel',
                            fontFamilyFallback: const ['NotoSansDevanagari'],
                            fontWeight: FontWeight.w700,
                            fontSize: 25,
                            color: fg,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(widget.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: sub, height: 1.3)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
