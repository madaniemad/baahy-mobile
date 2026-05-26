import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;
  late List<AnimationController> _dotCtrls;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _dotCtrls = List.generate(3, (i) {
      final c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1200));
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });

    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final cityChosen = prefs.getString('city') != null;

    if (!cityChosen) {
      context.go('/city');
    } else {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    for (final c in _dotCtrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFF5F5F5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FadeTransition(
          opacity: _fade,
          child: Stack(children: [
            Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('baahy',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 64, fontWeight: FontWeight.w800,
                    color: AppColors.primary, letterSpacing: -1, height: 1)),
                const SizedBox(height: 10),
                const Text('سوق ليبيا الإلكتروني',
                  style: TextStyle(fontSize: 13, color: AppColors.ink3)),
              ]),
            ),
            Positioned(
              bottom: 60,
              left: 0, right: 0,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (int i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  AnimatedBuilder(
                    animation: _dotCtrls[i],
                    builder: (_, __) => Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.teal600.withValues(
                          alpha: 0.3 + 0.7 * _dotCtrls[i].value),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
