import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/product.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../shared/theme/app_theme.dart';

const _kCols = 3;
const _kGap = 10.0;

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

class BrowseScreen extends ConsumerStatefulWidget {
  final int? deepCategoryId;
  const BrowseScreen({super.key, this.deepCategoryId});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  int? _activeCategoryId;
  bool _deepLinked = false;
  final _scrollCtrl = ScrollController();
  final _subcatKey = GlobalKey();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(BrowseScreen old) {
    super.didUpdateWidget(old);
    if (widget.deepCategoryId != old.deepCategoryId &&
        widget.deepCategoryId != null) {
      _deepLinked = false;
      _activeCategoryId = null;
    }
  }

  void _selectCategory(int id, bool wasActive) {
    setState(() => _activeCategoryId = wasActive ? null : id);
    // No auto-scroll — the selected row stays in place, subcategory panel
    // expands below it and pushes down everything else.
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider);
    final categoriesAsync = ref.watch(_browseCategoriesProvider);
    final categories = categoriesAsync.valueOrNull?.isNotEmpty == true
        ? categoriesAsync.valueOrNull!
        : home.categories;

    if (categories.isNotEmpty && !_deepLinked && widget.deepCategoryId != null) {
      _deepLinked = true;
      final targetId = widget.deepCategoryId!;
      final isRoot = categories.any((c) => c.id == targetId);
      if (isRoot) {
        _activeCategoryId = targetId;
      } else {
        for (final root in categories) {
          if (root.children.any((child) => child.id == targetId)) {
            _activeCategoryId = root.id;
            break;
          }
        }
        _activeCategoryId ??= categories.first.id;
      }
    }

    final activeIdx = _activeCategoryId == null
        ? -1
        : categories.indexWhere((c) => c.id == _activeCategoryId);
    final activeRow = activeIdx == -1 ? -1 : activeIdx ~/ _kCols;
    final rowCount = (categories.length / _kCols).ceil();

    final activeCategory = activeIdx == -1 ? null : categories[activeIdx];

    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.col.bg,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            // ── Search bar ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: GestureDetector(
                onTap: () => safePush(context, '/search'),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? context.col.surfaceSoft : context.col.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.col.borderStrong, width: 1.0),
                  ),
                  child: Row(children: [
                    Icon(Icons.search, size: 17, color: context.col.ink1),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(context.s.searchHint,
                          style: TextStyle(
                              color: context.col.ink1, fontSize: 13)),
                    ),
                    GestureDetector(
                      onTap: () => safePush(context, '/search/camera'),
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.camera_alt_outlined,
                            size: 17, color: context.col.ink1),
                      ),
                    ),
                  ]),
                ),
              ),
            ),

            // ── "التصنيفات" header ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text(
                  isAr ? 'التصنيفات' : 'Categories',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.col.ink0,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ),

            if (categories.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.teal),
                ),
              )
            else
              // ── Category rows with inline subcategory panel ─────────────
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, rowIdx) {
                      final start = rowIdx * _kCols;
                      final end =
                          min(start + _kCols, categories.length);
                      final rowCats = categories.sublist(start, end);
                      final isActiveRow = rowIdx == activeRow;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Row of category cards ──────────────────────
                          // Selected card gets flex:2 (2× wider → 2× taller via AspectRatio)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (int j = 0; j < _kCols; j++) ...[
                                if (j > 0) const SizedBox(width: _kGap),
                                Expanded(
                                  flex: (j < rowCats.length &&
                                          rowCats[j].id == _activeCategoryId)
                                      ? 4
                                      : 3,
                                  child: j < rowCats.length
                                      ? _CategoryCard(
                                          category: rowCats[j],
                                          label: isAr
                                              ? rowCats[j].nameAr
                                              : rowCats[j].name,
                                          isDark: isDark,
                                          onTap: () => _selectCategory(
                                            rowCats[j].id,
                                            rowCats[j].id ==
                                                _activeCategoryId,
                                          ),
                                        )
                                      : const SizedBox(),
                                ),
                              ],
                            ],
                          ),

                          // ── Subcategory panel (injected after active row) ──
                          if (isActiveRow &&
                              activeCategory != null &&
                              activeCategory.children.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _SubcategoryList(
                              key: _subcatKey,
                              category: activeCategory,
                              isAr: isAr,
                              isDark: isDark,
                            ),
                          ],

                          // Row gap (space before next row)
                          const SizedBox(height: 10),
                        ],
                      );
                    },
                    childCount: rowCount,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

// ── Category card ─────────────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final Category category;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.card);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Square image — AspectRatio ensures 1:1; flex in parent row drives the size
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1A1A1A)
                    : const Color(0xFFF5F5F5),
                borderRadius: radius,
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: category.image != null
                    ? CachedNetworkImage(
                        imageUrl: category.image!,
                        fit: BoxFit.cover,
                        memCacheWidth: 320,
                        errorWidget: (_, __, ___) => Icon(
                          Icons.category_outlined,
                          size: 32,
                          color: context.col.ink3,
                        ),
                      )
                    : Icon(
                        Icons.category_outlined,
                        size: 32,
                        color: context.col.ink3,
                      ),
              ),
            ),
          ),
          // Label — same style regardless of selection state
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: context.col.ink0,
                fontFamily: 'Cairo',
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Subcategory list ──────────────────────────────────────────────────────────

class _SubcategoryList extends StatelessWidget {
  final Category category;
  final bool isAr;
  final bool isDark;

  const _SubcategoryList({
    super.key,
    required this.category,
    required this.isAr,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final subcats = category.children;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? context.col.surfaceSoft : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: List.generate(subcats.length, (i) {
            final sub = subcats[i];
            final name = isAr ? sub.nameAr : sub.name;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => safePush(
                      context,
                      '/search/results?q=&category=${sub.id}',
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      child: Row(
                        // RTL: first child → right, last child → left.
                        // text (right) then image (left) matches design.
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              textAlign: isAr
                                  ? TextAlign.right
                                  : TextAlign.left,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.col.ink0,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: sub.image != null
                                ? CachedNetworkImage(
                                    imageUrl: sub.image!,
                                    fit: BoxFit.contain,
                                    memCacheWidth: 124,
                                    errorWidget: (_, __, ___) => Icon(
                                      Icons.category_outlined,
                                      size: 28,
                                      color: context.col.ink3,
                                    ),
                                  )
                                : Icon(
                                    Icons.category_outlined,
                                    size: 28,
                                    color: context.col.ink3,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (i < subcats.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: context.col.border,
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
