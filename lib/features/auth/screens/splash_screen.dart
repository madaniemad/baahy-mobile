import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/theme/app_theme.dart';

// ─── Bubble data (fixed positions so it doesn't reshuffle on re-render) ───────
class _BubbleDef {
  final double left;   // 0–1 fraction of screen width
  final double size;
  final double delay;  // seconds
  final double dur;    // seconds
  final bool blur;
  final bool bright;   // white vs light teal
  const _BubbleDef(this.left, this.size, this.delay, this.dur, {this.blur = false, this.bright = true});
}

const _kBubbles = <_BubbleDef>[
  _BubbleDef(0.08,  26, 0.0,  9.0,  blur: false, bright: true),
  _BubbleDef(0.20,  14, 2.4,  7.0,  blur: false, bright: false),
  _BubbleDef(0.33,  38, 1.1,  11.0, blur: true,  bright: true),
  _BubbleDef(0.46,  18, 3.6,  8.0,  blur: false, bright: false),
  _BubbleDef(0.58,  30, 0.6,  10.0, blur: true,  bright: true),
  _BubbleDef(0.70,  16, 2.0,  7.5,  blur: false, bright: false),
  _BubbleDef(0.82,  34, 1.7,  12.0, blur: true,  bright: true),
  _BubbleDef(0.92,  12, 4.2,  6.5,  blur: false, bright: false),
  _BubbleDef(0.14,  10, 5.0,  6.0,  blur: false, bright: true),
  _BubbleDef(0.64,  22, 3.0,  9.5,  blur: false, bright: false),
  _BubbleDef(0.38,  12, 4.6,  7.0,  blur: false, bright: true),
  _BubbleDef(0.76,  20, 0.3,  10.5, blur: false, bright: false),
];

// ─── Splash screen ─────────────────────────────────────────────────────────────
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {

  // Entry sequence controller (0→4000ms covers all staged fade-ins)
  late AnimationController _entryCtrl;

  // Looping controllers (start after entry settles)
  late AnimationController _breatheCtrl;
  late AnimationController _driftCtrl;
  late List<AnimationController> _dotCtrls;
  late List<AnimationController> _bubbleCtrls;

  // ── Derived animations ──────────────────────────────────────────────────────
  // pattern fade-in: 0–1000ms (0.0–0.25)
  late Animation<double> _patternOpacity;
  // logo pop: 300–1400ms (0.075–0.35)
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  // squiggle: 1200–2200ms (0.30–0.55)
  late Animation<double> _squiggleScale;
  late Animation<double> _squiggleOpacity;
  // tagline: 2500–3500ms (0.625–0.875)
  late Animation<double> _taglineOpacity;
  late Animation<double> _taglineSlide;
  // glow behind logo: synced with logo
  late Animation<double> _glowOpacity;
  // breathe: logo scale
  late Animation<double> _breathe;
  // drift: pattern vertical offset
  late Animation<double> _drift;

  @override
  void initState() {
    super.initState();

    // ── Entry ──────────────────────────────────────────────────────────────────
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4000))
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
            curve: const Interval(0.625, 0.875, curve: Curves.easeOut)));

    _taglineSlide = Tween<double>(begin: 14, end: 0).animate(
        CurvedAnimation(parent: _entryCtrl,
            curve: const Interval(0.625, 0.875, curve: Curves.easeOut)));

    // ── Breathe loop (starts after logo settles) ───────────────────────────────
    _breatheCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 6500));
    _breathe = Tween<double>(begin: 1.0, end: 1.025).animate(
        CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut));

    // ── Pattern drift loop ─────────────────────────────────────────────────────
    _driftCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 13000));
    _drift = Tween<double>(begin: 0, end: 7).animate(
        CurvedAnimation(parent: _driftCtrl, curve: Curves.easeInOut));

    // ── Dot bounce loops ───────────────────────────────────────────────────────
    _dotCtrls = List.generate(3, (_) => AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1800)));

    // ── Bubble controllers ─────────────────────────────────────────────────────
    _bubbleCtrls = _kBubbles.map((b) => AnimationController(vsync: this,
        duration: Duration(milliseconds: (b.dur * 1000).toInt()))).toList();

    _runSequence();
  }

  Future<void> _runSequence() async {
    // t=0: pattern fades in; drift starts; bubbles begin
    _driftCtrl.repeat(reverse: true);
    for (int i = 0; i < _kBubbles.length; i++) {
      Future.delayed(Duration(milliseconds: (_kBubbles[i].delay * 1000).toInt()),
          () { if (mounted) _bubbleCtrls[i].repeat(); });
    }

    // t=2800ms: start breathing
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;
    _breatheCtrl.repeat(reverse: true);

    // t=1500ms: dots bounce (relative — actually start separately)
    // Use absolute timing:
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: 1500 + i * 240),
          () { if (mounted) _dotCtrls[i].repeat(reverse: true); });
    }

    // t=4500ms: navigate
    await Future.delayed(const Duration(milliseconds: 1700)); // already at ~2800+1700=4500
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    final cityChosen = prefs.getString('city') != null;
    if (!mounted) return;
    if (onboardingDone && cityChosen) {
      context.go('/home');
    } else {
      context.go('/city');
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _breatheCtrl.dispose();
    _driftCtrl.dispose();
    for (final c in _dotCtrls) c.dispose();
    for (final c in _bubbleCtrls) c.dispose();
    super.dispose();
  }

  // ── Colors ──────────────────────────────────────────────────────────────────
  static const _teal    = AppColors.primary;         // #32DDE5
  static const _tealLight = Color(0xFF53E2E9);       // lighten(primary, 0.16)
  static const _tealDark  = Color(0xFF2FCED5);       // darken(primary, 0.07)
  static const _tealSoft  = Color(0xFFADF3F6);       // bubble tint
  static const _navy    = Color(0xFF0E3C46);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/city'),
      child: Scaffold(
        backgroundColor: _teal,
        body: Stack(children: [
          // ── Background gradient ──────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.72),
                radius: 1.48,
                colors: [_tealLight, _teal, _tealDark],
                stops: [0.0, 0.46, 1.0],
              ),
            ),
          ),

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

          // ── Rising bubbles ───────────────────────────────────────────────
          ...List.generate(_kBubbles.length, (i) {
            final b = _kBubbles[i];
            final bright = b.bright;
            return AnimatedBuilder(
              animation: _bubbleCtrls[i],
              builder: (_, __) {
                final t = _bubbleCtrls[i].value;
                final y = -150 * t - 40 * (1 - t); // bottom → top
                final opacity = t < 0.14
                    ? t / 0.14 * 0.75
                    : t < 0.82 ? 0.45 : (1 - t) / 0.18 * 0.45;
                final scale = 0.85 + 0.25 * t;
                return Positioned(
                  bottom: -40,
                  left: MediaQuery.of(context).size.width * b.left - b.size / 2,
                  child: Transform.translate(
                    offset: Offset(0, y),
                    child: Transform.scale(scale: scale,
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Container(
                          width: b.size, height: b.size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: bright ? Colors.white : _tealSoft,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),

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
                      // Glow circle
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
                      // Wordmark
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

          // ── Bouncing dots (bottom) ───────────────────────────────────────
          Positioned(
            bottom: 50, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _dotCtrls[i],
                  builder: (_, __) {
                    final t = _dotCtrls[i].value;
                    final dy  = t < 0.35 ? -14 * (t / 0.35) : -14 * (1 - (t - 0.35) / 0.65);
                    final sc  = t < 0.35 ? 1 + 0.3 * (t / 0.35) : 1 + 0.3 * (1 - (t - 0.35) / 0.65);
                    final op  = t < 0.35 ? 0.4 + 0.6 * (t / 0.35) : 0.4 + 0.6 * (1 - (t - 0.35) / 0.65);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Transform.translate(
                        offset: Offset(0, dy),
                        child: Transform.scale(scale: sc,
                          child: Opacity(
                            opacity: op.clamp(0.4, 1.0),
                            child: Container(
                              width: 12, height: 12,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle, color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ]),
      ),
    );
  }
}
