import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/vega_logo.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class VegaSplashScreen extends StatefulWidget {
  const VegaSplashScreen({super.key});

  @override
  State<VegaSplashScreen> createState() => _VegaSplashScreenState();
}

class _VegaSplashScreenState extends State<VegaSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _mandalaController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  Timer? _navTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..forward();

    _mandalaController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 26),
    )..repeat();

    _scaleAnim = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutBack),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic),
    );

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
        pageBuilder: (_, __, ___) =>
            seen ? const HomeScreen() : const OnboardingScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _introController.dispose();
    _mandalaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _goHome,
      child: Scaffold(
        backgroundColor: VegaColors.deepNavy,
        body: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _HeritageSplashPainter()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Manatwal Innovations',
                          style: TextStyle(
                            color: VegaColors.lightSky,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: VegaColors.sandstoneGold.withValues(alpha: 0.45),
                            ),
                            color: VegaColors.deepNavy.withValues(alpha: 0.7),
                          ),
                          child: const Text(
                            'v1.0.0',
                            style: TextStyle(
                              color: VegaColors.goldHighlight,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: ScaleTransition(
                        scale: _scaleAnim,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Central Animated Rajasthani Mandala Crest rotating gracefully around VEGA Logo
                            SizedBox(
                              width: 224,
                              height: 224,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  RotationTransition(
                                    turns: _mandalaController,
                                    child: const SizedBox(
                                      width: 224,
                                      height: 224,
                                      child: CustomPaint(
                                        painter: _OuterMandalaPainter(),
                                      ),
                                    ),
                                  ),
                                  RotationTransition(
                                    turns: Tween<double>(begin: 1.0, end: 0.0)
                                        .animate(_mandalaController),
                                    child: const SizedBox(
                                      width: 162,
                                      height: 162,
                                      child: CustomPaint(
                                        painter: _InnerMandalaPainter(),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      boxShadow: [
                                        BoxShadow(
                                          color: VegaColors.electricBlue
                                              .withValues(alpha: 0.38),
                                          blurRadius: 34,
                                          spreadRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: const VegaLogo(size: 104),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            RichText(
                              text: const TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Vega ',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2.2,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'वेग',
                                    style: TextStyle(
                                      color: VegaColors.goldHighlight,
                                      fontSize: 23,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Offline File Sharing · Android & Windows',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: VegaColors.lightSky,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Column(
                      children: [
                        SizedBox(
                          width: 156,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              minHeight: 4,
                              backgroundColor:
                                  VegaColors.sandstoneGold.withValues(alpha: 0.22),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                VegaColors.electricBlue,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'AES-256-GCM · Zero Internet Required',
                          style: TextStyle(
                            color: VegaColors.goldHighlight.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OuterMandalaPainter extends CustomPainter {
  const _OuterMandalaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.45;

    // Outer Gold-Leaf dashed halo
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = VegaColors.sandstoneGold.withValues(alpha: 0.55),
    );

    canvas.drawCircle(
      center,
      r * 0.88,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = VegaColors.electricBlue.withValues(alpha: 0.45),
    );

    final petalPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = VegaColors.sandstoneGold.withValues(alpha: 0.72);

    final dotGoldPaint = Paint()..color = VegaColors.goldHighlight;
    final dotBluePaint = Paint()..color = VegaColors.electricBlue;

    // 16 Rajasthani Lotus Petals
    for (int i = 0; i < 16; i++) {
      final angle = (i * math.pi * 2) / 16;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);

      final petal = Path()
        ..moveTo(0, -r * 0.99)
        ..quadraticBezierTo(r * 0.08, -r * 0.84, 0, -r * 0.70)
        ..quadraticBezierTo(-r * 0.08, -r * 0.84, 0, -r * 0.99);
      canvas.drawPath(petal, petalPaint);

      canvas.drawCircle(
        Offset(0, -r * 0.99),
        i.isEven ? 2.4 : 1.7,
        i.isEven ? dotGoldPaint : dotBluePaint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InnerMandalaPainter extends CustomPainter {
  const _InnerMandalaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.44;

    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = VegaColors.sandstoneGold.withValues(alpha: 0.50),
    );

    // 8-point Jharokha diamond filigree
    final starPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = VegaColors.goldHighlight.withValues(alpha: 0.65);

    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi * 2) / 8;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      final diamond = Path()
        ..moveTo(0, -r * 0.96)
        ..lineTo(r * 0.11, -r * 0.80)
        ..lineTo(0, -r * 0.64)
        ..lineTo(-r * 0.11, -r * 0.80)
        ..close();
      canvas.drawPath(diamond, starPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeritageSplashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Deep Navy -> Midnight Blue Gradient
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            VegaColors.deepNavy,
            Color(0xFF071A3C),
            VegaColors.midnightBlue,
          ],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    // Subtle Rajasthani Jali Diamonds in Gold-Leaf
    final jaliPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = VegaColors.sandstoneGold.withValues(alpha: 0.065);
    const step = 42.0;
    for (double y = 0; y < size.height * 0.70; y += step) {
      for (double x = 0; x < size.width; x += step) {
        final diamond = Path()
          ..moveTo(x + step * 0.5, y + 3)
          ..lineTo(x + step - 3, y + step * 0.5)
          ..lineTo(x + step * 0.5, y + step - 3)
          ..lineTo(x + 3, y + step * 0.5)
          ..close();
        canvas.drawPath(diamond, jaliPaint);
      }
    }

    // Jharokha Cusped Arch Frame
    final arch = Path()
      ..moveTo(size.width * 0.08, size.height * 0.62)
      ..lineTo(size.width * 0.08, size.height * 0.22)
      ..cubicTo(
        size.width * 0.08,
        size.height * 0.14,
        size.width * 0.22,
        size.height * 0.12,
        size.width * 0.34,
        size.height * 0.12,
      )
      ..quadraticBezierTo(
        size.width * 0.44,
        size.height * 0.10,
        size.width * 0.50,
        size.height * 0.06,
      )
      ..quadraticBezierTo(
        size.width * 0.56,
        size.height * 0.10,
        size.width * 0.66,
        size.height * 0.12,
      )
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.12,
        size.width * 0.92,
        size.height * 0.14,
        size.width * 0.92,
        size.height * 0.22,
      )
      ..lineTo(size.width * 0.92, size.height * 0.42);
    canvas.drawPath(
      arch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = VegaColors.sandstoneGold.withValues(alpha: 0.28),
    );

    // Electric Blue S-Wave
    final crest = Path()
      ..moveTo(0, size.height * 0.65)
      ..cubicTo(
        size.width * 0.36,
        size.height * 0.65,
        size.width * 0.74,
        size.height * 0.54,
        size.width,
        size.height * 0.36,
      );

    final wave = Path.from(crest)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      wave,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomRight,
          colors: [
            VegaColors.electricBlue,
            Color(0xFF0055B8),
            VegaColors.midnightBlue,
          ],
        ).createShader(rect),
    );

    canvas.drawPath(
      crest,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = VegaColors.sandstoneGold.withValues(alpha: 0.72),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
