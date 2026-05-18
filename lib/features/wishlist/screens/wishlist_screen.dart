import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/providers/wishlist_provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/product.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';

String _decodeHtml(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&nbsp;', ' ');

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(authProvider).isLoggedIn;
    final products = ref.watch(wishlistProductsProvider);

    if (!isLoggedIn) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text('المفضلة',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90, height: 90,
                decoration: const BoxDecoration(
                    color: AppColors.surfaceSoft, shape: BoxShape.circle),
                child: const Icon(Icons.favorite_outline, size: 36, color: AppColors.ink3),
              ),
              const SizedBox(height: 14),
              const Text('مفضلتك فارغة',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('اضغط على القلب لحفظ المنتج للوقت لاحق.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: AppColors.ink2)),
              const SizedBox(height: 20),
              AppButton(
                  label: 'تسجيل الدخول',
                  width: 200,
                  onTap: () => safePush(context, '/signin')),
            ],
          ),
        ),
      );
    }

    final discountCount = products.where((p) => p.displayPrice < p.price).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('المفضلة (${products.length})',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      ),
      body: products.isEmpty
          ? RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => ref.read(wishlistProductsProvider.notifier).fetch(),
              child: ListView(children: const [
                SizedBox(height: 100),
                Center(
                  child: Column(children: [
                    Icon(Icons.favorite_outline, size: 72, color: AppColors.ink4),
                    SizedBox(height: 12),
                    Text('لا توجد منتجات في المفضلة',
                        style: TextStyle(
                            fontFamily: 'Cairo', fontSize: 16, color: AppColors.ink2)),
                  ]),
                ),
              ]),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => ref.read(wishlistProductsProvider.notifier).fetch(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  // Price drops banner
                  if (discountCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.local_fire_department_rounded,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('تخفيضات الأسعار',
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: AppColors.primary)),
                              Text('$discountCount منتج انخفض سعره — أضفه قبل نفاد الكمية',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.ink2, height: 1.4)),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ],
                  ...products.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _WishlistCard(product: p),
                      )),
                ],
              ),
            ),
    );
  }
}

class _WishlistCard extends ConsumerWidget {
  final Product product;
  const _WishlistCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = context.isAr;
    final name = isAr ? product.nameAr : product.name;
    final rawBrand = (product.brand != null && product.brand!.isNotEmpty)
        ? product.brand!
        : product.vendor != null
            ? (isAr ? product.vendor!.storeNameAr : product.vendor!.storeName)
            : null;
    final brandLabel = rawBrand != null ? _decodeHtml(rawBrand) : null;
    final salePrice = product.displayPrice;
    final hasDiscount = salePrice < product.price;
    final isVariable = product.productType == 'variable';

    return GestureDetector(
      onTap: () => safePush(context, '/product/${product.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasDiscount ? AppColors.primary : AppColors.border,
            width: hasDiscount ? 1.5 : 1,
          ),
          boxShadow: hasDiscount ? AppShadows.shadowCard : null,
        ),
        child: Row(children: [
          // Image with discount badge
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 82, height: 82,
                  child: product.firstImage != null
                      ? CachedNetworkImage(
                          imageUrl: product.firstImage!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              Container(color: AppColors.surfaceSoft,
                                child: const Icon(Icons.image_outlined,
                                    color: AppColors.ink4, size: 28)),
                        )
                      : Container(
                          color: AppColors.surfaceSoft,
                          child: const Icon(Icons.image_outlined,
                              color: AppColors.ink4, size: 28)),
                ),
              ),
              if (hasDiscount)
                Positioned(
                  top: 4, left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                        '−${((1 - salePrice / product.price) * 100).round()}%',
                        style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (brandLabel != null)
                  Text(brandLabel,
                      style: const TextStyle(fontSize: 11, color: AppColors.ink3),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, height: 1.3)),
                const SizedBox(height: 6),
                Row(children: [
                  Text('${salePrice.toStringAsFixed(0)} د.ل',
                      style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  if (hasDiscount) ...[
                    const SizedBox(width: 6),
                    Text('${product.price.toStringAsFixed(0)} د.ل',
                        style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            color: AppColors.ink3,
                            decoration: TextDecoration.lineThrough)),
                  ],
                ]),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Actions: X top, Add bottom
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => ref.read(wishlistProvider.notifier).toggle(product.id),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 18, color: AppColors.ink3),
                ),
              ),
              const SizedBox(height: 14),
              if (isVariable)
                _ActionChip(
                  label: 'اختر',
                  icon: Icons.tune_rounded,
                  filled: hasDiscount,
                  onTap: () => safePush(context, '/product/${product.id}'),
                )
              else if (product.inStock)
                _ActionChip(
                  label: 'أضف',
                  icon: Icons.shopping_cart_outlined,
                  filled: true,
                  onTap: () => ref.read(cartProvider.notifier).add(product),
                )
              else
                _ActionChip(
                  label: 'نفد',
                  icon: Icons.notifications_outlined,
                  filled: false,
                  onTap: () => safePush(context, '/product/${product.id}'),
                ),
            ],
          ),
        ]),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;
  const _ActionChip(
      {required this.label,
      required this.icon,
      required this.filled,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: filled ? AppColors.primary : AppColors.border, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: filled ? Colors.white : AppColors.ink2),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: filled ? Colors.white : AppColors.ink1)),
        ]),
      ),
    );
  }
}
