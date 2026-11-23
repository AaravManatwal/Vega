import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/approval.dart';
import '../l10n/vega_strings.dart';
import '../state/app_state.dart';
import '../widgets/approval/action_bar.dart';
import '../widgets/approval/approval_strings.dart';
import '../widgets/approval/code_digits.dart';
import '../widgets/approval/file_card.dart';
import '../widgets/approval/link_orbit.dart';
import '../widgets/approval/trust_banner.dart';
import '../widgets/heritage/heritage_page.dart';
import '../widgets/heritage/heritage_palette.dart';

/// Receiver side: "Rahul wants to send a file. Do the codes match? Accept?"
class ApprovalScreen extends ConsumerWidget {
  const ApprovalScreen({
    super.key,
    required this.request,
    required this.onDecision,
    this.window = const Duration(seconds: 60),
  });

  final ApprovalRequest request;
  final void Function(bool accept) onDecision;

  /// Total time the user has (used for the countdown bar).
  final Duration window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hi = ref.watch(hindiProvider);
    final str = ApprovalStrings(VegaStrings(hi));
    final verified = request.authenticated;

    final TrustVariant banner;
    final String bannerTitle;
    final String bannerText;
    if (!request.encrypted) {
      banner = TrustVariant.warning;
      bannerTitle = str.plaintextTitle;
      bannerText = str.plaintextText;
    } else if (verified) {
      banner = TrustVariant.verified;
      bannerTitle = str.verifiedTitle;
      bannerText = str.verifiedText;
    } else {
      banner = TrustVariant.warning;
      bannerTitle = str.unverifiedTitle;
      bannerText = str.unverifiedText;
    }

    return PopScope(
      canPop: false, // only Accept / Reject close this screen
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onDecision(false);
      },
      child: HeritagePage(
        title: str.receiveMode,
        subtitle: str.receiverTitle(request.senderName),
        showBack: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Countdown(expiresAt: request.expiresAt, window: window, str: str),
              const SizedBox(height: 14),
              LinkOrbit(
                mode: verified ? LinkOrbitMode.verified : LinkOrbitMode.check,
                fromName: request.senderName,
                toName: str.you,
              ),
              const SizedBox(height: 14),
              if (verified) ...[
                TrustBanner(variant: banner, title: bannerTitle, text: bannerText),
                const SizedBox(height: 14),
                CodeDigits(
                  digits: request.sas,
                  caption: str.codeCaptionInfo,
                  tone: CodeTone.green,
                  compact: true,
                ),
              ] else ...[
                CodeDigits(digits: request.sas, caption: str.codeCaption),
                const SizedBox(height: 14),
                TrustBanner(variant: banner, title: bannerTitle, text: bannerText),
              ],
              const SizedBox(height: 14),
              FileCard(
                fileName: request.fileName,
                totalBytes: request.totalBytes,
                encrypted: request.encrypted,
                linkLabel: request.encrypted ? str.linkEncrypted : str.linkPlain,
              ),
              const SizedBox(height: 22),
              ActionBar(
                primaryLabel: verified ? str.accept : str.acceptAfterMatch,
                secondaryLabel: str.reject,
                onPrimary: () => onDecision(true),
                onSecondary: () => onDecision(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thin bar that drains while the request is open ("auto reject in 42 s").
class _Countdown extends StatelessWidget {
  const _Countdown({required this.expiresAt, required this.window, required this.str});
  final DateTime expiresAt;
  final Duration window;
  final ApprovalStrings str;

  @override
  Widget build(BuildContext context) {
    final p = HeritagePalette.of(context);
    final left = expiresAt.difference(DateTime.now());
    final remaining = left.isNegative ? Duration.zero : left;
    final totalMs = window.inMilliseconds <= 0 ? 1 : window.inMilliseconds;
    final begin = (remaining.inMilliseconds / totalMs).clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: begin, end: 0),
      duration: remaining,
      builder: (context, v, _) {
        final seconds = (v * totalMs / 1000).ceil();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: v, minHeight: 4, color: p.accentText, backgroundColor: p.softBorder),
            ),
            const SizedBox(height: 4),
            Text(
              str.autoReject(seconds),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: p.textMuted),
            ),
          ],
        );
      },
    );
  }
}
