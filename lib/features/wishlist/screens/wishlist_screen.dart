import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/providers/wishlist_provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/product.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';

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
          title: const Text('المفضلة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
          backgroundColor: Colors.white, elevation: 0,
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
                style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('اضغط على القلب لحفظ المنتج للوقت لاحق.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: AppColors.ink2)),
              const SizedBox(height: 20),
              AppButton(label: 'تسجيل الدخول', width: 200,
                onTap: () => context.push('/signin')),
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
        title: Text('المفضلة (${products.length})',
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      ),
      body: products.isEmpty
          ? RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => ref.read(wishlistProductsProvider.notifier).fetch(),
              child: ListView(children: const [
                SizedBox(height: 100),
                Center(child: Column(children: [
                  Icon(Icons.favorite_outline, size: 72, color: AppColors.ink4),
                  SizedBox(height: 12),
                  Text('لا توجد منتجات في المفضلة',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: AppColors.ink2)),
                ])),
              ]),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => ref.read(wishlistProductsProvider.notifier).fetch(),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _WishlistCard(product: products[i]),
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
    final name = context.isAr ? product.nameAr : product.name;
    final vendor = product.vendor;

    return GestureDetector(
      onTap: () => context.push('/product/${product.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.shadowCard,
        ),
        child: Row(children: [
          // Product image
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 74, height: 74,
              child: product.firstImage != null
                  ? CachedNetworkImage(imageUrl: product.firstImage!, fit: BoxFit.cover)
                  : Container(color: AppColors.surfaceSoft,
                      child: const Icon(Icons.image_outlined, color: AppColors.ink4)),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3)),
                if (vendor != null) ...[
                  const SizedBox(height: 2),
                  Text(context.isAr ? vendor.storeNameAr : vendor.storeName,
                    style: const TextStyle(fontSize: 11, color: AppColors.ink2)),
                ],
                const SizedBox(height: 6),
                Text('${product.displayPrice.toStringAsFixed(0)} د.ل',
                  style: const TextStyle(fontFamily: 'PlusJakartaSans',
                    fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ),

          // Actions
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => ref.read(wishlistProvider.notifier).toggle(product.id),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 18, color: AppColors.ink3),
                ),
              ),
              const SizedBox(height: 12),
              if (product.inStock && product.productType != 'variable')
                GestureDetector(
                  onTap: () => ref.read(cartProvider.notifier).add(product),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.shopping_cart_outlined, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      const Text('أضف',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                          color: Colors.white)),
                    ]),
                  ),
                ),
              if (!product.inStock)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('نفد',
                    style: TextStyle(fontSize: 11, color: AppColors.ink3)),
                ),
            ],
          ),
        ]),
      ),
    );
  }
}

