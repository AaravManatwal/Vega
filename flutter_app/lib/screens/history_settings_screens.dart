import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transfer_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'abhi abhi';
  if (d.inMinutes < 60) return '${d.inMinutes} minute pehle';
  if (d.inHours < 24) return '${d.inHours} ghante pehle';
  if (d.inDays < 7) return '${d.inDays} din pehle';
  return '${t.day}/${t.month}/${t.year}';
}

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('History saaf karein?'),
        content: const Text('Sirf list hategi. Aapki mili hui files waisi hi rahengi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Rehne dein')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Saaf karein')),
        ],
      ),
    );
    if (yes == true) ref.read(vegaProvider.notifier).clearHistory();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vegaProvider);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer History'),
        actions: [
          if (state.history.isNotEmpty)
            IconButton(
              tooltip: 'History saaf karein',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _confirmClear(context, ref),
            ),
        ],
      ),
      body: state.history.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history_rounded, size: 72, color: cs.outline),
                    const SizedBox(height: 16),
                    Text('Abhi koi transfer nahi hua',
                        style: text.titleMedium?.copyWith(color: cs.onSurface)),
                    const SizedBox(height: 6),
                    Text(
                      'Jo files aap bhejenge ya payenge, yahan dikhengi.',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: state.history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = state.history[index];
                final isSend = item.direction == TransferDirection.send;
                final ok = item.status == TransferStatus.completed;
                final tint = !ok
                    ? cs.error
                    : (isSend ? cs.primary : VegaColors.success);
                return Card(
                  child: Padding(
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
                                style: text.titleSmall?.copyWith(color: cs.onSurface),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${isSend ? "Bheja" : "Mila"} · ${item.peerName} · '
                                '${formatBytes(item.totalBytes)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                ok
                                    ? (item.integrityVerified
                                        ? 'Verified · ${_ago(item.updatedAt)}'
                                        : _ago(item.updatedAt))
                                    : 'Poora nahi hua · ${_ago(item.updatedAt)}',
                                style: text.labelSmall?.copyWith(
                                  color: ok ? cs.onSurfaceVariant : cs.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          item.encrypted ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

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

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(vegaProvider).settings;
    final controller = ref.read(vegaProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          _section(context, 'AAPKA DEVICE'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _nameController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Device ka naam',
                  helperText: 'Dusre phone par aap isi naam se dikhenge',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _saveName(),
                onSubmitted: (_) => _saveName(),
                onTapOutside: (_) {
                  _saveName();
                  FocusManager.instance.primaryFocus?.unfocus();
                },
              ),
            ),
          ),
          _section(context, 'SURAKSHA'),
          Card(
            child: SwitchListTile(
              title: const Text('Files ko lock karein (AES-256)'),
              subtitle: const Text(
                'Chalu rakhna behtar hai. Band karne par transfer thoda tez ho sakta hai, '
                'par raste me koi file padh sakta hai.',
              ),
              value: settings.encryptTransfers,
              onChanged: (v) =>
                  controller.updateSettings(settings.copyWith(encryptTransfers: v)),
            ),
          ),
          _section(context, 'SPEED'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chunk ka size', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    'Bade chunk aam taur par tez hote hain. 1024 KB sabse tez hai.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 256, label: Text('256 KB')),
                      ButtonSegment(value: 512, label: Text('512 KB')),
                      ButtonSegment(value: 1024, label: Text('1024 KB')),
                    ],
                    selected: {settings.chunkSizeKb},
                    onSelectionChanged: (sel) => controller
                        .updateSettings(settings.copyWith(chunkSizeKb: sel.first)),
                  ),
                ],
              ),
            ),
          ),
          _section(context, 'DIKHAAWA'),
          Card(
            child: SwitchListTile(
              title: const Text('Dark theme'),
              value: settings.darkMode,
              onChanged: (v) =>
                  controller.updateSettings(settings.copyWith(darkMode: v)),
            ),
          ),
        ],
      ),
    );
  }
}

class AboutPrivacyScreen extends StatelessWidget {
  const AboutPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    const points = <(IconData, String)>[
      (Icons.wifi_tethering_rounded,
          'Transfer seedha dono device ke beech hota hai: Wi-Fi, Wi-Fi Direct ya hotspot par.'),
      (Icons.cloud_off_rounded,
          'Koi cloud server nahi, koi analytics nahi, aapka koi data jama nahi hota.'),
      (Icons.location_off_rounded,
          'Android 13+ ki NEARBY_WIFI_DEVICES permission use hoti hai. GPS ya location ki zarurat nahi.'),
      (Icons.verified_user_rounded,
          'Har transfer AES-256-GCM se locked hota hai aur SHA-256 se jaancha jaata hai.'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Vega ke baare me')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vega (वेग) v1.0.0', style: text.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    'Manatwal Innovations · Build · Innovate · Empower',
                    style: text.labelLarge?.copyWith(color: cs.primary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final p in points)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(p.$1, color: cs.primary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(p.$2, style: text.bodyMedium?.copyWith(height: 1.45)),
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
