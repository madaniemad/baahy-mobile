import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/cart.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final isLoggedIn = ref.watch(authProvider).isLoggedIn;

    if (!isLoggedIn) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text('السلة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
          backgroundColor: Colors.white, elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_bag_outlined, size: 72, color: AppColors.ink4),
              const SizedBox(height: 12),
              const Text('سجّل دخولك لعرض السلة',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: AppColors.ink2)),
              const SizedBox(height: 20),
              AppButton(
                label: 'تسجيل الدخول',
                width: 200,
                onTap: () => context.push('/signin'),
              ),
            ],
          ),
        ),
      );
    }

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
              onPressed: () => ref.read(cartProvider.notifier).clear(),
              child: const Text('مسح الكل',
                style: TextStyle(color: AppColors.danger, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
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
                  const Text('السلة فارغة',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: AppColors.ink2)),
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'تسوق الآن',
                    width: 180,
                    onTap: () => context.go('/home'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _CartItemCard(item: cart.items[i]),
                  ),
                ),
                _CartSummary(cart: cart),
              ],
            ),
    );
  }
}

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
        borderRadius: BorderRadius.circular(14),
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
                      onTap: () => ref.read(cartProvider.notifier).updateQty(item.id, item.quantity - 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('${item.quantity}',
                        style: const TextStyle(fontFamily: 'PlusJakartaSans',
                          fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                    _QtyBtn(
                      icon: Icons.add,
                      onTap: () => ref.read(cartProvider.notifier).updateQty(item.id, item.quantity + 1),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => ref.read(cartProvider.notifier).remove(item.id),
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _Row('المجموع الفرعي', '${cart.subtotal.toStringAsFixed(0)} د.ل'),
          if ((cart.shippingCost ?? 0) > 0)
            _Row('الشحن', '${cart.shippingCost!.toStringAsFixed(0)} د.ل'),
          if ((cart.discount ?? 0) > 0)
            _Row('الخصم', '-${cart.discount!.toStringAsFixed(0)} د.ل',
              color: AppColors.success),
          const Divider(height: 20, color: AppColors.border),
          _Row('الإجمالي', '${cart.total.toStringAsFixed(0)} د.ل',
            bold: true, fontSize: 17),
          const SizedBox(height: 14),
          AppButton(
            label: 'متابعة الشراء',
            onTap: () => context.push('/checkout'),
          ),
        ],
      ),
    );
  }

  Widget _Row(String label, String value,
      {Color? color, bool bold = false, double fontSize = 14}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
          Text(value, style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: fontSize, fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: color ?? AppColors.ink0)),
        ],
      ),
    );
}
