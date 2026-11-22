import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/transfer_models.dart';
import '../theme/app_theme.dart';
import 'radar_discovery_screen.dart';

enum _CategoryKind { photos, videos, documents, apps, audio, files }

class SendScreen extends StatefulWidget {
  final List<({String path, String name, int size})>? initialFiles;

  const SendScreen({super.key, this.initialFiles});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final List<({String path, String name, int size, _CategoryKind kind})> _items = [];
  final Set<int> _selectedIndices = {};
  _CategoryKind _activeCategory = _CategoryKind.photos;

  @override
  void initState() {
    super.initState();
    if (widget.initialFiles != null && widget.initialFiles!.isNotEmpty) {
      for (final f in widget.initialFiles!) {
        final idx = _items.length;
        _items.add((
          path: f.path,
          name: f.name,
          size: f.size,
          kind: _inferKind(f.name),
        ));
        _selectedIndices.add(idx);
      }
    }
  }

  _CategoryKind _inferKind(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic')) {
      return _CategoryKind.photos;
    }
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm')) {
      return _CategoryKind.videos;
    }
    if (lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.flac')) {
      return _CategoryKind.audio;
    }
    if (lower.endsWith('.apk') || lower.endsWith('.exe') || lower.endsWith('.zip')) {
      return _CategoryKind.apps;
    }
    if (lower.endsWith('.pdf') ||
        lower.endsWith('.doc') ||
        lower.endsWith('.docx') ||
        lower.endsWith('.txt') ||
        lower.endsWith('.xlsx')) {
      return _CategoryKind.documents;
    }
    return _CategoryKind.files;
  }

  Future<void> _pickCategory(_CategoryKind kind) async {
    setState(() => _activeCategory = kind);

    FileType type = FileType.any;
    List<String>? extensions;
    switch (kind) {
      case _CategoryKind.photos:
        type = FileType.image;
        break;
      case _CategoryKind.videos:
        type = FileType.video;
        break;
      case _CategoryKind.audio:
        type = FileType.audio;
        break;
      case _CategoryKind.documents:
        type = FileType.custom;
        extensions = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv'];
        break;
      case _CategoryKind.apps:
        // Play Store compliant: opens standard file picker for .apk/.zip without QUERY_ALL_PACKAGES
        type = FileType.custom;
        extensions = ['apk', 'zip'];
        break;
      case _CategoryKind.files:
        type = FileType.any;
        break;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: type,
      allowedExtensions: extensions,
    );
    if (result == null) return;

    setState(() {
      for (final f in result.files) {
        if (f.path == null) continue;
        final existingIdx = _items.indexWhere((e) => e.path == f.path);
        if (existingIdx != -1) {
          _selectedIndices.add(existingIdx);
        } else {
          final nextIdx = _items.length;
          _items.add((
            path: f.path!,
            name: f.name,
            size: f.size,
            kind: kind,
          ));
          _selectedIndices.add(nextIdx);
        }
      }
    });
  }

  int _countFor(_CategoryKind kind) {
    if (kind == _CategoryKind.files) return _items.length;
    return _items.where((item) => item.kind == kind).length;
  }

  IconData _iconFor(_CategoryKind kind) {
    switch (kind) {
      case _CategoryKind.photos:
        return Icons.image_outlined;
      case _CategoryKind.videos:
        return Icons.videocam_outlined;
      case _CategoryKind.documents:
        return Icons.description_outlined;
      case _CategoryKind.apps:
        return Icons.apps_rounded;
      case _CategoryKind.audio:
        return Icons.music_note_rounded;
      case _CategoryKind.files:
        return Icons.folder_outlined;
    }
  }

  void _openRadar() {
    final selected = <({String path, String name, int size})>[];
    for (final idx in _selectedIndices) {
      if (idx >= 0 && idx < _items.length) {
        final item = _items[idx];
        selected.add((path: item.path, name: item.name, size: item.size));
      }
    }
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tap any category above to select files first')),
      );
      return;
    }
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RadarDiscoveryScreen(filesToSend: selected),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedIndices.length;

    return Scaffold(
      backgroundColor: VegaColors.deepCanvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Integrated Header inside the Send Card
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Send Files · भेजें',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '$selectedCount file${selectedCount == 1 ? '' : 's'} selected · Unlimited size',
                              style: const TextStyle(
                                color: VegaColors.goldHighlight,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

              // 2x3 Category Grid matching Photo 2
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
                children: [
                  _CategoryTileCard(
                    label: 'Photos',
                    count: _countFor(_CategoryKind.photos),
                    icon: Icons.image_outlined,
                    selected: _activeCategory == _CategoryKind.photos,
                    onTap: () => _pickCategory(_CategoryKind.photos),
                  ),
                  _CategoryTileCard(
                    label: 'Videos',
                    count: _countFor(_CategoryKind.videos),
                    icon: Icons.videocam_outlined,
                    selected: _activeCategory == _CategoryKind.videos,
                    onTap: () => _pickCategory(_CategoryKind.videos),
                  ),
                  _CategoryTileCard(
                    label: 'Documents',
                    count: _countFor(_CategoryKind.documents),
                    icon: Icons.description_outlined,
                    selected: _activeCategory == _CategoryKind.documents,
                    onTap: () => _pickCategory(_CategoryKind.documents),
                  ),
                  _CategoryTileCard(
                    label: 'Apps',
                    count: _countFor(_CategoryKind.apps),
                    icon: Icons.apps_rounded,
                    selected: _activeCategory == _CategoryKind.apps,
                    onTap: () => _pickCategory(_CategoryKind.apps),
                  ),
                  _CategoryTileCard(
                    label: 'Audio',
                    count: _countFor(_CategoryKind.audio),
                    icon: Icons.music_note_rounded,
                    selected: _activeCategory == _CategoryKind.audio,
                    onTap: () => _pickCategory(_CategoryKind.audio),
                  ),
                  _CategoryTileCard(
                    label: 'Files',
                    count: _countFor(_CategoryKind.files),
                    icon: Icons.folder_outlined,
                    selected: _activeCategory == _CategoryKind.files,
                    onTap: () => _pickCategory(_CategoryKind.files),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Text(
                'Available Files',
                style: TextStyle(
                  color: VegaColors.goldHighlight,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),

              // Checklist matching Photo 2
              Expanded(
                child: _items.isEmpty
                    ? Center(
                        child: Text(
                          'Tap any category above to browse\nand queue files for fast transfer.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: VegaColors.lightSky.withValues(alpha: 0.7),
                            fontSize: 13.5,
                            height: 1.5,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final item = _items[idx];
                          final isChecked = _selectedIndices.contains(idx);
                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isChecked) {
                                  _selectedIndices.remove(idx);
                                } else {
                                  _selectedIndices.add(idx);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: VegaColors.deepNavy,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isChecked
                                      ? VegaColors.sandstoneGold.withValues(alpha: 0.85)
                                      : VegaColors.sandstoneGold.withValues(alpha: 0.30),
                                  width: isChecked ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isChecked
                                          ? VegaColors.electricBlue
                                          : VegaColors.deepCanvas,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _iconFor(item.kind),
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          formatBytes(item.size),
                                          style: const TextStyle(
                                            color: VegaColors.lightSky,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isChecked
                                          ? VegaColors.electricBlue
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isChecked
                                            ? VegaColors.sandstoneGold
                                            : VegaColors.sandstoneGold
                                                .withValues(alpha: 0.4),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: isChecked
                                        ? const Icon(
                                            Icons.check,
                                            size: 17,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 14),
              // Full-width Electric Blue + Gold-Leaf CTA
              SizedBox(
                height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: VegaColors.sandstoneGold.withValues(alpha: 0.72),
                    ),
                  ),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: VegaColors.electricBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: _openRadar,
                    icon: const Icon(
                      Icons.radar,
                      color: VegaColors.goldHighlight,
                    ),
                    label: const Text(
                      'Scan for Receivers',
                      style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
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

class _CategoryTileCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTileCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    VegaColors.electricBlue,
                    VegaColors.midnightBlue,
                  ],
                )
              : null,
          color: selected ? null : VegaColors.deepNavy,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? VegaColors.goldHighlight.withValues(alpha: 0.85)
                : VegaColors.sandstoneGold.withValues(alpha: 0.35),
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : VegaColors.goldHighlight,
              size: 26,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$count',
              style: TextStyle(
                color: selected
                    ? Colors.white.withValues(alpha: 0.92)
                    : VegaColors.sandstoneGold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
