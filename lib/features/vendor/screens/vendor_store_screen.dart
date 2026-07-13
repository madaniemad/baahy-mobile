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

  @override
  void initState() {
    super.initState();
    _loadVendor();
    _loadCategories();
    _loadProducts(1);
  }

  Future<void> _loadVendor() async {
    try {
      final res = await ApiClient.instance.dio.get('/vendors/${widget.vendorId}');
      if (mounted) setState(() { _vendor = Vendor.fromJson(res.data['data']); _loadingVendor = false; });
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      if (mounted) setState(() => _loadingVendor = false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final res = await ApiClient.instance.dio.get('/vendors/${widget.vendorId}/categories');
      final list = (res.data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) setState(() => _categories = list);
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
    }
  }

  Future<void> _loadProducts(int page, {bool resetFilter = false}) async {
    if (page == 1) {
      if (mounted) setState(() => _loading = true);
    } else {
      if (_loadingMore) return;
      if (mounted) setState(() => _loadingMore = true);
    }
    try {
      final res = await ApiClient.instance.dio.get('/products', queryParameters: {
        'vendor_id': widget.vendorId,
        'per_page': _perPage,
        'has_image': 1,
        'page': page,
        if (_selectedCategoryId != null) 'category_id': _selectedCategoryId,
      });
      final list = (res.data['data']['data'] as List?)
          ?.map((p) => Product.fromJson(p)).toList() ?? [];
      final total = (res.data['data']['total'] as num?)?.toInt() ?? list.length;
      if (mounted) {
        setState(() {
          if (page == 1) _products = list;
          else _products = [..._products, ...list];
          _page = page;
          _hasMore = _products.length < total;
          _loading = false;
          _loadingMore = false;
        });
      }
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      if (mounted) setState(() { _loading = false; _loadingMore = false; });
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
        ? (isAr && _vendor!.storeNameAr.isNotEmpty ? _vendor!.storeNameAr : _vendor!.storeName)
        : '';

    // The grid is a sliver, so there's no LayoutBuilder box to measure — take
    // the width from MediaQuery (grid spans the screen minus its 12+12 padding).
    final gridW = MediaQuery.sizeOf(context).width - 24;
    _gridCols = productGridColumns(gridW);
    _gridColW = productColumnWidth(
      maxWidth: gridW, columns: _gridCols, spacing: 12);

    return Scaffold(
      backgroundColor: context.col.bg,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ──────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            title: _loadingVendor
                ? const SizedBox.shrink()
                : Text(vendorName.isNotEmpty ? vendorName : context.s.storeLabel,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                      fontSize: 17, fontWeight: FontWeight.w700)),
          ),

          // ── Banner ──────────────────────────────────────────────
          if (_vendor?.banner != null)
            SliverToBoxAdapter(
              child: AspectRatio(
                aspectRatio: 3.0,
                child: CachedNetworkImage(
                  imageUrl: _vendor!.banner!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
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
                                ? cat['name_ar'] : cat['name'])
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),

          // ── Products grid ────────────────────────────────────────
          if (_loading)
            const SliverToBoxAdapter(
              child: SizedBox(height: 200,
                child: Center(child: CircularProgressIndicator(color: AppColors.primary))))
          else if (_products.isEmpty)
            SliverToBoxAdapter(
              child: Center(child: Padding(
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

          // ── Load more ────────────────────────────────────────────
          if (_hasMore || _loadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: _loadingMore
                    ? const Center(child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(color: AppColors.primary)))
                    : OutlinedButton(
                        onPressed: () => _loadProducts(_page + 1),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          side: BorderSide(color: context.col.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(context.s.viewMore,
                          style: TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w700,
                            color: context.col.ink0)),
                      ),
              ),
            )
          else
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
          fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : context.col.ink1)),
    ),
  );
}
