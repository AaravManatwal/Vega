import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/vega_logo.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

/// Splash: only the logo, and "by Manatwal Innovations" at the bottom.
class VegaSplashScreen extends StatefulWidget {
  const VegaSplashScreen({super.key});

  @override
  State<VegaSplashScreen> createState() => _VegaSplashScreenState();
}

class _VegaSplashScreenState extends State<VegaSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  Timer? _navTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 950))
      ..forward();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat();
    _scale = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: _intro, curve: Curves.easeOutBack));
    _fade = CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic);
    _navTimer = Timer(const Duration(milliseconds: 2200), _goHome);
  }

  Future<void> _goHome() async {
    if (_navigated || !mounted) return;
    _navigated = true;
    final seen = await OnboardingScreen.alreadySeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, __, ___) => seen ? const HomeScreen() : const OnboardingScreen(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      onTap: _goHome,
      child: Scaffold(
        backgroundColor: VegaColors.deepNavy,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.1),
                  radius: 1.1,
                  colors: [Color(0xFF12306B), Color(0xFF0A1F44), Color(0xFF04122B)],
                  stops: [0, 0.5, 1],
                ),
              ),
            ),
            Center(
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: SizedBox(
                    width: 280,
                    height: 280,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (!still)
                          AnimatedBuilder(
                            animation: _pulse,
                            builder: (_, __) => CustomPaint(
                              size: const Size.square(280),
                              painter: _PulsePainter(_pulse.value),
                            ),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(46),
                            boxShadow: [
                              BoxShadow(
                                color: VegaColors.saffron.withValues(alpha: 0.4),
                                blurRadius: 44,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const VegaLogo(size: 168),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 56,
              child: FadeTransition(
                opacity: _fade,
                child: const Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: 'by ',
                      style: TextStyle(color: VegaColors.goldBorder),
                    ),
                    TextSpan(
                      text: 'MANATWAL INNOVATIONS',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ]),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, letterSpacing: 2.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (final shift in [0.0, 0.5]) {
      final v = (t + shift) % 1.0;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = (shift == 0 ? VegaColors.saffron : VegaColors.goldBorder)
            .withValues(alpha: (1 - v) * 0.55);
      canvas.drawCircle(c, size.width * (0.34 + 0.16 * v), paint);
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.t != t;
}
