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

  static const _images = <String>[
    'assets/onboarding/full/slide_payments.png',
    'assets/onboarding/full/slide_delivery.png',
    'assets/onboarding/full/slide_coupon.png',
    'assets/onboarding/full/slide_rewards.png',
    'assets/onboarding/full/slide_products.png',
  ];
  int get _count => _images.length + 1; // + city

  // pages where the user may swipe freely (no button on these).
  bool get _swipeable => _page == 1 || _page == 2 || _page == 4;

  @override
  void dispose() { _pc.dispose(); super.dispose(); }

  void _next() {
    if (_page >= _count - 1) { _finish(); return; }
    _pc.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  void _requestPush() { try { PushNotificationService.instance.requestPermissionIfNeeded(); } catch (_) {} }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_v2_done', true);
    _requestPush();
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
          final isCoupon = idx == 2;
          final isLast = idx == _images.length - 1;
          return _ImageSlide(
            image: _images[idx],
            isAr: isAr,
            cta: isCoupon
                ? (isAr ? 'فعّل الإشعارات' : 'Enable notifications')
                : isLast
                    ? (isAr ? 'ابدأ التسوق' : 'Start shopping')
                    : null, // plain promos: no button, swipe instead
            onCta: isCoupon ? () { _requestPush(); _next(); } : _finish,
            later: isCoupon ? (isAr ? 'لاحقاً' : 'Later') : null,
            onLater: _next,
            showDots: !isCoupon,
            dots: _Dots(count: _images.length, active: idx),
            onToggle: () => ref.read(localeProvider.notifier).toggle(),
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
  final VoidCallback onCta, onLater, onToggle;
  final Widget dots;
  const _ImageSlide({
    required this.image, required this.isAr, required this.showDots,
    required this.onCta, required this.onLater, required this.onToggle, required this.dots,
    this.cta, this.later,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;
    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(image, fit: BoxFit.cover, alignment: Alignment.topCenter),

          // language toggle (top-right, in the design's empty top padding)
          Positioned(top: topPad + 16, right: 20, child: _LangPill(isAr: isAr, onTap: onToggle)),

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
    height: 56, width: double.infinity, alignment: Alignment.center,
    decoration: BoxDecoration(gradient: Onb.ctaGradient, borderRadius: BorderRadius.circular(15), boxShadow: Onb.ctaShadow),
    child: Text(label, style: const TextStyle(fontFamily: Onb.font, fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
  ));
}

class _LangPill extends StatelessWidget {
  final bool isAr; final VoidCallback onTap;
  const _LangPill({required this.isAr, required this.onTap});
  @override
  Widget build(BuildContext context) {
    Widget opt(String s, bool on) => Text(s, style: TextStyle(fontFamily: Onb.font, fontSize: 15, fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: on ? Onb.tealDeep : const Color(0xFF9AA6A9)));
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), boxShadow: const [BoxShadow(color: Color(0x29073C46), blurRadius: 16, offset: Offset(0, 6))]),
      child: Directionality(textDirection: TextDirection.ltr, child: Row(mainAxisSize: MainAxisSize.min, children: [
        opt('English', !isAr),
        Container(width: 1, height: 16, margin: const EdgeInsets.symmetric(horizontal: 8), color: const Color(0xFFDCE2E4)),
        opt('العربية', isAr),
      ])),
    ));
  }
}

class _Dots extends StatelessWidget {
  final int count, active;
  const _Dots({required this.count, required this.active});
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
    for (int i = 0; i < count; i++) AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: i == active ? 22 : 8, height: 8,
      decoration: BoxDecoration(color: i == active ? Onb.teal : const Color(0xFFCDE9EC), borderRadius: BorderRadius.circular(4)),
    ),
  ]);
}
