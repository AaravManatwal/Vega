import 'package:flutter/material.dart';
import '../../models/transfer_models.dart';
import '../../theme/app_theme.dart';

/// Compact card for a running transfer; tap to open the full progress screen.
class LiveTransferCard extends StatelessWidget {
  const LiveTransferCard({super.key, required this.task, required this.onTap});

  final TransferTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final pct = (task.progress * 100).round();
    final sending = task.direction == TransferDirection.send;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: '${sending ? 'Sending' : 'Receiving'}: ${task.fileName}, $pct%',
      child: Material(
        color: cs.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: VegaColors.sandstoneGold.withValues(alpha: 0.4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      sending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      size: 18,
                      color: dark ? VegaColors.goldHighlight : cs.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall?.copyWith(color: cs.onSurface),
                      ),
                    ),
                    Text(
                      '$pct% · ${formatSpeed(task.speedBytesPerSec)}',
                      style: text.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: task.progress),
                  duration: VegaMotion.medium,
                  curve: VegaMotion.decelerate,
                  builder: (context, v, _) => LinearProgressIndicator(value: v),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
