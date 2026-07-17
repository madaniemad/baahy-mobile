import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/services/version_gate.dart';
import '../../../shared/theme/app_theme.dart';

// ─── Background widget — swaps to admin image when configured ──────────────────
class _SplashBackground extends ConsumerWidget {
  final Color teal;
  final Color tealLight;
  final Color tealDark;
  const _SplashBackground({required this.teal, required this.tealLight, required this.tealDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = ref.watch(appConfigProvider).splashBgImageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => Container(color: teal),
        errorWidget: (_, __, ___) => _gradient(teal, tealLight, tealDark),
      );
    }
    return _gradient(teal, tealLight, tealDark);
  }

  static Widget _gradient(Color teal, Color tealLight, Color tealDark) => Container(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: const Alignment(0, -0.72),
        radius: 1.48,
        colors: [tealLight, teal, tealDark],
        stops: const [0.0, 0.46, 1.0],
      ),
    ),
  );
}

// ─── Splash screen ─────────────────────────────────────────────────────────────
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {

  // Entry sequence controller
  late AnimationController _entryCtrl;

  // Looping controllers
  late AnimationController _breatheCtrl;
  late AnimationController _driftCtrl;

  // ── Derived animations ──────────────────────────────────────────────────────
  late Animation<double> _patternOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _squiggleScale;
  late Animation<double> _squiggleOpacity;
  late Animation<double> _taglineOpacity;
  late Animation<double> _taglineSlide;
  late Animation<double> _glowOpacity;
  late Animation<double> _breathe;
  late Animation<double> _drift;

  @override
  void initState() {
    super.initState();

    // ── Entry (2 s total) ──────────────────────────────────────────────────────
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..forward();

    _patternOpacity = Tween<double>(begin: 0, end: 0.92).animate(
        CurvedAnimation(parent: _entryCtrl,
            curve: const Interval(0.0, 0.25, curve: Curves.easeOut)));

    _logoScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.72, end: 1.04), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0),  weight: 30),
    ]).animate(CurvedAnimation(parent: _entryCtrl,
        curve: const Interval(0.075, 0.35, curve: Curves.easeOutCubic)));

    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _entryCtrl,
            curve: const Interval(0.075, 0.28, curve: Curves.easeOut)));

    _glowOpacity = Tween<double>(begin: 0, end: 0.45).animate(
        CurvedAnimation(parent: _entryCtrl,
            curve: const Interval(0.1, 0.4, curve: Curves.easeOut)));

    _squiggleScale = Tween<double>(begin: 0.82, end: 1.0).animate(
        CurvedAnimation(parent: _entryCtrl,
            curve: const Interval(0.30, 0.57, curve: Curves.easeOutBack)));

    _squiggleOpacity = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _entryCtrl,
            curve: const Interval(0.30, 0.50, curve: Curves.easeOut)));

    _taglineOpacity = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _entryCtrl,
            curve: const Interval(0.60, 0.85, curve: Curves.easeOut)));

    _taglineSlide = Tween<double>(begin: 14, end: 0).animate(
        CurvedAnimation(parent: _entryCtrl,
            curve: const Interval(0.60, 0.85, curve: Curves.easeOut)));

    // ── Breathe loop ───────────────────────────────────────────────────────────
    _breatheCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 6500));
    _breathe = Tween<double>(begin: 1.0, end: 1.025).animate(
        CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut));

    // ── Pattern drift loop ─────────────────────────────────────────────────────
    _driftCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 13000));
    _drift = Tween<double>(begin: 0, end: 7).animate(
        CurvedAnimation(parent: _driftCtrl, curve: Curves.easeInOut));

    _runSequence();
  }

  Future<void> _runSequence() async {
    _driftCtrl.repeat(reverse: true);

    // Start breathing after logo settles (~700ms into the 2s animation)
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    _breatheCtrl.repeat(reverse: true);

    // Navigate as the entry animation finishes (2 000 ms total from start)
    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    // Force-update gate (fail-open): block below the backend min_version.
    final gate = await VersionGate.check();
    if (!mounted) return;
    if (gate.forceUpdate) {
      context.go('/force-update', extra: gate);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final v2Done  = prefs.getBool('onboarding_v2_done') ?? false;
    if (!mounted) return;
    // Onboarding is one swipeable flow (city → products → rewards); city is its
    // first page, so route straight there for any non-finished user.
    context.go(v2Done ? '/home' : '/rewards-intro');
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _breatheCtrl.dispose();
    _driftCtrl.dispose();
    super.dispose();
  }

  // ── Colors ──────────────────────────────────────────────────────────────────
  static const _teal      = AppColors.primary;
  static const _tealLight = Color(0xFF53E2E9);
  static const _tealDark  = Color(0xFF2FCED5);
  static const _navy      = Color(0xFF0E3C46);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final gate = await VersionGate.check();
        if (!context.mounted) return;
        if (gate.forceUpdate) {
          context.go('/force-update', extra: gate);
          return;
        }
        final prefs = await SharedPreferences.getInstance();
        final v2Done = prefs.getBool('onboarding_v2_done') ?? false;
        if (!context.mounted) return;
        context.go(v2Done ? '/home' : '/rewards-intro');
      },
      child: Scaffold(
        backgroundColor: _teal,
        body: Stack(children: [
          // ── Background: admin image or default teal gradient ────────────
          _SplashBackground(teal: _teal, tealLight: _tealLight, tealDark: _tealDark),

          // ── Icon pattern band (top) ──────────────────────────────────────
          AnimatedBuilder(
            animation: Listenable.merge([_patternOpacity, _drift]),
            builder: (_, __) => Opacity(
              opacity: _patternOpacity.value,
              child: ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.transparent],
                  stops: [0.56, 1.0],
                ).createShader(r),
                blendMode: BlendMode.dstIn,
                child: Transform.translate(
                  offset: Offset(0, _drift.value),
                  child: Image.asset('assets/images/onb-pattern.png',
                    width: double.infinity, fit: BoxFit.fitWidth,
                    alignment: Alignment.topCenter),
                ),
              ),
            ),
          ),

          // ── Hero column: logo → squiggle → tagline ───────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo with glow
                AnimatedBuilder(
                  animation: Listenable.merge([_logoScale, _logoOpacity,
                      _glowOpacity, _breathe]),
                  builder: (_, __) {
                    final scale = _logoScale.value *
                        ((_breatheCtrl.isAnimating || _breatheCtrl.value > 0)
                            ? _breathe.value : 1.0);
                    return Stack(alignment: Alignment.center, children: [
                      Opacity(
                        opacity: _glowOpacity.value,
                        child: Container(
                          width: 340, height: 340,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              Colors.white.withValues(alpha: 0.55),
                              Colors.white.withValues(alpha: 0),
                            ]),
                          ),
                        ),
                      ),
                      Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(
                          scale: scale,
                          child: Image.asset('assets/images/onb-wordmark-white.png',
                            width: 258),
                        ),
                      ),
                    ]);
                  },
                ),

                const SizedBox(height: 18),

                // Squiggle
                AnimatedBuilder(
                  animation: Listenable.merge([_squiggleScale, _squiggleOpacity]),
                  builder: (_, __) => Opacity(
                    opacity: _squiggleOpacity.value,
                    child: Transform.scale(
                      scale: _squiggleScale.value,
                      child: Image.asset('assets/images/onb-squiggle.png', width: 104),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Tagline
                AnimatedBuilder(
                  animation: Listenable.merge([_taglineOpacity, _taglineSlide]),
                  builder: (_, __) => Opacity(
                    opacity: _taglineOpacity.value,
                    child: Transform.translate(
                      offset: Offset(0, _taglineSlide.value),
                      child: Image.asset('assets/images/onb-tagline.png',
                        width: 206,
                        color: Colors.white.withValues(alpha: 0.97),
                        colorBlendMode: BlendMode.modulate),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
