import 'dart:ui' show FontFeature, ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/vega_strings.dart';
import '../../models/transfer_models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import 'heritage_palette.dart';
import 'wavy_progress.dart';

/// Screens that already show the running transfer big (Home card, progress screen)
/// wrap themselves in [SuppressMiniBar] so the mini bar does not repeat it.
final ValueNotifier<int> miniBarSuppress = ValueNotifier<int>(0);

class SuppressMiniBar extends StatefulWidget {
  const SuppressMiniBar({super.key, required this.child});
  final Widget child;

  @override
  State<SuppressMiniBar> createState() => _SuppressMiniBarState();
}

class _SuppressMiniBarState extends State<SuppressMiniBar> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => miniBarSuppress.value++);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (miniBarSuppress.value > 0) miniBarSuppress.value--;
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Small frosted bar floating above the content while a transfer runs and the person is
/// on some other screen. Tap opens the full progress screen.
class MiniTransferBar extends ConsumerWidget {
  const MiniTransferBar({super.key, required this.onOpen});

  final void Function(String taskId) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<int>(
      valueListenable: miniBarSuppress,
      builder: (context, suppressed, _) {
        final active = ref.watch(vegaProvider.select((s) => s.activeTasks));
        if (suppressed > 0 || active.isEmpty) return const SizedBox.shrink();
        final task = active.first;
        final hi = ref.watch(hindiProvider);
        final s = VegaStrings(hi);
        final p = HeritagePalette.of(context);
        final sending = task.direction == TransferDirection.send;
        final engine = ref.read(vegaProvider.notifier).engine;
        final paused = task.status == TransferStatus.paused;
        final pct = (task.progress * 100).floor();
        const tnum = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, 12 + MediaQuery.paddingOf(context).bottom),
          child: RepaintBoundary(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Material(
                  color: p.panel.withValues(alpha: p.dark ? 0.78 : 0.88),
                  child: InkWell(
                    onTap: () => onOpen(task.id),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: p.border),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            sending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                            color: p.accentText,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.fileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: p.text, fontWeight: FontWeight.w700, fontSize: 13.5),
                                ),
                                const SizedBox(height: 4),
                                WavyProgress(value: task.progress, height: 10),
                                const SizedBox(height: 2),
                                Text(
                                  '$pct% · ${formatSpeed(task.speedBytesPerSec)}',
                                  style: tnum.copyWith(color: p.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          if (sending)
                            IconButton(
                              tooltip: paused ? s.t('Resume', 'फिर शुरू') : s.t('Pause', 'रोकें'),
                              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                              onPressed: () => paused
                                  ? engine.resumeTransfer(task.id)
                                  : engine.pauseTransfer(task.id),
                              icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                                  color: p.text),
                            ),
                          IconButton(
                            tooltip: s.t('Cancel', 'रद्द करें'),
                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                            onPressed: () => engine.cancelTransfer(task.id),
                            icon: Icon(Icons.close_rounded, color: p.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
