import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/product.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/product_card.dart';

final _vendorDetailProvider = FutureProvider.autoDispose.family<Vendor, int>((ref, id) async {
  final res = await ApiClient.instance.dio.get('/vendors/$id');
  return Vendor.fromJson(res.data['data']);
});

final _vendorProductsProvider = FutureProvider.autoDispose.family<List<Product>, int>((ref, id) async {
  final res = await ApiClient.instance.dio.get('/products',
    queryParameters: {'vendor_id': id, 'per_page': 20, 'has_image': 1});
  return (res.data['data']['data'] as List?)
      ?.map((p) => Product.fromJson(p)).toList() ?? [];
});

class VendorStoreScreen extends ConsumerWidget {
  final int vendorId;
  const VendorStoreScreen({required this.vendorId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorAsync = ref.watch(_vendorDetailProvider(vendorId));
    final productsAsync = ref.watch(_vendorProductsProvider(vendorId));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            title: vendorAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => Text(context.s.storeLabel, style: const TextStyle(color: Colors.white)),
              data: (v) => Text(
                context.isAr && v.storeNameAr.isNotEmpty ? v.storeNameAr : v.storeName,
                style: const TextStyle(color: Colors.white, fontFamily: 'Cairo',
                  fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ),

          // Vendor header
          SliverToBoxAdapter(
            child: vendorAsync.when(
              loading: () => const SizedBox(height: 80,
                child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
              error: (_, __) => const SizedBox.shrink(),
              data: (vendor) => Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: vendor.logo != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: vendor.logo!, fit: BoxFit.cover))
                        : const Icon(Icons.store_outlined, size: 30, color: AppColors.ink2),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vendor.storeNameAr.isNotEmpty ? vendor.storeNameAr : vendor.storeName,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      if (vendor.city != null && vendor.city!.isNotEmpty)
                        Text(vendor.city!,
                          style: const TextStyle(fontSize: 13, color: AppColors.ink3)),
                    ],
                  )),
                ]),
              ),
            ),
          ),

          // Section header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(context.s.storeProducts,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),

          // Products grid
          productsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: SizedBox(height: 200,
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)))),
            error: (_, __) => SliverToBoxAdapter(
              child: Center(child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(context.s.loadProductsFailed, style: const TextStyle(color: AppColors.ink3))))),
            data: (products) => products.isEmpty
                ? SliverToBoxAdapter(
                    child: Center(child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(context.s.noProductsNow, style: const TextStyle(color: AppColors.ink3)))))
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => ProductCard(product: products[i]),
                        childCount: products.length,
                      ),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 344,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
