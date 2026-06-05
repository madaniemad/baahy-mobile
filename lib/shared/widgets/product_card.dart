import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/models/product.dart';
import '../../core/providers/wishlist_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/format.dart';
import '../../core/utils/l10n.dart';
import '../../core/utils/navigation.dart';
import '../theme/app_theme.dart';

class ProductCard extends ConsumerWidget {
  final Product product;
  final double? width;
  const ProductCard({required this.product, this.width, super.key});

  // IDs of clothing parent categories + all known children — use object-cover for these.
  // Women Clothing(2)+subs(3-13), Men Clothing(26)+subs(27-34),
  // Girls Clothing(48), Boys Clothing(51), Baby Fashion(53)+subs(54,55)
  static const _clothingIds = {
    2,  3,  4,  5,  6,  7,  8,  9,  10, 11, 12, 13,
    26, 27, 28, 29, 30, 31, 32, 33, 34,
    48, 51,
    53, 54, 55,
  };

  static BoxFit _imageFit(Product p) {
    final cat = p.category;
    if (cat == null) return BoxFit.contain;
    if (_clothingIds.contains(cat.id)) return BoxFit.cover;
    if (cat.parentId != null && _clothingIds.contains(cat.parentId)) return BoxFit.cover;
    if (cat.parent != null && _clothingIds.contains(cat.parent!.id)) return BoxFit.cover;
    // Name-based fallback: mirrors web logic — any Arabic clothing category name
    if (cat.nameAr.contains('ملاب')) return BoxFit.cover;
    if (cat.parent?.nameAr.contains('ملاب') == true) return BoxFit.cover;
    return BoxFit.contain;
  }

  static Widget _buildProductImage(Product p, Color bgColor) {
    final fit = _imageFit(p);
    Widget img = p.firstImage != null
        ? CachedNetworkImage(
            imageUrl: p.firstImage!,
            fit: fit,
            memCacheWidth: 400,
            memCacheHeight: 500,
            placeholder: (_, __) => Container(color: bgColor),
            errorWidget: (_, __, ___) => Container(
              color: bgColor,
              child: Icon(Icons.image_not_supported_outlined, color: bgColor, size: 28),
            ),
          )
        : Container(
            color: bgColor,
            child: Icon(Icons.image_outlined, color: bgColor),
          );
    img = ColorFiltered(
      colorFilter: ColorFilter.mode(bgColor, BlendMode.multiply),
      child: img,
    );
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
          color: context.col.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: context.col.border),
          boxShadow: AppShadows.shadowCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
                  child: Container(
                    color: context.col.cardImageBg,
                    child: AspectRatio(
                      aspectRatio: 0.8,
                      child: _buildProductImage(product, context.col.cardImageBg),
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
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 34,
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
                    ),
                  ),
                  const SizedBox(height: 5),
                  _StarRating(
                    rating: product.averageRating,
                    count: product.reviewsCount ?? 0,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '${fmtPrice(product.displayPrice)} ${context.s.lydUnit}',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.col.ink0,
                          height: 1.0,
                        ),
                      ),
                      if (product.hasDiscount) ...[
                        const SizedBox(width: 5),
                        Text(
                          fmtPrice(product.price),
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            color: AppColors.danger,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: AppColors.danger,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (product.fulfilledByBaahy) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF500),
                        border: Border.all(color: const Color(0xFFFFF500), width: 0.8),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.bolt_rounded, size: 9, color: Colors.black87),
                          const SizedBox(width: 2),
                          Text(
                            context.tr('اكسبرس', 'Express'),
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else
                    const SizedBox(height: 22),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  final double? rating;
  final int count;
  const _StarRating({this.rating, required this.count});

  @override
  Widget build(BuildContext context) {
    final filled = rating != null ? rating!.round().clamp(0, 5) : 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= 5; i++)
          Icon(
            Icons.star_rounded,
            size: 13,
            color: i <= filled ? const Color(0xFFFAB500) : const Color(0xFFE5E7EB),
          ),
        if (count > 0 && rating != null) ...[
          const SizedBox(width: 3),
          Text(
            rating!.toStringAsFixed(1),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.col.ink1, height: 1.0),
          ),
          const SizedBox(width: 2),
          Text(
            '($count)',
            style: TextStyle(fontSize: 10, color: context.col.ink3, height: 1.0),
          ),
        ],
      ],
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
          color: inWishlist ? AppColors.danger : context.col.ink3,
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
    final bg = context.col.surfaceSoft;
    final surface = context.col.surface;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(aspectRatio: 0.8, child: Container(color: bg)),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(bg, height: 12, width: double.infinity),
                const SizedBox(height: 6),
                _shimmerBox(bg, height: 12, width: 80),
                const SizedBox(height: 8),
                _shimmerBox(bg, height: 14, width: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerBox(Color c, {required double height, required double width}) =>
      Container(height: height, width: width, decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(4),
      ));
}
