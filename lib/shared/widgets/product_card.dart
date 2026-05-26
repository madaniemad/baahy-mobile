import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/models/product.dart';
import '../../core/providers/wishlist_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/l10n.dart';
import '../../core/utils/navigation.dart';
import '../theme/app_theme.dart';

class ProductCard extends ConsumerWidget {
  final Product product;
  final double? width;
  const ProductCard({required this.product, this.width, super.key});

  static bool _isClothing(String ar, String en) =>
      ar.contains('ملاب') || en.contains('cloth') || en.contains('clothing');

  static BoxFit _imageFit(Product p) {
    final cat = p.category;
    if (cat == null) return BoxFit.contain;
    // Check the leaf category OR its parent — API now returns both.
    if (_isClothing(cat.nameAr, cat.name.toLowerCase())) return BoxFit.cover;
    final par = cat.parent;
    if (par != null && _isClothing(par.nameAr, par.name.toLowerCase())) return BoxFit.cover;
    return BoxFit.contain;
  }

  static Widget _buildProductImage(Product p) {
    final fit = _imageFit(p);
    Widget img = p.firstImage != null
        ? CachedNetworkImage(
            imageUrl: p.firstImage!,
            fit: fit,
            placeholder: (_, __) => Container(color: AppColors.surfaceSoft),
            errorWidget: (_, __, ___) => Container(
              color: AppColors.surfaceSoft,
              child: const Icon(Icons.image_not_supported_outlined, color: AppColors.ink4, size: 28),
            ),
          )
        : Container(
            color: AppColors.bg,
            child: const Icon(Icons.image_outlined, color: AppColors.ink4),
          );
    if (fit == BoxFit.contain) {
      img = ColorFiltered(
        colorFilter: const ColorFilter.mode(AppColors.bg, BlendMode.multiply),
        child: img,
      );
    }
    return img;
  }

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
                    child: _buildProductImage(product),
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
            Expanded(
              child: Padding(
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
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (product.averageRating != null &&
                            product.reviewsCount != null &&
                            product.reviewsCount! > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFAB500)),
                                const SizedBox(width: 3),
                                Text(
                                  product.averageRating!.toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.ink1),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '(${product.reviewsCount})',
                                  style: const TextStyle(fontSize: 10, color: AppColors.ink3),
                                ),
                              ],
                            ),
                          ),
                        if (product.inStock &&
                            product.productType != 'variable' &&
                            product.stockQuantity != null &&
                            product.stockQuantity! > 0 &&
                            product.stockQuantity! <= 5)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              context.tr('تبقّى ${product.stockQuantity} فقط', 'Only ${product.stockQuantity} left'),
                              style: const TextStyle(
                                fontSize: 10.5, fontWeight: FontWeight.w700,
                                color: Color(0xFFB85A3A)),
                            ),
                          ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
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
                          ],
                        ),
                        if (product.fulfilledByBaahy)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE849),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.bolt_rounded, size: 10, color: Color(0xFF1A1A1A)),
                                  const SizedBox(width: 2),
                                  Text(
                                    context.tr('إكسبرس', 'Express'),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
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
