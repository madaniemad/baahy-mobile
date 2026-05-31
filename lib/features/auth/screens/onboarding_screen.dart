import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/theme/app_theme.dart';

// Reuse _OnboardingDots and _BottomBar from city_screen — so we copy the
// minimal versions here to keep files self-contained.

const _navy  = Color(0xFF0E3C46);
const _teal  = AppColors.primary;
const _tealLight = Color(0xFF53E2E9);
const _tealDark  = Color(0xFF2FCED5);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late AnimationController _floatCtrl;
  late Animation<double> _floatY;
  late AnimationController _entryCtrl;
  late Animation<double> _fade;
  late Animation<double> _slideY;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 7000))
      ..repeat(reverse: true);
    _floatY = Tween<double>(begin: 0, end: -9).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _entryCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600))
      ..forward();
    _fade   = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideY = Tween<double>(begin: 14, end: 0).animate(
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final top    = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _teal,
      body: Stack(children: [
        // Background gradient
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

        // Content
        Positioned(
          top: top + 72, left: 22, right: 22, bottom: 160 + bottom,
          child: AnimatedBuilder(
            animation: Listenable.merge([_fade, _slideY]),
            builder: (_, child) => Opacity(
              opacity: _fade.value,
              child: Transform.translate(
                offset: Offset(0, _slideY.value), child: child)),
            child: Column(children: [
              // Heading
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 36,
                    fontWeight: FontWeight.w900, height: 1.12),
                  children: [
                    TextSpan(text: 'آلاف المنتجات',
                      style: TextStyle(color: Colors.white,
                        shadows: [Shadow(color: Color(0x2E0E3C46),
                          blurRadius: 14, offset: Offset(0, 3))])),
                    TextSpan(text: '\n'),
                    TextSpan(text: 'بانتظارك',
                      style: TextStyle(color: _navy)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('تسوّق أحدث المنتجات من مختلف الفئات',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Cairo', fontSize: 16,
                  fontWeight: FontWeight.w700, color: _navy, height: 1.5)),

              // Floating products image
              Expanded(
                child: AnimatedBuilder(
                  animation: _floatY,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, _floatY.value), child: child),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Image.asset('assets/images/onb-products.png',
                      width: MediaQuery.of(context).size.width * 1.08,
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.bottomCenter),
                  ),
                ),
              ),
            ]),
          ),
        ),

        // Pagination dots
        Positioned(
          bottom: 88 + bottom, left: 0, right: 0,
          child: _Dots(count: 3, active: 2),
        ),

        // Bottom action bar
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: _ActionBar(onTap: _start),
        ),
      ]),
    );
  }
}

// ── Reusable sub-widgets ───────────────────────────────────────────────────────

class _Dots extends StatelessWidget {
  final int count;
  final int active;
  const _Dots({required this.count, required this.active});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (int i = 0; i < count; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: i == active ? 26 : 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: i == active ? Colors.white : Colors.white.withValues(alpha: 0.45),
          ),
        ),
    ]);
  }
}

class _ActionBar extends StatelessWidget {
  final VoidCallback onTap;
  const _ActionBar({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(18, 0, 18, 26 + bottom),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [BoxShadow(
              color: Color(0x330E3C46), blurRadius: 30, offset: Offset(0, 14))],
          ),
          child: Stack(alignment: Alignment.center, children: [
            Positioned(
              right: 0,
              child: Opacity(opacity: 0.5,
                child: Icon(Icons.arrow_forward_ios_rounded,
                  size: 18, color: _teal)),
            ),
            const Text('ابدأ التسوق', style: TextStyle(fontFamily: 'Cairo',
              fontSize: 19, fontWeight: FontWeight.w900, color: _navy)),
          ]),
        ),
      ),
    );
  }
}
