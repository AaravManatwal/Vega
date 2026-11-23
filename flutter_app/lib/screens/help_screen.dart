import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/vega_strings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/heritage/heritage_page.dart';
import '../widgets/heritage/heritage_palette.dart';
import '../widgets/heritage/heritage_panel.dart';
import 'receive_screen.dart';

/// "How it works": three steps and common questions (same content as the web design).
class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = VegaStrings(ref.watch(vegaProvider.select((v) => v.settings.isHindi)));
    final p = HeritagePalette.of(context);
    final text = Theme.of(context).textTheme;

    final steps = <(String, String)>[
      (
        s.t('Connect to Same Wi-Fi or Hotspot', 'एक ही Wi-Fi या हॉटस्पॉट से जुड़ें'),
        s.t(
          'Connect both devices to the same Wi-Fi or mobile hotspot. Internet is not required.',
          'दोनों डिवाइस को एक ही Wi-Fi या मोबाइल हॉटस्पॉट से जोड़ें। इंटरनेट ज़रूरी नहीं है।',
        ),
      ),
      (
        s.t('Scan QR or Pick Device', 'QR स्कैन करें या डिवाइस चुनें'),
        s.t(
          'Scan the QR code on the Receive screen, enter the short code, or pick a nearby device.',
          'रिसीव स्क्रीन का QR कोड स्कैन करें, छोटा कोड डालें, या पास का डिवाइस चुनें।',
        ),
      ),
      (
        s.t('Choose Files & Send', 'फ़ाइलें चुनें और भेजें'),
        s.t(
          'Pick your files and tap Send. Once the other person accepts, they save straight to that device.',
          'फ़ाइलें चुनकर भेजें दबाएँ। सामने वाले के स्वीकार करते ही वे सीधे उसके डिवाइस में सेव होती हैं।',
        ),
      ),
    ];

    final faqs = <(String, String)>[
      (
        s.t('Device Not Showing Up?', 'डिवाइस नहीं दिख रहा?'),
        s.t(
          'Make sure both devices are on the same Wi-Fi or hotspot, or scan the QR code directly.',
          'दोनों डिवाइस एक ही Wi-Fi या हॉटस्पॉट पर हों, या QR कोड सीधे स्कैन करें।',
        ),
      ),
      (
        s.t('QR or Code Expired?', 'QR या कोड की समय सीमा खत्म?'),
        s.t(
          'Codes expire after a short time for safety. Tap Refresh on the Receive screen for a new one.',
          'सुरक्षा के लिए कोड थोड़ी देर में खत्म हो जाते हैं। रिसीव स्क्रीन पर रिफ़्रेश दबाकर नया लें।',
        ),
      ),
      (
        s.t('Camera Not Available?', 'कैमरा उपलब्ध नहीं?'),
        s.t(
          'If camera access is off, type the short code shown below the QR code.',
          'कैमरा बंद हो तो QR के नीचे दिखा छोटा कोड टाइप करें।',
        ),
      ),
      (
        s.t('Where Are Received Files Saved?', 'मिली हुई फ़ाइलें कहाँ सेव होती हैं?'),
        s.t(
          'Received files go to your Downloads folder and also appear inside the Files screen.',
          'मिली फ़ाइलें Downloads फ़ोल्डर में जाती हैं और Files स्क्रीन में भी दिखती हैं।',
        ),
      ),
    ];

    return HeritagePage(
      title: s.t('How It Works', 'कैसे काम करता है'),
      subtitle: s.t('Simple steps for offline sharing', 'ऑफ़लाइन शेयरिंग के सरल चरण'),
      trailing: _MiniButton(
        label: s.t('Receive & QR', 'रिसीव और QR'),
        icon: Icons.qr_code_2_rounded,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ReceiveScreen()),
        ),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            HeritagePanel(
              radius: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [VegaColors.saffron, VegaColors.saffronDark],
                      ),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    steps[i].$1,
                    style: text.titleSmall?.copyWith(color: p.text, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    steps[i].$2,
                    style: text.bodySmall?.copyWith(color: p.textMuted, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          HeritagePanel(
            radius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('Common Questions', 'आम सवाल'),
                  style: text.titleMedium?.copyWith(color: p.text, fontFamily: 'serif'),
                ),
                const SizedBox(height: 12),
                for (final q in faqs) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: p.field,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: p.softBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.help_outline_rounded, size: 17, color: p.accentText),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                q.$1,
                                style: text.labelLarge?.copyWith(
                                  color: p.text,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          q.$2,
                          style: text.bodySmall?.copyWith(color: p.textMuted, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Ink(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              colors: [VegaColors.saffron, VegaColors.saffronDark],
            ),
            border: Border.all(color: VegaColors.goldBorder.withValues(alpha: 0.8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
