import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/vega_strings.dart';
import '../models/transfer_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/heritage/heritage_page.dart';
import '../widgets/heritage/heritage_palette.dart';
import '../widgets/heritage/heritage_panel.dart';

enum _Kind { all, photos, videos, documents }

_Kind _kindOf(String name) {
  final n = name.toLowerCase();
  const img = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.bmp'];
  const vid = ['.mp4', '.mkv', '.mov', '.avi', '.webm', '.3gp'];
  if (img.any(n.endsWith)) return _Kind.photos;
  if (vid.any(n.endsWith)) return _Kind.videos;
  return _Kind.documents;
}

/// Files received through Vega, with a search box and type filters.
class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  _Kind _filter = _Kind.all;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vegaProvider);
    final s = VegaStrings(state.settings.isHindi);
    final p = HeritagePalette.of(context);
    final text = Theme.of(context).textTheme;

    final received = state.history
        .where((t) =>
            t.direction == TransferDirection.receive &&
            t.status == TransferStatus.completed)
        .toList();
    int count(_Kind k) =>
        k == _Kind.all ? received.length : received.where((t) => _kindOf(t.fileName) == k).length;
    final shown = received
        .where((t) => _filter == _Kind.all || _kindOf(t.fileName) == _filter)
        .where((t) => t.fileName.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    String label(_Kind k) {
      switch (k) {
        case _Kind.all:
          return s.t('All', 'सभी');
        case _Kind.photos:
          return s.t('Photos', 'फ़ोटो');
        case _Kind.videos:
          return s.t('Videos', 'वीडियो');
        case _Kind.documents:
          return s.t('Documents', 'दस्तावेज़');
      }
    }

    return HeritagePage(
      title: s.t('Files', 'फ़ाइलें'),
      subtitle: s.t('Saved & received files', 'सेव और मिली फ़ाइलें'),
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
                  decoration: InputDecoration(
                    hintText: s.t('Search files...', 'फ़ाइलें खोजें...'),
                    hintStyle: TextStyle(color: p.textMuted),
                    prefixIcon: Icon(Icons.search_rounded, color: p.textMuted),
                    filled: true,
                    fillColor: p.field,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: p.softBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: p.softBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: VegaColors.saffron),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final k in _Kind.values) ...[
                        HeritagePill(
                          label: '${label(k)} ${count(k)}',
                          selected: _filter == k,
                          onTap: () => setState(() => _filter = k),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: shown.isEmpty
                ? HeritagePanel(
                    radius: 28,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: p.field,
                              border: Border.all(
                                color: VegaColors.saffron.withValues(alpha: 0.5),
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Icon(Icons.folder_rounded, size: 34, color: p.accentText),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            s.t('No files found', 'कोई फ़ाइल नहीं मिली'),
                            style: text.titleSmall?.copyWith(
                              color: p.text,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.t(
                              'Files you receive appear here.',
                              'जो फ़ाइलें आप पाएँगे वे यहाँ दिखेंगी।',
                            ),
                            style: text.bodySmall?.copyWith(color: p.textMuted),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: shown.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final t = shown[i];
                      final kind = _kindOf(t.fileName);
                      return HeritagePanel(
                        tile: true,
                        radius: 18,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: p.field,
                                border: Border.all(color: p.softBorder),
                              ),
                              child: Icon(
                                kind == _Kind.photos
                                    ? Icons.image_outlined
                                    : kind == _Kind.videos
                                        ? Icons.movie_outlined
                                        : Icons.description_outlined,
                                color: p.accentText,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.fileName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.titleSmall?.copyWith(
                                      color: p.text,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${formatBytes(t.totalBytes)} · ${t.peerName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.bodySmall?.copyWith(color: p.textMuted),
                                  ),
                                ],
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
    );
  }
}
