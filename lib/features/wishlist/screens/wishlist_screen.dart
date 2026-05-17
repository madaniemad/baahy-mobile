import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/wishlist_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/product_card.dart';
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
              const Icon(Icons.favorite_outline, size: 72, color: AppColors.ink4),
              const SizedBox(height: 12),
              const Text('سجّل دخولك لعرض المفضلة',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: AppColors.ink2)),
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
                SizedBox(height: 120),
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
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.68,
                ),
                itemCount: products.length,
                itemBuilder: (_, i) => ProductCard(product: products[i]),
              ),
            ),
    );
  }
}
