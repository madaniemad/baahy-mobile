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

final _categoryProductsProvider = FutureProvider.family<List<Product>, int>((ref, catId) async {
  final res = await ApiClient.instance.dio.get('/products',
    queryParameters: {'category_id': catId, 'per_page': 20, 'sort': 'popular'});
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
                      return GestureDetector(
                        onTap: () => setState(() => _activeCategoryId = cat.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
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
                                borderRadius: BorderRadius.circular(12),
                                child: AspectRatio(
                                  aspectRatio: 1.0,
                                  child: cat.image != null
                                      ? CachedNetworkImage(
                                          imageUrl: cat.image!, fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) =>
                                            Container(color: AppColors.primary.withValues(alpha: 0.1),
                                              child: const Icon(Icons.grid_view_rounded,
                                                color: AppColors.primary, size: 28)),
                                        )
                                      : Container(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          child: const Icon(Icons.grid_view_rounded,
                                            color: AppColors.primary, size: 28)),
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
    // Always show main category's popular products — subcats navigate away
    final productsAsync = ref.watch(_categoryProductsProvider(widget.categoryId));

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
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.0,
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
            const SizedBox(height: 12),
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
                mainAxisExtent: 290,
              ),
              itemCount: products.length,
              itemBuilder: (_, i) => ProductCard(product: products[i]),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image != null)
              CachedNetworkImage(
                imageUrl: image!, fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(color: AppColors.primary.withValues(alpha: 0.15)),
              )
            else
              Container(color: AppColors.primary.withValues(alpha: 0.15)),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 4)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
