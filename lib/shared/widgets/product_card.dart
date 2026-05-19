import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/models/product.dart';
import '../../core/providers/wishlist_provider.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/l10n.dart';
import '../../core/utils/navigation.dart';
import '../theme/app_theme.dart';

class ProductCard extends ConsumerWidget {
  final Product product;
  final double? width;
  const ProductCard({required this.product, this.width, super.key});

  static String _decode(String s) => s
      .replaceAll('&amp;', '&').replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>').replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'").replaceAll('&nbsp;', ' ');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = context.isAr;
    final rawName = isAr ? product.nameAr : product.name;
    final rawBrand = product.brand != null && product.brand!.isNotEmpty
        ? _decode(product.brand!)
        : product.vendor != null
            ? _decode(isAr ? product.vendor!.storeNameAr : product.vendor!.storeName)
            : null;
    final name = rawBrand != null ? '$rawBrand $rawName' : rawName;
    final inWishlist = ref.watch(wishlistProvider).contains(product.id);

    return GestureDetector(
      onTap: () => safePush(context, '/product/${product.id}'),
      child: Container(
        width: width,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.cardRadius,
          boxShadow: AppShadows.shadowCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
                  child: AspectRatio(
                    aspectRatio: 0.8,
                    child: product.firstImage != null
                        ? CachedNetworkImage(
                            imageUrl: product.firstImage!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: AppColors.surfaceSoft),
                            errorWidget: (_, __, ___) => Container(
                              color: AppColors.surfaceSoft,
                              child: const Icon(Icons.image_not_supported_outlined, color: AppColors.ink4, size: 28),
                            ),
                          )
                        : Container(
                            color: AppColors.bg,
                            child: const Icon(Icons.image_outlined, color: AppColors.ink4),
                          ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: isAr ? null : 8,
                  left: isAr ? 8 : null,
                  child: _WishlistButton(productId: product.id, inWishlist: inWishlist),
                ),
                if (product.hasDiscount)
                  Positioned(
                    top: 8,
                    left: isAr ? null : 8,
                    right: isAr ? 8 : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '-${product.discountPercent}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                if (!product.inStock)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.55),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.ink0,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            context.tr('نفدت الكمية', 'OUT OF STOCK'),
                            style: const TextStyle(color: Colors.white, fontSize: 10,
                              fontWeight: FontWeight.w700, letterSpacing: 0.4),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
                  ),
                  const SizedBox(height: 5),
                  if (product.inStock &&
                      product.productType != 'variable' &&
                      product.stockQuantity != null &&
                      product.stockQuantity! > 0 &&
                      product.stockQuantity! <= 5)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        context.tr('تبقّى ${product.stockQuantity} فقط', 'Only ${product.stockQuantity} left'),
                        style: const TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.w700,
                          color: Color(0xFFB85A3A)),
                      ),
                    ),
                  Row(
                    children: [
                      Text(
                        '${product.displayPrice.toStringAsFixed(0)} د.ل',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink0,
                        ),
                      ),
                      if (product.hasDiscount) ...[
                        const SizedBox(width: 4),
                        Text(
                          product.price.toStringAsFixed(0),
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            color: AppColors.ink3,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                      const Spacer(),
                      _AddToCartButton(product: product),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistButton extends ConsumerWidget {
  final int productId;
  final bool inWishlist;
  const _WishlistButton({required this.productId, required this.inWishlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        final isLoggedIn = ref.read(authProvider).isLoggedIn;
        if (!isLoggedIn) {
          safePush(context, '/signin');
          return;
        }
        ref.read(wishlistProvider.notifier).toggle(productId);
      },
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: AppShadows.shadowCard,
        ),
        child: Icon(
          inWishlist ? Icons.favorite_rounded : Icons.favorite_outline,
          size: 16,
          color: inWishlist ? AppColors.danger : AppColors.ink3,
        ),
      ),
    );
  }
}

class _AddToCartButton extends ConsumerWidget {
  final Product product;
  const _AddToCartButton({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!product.inStock) return const SizedBox.shrink();
    if (product.productType == 'variable') {
      return GestureDetector(
        onTap: () => safePush(context, '/product/${product.id}'),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
        ),
      );
    }
    return GestureDetector(
      onTap: () => ref.read(cartProvider.notifier).add(product),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
      ),
    );
  }
}

class ProductCardSkeleton extends StatelessWidget {
  final double? width;
  const ProductCardSkeleton({this.width, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(aspectRatio: 0.8, child: _shimmer()),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(height: 12, width: double.infinity),
                const SizedBox(height: 6),
                _shimmerBox(height: 12, width: 80),
                const SizedBox(height: 8),
                _shimmerBox(height: 14, width: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmer() => Container(color: AppColors.bg);
  Widget _shimmerBox({required double height, required double width}) =>
      Container(height: height, width: width, decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(4),
      ));
}
