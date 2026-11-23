import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/vega_strings.dart';
import '../models/transfer_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/heritage/heritage_page.dart';
import '../widgets/heritage/heritage_palette.dart';
import '../widgets/heritage/heritage_panel.dart';

String _ago(VegaStrings s, DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return s.t('just now', 'अभी अभी');
  if (d.inMinutes < 60) return s.t('${d.inMinutes} min ago', '${d.inMinutes} मिनट पहले');
  if (d.inHours < 24) return s.t('${d.inHours} h ago', '${d.inHours} घंटे पहले');
  if (d.inDays < 7) return s.t('${d.inDays} d ago', '${d.inDays} दिन पहले');
  return '${t.day}/${t.month}/${t.year}';
}

InputDecoration _fieldDecoration(HeritagePalette p, {String? hint, Widget? prefix}) {
  OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: p.textMuted),
    prefixIcon: prefix,
    filled: true,
    fillColor: p.field,
    border: border(p.softBorder),
    enabledBorder: border(p.softBorder),
    focusedBorder: border(VegaColors.saffron),
  );
}

// ---------------------------------------------------------------- History

enum _Dir { all, sent, received }

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _Dir _dir = _Dir.all;
  String _query = '';

  Future<void> _confirmClear(VegaStrings s) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('Clear history?', 'इतिहास साफ़ करें?')),
        content: Text(
          s.t(
            'Only the list is removed. Your received files stay as they are.',
            'सिर्फ़ सूची हटेगी। आपकी मिली हुई फ़ाइलें वैसी ही रहेंगी।',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.t('Keep', 'रहने दें')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.t('Clear', 'साफ़ करें')),
          ),
        ],
      ),
    );
    if (yes == true) ref.read(vegaProvider.notifier).clearHistory();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vegaProvider);
    final s = VegaStrings(state.settings.isHindi);
    final p = HeritagePalette.of(context);
    final text = Theme.of(context).textTheme;

    final items = state.history
        .where((t) =>
            _dir == _Dir.all ||
            (_dir == _Dir.sent && t.direction == TransferDirection.send) ||
            (_dir == _Dir.received && t.direction == TransferDirection.receive))
        .where((t) {
      final q = _query.toLowerCase();
      return q.isEmpty ||
          t.fileName.toLowerCase().contains(q) ||
          t.peerName.toLowerCase().contains(q);
    }).toList();

    return HeritagePage(
      title: s.t('History', 'इतिहास'),
      subtitle: s.t('Sent & received transfers', 'भेजे और मिले ट्रांसफ़र'),
      trailing: state.history.isEmpty
          ? null
          : HeritageRoundButton(
              icon: Icons.delete_outline_rounded,
              tooltip: s.t('Clear history', 'इतिहास साफ़ करें'),
              onTap: () => _confirmClear(s),
            ),
      child: Column(
        children: [
          HeritagePanel(
            radius: 20,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: TextStyle(color: p.text),
                  decoration: _fieldDecoration(
                    p,
                    hint: s.t('Search file or device...', 'फ़ाइल या डिवाइस खोजें...'),
                    prefix: Icon(Icons.search_rounded, color: p.textMuted),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    HeritagePill(
                      label: s.t('All', 'सभी'),
                      selected: _dir == _Dir.all,
                      onTap: () => setState(() => _dir = _Dir.all),
                    ),
                    const SizedBox(width: 8),
                    HeritagePill(
                      label: s.t('Sent', 'भेजे'),
                      selected: _dir == _Dir.sent,
                      onTap: () => setState(() => _dir = _Dir.sent),
                    ),
                    const SizedBox(width: 8),
                    HeritagePill(
                      label: s.t('Received', 'मिले'),
                      selected: _dir == _Dir.received,
                      onTap: () => setState(() => _dir = _Dir.received),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: items.isEmpty
                ? HeritagePanel(
                    radius: 28,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_user_outlined, size: 40, color: p.accentText),
                            const SizedBox(height: 12),
                            Text(
                              s.t('No transfer records yet', 'अभी कोई ट्रांसफ़र रिकॉर्ड नहीं'),
                              textAlign: TextAlign.center,
                              style: text.titleSmall?.copyWith(
                                color: p.text,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.t(
                                'Sent and received files appear here automatically.',
                                'भेजी और मिली फ़ाइलें यहाँ अपने आप दिखेंगी।',
                              ),
                              textAlign: TextAlign.center,
                              style: text.bodySmall?.copyWith(color: p.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final isSend = item.direction == TransferDirection.send;
                      final ok = item.status == TransferStatus.completed;
                      final tint = !ok
                          ? const Color(0xFFEF4444)
                          : (isSend ? VegaColors.saffron : VegaColors.success);
                      return HeritagePanel(
                        tile: true,
                        radius: 18,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: tint.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isSend ? Icons.north_east_rounded : Icons.south_west_rounded,
                                color: tint,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.fileName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.titleSmall?.copyWith(
                                      color: p.text,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${isSend ? s.t("Sent", "भेजा") : s.t("Received", "मिला")}'
                                    ' · ${item.peerName} · ${formatBytes(item.totalBytes)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.bodySmall?.copyWith(color: p.textMuted),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    ok
                                        ? (item.integrityVerified
                                            ? '${s.t("Verified", "वेरिफ़ाइड")} · ${_ago(s, item.updatedAt)}'
                                            : _ago(s, item.updatedAt))
                                        : '${s.t("Not completed", "पूरा नहीं हुआ")} · ${_ago(s, item.updatedAt)}',
                                    style: text.labelSmall?.copyWith(
                                      color: ok ? p.textMuted : const Color(0xFFEF4444),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              item.encrypted
                                  ? Icons.lock_outline_rounded
                                  : Icons.lock_open_rounded,
                              size: 18,
                              color: p.textMuted,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- Settings

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: ref.read(vegaProvider).settings.deviceName,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveName() {
    final v = _nameController.text.trim();
    final settings = ref.read(vegaProvider).settings;
    if (v.isNotEmpty && v != settings.deviceName) {
      ref.read(vegaProvider.notifier).updateSettings(settings.copyWith(deviceName: v));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(vegaProvider).settings;
    final controller = ref.read(vegaProvider.notifier);
    final s = VegaStrings(settings.isHindi);
    final p = HeritagePalette.of(context);
    final text = Theme.of(context).textTheme;

    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(
            t,
            style: text.labelMedium?.copyWith(
              color: p.dark ? VegaColors.skyText : VegaColors.brownText,
              fontWeight: FontWeight.w700,
            ),
          ),
        );

    Widget choice(String t, bool selected, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: selected
                    ? const LinearGradient(
                        colors: [VegaColors.saffron, VegaColors.saffronDark],
                      )
                    : null,
                color: selected ? null : p.field,
                border: Border.all(
                  color: selected
                      ? VegaColors.goldBorder.withValues(alpha: 0.8)
                      : p.softBorder,
                ),
              ),
              child: Text(
                t,
                style: TextStyle(
                  color: selected ? Colors.white : p.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
        );

    Widget toggle(String title, String sub, bool value, ValueChanged<bool> onChanged) =>
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: Colors.white,
          activeTrackColor: VegaColors.saffron,
          title: Text(
            title,
            style: text.titleSmall?.copyWith(color: p.text, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(sub, style: text.bodySmall?.copyWith(color: p.textMuted)),
          value: value,
          onChanged: onChanged,
        );

    return HeritagePage(
      title: s.t('Settings', 'सेटिंग्स'),
      subtitle: s.t('Language, theme & sharing preferences', 'भाषा, थीम और शेयरिंग पसंद'),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          HeritagePanel(
            radius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label(s.t('Device Name', 'डिवाइस का नाम')),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        textInputAction: TextInputAction.done,
                        style: TextStyle(color: p.text),
                        decoration: _fieldDecoration(p),
                        onChanged: (_) => _saveName(),
                        onSubmitted: (_) => _saveName(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  s.t(
                    'Other phones see you by this name.',
                    'दूसरे फ़ोन आपको इसी नाम से देखेंगे।',
                  ),
                  style: text.bodySmall?.copyWith(color: p.textMuted),
                ),
                const SizedBox(height: 14),
                Divider(color: p.softBorder, height: 1),
                const SizedBox(height: 14),
                label(s.t('Language', 'भाषा')),
                Row(
                  children: [
                    choice('English', !settings.isHindi,
                        () => controller.updateSettings(settings.copyWith(language: 'en'))),
                    const SizedBox(width: 10),
                    choice('हिन्दी', settings.isHindi,
                        () => controller.updateSettings(settings.copyWith(language: 'hi'))),
                  ],
                ),
                const SizedBox(height: 14),
                label(s.t('Theme', 'थीम')),
                Row(
                  children: [
                    choice(s.t('Light', 'लाइट'), !settings.darkMode,
                        () => controller.updateSettings(settings.copyWith(darkMode: false))),
                    const SizedBox(width: 10),
                    choice(s.t('Dark', 'डार्क'), settings.darkMode,
                        () => controller.updateSettings(settings.copyWith(darkMode: true))),
                  ],
                ),
                const SizedBox(height: 10),
                toggle(
                  s.t('Alerts', 'अलर्ट'),
                  s.t('Show an alert when a file arrives.', 'फ़ाइल आने पर अलर्ट दिखाएँ।'),
                  settings.alerts,
                  (v) => controller.updateSettings(settings.copyWith(alerts: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          HeritagePanel(
            radius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('Security & Speed', 'सुरक्षा और स्पीड'),
                  style: text.titleMedium?.copyWith(color: p.text, fontFamily: 'Cinzel', fontFamilyFallback: const ['NotoSansDevanagari']),
                ),
                const SizedBox(height: 6),
                toggle(
                  s.t('Lock files (AES-256)', 'फ़ाइलें लॉक करें (AES-256)'),
                  s.t(
                    'Recommended. Turning it off may be faster, but anyone on the network can read the file.',
                    'चालू रखना बेहतर है। बंद करने पर थोड़ी तेज़ी आ सकती है, पर नेटवर्क पर कोई भी फ़ाइल पढ़ सकता है।',
                  ),
                  settings.encryptTransfers,
                  (v) => controller.updateSettings(settings.copyWith(encryptTransfers: v)),
                ),
                const SizedBox(height: 8),
                label(s.t('Chunk size', 'चंक साइज़')),
                Row(
                  children: [
                    for (final kb in const [256, 512, 1024]) ...[
                      choice('$kb KB', settings.chunkSizeKb == kb,
                          () => controller.updateSettings(settings.copyWith(chunkSizeKb: kb))),
                      if (kb != 1024) const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  s.t(
                    'Bigger chunks are usually faster. 1024 KB is the fastest.',
                    'बड़े चंक आम तौर पर तेज़ होते हैं। 1024 KB सबसे तेज़ है।',
                  ),
                  style: text.bodySmall?.copyWith(color: p.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ About

class AboutPrivacyScreen extends ConsumerWidget {
  const AboutPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = VegaStrings(ref.watch(vegaProvider.select((v) => v.settings.isHindi)));
    final p = HeritagePalette.of(context);
    final text = Theme.of(context).textTheme;

    final points = <(IconData, String)>[
      (
        Icons.wifi_tethering_rounded,
        s.t(
          'Transfers go straight between the two devices over Wi-Fi, Wi-Fi Direct or hotspot.',
          'ट्रांसफ़र सीधे दोनों डिवाइस के बीच Wi-Fi, Wi-Fi Direct या हॉटस्पॉट पर होता है।',
        ),
      ),
      (
        Icons.cloud_off_rounded,
        s.t(
          'No cloud server, no analytics. Nothing about you is collected.',
          'कोई क्लाउड सर्वर नहीं, कोई एनालिटिक्स नहीं। आपका कोई डेटा जमा नहीं होता।',
        ),
      ),
      (
        Icons.location_off_rounded,
        s.t(
          'Uses the Android 13+ NEARBY_WIFI_DEVICES permission. No GPS or location needed.',
          'Android 13+ की NEARBY_WIFI_DEVICES अनुमति इस्तेमाल होती है। GPS या लोकेशन नहीं चाहिए।',
        ),
      ),
      (
        Icons.verified_user_rounded,
        s.t(
          'Every transfer is locked with AES-256-GCM and checked with SHA-256.',
          'हर ट्रांसफ़र AES-256-GCM से लॉक होता है और SHA-256 से जाँचा जाता है।',
        ),
      ),
    ];

    return HeritagePage(
      title: s.t('About Vega', 'वेग के बारे में'),
      subtitle: s.t('Privacy & security', 'गोपनीयता और सुरक्षा'),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          HeritagePanel(
            radius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vega (वेग) v1.0.0',
                  style: text.titleLarge?.copyWith(color: p.text),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manatwal Innovations · Build · Innovate · Empower',
                  style: text.labelLarge?.copyWith(color: p.accentText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          for (final pt in points) ...[
            HeritagePanel(
              tile: true,
              radius: 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(pt.$1, color: p.accentText),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      pt.$2,
                      style: text.bodyMedium?.copyWith(color: p.text, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
