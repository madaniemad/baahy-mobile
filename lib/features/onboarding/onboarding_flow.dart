import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/l10n.dart';
import '../../core/services/push_notification_service.dart';
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
  static const _iCoupon = 3;                 // notifications slide (idx)
  int get _iLast => _slides.length - 1;      // products slide (idx)
  int get _count => _slides.length + 1;      // + city

  // Pages where the user may swipe freely (no button): delivery/payments/rewards
  // = promo idx 0,1,2 → carousel pages 1,2,3. City, coupon, products are gated.
  bool get _swipeable => _page >= 1 && _page <= 3;

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
    _pc.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  // The system permission dialog is triggered ONLY by the coupon screen's
  // "Activate Notifications" button (awaited, so the dialog shows there — not
  // later on the home screen). "Later" / finishing never requests it.
  Future<void> _activateNotifications() async {
    try { await PushNotificationService.instance.requestPermissionIfNeeded(); } catch (_) {}
    if (mounted) _next();
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
      body: PageView.builder(
        controller: _pc,
        itemCount: _count,
        physics: _swipeable ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _page = i),
        itemBuilder: (_, i) {
          if (i == 0) return OnbCityPicker(onContinue: _next);
          final idx = i - 1;
          final isCoupon = idx == _iCoupon;
          final isLast = idx == _iLast;
          final slide = _slides[idx];
          return _ImageSlide(
            image: isAr ? slide.ar : slide.en,
            isAr: isAr,
            cta: isCoupon
                ? (isAr ? 'فعّل الإشعارات' : 'Activate Notifications')
                : isLast
                    ? (isAr ? 'ابدأ التسوق' : 'Start Shopping')
                    : null, // plain promos: no button, swipe instead
            onCta: isCoupon ? _activateNotifications : _finish,
            later: isCoupon ? (isAr ? 'لاحقاً' : 'Later') : null,
            onLater: _next,
            // Dots only on the freely-swipeable promos (not coupon/products).
            showDots: !isCoupon && !isLast,
            dots: _Dots(count: _slides.length, active: idx),
          );
        },
      ),
    );
  }
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

          // bottom chrome: CTA (only coupon + last) and/or dots, over a soft fade
          Positioned(left: 0, right: 0, bottom: 0, child: Container(
            padding: EdgeInsets.fromLTRB(24, 28, 24, botPad + 16),
            decoration: const BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0x00EAF9FB), Color(0xF2EAF9FB)], stops: [0.0, 0.55])),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (cta != null) _Cta(label: cta!, onTap: onCta),
              if (later != null) ...[
                const SizedBox(height: 8),
                GestureDetector(onTap: onLater, behavior: HitTestBehavior.opaque, child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(later!, style: const TextStyle(fontFamily: Onb.font, fontSize: 14.5, fontWeight: FontWeight.w600, color: Onb.inkMuted)))),
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

class _Cta extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _Cta({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Container(
    height: 50, width: double.infinity, alignment: Alignment.center,
    decoration: BoxDecoration(gradient: Onb.ctaGradient, borderRadius: BorderRadius.circular(13)),
    child: Text(label, style: const TextStyle(fontFamily: Onb.font, fontSize: 15.5, fontWeight: FontWeight.w800, color: Colors.white)),
  ));
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
