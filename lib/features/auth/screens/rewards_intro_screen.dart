import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/address_provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/providers/app_pages_provider.dart';
import '../../../core/providers/shipping_provider.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';

const _navy      = Color(0xFF0E3C46);
const _teal      = AppColors.primary;
const _tealLight = Color(0xFF53E2E9);
const _tealDark  = Color(0xFF2FCED5);

/// Single swipeable onboarding flow — 3 mandatory pages:
/// city (language toggle lives here) → products → rewards.
/// No skip: the city page is page 0 so it can't be bypassed, and every page
/// is reachable by swipe or by tapping the dots.
class RewardsIntroScreen extends ConsumerStatefulWidget {
  const RewardsIntroScreen({super.key});
  @override
  ConsumerState<RewardsIntroScreen> createState() => _RewardsIntroScreenState();
}

class _RewardsIntroScreenState extends ConsumerState<RewardsIntroScreen>
    with TickerProviderStateMixin {
  final _pageCtrl   = PageController();
  final _searchCtrl = TextEditingController();
  final _listCtrl   = ScrollController();
  int _page      = 0;
  String _query  = '';
  String _selectedCity = 'طرابلس';
  static const _pageCount = 3;

  late AnimationController _floatCtrl;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 7000))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _searchCtrl.dispose();
    _listCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  void _goToPage(int i) => _pageCtrl.animateToPage(i,
      duration: const Duration(milliseconds: 340), curve: Curves.easeInOutCubic);

  void _next() {
    if (_page < _pageCount - 1) {
      _goToPage(_page + 1);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await ref.read(cityProvider.notifier).setCity(_selectedCity);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_v2_done', true);
    // MUST be awaited. Fire-and-forget meant we navigated to /home immediately
    // and tore this screen down while the iOS permission request was still in
    // flight — so the system Allow/Don't Allow dialog never appeared and the
    // button looked like it did nothing.
    try { await PushNotificationService.instance.requestPermissionIfNeeded(); } catch (_) {}
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final top    = MediaQuery.of(context).padding.top;
    final isLast = _page == _pageCount - 1;

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

        // Swipeable pages
        Positioned.fill(
          child: PageView(
            controller: _pageCtrl,
            onPageChanged: (i) {
              FocusScope.of(context).unfocus();
              setState(() => _page = i);
            },
            children: [
              _citySlide(top, bottom),
              _productsSlide(top, bottom),
              _rewardsSlide(top, bottom),
            ],
          ),
        ),

        // Pagination dots (tappable). 3 mandatory pages: city, products, rewards.
        Positioned(
          bottom: 88 + bottom, left: 0, right: 0,
          child: _Dots(count: _pageCount, active: _page, onTap: _goToPage),
        ),

        // Bottom action bar
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: _ActionBar(
            label: isLast ? context.s.startShopping : context.s.nextBtn,
            onTap: _next),
        ),
      ]),
    );
  }

  // ── Page 0: city selection (mandatory, sets language) ──────────────────────
  Widget _citySlide(double top, double bottom) {
    final isAr       = ref.watch(localeProvider).languageCode == 'ar';
    final ratesAsync = ref.watch(shippingRatesProvider);
    final loading    = ratesAsync.isLoading;
    final rates      = ratesAsync.valueOrNull ?? const [];
    final all        = rates.map((r) => CityEntry(ar: r.cityAr, en: r.city)).toList();
    final q          = _query.trim().toLowerCase();
    final filtered   = q.isEmpty ? all
        : all.where((c) => c.ar.contains(q) || c.en.toLowerCase().contains(q)).toList();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, top + 8, 20, 150 + bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Language toggle
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => ref.read(localeProvider.notifier).toggle(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.language_rounded, size: 16, color: _teal),
                  const SizedBox(width: 6),
                  Text(isAr ? 'English' : 'العربية',
                    style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                      fontSize: 13, fontWeight: FontWeight.w800, color: _navy)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Text(isAr ? 'اختار مدينتك' : 'Choose Your City',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 26,
              fontWeight: FontWeight.w900, color: Colors.white,
              shadows: [Shadow(color: Color(0x2E0E3C46), blurRadius: 14, offset: Offset(0, 3))])),
          const SizedBox(height: 10),
          Text(isAr
              ? 'لنتمكن من عرض المنتجات والعروض المناسبة لك'
              : 'To show you relevant products and offers',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 13,
              fontWeight: FontWeight.w700, color: _navy, height: 1.4)),
          const SizedBox(height: 22),

          // Search
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 14, offset: const Offset(0, 5))],
              ),
              child: Row(children: [
                const SizedBox(width: 14),
                const Icon(Icons.search_rounded, size: 20, color: Color(0xFF0D6B75)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    textAlign: isAr ? TextAlign.right : TextAlign.left,
                    textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                      fontSize: 13.5, fontWeight: FontWeight.w600, color: _navy),
                    cursorColor: _teal,
                    decoration: InputDecoration(
                      hintText: isAr ? 'ابحث عن مدينتك' : 'Search cities',
                      hintStyle: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                        color: Color(0xFF2A6E78), fontSize: 13.5, fontWeight: FontWeight.w500),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // City list card
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 24, offset: const Offset(0, 10))],
                ),
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(child: CircularProgressIndicator(
                          color: _teal, strokeWidth: 2.5)),
                      )
                    : filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(isAr ? 'لا توجد نتائج' : 'No results',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: _navy, fontWeight: FontWeight.w700)),
                          )
                        : Scrollbar(
                            controller: _listCtrl,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _listCtrl,
                              physics: const BouncingScrollPhysics(),
                              child: Column(children: [
                                for (int i = 0; i < filtered.length; i++) ...[
                                  _CityRow(
                                    label: isAr ? filtered[i].ar : filtered[i].en,
                                    isAr: isAr,
                                    selected: _selectedCity == filtered[i].ar,
                                    onTap: () => setState(() => _selectedCity = filtered[i].ar),
                                  ),
                                  if (i < filtered.length - 1)
                                    const Divider(height: 1, thickness: 1,
                                      indent: 16, endIndent: 16, color: Color(0xFFEDF1F2)),
                                ],
                              ]),
                            ),
                          ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Page 1: products ───────────────────────────────────────────────────────
  Widget _productsSlide(double top, double bottom) {
    return Padding(
      padding: EdgeInsets.fromLTRB(22, top + 72, 22, 150 + bottom),
      child: Column(children: [
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 36,
              fontWeight: FontWeight.w900, height: 1.12),
            children: [
              TextSpan(text: 'آلاف المنتجات',
                style: TextStyle(color: Colors.white,
                  shadows: [Shadow(color: Color(0x2E0E3C46),
                    blurRadius: 14, offset: Offset(0, 3))])),
              TextSpan(text: '\n'),
              TextSpan(text: 'بانتظارك', style: TextStyle(color: _navy)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(context.s.discoverCategories,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 16,
            fontWeight: FontWeight.w700, color: _navy, height: 1.5)),
        Expanded(
          child: AnimatedBuilder(
            animation: _floatCtrl,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, sin(_floatCtrl.value * 2 * pi) * 9), child: child),
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
    );
  }

  // ── Page 2: rewards ────────────────────────────────────────────────────────
  Widget _rewardsSlide(double top, double bottom) {
    final s = context.s;
    final config = ref.watch(appConfigProvider);
    final platCashback = config.tierPlatinumCashback.toStringAsFixed(0);
    final referralAmt  = config.referralGiverAmount.toString();

    return Padding(
      padding: EdgeInsets.fromLTRB(22, top + 64, 22, 150 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 30,
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
    );
  }
}

// ── City row ─────────────────────────────────────────────────────────────────
class _CityRow extends StatelessWidget {
  final String label;
  final bool isAr;
  final bool selected;
  final VoidCallback onTap;
  const _CityRow({required this.label, required this.isAr,
    required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _teal.withValues(alpha: 0.10) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
          child: Row(children: [
            Expanded(
              child: Text(label,
                textAlign: isAr ? TextAlign.right : TextAlign.left,
                style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 14.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? _navy : const Color(0xFF33565C))),
            ),
            const SizedBox(width: 10),
            if (selected)
              const Icon(Icons.check_circle_rounded, size: 20, color: _teal)
            else
              const SizedBox(width: 20),
          ]),
        ),
      ),
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
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 24, color: _teal),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 15,
                  fontWeight: FontWeight.w800, color: _navy)),
              const SizedBox(height: 2),
              Text(subtitle,
                style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontSize: 13,
                  fontWeight: FontWeight.w600, color: Color(0xFF2A6E78))),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Dots (tappable) ──────────────────────────────────────────────────────────
class _Dots extends StatelessWidget {
  final int count;
  final int active;
  final ValueChanged<int>? onTap;
  const _Dots({required this.count, required this.active, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (int i = 0; i < count; i++)
        GestureDetector(
          onTap: onTap == null ? null : () => onTap!(i),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            height: 8,
            width: i == active ? 26 : 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: i == active ? Colors.white : Colors.white.withValues(alpha: 0.45),
            ),
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
            Text(label, style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
              fontSize: 17, fontWeight: FontWeight.w900, color: _navy)),
          ]),
        ),
      ),
    );
  }
}
