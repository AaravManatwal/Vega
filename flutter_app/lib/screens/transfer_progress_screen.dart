import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/vega_strings.dart';
import '../models/transfer_models.dart';
import '../state/app_state.dart';
import '../widgets/heritage/heritage_page.dart';
import '../widgets/heritage/mini_transfer_bar.dart';
import '../widgets/heritage/heritage_palette.dart';
import '../widgets/heritage/heritage_panel.dart';
import '../widgets/heritage/saffron_button.dart';
import '../widgets/progress/progress_ring.dart';
import 'history_settings_screens.dart';

/// One transfer, full screen, in the heritage design: ring, speed, time left, file.
class TransferProgressScreen extends ConsumerWidget {
  const TransferProgressScreen({super.key, required this.taskId});

  final String taskId;

  Duration? _remaining(TransferTask t) {
    if (t.speedBytesPerSec <= 0) return null;
    final left = t.totalBytes - t.transferredBytes;
    if (left <= 0) return Duration.zero;
    return Duration(seconds: (left / t.speedBytesPerSec).ceil());
  }

  static String _size(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1024 * 1024 * 1024) return '${(b / 1048576).toStringAsFixed(1)} MB';
    return '${(b / 1073741824).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(vegaProvider.select((s) => s.tasks[taskId]));
    final hi = ref.watch(vegaProvider.select((s) => s.settings.isHindi));
    final s = VegaStrings(hi);
    final p = HeritagePalette.of(context);

    if (task == null) {
      return HeritagePage(
        title: s.t('Transfer', 'ट्रांसफर'),
        child: Center(
          child: Text(s.t('This transfer is no longer available',
              'यह ट्रांसफर अब उपलब्ध नहीं है'),
              style: TextStyle(color: p.textMuted)),
        ),
      );
    }

    final sending = task.direction == TransferDirection.send;
    final done = task.status == TransferStatus.completed;
    final failed = task.status == TransferStatus.failed ||
        task.status == TransferStatus.cancelled;
    final verifying = task.status == TransferStatus.verifying;
    final paused = task.status == TransferStatus.paused;

    final title = done
        ? s.t('Transfer complete', 'ट्रांसफर पूरा हुआ')
        : failed
            ? s.t('Transfer stopped', 'ट्रांसफर रुक गया')
            : paused
                ? s.t('Transfer paused', 'ट्रांसफर रुका है')
                : sending
                    ? s.t('Sending', 'भेजा जा रहा है')
                    : s.t('Receiving', 'प्राप्त हो रहा है');
    final peerLine = sending
        ? s.t('To ${task.peerName}', '${task.peerName} को')
        : s.t('From ${task.peerName}', '${task.peerName} से');

    return SuppressMiniBar(child: HeritagePage(
      title: title,
      subtitle: peerLine,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: ProgressRing(
                hindi: hi,
                progress: task.progress,
                speedBytesPerSec: done ? 0 : task.speedBytesPerSec,
                remaining: _remaining(task),
                done: done,
              ),
            ),
            const SizedBox(height: 18),
            if (failed || verifying) ...[
              HeritagePanel(
                highlight: failed,
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      failed ? Icons.error_outline_rounded : Icons.hourglass_top_rounded,
                      color: p.accentText,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        failed
                            ? (task.errorMessage ??
                                s.t('Transfer did not finish. Please try again.',
                                    'ट्रांसफर पूरा नहीं हुआ। दोबारा कोशिश करें।'))
                            : s.t('Verifying the file…', 'फ़ाइल की जाँच हो रही है…'),
                        style: TextStyle(color: p.text, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            HeritagePanel(
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: p.accentText.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.insert_drive_file_outlined, color: p.accentText),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.fileName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: p.text, fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_size(task.transferredBytes)} / ${_size(task.totalBytes)}',
                          style: TextStyle(color: p.textMuted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Tag(
                  icon: task.encrypted ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                  label: task.encrypted
                      ? s.t('Encrypted', 'एन्क्रिप्टेड')
                      : s.t('Not encrypted', 'एन्क्रिप्टेड नहीं'),
                ),
                _Tag(
                  icon: task.integrityVerified
                      ? Icons.verified_outlined
                      : Icons.hourglass_empty_rounded,
                  label: task.integrityVerified
                      ? s.t('Verified', 'सत्यापित')
                      : s.t('Verified after completion', 'पूरा होने पर सत्यापन'),
                ),
              ],
            ),
            if (done && task.savedLocation != null) ...[
              const SizedBox(height: 10),
              Text(
                s.t('Saved to: ${task.savedLocation}', 'सेव हुआ: ${task.savedLocation}'),
                style: TextStyle(color: p.textMuted, fontSize: 12.5),
              ),
            ],
            const SizedBox(height: 22),
            _actions(context, ref, task, sending, done || failed, s, p),
          ],
        ),
      ),
    ));
  }

  Widget _actions(BuildContext context, WidgetRef ref, TransferTask task, bool sending,
      bool finished, VegaStrings s, HeritagePalette p) {
    final engine = ref.read(vegaProvider.notifier).engine;
    Widget ghost(String label, VoidCallback onTap) => OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: p.text,
            side: BorderSide(color: p.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          ),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        );

    if (finished) {
      return Column(children: [
        SaffronButton(
          label: s.t('Done', 'पूरा हुआ'),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(height: 10),
        ghost(s.t('View history', 'हिस्ट्री देखें'), () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HistoryScreen()),
          );
        }),
      ]);
    }
    if (sending) {
      final paused = task.status == TransferStatus.paused;
      return Column(children: [
        SaffronButton(
          label: paused ? s.t('Resume', 'फिर शुरू करें') : s.t('Pause', 'रोकें'),
          icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          onPressed: () =>
              paused ? engine.resumeTransfer(task.id) : engine.pauseTransfer(task.id),
        ),
        const SizedBox(height: 10),
        ghost(s.t('Cancel', 'रद्द करें'), () => engine.cancelTransfer(task.id)),
      ]);
    }
    return Column(children: [
      SaffronButton(
        label: s.t('Go back', 'पीछे जाएँ'),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      const SizedBox(height: 10),
      ghost(s.t('Stop transfer', 'ट्रांसफर रोकें'), () => engine.cancelTransfer(task.id)),
    ]);
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = HeritagePalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: p.tile,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.softBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: p.accentText),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: p.text, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
