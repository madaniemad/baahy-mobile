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
import '../../../core/api/api_client.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/utils/navigation.dart';

// ── Recommended products provider ────────────────────────────────────────────

final _cartRecommendedProvider = FutureProvider<List<Product>>((ref) async {
  try {
    final res = await ApiClient.instance.dio.get('/products/recommended',
        queryParameters: {'limit': 8});
    final list = (res.data['data'] as List?) ?? [];
    return list.map((p) => Product.fromJson(p as Map<String, dynamic>)).toList();
  } catch (_) {
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
        // In RTL: leading = RIGHT side, actions = LEFT side
        leading: IconButton(
          onPressed: () => safePush(context, '/checkout'),
          icon: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: context.col.ink0)),
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
                  builder: (_) => AlertDialog(
                    title: Text(context.s.clearCart,
                      style: const TextStyle(fontFamily: 'Cairo')),
                    content: Text(context.s.clearCartMsg),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false),
                        child: Text(context.s.cancel)),
                      TextButton(onPressed: () => Navigator.pop(context, true),
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
            borderRadius: BorderRadius.circular(10),
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

  Future<void> _handleCheckout() async {
    if (!ref.read(authProvider).isLoggedIn) {
      safePush(context, '/signin');
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
        builder: (_) => AlertDialog(
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
                ...unavailable.map((u) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.remove_circle_outline_rounded, size: 14, color: AppColors.danger),
                    const SizedBox(width: 6),
                    Expanded(child: Text(isAr ? u.item.product.nameAr : u.item.product.name,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13))),
                  ]),
                )),
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
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.s.cancel,
                style: TextStyle(fontFamily: 'Cairo', color: context.col.ink2))),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
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
            if (cart.freeShippingRemaining > 0)
              _FreeShippingProgressBanner(
                remaining: cart.freeShippingRemaining,
                subtotal: cart.subtotal,
                threshold: cart.freeShippingThreshold),
            if (cart.subtotal >= cart.freeShippingThreshold)
              _FreeShippingAchievedBanner(saved: cart.deliveryFee),

            // ── Delivery header ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 12),
              child: Row(children: [
                // Truck icon (first = RIGHT in RTL)
                Container(
                  width: 38, height: 38,
                  decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.local_shipping_rounded,
                    size: 20, color: Colors.white),
                ),
                const SizedBox(width: 10),
                // Text (LEFT in RTL)
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.s.deliveryBy,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                        color: context.col.ink0, fontFamily: 'Cairo')),
                    const SizedBox(height: 3),
                    Text(
                      context.tr(
                        'توصيل خلال 1-2 يوم  •  شحنة واحدة  •  الدفع عند الاستلام متاح',
                        'Delivery in 1-2 days  •  One shipment  •  COD available'),
                      style: TextStyle(fontSize: 11, color: context.col.ink2,
                        fontFamily: 'Cairo', height: 1.4)),
                  ]),
                ),
              ]),
            ),

            // ── Cart items ────────────────────────────────────────────────
            ..._buildGroupedItems(context, cart.items),

            const SizedBox(height: 6),

            // ── Coupon section ────────────────────────────────────────────
            _CouponSection(cart: cart),

            const SizedBox(height: 10),

            // ── Loyalty points banner ─────────────────────────────────────
            _LoyaltyPointsBanner(subtotal: cart.subtotal),

            const SizedBox(height: 10),

            // ── "قد يعجبك أيضاً" ─────────────────────────────────────────
            _MayAlsoLikeSection(),

            const SizedBox(height: 10),

            // ── Trust badges ──────────────────────────────────────────────
            _TrustBadges(),

            const SizedBox(height: 16),

            // ── Order summary ─────────────────────────────────────────────
            _OrderSummary(cart: cart),

            const SizedBox(height: 12),
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
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.lock_outline_rounded, size: 18,
                color: Color(0xFFE8FFFE)),
              const SizedBox(width: 8),
              if (_checking)
                const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE8FFFE)))
              else
                Text(context.tr('متابعة الدفع', 'Proceed to Payment'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                    color: Color(0xFFE8FFFE), fontFamily: 'Cairo')),
            ]),
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
        borderRadius: BorderRadius.circular(10),
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
      borderRadius: BorderRadius.circular(10),
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.col.border),
        boxShadow: AppShadows.shadowCard,
      ),
      child: Column(children: [
        // Header row — always visible
        GestureDetector(
          onTap: hasCoupon ? null : () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(children: [
              // Chevron (LEFT in RTL)
              if (!hasCoupon)
                Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 20, color: context.col.ink2),
              const Spacer(),
              // Title + subtitle (RIGHT in RTL)
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(context.tr('لديك كوبون خصم؟', 'Have a coupon?'),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: context.col.ink0, fontFamily: 'Cairo')),
                  const SizedBox(width: 8),
                  Icon(Icons.local_offer_outlined, size: 16, color: context.col.ink1),
                ]),
                if (!hasCoupon)
                  Text(context.tr('أدخل كود الخصم للحصول على خصم إضافي',
                    'Enter coupon code for extra discount'),
                    style: TextStyle(fontSize: 11, color: context.col.ink3,
                      fontFamily: 'Cairo')),
              ]),
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
                  borderRadius: BorderRadius.circular(8),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.col.border)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.col.border)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.col.border),
        boxShadow: AppShadows.shadowCard,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Product image (first = RIGHT in RTL)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
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
                if (item.variation != null && item.variation!.attributes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.variation!.attributes
                        .map((a) => isAr && a.valueAr.isNotEmpty ? a.valueAr : a.value)
                        .join(' · '),
                    style: TextStyle(fontSize: 11.5, color: context.col.ink2)),
                ],
                const SizedBox(height: 4),
                Text(
                  '${fmtPrice(item.unitPrice)} ${context.s.lydUnit}',
                  style: TextStyle(fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w800, fontSize: 15, color: context.col.ink0),
                ),
                const SizedBox(height: 8),
                // Action row: [stepper (RIGHT)] [delete + save-for-later (LEFT)]
                Row(children: [
                  // Qty stepper (first = RIGHT in RTL)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: context.col.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _QtyBtn(
                        icon: Icons.add,
                        onTap: (item.product.stockQuantity != null &&
                                item.quantity >= item.product.stockQuantity!)
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
                      ref.read(wishlistProvider.notifier).toggle(item.productId);
                      ref.read(cartProvider.notifier).remove(item.key);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(context.s.savedToWishlist),
                        duration: const Duration(seconds: 2),
                      ));
                    },
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.bookmark_border_rounded, color: context.col.ink3, size: 16),
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
    final pointsRate = config.cashbackRate > 0 ? config.cashbackRate : 2.0;
    final points = (subtotal * pointsRate / 10).round().clamp(1, 9999);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        // Star circle (first = RIGHT in RTL)
        Container(
          width: 42, height: 42,
          decoration: const BoxDecoration(
            color: AppColors.primary, shape: BoxShape.circle),
          child: const Icon(Icons.star_outline_rounded, size: 22, color: Colors.white),
        ),
        const SizedBox(width: 12),
        // Text (second = LEFT in RTL)
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              context.tr(
                'ستحصل على $points نقطة مكافآت من هذا الطلب',
                'You\'ll earn $points reward points from this order'),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: context.col.ink0, fontFamily: 'Cairo')),
            const SizedBox(height: 2),
            Text(
              context.tr('عند إتمام الشراء', 'Upon completing purchase'),
              style: const TextStyle(fontSize: 11, color: AppColors.primary,
                fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
          ]),
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
            child: Row(children: [
              // "عرض الكل" (LEFT in RTL)
              GestureDetector(
                onTap: () => safePush(context, '/home'),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.chevron_left, size: 16, color: AppColors.primary),
                  Text(context.tr('عرض الكل', 'See all'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppColors.primary, fontFamily: 'Cairo')),
                ]),
              ),
              const Spacer(),
              // Title (RIGHT in RTL)
              Text(context.tr('قد يعجبك أيضاً', 'You may also like'),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                  color: context.col.ink0, fontFamily: 'Cairo')),
            ]),
          ),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              reverse: true,
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
    final price = product.salePrice ?? product.price;
    final inCart = ref.watch(cartProvider).items.any((i) => i.productId == product.id);

    return GestureDetector(
      onTap: () => safePush(context, '/product/${product.id}'),
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: context.col.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.col.border),
        ),
        child: Stack(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
              child: SizedBox(
                width: 120, height: 90,
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
                Text('${fmtPrice(price)} ${context.s.lydUnit}',
                  style: TextStyle(fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w700, fontSize: 12,
                    color: context.col.ink0)),
              ]),
            ),
          ]),

          // Add to cart button
          Positioned(
            bottom: 38, left: 6,
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
      (Icons.verified_outlined, context.tr('منتجات أصلية\n100%', 'Authentic\n100%')),
      (Icons.local_shipping_outlined, context.tr('شحن سريع\n1-2 يوم', 'Fast Ship\n1-2 days')),
      (Icons.payments_outlined, context.tr('الدفع عند\nالاستلام', 'Cash on\nDelivery')),
      (Icons.undo_rounded, context.tr('استرجاع خلال\n3 أيام', 'Return in\n3 days')),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: context.col.surfaceSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: badges.map((b) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(b.$1, size: 22, color: context.col.ink2),
            const SizedBox(height: 5),
            Text(b.$2,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: context.col.ink2,
                fontFamily: 'Cairo', height: 1.3)),
          ],
        )).toList(),
      ),
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.col.border),
        boxShadow: AppShadows.shadowCard,
      ),
      child: Column(children: [
        _Row(context.tr('المجموع الجزئي', 'Subtotal'),
          '${fmtPrice(cart.subtotal)} ${context.s.lyd}'),
        if (cart.discountAmount > 0)
          _Row(context.s.discount,
            '− ${fmtPrice(cart.discountAmount)} ${context.s.lyd}',
            valueColor: AppColors.success),
        _Row(context.s.shipping,
          cart.deliveryFee == 0 ? context.s.free : '${fmtPrice(cart.deliveryFee)} ${context.s.lyd}',
          valueColor: cart.deliveryFee == 0 ? AppColors.success : null),
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
