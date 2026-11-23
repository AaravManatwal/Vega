import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/vega_strings.dart';
import '../state/app_state.dart';
import '../widgets/approval/action_bar.dart';
import '../widgets/approval/approval_strings.dart';
import '../widgets/approval/code_digits.dart';
import '../widgets/approval/file_card.dart';
import '../widgets/approval/link_orbit.dart';
import '../widgets/approval/trust_banner.dart';
import '../widgets/heritage/heritage_page.dart';

/// Sender side: shows the same match code while the receiver decides.
class SenderCodeScreen extends ConsumerWidget {
  const SenderCodeScreen({
    super.key,
    required this.peerName,
    required this.fileName,
    required this.totalBytes,
    required this.encrypted,
    required this.sas,
    required this.authenticated,
    required this.onCancel,
  });

  final String peerName;
  final String fileName;
  final int totalBytes;
  final bool encrypted;
  final String sas;
  final bool authenticated;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hi = ref.watch(hindiProvider);
    final str = ApprovalStrings(VegaStrings(hi));
    return PopScope(
      canPop: false, // Cancel is the only way out; the screen closes itself otherwise
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onCancel();
      },
      child: HeritagePage(
        title: str.sendMode,
        subtitle: str.senderTitle(peerName),
        showBack: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              LinkOrbit(
                mode: authenticated ? LinkOrbitMode.verified : LinkOrbitMode.waiting,
                fromName: str.you,
                toName: peerName,
              ),
              const SizedBox(height: 14),
              CodeDigits(digits: sas, caption: str.codeCaption),
              const SizedBox(height: 14),
              TrustBanner(
                variant: authenticated ? TrustVariant.verified : TrustVariant.waiting,
                title: str.waitingTitle,
                text: authenticated ? str.waitingVerifiedText : str.waitingText,
              ),
              const SizedBox(height: 14),
              FileCard(
                fileName: fileName,
                totalBytes: totalBytes,
                encrypted: encrypted,
                linkLabel: encrypted ? str.linkEncrypted : str.linkPlain,
              ),
              const SizedBox(height: 22),
              ActionBar(secondaryLabel: str.cancelMismatch, onSecondary: onCancel),
            ],
          ),
        ),
      ),
    );
  }
}
