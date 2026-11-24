import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/vega_strings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

/// Three short pages shown once, the first time Vega opens.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  static const String prefsKey = 'vega_onboarded_v1';

  static Future<bool> alreadySeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(prefsKey) ?? false;
    } catch (_) {
      return true; // never trap the user on this screen
    }
  }

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Page {
  const _Page(this.icon, this.title, this.text);
  final IconData icon;
  final String title;
  final String text;
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  List<_Page> _pages(VegaStrings s) => [
        _Page(
          Icons.bolt_rounded,
          s.t('Fast, without internet', 'इंटरनेट के बिना, तेज़ी से'),
          s.t(
            'Vega sends files straight to nearby phones and laptops over Wi-Fi. No mobile data, no server in between.',
            'Vega आस-पास के फ़ोन या लैपटॉप को सीधे Wi-Fi पर फ़ाइल भेजता है। न डेटा लगता है, न बीच में कोई सर्वर।',
          ),
        ),
        _Page(
          Icons.verified_user_rounded,
          s.t('Match the code, then Accept', 'पहले कोड मिलाइए, फिर Accept'),
          s.t(
            'Both phones show the same 6-digit code. Accept only if it matches. Every file stays locked and is verified when it arrives.',
            'दोनों फ़ोन पर एक जैसा 6 अंकों का कोड दिखता है। कोड मिले तभी फ़ाइल लें। हर फ़ाइल लॉक रहती है और पूरी आने पर जाँची जाती है।',
          ),
        ),
        _Page(
          Icons.pause_circle_rounded,
          s.t('Interrupted? No problem', 'बीच में रुक जाए तो कोई बात नहीं'),
          s.t(
            'If the connection drops, the transfer resumes where it stopped. You can Pause, Resume or Cancel any time.',
            'कनेक्शन टूट जाए तो ट्रांसफ़र वहीं से दोबारा शुरू होता है। आप जब चाहें Pause, Resume या Cancel कर सकते हैं।',
          ),
        ),
      ];

  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(OnboardingScreen.prefsKey, true);
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    );
  }

  void _next() {
    if (_index >= 2) {
      _finish();
    } else {
      _controller.nextPage(duration: VegaMotion.medium, curve: VegaMotion.decelerate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final hi = ref.watch(hindiProvider);
    final str = VegaStrings(hi);
    final pages = _pages(str);
    final last = _index == pages.length - 1;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      final c = ref.read(vegaProvider.notifier);
                      c.updateSettings(
                          ref.read(vegaProvider).settings.copyWith(language: hi ? 'en' : 'hi'));
                    },
                    child: Text(hi ? 'English' : 'हिन्दी'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    child: Text(str.t('Skip', 'छोड़ें')),
                  ),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final page = pages[i];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 148,
                          height: 148,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [cs.primaryContainer, cs.tertiaryContainer],
                            ),
                          ),
                          child: Icon(page.icon, size: 72, color: cs.onPrimaryContainer),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: text.headlineSmall?.copyWith(color: cs.onSurface),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          page.text,
                          textAlign: TextAlign.center,
                          style: text.bodyLarge?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < pages.length; i++)
                    AnimatedContainer(
                      duration: VegaMotion.short,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index ? cs.primary : cs.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(last ? str.t('Get started', 'शुरू करें') : str.t('Next', 'आगे')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
