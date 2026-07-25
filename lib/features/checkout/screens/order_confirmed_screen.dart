import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/providers/notifications_provider.dart';
import '../../../core/providers/tier_provider.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';

class OrderConfirmedScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  const OrderConfirmedScreen({required this.data, super.key});

  @override
  ConsumerState<OrderConfirmedScreen> createState() => _OrderConfirmedScreenState();
}

class _OrderConfirmedScreenState extends ConsumerState<OrderConfirmedScreen> {
  String _deliveryLabel(bool isAr) {
    final rate = widget.data['shipping_rate'];
    final city = (widget.data['city'] ?? widget.data['shipping_city'] ?? '').toString();
    final zoneType = rate is Map ? rate['zone_type']?.toString() : null;
    final isHubCity = zoneType == 'hub_city' ||
        city.toLowerCase().contains('طرابلس') ||
        city.toLowerCase().contains('tripoli');
    // Hub city: promise same/next-day honoring the 4pm cutoff + Friday skip,
    // consistent with the cart strip and product-detail delivery card.
    if (isHubCity) {
      final now = DateTime.now();
      final beforeCutoff = now.hour < 16 && now.weekday != DateTime.friday;
      return isAr
          ? (beforeCutoff ? 'اليوم' : 'غداً')
          : (beforeCutoff ? 'Today' : 'By tomorrow');
    }
    // Other cities: their shipping-rate day range.
    if (rate is Map && rate['estimated_days'] != null) {
      return isAr ? '${rate['estimated_days']} يوم' : '${rate['estimated_days']} days';
    }
    return isAr ? '2 - 5 يوم' : '2 - 5 days';
  }

  @override
  void initState() {
    super.initState();
    // Pull the freshly-created "order received" notification so the bell badge
    // reflects it without an app restart. The backend creates it in an
    // afterResponse handler (~1-3s after the order response), so a single
    // immediate fetch would race it — retry a couple of times to catch it.
    for (final ms in const [0, 3000, 7000]) {
      Future.delayed(Duration(milliseconds: ms), () {
        if (!mounted) return;
        ref.read(notificationsProvider.notifier).fetch();
      });
    }
    // Ask for notification permission at the one moment it's clearly relevant —
    // the user just placed an order and the screen promises order updates. This
    // is the only place existing users (who onboarded long ago and were never
    // prompted) get asked, so their device registers a push token.
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      try { PushNotificationService.instance.requestPermissionIfNeeded(); } catch (_) {}
    });
    // Haptic success burst so the user feels the payment went through even
    // without looking. Wait for the route transition to finish (~350ms) so the
    // buzz fires exactly when the screen settles — the "payment done" feel.
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      Haptics.success();
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final orderNumber = data['order_number'] ?? '#${data['id']}';
    final orderId = data['id'];
    final rawTotal = data['total'];
    final total = rawTotal is num
        ? rawTotal.toDouble()
        : double.tryParse(rawTotal?.toString() ?? '');
    final config = ref.watch(appConfigProvider);
    final tierAsync = ref.watch(tierProvider);
    final tier = tierAsync.valueOrNull;
    final rawSubtotal = data['subtotal'];
    final subtotal =
        rawSubtotal is num ? rawSubtotal.toDouble() : (total ?? 0.0);
    // Use the shopper's own tier rate (Silver 1.5 → Black 5), not the base rate.
    final cbRate = (tier?.cashbackRate ?? 0) > 0 ? tier!.cashbackRate : config.cashbackRate;
    final cashbackAmount = subtotal >= config.cashbackMinOrder && cbRate > 0
        ? subtotal * cbRate / 100
        : null;
    final loyaltyRemaining = tier?.nextMilestoneRemaining;
    final loyaltyReward = tier?.nextMilestoneReward;
    final isAr = context.isAr;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deliveryLabel = _deliveryLabel(isAr);

    return Scaffold(
      backgroundColor: context.col.bg,
      body: SafeArea(
        child: Column(children: [
          // ── scrollable body ──────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(children: [
                // drag handle
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: context.col.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),

                // ── hero bag + confetti ──────────────────────────────────
                SizedBox(
                  height: 155,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // confetti decorations
                      _Sparkle(top: 8, right: 30, size: 12),
                      _Dash(top: 18, right: 75, angle: 0.4),
                      _Sparkle(top: 5, left: 55, size: 9),
                      _Dash(top: 38, left: 22, angle: -0.5),
                      _Dot(top: 50, left: 42, size: 7),
                      _GoldDot(top: 75, left: 14),
                      _Dash(bottom: 35, left: 44, angle: 0.3),
                      _Dot(bottom: 25, left: 72, size: 5, color: AppColors.primary.withValues(alpha: 0.5)),
                      _Sparkle(bottom: 15, right: 36, size: 10),
                      _Dash(bottom: 32, right: 20, angle: -0.3),
                      _Dot(top: 28, right: 50, size: 5, color: AppColors.primary.withValues(alpha: 0.4)),
                      _Sparkle(bottom: 55, left: 26, size: 8),
                      _Dot(top: 12, right: 100, size: 9),
                      _Dash(top: 8, left: 90, angle: 0.6),

                      // bag image
                      Image.asset(
                        'assets/images/order_success_bag.png',
                        width: 130,
                        height: 130,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),

                // ── title ────────────────────────────────────────────────
                Text(
                  isAr ? 'تم تسجيل الطلب' : 'Order Placed!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: context.col.ink0,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAr
                      ? 'تم حفظ طلبك بنجاح في حسابك'
                      : 'Your order has been saved successfully',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                    fontSize: 13,
                    color: context.col.ink2,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),

                // ── order number pill ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        orderNumber.toString(),
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isAr ? 'رقم الطلب' : 'Order #',
                        style: TextStyle(
                          fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: context.col.ink1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // thin divider
                Container(height: 1, color: context.col.border),
                const SizedBox(height: 10),

                // ── delivery card ─────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.col.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.col.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // text on right (first in RTL)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAr ? 'موعد التوصيل المتوقع' : 'Expected Delivery',
                              style: TextStyle(
                                fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: context.col.ink0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              deliveryLabel,
                              style: const TextStyle(
                                fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isAr
                                  ? 'سنوافيك بتحديثات الطلب'
                                  : "We'll keep you updated",
                              style: TextStyle(
                                fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                                fontSize: 12,
                                color: context.col.ink3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // calendar icon on left
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.calendar_today_rounded,
                            color: AppColors.primary, size: 22),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // ── rewards two-column card ───────────────────────────────
                if (loyaltyRemaining != null || cashbackAmount != null)
                  Container(
                    decoration: BoxDecoration(
                      color: context.col.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.col.border),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          // loyalty column (RIGHT in RTL = first)
                          if (loyaltyRemaining != null && loyaltyReward != null)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 40, height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.star_outline_rounded,
                                          color: AppColors.primary, size: 20),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isAr ? 'نقاط الولاء' : 'Loyalty',
                                      style: TextStyle(
                                        fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: context.col.ink0,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      isAr
                                          ? 'أكمل $loyaltyRemaining طلب'
                                          : 'Complete $loyaltyRemaining order',
                                      style: TextStyle(
                                        fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                                        fontSize: 12,
                                        color: context.col.ink2,
                                      ),
                                    ),
                                    Text(
                                      isAr
                                          ? 'واحصل على ${loyaltyReward.toStringAsFixed(0)} ${context.s.lydUnit} بعد الاستلام'
                                          : 'and get ${loyaltyReward.toStringAsFixed(0)} ${context.s.lydUnit} after receipt',
                                      style: const TextStyle(
                                        fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // vertical divider
                          if ((loyaltyRemaining != null && loyaltyReward != null) &&
                              cashbackAmount != null)
                            Container(
                              width: 1,
                              color: context.col.border,
                            ),

                          // cashback column (LEFT in RTL = last)
                          if (cashbackAmount != null)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 40, height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.savings_outlined,
                                          color: AppColors.primary, size: 20),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isAr ? 'كاش باك' : 'Cashback',
                                      style: TextStyle(
                                        fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: context.col.ink0,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      isAr ? 'ستحصل على' : "You'll receive",
                                      style: TextStyle(
                                        fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                                        fontSize: 12,
                                        color: context.col.ink2,
                                      ),
                                    ),
                                    Text(
                                      isAr
                                          ? '${fmtPrice(cashbackAmount)} ${context.s.lydUnit} عند التوصيل'
                                          : '${fmtPrice(cashbackAmount)} ${context.s.lydUnit} on delivery',
                                      style: const TextStyle(
                                        fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 8),

                // ── notification banner ───────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      // text on right (first in RTL)
                      Expanded(
                        child: Text(
                          isAr
                              ? 'سنخبرك عند تأكيد طلبك وتجهيزه للتوصيل'
                              : "We'll notify you when your order is confirmed and prepared for delivery",
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: context.col.ink1,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // bell icon on left
                      Container(
                        width: 44, height: 44,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),

          // ── bottom buttons ────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 8, 20, MediaQuery.of(context).padding.bottom + 16),
            child: Row(children: [
              // track order — RIGHT (first in RTL) = dark fill
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (orderId != null) {
                      context.go('/orders/$orderId');
                    } else {
                      context.go('/orders');
                    }
                  },
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      // The near-black fill blends into the dark scaffold, hiding the
                      // primary CTA. In dark mode use the brand tiffany with dark text
                      // so "Track Order" stands out; light mode keeps the dark fill.
                      color: isDark ? AppColors.primary : const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isAr ? 'تتبع الطلب' : 'Track Order',
                          style: TextStyle(
                            fontFamily: 'Manrope', fontFamilyFallback: const ['Tajawal'],
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF004D54) : Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.location_on_outlined,
                            color: isDark ? const Color(0xFF004D54) : Colors.white,
                            size: 18),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // continue shopping — LEFT (last in RTL) = outlined
              Expanded(
                child: GestureDetector(
                  onTap: () => context.go('/home'),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: context.col.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: context.col.border, width: 1.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isAr ? 'الصفحة الرئيسية' : 'Home',
                          style: TextStyle(
                            fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.col.ink0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.home_outlined,
                            color: context.col.ink0, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── confetti decorations ──────────────────────────────────────────────────────

class _Sparkle extends StatelessWidget {
  final double? top, bottom, left, right;
  final double size;
  const _Sparkle({this.top, this.bottom, this.left, this.right, this.size = 12});

  @override
  Widget build(BuildContext context) => Positioned(
    top: top, bottom: bottom, left: left, right: right,
    child: Icon(Icons.star_rate_rounded,
        size: size, color: AppColors.primary.withValues(alpha: 0.7)),
  );
}

class _Dash extends StatelessWidget {
  final double? top, bottom, left, right;
  final double angle;
  const _Dash({this.top, this.bottom, this.left, this.right, this.angle = 0});

  @override
  Widget build(BuildContext context) => Positioned(
    top: top, bottom: bottom, left: left, right: right,
    child: Transform.rotate(
      angle: angle,
      child: Container(
        width: 18, height: 4,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );
}

class _Dot extends StatelessWidget {
  final double? top, bottom, left, right;
  final double size;
  final Color? color;
  const _Dot({this.top, this.bottom, this.left, this.right,
      this.size = 8, this.color});

  @override
  Widget build(BuildContext context) => Positioned(
    top: top, bottom: bottom, left: left, right: right,
    child: Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: color ?? AppColors.primary.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
    ),
  );
}

class _GoldDot extends StatelessWidget {
  final double? top, bottom, left, right;
  const _GoldDot({this.top, this.bottom, this.left, this.right});

  @override
  Widget build(BuildContext context) => Positioned(
    top: top, bottom: bottom, left: left, right: right,
    child: Container(
      width: 20, height: 20,
      decoration: const BoxDecoration(
        color: Color(0xFFFBBF24),
        shape: BoxShape.circle,
      ),
    ),
  );
}
