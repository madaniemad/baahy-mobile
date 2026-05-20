import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/product.dart';
import '../../../core/providers/home_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/product_card.dart';

class _AttrValue {
  final int id;
  final String value;
  final String valueAr;
  final String? colorHex;
  const _AttrValue({required this.id, required this.value, required this.valueAr, this.colorHex});
}

class _AttrType {
  final int id;
  final String name;
  final String nameAr;
  final String displayType;
  final List<_AttrValue> values;
  const _AttrType({required this.id, required this.name, required this.nameAr,
    required this.displayType, required this.values});
}

class _FilterOptions {
  final List<_AttrType> attrTypes;
  final List<String> brands;
  const _FilterOptions({this.attrTypes = const [], this.brands = const []});
}

// Scope key: category + brand drive dynamic re-fetching of available attributes
class _FilterScope {
  final int? categoryId;
  final String? brand;
  final Set<int> attrValueIds;
  const _FilterScope({this.categoryId, this.brand, this.attrValueIds = const {}});

  @override
  bool operator ==(Object other) =>
    other is _FilterScope &&
    other.categoryId == categoryId &&
    other.brand == brand &&
    _setEquals(other.attrValueIds, attrValueIds);

  @override
  int get hashCode => Object.hash(categoryId, brand, Object.hashAll(attrValueIds.toList()..sort()));

  static bool _setEquals(Set<int> a, Set<int> b) =>
    a.length == b.length && a.containsAll(b);
}

final _filterOptionsProvider = FutureProvider.family<_FilterOptions, _FilterScope>((_, scope) async {
  try {
    final params = <String, dynamic>{};
    if (scope.categoryId != null) params['category_id'] = scope.categoryId;
    if (scope.brand != null && scope.brand!.isNotEmpty) params['brand'] = scope.brand;
    final res = await ApiClient.instance.dio.get('/products/filter-options',
      queryParameters: params.isNotEmpty ? params : null);
    final data = res.data['data'];
    final types = (data['attribute_types'] as List? ?? []).map((t) => _AttrType(
      id: t['id'], name: t['name'] ?? '', nameAr: t['name_ar'] ?? '',
      displayType: t['display_type'] ?? 'button',
      values: (t['values'] as List? ?? []).map((v) => _AttrValue(
        id: v['id'], value: v['value'] ?? '', valueAr: v['value_ar'] ?? '',
        colorHex: v['color_hex'],
      )).toList(),
    )).toList();
    final brands = (data['brands'] as List? ?? []).map((b) => b.toString()).toList();
    return _FilterOptions(attrTypes: types, brands: brands);
  } catch (_) {
    return const _FilterOptions();
  }
});

final _sortOptions = [
  ('latest', 'الأحدث'),
  ('popular', 'الأكثر مبيعاً'),
  ('price_asc', 'الأرخص'),
  ('price_desc', 'الأغلى'),
];

class _FilterState {
  final double? minPrice;
  final double? maxPrice;
  final int? minRating;
  final bool inStockOnly;
  final bool featuredOnly;
  final int? categoryId;
  final String? categoryName;
  final Set<int> attributeValueIds;
  final String? brand;

  const _FilterState({
    this.minPrice,
    this.maxPrice,
    this.minRating,
    this.inStockOnly = false,
    this.featuredOnly = false,
    this.categoryId,
    this.categoryName,
    this.attributeValueIds = const {},
    this.brand,
  });

  bool get isActive =>
      minPrice != null || maxPrice != null || minRating != null ||
      inStockOnly || featuredOnly || categoryId != null ||
      attributeValueIds.isNotEmpty || (brand != null && brand!.isNotEmpty);

  _FilterState copyWith({
    Object? minPrice = _unset,
    Object? maxPrice = _unset,
    Object? minRating = _unset,
    bool? inStockOnly,
    bool? featuredOnly,
    Object? categoryId = _unset,
    Object? categoryName = _unset,
    Set<int>? attributeValueIds,
    Object? brand = _unset,
  }) => _FilterState(
    minPrice: identical(minPrice, _unset) ? this.minPrice : minPrice as double?,
    maxPrice: identical(maxPrice, _unset) ? this.maxPrice : maxPrice as double?,
    minRating: identical(minRating, _unset) ? this.minRating : minRating as int?,
    inStockOnly: inStockOnly ?? this.inStockOnly,
    featuredOnly: featuredOnly ?? this.featuredOnly,
    categoryId: identical(categoryId, _unset) ? this.categoryId : categoryId as int?,
    categoryName: identical(categoryName, _unset) ? this.categoryName : categoryName as String?,
    attributeValueIds: attributeValueIds ?? this.attributeValueIds,
    brand: identical(brand, _unset) ? this.brand : brand as String?,
  );

  static const _unset = Object();
}

class SearchResultsScreen extends ConsumerStatefulWidget {
  final String query;
  final int? categoryId;
  const SearchResultsScreen({required this.query, this.categoryId, super.key});

  @override
  ConsumerState<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  final _scrollCtrl = ScrollController();
  List<Product> _products = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  bool _hasMore = true;
  String _sort = 'latest';
  late _FilterState _filters;

  @override
  void initState() {
    super.initState();
    _filters = _FilterState(categoryId: widget.categoryId);
    _fetch(reset: true);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels > _scrollCtrl.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMore) _fetch();
    }
  }

  Future<void> _fetch({bool reset = false}) async {
    if (reset) {
      setState(() { _loading = true; _page = 1; _hasMore = true; _products = []; });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final res = await ApiClient.instance.dio.get('/products', queryParameters: {
        if (widget.query.isNotEmpty) 'search': widget.query,
        if (_filters.categoryId != null) 'category_id': _filters.categoryId
        else if (widget.categoryId != null) 'category_id': widget.categoryId,
        'sort': _sort,
        'page': _page,
        'per_page': 20,
        if (_filters.minPrice != null) 'min_price': _filters.minPrice,
        if (_filters.maxPrice != null) 'max_price': _filters.maxPrice,
        if (_filters.minRating != null) 'min_rating': _filters.minRating,
        if (_filters.inStockOnly) 'in_stock': 1,
        if (_filters.featuredOnly) 'featured': 1,
        if (_filters.brand != null && _filters.brand!.isNotEmpty) 'brand': _filters.brand,
        ..._filters.attributeValueIds.isNotEmpty
            ? {'attribute_value_ids[]': _filters.attributeValueIds.toList()} : {},
      });
      final data = res.data['data'];
      final newProducts = (data['data'] as List).map((p) => Product.fromJson(p)).toList();
      setState(() {
        _products = reset ? newProducts : [..._products, ...newProducts];
        _page++;
        _hasMore = data['current_page'] < data['last_page'];
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      setState(() { _loading = false; _loadingMore = false; });
    }
  }

  void _openFilters() async {
    final result = await showModalBottomSheet<_FilterState>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FilterSheet(initial: _filters, scopeCategoryId: widget.categoryId),
    );
    if (result != null && mounted) {
      setState(() => _filters = result);
      _fetch(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.query.isNotEmpty ? widget.query : 'المنتجات',
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: [
          // Filter icon with active indicator
          Stack(
            children: [
              IconButton(
                onPressed: _openFilters,
                icon: const Icon(Icons.tune_rounded, color: AppColors.ink0),
              ),
              if (_filters.isActive)
                Positioned(
                  top: 10, right: 10,
                  child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, color: AppColors.ink0),
            onSelected: (v) { _sort = v; _fetch(reset: true); },
            itemBuilder: (_) => _sortOptions.map((opt) =>
              PopupMenuItem(value: opt.$1, child: Text(opt.$2,
                style: TextStyle(fontWeight: _sort == opt.$1 ? FontWeight.w700 : FontWeight.normal))
            )).toList(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off, size: 64, color: AppColors.ink4),
                      const SizedBox(height: 12),
                      const Text('لا توجد نتائج',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: AppColors.ink2)),
                      if (_filters.isActive) ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () {
                            setState(() => _filters = const _FilterState());
                            _fetch(reset: true);
                          },
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          label: const Text('إزالة الفلاتر'),
                        ),
                      ],
                    ],
                  ),
                )
              : GridView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 348,
                  ),
                  itemCount: _products.length + (_loadingMore ? 2 : 0),
                  itemBuilder: (_, i) {
                    if (i >= _products.length) return const ProductCardSkeleton();
                    return ProductCard(product: _products[i]);
                  },
                ),
    );
  }
}

// ── Filter bottom sheet ───────────────────────────────────────────────────────

class _FilterSheet extends ConsumerStatefulWidget {
  final _FilterState initial;
  final int? scopeCategoryId;
  const _FilterSheet({required this.initial, this.scopeCategoryId});
  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  int? _rating;
  late bool _inStock;
  late bool _featured;
  int? _categoryId;
  String? _categoryName;
  late Set<int> _attrValueIds;
  String? _brand;
  bool _catExpanded = true;
  bool _priceExpanded = true;
  bool _ratingExpanded = false;
  bool _attrExpanded = true;
  bool _brandExpanded = false;
  final Set<int> _expandedCats = {};

  @override
  void initState() {
    super.initState();
    _minCtrl = TextEditingController(
      text: widget.initial.minPrice?.toStringAsFixed(0) ?? '');
    _maxCtrl = TextEditingController(
      text: widget.initial.maxPrice?.toStringAsFixed(0) ?? '');
    _rating = widget.initial.minRating;
    _inStock = widget.initial.inStockOnly;
    _featured = widget.initial.featuredOnly;
    _categoryId = widget.initial.categoryId;
    _categoryName = widget.initial.categoryName;
    _attrValueIds = Set.from(widget.initial.attributeValueIds);
    _brand = widget.initial.brand;
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final minPrice = double.tryParse(_minCtrl.text.trim());
    final maxPrice = double.tryParse(_maxCtrl.text.trim());
    Navigator.of(context).pop(_FilterState(
      minPrice: minPrice,
      maxPrice: maxPrice,
      minRating: _rating,
      inStockOnly: _inStock,
      featuredOnly: _featured,
      categoryId: _categoryId,
      categoryName: _categoryName,
      attributeValueIds: Set.from(_attrValueIds),
      brand: _brand?.trim().isEmpty == true ? null : _brand?.trim(),
    ));
  }

  void _reset() {
    setState(() {
      _minCtrl.clear();
      _maxCtrl.clear();
      _rating = null;
      _inStock = false;
      _featured = false;
      _categoryId = null;
      _categoryName = null;
      _attrValueIds = {};
      _brand = null;
    });
  }

  Widget _sectionHeader(String title, bool expanded, VoidCallback toggle) {
    return GestureDetector(
      onTap: toggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Text(title,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700,
              color: AppColors.ink1)),
          const Spacer(),
          Icon(expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
            color: AppColors.ink3, size: 20),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final allCategories = ref.watch(homeProvider).categories;

    // Compute scoped subcategories for the category filter section
    List<Category> scopedCats = [];
    if (widget.scopeCategoryId != null) {
      final topLevel = allCategories.where((c) => c.id == widget.scopeCategoryId).firstOrNull;
      if (topLevel != null) {
        scopedCats = topLevel.children;
      } else {
        for (final parent in allCategories) {
          final match = parent.children.where((c) => c.id == widget.scopeCategoryId).firstOrNull;
          if (match != null) {
            scopedCats = match.children;
            break;
          }
        }
      }
    } else {
      scopedCats = allCategories;
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              Row(children: [
                const Text('الفلاتر',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton(onPressed: _reset,
                  child: const Text('إعادة تعيين',
                    style: TextStyle(color: AppColors.ink2))),
              ]),
              const Divider(height: 1),
            ]),
          ),

          // Scrollable content
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              children: [

                // ── Category chips ─────────────────────────────────────
                if (scopedCats.isNotEmpty) ...[
                  _sectionHeader('القسم', _catExpanded,
                    () => setState(() => _catExpanded = !_catExpanded)),

                  if (_catExpanded) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _CatChip(
                          label: 'الكل',
                          selected: _categoryId == null || _categoryId == widget.scopeCategoryId,
                          onTap: () => setState(() { _categoryId = null; _categoryName = null; }),
                        ),
                        ...scopedCats.map((cat) => _CatChip(
                          label: isAr ? cat.nameAr : cat.name,
                          selected: _categoryId == cat.id ||
                              cat.children.any((c) => c.id == _categoryId),
                          onTap: () => setState(() {
                            _categoryId = cat.id;
                            _categoryName = isAr ? cat.nameAr : cat.name;
                          }),
                        )),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                  ],
                ],

                // ── Price ─────────────────────────────────────────────────
                _sectionHeader('نطاق السعر (د.ل)', _priceExpanded,
                  () => setState(() => _priceExpanded = !_priceExpanded)),

                if (_priceExpanded) ...[
                  Row(children: [
                    Expanded(child: _PriceField(controller: _minCtrl, hint: 'الحد الأدنى')),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('—', style: TextStyle(color: AppColors.ink3))),
                    Expanded(child: _PriceField(controller: _maxCtrl, hint: 'الحد الأقصى')),
                  ]),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                ],

                // ── Deals Only ────────────────────────────────────────────
                GestureDetector(
                  onTap: () => setState(() => _featured = !_featured),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      const Text('عروض فقط',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700,
                          color: AppColors.ink1)),
                      const Spacer(),
                      Switch(
                        value: _featured,
                        onChanged: (v) => setState(() => _featured = v),
                        activeColor: AppColors.primary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ]),
                  ),
                ),
                const Divider(height: 1),

                // ── In-stock ──────────────────────────────────────────────
                GestureDetector(
                  onTap: () => setState(() => _inStock = !_inStock),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      const Text('متوفّر فقط',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700,
                          color: AppColors.ink1)),
                      const Spacer(),
                      Switch(
                        value: _inStock,
                        onChanged: (v) => setState(() => _inStock = v),
                        activeColor: AppColors.primary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ]),
                  ),
                ),
                const Divider(height: 1),

                // ── Rating ────────────────────────────────────────────────
                _sectionHeader('الحد الأدنى للتقييم', _ratingExpanded,
                  () => setState(() => _ratingExpanded = !_ratingExpanded)),

                if (_ratingExpanded) ...[
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [3, 4, 5].map((star) {
                      final selected = _rating == star;
                      return GestureDetector(
                        onTap: () => setState(() => _rating = selected ? null : star),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected ? AppColors.primary : AppColors.border,
                              width: 1.5),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.star_rounded, size: 14,
                              color: selected ? AppColors.ink0 : AppColors.warn),
                            const SizedBox(width: 4),
                            Text('$star+ نجوم',
                              style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: selected ? AppColors.ink0 : AppColors.ink1)),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                ],

                // ── Attributes (Size, Color, etc.) ────────────────────
                Consumer(builder: (ctx, attrRef, _) {
                  final opts = attrRef.watch(_filterOptionsProvider(_FilterScope(
                    categoryId: widget.scopeCategoryId, brand: _brand)));
                  return opts.maybeWhen(
                    data: (options) {
                      // Filter out brand attribute type — handled by the dedicated brand section
                      final attrTypes = options.attrTypes.where((t) {
                        final n = t.name.toLowerCase();
                        final na = t.nameAr;
                        return !n.contains('brand') && !na.contains('ماركة');
                      }).toList();
                      if (attrTypes.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: attrTypes.map((attrType) {
                          final typeLabel = isAr ? attrType.nameAr : attrType.name;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionHeader(typeLabel, _attrExpanded,
                                () => setState(() => _attrExpanded = !_attrExpanded)),
                              if (_attrExpanded) ...[
                                Wrap(
                                  spacing: 8, runSpacing: 8,
                                  children: attrType.values.map((val) {
                                    final sel = _attrValueIds.contains(val.id);
                                    final valLabel = isAr ? val.valueAr : val.value;
                                    if (attrType.displayType == 'color' && val.colorHex != null) {
                                      Color? color;
                                      try {
                                        color = Color(int.parse(
                                          val.colorHex!.replaceFirst('#', '0xFF')));
                                      } catch (_) {}
                                      return GestureDetector(
                                        onTap: () => setState(() =>
                                            sel ? _attrValueIds.remove(val.id)
                                                : _attrValueIds.add(val.id)),
                                        child: Container(
                                          width: 32, height: 32,
                                          decoration: BoxDecoration(
                                            color: color ?? AppColors.bg,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: sel ? AppColors.primary : AppColors.border,
                                              width: sel ? 2.5 : 1.5)),
                                          child: sel ? const Icon(Icons.check,
                                            size: 14, color: Colors.white) : null,
                                        ),
                                      );
                                    }
                                    return GestureDetector(
                                      onTap: () => setState(() =>
                                          sel ? _attrValueIds.remove(val.id)
                                              : _attrValueIds.add(val.id)),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: sel ? AppColors.primary : Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: sel ? AppColors.primary : AppColors.border,
                                            width: 1.5)),
                                        child: Text(valLabel,
                                          style: TextStyle(
                                            fontSize: 12, fontWeight: FontWeight.w600,
                                            color: sel ? AppColors.ink0 : AppColors.ink1)),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                              ],
                            ],
                          );
                        }).toList(),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  );
                }),

                // ── Brand ─────────────────────────────────────────────
                Consumer(builder: (ctx, brandRef, _) {
                  final opts = brandRef.watch(_filterOptionsProvider(_FilterScope(
                    categoryId: widget.scopeCategoryId)));
                  return opts.maybeWhen(
                    data: (options) {
                      if (options.brands.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader('الماركة', _brandExpanded,
                            () => setState(() => _brandExpanded = !_brandExpanded)),
                          if (_brandExpanded) ...[
                            Wrap(
                              spacing: 8, runSpacing: 8,
                              children: options.brands.map((b) {
                                final sel = _brand == b;
                                return GestureDetector(
                                  onTap: () => setState(() => _brand = sel ? null : b),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: sel ? AppColors.primary : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: sel ? AppColors.primary : AppColors.border,
                                        width: 1.5)),
                                    child: Text(b,
                                      style: TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.w600,
                                        color: sel ? AppColors.ink0 : AppColors.ink1)),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  );
                }),

              ],
            ),
          ),

          // Apply button
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 16),
            child: SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('تطبيق الفلاتر',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800,
                    fontSize: 15, color: AppColors.ink0)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatRow extends StatelessWidget {
  final String label;
  final bool selected;
  final bool small;
  final VoidCallback onTap;
  const _CatRow({required this.label, required this.selected, required this.onTap, this.small = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Text(label,
            style: TextStyle(
              fontSize: small ? 12 : 13,
              color: selected ? AppColors.primary : AppColors.ink1,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            )),
          const Spacer(),
          if (selected)
            const Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
        ]),
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CatChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: 1.5),
        ),
        child: Text(label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.ink0 : AppColors.ink1,
          )),
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _PriceField({required this.controller, required this.hint});
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: AppColors.ink3, fontFamily: 'Cairo'),
        filled: true, fillColor: AppColors.surfaceSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
