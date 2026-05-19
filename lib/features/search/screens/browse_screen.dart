import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/product.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/utils/l10n.dart';
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
  int? _activeSubId;

  @override
  void didUpdateWidget(_RightContent old) {
    super.didUpdateWidget(old);
    if (old.categoryId != widget.categoryId) {
      _activeSubId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final subcats = widget.category.children;
    final fetchId = _activeSubId ?? widget.categoryId;
    final productsAsync = ref.watch(_categoryProductsProvider(fetchId));

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (_, __) => Center(child: Text(context.s.loadError, style: const TextStyle(color: AppColors.ink2))),
      data: (products) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Subcategory image tiles — 3-column grid
          if (subcats.isNotEmpty) ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.0,
              ),
              itemCount: subcats.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
                  return _SubTile(
                    label: context.s.all,
                    image: null,
                    selected: _activeSubId == null,
                    onTap: () => setState(() => _activeSubId = null),
                  );
                }
                final sub = subcats[i - 1];
                return _SubTile(
                  label: isAr ? sub.nameAr : sub.name,
                  image: sub.image,
                  selected: _activeSubId == sub.id,
                  onTap: () => setState(() => _activeSubId = sub.id),
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

class _SubTile extends StatelessWidget {
  final String label;
  final String? image;
  final bool selected;
  final VoidCallback onTap;
  const _SubTile({required this.label, required this.image, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image or color
              if (image != null)
                CachedNetworkImage(
                  imageUrl: image!, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: AppColors.primary.withValues(alpha: 0.15)),
                )
              else
                Container(color: AppColors.primary.withValues(alpha: 0.15)),
              // Dark overlay
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
              // Label at bottom
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
              // Selected teal border highlight
              if (selected)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary, width: 2.5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
