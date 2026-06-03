import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/product.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/product_card.dart';

// Key: "parentId" or "parentId,sub1,sub2,..."
final _categoryProductsProvider = FutureProvider.family<List<Product>, String>((ref, key) async {
  final ids = key.split(',').map(int.parse).toList();
  if (ids.length <= 1) {
    final res = await ApiClient.instance.dio.get('/products',
      queryParameters: {'category_id': ids[0], 'per_page': 50, 'sort': 'popular'});
    final list = (res.data['data']['data'] as List?)
        ?.map((p) => Product.fromJson(p)).toList() ?? [];
    list.shuffle(Random());
    return list;
  }
  // Fetch from each subcategory in parallel for a true cross-category mix
  final subcatIds = ids.skip(1).toList();
  final perCat = (48 / subcatIds.length).ceil().clamp(4, 12);
  final futures = subcatIds.map((id) =>
    ApiClient.instance.dio.get('/products',
      queryParameters: {'category_id': id, 'per_page': perCat, 'sort': 'popular'})
    .then((res) => (res.data['data']['data'] as List?)
        ?.map((p) => Product.fromJson(p)).toList() ?? <Product>[])
    .catchError((_) => <Product>[])
  ).toList();
  final results = await Future.wait(futures);
  final combined = results.expand((l) => l).toList();
  combined.shuffle(Random());
  return combined;
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

    final activeCategory = categories.isEmpty ? null
        : categories.firstWhere((c) => c.id == _activeCategoryId,
            orElse: () => categories.first);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(context.s.categories,
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: true,
      ),
      body: categories.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left rail
                Container(
                  width: 94,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceSoft,
                    border: Border(right: BorderSide(color: AppColors.border)),
                  ),
                  child: ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (_, i) {
                      final cat = categories[i];
                      final isActive = cat.id == _activeCategoryId;
                      final isAr = Localizations.localeOf(context).languageCode == 'ar';
                      return GestureDetector(
                        onTap: () => setState(() => _activeCategoryId = cat.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 5),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.white : Colors.transparent,
                            border: isAr
                              ? Border(left: BorderSide(
                                  color: isActive ? AppColors.primary : Colors.transparent,
                                  width: 3))
                              : Border(right: BorderSide(
                                  color: isActive ? AppColors.primary : Colors.transparent,
                                  width: 3)),
                          ),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: AspectRatio(
                                  aspectRatio: 1.0,
                                  child: cat.image != null
                                      ? CachedNetworkImage(
                                          imageUrl: cat.image!, fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) =>
                                            Container(color: AppColors.primary.withValues(alpha: 0.1),
                                              child: const Icon(Icons.grid_view_rounded,
                                                color: AppColors.primary, size: 24)),
                                        )
                                      : Container(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          child: const Icon(Icons.grid_view_rounded,
                                            color: AppColors.primary, size: 24)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isAr ? cat.nameAr : cat.name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: isActive ? AppColors.primary : AppColors.ink2,
                                  fontFamily: 'Cairo',
                                ),
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
                  child: _activeCategoryId == null || activeCategory == null
                      ? const SizedBox.shrink()
                      : _RightContent(
                          categoryId: _activeCategoryId!,
                          category: activeCategory,
                        ),
                ),
              ],
            ),
    );
  }
}

class _RightContent extends ConsumerStatefulWidget {
  final int categoryId;
  final Category category;
  const _RightContent({required this.categoryId, required this.category});

  @override
  ConsumerState<_RightContent> createState() => _RightContentState();
}

class _RightContentState extends ConsumerState<_RightContent> {
  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final subcats = widget.category.children;
    // Fetch from all subcategories for a true cross-category mix
    final key = subcats.isNotEmpty
        ? '${widget.categoryId},${subcats.map((s) => s.id).join(',')}'
        : '${widget.categoryId}';
    final productsAsync = ref.watch(_categoryProductsProvider(key));

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (_, __) => Center(child: Text(context.s.loadError, style: const TextStyle(color: AppColors.ink2))),
      data: (products) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Subcategory tiles — tap navigates to search results
          if (subcats.isNotEmpty) ...[
            GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.82,
              ),
              itemCount: subcats.length,
              itemBuilder: (_, i) {
                final sub = subcats[i];
                return _SubTile(
                  label: isAr ? sub.nameAr : sub.name,
                  image: sub.image,
                  onTap: () => safePush(context, '/search/results?q=&category=${sub.id}'),
                );
              },
            ),
            const SizedBox(height: 20),
            Row(children: [
              Container(width: 3, height: 16, decoration: BoxDecoration(
                color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text(context.s.sneakPeek,
                style: const TextStyle(fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.ink0)),
            ]),
            const SizedBox(height: 10),
          ],

          if (products.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(context.s.noProducts, style: const TextStyle(color: AppColors.ink2)),
            ))
          else
            GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 285,
              ),
              itemCount: products.length,
              itemBuilder: (_, i) => Align(
                alignment: Alignment.topCenter,
                child: ProductCard(product: products[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _SubTile extends StatelessWidget {
  final String label;
  final String? image;
  final VoidCallback onTap;
  const _SubTile({required this.label, required this.image, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: image != null
                  ? CachedNetworkImage(
                      imageUrl: image!, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          Container(color: AppColors.primary.withValues(alpha: 0.12)),
                    )
                  : Container(color: AppColors.primary.withValues(alpha: 0.12)),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.ink0,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}
