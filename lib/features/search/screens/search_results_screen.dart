import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/product.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/navigation.dart';
import '../../../core/utils/price_input.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/product_card.dart';
import '../../../core/utils/responsive.dart';

class _SuggestedCategory {
  final int id;
  final String name;
  final String nameAr;
  final int productCount;
  const _SuggestedCategory(
      {required this.id,
      required this.name,
      required this.nameAr,
      required this.productCount});
  factory _SuggestedCategory.fromJson(Map<String, dynamic> j) =>
      _SuggestedCategory(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        nameAr: j['name_ar'] as String? ?? '',
        productCount: (j['product_count'] as num?)?.toInt() ?? 0,
      );
}

class _AttrValue {
  final int id;
  final String value;
  final String valueAr;
  final String? colorHex;
  const _AttrValue(
      {required this.id,
      required this.value,
      required this.valueAr,
      this.colorHex});
}

class _AttrType {
  final int id;
  final String name;
  final String nameAr;
  final String displayType;
  final List<_AttrValue> values;
  const _AttrType(
      {required this.id,
      required this.name,
      required this.nameAr,
      required this.displayType,
      required this.values});
}

class _Vendor {
  final int id;
  final String name;
  const _Vendor({required this.id, required this.name});
}

class _FilterOptions {
  final List<_AttrType> attrTypes;
  final List<String> brands;
  final List<_Vendor> vendors;

  /// Whether any product in the current scope actually has reviews. Absent (null in the
  /// payload) → default true for backward-compat with stale-cached responses.
  final bool hasReviews;
  const _FilterOptions(
      {this.attrTypes = const [],
      this.brands = const [],
      this.vendors = const [],
      this.hasReviews = true});
}

// Scope key: everything that narrows the results also narrows the options (a search for «عطر»
// lists only perfume brands). The server leaves a facet's own picks out of that facet, so
// picking one brand still lists the others. Any change here refetches.
class _FilterScope {
  final Map<String, dynamic> params;
  final String _key;
  const _FilterScope._(this.params, this._key);

  factory _FilterScope({
    String query = '',
    int? categoryId,
    bool onSale = false,
    bool featured = false,
    double? minPrice,
    double? maxPrice,
    int? minRating,
    Iterable<String> brands = const [],
    Iterable<int> attributeValueIds = const [],
    Iterable<int> vendorIds = const [],
  }) {
    final b = brands.toList()..sort();
    final a = attributeValueIds.toList()..sort();
    final v = vendorIds.toList()..sort();
    final params = <String, dynamic>{
      if (query.trim().isNotEmpty) 'search': query.trim(),
      if (categoryId != null) 'category_id': categoryId,
      if (onSale) 'on_sale': '1',
      if (featured) 'featured': 1,
      if (minPrice != null) 'min_price': minPrice,
      if (maxPrice != null) 'max_price': maxPrice,
      if (minRating != null) 'min_rating': minRating,
      if (b.isNotEmpty) 'brands[]': b,
      if (a.isNotEmpty) 'attribute_value_ids[]': a,
      if (v.isNotEmpty) 'vendor_ids[]': v,
    };
    return _FilterScope._(
        params, params.entries.map((e) => '${e.key}=${e.value}').join('&'));
  }

  @override
  bool operator ==(Object other) => other is _FilterScope && other._key == _key;

  @override
  int get hashCode => _key.hashCode;
}

// autoDispose: a failed (or stale) load is not kept for the whole session. Errors surface so the
// sheet can show Retry instead of silently empty options.
final _filterOptionsProvider = FutureProvider.autoDispose
    .family<_FilterOptions, _FilterScope>((_, scope) async {
  final res = await ApiClient.instance.dio.get('/products/filter-options',
      queryParameters: scope.params.isNotEmpty ? scope.params : null);
  final data = res.data['data'];
  final types = (data['attribute_types'] as List? ?? [])
      .map((t) => _AttrType(
            id: t['id'],
            name: t['name'] ?? '',
            nameAr: t['name_ar'] ?? '',
            displayType: t['display_type'] ?? 'button',
            values: (t['values'] as List? ?? [])
                .map((v) => _AttrValue(
                      id: v['id'],
                      value: v['value'] ?? '',
                      valueAr: v['value_ar'] ?? '',
                      colorHex: v['color_hex'],
                    ))
                .toList(),
          ))
      .toList();
  final brands =
      (data['brands'] as List? ?? []).map((b) => b.toString()).toList();
  final vendors = (data['vendors'] as List? ?? [])
      .map((v) {
        final id = v is Map ? (v['id'] as int? ?? 0) : 0;
        final name = v is Map
            ? (v['store_name'] ?? v['name'] ?? '').toString()
            : v.toString();
        return _Vendor(id: id, name: name);
      })
      .where((v) => v.id != 0 && v.name.isNotEmpty)
      .toList();
  return _FilterOptions(
      attrTypes: types,
      brands: brands,
      vendors: vendors,
      hasReviews:
          data['has_reviews'] == null ? true : data['has_reviews'] == true);
});

// 'relevance' is never sent: with no sort param the server ranks a text search by
// relevance. Offered (and the default) only when there is a text query.
const _relevanceSort = ('relevance', 'الأنسب', 'Best match');

final _sortOptions = [
  ('latest', 'الأحدث', 'Newest'),
  ('popular', 'الأكثر مبيعاً', 'Best selling'),
  ('price_asc', 'الأرخص', 'Price: low to high'),
  ('price_desc', 'الأغلى', 'Price: high to low'),
];

class _FilterState {
  final double? minPrice;
  final double? maxPrice;
  final int? minRating;
  final bool onSaleOnly;
  final int? categoryId;
  final String? categoryName;
  final Set<int> attributeValueIds;
  final Set<String> brands;
  final Set<int> vendorIds;

  /// Display names for the applied-filter chips (ids alone can't be shown).
  final Map<int, String> attrLabels;
  final Map<int, String> vendorNames;

  const _FilterState({
    this.minPrice,
    this.maxPrice,
    this.minRating,
    this.onSaleOnly = false,
    this.categoryId,
    this.categoryName,
    this.attributeValueIds = const {},
    this.brands = const {},
    this.vendorIds = const {},
    this.attrLabels = const {},
    this.vendorNames = const {},
  });

  // Category is left out: a subcategory tab is navigation, not a filter. A category picked from
  // the suggestions or the sheet is counted by the screen, which knows the tabs.
  bool get isActive =>
      minPrice != null ||
      maxPrice != null ||
      minRating != null ||
      onSaleOnly ||
      attributeValueIds.isNotEmpty ||
      brands.isNotEmpty ||
      vendorIds.isNotEmpty;

  _FilterState copyWith({
    Object? minPrice = _unset,
    Object? maxPrice = _unset,
    Object? minRating = _unset,
    bool? onSaleOnly,
    Object? categoryId = _unset,
    Object? categoryName = _unset,
    Set<int>? attributeValueIds,
    Set<String>? brands,
    Set<int>? vendorIds,
  }) =>
      _FilterState(
        minPrice:
            identical(minPrice, _unset) ? this.minPrice : minPrice as double?,
        maxPrice:
            identical(maxPrice, _unset) ? this.maxPrice : maxPrice as double?,
        minRating:
            identical(minRating, _unset) ? this.minRating : minRating as int?,
        onSaleOnly: onSaleOnly ?? this.onSaleOnly,
        categoryId: identical(categoryId, _unset)
            ? this.categoryId
            : categoryId as int?,
        categoryName: identical(categoryName, _unset)
            ? this.categoryName
            : categoryName as String?,
        attributeValueIds: attributeValueIds ?? this.attributeValueIds,
        brands: brands ?? this.brands,
        vendorIds: vendorIds ?? this.vendorIds,
        attrLabels: attrLabels,
        vendorNames: vendorNames,
      );

  static const _unset = Object();
}

class SearchResultsScreen extends ConsumerStatefulWidget {
  final String query;
  final String? pageTitle;
  final int? categoryId;
  final bool onSale;

  /// Featured products only (`featured=1`), e.g. a banner linked to /products?featured=true.
  final bool featured;
  final double? minPrice;
  final double? maxPrice;
  final String? initialSort;
  final String? initialBrand;

  /// Pre-loaded products from baahyVision camera search — skips API fetch when provided
  final List<Product>? visionProducts;
  const SearchResultsScreen({
    required this.query,
    this.pageTitle,
    this.categoryId,
    this.onSale = false,
    this.featured = false,
    this.minPrice,
    this.maxPrice,
    this.initialSort,
    this.initialBrand,
    this.visionProducts,
    super.key,
  });

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  final _scrollCtrl = ScrollController();
  List<Product> _products = [];
  List<_SuggestedCategory> _suggestedCategories = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  bool _hasMore = true;
  // Page-1 failure shows an error with Retry; a failed next page keeps what is loaded.
  bool _loadError = false;
  bool _loadMoreError = false;
  int _reqSeq = 0; // newest request wins; a reset drops older (and in-flight next-page) responses
  int? _total; // result count from the response (data.total)
  late String _sort;
  late _FilterState _filters;

  bool get _hasTextQuery => widget.query.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    // A text search defaults to relevance; plain browsing (category, brand, deals) keeps random.
    _sort = widget.initialSort ??
        (_hasTextQuery ? _relevanceSort.$1 : 'random');
    // Link params seed the filter state, so the sheet shows them and the shopper can undo them.
    _filters = _FilterState(
      categoryId: widget.categoryId,
      minPrice: widget.minPrice,
      maxPrice: widget.maxPrice,
      onSaleOnly: widget.onSale,
      brands: (widget.initialBrand != null && widget.initialBrand!.isNotEmpty)
          ? {widget.initialBrand!}
          : const {},
    );
    if (widget.visionProducts != null) {
      // Use pre-searched products from camera — skip API call
      _products = widget.visionProducts!;
      _loading = false;
      _hasMore = false;
    } else {
      _fetch(reset: true);
    }
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >
        _scrollCtrl.position.maxScrollExtent - 200) {
      // After a failed page, wait for the Retry tap instead of re-firing on every scroll tick.
      if (!_loadingMore && _hasMore && !_loadMoreError && !_loading) _fetch();
    }
  }

  Future<void> _fetch({bool reset = false}) async {
    if (reset) {
      ++_reqSeq; // anything still in flight (incl. a next page) is now stale
      setState(() {
        _loading = true;
        _loadingMore = false;
        _loadError = false;
        _loadMoreError = false;
        _page = 1;
        _hasMore = true;
        _products = [];
        _total = null;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() {
        _loadingMore = true;
        _loadMoreError = false;
      });
    }
    final seq = _reqSeq;
    final page = _page;

    try {
      final res =
          await ApiClient.instance.dio.get('/products', queryParameters: {
        if (widget.query.isNotEmpty) 'search': widget.query,
        if (_filters.categoryId != null)
          'category_id': _filters.categoryId
        else if (widget.categoryId != null)
          'category_id': widget.categoryId,
        if (_sort != _relevanceSort.$1) 'sort': _sort,
        'page': page,
        'per_page': 20,
        if (_filters.minPrice != null) 'min_price': _filters.minPrice,
        if (_filters.maxPrice != null) 'max_price': _filters.maxPrice,
        if (_filters.minRating != null) 'min_rating': _filters.minRating,
        if (_filters.onSaleOnly) 'on_sale': '1',
        if (widget.featured) 'featured': 1,
        if (_filters.brands.isNotEmpty) 'brands[]': _filters.brands.toList(),
        if (_filters.vendorIds.isNotEmpty)
          'vendor_ids[]': _filters.vendorIds.toList(),
        ..._filters.attributeValueIds.isNotEmpty
            ? {'attribute_value_ids[]': _filters.attributeValueIds.toList()}
            : {},
      });
      // A newer query / filter / category superseded this request: drop it.
      if (!mounted || seq != _reqSeq) return;
      final data = res.data['data'];
      final newProducts =
          (data['data'] as List).map((p) => Product.fromJson(p)).toList();
      final rawSuggestions = res.data['suggested_categories'] as List? ?? [];
      setState(() {
        _products = reset ? newProducts : [..._products, ...newProducts];
        if (reset) {
          _total = (data['total'] as num?)?.toInt();
          _suggestedCategories = rawSuggestions
              .map(
                  (c) => _SuggestedCategory.fromJson(c as Map<String, dynamic>))
              .toList();
        }
        _page = page + 1;
        _hasMore = data['current_page'] < data['last_page'];
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        if (reset) {
          _loadError = true;
        } else {
          _loadMoreError = true;
        }
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  // Sort = a bottom sheet in the filter sheet's style (Emad, 2026-10-23: the plain popup menu
  // "looks bad"). Tapping a row applies it and closes.
  void _openSort() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.col.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (_) => _SortSheet(
        options: [if (_hasTextQuery) _relevanceSort, ..._sortOptions],
        selected: _sort,
      ),
    );
    if (picked != null && picked != _sort && mounted) {
      _sort = picked;
      _fetch(reset: true);
    }
  }

  void _openFilters() async {
    final result = await showModalBottomSheet<_FilterState>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.col.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (_) => _FilterSheet(
          initial: _filters,
          scopeCategoryId: widget.categoryId,
          query: widget.query,
          featured: widget.featured),
    );
    if (result != null && mounted) {
      setState(() => _filters = result);
      _fetch(reset: true);
    }
  }

  // Find a category anywhere in the tree by id
  Category? _findCategory(List<Category> cats, int id) {
    for (final c in cats) {
      if (c.id == id) return c;
      for (final ch in c.children) {
        if (ch.id == id) return ch;
        for (final gc in ch.children) {
          if (gc.id == id) return gc;
        }
      }
    }
    return null;
  }

  void _applyFilters(_FilterState f) {
    setState(() => _filters = f);
    _fetch(reset: true);
  }

  // A category picked from the «ابحث في» suggestions or the sheet: not the page's own scope and
  // not one a subcategory tab already shows. It gets a removable chip and counts as a filter.
  String? _categoryFilterLabel(List<Category> all, List<Category> tabs) {
    final id = _filters.categoryId;
    if (id == null || id == widget.categoryId) return null;
    if (tabs.any((c) => c.id == id)) return null;
    if (_filters.categoryName?.isNotEmpty == true) return _filters.categoryName;
    final c = _findCategory(all, id);
    if (c == null) return context.s.category;
    return context.isAr ? c.nameAr : c.name;
  }

  // What the results are filtered by, each removable on its own.
  List<_AppliedChip> _appliedChips(String? catLabel) {
    final f = _filters;
    final ld = context.tr('د.ل', 'LD');
    final lo = formatPriceInput(f.minPrice);
    final hi = formatPriceInput(f.maxPrice);
    return [
      if (catLabel != null)
        _AppliedChip(
            catLabel,
            () => _applyFilters(f.copyWith(
                categoryId: widget.categoryId, categoryName: null))),
      for (final b in f.brands)
        _AppliedChip(b,
            () => _applyFilters(f.copyWith(brands: {...f.brands}..remove(b)))),
      if (f.minPrice != null || f.maxPrice != null)
        _AppliedChip(
            f.minPrice != null && f.maxPrice != null
                ? '$lo–$hi $ld'
                : f.minPrice != null
                    ? context.tr('من $lo $ld', 'From $lo $ld')
                    : context.tr('حتى $hi $ld', 'Up to $hi $ld'),
            () => _applyFilters(f.copyWith(minPrice: null, maxPrice: null))),
      if (f.onSaleOnly)
        _AppliedChip(context.s.dealsOnly,
            () => _applyFilters(f.copyWith(onSaleOnly: false))),
      if (f.minRating != null)
        _AppliedChip(
            context.tr('${f.minRating}+ نجوم', '${f.minRating}+ stars'),
            () => _applyFilters(f.copyWith(minRating: null))),
      for (final id in f.attributeValueIds)
        _AppliedChip(
            f.attrLabels[id] ?? context.tr('خيار', 'Option'),
            () => _applyFilters(f.copyWith(
                attributeValueIds: {...f.attributeValueIds}..remove(id)))),
      for (final id in f.vendorIds)
        _AppliedChip(
            f.vendorNames[id] ?? context.s.storeLabel,
            () => _applyFilters(
                f.copyWith(vendorIds: {...f.vendorIds}..remove(id)))),
    ];
  }

  void _selectSubcat(int? catId) {
    setState(() => _filters = _filters.copyWith(
          categoryId: catId,
          categoryName: null,
          attributeValueIds: const {},
          brands: const {},
          vendorIds: const {},
        ));
    _fetch(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final allCategories = ref.watch(homeProvider).categories;

    // Subcategory tabs: children of the page's scope category
    final scopeCat = widget.categoryId != null
        ? _findCategory(allCategories, widget.categoryId!)
        : null;
    final subcats = scopeCat?.children ?? <Category>[];
    final catLabel = _categoryFilterLabel(allCategories, subcats);
    final appliedChips = _appliedChips(catLabel);
    final filtersActive = _filters.isActive || catLabel != null;

    // Banners: use selected sub-cat's banners, fallback to scope cat's banners
    final bannerCatId = _filters.categoryId ?? widget.categoryId;
    final bannerCat =
        bannerCatId != null ? _findCategory(allCategories, bannerCatId) : null;
    var banners = bannerCat?.banners ?? <CategoryBanner>[];
    if (banners.isEmpty &&
        bannerCatId != widget.categoryId &&
        scopeCat != null) {
      banners = scopeCat.banners;
    }

    return Scaffold(
      backgroundColor: context.col.bg,
      appBar: AppBar(
        backgroundColor: context.col.surface,
        elevation: 0,
        title: Text(
          widget.pageTitle ??
              (widget.query.isNotEmpty
                  ? widget.query
                  : (widget.initialBrand?.isNotEmpty == true
                      ? widget.initialBrand!
                      : context.s.products)),
          style: const TextStyle(
              fontFamily: 'Manrope',
              fontFamilyFallback: ['Tajawal'],
              fontWeight: FontWeight.w700,
              fontSize: 16),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                onPressed: _openFilters,
                icon: Icon(Icons.tune_rounded, color: context.col.ink0),
              ),
              if (filtersActive)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.sort, color: context.col.ink0),
            onPressed: _openSort,
          ),
        ],
      ),
      body: Column(
        children: [
          // Subcategory tabs
          if (subcats.isNotEmpty)
            _SubcatTabs(
              categories: subcats,
              selectedId: _filters.categoryId,
              onSelect: _selectSubcat,
            ),
          // Applied filters, each with an × that removes just that one
          if (appliedChips.isNotEmpty) _AppliedFiltersRow(chips: appliedChips),
          // Banner slider
          if (banners.isNotEmpty) _BannerSlider(banners: banners),
          // Category chips — shown when search spans multiple categories and no category filter active
          if (_suggestedCategories.length >= 2 &&
              _filters.categoryId == null &&
              widget.categoryId == null)
            _CategoryChipsRow(
              categories: _suggestedCategories,
              isAr: Localizations.localeOf(context).languageCode == 'ar',
              // Like the subcategory tabs: brand / size / store picks belong to the old scope.
              onTap: (catId, catName) => _applyFilters(_filters.copyWith(
                  categoryId: catId,
                  categoryName: catName,
                  attributeValueIds: const {},
                  brands: const {},
                  vendorIds: const {})),
            ),
          // Products
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _loadError
                    ? _ErrorState(onRetry: () => _fetch(reset: true))
                : _products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off,
                                size: 64, color: context.col.ink4),
                            const SizedBox(height: 12),
                            Text(context.s.noResultsFound,
                                style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontFamilyFallback: ['Tajawal'],
                                    fontSize: 16,
                                    color: context.col.ink2)),
                            if (filtersActive) ...[
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: () {
                                  setState(
                                      () => _filters = const _FilterState());
                                  _fetch(reset: true);
                                },
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                label: Text(context.s.removeFilters),
                              ),
                            ],
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => safePush(context, '/chat'),
                              icon: const Icon(Icons.auto_awesome_outlined,
                                  size: 16, color: AppColors.primary),
                              label: Text(context.s.askAssistant,
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Manrope',
                                      fontFamilyFallback: ['Tajawal'])),
                            ),
                          ],
                        ),
                      )
                    : Column(children: [
                      if (_total != null)
                        Padding(
                          padding:
                              const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 0),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(context.s.resultsCountN(_total!),
                                style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontFamilyFallback: const ['Tajawal'],
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: context.col.ink3)),
                          ),
                        ),
                      Expanded(child: LayoutBuilder(builder: (_, box) {
                        final cols = productGridColumns(box.maxWidth);
                        final colW = productColumnWidth(
                          maxWidth: box.maxWidth,
                          columns: cols,
                          spacing: 12,
                          horizontalPadding: 24,
                        );
                        final cellH = productCellHeight(colW);
                        return GridView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            mainAxisExtent: cellH.ceilToDouble(),
                          ),
                          itemCount: _products.length + (_loadingMore ? 2 : 0),
                          itemBuilder: (_, i) {
                            if (i >= _products.length)
                              return const ProductCardSkeleton();
                            // Render at the column's real width (no FittedBox
                            // upscaling) — the cell height is sized exactly for
                            // it, so it fits with no dead space and stays crisp.
                            return ProductCard(product: _products[i]);
                          },
                        );
                      })),
                      // A failed next page keeps the loaded results; retry from here.
                      if (_loadMoreError)
                        _LoadMoreRetry(onRetry: () => _fetch()),
                    ]),
          ),
        ],
      ),
    );
  }
}

// ── Applied filters row ───────────────────────────────────────────────────────

class _AppliedChip {
  final String label;
  final VoidCallback onRemove;
  const _AppliedChip(this.label, this.onRemove);
}

/// A slim, scrollable row of the filters in force, in the filter-chip look (white, grey border).
class _AppliedFiltersRow extends StatelessWidget {
  final List<_AppliedChip> chips;
  const _AppliedFiltersRow({required this.chips});

  static final _arabic = RegExp(r'[\u0600-\u06FF]');

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.col.surface,
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = chips[i];
          return Semantics(
            button: true,
            label: context.tr('إزالة ${c.label}', 'Remove ${c.label}'),
            child: GestureDetector(
              onTap: c.onRemove,
              child: Container(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 8, 0),
                decoration: BoxDecoration(
                  color: context.col.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.col.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(c.label,
                      // Latin brand / size labels ("7-8 Years") must not be reversed by RTL bidi.
                      textDirection: _arabic.hasMatch(c.label)
                          ? null
                          : TextDirection.ltr,
                      style: TextStyle(
                          fontFamily: 'Manrope',
                          fontFamilyFallback: const ['Tajawal'],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.col.ink1)),
                  const SizedBox(width: 4),
                  Icon(Icons.close_rounded, size: 15, color: context.col.ink3),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Sort sheet ────────────────────────────────────────────────────────────────

class _SortSheet extends StatelessWidget {
  final List<(String, String, String)> options;
  final String selected;
  const _SortSheet({required this.options, required this.selected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: context.col.border,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Row(children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: context.col.surfaceSoft,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Icon(Icons.close_rounded,
                    size: 18, color: context.col.ink1),
              ),
            ),
            const SizedBox(width: 12),
            Text(context.s.sortBy,
                style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontFamilyFallback: ['Tajawal'],
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) Divider(height: 1, color: context.col.border),
            InkWell(
              onTap: () => Navigator.of(context).pop(options[i].$1),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(children: [
                  Expanded(
                    child: Text(context.tr(options[i].$2, options[i].$3),
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontFamilyFallback: const ['Tajawal'],
                          fontSize: 15,
                          fontWeight: options[i].$1 == selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: context.col.ink0,
                        )),
                  ),
                  if (options[i].$1 == selected)
                    Icon(Icons.check_rounded,
                        size: 22, color: AppColors.adaptive(context)),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Error states ──────────────────────────────────────────────────────────────

/// Page 1 failed (offline, timeout, 5xx) — not the same as "no results".
class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: context.col.ink4),
            const SizedBox(height: 12),
            Text(context.s.loadError,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Manrope',
                    fontFamilyFallback: const ['Tajawal'],
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.col.ink1)),
            const SizedBox(height: 6),
            Text(context.s.checkInternet,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Manrope',
                    fontFamilyFallback: const ['Tajawal'],
                    fontSize: 13,
                    color: context.col.ink3)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(context.s.retry),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small row under the grid when the next page failed.
class _LoadMoreRetry extends StatelessWidget {
  final VoidCallback onRetry;
  const _LoadMoreRetry({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: context.col.surface,
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Icon(Icons.error_outline_rounded, size: 18, color: context.col.ink3),
          const SizedBox(width: 8),
          Expanded(
            child: Text(context.s.loadMoreFailed,
                style: TextStyle(
                    fontFamily: 'Manrope',
                    fontFamilyFallback: const ['Tajawal'],
                    fontSize: 13,
                    color: context.col.ink2)),
          ),
          TextButton(onPressed: onRetry, child: Text(context.s.retry)),
        ]),
      ),
    );
  }
}

// ── Subcategory tab row ───────────────────────────────────────────────────────

class _SubcatTabs extends StatelessWidget {
  final List<Category> categories;
  final int? selectedId;
  final ValueChanged<int?> onSelect;
  const _SubcatTabs(
      {required this.categories,
      required this.selectedId,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Container(
      color: context.col.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _Tab(
                  label: isAr ? 'الكل' : 'All',
                  selected: selectedId == null,
                  onTap: () => onSelect(null),
                ),
                ...categories.map((cat) => Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      child: _Tab(
                        label: isAr ? cat.nameAr : cat.name,
                        selected: selectedId == cat.id,
                        onTap: () =>
                            onSelect(selectedId == cat.id ? null : cat.id),
                      ),
                    )),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Tab(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color:
              selected ? AppColors.adaptive(context) : context.col.surfaceSoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontFamilyFallback: ['Tajawal'],
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : context.col.ink1,
            )),
      ),
    );
  }
}

// ── Banner slider ─────────────────────────────────────────────────────────────

class _BannerSlider extends StatefulWidget {
  final List<CategoryBanner> banners;
  const _BannerSlider({required this.banners});
  @override
  State<_BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<_BannerSlider> {
  late final _ctrl = PageController(viewportFraction: 0.88);
  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.banners.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted) return;
        final next = (_current + 1) % widget.banners.length;
        _ctrl.animateToPage(next,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.col.surface,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: LayoutBuilder(builder: (context, constraints) {
        final itemW = constraints.maxWidth * 0.88;
        final sliderH = itemW / 2.6;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: sliderH,
              child: PageView.builder(
                clipBehavior: Clip.none,
                padEnds: false,
                controller: _ctrl,
                itemCount: widget.banners.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (_, i) {
                  final banner = widget.banners[i];
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(end: 10),
                    child: GestureDetector(
                      onTap: () {
                        if (banner.action != null &&
                            banner.action!.isNotEmpty) {
                          safePush(context, banner.action!);
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: banner.imageUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 1000,
                          placeholder: (_, __) =>
                              Container(color: context.col.cardImageBg),
                          errorWidget: (_, __, ___) =>
                              Container(color: context.col.cardImageBg),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (widget.banners.length > 1) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    widget.banners.length,
                    (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _current == i ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _current == i
                                ? context.col.ink0
                                : context.col.border,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        )),
              ),
            ],
          ],
        );
      }),
    );
  }
}

// ── Filter bottom sheet ───────────────────────────────────────────────────────

class _FilterSheet extends ConsumerStatefulWidget {
  final _FilterState initial;
  final int? scopeCategoryId;
  final String query; // the screen's search, so the options match its results
  final bool featured;
  const _FilterSheet(
      {required this.initial,
      this.scopeCategoryId,
      this.query = '',
      this.featured = false});
  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  int? _rating;
  late bool _onSale;
  int? _categoryId;
  String? _categoryName;
  late Set<int> _attrValueIds;
  Set<String> _brands = {};
  Set<int> _vendorIds = {};
  bool _catExpanded = true;
  bool _priceExpanded = true;
  bool _ratingExpanded = true;
  Map<int, bool> _attrExpanded = {};
  bool _brandExpanded = true;
  bool _vendorExpanded = true;
  // Long lists (brands, sizes…) show the first [_collapsedCount] until «عرض الكل» is tapped.
  static const _collapsedCount = 12;
  final Set<String> _listExpanded = {};
  // Price range the options are scoped to: the applied one (typing must not refetch per key).
  double? _scopeMinPrice;
  double? _scopeMaxPrice;
  // The last options shown, kept on screen while a pick refetches the narrowed ones.
  _FilterOptions? _lastOptions;
  // Every value / store seen in this sheet, so a pick the narrowed options no longer list stays
  // visible (and can be unticked), and the results page can name it on its chip.
  final Map<int, (_AttrType, _AttrValue)> _seenAttrValues = {};
  late final Map<int, String> _attrLabels;
  late final Map<int, String> _vendorNames;

  @override
  void initState() {
    super.initState();
    // Unrounded: a stored 99.5 reopens as 99.5, not 100.
    _minCtrl =
        TextEditingController(text: formatPriceInput(widget.initial.minPrice));
    _maxCtrl =
        TextEditingController(text: formatPriceInput(widget.initial.maxPrice));
    _scopeMinPrice = widget.initial.minPrice;
    _scopeMaxPrice = widget.initial.maxPrice;
    _attrLabels = {...widget.initial.attrLabels};
    _vendorNames = {...widget.initial.vendorNames};
    _rating = widget.initial.minRating;
    _onSale = widget.initial.onSaleOnly;
    _categoryId = widget.initial.categoryId;
    _categoryName = widget.initial.categoryName;
    _attrValueIds = Set.from(widget.initial.attributeValueIds);
    _brands = Set.from(widget.initial.brands);
    _vendorIds = Set.from(widget.initial.vendorIds);
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    // Arabic-Indic digits and "1,000" parse; a min above the max is swapped.
    final (minPrice, maxPrice) = parsePriceRange(_minCtrl.text, _maxCtrl.text);
    Navigator.of(context).pop(_FilterState(
      minPrice: minPrice,
      maxPrice: maxPrice,
      minRating: _rating,
      onSaleOnly: _onSale,
      categoryId: _categoryId,
      categoryName: _categoryName,
      attributeValueIds: Set.from(_attrValueIds),
      brands: Set.from(_brands),
      vendorIds: Set.from(_vendorIds),
      attrLabels: {
        for (final id in _attrValueIds)
          if (_attrLabels[id] != null) id: _attrLabels[id]!,
      },
      vendorNames: {
        for (final id in _vendorIds)
          if (_vendorNames[id] != null) id: _vendorNames[id]!,
      },
    ));
  }

  // The shopper's current view, picks in this sheet included: the options are fetched for it.
  _FilterScope get _scope => _FilterScope(
        query: widget.query,
        categoryId: _effectiveCategoryId,
        onSale: _onSale,
        featured: widget.featured,
        minPrice: _scopeMinPrice,
        maxPrice: _scopeMaxPrice,
        minRating: _rating,
        brands: _brands,
        attributeValueIds: _attrValueIds,
        vendorIds: _vendorIds,
      );

  // A deep-link brand ("nike") must match the option ("NIKE").
  bool _brandSelected(String b) =>
      _brands.any((x) => x.toLowerCase() == b.toLowerCase());

  void _toggleBrand(String b) => setState(() => _brandSelected(b)
      ? _brands.removeWhere((x) => x.toLowerCase() == b.toLowerCase())
      : _brands.add(b));

  void _remember(_FilterOptions o, bool isAr) {
    for (final t in o.attrTypes) {
      for (final v in t.values) {
        _seenAttrValues[v.id] = (t, v);
        _attrLabels[v.id] =
            (isAr && v.valueAr.isNotEmpty) ? v.valueAr : v.value;
      }
    }
    for (final v in o.vendors) {
      _vendorNames[v.id] = v.name;
    }
  }

  // Picks the narrowed options no longer list (another facet ruled them out) stay visible.
  _FilterOptions _withSelected(_FilterOptions o) {
    final brands = [...o.brands];
    for (final b in _brands) {
      if (!brands.any((x) => x.toLowerCase() == b.toLowerCase())) brands.add(b);
    }
    final vendors = [...o.vendors];
    for (final id in _vendorIds) {
      final name = _vendorNames[id];
      if (name != null && !vendors.any((v) => v.id == id)) {
        vendors.add(_Vendor(id: id, name: name));
      }
    }
    final types = [...o.attrTypes];
    for (final id in _attrValueIds) {
      if (types.any((t) => t.values.any((v) => v.id == id))) continue;
      final seen = _seenAttrValues[id];
      if (seen == null) continue;
      final (type, val) = seen;
      final i = types.indexWhere((t) => t.id == type.id);
      final base = i >= 0 ? types[i] : type;
      final merged = _AttrType(
          id: base.id,
          name: base.name,
          nameAr: base.nameAr,
          displayType: base.displayType,
          values: [if (i >= 0) ...base.values, val]);
      if (i >= 0) {
        types[i] = merged;
      } else {
        types.add(merged);
      }
    }
    return _FilterOptions(
        attrTypes: types,
        brands: brands,
        vendors: vendors,
        hasReviews: o.hasReviews);
  }

  // The first [_collapsedCount] items, plus any picked further down, until expanded.
  List<T> _visible<T>(String key, List<T> all, bool Function(T) isSel) {
    if (_listExpanded.contains(key) || all.length <= _collapsedCount) {
      return all;
    }
    return [
      for (var i = 0; i < all.length; i++)
        if (i < _collapsedCount || isSel(all[i])) all[i],
    ];
  }

  List<Widget> _showAll(String key, int total) {
    if (_listExpanded.contains(key) || total <= _collapsedCount) return [];
    return [
      GestureDetector(
        onTap: () => setState(() => _listExpanded.add(key)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
              color: context.col.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.col.border, width: 1.5)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(context.tr('عرض الكل ($total)', 'Show all ($total)'),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.col.ink1)),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 16, color: context.col.ink3),
          ]),
        ),
      ),
    ];
  }

  // The category driving filter-option scoping: user's in-sheet pick, else page scope.
  int? get _effectiveCategoryId => _categoryId ?? widget.scopeCategoryId;

  // Localized name of the scope category (searches top level + one level of children).
  String? _scopeCategoryName(List<Category> cats, int id, bool isAr) {
    for (final c in cats) {
      if (c.id == id) return isAr ? c.nameAr : c.name;
      for (final ch in c.children) {
        if (ch.id == id) return isAr ? ch.nameAr : ch.name;
      }
    }
    return null;
  }

  // Cascade-clear dependent selections when category changes.
  void _selectCategory(int? catId, String? catName) {
    setState(() {
      _categoryId = catId;
      _categoryName = catName;
      // Clear selections that are category-specific.
      _attrValueIds = {};
      _brands = {};
      _vendorIds = {};
    });
  }

  void _reset() {
    setState(() {
      _minCtrl.clear();
      _maxCtrl.clear();
      _rating = null;
      _onSale = false;
      _scopeMinPrice = null;
      _scopeMaxPrice = null;
      _categoryId = null;
      _categoryName = null;
      _attrValueIds = {};
      _brands = {};
      _vendorIds = {};
    });
  }

  Widget _sectionHeader(String title, bool expanded, VoidCallback toggle) {
    return GestureDetector(
      onTap: toggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Text(title,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: context.col.ink1)),
          const Spacer(),
          Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: context.col.ink3,
              size: 20),
        ]),
      ),
    );
  }

  // Whether an attribute type is a clothing/shoe size (drives natural ordering + LTR labels).
  bool _isSizeType(_AttrType t) => isSizeAttribute(t.name, t.nameAr);

  // Natural size ordering (see core/utils/size_order.dart): numeric sizes, XXS→5XL, months, years, rest last.
  List<_AttrValue> _orderedValues(_AttrType t) => !_isSizeType(t)
      ? t.values
      : sortSizeValues(
          t.values, (v) => v.value.isNotEmpty ? v.value : v.valueAr);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final allCategories = ref.watch(homeProvider).categories;

    // Options for the current view. While a pick refetches them the last ones stay up (with a
    // thin progress line); first load = spinner; failure = a Retry box.
    final scope = _scope;
    final optsAsync = ref.watch(_filterOptionsProvider(scope));
    final fresh = optsAsync.valueOrNull;
    if (fresh != null && !optsAsync.isLoading) {
      _lastOptions = fresh;
      _remember(fresh, isAr);
    }
    final optsFailed = optsAsync.hasError && !optsAsync.isLoading;
    final shownOpts = optsFailed ? null : (fresh ?? _lastOptions);
    final opts = shownOpts == null ? null : _withSelected(shownOpts);

    // Compute scoped subcategories for the category filter section
    List<Category> scopedCats = [];
    if (widget.scopeCategoryId != null) {
      final topLevel = allCategories
          .where((c) => c.id == widget.scopeCategoryId)
          .firstOrNull;
      if (topLevel != null) {
        scopedCats = topLevel.children;
      } else {
        for (final parent in allCategories) {
          final match = parent.children
              .where((c) => c.id == widget.scopeCategoryId)
              .firstOrNull;
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
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: context.col.border,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              Row(children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: context.col.surfaceSoft,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 18, color: context.col.ink1),
                  ),
                ),
                const SizedBox(width: 12),
                Text(context.s.filters,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton(
                    onPressed: _reset,
                    child: Text(context.s.resetFilters,
                        style: TextStyle(color: context.col.ink2))),
              ]),
              const Divider(height: 1),
            ]),
          ),

          // Scrollable content
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              // Dragging the sheet dismisses the price keyboard (it otherwise stays
              // stuck open with no Done key on the numeric pad).
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              children: [
                // ── Current category (context) — shown when we're scoped to a
                //    category that has no subcategories to narrow into.
                if (scopedCats.isEmpty &&
                    widget.scopeCategoryId != null &&
                    _scopeCategoryName(
                            allCategories, widget.scopeCategoryId!, isAr) !=
                        null) ...[
                  _sectionHeader(context.s.category, true, () {}),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _CatChip(
                      label: _scopeCategoryName(
                          allCategories, widget.scopeCategoryId!, isAr)!,
                      selected: true,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                ],

                // ── Category chips ─────────────────────────────────────
                if (scopedCats.isNotEmpty) ...[
                  _sectionHeader(context.s.category, _catExpanded,
                      () => setState(() => _catExpanded = !_catExpanded)),
                  if (_catExpanded) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _CatChip(
                          label: context.s.all,
                          selected: _categoryId == null ||
                              _categoryId == widget.scopeCategoryId,
                          onTap: () => _selectCategory(null, null),
                        ),
                        ...scopedCats.map((cat) => _CatChip(
                              label: isAr ? cat.nameAr : cat.name,
                              selected: _categoryId == cat.id ||
                                  cat.children.any((c) => c.id == _categoryId),
                              onTap: () => _selectCategory(
                                  cat.id, isAr ? cat.nameAr : cat.name),
                            )),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                  ],
                ],

                // ── Options loading / failed ──────────────────────────
                if (optsFailed)
                  _OptionsError(
                      onRetry: () =>
                          ref.invalidate(_filterOptionsProvider(scope)))
                else if (opts == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 2,
                    child: optsAsync.isLoading
                        ? const LinearProgressIndicator(
                            minHeight: 2, color: AppColors.primary)
                        : null,
                  ),

                // ── Attributes (Size, Color, etc.) ────────────────────
                if (opts != null)
                  Builder(builder: (_) {
                      final options = opts;
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
                          final typeLabel = attrTypeLabel(
                              isAr, attrType.name, attrType.nameAr);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionHeader(
                                  typeLabel,
                                  _attrExpanded[attrType.id] ?? true,
                                  () => setState(() =>
                                      _attrExpanded[attrType.id] =
                                          !(_attrExpanded[attrType.id] ??
                                              true))),
                              if (_attrExpanded[attrType.id] ?? true) ...[
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                  ..._visible(
                                          'attr_${attrType.id}',
                                          _orderedValues(attrType),
                                          (v) => _attrValueIds.contains(v.id))
                                      .map((val) {
                                    final sel = _attrValueIds.contains(val.id);
                                    final valLabel =
                                        (isAr && val.valueAr.isNotEmpty)
                                            ? val.valueAr
                                            : val.value;
                                    if (attrType.displayType == 'color' &&
                                        val.colorHex != null) {
                                      Color? color;
                                      try {
                                        color = Color(int.parse(val.colorHex!
                                            .replaceFirst('#', '0xFF')));
                                      } catch (_) {}
                                      return GestureDetector(
                                        onTap: () => setState(() => sel
                                            ? _attrValueIds.remove(val.id)
                                            : _attrValueIds.add(val.id)),
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                              color: color ?? context.col.bg,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color: sel
                                                      ? AppColors.adaptive(context)
                                                      : context.col.border,
                                                  width: sel ? 2.5 : 1.5)),
                                          child: sel
                                              ? const Icon(Icons.check,
                                                  size: 14, color: Colors.white)
                                              : null,
                                        ),
                                      );
                                    }
                                    return GestureDetector(
                                      onTap: () => setState(() => sel
                                          ? _attrValueIds.remove(val.id)
                                          : _attrValueIds.add(val.id)),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 7),
                                        decoration: BoxDecoration(
                                            color: sel
                                                ? AppColors.adaptive(context)
                                                : context.col.surface,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: sel
                                                    ? AppColors.adaptive(
                                                        context)
                                                    : context.col.border,
                                                width: 1.5)),
                                        child: Text(valLabel,
                                            // Force LTR on size labels so Latin/numeric values
                                            // ("7-8 Years", 27"-29") aren't reversed by RTL bidi.
                                            textDirection: _isSizeType(attrType)
                                                ? TextDirection.ltr
                                                : null,
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: sel
                                                    ? Colors.white
                                                    : context.col.ink1)),
                                      ),
                                    );
                                  }),
                                  ..._showAll('attr_${attrType.id}',
                                      attrType.values.length),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                              ],
                            ],
                          );
                        }).toList(),
                      );
                  }),

                // ── Brand ─────────────────────────────────────────────
                if (opts != null)
                  Builder(builder: (_) {
                      final options = opts;
                      if (options.brands.isEmpty)
                        return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                              context.s.brand,
                              _brandExpanded,
                              () => setState(
                                  () => _brandExpanded = !_brandExpanded)),
                          if (_brandExpanded) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                              ..._visible('brand', options.brands,
                                      _brandSelected)
                                  .map((b) {
                                final sel = _brandSelected(b);
                                return GestureDetector(
                                  onTap: () => _toggleBrand(b),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                        color: sel
                                            ? AppColors.adaptive(context)
                                            : context.col.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: sel
                                                ? AppColors.adaptive(context)
                                                : context.col.border,
                                            width: 1.5)),
                                    child: Text(b,
                                        // Latin brand names read LTR, as in the store sheet.
                                        textDirection: TextDirection.ltr,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: sel
                                                ? Colors.white
                                                : context.col.ink1)),
                                  ),
                                );
                              }),
                              ..._showAll('brand', options.brands.length),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                          ],
                        ],
                      );
                  }),

                // ── Price ─────────────────────────────────────────────────
                _sectionHeader(
                    context.isAr ? 'نطاق السعر (د.ل)' : 'Price Range (LD)',
                    _priceExpanded,
                    () => setState(() => _priceExpanded = !_priceExpanded)),

                if (_priceExpanded) ...[
                  Row(children: [
                    Expanded(
                        child: _PriceField(
                            controller: _minCtrl,
                            hint: context.isAr ? 'الحد الأدنى' : 'Min')),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('—',
                            style: TextStyle(color: context.col.ink3))),
                    Expanded(
                        child: _PriceField(
                            controller: _maxCtrl,
                            hint: context.isAr ? 'الحد الأقصى' : 'Max')),
                  ]),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                ],

                // ── Deals Only ────────────────────────────────────────────
                GestureDetector(
                  onTap: () => setState(() => _onSale = !_onSale),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      Text(context.s.dealsOnly,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: context.col.ink1)),
                      const Spacer(),
                      Switch(
                        value: _onSale,
                        onChanged: (v) => setState(() => _onSale = v),
                        activeColor: AppColors.primary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ]),
                  ),
                ),
                const Divider(height: 1),

                // ── Rating (only shown when products in scope actually have reviews,
                //    or a rating is already picked so it can be cleared) ──
                Builder(builder: (_) {
                  final hasReviews = (opts?.hasReviews ?? false) || _rating != null;
                  if (!hasReviews) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(
                          context.isAr ? 'الحد الأدنى للتقييم' : 'Min. Rating',
                          _ratingExpanded,
                          () => setState(
                              () => _ratingExpanded = !_ratingExpanded)),
                      if (_ratingExpanded) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [3, 4, 5].map((star) {
                            final selected = _rating == star;
                            return GestureDetector(
                              onTap: () => setState(
                                  () => _rating = selected ? null : star),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.adaptive(context)
                                      : context.col.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: selected
                                          ? AppColors.adaptive(context)
                                          : context.col.border,
                                      width: 1.5),
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.star_rounded,
                                          size: 14,
                                          color: selected
                                              ? Colors.white
                                              : AppColors.warn),
                                      const SizedBox(width: 4),
                                      Text(
                                          '$star+ ${context.isAr ? 'نجوم' : 'stars'}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: selected
                                                  ? Colors.white
                                                  : context.col.ink1)),
                                    ]),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                      ],
                    ],
                  );
                }),

                // ── Vendor / Seller ───────────────────────────────────
                Builder(builder: (_) {
                  final list = opts?.vendors ?? const <_Vendor>[];
                  if (list.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(
                          context.s.storeLabel,
                          _vendorExpanded,
                          () => setState(
                              () => _vendorExpanded = !_vendorExpanded)),
                      if (_vendorExpanded) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                          ..._visible('vendor', list,
                                  (v) => _vendorIds.contains(v.id))
                              .map((v) {
                            final sel = _vendorIds.contains(v.id);
                            return GestureDetector(
                              onTap: () => setState(() => sel
                                  ? _vendorIds.remove(v.id)
                                  : _vendorIds.add(v.id)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                    color: sel
                                        ? AppColors.adaptive(context)
                                        : context.col.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: sel
                                            ? AppColors.adaptive(context)
                                            : context.col.border,
                                        width: 1.5)),
                                child: Text(v.name,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: sel
                                            ? Colors.white
                                            : context.col.ink1)),
                              ),
                            );
                          }),
                          ..._showAll('vendor', list.length),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                }),
              ],
            ),
          ),

          // Apply button
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(context.s.applyFilters,
                    style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontFamilyFallback: ['Tajawal'],
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The sheet's brand / size / store options failed to load: say so, offer Retry.
class _OptionsError extends StatelessWidget {
  final VoidCallback onRetry;
  const _OptionsError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(children: [
        Icon(Icons.error_outline_rounded, size: 18, color: context.col.ink3),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
              context.tr('تعذّر تحميل خيارات الفلترة',
                  'Could not load the filter options'),
              style: TextStyle(
                  fontFamily: 'Manrope',
                  fontFamilyFallback: const ['Tajawal'],
                  fontSize: 13,
                  color: context.col.ink2)),
        ),
        TextButton(onPressed: onRetry, child: Text(context.s.retry)),
      ]),
    );
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CatChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.adaptive(context) : context.col.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color:
                  selected ? AppColors.adaptive(context) : context.col.border,
              width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : context.col.ink1,
            )),
      ),
    );
  }
}

// ── Category chips row ────────────────────────────────────────────────────────
class _CategoryChipsRow extends StatelessWidget {
  final List<_SuggestedCategory> categories;
  final bool isAr;
  final void Function(int id, String name) onTap;
  const _CategoryChipsRow(
      {required this.categories, required this.isAr, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text(
            isAr ? 'ابحث في:' : 'Browse in:',
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: context.col.ink3),
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final cat = categories[i];
              final label = isAr ? cat.nameAr : cat.name;
              return GestureDetector(
                onTap: () => onTap(cat.id, label),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    // White + grey outline, like the «الأقسام» chips on the
                    // search screen (Emad, 2026-10-23: not the old mint teal).
                    color: context.col.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.col.border),
                  ),
                  child: Text(
                    '$label  ${cat.productCount}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Manrope',
                      fontFamilyFallback: const ['Tajawal'],
                      color: context.col.ink1,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
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
      // Tapping anywhere outside the field dismisses the numeric keyboard.
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      style: const TextStyle(
          fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            fontSize: 12,
            color: context.col.ink3,
            fontFamily: 'Manrope',
            fontFamilyFallback: ['Tajawal']),
        // Clear background, outline only (Emad, 2026-10-23).
        filled: false,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.col.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.col.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
