import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/providers/wishlist_provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/product.dart';
import '../../../core/utils/format.dart';
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
    final wishlistIds = ref.watch(wishlistProvider);
    final productsAsync = ref.watch(wishlistProductsProvider);
    final displayCount = productsAsync.maybeWhen(
      data: (p) => p.length,
      orElse: () => wishlistIds.length,
    );

    if (!isLoggedIn) {
      return Scaffold(
        backgroundColor: context.col.bg,
        appBar: AppBar(
          title: Text(context.s.wishlistTitle,
              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
          backgroundColor: context.col.surface,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                    color: context.col.surfaceSoft, shape: BoxShape.circle),
                child: Icon(Icons.favorite_outline, size: 36, color: context.col.ink3),
              ),
              const SizedBox(height: 14),
              Text(context.s.wishlistEmpty,
                  style: const TextStyle(
                      fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(context.s.wishlistSub,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: context.col.ink2)),
              const SizedBox(height: 20),
              AppButton(
                  label: context.s.signIn,
                  width: 200,
                  onTap: () => safePush(context, '/signin')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.col.bg,
      appBar: AppBar(
        backgroundColor: context.col.surface,
        elevation: 0,
        title: Text('${context.s.wishlistTitle} ($displayCount)',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(context.s.loadError, style: TextStyle(color: context.col.ink2)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.read(wishlistProductsProvider.notifier).fetch(),
              child: Text(context.s.retry),
            ),
          ]),
        ),
        data: (products) {
          if (products.isEmpty) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => ref.read(wishlistProductsProvider.notifier).fetch(),
              child: ListView(children: [
                const SizedBox(height: 100),
                Center(child: Column(children: [
                  Icon(Icons.favorite_outline, size: 72, color: context.col.ink4),
                  const SizedBox(height: 12),
                  Text(context.s.wishlistEmpty,
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: context.col.ink2)),
                  const SizedBox(height: 6),
                  Text(context.s.wishlistSub,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: context.col.ink3)),
                  const SizedBox(height: 20),
                  AppButton(
                    label: context.s.startShopping,
                    width: 200,
                    onTap: () => context.go('/home'),
                  ),
                ])),
              ]),
            );
          }
          final discountCount = products.where((p) => p.displayPrice < p.price).length;
          final totalSavings = products.fold<double>(0, (sum, p) => sum + (p.price - p.displayPrice));
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.read(wishlistProductsProvider.notifier).fetch(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (discountCount > 0) ...[
                  _PriceDropBanner(count: discountCount, totalSavings: totalSavings),
                  const SizedBox(height: 14),
                ],
                ...products.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _WishlistCard(product: p),
                )),
              ],
            ),
          );
        },
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

    final Color stockColor;
    final String stockLabel;
    if (!product.inStock) {
      stockColor = AppColors.danger;
      stockLabel = isAr ? 'غير متوفر' : 'Out of stock';
    } else if (product.stockQuantity != null && product.stockQuantity! > 0 && product.stockQuantity! <= 5) {
      stockColor = AppColors.warn;
      stockLabel = isAr ? 'يبقى ${product.stockQuantity} فقط' : 'Only ${product.stockQuantity} left';
    } else {
      stockColor = AppColors.success;
      stockLabel = isAr ? 'متوفر' : 'Available';
    }

    return GestureDetector(
      onTap: () => safePush(context, '/product/${product.id}'),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.col.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.col.border, width: 1),
            ),
            child: Row(children: [
              // Square image + discount badge
              Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 82, height: 82,
                    child: product.firstImage != null
                        ? CachedNetworkImage(
                            imageUrl: product.firstImage!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                                color: context.col.surfaceSoft,
                                child: Icon(Icons.image_outlined, color: context.col.ink4, size: 28)),
                          )
                        : Container(
                            color: context.col.surfaceSoft,
                            child: Icon(Icons.image_outlined, color: context.col.ink4, size: 28)),
                  ),
                ),
                if (hasDiscount)
                  Positioned(
                    top: 4, left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.danger, borderRadius: BorderRadius.circular(12)),
                      child: Text('-${((1 - salePrice / product.price) * 100).round()}%',
                          style: const TextStyle(
                              fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ]),
              const SizedBox(width: 12),

              // Info column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // top padding for X button space
                    const SizedBox(height: 2),
                    if (brandLabel != null)
                      Text(brandLabel,
                          style: TextStyle(fontSize: 11, color: context.col.ink3),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(name,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3)),
                    const SizedBox(height: 6),
                    // Price
                    Row(children: [
                      Text('${fmtPrice(salePrice)} ${context.s.lydUnit}',
                          style: const TextStyle(
                              fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w800)),
                      if (hasDiscount) ...[
                        const SizedBox(width: 6),
                        Text('${fmtPrice(product.price)} ${context.s.lydUnit}',
                            style: TextStyle(
                                fontFamily: 'PlusJakartaSans', fontSize: 11,
                                color: context.col.ink3, decoration: TextDecoration.lineThrough)),
                      ],
                    ]),
                    const SizedBox(height: 8),
                    // Stock dot + label  |  compact action button — same row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 7, height: 7,
                              decoration: BoxDecoration(color: stockColor, shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          Text(stockLabel,
                              style: TextStyle(
                                  fontFamily: 'Cairo', fontSize: 12,
                                  fontWeight: FontWeight.w600, color: stockColor)),
                        ]),
                        if (isVariable)
                          _WishBtn(
                            label: isAr ? 'اختر المقاس' : 'Select Size',
                            isVariable: true,
                            onTap: () => safePush(context, '/product/${product.id}'),
                          )
                        else if (product.inStock)
                          _WishBtn(
                            label: isAr ? 'أضف للسلة' : 'Add to Cart',
                            isVariable: false,
                            onTap: () => ref.read(cartProvider.notifier).add(product),
                          )
                        else
                          _WishBtn(
                            label: isAr ? 'غير متوفر' : 'Unavailable',
                            isVariable: false,
                            disabled: true,
                            onTap: () {},
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ]),
          ),
          // X — physical top-left
          Positioned(
            top: 6, left: 6,
            child: GestureDetector(
              onTap: () {
                ref.read(wishlistProvider.notifier).toggle(product.id);
                ref.read(wishlistProductsProvider.notifier).remove(product.id);
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(Icons.close, size: 16, color: context.col.ink3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WishBtn extends StatelessWidget {
  final String label;
  final bool isVariable;
  final bool disabled;
  final VoidCallback onTap;
  const _WishBtn({
    required this.label,
    required this.isVariable,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    if (disabled) {
      return SizedBox(
        width: 100,
        height: 28,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.col.surfaceSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.col.border),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.col.ink3)),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 100,
        height: 28,
        child: Container(
          decoration: BoxDecoration(
            color: isVariable ? Colors.transparent : AppColors.primary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isVariable ? context.col.ink3 : AppColors.primary,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(label,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: isVariable ? 10 : 12,
                      fontWeight: FontWeight.w600,
                      color: isVariable ? context.col.ink2 : Colors.white)),
              if (isVariable) ...[
                const SizedBox(width: 2),
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 11, color: context.col.ink3),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceDropBanner extends StatelessWidget {
  final int count;
  final double totalSavings;
  const _PriceDropBanner({required this.count, required this.totalSavings});

  @override
  Widget build(BuildContext context) {
    final savedStr = '${fmtPrice(totalSavings)} ${context.s.lydUnit}';
    return Container(
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
                      ? '$count منتجات انخفضت سعرها  '
                      : '$count items on sale  ',
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
    );
  }
}
