import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';

const _navy      = Color(0xFF0E3C46);
const _teal      = AppColors.primary;
const _tealLight = Color(0xFF53E2E9);
const _tealDark  = Color(0xFF2FCED5);

class RewardsIntroScreen extends ConsumerStatefulWidget {
  const RewardsIntroScreen({super.key});
  @override
  ConsumerState<RewardsIntroScreen> createState() => _RewardsIntroScreenState();
}

class _RewardsIntroScreenState extends ConsumerState<RewardsIntroScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late Animation<double> _fade;
  late Animation<double> _slideY;
  late AnimationController _floatCtrl;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600))
      ..forward();
    _fade   = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideY = Tween<double>(begin: 14, end: 0).animate(
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _floatCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 7000))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  void _next() => context.go('/onboarding');
  void _skip() => context.go('/home');

  @override
  Widget build(BuildContext context) {
    final bottom  = MediaQuery.of(context).padding.bottom;
    final top     = MediaQuery.of(context).padding.top;
    final s       = context.s;
    final config  = ref.watch(appConfigProvider);
    final platCashback = config.tierPlatinumCashback.toStringAsFixed(0);
    final referralAmt  = config.referralGiverAmount.toString();

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

        // Pattern texture
        Positioned(
          top: 0, left: 0, right: 0,
          child: Opacity(
            opacity: 0.06,
            child: Image.asset('assets/images/onb-pattern.png',
              width: double.infinity, fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter),
          ),
        ),

        // Floating background icons
        AnimatedBuilder(
          animation: _floatCtrl,
          builder: (_, __) {
            final t = _floatCtrl.value * 2 * pi;
            return Stack(children: [
              Positioned(top: top + 60, left: 12,
                child: Opacity(opacity: 0.10, child: Transform.translate(
                  offset: Offset(0, sin(t) * 10),
                  child: const Icon(Icons.shopping_bag_rounded, size: 72, color: Colors.white)))),
              Positioned(top: top + 110, right: 8,
                child: Opacity(opacity: 0.09, child: Transform.translate(
                  offset: Offset(0, sin(t + pi * 0.4) * 8),
                  child: const Icon(Icons.local_offer_rounded, size: 56, color: Colors.white)))),
              Positioned(top: top + 240, left: 24,
                child: Opacity(opacity: 0.08, child: Transform.translate(
                  offset: Offset(0, sin(t + pi * 0.8) * 12),
                  child: const Icon(Icons.star_rounded, size: 44, color: Colors.white)))),
              Positioned(top: top + 310, right: 20,
                child: Opacity(opacity: 0.09, child: Transform.translate(
                  offset: Offset(0, sin(t + pi * 1.2) * 9),
                  child: const Icon(Icons.account_balance_wallet_rounded, size: 60, color: Colors.white)))),
              Positioned(top: top + 175, left: 0, right: 0,
                child: Align(alignment: Alignment.topCenter,
                  child: Opacity(opacity: 0.07, child: Transform.translate(
                    offset: Offset(0, sin(t + pi * 1.6) * 11),
                    child: const Icon(Icons.workspace_premium_rounded, size: 48, color: Colors.white))))),
            ]);
          },
        ),

        // Content
        Positioned(
          top: top + 64, left: 22, right: 22, bottom: 160 + bottom,
          child: AnimatedBuilder(
            animation: Listenable.merge([_fade, _slideY]),
            builder: (_, child) => Opacity(
              opacity: _fade.value,
              child: Transform.translate(
                offset: Offset(0, _slideY.value), child: child)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Headline
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 36,
                      fontWeight: FontWeight.w900, height: 1.12),
                    children: [
                      TextSpan(text: s.onbRewardsHeadline1,
                        style: const TextStyle(color: Colors.white,
                          shadows: [Shadow(color: Color(0x2E0E3C46),
                            blurRadius: 14, offset: Offset(0, 3))])),
                      const TextSpan(text: '\n'),
                      TextSpan(text: s.onbRewardsHeadline2,
                        style: const TextStyle(color: _navy)),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Benefit cards
                _BenefitCard(
                  icon: Icons.account_balance_wallet_rounded,
                  title: s.onbCashbackTitle,
                  subtitle: s.onbCashbackSub(platCashback),
                ),
                const SizedBox(height: 12),
                _BenefitCard(
                  icon: Icons.star_rounded,
                  title: s.onbTiersTitle,
                  subtitle: s.onbTiersSub,
                ),
                const SizedBox(height: 12),
                _BenefitCard(
                  icon: Icons.group_rounded,
                  title: s.onbReferralTitle,
                  subtitle: s.onbReferralSub(referralAmt),
                ),
              ],
            ),
          ),
        ),

        // Skip
        Positioned(
          top: top + 14, left: 16,
          child: GestureDetector(
            onTap: _skip,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(context.s.skipBtn,
                style: const TextStyle(fontFamily: 'Cairo',
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: Colors.white)),
            ),
          ),
        ),

        // Pagination dots (slide 1 of 3 → active=1)
        Positioned(
          bottom: 88 + bottom, left: 0, right: 0,
          child: _Dots(count: 3, active: 1),
        ),

        // Bottom action bar
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: _ActionBar(label: context.s.nextBtn, onTap: _next),
        ),
      ]),
    );
  }
}

// ── Benefit card ───────────────────────────────────────────────────────────────
class _BenefitCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _BenefitCard({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F9FB),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 24, color: _teal),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 15,
                  fontWeight: FontWeight.w800, color: _navy)),
              const SizedBox(height: 2),
              Text(subtitle,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13,
                  fontWeight: FontWeight.w600, color: Color(0xFF2A6E78))),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Dots ───────────────────────────────────────────────────────────────────────
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

// ── Action bar ─────────────────────────────────────────────────────────────────
class _ActionBar extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ActionBar({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(18, 0, 18, 26 + bottom),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
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
                child: Icon(Icons.arrow_forward_ios, size: 18, color: _teal)),
            ),
            Text(label, style: const TextStyle(fontFamily: 'Cairo',
              fontSize: 17, fontWeight: FontWeight.w900, color: _navy)),
          ]),
        ),
      ),
    );
  }
}
