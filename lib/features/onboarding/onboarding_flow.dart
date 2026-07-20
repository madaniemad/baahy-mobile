import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/l10n.dart';
import 'onb_theme.dart';
import 'onb_city_picker.dart';

/// Onboarding: mandatory city picker, then promo slides (content-only images +
/// Flutter chrome). Rules:
///  - City (page 0): no swipe — must confirm/pick to proceed.
///  - Plain promos (payments/delivery/rewards): swipe to advance, dots, no button.
///  - Coupon: no swipe — must tap "Enable notifications" or "Later".
///  - Products (last): no swipe — must tap "Start shopping" to finish.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});
  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final _pc = PageController();
  int _page = 0;
  // The last *settled* page. Physics is derived from this (not the live page)
  // so a fling never has its settle animation cut off by a mid-flight physics
  // swap — the transition stays smooth right into a gated page.
  int _settled = 0;
  // True while a button-driven page animation is running. NeverScrollableScroll-
  // Physics makes animateToPage/nextPage jump instantly instead of animating, so
  // we relax to a scrollable physics for the duration of the programmatic slide.
  bool _animating = false;

  // Exact sequence (per design numbering): 2 delivery, 3 payments, 4 rewards,
  // 5 coupon/notifications, 6 products. Each has an Arabic + English artwork —
  // the language toggle swaps the whole slide, not just the chrome.
  static const _slides = <({String ar, String en})>[
    (ar: 'assets/onboarding/full/slide_delivery.webp', en: 'assets/onboarding/full/slide_delivery_en.webp'),
    (ar: 'assets/onboarding/full/slide_payments.webp', en: 'assets/onboarding/full/slide_payments_en.webp'),
    (ar: 'assets/onboarding/full/slide_rewards.webp',  en: 'assets/onboarding/full/slide_rewards_en.webp'),
    (ar: 'assets/onboarding/full/slide_coupon.webp',   en: 'assets/onboarding/full/slide_coupon_en.webp'),
    (ar: 'assets/onboarding/full/slide_products.webp', en: 'assets/onboarding/full/slide_products_en.webp'),
  ];
  int get _iLast => _slides.length - 1;      // products slide (idx)
  int get _count => _slides.length + 1;      // + city

  // Pages where the user may swipe freely (no button): every promo between the
  // city picker and the final products slide = carousel pages 1..4. Only the city
  // (page 0) and products (last page) are gated. Keyed off the settled page so
  // physics is stable during an in-flight settle. While a programmatic slide runs
  // we also allow scrolling, otherwise the animation is swallowed.
  bool get _canScroll => _animating || (_settled >= 1 && _settled <= _iLast);

  @override
  void dispose() { _pc.dispose(); super.dispose(); }

  bool _precached = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    // Precache all promo artwork up-front so slide transitions are smooth.
    for (final s in _slides) {
      precacheImage(AssetImage(s.ar), context);
      precacheImage(AssetImage(s.en), context);
    }
  }

  void _next() {
    if (_page >= _count - 1) { _finish(); return; }
    setState(() => _animating = true);
    // Gentle ease-in-out over a slightly longer beat so the slide reads as a
    // smooth glide, not an abrupt snap.
    _pc.nextPage(duration: const Duration(milliseconds: 480), curve: Curves.easeInOutCubic)
       .whenComplete(() { if (mounted) setState(() => _animating = false); });
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_v2_done', true);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final isAr = ref.watch(localeProvider).languageCode == 'ar';
    return Scaffold(
      backgroundColor: const Color(0xFFEAF9FB),
      body: Stack(children: [
        NotificationListener<ScrollEndNotification>(
          // Update the gate only once a swipe fully settles, so the physics never
          // flips while an animation is still running.
          onNotification: (_) {
            final s = _pc.hasClients ? (_pc.page?.round() ?? _settled) : _settled;
            if (s != _settled) setState(() => _settled = s);
            return false;
          },
          child: PageView.builder(
            controller: _pc,
            itemCount: _count,
            physics: _canScroll ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) {
              if (i == 0) return OnbCityPicker(onContinue: _next);
              final idx = i - 1;
              final isLast = idx == _iLast;
              final slide = _slides[idx];
              return _parallax(i, _ImageSlide(
                image: isAr ? slide.ar : slide.en,
                isAr: isAr,
                // Only the last (products) slide has a button — every slide between
                // the city picker and products is a swipe-through promo. Notification
                // permission is no longer requested here; it moves to first sign-in.
                cta: isLast ? (isAr ? 'ابدأ التسوق' : 'Start Shopping') : null,
                onCta: _finish,
                later: null,
                onLater: _next,
                // Dots on every promo except the last (products has the button).
                showDots: !isLast,
                dots: _Dots(count: _slides.length, active: idx),
              ));
            },
          ),
        ),
        // Skip (top-left) — shown on every screen after the city picker so users
        // can jump straight into the app. Hidden on the city page (must pick a
        // city) and on the last slide (which already has "Start Shopping").
        if (_page >= 1 && _page < _count - 1)
          Positioned(
            top: MediaQuery.of(context).padding.top + 6,
            left: 12,
            child: _SkipButton(label: isAr ? 'تخطّي' : 'Skip', onTap: _finish),
          ),
      ]),
    );
  }

  // Subtle depth as slides move: the entering/leaving promo eases up from 96%
  // scale and fades in, so a swipe reads as a smooth, premium transition rather
  // than a flat slide. Only applied to promo pages — the city picker (i==0) is
  // left untransformed so it stays crisp and fully interactive.
  Widget _parallax(int i, Widget child) => AnimatedBuilder(
    animation: _pc,
    child: child,
    builder: (context, ch) {
      final page = (_pc.hasClients && _pc.position.haveDimensions)
          ? (_pc.page ?? _page.toDouble())
          : _page.toDouble();
      final a = (page - i).clamp(-1.0, 1.0).abs();
      return Opacity(
        opacity: (1 - a * 0.45).clamp(0.0, 1.0),
        child: Transform.scale(scale: 1 - a * 0.04, child: ch),
      );
    },
  );
}

/// One promo slide: content-only design image + Flutter chrome.
class _ImageSlide extends StatelessWidget {
  final String image;
  final bool isAr, showDots;
  final String? cta, later;
  final VoidCallback onCta, onLater;
  final Widget dots;
  const _ImageSlide({
    required this.image, required this.isAr, required this.showDots,
    required this.onCta, required this.onLater, required this.dots,
    this.cta, this.later,
  });

  @override
  Widget build(BuildContext context) {
    final botPad = MediaQuery.of(context).padding.bottom;
    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed artwork. No language toggle on promo slides — language is
          // chosen on the map screen.
          Image.asset(image, fit: BoxFit.cover, alignment: Alignment.topCenter),

          // Tall soft scrim so the bottom of the artwork fades cleanly into the
          // footer instead of being sliced mid-text by the button.
          Positioned(left: 0, right: 0, bottom: 0,
            height: MediaQuery.of(context).size.height * (cta != null ? 0.34 : 0.22),
            child: const IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0x00EAF9FB), Color(0xE6EAF9FB), Color(0xFFEAF9FB)], stops: [0.0, 0.6, 0.9])))),
          ),

          // bottom chrome: CTA (only coupon + last) and/or dots
          Positioned(left: 0, right: 0, bottom: 0, child: Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, botPad + 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (cta != null) _Cta(label: cta!, onTap: onCta),
              if (later != null) ...[
                const SizedBox(height: 4),
                GestureDetector(onTap: onLater, behavior: HitTestBehavior.opaque, child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text(later!, style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 14.5, fontWeight: FontWeight.w600, color: Onb.inkMuted)))),
              ] else if (showDots) ...[
                SizedBox(height: cta != null ? 16 : 4),
                dots,
              ],
            ]),
          )),
        ],
      ),
    );
  }
}

// Static CTA — no pulse (kept calm to match the still city button).
class _Cta extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _Cta({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Container(
    height: 50, width: double.infinity, alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: Onb.ctaGradient, borderRadius: BorderRadius.circular(13),
      boxShadow: [BoxShadow(color: Onb.teal.withValues(alpha: 0.38), blurRadius: 16, offset: const Offset(0, 6))]),
    child: Text(label, style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 15.5, fontWeight: FontWeight.w800, color: Colors.white)),
  ));
}

// Subtle "Skip" pill (top-left) — legible over artwork, calm styling.
class _SkipButton extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _SkipButton({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Text(label, style: const TextStyle(fontFamily: Onb.font, fontFamilyFallback: Onb.fontFallback, fontSize: 13.5, fontWeight: FontWeight.w700, color: Onb.inkMuted)),
    ),
  );
}

class _Dots extends StatelessWidget {
  final int count, active;
  const _Dots({required this.count, required this.active});
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
    for (int i = 0; i < count; i++) AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: i == active ? 18 : 7, height: 7,
      decoration: BoxDecoration(color: i == active ? Onb.teal : const Color(0xFFCDE9EC), borderRadius: BorderRadius.circular(4)),
    ),
  ]);
}
