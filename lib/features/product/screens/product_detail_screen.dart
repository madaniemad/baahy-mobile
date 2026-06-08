import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/app_config.dart';
import '../../../core/models/product.dart';
import '../../../core/models/review.dart';
import '../../../core/providers/address_provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/utils/navigation.dart';
import '../../../core/providers/wishlist_provider.dart';
import '../../../core/providers/recently_viewed_provider.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/product_card.dart';

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
    final attrCount = product.variations.first.attributes.length;
    if (_selections.length < attrCount) {
      _selectedVariation = null;
      setState(() {});
      return;
    }
    final match = product.variations.cast<ProductVariation?>().firstWhere(
      (v) => v!.attributes.every((a) => _selections[a.typeName] == a.value),
      orElse: () => null,
    );
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

  Future<void> _addToCart(Product product, {bool goToCart = false}) async {
    if (product.variations.isNotEmpty && _selectedVariation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.s.selectOptions)));
      return;
    }
    await ref.read(cartProvider.notifier).add(
      product, variation: _selectedVariation, qty: _qty);
    if (!mounted) return;
    if (goToCart) {
      safePush(context, '/cart');
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: context.col.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
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
        error: (_, __) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: context.col.ink3),
            const SizedBox(height: 12),
            Text(context.s.loadProductFailed, style: TextStyle(color: context.col.ink2)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.refresh(_productDetailProvider(widget.id)),
              child: Text(context.s.retry)),
          ]),
        ),
        data: (product) {
          // Track as recently viewed (deferred to avoid setState during build)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(recentlyViewedProvider.notifier).add(product);
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

          final lowStock = product.inStock &&
              product.productType != 'variable' &&
              product.stockQuantity != null &&
              product.stockQuantity! > 0 &&
              product.stockQuantity! <= 5;

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
                            boxShadow: AppShadows.shadowCard,
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
                                  imageUrl: product.images[i], fit: BoxFit.contain));
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
                                  borderRadius: BorderRadius.circular(8),
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
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: i == _imageIndex ? AppColors.primary : context.col.border,
                                      width: i == _imageIndex ? 2 : 1),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child: CachedNetworkImage(
                                      imageUrl: product.images[i],
                                      fit: BoxFit.cover,
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
                            boxShadow: AppShadows.shadowCard,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Brand name — no prefix, bigger
                              if (product.brand != null && product.brand!.isNotEmpty)
                                Text(product.brand!,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                                    color: AppColors.primary))
                              else if (product.vendor != null)
                                Text(
                                  isAr
                                    ? (product.vendor!.storeNameAr.isNotEmpty
                                        ? product.vendor!.storeNameAr : product.vendor!.storeName)
                                    : product.vendor!.storeName,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                                    color: AppColors.primary)),
                              const SizedBox(height: 6),
                              Text(name, style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800, height: 1.3)),
                              const SizedBox(height: 10),
                              // Full 5-star rating
                              if (product.averageRating != null && product.reviewsCount != null)
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
                                            borderRadius: BorderRadius.circular(6)),
                                          child: Text(
                                            '${context.s.saveAmountPrefix} ${fmtPrice(product.price - displayPrice)} ${context.s.lydUnit}',
                                            style: const TextStyle(color: AppColors.danger,
                                              fontFamily: 'Cairo',
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
                                    color: product.inStock
                                        ? (lowStock ? AppColors.warn : AppColors.success)
                                        : AppColors.danger,
                                    shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  product.inStock
                                      ? (lowStock ? context.s.lowStockN(product.stockQuantity!) : context.s.inStock)
                                      : context.s.outOfStock,
                                  style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: product.inStock
                                        ? (lowStock ? AppColors.warn : AppColors.success)
                                        : AppColors.danger),
                                ),
                              ]),
                            ],
                          ),
                        ),

                        // ── Card 2: Attributes / Variations ──────────
                        if (product.variations.isEmpty && product.productAttributes.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.col.surface,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: AppShadows.shadowCard,
                            ),
                            child: _ProductAttributesDisplay(product: product),
                          ),
                        ],
                        if (product.variations.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.col.surface,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: AppShadows.shadowCard,
                            ),
                            child: _VariationPicker(
                              product: product,
                              selections: _selections,
                              onChanged: (type, value) {
                                setState(() => _selections[type] = value);
                                _trySelectVariation(product);
                              },
                            ),
                          ),
                        ],

                        // ── Card 3: Qty + Trust + Delivery ───────────
                        const SizedBox(height: 10),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.col.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.col.border),
                            boxShadow: AppShadows.shadowCard,
                          ),
                          child: Column(children: [
                            _QtySelector(
                              qty: _qty,
                              onChanged: (v) => setState(() => _qty = v),
                              enabled: product.inStock,
                              max: product.stockQuantity ?? 99,
                            ),
                            const SizedBox(height: 16),
                            Divider(height: 1, color: context.col.border),
                            const SizedBox(height: 16),
                            const _TrustPills(),
                            const SizedBox(height: 12),
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
                          ]),
                        ),

                        // ── Card 4: Description ──────────────────────
                        if (product.description != null && product.description!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.col.surface,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: AppShadows.shadowCard,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
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
                              boxShadow: AppShadows.shadowCard,
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
                            boxShadow: AppShadows.shadowCard,
                          ),
                          child: const _CouponSection(),
                        ),

                        // ── Frequently bought together ───────────────
                        if (product.category != null)
                          _FrequentlyBoughtTogether(
                            mainProduct: product,
                            categoryId: product.category!.id,
                            lazyLoad: _lazyTriggered,
                          ),

                        // ── You may also like ────────────────────────
                        _YouMayAlsoLike(
                          productId: product.id,
                          categoryId: product.category?.id,
                          lazyLoad: _lazyTriggered,
                        ),

                        // ── Reviews snippet ─────────────────────────
                        _ReviewsSnippet(productId: product.id,
                          count: product.reviewsCount ?? 0,
                          rating: product.averageRating ?? 0,
                          lazyLoad: _lazyTriggered),

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
                          onTap: () => Share.share(
                            '${product.nameAr}\nhttps://baahy-web.vercel.app/products/${product.id}'),
                          child: Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: context.col.surface.withValues(alpha: 0.95),
                              shape: BoxShape.circle,
                              boxShadow: AppShadows.shadowCard,
                            ),
                            child: Icon(Icons.share_outlined, size: 20, color: context.col.ink0),
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
                              boxShadow: AppShadows.shadowCard,
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
                              Text('${displayPrice.toStringAsFixed(0)} ${context.s.lydUnit}',
                                style: const TextStyle(fontFamily: 'PlusJakartaSans',
                                  fontSize: 16, fontWeight: FontWeight.w800)),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _addToCart(product),
                              icon: const Icon(Icons.shopping_cart_outlined,
                                size: 18, color: Colors.black87),
                              label: Text(context.s.addToCart,
                                style: const TextStyle(fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w700, fontSize: 15, color: Colors.black87)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ])
                      : SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.notifications_outlined, size: 18),
                            label: Text(context.s.outOfStock,
                              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
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

// ── Stock + ETA strip ─────────────────────────────────────────────────────────

class _StockEtaStrip extends StatelessWidget {
  final Product product;
  final String deliveryPromise;
  const _StockEtaStrip({required this.product, required this.deliveryPromise});

  @override
  Widget build(BuildContext context) {
    final lowStock = product.inStock &&
        product.productType != 'variable' &&
        product.stockQuantity != null &&
        product.stockQuantity! > 0 &&
        product.stockQuantity! <= 5;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.col.surfaceSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(children: [
            Icon(
              product.inStock
                  ? (lowStock ? Icons.local_fire_department_rounded : Icons.check_circle_rounded)
                  : Icons.info_rounded,
              size: 16,
              color: product.inStock
                  ? (lowStock ? AppColors.warn : AppColors.success)
                  : AppColors.danger,
            ),
            const SizedBox(width: 8),
            Text(
              product.inStock
                  ? (lowStock
                      ? context.s.lowStockN(product.stockQuantity!)
                      : context.s.inStock)
                  : context.s.outOfStock,
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: product.inStock
                    ? (lowStock ? AppColors.warn : AppColors.success)
                    : AppColors.danger,
              ),
            ),
          ]),
          if (product.inStock) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: context.col.border),
            const SizedBox(height: 10),
            if (product.fulfilledByBaahy)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.bolt_rounded, size: 13, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(context.s.deliveredDirect,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                    ]),
                  ),
                ]),
              ),
            Row(children: [
              const Icon(Icons.local_shipping_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(deliveryPromise,
                  style: TextStyle(fontSize: 12.5,
                    fontWeight: FontWeight.w600, color: context.col.ink1)),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

// ── Trust block ───────────────────────────────────────────────────────────────

class _TrustBlock extends StatelessWidget {
  final AppConfig config;
  const _TrustBlock({required this.config});

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    final paymentLabels = config.paymentMethods
        .where((m) => m.enabled)
        .map((m) => isAr ? m.labelAr : (m.labelEn.isNotEmpty ? m.labelEn : m.labelAr))
        .join(' · ');
    final rows = [
      (Icons.local_shipping_outlined, isAr ? config.deliveryPromiseAr : config.deliveryPromiseEn),
      (Icons.refresh_rounded, isAr
          ? 'إرجاع خلال ${config.returnDays} أيام · من باب منزلك'
          : 'Returns within ${config.returnDays} days · From your door'),
      (Icons.credit_card_outlined, paymentLabels.isNotEmpty
          ? paymentLabels : (isAr ? 'الدفع عند الاستلام' : 'Cash on Delivery')),
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.col.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.col.border),
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.inventory_2_outlined,
                  size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.s.soldByBaahy,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  Text(context.s.qualityChecked,
                    style: TextStyle(fontSize: 11.5, color: context.col.ink3)),
                ],
              )),
            ]),
          ),
          Divider(height: 1, color: context.col.border),
          ...rows.map((row) => Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Icon(row.$1, size: 20, color: context.col.ink2),
                const SizedBox(width: 12),
                Expanded(child: Text(row.$2,
                  style: TextStyle(fontSize: 13, color: context.col.ink1))),
              ]),
            ),
            if (row != rows.last) Divider(height: 1, color: context.col.border),
          ])),
        ],
      ),
    );
  }
}

// ── Frequently bought together ────────────────────────────────────────────────

class _FrequentlyBoughtTogether extends ConsumerStatefulWidget {
  final Product mainProduct;
  final int categoryId;
  final bool lazyLoad;
  const _FrequentlyBoughtTogether({required this.mainProduct, required this.categoryId, this.lazyLoad = false});
  @override
  ConsumerState<_FrequentlyBoughtTogether> createState() => _FBTState();
}

class _FBTState extends ConsumerState<_FrequentlyBoughtTogether> {
  late Map<int, bool> _checked;

  @override
  void initState() {
    super.initState();
    _checked = {widget.mainProduct.id: true};
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.lazyLoad) return const SizedBox.shrink();
    final relatedAsync = ref.watch(_relatedProductsProvider(widget.categoryId));

    return relatedAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (related) {
        final others = related
            .where((p) => p.id != widget.mainProduct.id)
            .take(2)
            .toList();
        if (others.isEmpty) return const SizedBox.shrink();

        final all = [widget.mainProduct, ...others];
        // Initialize checked for new items
        for (final p in all) {
          _checked.putIfAbsent(p.id, () => true);
        }

        final selected = all.where((p) => _checked[p.id] == true).toList();
        final total = selected.fold(0.0, (s, p) => s + p.displayPrice);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.s.frequentlyBought,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),

              // Image stack with + signs
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < all.length; i++) ...[
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _checked[all[i].id] == true
                              ? AppColors.primary : context.col.border,
                          width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Opacity(
                        opacity: _checked[all[i].id] == true ? 1 : 0.3,
                        child: all[i].firstImage != null
                            ? CachedNetworkImage(
                                imageUrl: all[i].firstImage!, fit: BoxFit.cover)
                            : Container(color: context.col.surfaceSoft),
                      ),
                    ),
                    if (i < all.length - 1)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.add, size: 16, color: context.col.ink3),
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Checkbox list
              Container(
                decoration: BoxDecoration(
                  color: context.col.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.col.border),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < all.length; i++) ...[
                      GestureDetector(
                        onTap: i == 0 ? null : () =>
                          setState(() => _checked[all[i].id] = !(_checked[all[i].id] ?? true)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(children: [
                            Container(
                              width: 20, height: 20,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: _checked[all[i].id] == true ? context.col.ink0 : context.col.surface,
                                border: _checked[all[i].id] == true
                                    ? null : Border.all(color: context.col.borderStrong, width: 1.8),
                              ),
                              child: _checked[all[i].id] == true
                                  ? Icon(Icons.check, size: 13, color: context.col.bg)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (i == 0 ? (context.isAr ? 'هذا المنتج: ' : 'This product: ') : '') +
                                  (context.isAr ? all[i].nameAr : all[i].name),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                                Text('${fmtPrice(all[i].displayPrice)} ${context.s.lydUnit}',
                                  style: const TextStyle(fontFamily: 'PlusJakartaSans',
                                    fontSize: 13, fontWeight: FontWeight.w700)),
                              ],
                            )),
                          ]),
                        ),
                      ),
                      if (i < all.length - 1) Divider(height: 1, color: context.col.border),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.s.totalForN(selected.length),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text('${fmtPrice(total)} ${context.s.lydUnit}',
                    style: const TextStyle(fontFamily: 'PlusJakartaSans',
                      fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: selected.length < 2 ? null : () {
                    for (final p in selected.where((p) => p.id != widget.mainProduct.id)) {
                      ref.read(cartProvider.notifier).add(p);
                    }
                    safePush(context, '/cart');
                  },
                  icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                  label: Text(context.s.addNToCart(selected.length),
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Reviews snippet ───────────────────────────────────────────────────────────

class _ReviewsSnippet extends ConsumerWidget {
  final int productId;
  final int count;
  final double rating;
  final bool lazyLoad;
  const _ReviewsSnippet({required this.productId, required this.count, required this.rating, this.lazyLoad = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!lazyLoad) return const SizedBox.shrink();
    final reviewsAsync = ref.watch(_productReviewsProvider(productId));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(context.s.reviewsCountN(count),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const Spacer(),
            GestureDetector(
              onTap: () => safePush(context, '/product/$productId/reviews'),
              child: Text(context.s.seeAllReviews,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
            ),
          ]),
          if (rating > 0) ...[
            const SizedBox(height: 12),
            Row(children: [
              Text(rating.toStringAsFixed(1),
                style: const TextStyle(fontFamily: 'PlusJakartaSans',
                  fontSize: 32, fontWeight: FontWeight.w800)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                RatingBarIndicator(
                  rating: rating,
                  itemSize: 16,
                  itemBuilder: (_, __) => const Icon(Icons.star_rounded, color: AppColors.gold),
                ),
                const SizedBox(height: 4),
                Text(context.s.basedOnN(count),
                  style: TextStyle(fontSize: 12, color: context.col.ink3)),
              ]),
            ]),
          ],
          const SizedBox(height: 14),
          reviewsAsync.when(
            loading: () => const SizedBox(height: 40,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            error: (_, __) => const SizedBox.shrink(),
            data: (reviews) => Column(
              children: reviews.take(2).map((r) => _ReviewCard(review: r)).toList()),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Review review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.col.surfaceSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: Text(review.reviewerName.isNotEmpty ? review.reviewerName[0] : '?',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(review.reviewerName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(review.createdAt ?? '',
                  style: TextStyle(fontSize: 11, color: context.col.ink3)),
              ],
            )),
            Row(children: List.generate(5, (i) => Icon(
              i < review.rating ? Icons.star_rounded : Icons.star_border_rounded,
              size: 13, color: AppColors.gold))),
          ]),
          const SizedBox(height: 8),
          Text(review.body, style: TextStyle(fontSize: 13, color: context.col.ink1, height: 1.5)),
        ],
      ),
    );
  }
}

// ── Simple-product attribute display (no variations) ─────────────────────────

class _ProductAttributesDisplay extends StatelessWidget {
  final Product product;
  const _ProductAttributesDisplay({required this.product});

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    const arNameMap = {'الحجم': 'المقاس'};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: product.productAttributes.where((a) => a.values.isNotEmpty).map((attr) {
        final rawLabel = isAr ? attr.nameAr : attr.name;
        final label = arNameMap[rawLabel.trim()] ?? rawLabel;
        final isColor = attr.displayType == 'color' ||
            attr.name.toLowerCase() == 'color' ||
            attr.nameAr.contains('لون');
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Text('$label: ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Wrap(
                spacing: 6,
                children: attr.values.map((v) {
                  final val = isAr ? v.valueAr : v.value;
                  if (isColor && v.colorHex != null) {
                    return _ColorSwatch(hex: v.colorHex!, selected: false, available: true, size: 22);
                  }
                  return Text(val, style: TextStyle(fontSize: 13, color: context.col.ink2));
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Variation picker ──────────────────────────────────────────────────────────

class _VariationPicker extends StatelessWidget {
  final Product product;
  final Map<String, String> selections;
  final void Function(String type, String value) onChanged;
  const _VariationPicker({required this.product, required this.selections, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    const arNameMap = {'الحجم': 'المقاس'};

    // Group options by typeName from variation_attributes
    final grouped = <String, List<VariationAttribute>>{};
    for (final v in product.variations) {
      for (final a in v.attributes) {
        grouped.putIfAbsent(a.typeName, () => []);
        if (!grouped[a.typeName]!.any((x) => x.value == a.value)) {
          grouped[a.typeName]!.add(a);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        final typeName = entry.key;
        final options = entry.value;
        final rawAr = options.first.typeNameAr.isNotEmpty ? options.first.typeNameAr : typeName;
        final label = isAr ? (arNameMap[rawAr.trim()] ?? rawAr) : typeName;
        final isColor = options.any((o) => o.colorHex != null) ||
            typeName.toLowerCase() == 'color' ||
            rawAr.contains('لون');

        // Single value → display label (not interactive)
        if (options.length == 1) {
          final opt = options.first;
          final val = isAr && opt.valueAr.isNotEmpty ? opt.valueAr : opt.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text('$label: ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                if (isColor && opt.colorHex != null) ...[
                  _ColorSwatch(hex: opt.colorHex!, selected: false, available: true, size: 22),
                  const SizedBox(width: 6),
                ],
                Text(val, style: TextStyle(fontSize: 13, color: context.col.ink2)),
              ],
            ),
          );
        }

        // Multiple values → interactive picker
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                if (selections[typeName] != null)
                  Text(selections[typeName]!, style: TextStyle(fontSize: 13, color: context.col.ink2)),
              ]),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: options.map((opt) {
                  final isSelected = selections[typeName] == opt.value;
                  final isOutOfStock = !product.variations.any((v) =>
                      v.attributes.any((a) => a.typeName == typeName && a.value == opt.value) &&
                      (v.inStock || v.stockQuantity > 0));
                  if (isColor && opt.colorHex != null) {
                    return GestureDetector(
                      onTap: isOutOfStock ? null : () => onChanged(typeName, opt.value),
                      child: Tooltip(
                        message: isAr && opt.valueAr.isNotEmpty ? opt.valueAr : opt.value,
                        child: _ColorSwatch(hex: opt.colorHex!, selected: isSelected, available: !isOutOfStock, size: 36),
                      ),
                    );
                  }
                  return GestureDetector(
                    onTap: isOutOfStock ? null : () => onChanged(typeName, opt.value),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? context.col.ink0
                                : isOutOfStock ? context.col.surfaceSoft
                                : context.col.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? context.col.ink0
                                  : isOutOfStock ? context.col.border
                                  : context.col.border,
                              width: 1.5),
                          ),
                          child: Text(opt.value,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: isSelected ? context.col.bg
                                  : isOutOfStock ? context.col.ink3
                                  : context.col.ink0)),
                        ),
                        if (isOutOfStock)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: CustomPaint(painter: _OutOfStockPainter()),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Color swatch circle ───────────────────────────────────────────────────────

class _ColorSwatch extends StatelessWidget {
  final String hex;
  final bool selected;
  final bool available;
  final double size;
  const _ColorSwatch({required this.hex, required this.selected, required this.available, required this.size});

  static Color _parse(String hex) {
    try {
      final h = hex.replaceAll('#', '').padLeft(6, '0');
      return Color(int.parse('0xFF$h'));
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _parse(hex);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: selected ? AppColors.primary : const Color(0xFFD1D5DB),
          width: selected ? 2.5 : 1.5,
        ),
        boxShadow: selected
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 4, spreadRadius: 1)]
            : null,
      ),
      child: available
          ? null
          : ClipOval(child: CustomPaint(painter: _OutOfStockPainter())),
    );
  }
}

// ── Qty selector ──────────────────────────────────────────────────────────────

class _QtySelector extends StatelessWidget {
  final int qty;
  final ValueChanged<int> onChanged;
  final bool enabled;
  final int max;
  const _QtySelector({required this.qty, required this.onChanged, this.enabled = true, this.max = 99});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(context.s.qty, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      const Spacer(),
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: context.col.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          _QtyBtn(Icons.remove, qty > 1 && enabled ? () => onChanged(qty - 1) : null),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('$qty',
              style: const TextStyle(fontFamily: 'PlusJakartaSans',
                fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          _QtyBtn(Icons.add, enabled && qty < max ? () => onChanged(qty + 1) : null),
        ]),
      ),
    ]);
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _QtyBtn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Icon(icon, size: 18,
        color: onTap != null ? context.col.ink0 : context.col.border),
    ),
  );
}

// ── Trust pills ───────────────────────────────────────────────────────────────

class _TrustPills extends StatelessWidget {
  const _TrustPills();

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String)>[
      (Icons.refresh_rounded,                 context.s.trustReturn),
      (Icons.account_balance_wallet_outlined, context.s.trustPayment),
      (Icons.local_shipping_outlined,         context.s.trustDelivery),
    ];
    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(items[i].$1, size: 13,
                    color: AppColors.primary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(items[i].$2,
                      style: TextStyle(fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: context.col.ink1),
                      overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Delivery card ─────────────────────────────────────────────────────────────

class _DeliveryCard extends ConsumerWidget {
  const _DeliveryCard();

  static const _arabicDays = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
  static const _arabicMonths = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  static const _englishDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _englishMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String _fmtDate(DateTime d, bool isAr) => isAr
      ? '${_arabicDays[d.weekday % 7]} ${d.day} ${_arabicMonths[d.month - 1]}'
      : '${_englishDays[d.weekday % 7]}, ${_englishMonths[d.month - 1]} ${d.day}';

  static (int, int) _daysForCity(String city) {
    if (city.contains('طرابلس') || city.contains('مصراتة') || city.contains('الزاوية') ||
        city.contains('زليتن') || city.contains('الخمس') || city.contains('تاجوراء') ||
        city.contains('جنزور') || city.contains('قرجي')) return (1, 2);
    if (city.contains('بنغازي') || city.contains('البيضاء') || city.contains('سرت') ||
        city.contains('درنة') || city.contains('أجدابيا') || city.contains('الزنتان') ||
        city.contains('ترهونة') || city.contains('غريان')) return (2, 4);
    if (city == 'ليبيا' || city.isEmpty || city == 'كل ليبيا') return (1, 4);
    return (3, 6);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = ref.watch(cityProvider);
    final (minDays, maxDays) = _daysForCity(city);
    final now = DateTime.now();
    final isAr = context.isAr;
    final minDate = _fmtDate(now.add(Duration(days: minDays)), isAr);
    final maxDate = _fmtDate(now.add(Duration(days: maxDays)), isAr);
    final estimate = isAr
        ? (minDays == maxDays ? 'يصل يوم $minDate' : 'يصل بين $minDate و$maxDate')
        : (minDays == maxDays ? 'Arrives $minDate' : 'Arrives between $minDate and $maxDate');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: context.col.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(context.s.deliveryToCity(city),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              const Icon(Icons.local_shipping_outlined, size: 16, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.col.surfaceSoft,
              borderRadius: BorderRadius.circular(8)),
            child: Text(estimate,
              style: TextStyle(fontSize: 12.5,
                fontWeight: FontWeight.w600, color: context.col.ink1),
              textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

// ── Vendor row ────────────────────────────────────────────────────────────────

class _VendorRow extends StatelessWidget {
  final Vendor vendor;
  const _VendorRow({required this.vendor});

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    final name = isAr
        ? (vendor.storeNameAr.isNotEmpty ? vendor.storeNameAr : vendor.storeName)
        : (vendor.storeName.isNotEmpty ? vendor.storeName : vendor.storeNameAr);
    return Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: context.col.surfaceSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.col.border)),
        child: vendor.logo != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: vendor.logo!, fit: BoxFit.cover))
            : Icon(Icons.store_outlined, size: 22, color: context.col.ink2),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          if (vendor.city != null && vendor.city!.isNotEmpty)
            Text(vendor.city!,
              style: TextStyle(fontSize: 12, color: context.col.ink3)),
        ],
      )),
      OutlinedButton(
        onPressed: () => context.push('/vendors/${vendor.id}'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          side: BorderSide(color: AppColors.success.withValues(alpha: 0.8)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(context.s.visitStore,
          style: const TextStyle(fontFamily: 'Cairo',
            fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
      ),
    ]);
  }
}

// ── Coupon section ────────────────────────────────────────────────────────────

class _CouponSection extends StatefulWidget {
  const _CouponSection();
  @override
  State<_CouponSection> createState() => _CouponSectionState();
}

class _CouponSectionState extends State<_CouponSection> {
  bool _expanded = false;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Divider(height: 1, color: context.col.border),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(children: [
            const Spacer(),
            Text(context.s.hasCoupon,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Icon(Icons.local_offer_outlined, size: 15, color: context.col.ink3),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.expand_more_rounded, size: 20, color: context.col.ink3),
            ),
          ]),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: context.col.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _ctrl,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.start,
                    style: const TextStyle(fontFamily: 'PlusJakartaSans',
                      fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                    decoration: InputDecoration(
                      hintText: 'أدخل كود الخصم',
                      hintTextDirection: TextDirection.rtl,
                      hintStyle: TextStyle(
                        color: context.col.ink3,
                        fontWeight: FontWeight.w400,
                        fontSize: 13,
                        letterSpacing: 0,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(context.s.apply,
                  style: const TextStyle(fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black87)),
              ),
            ]),
          ),
          crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

// ── You may also like ─────────────────────────────────────────────────────────

class _YouMayAlsoLike extends ConsumerStatefulWidget {
  final int productId;
  final int? categoryId;
  final bool lazyLoad;
  const _YouMayAlsoLike({required this.productId, this.categoryId, this.lazyLoad = false});
  @override
  ConsumerState<_YouMayAlsoLike> createState() => _YouMayAlsoLikeState();
}

class _YouMayAlsoLikeState extends ConsumerState<_YouMayAlsoLike> {
  final List<Product> _products = [];
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    if (widget.lazyLoad) _loadMore();
  }

  @override
  void didUpdateWidget(_YouMayAlsoLike old) {
    super.didUpdateWidget(old);
    if (!old.lazyLoad && widget.lazyLoad && _products.isEmpty) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{'per_page': 10, 'page': _page, 'sort': 'popular'};
      if (widget.categoryId != null) params['category_id'] = widget.categoryId;
      final res = await ApiClient.instance.dio.get('/products', queryParameters: params);
      final data = res.data['data']['data'] as List? ?? [];
      final fetched = data.map((p) => Product.fromJson(p))
          .where((p) => p.id != widget.productId).toList();
      if (mounted) {
        setState(() {
          _products.addAll(fetched);
          _page++;
          _hasMore = data.length == 10 && _products.length < 50;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_products.isEmpty && !_loading) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.s.youMayAlsoLike,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (_, box) {
            const srcW = 165.0;
            const srcH = 345.0;
            final colW = (box.maxWidth - 12) / 2;
            final cellH = srcH * (colW / srcW);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: cellH.ceilToDouble(),
              ),
              itemCount: _products.length % 2 == 0 ? _products.length : _products.length - 1,
              itemBuilder: (_, i) => FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: srcW,
                  child: ProductCard(product: _products[i], width: srcW),
                ),
              ),
            );
          }),
          if (_loading) ...[
            const SizedBox(height: 16),
            const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
          ],
          if (_hasMore && !_loading) ...[
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton(
                onPressed: _loadMore,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                  side: const BorderSide(color: Colors.black54, width: 1.2),
                  shape: const StadiumBorder(),
                  foregroundColor: Colors.black87,
                ),
                child: Text(context.s.viewMore,
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Out-of-stock diagonal line painter ───────────────────────────────────────

class _OutOfStockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(size.width * 0.12, size.height * 0.88),
      Offset(size.width * 0.88, size.height * 0.12),
      Paint()
        ..color = const Color(0xFFAAAAAA)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }
  @override
  bool shouldRepaint(_) => false;
}

// ── Added to cart sheet ───────────────────────────────────────────────────────

class _AddedToCartSheet extends StatelessWidget {
  final Product product;
  final int qty;
  final VoidCallback? onViewCart;
  const _AddedToCartSheet({required this.product, required this.qty, this.onViewCart});

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    final name = isAr ? product.nameAr : product.name;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: context.col.border,
              borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 22, color: AppColors.success),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.s.addedToCart,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('$qty× $name',
                  style: TextStyle(fontSize: 12, color: context.col.ink2),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: BorderSide(color: context.col.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(context.s.continueShopping,
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, color: context.col.ink0)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onViewCart?.call();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: Text(context.s.viewCart,
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.black87)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
