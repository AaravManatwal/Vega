import 'package:flutter/material.dart';
import '../core/approval.dart';
import '../widgets/approval/action_bar.dart';
import '../widgets/approval/approval_strings.dart';
import '../widgets/approval/code_digits.dart';
import '../widgets/approval/file_card.dart';
import '../widgets/approval/link_orbit.dart';
import '../widgets/approval/trust_banner.dart';
import '../widgets/approval/vega_header.dart';

/// Receiver side: "Rahul wants to send a file. Do the codes match? Accept?"
class ApprovalScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final verified = request.authenticated;

    final TrustVariant banner;
    final String bannerTitle;
    final String bannerText;
    if (!request.encrypted) {
      banner = TrustVariant.warning;
      bannerTitle = ApprovalStrings.plaintextTitle;
      bannerText = ApprovalStrings.plaintextText;
    } else if (verified) {
      banner = TrustVariant.verified;
      bannerTitle = ApprovalStrings.verifiedTitle;
      bannerText = ApprovalStrings.verifiedText;
    } else {
      banner = TrustVariant.warning;
      bannerTitle = ApprovalStrings.unverifiedTitle;
      bannerText = ApprovalStrings.unverifiedText;
    }

    return PopScope(
      canPop: false, // only Accept / Reject close this screen
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onDecision(false);
      },
      child: Scaffold(
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
                      const VegaHeader(mode: ApprovalStrings.receiveMode),
                      const SizedBox(height: 10),
                      _Countdown(expiresAt: request.expiresAt, window: window),
                      const SizedBox(height: 14),
                      Text(
                        ApprovalStrings.receiverTitle(request.senderName),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: cs.onSurface,
                              height: 1.15,
                            ),
                      ),
                      const SizedBox(height: 14),
                      LinkOrbit(
                        mode: verified ? LinkOrbitMode.verified : LinkOrbitMode.check,
                        fromName: request.senderName,
                        toName: ApprovalStrings.you,
                      ),
                      const SizedBox(height: 14),
                      if (verified) ...[
                        TrustBanner(variant: banner, title: bannerTitle, text: bannerText),
                        const SizedBox(height: 14),
                        CodeDigits(
                          digits: request.sas,
                          caption: ApprovalStrings.codeCaptionInfo,
                          tone: CodeTone.green,
                          compact: true,
                        ),
                      ] else ...[
                        CodeDigits(
                          digits: request.sas,
                          caption: ApprovalStrings.codeCaption,
                        ),
                        const SizedBox(height: 14),
                        TrustBanner(variant: banner, title: bannerTitle, text: bannerText),
                      ],
                      const SizedBox(height: 14),
                      FileCard(
                        fileName: request.fileName,
                        totalBytes: request.totalBytes,
                        encrypted: request.encrypted,
                        linkLabel: request.encrypted
                            ? ApprovalStrings.linkEncrypted
                            : ApprovalStrings.linkPlain,
                      ),
                      const Spacer(),
                      const SizedBox(height: 14),
                      ActionBar(
                        primaryLabel: verified
                            ? ApprovalStrings.accept
                            : ApprovalStrings.acceptAfterMatch,
                        secondaryLabel: ApprovalStrings.reject,
                        onPrimary: () => onDecision(true),
                        onSecondary: () => onDecision(false),
                      ),
                    ],
                  ),
                ),
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
  const _Countdown({required this.expiresAt, required this.window});
  final DateTime expiresAt;
  final Duration window;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
              child: LinearProgressIndicator(value: v, minHeight: 3),
            ),
            const SizedBox(height: 4),
            Text(
              ApprovalStrings.autoReject(seconds),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        );
      },
    );
  }
}
