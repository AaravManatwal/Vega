import 'dart:ui' show FontFeature;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../l10n/vega_strings.dart';
import '../models/transfer_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/heritage/heritage_page.dart';
import '../widgets/heritage/heritage_palette.dart';
import '../widgets/heritage/heritage_panel.dart';
import '../widgets/heritage/saffron_button.dart';
import 'radar_discovery_screen.dart';

enum _CategoryKind { photos, videos, documents, apps, audio, files }

class SendScreen extends ConsumerStatefulWidget {
  final List<({String path, String name, int size})>? initialFiles;

  const SendScreen({super.key, this.initialFiles});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  final List<({String path, String name, int size, _CategoryKind kind})> _items = [];
  final Set<int> _selectedIndices = {};
  _CategoryKind? _filter; // null = show everything
  bool _noteMode = false;
  final TextEditingController _noteTitle = TextEditingController();
  final TextEditingController _noteBody = TextEditingController();

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

  @override
  void dispose() {
    _noteTitle.dispose();
    _noteBody.dispose();
    super.dispose();
  }

  void _addPicked(List<PlatformFile> files, {String? relativeRoot}) {
    setState(() {
      for (final f in files) {
        final path = f.path;
        if (path == null) continue;
        final existing = _items.indexWhere((e) => e.path == path);
        if (existing != -1) {
          _selectedIndices.add(existing);
        } else {
          _items.add((path: path, name: f.name, size: f.size, kind: _inferKind(f.name)));
          _selectedIndices.add(_items.length - 1);
        }
      }
    });
  }

  Future<void> _pickFiles({FileType type = FileType.any}) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, type: type);
    if (result == null) return;
    _addPicked(result.files);
  }

  Future<void> _pickFolder() async {
    final s = VegaStrings(ref.read(vegaProvider).settings.isHindi);
    String? dir;
    try {
      dir = await FilePicker.platform.getDirectoryPath();
    } catch (_) {}
    if (dir == null) return;
    final found = <PlatformFile>[];
    try {
      await for (final e in Directory(dir).list(recursive: true, followLinks: false)) {
        if (e is File) {
          found.add(PlatformFile(path: e.path, name: p.basename(e.path), size: await e.length()));
          if (found.length >= 2000) break;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    if (found.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.t(
              'This folder cannot be read on this phone yet. Pick its files instead.',
              'इस फ़ोन पर यह फ़ोल्डर अभी नहीं पढ़ा जा सकता। इसकी फ़ाइलें चुनें।',
            ),
          ),
        ),
      );
      return;
    }
    _addPicked(found);
  }

  Future<void> _addNote() async {
    final body = _noteBody.text.trim();
    if (body.isEmpty) return;
    final title = _noteTitle.text.trim();
    final dir = await getTemporaryDirectory();
    final safe = (title.isEmpty ? 'Note' : title).replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File(p.join(dir.path, '$safe-${DateTime.now().millisecondsSinceEpoch}.txt'));
    await file.writeAsString(body);
    if (!mounted) return;
    setState(() {
      _items.add((
        path: file.path,
        name: '$safe.txt',
        size: file.lengthSync(),
        kind: _CategoryKind.documents,
      ));
      _selectedIndices.add(_items.length - 1);
      _noteMode = false;
      _noteTitle.clear();
      _noteBody.clear();
    });
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
        return Icons.insert_drive_file_outlined;
    }
  }

  String _kindLabel(VegaStrings s, _CategoryKind k) {
    switch (k) {
      case _CategoryKind.photos:
        return s.t('Photos', 'फ़ोटो');
      case _CategoryKind.videos:
        return s.t('Videos', 'वीडियो');
      case _CategoryKind.documents:
        return s.t('Docs', 'दस्तावेज़');
      case _CategoryKind.apps:
        return s.t('Apps', 'ऐप्स');
      case _CategoryKind.audio:
        return s.t('Audio', 'ऑडियो');
      case _CategoryKind.files:
        return s.t('Other', 'अन्य');
    }
  }

  void _openRadar(VegaStrings s) {
    final selected = <({String path, String name, int size})>[];
    for (final idx in _selectedIndices) {
      if (idx >= 0 && idx < _items.length) {
        final item = _items[idx];
        selected.add((path: item.path, name: item.name, size: item.size));
      }
    }
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.t('Choose at least one file first', 'पहले कम से कम एक फ़ाइल चुनें'),
          ),
        ),
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

  Widget _tile({
    required HeritagePalette pal,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool primary = false,
    bool highlight = false,
  }) {
    final fg = primary ? Colors.white : pal.text;
    final sub = primary ? VegaColors.goldPale : pal.textMuted;
    final inner = Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: primary ? Colors.white.withValues(alpha: 0.15) : pal.field,
            border: Border.all(
              color: primary
                  ? VegaColors.goldBorder.withValues(alpha: 0.5)
                  : pal.softBorder,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: primary ? Colors.white : pal.accentText,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w800),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: sub, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );

    if (primary) {
      return Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [VegaColors.saffron, VegaColors.saffronDeep, VegaColors.saffronShade],
              ),
              border: Border.all(color: VegaColors.goldBorder),
              boxShadow: [
                BoxShadow(
                  color: VegaColors.saffronDeep.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: inner,
          ),
        ),
      );
    }
    return HeritagePanel(
      tile: true,
      highlight: highlight,
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      onTap: onTap,
      child: inner,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = VegaStrings(ref.watch(vegaProvider.select((v) => v.settings.isHindi)));
    final pal = HeritagePalette.of(context);
    final text = Theme.of(context).textTheme;
    final selectedCount = _selectedIndices.length;

    final visible = <int>[
      for (var i = 0; i < _items.length; i++)
        if (_filter == null || _items[i].kind == _filter) i,
    ];
    final kindsPresent = <_CategoryKind>{for (final it in _items) it.kind};

    return HeritagePage(
      title: s.t('Send Files', 'फ़ाइलें भेजें'),
      subtitle: s.t(
        '$selectedCount ${selectedCount == 1 ? 'item' : 'items'} selected',
        '$selectedCount फ़ाइलें चुनी गईं',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.15,
            children: [
              _tile(
                pal: pal,
                icon: Icons.note_add_outlined,
                title: s.t('Pick Files', 'फ़ाइलें चुनें'),
                subtitle: s.t('Photos, video, docs', 'फ़ोटो, वीडियो, PDF'),
                primary: true,
                onTap: _pickFiles,
              ),
              _tile(
                pal: pal,
                icon: Icons.drive_folder_upload_outlined,
                title: s.t('Pick Folder', 'फ़ोल्डर चुनें'),
                subtitle: s.t('Entire directory', 'पूरा फ़ोल्डर भेजें'),
                onTap: _pickFolder,
              ),
              _tile(
                pal: pal,
                icon: Icons.description_outlined,
                title: s.t('Text Note', 'टेक्स्ट / नोट'),
                subtitle: s.t('Type text or link', 'लिंक या संदेश लिखें'),
                highlight: _noteMode,
                onTap: () => setState(() => _noteMode = !_noteMode),
              ),
              _tile(
                pal: pal,
                icon: Icons.photo_library_outlined,
                title: s.t('Gallery', 'गैलरी'),
                subtitle: s.t('Photos & videos', 'फ़ोटो और वीडियो'),
                onTap: () => _pickFiles(type: FileType.media),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _noteMode
                ? HeritagePanel(
                    radius: 24,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.t('Write Text or Link to Send', 'भेजने के लिए टेक्स्ट या लिंक लिखें'),
                                  style: text.titleSmall?.copyWith(
                                    color: pal.text,
                                    fontFamily: 'Cinzel', fontFamilyFallback: const ['NotoSansDevanagari'],
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(() => _noteMode = false),
                                child: Text(s.t('View List', 'सूची देखें')),
                              ),
                            ],
                          ),
                          TextField(
                            controller: _noteTitle,
                            style: TextStyle(color: pal.text),
                            decoration: InputDecoration(
                              hintText: s.t('Title (optional)', 'शीर्षक (वैकल्पिक)'),
                              hintStyle: TextStyle(color: pal.textMuted),
                              filled: true,
                              fillColor: pal.field,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _noteBody,
                            minLines: 4,
                            maxLines: 6,
                            style: TextStyle(color: pal.text),
                            decoration: InputDecoration(
                              hintText: s.t(
                                'Type or paste a message, password, or link here...',
                                'यहाँ कोई भी संदेश, पासवर्ड या लिंक पेस्ट करें...',
                              ),
                              hintStyle: TextStyle(color: pal.textMuted),
                              filled: true,
                              fillColor: pal.field,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: SaffronButton(
                              label: s.t('Add to Send List', 'सूची में जोड़ें'),
                              expand: false,
                              height: 42,
                              fontSize: 13,
                              onPressed: _addNote,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.t('Ready to Send', 'भेजने के लिए तैयार'),
                              style: text.titleSmall?.copyWith(
                                color: pal.dark ? VegaColors.skyText : const Color(0xFF5B4D38),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (selectedCount > 0)
                            TextButton(
                              onPressed: () => setState(_selectedIndices.clear),
                              child: Text(s.t('Clear Selection', 'चयन हटाएं')),
                            ),
                        ],
                      ),
                      if (kindsPresent.length > 1)
                        SizedBox(
                          height: 36,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              HeritagePill(
                                label: s.t('All', 'सभी'),
                                selected: _filter == null,
                                onTap: () => setState(() => _filter = null),
                              ),
                              for (final k in kindsPresent) ...[
                                const SizedBox(width: 8),
                                HeritagePill(
                                  label: _kindLabel(s, k),
                                  selected: _filter == k,
                                  onTap: () => setState(() => _filter = k),
                                ),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: visible.isEmpty
                            ? Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: pal.dark ? const Color(0xB30D224A) : const Color(0xBFFFFFFF),
                                  border: Border.all(color: pal.border),
                                ),
                                child: Text(
                                  _items.isEmpty
                                      ? s.t(
                                          'Choose Files, Folder, or Note above',
                                          'ऊपर से फ़ाइल, फ़ोल्डर या टेक्स्ट चुनें',
                                        )
                                      : s.t('No files match this filter', 'इस श्रेणी में कोई फ़ाइल नहीं है'),
                                  textAlign: TextAlign.center,
                                  style: text.titleSmall?.copyWith(
                                    color: pal.text,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: visible.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, i) {
                                  final idx = visible[i];
                                  final item = _items[idx];
                                  final checked = _selectedIndices.contains(idx);
                                  return HeritagePanel(
                                    tile: true,
                                    highlight: checked,
                                    radius: 18,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    onTap: () => setState(() {
                                      checked
                                          ? _selectedIndices.remove(idx)
                                          : _selectedIndices.add(idx);
                                    }),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(12),
                                            gradient: checked
                                                ? const LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      VegaColors.saffronLight,
                                                      VegaColors.saffronDark,
                                                    ],
                                                  )
                                                : null,
                                            color: checked ? null : pal.field,
                                            border: Border.all(color: pal.softBorder),
                                          ),
                                          child: Icon(
                                            _iconFor(item.kind),
                                            size: 20,
                                            color: checked ? Colors.white : pal.textMuted,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: text.titleSmall?.copyWith(
                                                  color: pal.text,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                formatBytes(item.size),
                                                style: text.bodySmall?.copyWith(
                                                  color: pal.textMuted,
                                                  fontFeatures: const [FontFeature.tabularFigures()],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: checked ? VegaColors.saffron : Colors.transparent,
                                            border: Border.all(
                                              color: checked
                                                  ? VegaColors.goldBorder
                                                  : pal.border,
                                            ),
                                          ),
                                          child: checked
                                              ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                                              : null,
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
          const SizedBox(height: 12),
          SaffronButton(
            label: s.t('Scan for Receivers', 'रिसीवर खोजें'),
            icon: Icons.podcasts_rounded,
            fontSize: 16.5,
            onPressed: () => _openRadar(s),
          ),
        ],
      ),
    );
  }
}
