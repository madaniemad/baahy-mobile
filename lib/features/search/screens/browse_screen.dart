import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/product.dart';
import '../../../core/providers/home_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/product_card.dart';

final _categoryProductsProvider = FutureProvider.family<List<Product>, int>((ref, catId) async {
  final res = await ApiClient.instance.dio.get('/products',
    queryParameters: {'category_id': catId, 'per_page': 12, 'sort': 'popular'});
  return (res.data['data']['data'] as List?)
      ?.map((p) => Product.fromJson(p)).toList() ?? [];
});

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  int? _activeCategoryId;

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider);
    final categories = home.categories;

    if (categories.isNotEmpty && _activeCategoryId == null) {
      _activeCategoryId = categories.first.id;
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('الأقسام',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: true,
      ),
      body: categories.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left rail
                Container(
                  width: 88,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceSoft,
                    border: Border(right: BorderSide(color: AppColors.border)),
                  ),
                  child: ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (_, i) {
                      final cat = categories[i];
                      final isActive = cat.id == _activeCategoryId;
                      return GestureDetector(
                        onTap: () => setState(() => _activeCategoryId = cat.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.white : Colors.transparent,
                            border: Border(
                              left: BorderSide(
                                color: isActive ? AppColors.primary : Colors.transparent,
                                width: 3),
                            ),
                          ),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 40, height: 40,
                                  child: cat.image != null
                                      ? CachedNetworkImage(
                                          imageUrl: cat.image!, fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) =>
                                            Container(color: AppColors.primary.withValues(alpha: 0.1),
                                              child: const Icon(Icons.grid_view_rounded,
                                                color: AppColors.primary, size: 20)),
                                        )
                                      : Container(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          child: const Icon(Icons.grid_view_rounded,
                                            color: AppColors.primary, size: 20)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                Localizations.localeOf(context).languageCode == 'ar'
                                    ? cat.nameAr : cat.name,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                  color: isActive ? AppColors.ink0 : AppColors.ink2,
                                  height: 1.2),
                                textAlign: TextAlign.center,
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Right content
                Expanded(
                  child: _activeCategoryId == null
                      ? const SizedBox.shrink()
                      : _RightContent(categoryId: _activeCategoryId!),
                ),
              ],
            ),
    );
  }
}

class _RightContent extends ConsumerWidget {
  final int categoryId;
  const _RightContent({required this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(_categoryProductsProvider(categoryId));
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (_, __) => const Center(child: Text('تعذر التحميل', style: TextStyle(color: AppColors.ink2))),
      data: (products) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // "TOP PICKS" heading
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('الأكثر شعبية',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: AppColors.ink2, letterSpacing: 0.5)),
          ),

          if (products.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('لا توجد منتجات', style: TextStyle(color: AppColors.ink2)),
            ))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.72,
              ),
              itemCount: products.length,
              itemBuilder: (_, i) => ProductCard(product: products[i]),
            ),
        ],
      ),
    );
  }
}
