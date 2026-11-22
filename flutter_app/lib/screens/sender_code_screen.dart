import 'package:flutter/material.dart';
import '../widgets/approval/action_bar.dart';
import '../widgets/approval/approval_strings.dart';
import '../widgets/approval/code_digits.dart';
import '../widgets/approval/file_card.dart';
import '../widgets/approval/link_orbit.dart';
import '../widgets/approval/trust_banner.dart';
import '../widgets/approval/vega_header.dart';

/// Sender side: shows the same match code while the receiver decides.
class SenderCodeScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false, // Cancel is the only way out; the screen closes itself otherwise
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onCancel();
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
                      const VegaHeader(mode: ApprovalStrings.sendMode),
                      const SizedBox(height: 24),
                      Text(
                        ApprovalStrings.senderTitle(peerName),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: cs.onSurface,
                              height: 1.15,
                            ),
                      ),
                      const SizedBox(height: 14),
                      LinkOrbit(
                        mode: authenticated ? LinkOrbitMode.verified : LinkOrbitMode.waiting,
                        fromName: ApprovalStrings.you,
                        toName: peerName,
                      ),
                      const SizedBox(height: 14),
                      CodeDigits(digits: sas, caption: ApprovalStrings.codeCaption),
                      const SizedBox(height: 14),
                      TrustBanner(
                        variant: authenticated ? TrustVariant.verified : TrustVariant.waiting,
                        title: ApprovalStrings.waitingTitle,
                        text: authenticated
                            ? ApprovalStrings.waitingVerifiedText
                            : ApprovalStrings.waitingText,
                      ),
                      const SizedBox(height: 14),
                      FileCard(
                        fileName: fileName,
                        totalBytes: totalBytes,
                        encrypted: encrypted,
                        linkLabel: encrypted
                            ? ApprovalStrings.linkEncrypted
                            : ApprovalStrings.linkPlain,
                      ),
                      const Spacer(),
                      const SizedBox(height: 14),
                      ActionBar(
                        secondaryLabel: ApprovalStrings.cancelMismatch,
                        onSecondary: onCancel,
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
