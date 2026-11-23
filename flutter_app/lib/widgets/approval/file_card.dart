import 'package:flutter/material.dart';
import '../../models/transfer_models.dart';
import '../../theme/app_theme.dart';
import '../heritage/heritage_palette.dart';
import '../heritage/heritage_panel.dart';

/// File name, size and link status in a Material 3 card.
class FileCard extends StatefulWidget {
  const FileCard({
    super.key,
    required this.fileName,
    required this.totalBytes,
    required this.linkLabel,
    required this.encrypted,
  });

  final String fileName;
  final int totalBytes;
  final String linkLabel;
  final bool encrypted;

  @override
  State<FileCard> createState() => _FileCardState();
}

class _FileCardState extends State<FileCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
      _c.value = 1;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  IconData get _icon {
    final dot = widget.fileName.lastIndexOf('.');
    final ext = dot < 0 ? '' : widget.fileName.substring(dot + 1).toLowerCase();
    if (const {'mp4', 'mkv', 'mov', 'avi', 'webm', '3gp'}.contains(ext)) {
      return Icons.play_arrow_rounded;
    }
    if (const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'}.contains(ext)) {
      return Icons.image_outlined;
    }
    if (const {'mp3', 'wav', 'flac', 'm4a', 'aac', 'ogg'}.contains(ext)) {
      return Icons.music_note_rounded;
    }
    if (const {'zip', 'rar', '7z', 'tar', 'gz'}.contains(ext)) {
      return Icons.folder_zip_outlined;
    }
    if (ext == 'apk') return Icons.android;
    if (const {'pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx'}.contains(ext)) {
      return Icons.description_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final pal = HeritagePalette.of(context);
    final text = Theme.of(context).textTheme;
    final accent = pal.accentText;
    final linkColor = widget.encrypted ? pal.textMuted : VegaColors.warning;

    return HeritagePanel(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.45, end: 1).animate(_c),
                child: Icon(_icon, color: accent, size: 26),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium?.copyWith(color: pal.text),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        formatBytes(widget.totalBytes),
                        style: text.bodySmall?.copyWith(color: pal.textMuted),
                      ),
                      const SizedBox(width: 6),
                      Text('·', style: text.bodySmall?.copyWith(color: pal.textMuted)),
                      const SizedBox(width: 6),
                      Icon(
                        widget.encrypted ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                        size: 14,
                        color: linkColor,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          widget.linkLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(color: linkColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }
}
