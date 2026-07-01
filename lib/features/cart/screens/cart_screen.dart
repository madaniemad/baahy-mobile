import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/wishlist_provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/models/cart.dart';
import '../../../core/models/product.dart';
import 'package:dio/dio.dart' show Response;
import '../../../core/api/api_client.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/utils/navigation.dart';
import '../../../core/providers/welcome_coupon_provider.dart';
import '../../../core/providers/shipping_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

// ── Recommended products provider ────────────────────────────────────────────

final _cartRecommendedProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  // Watch only the sorted category-ID list — rebuilds only when the set of categories changes,
  // not on qty/coupon/price mutations.
  final catIdsKey = ref.watch(cartProvider.select((c) {
    final ids = c.items
        .map((i) => i.product.category?.parentId ?? i.product.category?.id)
        .whereType<int>()
        .toSet()
        .toList()..sort();
    return ids.join(',');
  }));
  final catIds = catIdsKey.isEmpty
      ? <int>[]
      : catIdsKey.split(',').map(int.parse).toList();
  try {
    final cartItems = ref.read(cartProvider).items;
    final excludeIds = cartItems.map((i) => i.product.id).toSet();

    if (catIds.isNotEmpty) {
      final seen = <int>{...excludeIds};
      final perCat = (20 / catIds.length).ceil().clamp(6, 20);
      final futures = catIds.map((catId) => ApiClient.instance.dio
          .get('/products', queryParameters: {
            'category_id': catId, 'sort': 'popular', 'per_page': perCat + 4,
          })
          .then<dynamic>((r) => r)
          .catchError((_) => null));
      final responses = await Future.wait(futures);
      final results = <Product>[];
      for (final res in responses) {
        if (res == null) continue;
        final raw = res.data['data']?['data'] as List? ?? [];
        int count = 0;
        for (final p in raw) {
          final product = Product.fromJson(p as Map<String, dynamic>);
          if (!seen.contains(product.id)) {
            seen.add(product.id);
            results.add(product);
            count++;
            if (count >= perCat) break;
          }
        }
      }
      if (results.isNotEmpty) { results.shuffle(); return results.take(20).toList(); }
    }

    final fallback = await ApiClient.instance.dio.get('/products/recommended',
        queryParameters: {'limit': 20});
    final list = (fallback.data['data'] as List?) ?? [];
    return list.map((p) => Product.fromJson(p as Map<String, dynamic>)).toList();
  } catch (e, st) {
    Sentry.captureException(e, stackTrace: st);
    return [];
  }
});

// ── Helpers ───────────────────────────────────────────────────────────────────

List<Widget> _buildGroupedItems(BuildContext context, List<CartItem> items) {
  final isAr = context.isAr;
  final Map<String, List<CartItem>> groups = {};
  for (final item in items) {
    final vendorName = item.product.vendor != null
        ? (isAr && item.product.vendor!.storeNameAr.isNotEmpty
            ? item.product.vendor!.storeNameAr
            : item.product.vendor!.storeName)
        : (isAr ? 'بائع آخر' : 'Other Seller');
    groups.putIfAbsent(vendorName, () => []).add(item);
  }
  final multiVendor = groups.length > 1;
  final result = <Widget>[];
  for (final entry in groups.entries) {
    if (multiVendor) {
      result.add(Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 2),
        child: Row(children: [
          Icon(Icons.store_outlined, size: 14, color: context.col.ink2),
          const SizedBox(width: 6),
          Text(entry.key,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.col.ink1)),
        ]),
      ));
    }
    for (final item in entry.value) {
      result.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _CartItemCard(item: item),
      ));
    }
  }
  return result;
}

// ── Main screen ───────────────────────────────────────────────────────────────

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: context.col.bg,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: context.col.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        // Only show back arrow when cart was pushed (not opened from bottom nav)
        leading: GoRouterState.of(context).matchedLocation != '/cart' && context.canPop()
            ? IconButton(
                onPressed: () => context.pop(),
                icon: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: context.col.ink0))
            : null,
        title: Text(
          context.tr('السلة (${cart.count})', 'Cart (${cart.count})'),
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          if (cart.items.isNotEmpty)
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dlgCtx) => AlertDialog(
                    title: Text(context.s.clearCart,
                      style: const TextStyle(fontFamily: 'Cairo')),
                    content: Text(context.s.clearCartMsg),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dlgCtx, false),
                        child: Text(context.s.cancel)),
                      TextButton(onPressed: () => Navigator.pop(dlgCtx, true),
                        child: Text(context.tr('مسح', 'Clear'),
                          style: const TextStyle(color: AppColors.danger))),
                    ],
                  ),
                );
                if (ok == true) ref.read(cartProvider.notifier).clear();
              },
              child: Text(context.s.clearAll,
                maxLines: 1,
                style: const TextStyle(
                  color: AppColors.danger, fontFamily: 'Cairo',
                  fontWeight: FontWeight.w600, fontSize: 13)),
            ),
        ],
      ),
      body: cart.items.isEmpty
          ? _EmptyCart()
          : _CartBody(cart: cart),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyCart extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.shopping_bag_outlined, size: 72, color: context.col.ink4),
      const SizedBox(height: 12),
      Text(context.s.emptyCart,
        style: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: context.col.ink2)),
      const SizedBox(height: 20),
      GestureDetector(
        onTap: () => context.go('/home'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(context.s.shopNow,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
              color: Colors.white, fontFamily: 'Cairo')),
        ),
      ),
    ]),
  );
}

// ── Cart body ─────────────────────────────────────────────────────────────────

class _CartBody extends ConsumerStatefulWidget {
  final CartState cart;
  const _CartBody({required this.cart});
  @override
  ConsumerState<_CartBody> createState() => _CartBodyState();
}

class _CartBodyState extends ConsumerState<_CartBody> {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (ref.read(cartProvider).couponCode != null) return;
      try {
        final coupon = await ref.read(welcomeCouponProvider.future);
        if (!mounted || coupon == null) return;
        await ref.read(cartProvider.notifier).applyCoupon(coupon.code);
      } catch (e, st) {
        Sentry.captureException(e, stackTrace: st);
      }
    });
  }

  Future<void> _handleCheckout() async {
    if (!ref.read(authProvider).isLoggedIn) {
      safePush(context, '/signin');
      return;
    }
    // Wait for vendor fee refresh to complete before showing checkout total
    if (ref.read(cartProvider).feesRefreshing) {
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 200));
        return ref.read(cartProvider).feesRefreshing;
      });
    }
    // Block variable items without a variation before hitting the server
    final cartItems = ref.read(cartProvider).items;
    final unresolved = cartItems
        .where((i) => i.variationId == null && i.product.productType == 'variable')
        .toList();
    if (unresolved.isNotEmpty) {
      if (mounted) {
        final names = unresolved.map((i) => i.product.nameAr).join('، ');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.isAr ? 'اختر المقاس/اللون لـ: $names' : 'Choose size/colour for: $names'),
          backgroundColor: AppColors.danger,
        ));
      }
      return;
    }

    setState(() => _checking = true);
    final issues = await ref.read(cartProvider.notifier).validateAndGetIssues();
    if (!mounted) return;
    setState(() => _checking = false);

    if (issues.isNotEmpty) {
      final isAr = context.isAr;
      final unavailable = issues.where((i) => i.type == 'unavailable').toList();
      final priceChanged = issues.where((i) => i.type == 'price_changed').toList();

      final ok = await showDialog<bool>(
        context: context,
        builder: (dlgCtx) => AlertDialog(
          title: Text(context.s.cartUpdateTitle,
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (unavailable.isNotEmpty) ...[
                Text(context.s.itemsUnavailable,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 13,
                    fontWeight: FontWeight.w600, color: AppColors.danger)),
                const SizedBox(height: 8),
                ...unavailable.map((u) {
                  final attrs = u.item.variation?.attributes ?? [];
                  final varLabel = attrs.isNotEmpty
                      ? attrs.map((a) => isAr ? a.valueAr : a.value).join(' · ')
                      : null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.remove_circle_outline_rounded, size: 14, color: AppColors.danger),
                      const SizedBox(width: 6),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isAr ? u.item.product.nameAr : u.item.product.name,
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                          if (varLabel != null)
                            Text(varLabel,
                              style: const TextStyle(
                                fontFamily: 'Cairo', fontSize: 11.5,
                                color: AppColors.danger, fontWeight: FontWeight.w500)),
                        ],
                      )),
                    ]),
                  );
                }),
              ],
              if (priceChanged.isNotEmpty) ...[
                if (unavailable.isNotEmpty) const SizedBox(height: 12),
                Text(context.s.priceChangedItems,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 13,
                    fontWeight: FontWeight.w600, color: AppColors.warn)),
                const SizedBox(height: 8),
                ...priceChanged.map((u) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.price_change_outlined, size: 14, color: AppColors.warn),
                    const SizedBox(width: 6),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isAr ? u.item.product.nameAr : u.item.product.name,
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                        if (u.oldPrice != null && u.newPrice != null)
                          Directionality(textDirection: TextDirection.ltr,
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('${fmtPrice(u.oldPrice!)} ${context.s.lydUnit}',
                                style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11.5,
                                  color: context.col.ink3, fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: context.col.ink3)),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(Icons.arrow_forward_rounded, size: 12, color: AppColors.warn)),
                              Text('${fmtPrice(u.newPrice!)} ${context.s.lydUnit}',
                                style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11.5,
                                  color: AppColors.warn, fontWeight: FontWeight.w700)),
                            ])),
                      ],
                    )),
                  ]),
                )),
              ],
              const SizedBox(height: 12),
              Text(
                unavailable.isNotEmpty
                    ? context.s.willRemoveUnavailable
                    : context.s.continueUpdatedPrices,
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: context.col.ink2)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx, false),
              child: Text(context.s.cancel,
                style: TextStyle(fontFamily: 'Cairo', color: context.col.ink2))),
            ElevatedButton(
              onPressed: () => Navigator.pop(dlgCtx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(
                unavailable.isNotEmpty ? context.s.removeAndContinue : context.s.continueBtn,
                style: const TextStyle(fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700, color: Colors.white))),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      for (final u in unavailable) {
        ref.read(cartProvider.notifier).remove(u.item.key);
      }
      if (ref.read(cartProvider).items.isEmpty) return;
    }
    if (mounted) safePush(context, '/checkout');
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart;
    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
          children: [
            // ── Free shipping banner ──────────────────────────────────────
            if (cart.freeShippingThreshold != null && cart.freeShippingRemaining > 0)
              _FreeShippingProgressBanner(
                remaining: cart.freeShippingRemaining,
                subtotal: cart.subtotal,
                threshold: cart.freeShippingThreshold!),
            if (cart.freeShippingThreshold != null && cart.subtotal >= cart.freeShippingThreshold!)
              _FreeShippingAchievedBanner(saved: cart.deliveryFee),

            // ── Delivery header ───────────────────────────────────────────
            Builder(builder: (_) {
              final rate = ref.watch(cityShippingRateProvider);
              final etaMin = rate?.etaMin ?? rate?.deliveryDays ?? 1;
              final etaMax = rate?.etaMax ?? (etaMin + 1);
              final codOk = rate?.codAllowed ?? false;
              final etaStr = context.s.isAr
                  ? 'توصيل خلال $etaMin-$etaMax يوم  •  شحنة واحدة${codOk ? '  •  الدفع عند الاستلام متاح' : ''}'
                  : 'Delivery in $etaMin-$etaMax days  •  One shipment${codOk ? '  •  COD available' : ''}';
              return Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.local_shipping_rounded,
                      size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(etaStr,
                      style: TextStyle(fontSize: 11, color: context.col.ink2,
                        fontFamily: 'Cairo', height: 1.4)),
                  ),
                ]),
              );
            }),

            // ── Price drop banner ─────────────────────────────────────────
            Builder(builder: (ctx) {
              final saleItems = cart.items.where((i) =>
                  i.product.salePrice != null && i.product.salePrice! < i.product.price);
              final saleCount = saleItems.length;
              if (saleCount == 0) return const SizedBox.shrink();
              final totalSavings = saleItems.fold<double>(0, (sum, i) =>
                  sum + (i.product.price - i.product.salePrice!) * i.quantity);
              final savedStr = '${fmtPrice(totalSavings)} ${context.s.lydUnit}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1EB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warn.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.local_fire_department_rounded, color: AppColors.warn, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.4),
                          children: [
                            TextSpan(
                              text: context.s.isAr
                                  ? '$saleCount منتجات انخفضت سعرها  '
                                  : '$saleCount items on sale  ',
                              style: TextStyle(color: context.col.ink1, fontWeight: FontWeight.w600),
                            ),
                            TextSpan(
                              text: context.s.isAr ? '•  وفر حتى $savedStr' : '•  Save up to $savedStr',
                              style: const TextStyle(color: AppColors.warn, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
              );
            }),

            // ── Cart items ────────────────────────────────────────────────
            ..._buildGroupedItems(context, cart.items),

            const SizedBox(height: 16),

            // ── Coupon section ────────────────────────────────────────────
            _CouponSection(cart: cart),

            const SizedBox(height: 16),

            // ── Loyalty points banner ─────────────────────────────────────
            _LoyaltyPointsBanner(subtotal: cart.subtotal),

            const SizedBox(height: 16),

            // ── "قد يعجبك أيضاً" ─────────────────────────────────────────
            _MayAlsoLikeSection(),

            const SizedBox(height: 16),

            // ── Trust badges ──────────────────────────────────────────────
            _TrustBadges(),

            const SizedBox(height: 20),

            // ── First-order coupon banner ─────────────────────────────────
            _FirstOrderCouponBanner(),

            // ── Order summary ─────────────────────────────────────────────
            _OrderSummary(cart: cart),

            const SizedBox(height: 16),
          ],
        ),
      ),

      // ── Sticky checkout button ────────────────────────────────────────────
      Container(
        padding: EdgeInsets.fromLTRB(14, 12, 14,
            MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(
          color: context.col.surface,
          border: Border(top: BorderSide(color: context.col.border)),
        ),
        child: GestureDetector(
          onTap: _checking ? null : _handleCheckout,
          child: Container(
            height: 52,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_checking)
                  const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE8FFFE)))
                else
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(context.tr('متابعة', 'Continue'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                        color: Color(0xFFE8FFFE), fontFamily: 'Cairo')),
                  ]),
                if (!_checking)
                  Positioned(
                    left: 16,
                    child: Text('${fmtPrice(cart.total)} ${context.s.lydUnit}',
                      style: const TextStyle(fontFamily: 'PlusJakartaSans',
                        fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFE8FFFE))),
                  ),
              ],
            ),
          ),
        ),
      ),
    ]);
  }
}

// ── Free shipping progress banner ─────────────────────────────────────────────

class _FreeShippingProgressBanner extends StatelessWidget {
  final double remaining;
  final double subtotal;
  final double threshold;
  const _FreeShippingProgressBanner({
    required this.remaining, required this.subtotal, required this.threshold});

  @override
  Widget build(BuildContext context) {
    final progress = (subtotal / threshold).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: context.col.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.col.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.local_shipping_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text.rich(TextSpan(
            style: const TextStyle(fontSize: 12.5),
            children: [
              TextSpan(
                text: '${fmtPrice(remaining)} ${context.s.lydUnit}',
                style: TextStyle(fontWeight: FontWeight.w800, color: context.col.ink0,
                  fontFamily: 'PlusJakartaSans')),
              TextSpan(text: ' ${context.tr('حتى الشحن المجاني', 'for free shipping')}',
                style: TextStyle(color: context.col.ink1)),
            ],
          ))),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress, minHeight: 4,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            color: AppColors.primary,
          ),
        ),
      ]),
    );
  }
}

// ── Free shipping achieved banner ─────────────────────────────────────────────

class _FreeShippingAchievedBanner extends StatelessWidget {
  final double saved;
  const _FreeShippingAchievedBanner({required this.saved});

  static const _green = Color(0xFF2E8B57);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: _green.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _green.withValues(alpha: 0.25)),
    ),
    child: Row(children: [
      // Checkmark (first = RIGHT in RTL)
      Container(
        width: 26, height: 26,
        decoration: BoxDecoration(color: _green, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
      ),
      const SizedBox(width: 12),
      // Text (middle)
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('مبروك! حصلت على شحن مجاني', 'Congrats! You got free shipping'),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
              color: _green, fontFamily: 'Cairo')),
          if (saved > 0) ...[
            const SizedBox(height: 1),
            Text(
              context.tr('وفرت ${fmtPrice(saved)} ${context.s.lydUnit} من رسوم الشحن',
                'You saved ${fmtPrice(saved)} ${context.s.lydUnit} in shipping'),
              style: TextStyle(fontSize: 11, color: _green.withValues(alpha: 0.75),
                fontFamily: 'Cairo')),
          ],
        ]),
      ),
      const SizedBox(width: 12),
      // Truck (last = LEFT in RTL)
      Icon(Icons.local_shipping_outlined, size: 20, color: _green),
    ]),
  );
}

// ── Coupon section ────────────────────────────────────────────────────────────

class _CouponSection extends ConsumerStatefulWidget {
  final CartState cart;
  const _CouponSection({required this.cart});
  @override
  ConsumerState<_CouponSection> createState() => _CouponSectionState();
}

class _CouponSectionState extends ConsumerState<_CouponSection> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  bool _expanded = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    setState(() { _loading = true; _error = null; });
    final err = await ref.read(cartProvider.notifier).applyCoupon(_ctrl.text);
    if (mounted) setState(() { _loading = false; _error = err; });
  }

  @override
  Widget build(BuildContext context) {
    final hasCoupon = widget.cart.couponCode != null;

    return Container(
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E4E4)),
      ),
      child: Column(children: [
        // Header row — always visible
        GestureDetector(
          onTap: hasCoupon ? null : () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(children: [
              // Title + subtitle (RIGHT in RTL = first child)
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.local_offer_outlined, size: 16, color: context.col.ink1),
                    const SizedBox(width: 6),
                    Text(context.tr('لديك كوبون خصم؟', 'Have a coupon?'),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: context.col.ink0, fontFamily: 'Cairo')),
                  ]),
                  if (!hasCoupon)
                    Text(context.tr('أدخل كود الخصم للحصول على خصم إضافي',
                      'Enter coupon code for extra discount'),
                      style: TextStyle(fontSize: 11, color: context.col.ink3,
                        fontFamily: 'Cairo')),
                ]),
              ),
              // Chevron (LEFT in RTL = last child)
              if (!hasCoupon) ...[
                const SizedBox(width: 10),
                Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 20, color: context.col.ink2),
              ],
            ]),
          ),
        ),

        // Applied coupon
        if (hasCoupon)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(children: [
              GestureDetector(
                onTap: () => ref.read(cartProvider.notifier).removeCoupon(),
                child: Icon(Icons.close, size: 18, color: context.col.ink3)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(widget.cart.couponCode!,
                    style: const TextStyle(fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w700, color: AppColors.success)),
                  const SizedBox(width: 4),
                  Text('− ${fmtPrice(widget.cart.discountAmount)} ${context.s.lydUnit}',
                    style: const TextStyle(fontFamily: 'PlusJakartaSans',
                      fontSize: 12, color: AppColors.success)),
                ]),
              ),
            ]),
          ),

        // Expanded input
        if (!hasCoupon && _expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(children: [
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _loading ? null : _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(context.s.apply,
                          style: const TextStyle(fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: context.s.couponHint,
                    hintStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13,
                      color: context.col.ink3),
                    filled: true, fillColor: context.col.bg,
                    errorText: _error,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.col.border)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.col.border)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

// ── Cart item card ────────────────────────────────────────────────────────────

class _CartItemCard extends ConsumerWidget {
  final CartItem item;
  const _CartItemCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = context.isAr;
    final name = isAr ? item.product.nameAr : item.product.name;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E4E4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Product image (first = RIGHT in RTL)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 78, height: 78,
              child: item.image != null
                  ? CachedNetworkImage(imageUrl: item.image!, fit: BoxFit.cover)
                  : Container(color: context.col.surfaceSoft,
                      child: Icon(Icons.image_outlined, color: context.col.ink4)),
            ),
          ),
          const SizedBox(width: 10),
          // Right side: name/price + action row
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5,
                    color: context.col.ink0)),
                Builder(builder: (_) {
                  // Try item.variation first, then fall back to product.variations lookup
                  List<dynamic>? attrs = item.variation?.attributes.isNotEmpty == true
                      ? item.variation!.attributes
                      : item.variationId != null
                          ? () {
                              try {
                                return item.product.variations
                                    .firstWhere((v) => v.id == item.variationId)
                                    .attributes;
                              } catch (e, st) { Sentry.captureException(e, stackTrace: st); return null; }
                            }()
                          : null;
                  if (attrs == null || attrs.isEmpty) return const SizedBox.shrink();
                  final label = attrs
                      .where((a) {
                        final t = (a.typeName as String).toLowerCase();
                        final tAr = (a.typeNameAr as String);
                        return t != 'gender' && t != 'جنس' && tAr != 'الجنس' && t != 'sex';
                      })
                      .map((a) => isAr && a.valueAr.isNotEmpty ? a.valueAr : a.value)
                      .where((v) => (v as String).isNotEmpty)
                      .join(' · ');
                  if (label.isEmpty) return const SizedBox.shrink();
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(label,
                        style: TextStyle(fontSize: 11, color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                    ),
                  ]);
                }),
                const SizedBox(height: 4),
                Builder(builder: (_) {
                  final onSale = item.product.salePrice != null &&
                      item.product.salePrice! < item.product.price &&
                      item.unitPrice < item.product.price;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${fmtPrice(item.unitPrice)} ${context.s.lydUnit}',
                        style: TextStyle(fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w800, fontSize: 15,
                          color: onSale ? AppColors.danger : context.col.ink0),
                      ),
                      if (onSale) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${fmtPrice(item.product.price)} ${context.s.lydUnit}',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans', fontSize: 12,
                            color: context.col.ink3,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: context.col.ink3,
                          ),
                        ),
                      ],
                    ],
                  );
                }),
                const SizedBox(height: 8),
                // Action row: [stepper (RIGHT)] [delete + save-for-later (LEFT)]
                Row(children: [
                  // Qty stepper (first = RIGHT in RTL)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: context.col.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _QtyBtn(
                        icon: Icons.add,
                        onTap: (() {
                          if (item.variationId != null) {
                            final v = item.variation;
                            if (v == null) return item.quantity >= 10;
                            if (!v.isActive || !v.inStock || v.stockQuantity <= 0) return true;
                            return item.quantity >= v.stockQuantity;
                          }
                          if (!item.product.manageStock) return item.quantity >= 10;
                          return item.product.stockQuantity != null &&
                              item.quantity >= item.product.stockQuantity!;
                        })()
                            ? null
                            : () => ref.read(cartProvider.notifier)
                                .updateQty(item.key, item.quantity + 1),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('${item.quantity}',
                          style: const TextStyle(fontFamily: 'PlusJakartaSans',
                            fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                      _QtyBtn(
                        icon: Icons.remove,
                        onTap: item.quantity > 1
                            ? () => ref.read(cartProvider.notifier)
                                .updateQty(item.key, item.quantity - 1)
                            : null,
                      ),
                    ]),
                  ),
                  const Spacer(),
                  // Save for later (RIGHT of trash in RTL)
                  GestureDetector(
                    onTap: () {
                      // Only add if not already wishlisted — toggle() would remove it
                      if (!ref.read(wishlistProvider).contains(item.productId)) {
                        ref.read(wishlistProvider.notifier).toggle(item.productId);
                      }
                      ref.read(cartProvider.notifier).remove(item.key);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(context.s.savedToWishlist),
                        duration: const Duration(seconds: 2),
                      ));
                    },
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.favorite_border_rounded, color: context.col.ink3, size: 16),
                      const SizedBox(width: 3),
                      Text(context.s.saveForLater,
                        style: TextStyle(fontSize: 11.5, color: context.col.ink3,
                          fontFamily: 'Cairo')),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  // Delete (leftmost)
                  GestureDetector(
                    onTap: () => ref.read(cartProvider.notifier).remove(item.key),
                    child: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.danger, size: 18),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _QtyBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SizedBox(
      width: 32, height: 32,
      child: Center(
        child: Icon(icon, size: 15,
          color: onTap != null ? context.col.ink0 : context.col.ink4),
      ),
    ),
  );
}

// ── Loyalty points banner ─────────────────────────────────────────────────────

class _LoyaltyPointsBanner extends ConsumerWidget {
  final double subtotal;
  const _LoyaltyPointsBanner({required this.subtotal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final rate = config.cashbackRate > 0 ? config.cashbackRate : 2.0;
    final cashback = subtotal * rate / 100;
    final points = (subtotal * rate / 10).round().clamp(1, 9999);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: isDark ? Colors.transparent : AppColors.success.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: isDark ? 0.4 : 0.25)),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: isDark ? Colors.transparent : AppColors.success,
            shape: BoxShape.circle,
            border: isDark ? Border.all(color: AppColors.success.withValues(alpha: 0.5)) : null,
          ),
          child: Icon(Icons.stars_rounded, size: 20,
            color: isDark ? AppColors.success : Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            context.s.orderCashbackEarn(
              cashback.round().toString(),
              points.toString()),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: AppColors.success, fontFamily: 'Cairo')),
        ),
      ]),
    );
  }
}

// ── May also like ─────────────────────────────────────────────────────────────

class _MayAlsoLikeSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_cartRecommendedProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(context.tr('قد يعجبك أيضاً', 'You may also like'),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                color: context.col.ink0, fontFamily: 'Cairo')),
          ),
          SizedBox(
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              reverse: true,
              clipBehavior: Clip.none,
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _RecommendedCard(product: products[i]),
            ),
          ),
          const SizedBox(height: 6),
        ]);
      },
    );
  }
}

class _RecommendedCard extends ConsumerWidget {
  final Product product;
  const _RecommendedCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = context.isAr;
    final name = isAr ? product.nameAr : product.name;
    final hasSale = product.salePrice != null && product.salePrice! < product.price;
    final displayPrice = hasSale ? product.salePrice! : product.price;
    final inCart = ref.watch(cartProvider).items.any((i) => i.productId == product.id);

    return GestureDetector(
      onTap: () => safePush(context, '/product/${product.id}'),
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: context.col.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.col.border),
        ),
        child: Stack(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
              child: SizedBox(
                width: 100, height: 76,
                child: product.firstImage != null
                    ? CachedNetworkImage(imageUrl: product.firstImage!, fit: BoxFit.cover)
                    : Container(color: context.col.surfaceSoft,
                        child: Icon(Icons.image_outlined, color: context.col.ink4)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, color: context.col.ink1,
                    fontFamily: 'Cairo')),
                const SizedBox(height: 2),
                Text('${fmtPrice(displayPrice)} ${context.s.lydUnit}',
                  style: TextStyle(fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w700, fontSize: 12,
                    color: hasSale ? AppColors.danger : context.col.ink0)),
                if (hasSale)
                  Text('${fmtPrice(product.price)} ${context.s.lydUnit}',
                    style: TextStyle(fontFamily: 'PlusJakartaSans',
                      fontSize: 10, color: context.col.ink3,
                      decoration: TextDecoration.lineThrough)),
              ]),
            ),
          ]),

          // Add to cart button
          Positioned(
            bottom: 6, left: 6,
            child: GestureDetector(
              onTap: inCart ? null : () {
                if (product.productType == 'variable' || product.variations.isNotEmpty) {
                  safePush(context, '/product/${product.id}');
                } else {
                  ref.read(cartProvider.notifier).add(product);
                }
              },
              child: Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: inCart ? AppColors.success : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(inCart ? Icons.check : Icons.add,
                  size: 15, color: Colors.white),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Trust badges ──────────────────────────────────────────────────────────────

class _TrustBadges extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final badges = [
      (Icons.verified_outlined,          context.s.trustAuthentic),
      (Icons.local_shipping_outlined,    context.s.trustDelivery),
      (Icons.workspace_premium_outlined, context.s.trustWarranty),
      (Icons.replay_outlined,            context.s.trustReturn),
    ];
    const teal = AppColors.teal;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.col.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: badges.map((b) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: teal.withValues(alpha: 0.08),
                border: Border.all(color: teal.withValues(alpha: 0.30)),
              ),
              child: Icon(b.$1, size: 18, color: teal),
            ),
            const SizedBox(height: 6),
            Text(b.$2,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: context.col.ink1,
                fontFamily: 'Cairo', height: 1.3)),
          ],
        )).toList(),
      ),
    );
  }
}

// ── First-order coupon banner ─────────────────────────────────────────────────

class _FirstOrderCouponBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final couponAsync = ref.watch(welcomeCouponProvider);

    final firstOrderApplied = cart.couponCode?.toUpperCase() == 'FIRSTORDER';
    final coupon = couponAsync.valueOrNull;

    // Nothing to show: not applied and no eligible coupon data
    if (!firstOrderApplied && coupon == null) return const SizedBox.shrink();

    // FIRSTORDER is in cart but provider still loading — show minimal strip to prevent flicker
    if (firstOrderApplied && coupon == null) {
      return _buildBannerShell(
        context,
        headline: 'تم تطبيق خصم الطلب الأول على سلتك',
        sub: 'هذا الخصم لمرة واحدة فقط، لا تفوّته!',
      );
    }

    final discountPct = coupon!.discount.toInt();
    final maxDiscount = coupon.maxDiscount?.toInt() ?? 39;
    return _buildBannerShell(
      context,
      headline: firstOrderApplied
          ? 'تم تطبيق خصم $discountPct% (بحد أقصى $maxDiscount د.ل) على طلبك الأول'
          : 'خصم $discountPct% على طلبك الأول — يتم التطبيق تلقائياً',
      sub: 'هذا الخصم لمرة واحدة فقط، لا تفوّته!',
    );
  }

  Widget _buildBannerShell(BuildContext context,
      {required String headline, required String sub}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(headline,
              style: const TextStyle(
                color: Colors.white, fontSize: 13,
                fontWeight: FontWeight.w800, fontFamily: 'Cairo')),
            const SizedBox(height: 2),
            Text(sub,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 11, fontFamily: 'Cairo')),
          ]),
        ),
      ]),
    );
  }
}

// ── Order summary ─────────────────────────────────────────────────────────────

class _OrderSummary extends StatelessWidget {
  final CartState cart;
  const _OrderSummary({required this.cart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E4E4)),
      ),
      child: Column(children: [
        _Row(context.s.subtotal,
          '${fmtPrice(cart.subtotal)} ${context.s.lyd}'),
        if (cart.discountAmount > 0)
          _Row(context.s.discount,
            '− ${fmtPrice(cart.discountAmount)} ${context.s.lyd}',
            valueColor: AppColors.success),
        _Row(context.s.shipping,
          cart.feesRefreshing
            ? '...'
            : (cart.deliveryFee == 0 ? context.s.free : '${fmtPrice(cart.deliveryFee)} ${context.s.lyd}'),
          valueColor: cart.deliveryFee == 0 && !cart.feesRefreshing ? AppColors.success : null),
        Divider(height: 20, color: context.col.border),
        _Row(context.tr('الإجمالي', 'Total'),
          '${fmtPrice(cart.total)} ${context.s.lyd}',
          bold: true, fontSize: 18),
        const SizedBox(height: 2),
        Row(children: [
          Text(context.tr('شامل ضريبة القيمة المضافة', 'VAT included'),
            style: TextStyle(fontSize: 10.5, color: context.col.ink3, fontFamily: 'Cairo')),
        ]),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  final double fontSize;
  const _Row(this.label, this.value,
    {this.valueColor, this.bold = false, this.fontSize = 14});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      // Label (first = RIGHT in RTL)
      Text(label, style: TextStyle(
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        color: bold ? context.col.ink0 : context.col.ink1,
        fontFamily: 'Cairo')),
      const Spacer(),
      // Value (second = LEFT in RTL)
      Text(value, style: TextStyle(
        fontFamily: 'PlusJakartaSans', fontSize: fontSize,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        color: valueColor ?? context.col.ink0)),
    ]),
  );
}
