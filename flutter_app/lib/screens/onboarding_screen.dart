import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

/// Three short pages shown once, the first time Vega opens.
class OnboardingScreen extends StatefulWidget {
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
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Page {
  const _Page(this.icon, this.title, this.text);
  final IconData icon;
  final String title;
  final String text;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pages = <_Page>[
    _Page(
      Icons.bolt_rounded,
      'Internet ke bina, tezi se',
      'Vega aas-paas ke phone ya laptop ko seedha Wi-Fi par file bhejta hai. '
          'Na data lagta hai, na koi server beech me aata hai.',
    ),
    _Page(
      Icons.verified_user_rounded,
      'Pehle code milaiye, phir Accept',
      'Dono phone par ek 6 ank ka code dikhta hai. Code same ho to hi file lein. '
          'Har file locked rehti hai aur poori aane par jaanchi jaati hai.',
    ),
    _Page(
      Icons.pause_circle_rounded,
      'Beech me ruk jaye to koi baat nahi',
      'Connection toot jaye to transfer wahin se dobara shuru hota hai. '
          'Aap Pause, Resume ya Cancel jab chahein kar sakte hain.',
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
    if (_index >= _pages.length - 1) {
      _finish();
    } else {
      _controller.nextPage(duration: VegaMotion.medium, curve: VegaMotion.decelerate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final last = _index == _pages.length - 1;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Chhodiye'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final page = _pages[i];
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
                  for (int i = 0; i < _pages.length; i++)
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
                  child: Text(last ? 'Shuru karein' : 'Aage'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
