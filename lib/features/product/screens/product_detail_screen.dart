import '../../../core/utils/delivery.dart';
import '../../../core/providers/tier_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/app_config.dart';
import '../../../core/models/product.dart';
import '../../../core/models/review.dart';
import '../../../core/providers/address_provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/providers/shipping_provider.dart';
import '../../../core/utils/navigation.dart';
import '../../../core/providers/wishlist_provider.dart';
import '../../../core/providers/recently_viewed_provider.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/product_card.dart';
import '../../../shared/widgets/baahy_plus_badge.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../../core/utils/responsive.dart';

part '../widgets/product_detail_widgets.dart';


final _productDetailProvider = FutureProvider.autoDispose.family<Product, int>((ref, id) async {
  final res = await ApiClient.instance.dio.get('/products/$id');
  return Product.fromJson(res.data['data']);
});

final _relatedProductsProvider = FutureProvider.autoDispose.family<List<Product>, int>((ref, categoryId) async {
  final res = await ApiClient.instance.dio.get('/products',
    queryParameters: {'category_id': categoryId, 'per_page': 4, 'sort': 'popular'});
  return (res.data['data']['data'] as List?)
      ?.map((p) => Product.fromJson(p)).toList() ?? [];
});

final _sisterProductsProvider = FutureProvider.autoDispose.family<List<Product>, int>((ref, parentCategoryId) async {
  final res = await ApiClient.instance.dio.get('/products',
    queryParameters: {'category_id': parentCategoryId, 'per_page': 10, 'sort': 'popular'});
  return (res.data['data']['data'] as List?)
      ?.map((p) => Product.fromJson(p)).toList() ?? [];
});

final _productReviewsProvider = FutureProvider.autoDispose.family<List<Review>, int>((ref, productId) async {
  final res = await ApiClient.instance.dio.get('/products/$productId/reviews',
    queryParameters: {'per_page': 3});
  return (res.data['data'] as List?)
      ?.map((r) => Review.fromJson(r)).toList() ?? [];
});

class ProductDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const ProductDetailScreen({required this.id, super.key});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _imageIndex = 0;
  late final PageController _pageController;
  late final ScrollController _scrollController;
  bool _lazyTriggered = false;
  bool _viewLogged = false;
  ProductVariation? _selectedVariation;
  int _qty = 1;
  final Map<String, String> _selections = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _scrollController = ScrollController()
      ..addListener(() {
        if (!_lazyTriggered && _scrollController.offset > 500) {
          setState(() => _lazyTriggered = true);
        }
      });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _trySelectVariation(Product product) {
    if (product.variations.isEmpty) return;

    // Build all distinct values per attribute type
    final grouped = <String, Set<String>>{};
    for (final v in product.variations) {
      for (final a in v.attributes) {
        grouped.putIfAbsent(a.typeName, () => {}).add(a.value);
      }
    }

    // Auto-select attributes that have only one possible value (shown as label, not picker)
    for (final entry in grouped.entries) {
      if (entry.value.length == 1) {
        _selections.putIfAbsent(entry.key, () => entry.value.first);
      }
    }

    if (_selections.length < grouped.length) {
      _selectedVariation = null;
      _qty = 1;
      setState(() {});
      return;
    }
    final match = product.variations.cast<ProductVariation?>().firstWhere(
      (v) => v!.attributes.every((a) => _selections[a.typeName] == a.value),
      orElse: () => null,
    );
    if (match != _selectedVariation) _qty = 1;
    _selectedVariation = match;
    setState(() {});
  }

  void _notifyMe(int productId) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.s.notifyAvailability),
        backgroundColor: AppColors.success,
      ));
  }

  /// Tapping "add to cart" with no size chosen used to give NO feedback at all: the
  /// SnackBar never appeared on this screen, so the button read as dead. The success
  /// path uses a modal sheet and that does render here, so use the same mechanism.
  /// "اختر المقاس أولاً" beats "اختر الخيارات أولاً": name what the product actually
  /// asks for, using the same label the selector shows.
  String _chooseOptionsMessage(Product product) {
    final labels = product.productAttributes
        .where((a) => a.values.isNotEmpty)
        .map((a) => attrLabel(context, a))
        .toList();
    if (labels.isEmpty) return context.s.selectOptions;
    final isAr = context.isAr;
    final joined = labels.length == 1
        ? labels.first
        : labels.length == 2
            ? '${labels[0]} ${isAr ? 'و' : 'and '}${labels[1]}'
            : labels.join(isAr ? '، ' : ', ');
    return isAr ? 'اختر $joined أولاً' : 'Select $joined first';
  }

  void _notice(String msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.col.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(msg,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(sheetCtx).pop(),
                child: Text(context.isAr ? 'حسناً' : 'OK'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _addToCart(Product product, {bool goToCart = false}) async {
    if ((product.variations.isNotEmpty || product.productType == 'variable') && _selectedVariation == null) {
      _notice(_chooseOptionsMessage(product));
      return;
    }
    if (_selectedVariation != null && !_selectedVariation!.inStock) {
      _notice(context.isAr ? 'هذا الخيار غير متوفر' : 'This option is out of stock');
      return;
    }
    await ref.read(cartProvider.notifier).add(
      product, variation: _selectedVariation, qty: _qty);
    Analytics.instance.addToCart(
      id: '${product.id}', name: product.name,
      price: _selectedVariation?.price ?? product.price, quantity: _qty);
    if (!mounted) return;
    if (goToCart) {
      safePush(context, '/cart');
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: context.col.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
        builder: (_) => _AddedToCartSheet(
          product: product,
          qty: _qty,
          onViewCart: () {
            context.go('/cart');
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    final productAsync = ref.watch(_productDetailProvider(widget.id));

    return Scaffold(
      backgroundColor: context.col.bg,
      body: productAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, __) {
          final is404 = err is DioException && err.response?.statusCode == 404;
          return Scaffold(
            backgroundColor: context.col.bg,
            appBar: AppBar(
              backgroundColor: context.col.bg, elevation: 0,
              leading: IconButton(
                onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                icon: Icon(Icons.arrow_back, color: context.col.ink0)),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(is404 ? Icons.inventory_2_outlined : Icons.wifi_off_rounded,
                    size: 56, color: context.col.ink3),
                  const SizedBox(height: 16),
                  Text(
                    is404
                      ? (context.isAr ? 'هذا المنتج لم يعد متاحاً' : 'This product is no longer available')
                      : context.s.loadProductFailed,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.col.ink1)),
                  const SizedBox(height: 8),
                  if (is404)
                    Text(
                      context.isAr ? 'ربما تم سحبه من المتجر أو نفذت الكمية بشكل نهائي.'
                                   : 'It may have been removed from the store.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: context.col.ink3, height: 1.5)),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                    child: Text(context.isAr ? 'العودة' : 'Go Back',
                      style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal']))),
                ]),
              ),
            ),
          );
        },
        data: (product) {
          // Track as recently viewed + auto-select any single-value attributes
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(recentlyViewedProvider.notifier).add(product);
            if (product.variations.isNotEmpty) _trySelectVariation(product);
            if (!_viewLogged) {
              _viewLogged = true;
              Analytics.instance.viewItem(
                id: '${product.id}',
                name: product.name,
                price: product.displayPrice,
                category: product.category?.nameAr ?? product.category?.name,
              );
            }
          });

          final name = isAr ? product.nameAr : product.name;
          final inWishlist = ref.watch(wishlistProvider).contains(product.id);
          // Use selected variation price, or cheapest in-stock variation, or product price
          final _inStockVarsForPrice = product.variations.where((v) => v.inStock || v.stockQuantity > 0).toList();
          final _cheapestInStock = _inStockVarsForPrice.isNotEmpty
              ? _inStockVarsForPrice.map((v) => v.salePrice ?? v.price).reduce((a, b) => a < b ? a : b)
              : null;
          final displayPrice = _selectedVariation?.salePrice
              ?? _selectedVariation?.price
              ?? _cheapestInStock
              ?? product.displayPrice;

          // For variable products: compute min/max across IN-STOCK variations only
          final inStockVars = product.variations.where((v) => v.inStock || v.stockQuantity > 0).toList();
          final varPrices = inStockVars.map((v) => v.salePrice ?? v.price).toList();
          final varMinPrice = varPrices.isNotEmpty
              ? varPrices.reduce((a, b) => a < b ? a : b) : null;
          final varMaxPrice = varPrices.isNotEmpty
              ? varPrices.reduce((a, b) => a > b ? a : b) : null;
          final showRange = product.productType == 'variable' &&
              _selectedVariation == null &&
              varMinPrice != null && varMaxPrice != null &&
              varMinPrice != varMaxPrice;

          final effectiveInStock = _selectedVariation != null
              ? _selectedVariation!.inStock
              : product.productType == 'variable' && product.variations.isNotEmpty
                  ? product.variations.any((v) => v.inStock)
                  : product.inStock;
          final _effQty = _selectedVariation?.stockQuantity ?? product.stockQuantity;
          final effectiveLowStock = effectiveInStock &&
              product.manageStock &&
              _effQty != null && _effQty > 0 && _effQty <= 5;

          return Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // ── Image gallery ────────────────────────────────
                  SliverAppBar(
                    expandedHeight: 340 + MediaQuery.of(context).padding.top,
                    pinned: true,
                    backgroundColor: context.col.surface,
                    elevation: 0,
                    leading: Padding(
                      padding: const EdgeInsets.all(8),
                      child: GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          decoration: BoxDecoration(
                            color: context.col.surface.withValues(alpha: 0.95),
                            shape: BoxShape.circle,
                            border: Border.all(color: context.col.border),
                            boxShadow: AppShadows.shadowLifted,
                          ),
                          child: Icon(Icons.arrow_back, size: 20, color: context.col.ink0),
                        ),
                      ),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                            child: PageView.builder(
                            controller: _pageController,
                            itemCount: product.images.isEmpty ? 1 : product.images.length,
                            onPageChanged: (i) => setState(() => _imageIndex = i),
                            itemBuilder: (_, i) {
                              if (product.images.isEmpty) {
                                return Container(color: context.col.bg,
                                  child: Icon(Icons.image_outlined, size: 80, color: context.col.border));
                              }
                              return InteractiveViewer(
                                minScale: 1.0,
                                maxScale: 4.0,
                                child: CachedNetworkImage(
                                  imageUrl: product.images[i], fit: BoxFit.contain,
                                  memCacheWidth: 1200));
                            },
                          )),
                          if (product.images.length > 1)
                            Positioned(
                              bottom: 12, left: 0, right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(product.images.length, (i) =>
                                  GestureDetector(
                                    onTap: () => _pageController.animateToPage(i,
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.symmetric(horizontal: 3),
                                      width: i == _imageIndex ? 18 : 6, height: 6,
                                      decoration: BoxDecoration(
                                        color: i == _imageIndex ? AppColors.primary : context.col.border,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  )),
                              ),
                            ),
                          if (product.images.length > 1)
                            Positioned(
                              right: 12, bottom: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text('${_imageIndex + 1}/${product.images.length}',
                                  style: const TextStyle(color: Colors.white,
                                    fontFamily: 'PlusJakartaSans', fontSize: 11)),
                              ),
                            ),
                          if (displayPrice < product.price)
                            Positioned(
                              bottom: 20,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.danger,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '-${((product.price - displayPrice) / product.price * 100).round()}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Thumbnail strip ───────────────────────────
                        if (product.images.length > 1)
                          SizedBox(
                            height: 62,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                              itemCount: product.images.length,
                              itemBuilder: (_, i) => GestureDetector(
                                onTap: () => _pageController.animateToPage(i,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut),
                                child: Container(
                                  width: 46, height: 46,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: i == _imageIndex ? AppColors.primary : context.col.border,
                                      width: i == _imageIndex ? 2 : 1),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child: CachedNetworkImage(
                                      imageUrl: product.images[i],
                                      fit: BoxFit.cover,
                                      memCacheWidth: 140,
                                      errorWidget: (_, __, ___) =>
                                        Container(color: context.col.surfaceSoft)),
                                  ),
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 10),

                        // ── Card 1: Title, price, rating ─────────────
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.col.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.col.border),
                            boxShadow: AppShadows.shadowLifted,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Brand / vendor name — tappable
                              if (product.brand != null && product.brand!.isNotEmpty)
                                GestureDetector(
                                  onTap: () => safePush(context,
                                    '/search/results?q=&brand=${Uri.encodeComponent(product.brand!)}'),
                                  child: Text(product.brand!,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                                      color: AppColors.primary)),
                                )
                              else if (product.vendor != null)
                                GestureDetector(
                                  onTap: () => safePush(context, '/vendors/${product.vendor!.id}'),
                                  child: Text(
                                    isAr
                                      ? (product.vendor!.storeNameAr.isNotEmpty
                                          ? product.vendor!.storeNameAr : product.vendor!.storeName)
                                      : product.vendor!.storeName,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                                      color: AppColors.primary)),
                                ),
                              const SizedBox(height: 6),
                              Text(name, style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800, height: 1.3)),
                              const SizedBox(height: 10),
                              // Full 5-star rating — hide if no reviews yet
                              if (product.averageRating != null && product.reviewsCount != null && product.reviewsCount! > 0)
                                GestureDetector(
                                  onTap: () => safePush(context, '/product/${product.id}/reviews'),
                                  child: Row(children: [
                                    RatingBarIndicator(
                                      rating: product.averageRating!,
                                      itemSize: 16,
                                      itemCount: 5,
                                      itemBuilder: (_, __) => const Icon(Icons.star_rounded, color: AppColors.gold),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(product.averageRating!.toStringAsFixed(1),
                                      style: const TextStyle(fontFamily: 'PlusJakartaSans',
                                        fontSize: 13, fontWeight: FontWeight.w700)),
                                    const SizedBox(width: 4),
                                    Text('(${product.reviewsCount})',
                                      style: TextStyle(color: context.col.ink3, fontSize: 12)),
                                    if (product.soldCount != null && product.soldCount! > 0) ...[
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 6),
                                        child: Text('·', style: TextStyle(color: context.col.ink3)),
                                      ),
                                      Text(context.s.nSold(product.soldCount!),
                                        style: TextStyle(fontSize: 12, color: context.col.ink2)),
                                    ],
                                  ]),
                                ),
                              const SizedBox(height: 14),
                              // Price — baseline aligned
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (showRange) ...[
                                    Text('${fmtPrice(varMinPrice!)} - ${fmtPrice(varMaxPrice!)} ${context.s.lydUnit}',
                                      style: TextStyle(fontFamily: 'PlusJakartaSans',
                                        fontSize: 22, fontWeight: FontWeight.w800, color: context.col.ink0)),
                                  ] else ...[
                                    Text('${fmtPrice(displayPrice)} ${context.s.lydUnit}',
                                      style: TextStyle(fontFamily: 'PlusJakartaSans',
                                        fontSize: 26, fontWeight: FontWeight.w800, color: context.col.ink0)),
                                    if (displayPrice < product.price) ...[
                                      const SizedBox(width: 8),
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 3),
                                        child: Text('${fmtPrice(product.price)} ${context.s.lydUnit}',
                                          style: TextStyle(fontFamily: 'PlusJakartaSans',
                                            fontSize: 15, color: context.col.ink3,
                                            decoration: TextDecoration.lineThrough,
                                            decorationColor: context.col.ink3)),
                                      ),
                                      const SizedBox(width: 8),
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 3),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.danger.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12)),
                                          child: Text(
                                            '${context.s.saveAmountPrefix} ${fmtPrice(product.price - displayPrice)} ${context.s.lydUnit}',
                                            style: const TextStyle(color: AppColors.danger,
                                              fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                                              fontSize: 11, fontWeight: FontWeight.w700)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                              // Stock indicator
                              const SizedBox(height: 10),
                              Row(children: [
                                Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(
                                    color: effectiveInStock
                                        ? (effectiveLowStock ? AppColors.warn : AppColors.success)
                                        : AppColors.danger,
                                    shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  effectiveInStock
                                      ? (effectiveLowStock ? context.s.lowStockN(_effQty!) : context.s.inStock)
                                      : context.s.outOfStock,
                                  style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: effectiveInStock
                                        ? (effectiveLowStock ? AppColors.warn : AppColors.success)
                                        : AppColors.danger),
                                ),
                              ]),
                            ],
                          ),
                        ),

                        // ── Card 2: Size/Variations + Qty ────────────
                        const SizedBox(height: 10),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.col.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.col.border),
                            boxShadow: AppShadows.shadowLifted,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (product.variations.isEmpty && product.productAttributes.isNotEmpty) ...[
                                _ProductAttributesDisplay(product: product),
                                const SizedBox(height: 12),
                                Divider(height: 1, color: context.col.border),
                                const SizedBox(height: 12),
                              ],
                              if (product.variations.isNotEmpty) ...[
                                _VariationPicker(
                                  product: product,
                                  selections: _selections,
                                  onChanged: (type, value) {
                                    setState(() => _selections[type] = value);
                                    _trySelectVariation(product);
                                  },
                                ),
                                const SizedBox(height: 4),
                                Divider(height: 1, color: context.col.border),
                                const SizedBox(height: 12),
                              ],
                              _QtySelector(
                                qty: _qty,
                                onChanged: (v) => setState(() => _qty = v),
                                enabled: product.variations.isNotEmpty
                                    ? (_selectedVariation?.inStock ?? false)
                                    : product.inStock,
                                max: () {
                                  if (!product.manageStock) return 10;
                                  if (product.variations.isNotEmpty) {
                                    final varQty = _selectedVariation?.stockQuantity;
                                    return (varQty != null && varQty > 0) ? varQty : 1;
                                  }
                                  final prodQty = product.stockQuantity;
                                  return (prodQty != null && prodQty > 0) ? prodQty : 10;
                                }(),
                              ),
                            ],
                          ),
                        ),

                        // ── Card 3: Trust + Delivery ──────────────────
                        const SizedBox(height: 10),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.col.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.col.border),
                            boxShadow: AppShadows.shadowLifted,
                          ),
                          child: Column(children: [
                            if (product.fulfilledByBaahy) ...[
                              Row(children: [
                                const BaahyPlusBadge(height: 16, tappable: true),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(context.s.deliveredDirect,
                                    style: TextStyle(fontSize: 11.5,
                                      fontWeight: FontWeight.w600, color: context.col.ink2)),
                                ),
                                Icon(Icons.info_outline_rounded, size: 14,
                                  color: context.col.ink3),
                              ]),
                              const SizedBox(height: 12),
                              Divider(height: 1, color: context.col.border),
                              const SizedBox(height: 12),
                            ],
                            const _DeliveryCard(),
                            const SizedBox(height: 14),
                            Divider(height: 1, color: context.col.border),
                            const SizedBox(height: 12),
                            Row(children: [
                              Icon(Icons.shield_outlined, size: 15, color: context.col.ink3),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(context.s.trustedSellers,
                                  style: TextStyle(fontSize: 12, color: context.col.ink2, height: 1.4)),
                              ),
                            ]),
                            const SizedBox(height: 14),
                            Divider(height: 1, color: context.col.border),
                            const SizedBox(height: 12),
                            const _TrustPills(),
                          ]),
                        ),

                        // ── Card 4: Description + SKU ────────────────
                        if ((product.description != null && product.description!.isNotEmpty) || product.sku != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.col.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.col.border),
                              boxShadow: AppShadows.shadowLifted,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (product.description != null && product.description!.isNotEmpty) ...[
                                  Text(context.s.description,
                                    textAlign: TextAlign.start,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 8),
                                  Text(isAr
                                      ? (product.descriptionAr ?? product.description!)
                                      : product.description!,
                                    textAlign: TextAlign.start,
                                    style: TextStyle(
                                      fontSize: 14, color: context.col.ink2, height: 1.6)),
                                  if (product.sku != null) ...[
                                    const SizedBox(height: 12),
                                    Divider(height: 1, color: context.col.border),
                                  ],
                                ],
                                if (product.sku != null) ...[
                                  const SizedBox(height: 10),
                                  Row(children: [
                                    Text(isAr ? 'كود المنتج:' : 'SKU:',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                        color: context.col.ink2)),
                                    const SizedBox(width: 8),
                                    Text(product.sku!,
                                      style: TextStyle(fontFamily: 'PlusJakartaSans',
                                        fontSize: 13, color: context.col.ink3)),
                                  ]),
                                ],
                              ],
                            ),
                          ),
                        ],

                        // ── Card 4: Vendor ────────────────────────────
                        if (product.vendor != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.col.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.col.border),
                              boxShadow: AppShadows.shadowLifted,
                            ),
                            child: _VendorRow(vendor: product.vendor!),
                          ),
                        ],

                        // ── Card 5: Coupon ────────────────────────────
                        const SizedBox(height: 10),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          decoration: BoxDecoration(
                            color: context.col.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.col.border),
                            boxShadow: AppShadows.shadowLifted,
                          ),
                          child: const _CouponSection(),
                        ),

                        // ── Complementary products (sister categories) ──
                        if (product.category != null)
                          _FrequentlyBoughtTogether(
                            mainProduct: product,
                            categoryId: product.category!.id,
                            lazyLoad: _lazyTriggered,
                          ),

                        // ── Reviews snippet ─────────────────────────
                        _ReviewsSnippet(productId: product.id,
                          count: product.reviewsCount ?? 0,
                          rating: product.averageRating ?? 0,
                          lazyLoad: _lazyTriggered),

                        // ── You may also like ────────────────────────
                        _YouMayAlsoLike(
                          productId: product.id,
                          categoryId: product.category?.id,
                          lazyLoad: _lazyTriggered,
                        ),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),

              // ── Share + Wishlist overlay (above PageView to avoid gesture conflicts) ──
              Positioned(
                top: 0, left: 0, right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, right: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => SharePlus.instance.share(ShareParams(text:
                            '${context.isAr ? product.nameAr : product.name}\nhttps://baahy.com/products/${product.id}')),
                          child: Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: context.col.surface.withValues(alpha: 0.95),
                              shape: BoxShape.circle,
                              border: Border.all(color: context.col.border),
                              boxShadow: AppShadows.shadowLifted,
                            ),
                            child: Icon(Icons.ios_share, size: 20, color: context.col.ink0),
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => ref.read(wishlistProvider.notifier).toggle(product.id),
                          child: Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: context.col.surface.withValues(alpha: 0.95),
                              shape: BoxShape.circle,
                              border: Border.all(color: context.col.border),
                              boxShadow: AppShadows.shadowLifted,
                            ),
                            child: Icon(
                              inWishlist ? Icons.favorite_rounded : Icons.favorite_outline,
                              size: 20,
                              color: inWishlist ? AppColors.danger : context.col.ink0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Bottom buy bar ──────────────────────────────────────
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(16, 10, 16,
                    MediaQuery.of(context).padding.bottom + 10),
                  decoration: BoxDecoration(
                    color: context.col.surface.withValues(alpha: 0.97),
                    boxShadow: AppShadows.shadowPop,
                    border: Border(top: BorderSide(color: context.col.border)),
                  ),
                  child: product.inStock
                      ? Row(children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(context.s.priceLabel,
                                style: TextStyle(fontSize: 10, color: context.col.ink3)),
                              Text('${fmtPrice(displayPrice)} ${context.s.lydUnit}',
                                style: const TextStyle(fontFamily: 'PlusJakartaSans',
                                  fontSize: 16, fontWeight: FontWeight.w800)),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _addToCart(product),
                              icon: const Icon(Icons.shopping_cart_outlined,
                                size: 18, color: Colors.white),
                              label: Text(context.s.addToCart,
                                style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'],
                                  fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ])
                      : SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _notifyMe(product.id),
                            icon: const Icon(Icons.notifications_outlined, size: 18),
                            label: Text(context.s.notifyMe,
                              style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
