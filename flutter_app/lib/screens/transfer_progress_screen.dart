import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transfer_models.dart';
import '../state/app_state.dart';
import '../widgets/approval/action_bar.dart';
import '../widgets/approval/approval_strings.dart';
import '../widgets/approval/file_card.dart';
import '../widgets/approval/trust_banner.dart';
import '../widgets/approval/vega_header.dart';
import '../widgets/progress/progress_ring.dart';
import 'history_settings_screens.dart';

/// One transfer, full screen: ring, speed, time left, file, integrity tags.
class TransferProgressScreen extends ConsumerWidget {
  const TransferProgressScreen({super.key, required this.taskId});

  final String taskId;

  Duration? _remaining(TransferTask t) {
    if (t.speedBytesPerSec <= 0) return null;
    final left = t.totalBytes - t.transferredBytes;
    if (left <= 0) return Duration.zero;
    return Duration(seconds: (left / t.speedBytesPerSec).ceil());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(vegaProvider.select((s) => s.tasks[taskId]));
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (task == null) {
      return Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(),
        body: const Center(child: Text('Ye transfer ab nahi mila')),
      );
    }

    final sending = task.direction == TransferDirection.send;
    final done = task.status == TransferStatus.completed;
    final failed = task.status == TransferStatus.failed ||
        task.status == TransferStatus.cancelled;
    final verifying = task.status == TransferStatus.verifying;

    final title = done
        ? (sending ? '${task.peerName} ko bhej diya' : '${task.peerName} se mil gaya')
        : failed
            ? 'Transfer ruk gaya'
            : task.status == TransferStatus.paused
                ? 'Transfer roka hua hai'
                : (sending
                ? '${task.peerName} ko bhej rahe hain'
                : '${task.peerName} se mil raha hai');

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    VegaHeader(
                      mode: sending
                          ? ApprovalStrings.sendMode
                          : ApprovalStrings.receiveMode,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      style: text.headlineSmall?.copyWith(color: cs.onSurface, height: 1.15),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: ProgressRing(
                        progress: task.progress,
                        speedBytesPerSec: done ? 0 : task.speedBytesPerSec,
                        remaining: _remaining(task),
                        done: done,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (failed)
                      TrustBanner(
                        variant: TrustVariant.warning,
                        title: 'Transfer poora nahi hua',
                        text: task.errorMessage ?? 'Dobara koshish kijiye.',
                      )
                    else if (verifying)
                      const TrustBanner(
                        variant: TrustVariant.waiting,
                        title: 'Jaanch ho rahi hai',
                        text: 'File ka hash milaya ja raha hai.',
                      ),
                    if (failed || verifying) const SizedBox(height: 14),
                    FileCard(
                      fileName: task.fileName,
                      totalBytes: task.totalBytes,
                      encrypted: task.encrypted,
                      linkLabel: task.encrypted
                          ? ApprovalStrings.linkEncrypted
                          : ApprovalStrings.linkPlain,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Tag(
                          icon: task.encrypted ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                          label: task.encrypted ? 'Encrypted' : 'Encrypted nahi',
                        ),
                        _Tag(
                          icon: task.integrityVerified
                              ? Icons.verified_outlined
                              : Icons.hourglass_empty_rounded,
                          label: task.integrityVerified
                              ? 'Verified'
                              : 'Verified: poora hone ke baad',
                        ),
                      ],
                    ),
                    if (done && task.savedLocation != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Save hua: ${task.savedLocation}',
                        style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                    const Spacer(),
                    const SizedBox(height: 14),
                    _actions(context, ref, task, sending, done || failed),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions(
    BuildContext context,
    WidgetRef ref,
    TransferTask task,
    bool sending,
    bool finished,
  ) {
    if (finished) {
      return ActionBar(
        primaryLabel: 'Ho gaya',
        secondaryLabel: 'History dekhein',
        onPrimary: () => Navigator.of(context).maybePop(),
        onSecondary: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HistoryScreen()),
          );
        },
      );
    }
    if (sending) {
      final engine = ref.read(vegaProvider.notifier).engine;
      final paused = task.status == TransferStatus.paused;
      return ActionBar(
        primaryLabel: paused ? 'Resume' : 'Pause',
        onPrimary: () =>
            paused ? engine.resumeTransfer(task.id) : engine.pauseTransfer(task.id),
        secondaryLabel: 'Cancel',
        onSecondary: () => engine.cancelTransfer(task.id),
      );
    }
    // Receiving: the user can stop it (the partial file is discarded) or just leave.
    final engine = ref.read(vegaProvider.notifier).engine;
    return ActionBar(
      primaryLabel: 'Peeche jaaiye',
      onPrimary: () => Navigator.of(context).maybePop(),
      secondaryLabel: 'Transfer rokein',
      onSecondary: () => engine.cancelTransfer(task.id),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(icon, size: 16, color: cs.onSurfaceVariant),
      label: Text(label),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurface),
      backgroundColor: cs.surfaceContainer,
      visualDensity: VisualDensity.compact,
    );
  }
}
