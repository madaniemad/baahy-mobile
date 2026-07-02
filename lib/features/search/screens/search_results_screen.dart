import 'dart:async';
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

class _SuggestedCategory {
  final int id;
  final String name;
  final String nameAr;
  final int productCount;
  const _SuggestedCategory({required this.id, required this.name, required this.nameAr, required this.productCount});
  factory _SuggestedCategory.fromJson(Map<String, dynamic> j) => _SuggestedCategory(
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

class _Vendor {
  final int id;
  final String name;
  const _Vendor({required this.id, required this.name});
}


class _FilterOptions {
  final List<_AttrType> attrTypes;
  final List<String> brands;
  final List<_Vendor> vendors;
  const _FilterOptions({this.attrTypes = const [], this.brands = const [], this.vendors = const []});
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
    final vendors = (data['vendors'] as List? ?? []).map((v) {
      final id = v is Map ? (v['id'] as int? ?? 0) : 0;
      final name = v is Map ? (v['store_name'] ?? v['name'] ?? '').toString() : v.toString();
      return _Vendor(id: id, name: name);
    }).where((v) => v.id != 0 && v.name.isNotEmpty).toList();
    return _FilterOptions(attrTypes: types, brands: brands, vendors: vendors);
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
  final int? vendorId;

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
    this.vendorId,
  });

  bool get isActive =>
      minPrice != null || maxPrice != null || minRating != null ||
      inStockOnly || featuredOnly || categoryId != null ||
      attributeValueIds.isNotEmpty || (brand != null && brand!.isNotEmpty) ||
      vendorId != null;

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
    Object? vendorId = _unset,
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
    vendorId: identical(vendorId, _unset) ? this.vendorId : vendorId as int?,
  );

  static const _unset = Object();
}

class SearchResultsScreen extends ConsumerStatefulWidget {
  final String query;
  final String? pageTitle;
  final int? categoryId;
  final bool onSale;
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
    this.maxPrice,
    this.initialSort,
    this.initialBrand,
    this.visionProducts,
    super.key,
  });

  @override
  ConsumerState<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  final _scrollCtrl = ScrollController();
  List<Product> _products = [];
  List<_SuggestedCategory> _suggestedCategories = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  bool _hasMore = true;
  late String _sort;
  late _FilterState _filters;

  @override
  void initState() {
    super.initState();
    _sort = widget.initialSort ?? 'random';
    _filters = _FilterState(
      categoryId: widget.categoryId,
      maxPrice: widget.maxPrice,
      inStockOnly: false,
      brand: widget.initialBrand,
    );
    if (widget.visionProducts != null) {
      // Use pre-searched products from camera — skip API call
      _products = widget.visionProducts!;
      _loading  = false;
      _hasMore  = false;
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
        if (_filters.vendorId != null) 'vendor_id': _filters.vendorId,
        if (widget.onSale) 'on_sale': '1',
        ..._filters.attributeValueIds.isNotEmpty
            ? {'attribute_value_ids[]': _filters.attributeValueIds.toList()} : {},
      });
      final data = res.data['data'];
      final newProducts = (data['data'] as List).map((p) => Product.fromJson(p)).toList();
      final rawSuggestions = res.data['suggested_categories'] as List? ?? [];
      setState(() {
        _products = reset ? newProducts : [..._products, ...newProducts];
        if (reset) {
          _suggestedCategories = rawSuggestions
              .map((c) => _SuggestedCategory.fromJson(c as Map<String, dynamic>))
              .toList();
        }
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
      backgroundColor: context.col.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (_) => _FilterSheet(initial: _filters, scopeCategoryId: widget.categoryId),
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

  void _selectSubcat(int? catId) {
    setState(() => _filters = _filters.copyWith(
      categoryId: catId,
      categoryName: null,
      attributeValueIds: const {},
      brand: null,
      vendorId: null,
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

    // Banners: use selected sub-cat's banners, fallback to scope cat's banners
    final bannerCatId = _filters.categoryId ?? widget.categoryId;
    final bannerCat = bannerCatId != null ? _findCategory(allCategories, bannerCatId) : null;
    var banners = bannerCat?.banners ?? <CategoryBanner>[];
    if (banners.isEmpty && bannerCatId != widget.categoryId && scopeCat != null) {
      banners = scopeCat.banners;
    }

    return Scaffold(
      backgroundColor: context.col.bg,
      appBar: AppBar(
        backgroundColor: context.col.surface,
        elevation: 0,
        title: Text(
          widget.pageTitle ?? (widget.query.isNotEmpty ? widget.query : context.s.products),
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                onPressed: _openFilters,
                icon: Icon(Icons.tune_rounded, color: context.col.ink0),
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
            icon: Icon(Icons.sort, color: context.col.ink0),
            onSelected: (v) { _sort = v; _fetch(reset: true); },
            itemBuilder: (_) => _sortOptions.map((opt) =>
              PopupMenuItem(value: opt.$1, child: Text(opt.$2,
                style: TextStyle(fontWeight: _sort == opt.$1 ? FontWeight.w700 : FontWeight.normal))
            )).toList(),
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
          // Banner slider
          if (banners.isNotEmpty) _BannerSlider(banners: banners),
          // Category chips — shown when search spans multiple categories and no category filter active
          if (_suggestedCategories.length >= 2 &&
              _filters.categoryId == null &&
              widget.categoryId == null)
            _CategoryChipsRow(
              categories: _suggestedCategories,
              isAr: Localizations.localeOf(context).languageCode == 'ar',
              onTap: (catId, catName) {
                setState(() => _filters = _filters.copyWith(categoryId: catId, categoryName: catName));
                _fetch(reset: true);
              },
            ),
          // Products
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 64, color: context.col.ink4),
                            const SizedBox(height: 12),
                            Text(context.s.noResultsFound,
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: context.col.ink2)),
                            if (_filters.isActive) ...[
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() => _filters = const _FilterState());
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
                                  fontFamily: 'Cairo')),
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(builder: (_, box) {
                        const srcW = 165.0;
                        const srcH = 345.0;
                        final colW = (box.maxWidth - 12 - 24) / 2;
                        final cellH = srcH * (colW / srcW);
                        return GridView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.all(12),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            mainAxisExtent: cellH.ceilToDouble(),
                          ),
                          itemCount: _products.length + (_loadingMore ? 2 : 0),
                          itemBuilder: (_, i) {
                            if (i >= _products.length) return const ProductCardSkeleton();
                            return FittedBox(
                              fit: BoxFit.contain,
                              alignment: Alignment.topCenter,
                              child: SizedBox(
                                width: srcW,
                                child: ProductCard(product: _products[i], width: srcW),
                              ),
                            );
                          },
                        );
                      }),
          ),
        ],
      ),
    );
  }
}

// ── Subcategory tab row ───────────────────────────────────────────────────────

class _SubcatTabs extends StatelessWidget {
  final List<Category> categories;
  final int? selectedId;
  final ValueChanged<int?> onSelect;
  const _SubcatTabs({required this.categories, required this.selectedId, required this.onSelect});

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
                const SizedBox(width: 8),
                ...categories.map((cat) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Tab(
                    label: isAr ? cat.nameAr : cat.name,
                    selected: selectedId == cat.id,
                    onTap: () => onSelect(selectedId == cat.id ? null : cat.id),
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
  const _Tab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.adaptive(context) : context.col.surfaceSoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? const Color(0xFFF0F0F0) : context.col.ink1,
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
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
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
                        if (banner.action != null && banner.action!.isNotEmpty) {
                          safePush(context, banner.action!);
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: banner.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: context.col.cardImageBg),
                          errorWidget: (_, __, ___) => Container(color: context.col.cardImageBg),
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
                children: List.generate(widget.banners.length, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _current == i ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _current == i ? context.col.ink0 : context.col.border,
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
  int? _vendorId;
  bool _catExpanded = true;
  bool _priceExpanded = true;
  bool _ratingExpanded = true;
  Map<int, bool> _attrExpanded = {};
  bool _brandExpanded = true;
  bool _vendorExpanded = true;
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
    _vendorId = widget.initial.vendorId;
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
      vendorId: _vendorId,
    ));
  }

  // The category driving filter-option scoping: user's in-sheet pick, else page scope.
  int? get _effectiveCategoryId => _categoryId ?? widget.scopeCategoryId;

  // Cascade-clear dependent selections when category changes.
  void _selectCategory(int? catId, String? catName) {
    setState(() {
      _categoryId = catId;
      _categoryName = catName;
      // Clear selections that are category-specific.
      _attrValueIds = {};
      _brand = null;
      _vendorId = null;
    });
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
      _vendorId = null;
    });
  }

  Widget _sectionHeader(String title, bool expanded, VoidCallback toggle) {
    return GestureDetector(
      onTap: toggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Text(title,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700,
              color: context.col.ink1)),
          const Spacer(),
          Icon(expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
            color: context.col.ink3, size: 20),
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
                decoration: BoxDecoration(color: context.col.border,
                  borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              Row(children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: context.col.surfaceSoft,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Icon(Icons.close_rounded, size: 18, color: context.col.ink1),
                  ),
                ),
                const SizedBox(width: 12),
                Text(context.s.filters,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton(onPressed: _reset,
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              children: [

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
                          selected: _categoryId == null || _categoryId == widget.scopeCategoryId,
                          onTap: () => _selectCategory(null, null),
                        ),
                        ...scopedCats.map((cat) => _CatChip(
                          label: isAr ? cat.nameAr : cat.name,
                          selected: _categoryId == cat.id ||
                              cat.children.any((c) => c.id == _categoryId),
                          onTap: () => _selectCategory(cat.id, isAr ? cat.nameAr : cat.name),
                        )),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                  ],
                ],

                // ── Attributes (Size, Color, etc.) ────────────────────
                Consumer(builder: (ctx, attrRef, _) {
                  final opts = attrRef.watch(_filterOptionsProvider(_FilterScope(
                    categoryId: _effectiveCategoryId, brand: _brand)));
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
                              _sectionHeader(typeLabel, _attrExpanded[attrType.id] ?? true,
                                () => setState(() => _attrExpanded[attrType.id] = !(_attrExpanded[attrType.id] ?? true))),
                              if (_attrExpanded[attrType.id] ?? true) ...[
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
                                            color: color ?? context.col.bg,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: sel ? context.col.ink0 : context.col.border,
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
                                          color: sel ? AppColors.adaptive(context) : context.col.surface,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: sel ? AppColors.adaptive(context) : context.col.border,
                                            width: 1.5)),
                                        child: Text(valLabel,
                                          style: TextStyle(
                                            fontSize: 12, fontWeight: FontWeight.w600,
                                            color: sel ? const Color(0xFFF0F0F0) : context.col.ink1)),
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
                    categoryId: _effectiveCategoryId)));
                  return opts.maybeWhen(
                    data: (options) {
                      if (options.brands.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(context.s.brand, _brandExpanded,
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
                                      color: sel ? context.col.ink0 : context.col.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: sel ? context.col.ink0 : context.col.border,
                                        width: 1.5)),
                                    child: Text(b,
                                      style: TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.w600,
                                        color: sel ? Colors.white : context.col.ink1)),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                          ],
                        ],
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  );
                }),

                // ── Price ─────────────────────────────────────────────────
                _sectionHeader(context.isAr ? 'نطاق السعر (د.ل)' : 'Price Range (LD)', _priceExpanded,
                  () => setState(() => _priceExpanded = !_priceExpanded)),

                if (_priceExpanded) ...[
                  Row(children: [
                    Expanded(child: _PriceField(controller: _minCtrl, hint: context.isAr ? 'الحد الأدنى' : 'Min')),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('—', style: TextStyle(color: context.col.ink3))),
                    Expanded(child: _PriceField(controller: _maxCtrl, hint: context.isAr ? 'الحد الأقصى' : 'Max')),
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
                      Text(context.s.dealsOnly,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700,
                          color: context.col.ink1)),
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
                      Text(context.s.inStockOnly,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700,
                          color: context.col.ink1)),
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
                _sectionHeader(context.isAr ? 'الحد الأدنى للتقييم' : 'Min. Rating', _ratingExpanded,
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
                            color: selected ? context.col.ink0 : context.col.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? context.col.ink0 : context.col.border,
                              width: 1.5),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.star_rounded, size: 14,
                              color: selected ? Colors.white : AppColors.warn),
                            const SizedBox(width: 4),
                            Text('$star+ ${context.isAr ? 'نجوم' : 'stars'}',
                              style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: selected ? Colors.white : context.col.ink1)),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                ],

                // ── Vendor / Seller ───────────────────────────────────
                Consumer(builder: (ctx, vendorRef, _) {
                  final optsAsync = vendorRef.watch(_filterOptionsProvider(_FilterScope(
                    categoryId: _effectiveCategoryId)));
                  final list = optsAsync.maybeWhen(data: (o) => o.vendors, orElse: () => <_Vendor>[]);
                  if (list.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(context.s.storeLabel, _vendorExpanded,
                        () => setState(() => _vendorExpanded = !_vendorExpanded)),
                      if (_vendorExpanded) ...[
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: list.map((v) {
                            final sel = _vendorId == v.id;
                            return GestureDetector(
                              onTap: () => setState(() => _vendorId = sel ? null : v.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: sel ? context.col.ink0 : context.col.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: sel ? context.col.ink0 : context.col.border,
                                    width: 1.5)),
                                child: Text(v.name,
                                  style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600,
                                    color: sel ? Colors.white : context.col.ink1)),
                              ),
                            );
                          }).toList(),
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
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(context.s.applyFilters,
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800,
                    fontSize: 15, color: context.col.ink0)),
              ),
            ),
          ),
        ],
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
          color: selected ? AppColors.adaptive(context) : context.col.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.adaptive(context) : context.col.border,
            width: 1.5),
        ),
        child: Text(label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? const Color(0xFFF0F0F0) : context.col.ink1,
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
  const _CategoryChipsRow({required this.categories, required this.isAr, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text(
            isAr ? 'ابحث في:' : 'Browse in:',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: context.col.ink3),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.teal50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.teal, width: 1),
                  ),
                  child: Text(
                    '$label  ${cat.productCount}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Cairo',
                      color: AppColors.teal600,
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
      style: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: context.col.ink3, fontFamily: 'Cairo'),
        filled: true, fillColor: context.col.surfaceSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.col.border)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.col.border)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
