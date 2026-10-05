import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/product.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/product_card.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../../core/utils/responsive.dart';
import '../widgets/store_filters.dart';
import '../../../shared/widgets/store_logo_placeholder.dart';

class VendorStoreScreen extends ConsumerStatefulWidget {
  final int vendorId;
  const VendorStoreScreen({required this.vendorId, super.key});

  @override
  ConsumerState<VendorStoreScreen> createState() => _VendorStoreScreenState();
}

class _VendorStoreScreenState extends ConsumerState<VendorStoreScreen> {
  Vendor? _vendor;
  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;
  List<Product> _products = [];
  bool _loadingVendor = true;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  static const _perPage = 20;
  int _gridCols = 2;
  double _gridColW = kCardDesignW;
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  StoreFilters _filters = const StoreFilters();
  int _reqSeq = 0; // newest products request wins; older responses are dropped
  int _reviewsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadVendor();
    _loadCategories();
    _loadReviewsCount();
    _loadProducts(1);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReviewsCount() async {
    try {
      final res = await ApiClient.instance.dio
          .get('/vendors/${widget.vendorId}/reviews');
      final total = (res.data?['data']?['total'] as num?)?.toInt() ?? 0;
      if (mounted) setState(() => _reviewsCount = total);
    } catch (_) {/* no rating line is better than an error */}
  }

  void _onSearchChanged(String _) {
    setState(() {}); // shows/hides the clear button
    _searchDebounce?.cancel();
    _searchDebounce =
        Timer(const Duration(milliseconds: 400), () => _loadProducts(1));
  }

  Future<void> _openFilters() async {
    final result = await showStoreFilterSheet(context, _filters,
        vendorId: widget.vendorId, categoryId: _selectedCategoryId);
    if (result != null && mounted) {
      setState(() => _filters = result);
      _loadProducts(1);
    }
  }

  Future<void> _loadVendor() async {
    try {
      final res =
          await ApiClient.instance.dio.get('/vendors/${widget.vendorId}');
      if (mounted)
        setState(() {
          _vendor = Vendor.fromJson(res.data['data']);
          _loadingVendor = false;
        });
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      if (mounted) setState(() => _loadingVendor = false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final res = await ApiClient.instance.dio
          .get('/vendors/${widget.vendorId}/categories');
      final list =
          (res.data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) setState(() => _categories = list);
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
    }
  }

  Future<void> _loadProducts(int page, {bool resetFilter = false}) async {
    final seq = ++_reqSeq; // pin this request; a newer one supersedes it
    final q = _searchCtrl.text.trim();
    if (page == 1) {
      if (mounted)
        setState(() {
          _loading = true;
          _loadingMore = false;
        });
    } else {
      if (_loadingMore) return;
      if (mounted) setState(() => _loadingMore = true);
    }
    try {
      final res =
          await ApiClient.instance.dio.get('/products', queryParameters: {
        'vendor_id': widget.vendorId,
        'per_page': _perPage,
        'has_image': 1,
        'page': page,
        'sort': _filters.sort,
        if (_selectedCategoryId != null) 'category_id': _selectedCategoryId,
        if (q.isNotEmpty) 'search': q,
        if (_filters.minPrice != null) 'min_price': _filters.minPrice,
        if (_filters.maxPrice != null) 'max_price': _filters.maxPrice,
        if (_filters.onSaleOnly) 'on_sale': '1',
        if (_filters.minRating != null) 'min_rating': _filters.minRating,
        if (_filters.brands.isNotEmpty) 'brands[]': _filters.brands.toList(),
        if (_filters.attributeValueIds.isNotEmpty)
          'attribute_value_ids[]': _filters.attributeValueIds.toList(),
      });
      final list = (res.data['data']['data'] as List?)
              ?.map((p) => Product.fromJson(p))
              .toList() ??
          [];
      final total = (res.data['data']['total'] as num?)?.toInt() ?? list.length;
      // Drop a late response if the shopper changed category, search or filters meanwhile.
      if (mounted && seq == _reqSeq) {
        setState(() {
          if (page == 1)
            _products = list;
          else
            _products = [..._products, ...list];
          _page = page;
          // Stop when a short page arrives (no more) or we've reached the total.
          _hasMore = list.length == _perPage && _products.length < total;
          _loading = false;
          _loadingMore = false;
        });
      }
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      if (mounted)
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
    }
  }

  void _selectCategory(int? catId) {
    if (_selectedCategoryId == catId) return;
    setState(() => _selectedCategoryId = catId);
    _loadProducts(1);
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    final vendorName = _vendor != null
        ? (isAr && _vendor!.storeNameAr.isNotEmpty
            ? _vendor!.storeNameAr
            : _vendor!.storeName)
        : '';

    // The grid is a sliver, so there's no LayoutBuilder box to measure — take
    // the width from MediaQuery (grid spans the screen minus its 12+12 padding).
    final gridW = MediaQuery.sizeOf(context).width - 24;
    _gridCols = productGridColumns(gridW);
    _gridColW =
        productColumnWidth(maxWidth: gridW, columns: _gridCols, spacing: 12);

    return Scaffold(
      backgroundColor: context.col.bg,
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          // Infinite scroll — auto-load the next page as the user nears the bottom
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 600 &&
              _hasMore &&
              !_loadingMore &&
              !_loading) {
            _loadProducts(_page + 1);
          }
          return false;
        },
        child: CustomScrollView(
          slivers: [
            // ── Banner: the top of the screen, back button floats over it ──
            // The logo straddles the banner's bottom edge (opposite the back button) and is
            // painted over the info block, so the name stays right under the banner.
            SliverToBoxAdapter(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(children: [
                    _StoreHero(vendor: _vendor, loading: _loadingVendor),
                    // ── Name, description, rating ──
                    _StoreInfo(
                      vendor: _vendor,
                      name: vendorName,
                      reviewsCount: _reviewsCount,
                    ),
                  ]),
                  if (_vendor != null && _StoreHero.showsBadge(_vendor, _loadingVendor))
                    PositionedDirectional(
                      end: 16,
                      top: _StoreHero.heightOf(context) - _StoreHero.badgeSize / 2,
                      child: _StoreLogoBadge(logo: _vendor!.logo),
                    ),
                ],
              ),
            ),

            // ── Search this store + filters ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: Row(children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: context.col.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.col.borderStrong),
                      ),
                      child: Row(children: [
                        Icon(Icons.search, size: 18, color: context.col.ink1),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: _onSearchChanged,
                            textInputAction: TextInputAction.search,
                            style: TextStyle(
                                color: context.col.ink0, fontSize: 13),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: false,
                              hintText: context.s.searchInStoreHint,
                              hintStyle: TextStyle(
                                  color: context.col.ink1, fontSize: 13),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 13),
                            ),
                          ),
                        ),
                        if (_searchCtrl.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              _onSearchChanged('');
                            },
                            child: Icon(Icons.close,
                                size: 18, color: context.col.ink1),
                          ),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _openFilters,
                    child: Stack(clipBehavior: Clip.none, children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: context.col.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _filters.isActive
                                ? AppColors.teal
                                : context.col.borderStrong,
                            width: _filters.isActive ? 1.4 : 1,
                          ),
                        ),
                        child: Icon(Icons.tune_rounded,
                            size: 20, color: context.col.ink0),
                      ),
                      if (_filters.isActive)
                        const Positioned(
                          top: -3,
                          right: -3,
                          child: CircleAvatar(
                              radius: 5, backgroundColor: AppColors.primary),
                        ),
                    ]),
                  ),
                ]),
              ),
            ),

            // ── Category filter carousel ─────────────────────────────
            if (_categories.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  color: context.col.surface,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        _CatChip(
                          label: isAr ? 'الكل' : 'All',
                          selected: _selectedCategoryId == null,
                          onTap: () => _selectCategory(null),
                        ),
                        ..._categories.map((cat) {
                          final label = isAr
                              ? (cat['name_ar']?.toString().isNotEmpty == true
                                  ? cat['name_ar']
                                  : cat['name'])
                              : cat['name'];
                          return _CatChip(
                            label: label ?? '',
                            selected: _selectedCategoryId == cat['id'],
                            onTap: () => _selectCategory(cat['id'] as int),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Section header ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text(context.s.storeProducts,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),

            // ── Products grid ────────────────────────────────────────
            if (_loading)
              const SliverToBoxAdapter(
                  child: SizedBox(
                      height: 200,
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary))))
            else if (_products.isEmpty)
              SliverToBoxAdapter(
                  child: Center(
                      child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(context.s.noProductsNow,
                              style: TextStyle(color: context.col.ink3)))))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => ProductCard(product: _products[i]),
                    childCount: _products.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _gridCols,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: productCellHeight(_gridColW).ceilToDouble(),
                  ),
                ),
              ),

            // ── Auto-load footer (infinite scroll) ───────────────────
            if (_loadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Center(
                      child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                              color: AppColors.primary))),
                ),
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
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
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : context.col.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? AppColors.primary : context.col.border,
                width: selected ? 0 : 1),
          ),
          child: Text(label,
              style: TextStyle(
                  fontFamily: 'Manrope',
                  fontFamilyFallback: ['Tajawal'],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : context.col.ink1)),
        ),
      );
}

/// Banner at the very top of the screen (under the status bar), with a floating back button.
/// A store with no banner gets a brand-coloured block carrying its logo instead.
class _StoreHero extends StatelessWidget {
  final Vendor? vendor;
  final bool loading;
  const _StoreHero({required this.vendor, required this.loading});

  static const badgeSize = 60.0;

  static double heightOf(BuildContext context) =>
      MediaQuery.paddingOf(context).top + MediaQuery.sizeOf(context).width / 3.4;

  /// A store with no banner already shows its logo centred; otherwise the logo is a badge
  /// (the default store mark when it has no logo).
  static bool showsBadge(Vendor? v, bool loading) =>
      !loading && v != null && (v.banner ?? '').isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final height = heightOf(context);
    final banner = vendor?.banner;
    final logo = vendor?.logo;

    Widget bg;
    if (banner != null && banner.isNotEmpty) {
      bg = CachedNetworkImage(
        imageUrl: banner,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => const ColoredBox(color: AppColors.primary),
      );
    } else {
      bg = DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.teal600],
          ),
        ),
        child: Center(
          child: (!loading && logo != null && logo.isNotEmpty)
              ? ClipOval(
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child:
                        CachedNetworkImage(imageUrl: logo, fit: BoxFit.cover),
                  ),
                )
              : Icon(Icons.storefront_outlined,
                  size: 54, color: Colors.white.withValues(alpha: 0.85)),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          bg,
          PositionedDirectional(
            top: top + 8,
            start: 12,
            child: GestureDetector(
              onTap: () =>
                  context.canPop() ? context.pop() : context.go('/browse'),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back,
                    size: 20, color: Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Store name, a short description and the rating line, sitting under the banner.
class _StoreInfo extends StatelessWidget {
  final Vendor? vendor;
  final String name;
  final int reviewsCount;
  const _StoreInfo(
      {required this.vendor, required this.name, required this.reviewsCount});

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    final v = vendor;
    if (v == null) return const SizedBox(height: 16);
    final desc = (isAr && (v.descriptionAr ?? '').trim().isNotEmpty
            ? v.descriptionAr
            : v.description)
        ?.trim();
    final rating = v.averageRating ?? 0;
    final hasReviews = reviewsCount > 0 && rating > 0;

    return Container(
      color: context.col.surface,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: context.col.ink0,
              fontFamily: 'Manrope',
              fontFamilyFallback: const ['Tajawal'],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (int i = 1; i <= 5; i++)
                Icon(
                  hasReviews && i <= rating.round()
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 18,
                  color: hasReviews && i <= rating.round()
                      ? AppColors.gold
                      : context.col.ink3,
                ),
              const SizedBox(width: 6),
              Text(
                hasReviews
                    ? '${rating.toStringAsFixed(1)} ${context.s.reviewsN(reviewsCount)}'
                    : context.s.noReviews,
                style: TextStyle(
                  fontSize: 12,
                  color: context.col.ink3,
                  fontFamily: 'Manrope',
                  fontFamilyFallback: const ['Tajawal'],
                ),
              ),
            ],
          ),
          if (desc != null && desc.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              desc,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: context.col.ink1,
                fontFamily: 'Manrope',
                fontFamilyFallback: const ['Tajawal'],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StoreLogoBadge extends StatelessWidget {
  final String? logo;
  const _StoreLogoBadge({required this.logo});

  @override
  Widget build(BuildContext context) => Container(
        width: _StoreHero.badgeSize,
        height: _StoreHero.badgeSize,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 8,
            ),
          ],
        ),
        child: ClipOval(
          child: (logo ?? '').isEmpty
              ? const StoreLogoPlaceholder()
              : CachedNetworkImage(
                  imageUrl: logo!,
                  fit: BoxFit.cover,
                  memCacheWidth: 200,
                  errorWidget: (_, __, ___) => const StoreLogoPlaceholder(),
                ),
        ),
      );
}
