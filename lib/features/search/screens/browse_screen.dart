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
import '../../../shared/widgets/mic_button.dart';

// Standalone categories loader — used when homeProvider hasn't populated categories yet
final _browseCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  try {
    final res = await ApiClient.instance.dio.get('/categories');
    final list = (res.data?['data'] as List?)
        ?.map((c) => Category.fromJson(c as Map<String, dynamic>)).toList() ?? [];
    return list;
  } catch (_) {
    return [];
  }
});

// Key: "parentId" or "parentId,sub1,sub2,..."
final _categoryProductsProvider = FutureProvider.family<List<Product>, String>((ref, key) async {
  final ids = key.split(',').map(int.parse).toList();
  if (ids.length <= 1) {
    final res = await ApiClient.instance.dio.get('/products',
      queryParameters: {'category_id': ids[0], 'per_page': 50, 'sort': 'popular'});
    final list = (res.data['data']['data'] as List?)
        ?.map((p) => Product.fromJson(p)).toList() ?? [];
    list.shuffle(Random(ids[0]));
    return list;
  }
  // Fetch from each subcategory in parallel for a true cross-category mix
  final subcatIds = ids.skip(1).toList();
  final perCat = (48 / subcatIds.length).ceil().clamp(4, 8);
  final futures = subcatIds.map((id) =>
    ApiClient.instance.dio.get('/products',
      queryParameters: {'category_id': id, 'per_page': perCat, 'sort': 'popular'})
    .then((res) => (res.data['data']['data'] as List?)
        ?.map((p) => Product.fromJson(p)).toList() ?? <Product>[])
    .catchError((_) => <Product>[])
  ).toList();
  final results = await Future.wait(futures);
  final combined = results.expand((l) => l).toList();
  combined.shuffle(Random(ids[0]));
  return combined;
});

class BrowseScreen extends ConsumerStatefulWidget {
  final int? deepCategoryId;
  const BrowseScreen({super.key, this.deepCategoryId});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  int? _activeCategoryId;
  bool _deepLinked = false;

  @override
  void didUpdateWidget(BrowseScreen old) {
    super.didUpdateWidget(old);
    if (widget.deepCategoryId != old.deepCategoryId && widget.deepCategoryId != null) {
      _deepLinked = false;
      _activeCategoryId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider);
    // Fall back to a direct /categories fetch if home provider hasn't loaded them yet
    final categoriesAsync = ref.watch(_browseCategoriesProvider);
    final categories = home.categories.isNotEmpty
        ? home.categories
        : (categoriesAsync.valueOrNull ?? []);

    if (categories.isNotEmpty && _activeCategoryId == null) {
      if (!_deepLinked && widget.deepCategoryId != null) {
        _deepLinked = true;
        final targetId = widget.deepCategoryId!;
        // Check if it's a root category
        final isRoot = categories.any((c) => c.id == targetId);
        if (isRoot) {
          _activeCategoryId = targetId;
        } else {
          // Find the root that has this as a child
          for (final root in categories) {
            if (root.children.any((child) => child.id == targetId)) {
              _activeCategoryId = root.id;
              break;
            }
          }
          _activeCategoryId ??= categories.first.id;
        }
      } else if (_activeCategoryId == null) {
        _activeCategoryId = categories.first.id;
      }
    }

    final activeCategory = categories.isEmpty ? null
        : categories.firstWhere((c) => c.id == _activeCategoryId,
            orElse: () => categories.first);

    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.col.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Full-width search bar ──────────────────────────────────────
            GestureDetector(
              onTap: () => safePush(context, '/search'),
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? context.col.surfaceSoft : context.col.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: context.col.border),
                  boxShadow: isDark ? null : AppShadows.shadowCard,
                ),
                child: Row(children: [
                  Icon(Icons.search, size: 17, color: context.col.ink3),
                  const SizedBox(width: 8),
                  Expanded(child: Text(context.s.searchHint,
                    style: TextStyle(color: context.col.ink3, fontSize: 13))),
                  const MicButton(size: 17),
                ]),
              ),
            ),

            // ── Rail + content ─────────────────────────────────────────────
            Expanded(
              child: categories.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left rail
                        Container(
                          width: 108,
                          decoration: BoxDecoration(
                            color: context.col.surface,
                            border: Border(right: BorderSide(color: context.col.border, width: 1)),
                          ),
                          child: ListView.builder(
                            itemCount: categories.length,
                            itemBuilder: (_, i) {
                              final cat = categories[i];
                              final isActive = cat.id == _activeCategoryId;
                              return GestureDetector(
                                onTap: () => setState(() => _activeCategoryId = cat.id),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? (isDark ? AppColors.primary.withValues(alpha: 0.12) : const Color(0xFFF0FFFE))
                                        : context.col.surface,
                                    border: isAr
                                      ? Border(left: BorderSide(
                                          color: isActive ? AppColors.primary : Colors.transparent,
                                          width: 3))
                                      : Border(right: BorderSide(
                                          color: isActive ? AppColors.primary : Colors.transparent,
                                          width: 3)),
                                  ),
                                  child: Text(
                                    isAr ? cat.nameAr : cat.name,
                                    textAlign: TextAlign.start,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                      color: isActive ? AppColors.primary : context.col.ink1,
                                      fontFamily: 'Cairo',
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // Right panel
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // "الأقسام" title
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                                child: Text(
                                  context.s.categories,
                                  textAlign: TextAlign.start,
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
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

    Widget _subcatGrid() => GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 0.88),
      itemCount: subcats.length,
      itemBuilder: (_, i) {
        final sub = subcats[i];
        return _SubTile(
          label: isAr ? sub.nameAr : sub.name,
          image: sub.image,
          onTap: () => safePush(context, '/search/results?q=&category=${sub.id}'),
        );
      },
    );

    return productsAsync.when(
      loading: () => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (subcats.isNotEmpty) ...[_subcatGrid(), const SizedBox(height: 16)],
          LayoutBuilder(builder: (_, box) {
            const srcW = 165.0;
            const srcH = 335.0; // natural card height at srcW
            final colW = (box.maxWidth - 10) / 2;
            final cellH = srcH * (colW / srcW);
            return GridView.builder(
              shrinkWrap: true, padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10,
                mainAxisExtent: cellH.ceilToDouble()),
              itemCount: 6,
              itemBuilder: (_, __) => const ProductCardSkeleton(),
            );
          }),
        ],
      ),
      error: (_, __) => Center(child: Text(context.s.loadError, style: TextStyle(color: context.col.ink2))),
      data: (products) => ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        children: [
          // Subcategory tiles
          if (subcats.isNotEmpty) ...[
            _subcatGrid(),
            const SizedBox(height: 20),
            Row(children: [
              Container(width: 3, height: 16, decoration: BoxDecoration(
                color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text(context.s.sneakPeek,
                style: TextStyle(fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800, fontSize: 14, color: context.col.ink0)),
            ]),
            const SizedBox(height: 10),
          ],

          if (products.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(context.s.noProducts, style: TextStyle(color: context.col.ink2)),
            ))
          else
            LayoutBuilder(builder: (_, box) {
              const srcW = 165.0;
              const srcH = 335.0;
              final colW = (box.maxWidth - 10) / 2;
              final cellH = srcH * (colW / srcW);
              return GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: cellH.ceilToDouble(),
                ),
                itemCount: products.length,
                itemBuilder: (_, i) => FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: srcW,
                    child: ProductCard(product: products[i], width: srcW),
                  ),
                ),
              );
            }),
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
              borderRadius: BorderRadius.circular(6),
              child: image != null
                  ? CachedNetworkImage(
                      imageUrl: image!, fit: BoxFit.cover,
                      memCacheWidth: 400,
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
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: context.col.ink0,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}
