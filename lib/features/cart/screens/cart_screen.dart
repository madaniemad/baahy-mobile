import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/cart.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/widgets/app_button.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          context.tr('السلة (${cart.count})', 'Cart (${cart.count})'),
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
        ),
        actions: [
          if (cart.items.isNotEmpty)
            TextButton(
              onPressed: () async {
                final s = context.s;
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(s.clearCart, style: const TextStyle(fontFamily: 'Cairo')),
                    content: Text(s.clearCartMsg),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false),
                        child: Text(s.cancel)),
                      TextButton(onPressed: () => Navigator.pop(context, true),
                        child: Text(context.tr('مسح', 'Clear'),
                          style: const TextStyle(color: AppColors.danger))),
                    ],
                  ),
                );
                if (ok == true) ref.read(cartProvider.notifier).clear();
              },
              child: Text(context.s.clearAll,
                style: const TextStyle(color: AppColors.danger, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: cart.items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_bag_outlined, size: 72, color: AppColors.ink4),
                  const SizedBox(height: 12),
                  Text(context.s.emptyCart,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, color: AppColors.ink2)),
                  const SizedBox(height: 20),
                  AppButton(
                    label: context.s.shopNow,
                    width: 180,
                    onTap: () => context.go('/home'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    children: [
                      // Free shipping progress bar
                      if (cart.freeShippingRemaining > 0)
                        _FreeShippingBanner(remaining: cart.freeShippingRemaining,
                          subtotal: cart.subtotal, threshold: cart.freeShippingThreshold),
                      if (cart.subtotal >= cart.freeShippingThreshold)
                        _FreeShippingAchieved(),

                      const SizedBox(height: 10),

                      // Delivered by baahy header
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.primary, shape: BoxShape.circle),
                            child: const Icon(Icons.local_shipping_rounded,
                              size: 16, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(context.s.deliveryBy,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                            Text(context.s.oneShipment,
                              style: const TextStyle(fontSize: 11, color: AppColors.ink3)),
                          ]),
                        ]),
                      ),

                      // Cart items
                      ...cart.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CartItemCard(item: item),
                      )),

                      const SizedBox(height: 6),

                      // Coupon section
                      _CouponSection(cart: cart),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
                _CartSummary(cart: cart),
              ],
            ),
    );
  }
}

// ── Free shipping banner ──────────────────────────────────────────────────────

class _FreeShippingBanner extends StatelessWidget {
  final double remaining;
  final double subtotal;
  final double threshold;
  const _FreeShippingBanner({required this.remaining, required this.subtotal, required this.threshold});

  @override
  Widget build(BuildContext context) {
    final progress = (subtotal / threshold).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.local_shipping_outlined, size: 18, color: AppColors.teal600),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(TextSpan(
                style: const TextStyle(fontSize: 12.5),
                children: [
                  TextSpan(
                    text: '${remaining.toStringAsFixed(0)} د.ل',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink0,
                      fontFamily: 'PlusJakartaSans')),
                  TextSpan(text: ' ${context.tr('حتى الشحن المجاني', 'for free shipping')}',
                    style: const TextStyle(color: AppColors.ink1)),
                ],
              )),
            ),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: AppColors.teal100,
              color: AppColors.teal600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FreeShippingAchieved extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.success.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
    ),
    child: Row(children: [
      const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
      const SizedBox(width: 8),
      Text(context.s.freeShipEarned,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success)),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: AppShadows.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.local_offer_outlined, size: 16, color: AppColors.ink1),
            const SizedBox(width: 8),
            Text(context.s.coupon,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          if (hasCoupon)
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(widget.cart.couponCode!,
                    style: const TextStyle(fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w700, color: AppColors.success)),
                  const SizedBox(width: 4),
                  Text('− ${widget.cart.discountAmount.toStringAsFixed(0)} د.ل',
                    style: const TextStyle(fontFamily: 'PlusJakartaSans',
                      fontSize: 12, color: AppColors.success)),
                ]),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => ref.read(cartProvider.notifier).removeCoupon(),
                child: const Icon(Icons.close, size: 18, color: AppColors.ink3),
              ),
            ])
          else
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: context.s.couponHint,
                    hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.ink3),
                    filled: true, fillColor: AppColors.bg,
                    errorText: _error,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _loading ? null : _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ink0,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            ]),
        ],
      ),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: AppShadows.shadowCard,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 72, height: 72,
              child: item.image != null
                  ? CachedNetworkImage(imageUrl: item.image!, fit: BoxFit.cover)
                  : Container(color: AppColors.bg,
                      child: const Icon(Icons.image_outlined, color: AppColors.ink4)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (item.variation != null && item.variation!.attributes.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.variation!.attributes
                        .map((a) => isAr && a.valueAr.isNotEmpty ? a.valueAr : a.value)
                        .join(' · '),
                    style: const TextStyle(fontSize: 12, color: AppColors.ink2),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${item.unitPrice.toStringAsFixed(0)} د.ل',
                  style: const TextStyle(fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.primary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _QtyBtn(
                      icon: Icons.remove,
                      onTap: () => ref.read(cartProvider.notifier).updateQty(item.key, item.quantity - 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('${item.quantity}',
                        style: const TextStyle(fontFamily: 'PlusJakartaSans',
                          fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                    _QtyBtn(
                      icon: Icons.add,
                      onTap: () => ref.read(cartProvider.notifier).updateQty(item.key, item.quantity + 1),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => ref.read(cartProvider.notifier).remove(item.key),
                      child: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                    ),
                  ],
                ),
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
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 16, color: AppColors.ink0),
    ),
  );
}

// ── Cart summary ──────────────────────────────────────────────────────────────

class _CartSummary extends ConsumerWidget {
  final CartState cart;
  const _CartSummary({required this.cart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: AppShadows.shadowPop,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Column(
        children: [
          _SummaryRow(context.s.subtotal, '${cart.subtotal.toStringAsFixed(0)} ${context.s.lyd}'),
          if (cart.discountAmount > 0)
            _SummaryRow(
              context.s.discount,
              '− ${cart.discountAmount.toStringAsFixed(0)} ${context.s.lyd}',
              color: AppColors.success,
            ),
          _SummaryRow(
            context.s.shipping,
            cart.deliveryFee == 0 ? context.s.free : '${cart.deliveryFee.toStringAsFixed(0)} ${context.s.lyd}',
            color: cart.deliveryFee == 0 ? AppColors.success : null,
          ),
          const Divider(height: 20, color: AppColors.border),
          _SummaryRow(context.s.total, '${cart.total.toStringAsFixed(0)} ${context.s.lyd}',
            bold: true, fontSize: 17),
          const SizedBox(height: 14),
          AppButton(
            label: context.s.checkout,
            onTap: () => ref.read(authProvider).isLoggedIn
                ? safePush(context, '/checkout')
                : safePush(context, '/signin'),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;
  final double fontSize;
  const _SummaryRow(this.label, this.value,
      {this.color, this.bold = false, this.fontSize = 14});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        Text(value, style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: color ?? AppColors.ink0)),
      ],
    ),
  );
}
