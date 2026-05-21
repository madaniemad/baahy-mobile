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
import '../../../core/providers/app_config_provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/utils/navigation.dart';
import '../../../core/providers/wishlist_provider.dart';
import '../../../core/providers/recently_viewed_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';

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
  ProductVariation? _selectedVariation;
  int _qty = 1;
  final Map<String, String> _selections = {};

  void _trySelectVariation(Product product) {
    if (product.variations.isEmpty) return;
    final attrCount = product.variations.first.attributes.length;
    if (_selections.length < attrCount) return;
    _selectedVariation = product.variations.firstWhere(
      (v) => v.attributes.every((a) => _selections[a.typeName] == a.value),
      orElse: () => product.variations.first,
    );
    setState(() {});
  }

  Future<void> _notifyMe(int productId) async {
    try {
      await ApiClient.instance.dio.post('/products/$productId/notify-me');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('سنعلمك عند توفر المنتج'),
          backgroundColor: AppColors.success,
        ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر تسجيل الطلب، حاول مجدداً')));
    }
  }

  Future<void> _addToCart(Product product, {bool goToCart = false}) async {
    if (product.productType == 'variable' && _selectedVariation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر المواصفات أولاً')));
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
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
    final config = ref.watch(appConfigProvider);
    final productAsync = ref.watch(_productDetailProvider(widget.id));

    return Scaffold(
      backgroundColor: Colors.white,
      body: productAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.ink3),
            const SizedBox(height: 12),
            const Text('تعذر تحميل المنتج', style: TextStyle(color: AppColors.ink2)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.refresh(_productDetailProvider(widget.id)),
              child: const Text('إعادة المحاولة')),
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
          final _inStockVarsForPrice = product.variations.where((v) => v.stockQuantity > 0).toList();
          final _cheapestInStock = _inStockVarsForPrice.isNotEmpty
              ? _inStockVarsForPrice.map((v) => v.salePrice ?? v.price).reduce((a, b) => a < b ? a : b)
              : null;
          final displayPrice = _selectedVariation?.salePrice
              ?? _selectedVariation?.price
              ?? _cheapestInStock
              ?? product.displayPrice;

          // For variable products: compute min/max across IN-STOCK variations only
          final inStockVars = product.variations.where((v) => v.stockQuantity > 0).toList();
          final varPrices = inStockVars.map((v) => v.salePrice ?? v.price).toList();
          final varMinPrice = varPrices.isNotEmpty
              ? varPrices.reduce((a, b) => a < b ? a : b) : null;
          final varMaxPrice = varPrices.isNotEmpty
              ? varPrices.reduce((a, b) => a > b ? a : b) : null;
          final showRange = product.productType == 'variable' &&
              _selectedVariation == null &&
              varMinPrice != null && varMaxPrice != null &&
              varMinPrice != varMaxPrice;

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // ── Image gallery ────────────────────────────────
                  SliverAppBar(
                    expandedHeight: 340,
                    pinned: true,
                    backgroundColor: Colors.white,
                    elevation: 0,
                    leading: Padding(
                      padding: const EdgeInsets.all(8),
                      child: GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            shape: BoxShape.circle,
                            boxShadow: AppShadows.shadowCard,
                          ),
                          child: const Icon(Icons.arrow_back, size: 20, color: AppColors.ink0),
                        ),
                      ),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        children: [
                          PageView.builder(
                            itemCount: product.images.isEmpty ? 1 : product.images.length,
                            onPageChanged: (i) => setState(() => _imageIndex = i),
                            itemBuilder: (_, i) {
                              if (product.images.isEmpty) {
                                return Container(color: AppColors.bg,
                                  child: const Icon(Icons.image_outlined, size: 80, color: AppColors.border));
                              }
                              return InteractiveViewer(
                                minScale: 1.0,
                                maxScale: 4.0,
                                child: CachedNetworkImage(
                                  imageUrl: product.images[i], fit: BoxFit.contain));
                            },
                          ),
                          if (product.images.length > 1)
                            Positioned(
                              bottom: 12, left: 0, right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(product.images.length, (i) =>
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: i == _imageIndex ? 18 : 6, height: 6,
                                    decoration: BoxDecoration(
                                      color: i == _imageIndex ? AppColors.primary : AppColors.border,
                                      borderRadius: BorderRadius.circular(3),
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
                        ],
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Title, price, rating ────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (product.brand != null && product.brand!.isNotEmpty)
                                Text(
                                  'الماركة: ${product.brand!}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                    color: AppColors.ink3, letterSpacing: 0.5))
                              else if (product.vendor != null)
                                Text(
                                  isAr
                                    ? 'الماركة: ${product.vendor!.storeNameAr.isNotEmpty ? product.vendor!.storeNameAr : product.vendor!.storeName}'
                                    : 'Brand: ${product.vendor!.storeName}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                    color: AppColors.ink3, letterSpacing: 0.5)),
                              const SizedBox(height: 4),
                              Text(name, style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800, height: 1.3)),
                              const SizedBox(height: 8),
                              if (product.averageRating != null && product.reviewsCount != null)
                                GestureDetector(
                                  onTap: () => safePush(context, '/product/${product.id}/reviews'),
                                  child: Row(children: [
                                    const Icon(Icons.star_rounded, size: 14, color: AppColors.gold),
                                    const SizedBox(width: 4),
                                    Text(product.averageRating!.toStringAsFixed(1),
                                      style: const TextStyle(fontFamily: 'PlusJakartaSans',
                                        fontSize: 13, fontWeight: FontWeight.w700)),
                                    const SizedBox(width: 4),
                                    Text('(${product.reviewsCount})',
                                      style: const TextStyle(color: AppColors.ink3, fontSize: 12)),
                                    if (product.soldCount != null && product.soldCount! > 0) ...[
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 6),
                                        child: Text('·', style: TextStyle(color: AppColors.ink3)),
                                      ),
                                      Text('${product.soldCount} مُباع',
                                        style: const TextStyle(fontSize: 12, color: AppColors.ink2)),
                                    ],
                                  ]),
                                ),
                              const SizedBox(height: 12),
                              Row(children: [
                                if (showRange) ...[
                                  Text('${varMinPrice!.toStringAsFixed(0)} - ${varMaxPrice!.toStringAsFixed(0)} د.ل',
                                    style: const TextStyle(fontFamily: 'PlusJakartaSans',
                                      fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink0)),
                                ] else ...[
                                  Text('${displayPrice.toStringAsFixed(0)} د.ل',
                                    style: const TextStyle(fontFamily: 'PlusJakartaSans',
                                      fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink0)),
                                  if (displayPrice < product.price) ...[
                                    const SizedBox(width: 8),
                                    Text('${product.price.toStringAsFixed(0)} د.ل',
                                      style: const TextStyle(fontFamily: 'PlusJakartaSans',
                                        fontSize: 15, color: AppColors.ink3,
                                        decoration: TextDecoration.lineThrough)),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6)),
                                      child: Text('−${((1 - displayPrice / product.price) * 100).round()}%',
                                        style: const TextStyle(color: AppColors.success,
                                          fontSize: 11, fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ],
                              ]),

                              // Stock + ETA strip
                              const SizedBox(height: 14),
                              _StockEtaStrip(product: product, deliveryPromise: config.deliveryPromiseAr),
                            ],
                          ),
                        ),

                        // ── Variations ──────────────────────────────
                        if (product.variations.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
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

                        // ── Qty selector ────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                          child: _QtySelector(
                            qty: _qty,
                            onChanged: (v) => setState(() => _qty = v),
                            enabled: product.inStock,
                          ),
                        ),

                        // ── Trust block ─────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                          child: _TrustBlock(config: config),
                        ),

                        // ── Description ─────────────────────────────
                        if (product.description != null && product.description!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('الوصف',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 8),
                                Text(isAr
                                    ? (product.descriptionAr ?? product.description!)
                                    : product.description!,
                                  style: const TextStyle(
                                    fontSize: 14, color: AppColors.ink2, height: 1.6)),
                              ],
                            ),
                          ),
                        ],

                        // ── Frequently bought together ───────────────
                        if (product.category != null)
                          _FrequentlyBoughtTogether(
                            mainProduct: product,
                            categoryId: product.category!.id,
                          ),

                        // ── Reviews snippet ─────────────────────────
                        _ReviewsSnippet(productId: product.id,
                          count: product.reviewsCount ?? 0,
                          rating: product.averageRating ?? 0),

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
                            '${product.nameAr}\nhttps://baahy.ly/product/${product.id}'),
                          child: Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              shape: BoxShape.circle,
                              boxShadow: AppShadows.shadowCard,
                            ),
                            child: const Icon(Icons.share_outlined, size: 20, color: AppColors.ink0),
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => ref.read(wishlistProvider.notifier).toggle(product.id),
                          child: Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              shape: BoxShape.circle,
                              boxShadow: AppShadows.shadowCard,
                            ),
                            child: Icon(
                              inWishlist ? Icons.favorite_rounded : Icons.favorite_outline,
                              size: 20,
                              color: inWishlist ? AppColors.danger : AppColors.ink0,
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
                  padding: EdgeInsets.fromLTRB(12, 10, 12,
                    MediaQuery.of(context).padding.bottom + 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.97),
                    boxShadow: AppShadows.shadowPop,
                  ),
                  child: product.inStock
                      ? Row(children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _addToCart(product),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('أضف للسلة',
                                style: TextStyle(fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w700, color: AppColors.ink0)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _addToCart(product, goToCart: true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Text('اشترِ الآن',
                                style: TextStyle(fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w700, color: AppColors.ink0)),
                            ),
                          ),
                        ])
                      : SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () => _notifyMe(product.id),
                            icon: const Icon(Icons.notifications_outlined, size: 18),
                            label: const Text('أعلمني عند التوفر',
                              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.surfaceSoft,
                              foregroundColor: AppColors.ink1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
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
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
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
                      ? 'تبقّى ${product.stockQuantity} فقط'
                      : 'متوفّر')
                  : 'نفدت الكمية',
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
            const Divider(height: 1, color: AppColors.border),
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
                      const Text('يُوصَّل مباشرةً من مستودعات باهي',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                    ]),
                  ),
                ]),
              ),
            Row(children: [
              const Icon(Icons.local_shipping_outlined, size: 18, color: AppColors.teal600),
              const SizedBox(width: 10),
              Expanded(
                child: Text(deliveryPromise,
                  style: const TextStyle(fontSize: 12.5,
                    fontWeight: FontWeight.w600, color: AppColors.ink1)),
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
    final paymentLabels = config.paymentMethods
        .where((m) => m.enabled)
        .map((m) => m.labelAr)
        .join(' · ');
    final rows = [
      (Icons.local_shipping_outlined, config.deliveryPromiseAr),
      (Icons.refresh_rounded, 'إرجاع خلال ${config.returnDays} أيام · من باب منزلك'),
      (Icons.credit_card_outlined, paymentLabels.isNotEmpty
          ? paymentLabels : 'الدفع عند الاستلام'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
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
                  size: 18, color: AppColors.ink0),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('يُباع ويُسلَّم عبر باهي',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  Text('مفحوص الجودة · مخزَّن في مستودعنا بطرابلس',
                    style: TextStyle(fontSize: 11.5, color: AppColors.ink3)),
                ],
              )),
            ]),
          ),
          const Divider(height: 1, color: AppColors.border),
          ...rows.map((row) => Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Icon(row.$1, size: 20, color: AppColors.ink2),
                const SizedBox(width: 12),
                Expanded(child: Text(row.$2,
                  style: const TextStyle(fontSize: 13, color: AppColors.ink1))),
              ]),
            ),
            if (row != rows.last) const Divider(height: 1, color: AppColors.border),
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
  const _FrequentlyBoughtTogether({required this.mainProduct, required this.categoryId});
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
              const Text('تُشترى عادةً معاً',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
                              ? AppColors.primary : AppColors.border,
                          width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Opacity(
                        opacity: _checked[all[i].id] == true ? 1 : 0.3,
                        child: all[i].firstImage != null
                            ? CachedNetworkImage(
                                imageUrl: all[i].firstImage!, fit: BoxFit.cover)
                            : Container(color: AppColors.surfaceSoft),
                      ),
                    ),
                    if (i < all.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.add, size: 16, color: AppColors.ink3),
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Checkbox list
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
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
                                borderRadius: BorderRadius.circular(5),
                                color: _checked[all[i].id] == true ? AppColors.ink0 : Colors.white,
                                border: _checked[all[i].id] == true
                                    ? null : Border.all(color: AppColors.borderStrong, width: 1.8),
                              ),
                              child: _checked[all[i].id] == true
                                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (i == 0 ? 'هذا المنتج: ' : '') +
                                  (context.isAr ? all[i].nameAr : all[i].name),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                                Text('${all[i].displayPrice.toStringAsFixed(0)} د.ل',
                                  style: const TextStyle(fontFamily: 'PlusJakartaSans',
                                    fontSize: 13, fontWeight: FontWeight.w700)),
                              ],
                            )),
                          ]),
                        ),
                      ),
                      if (i < all.length - 1) const Divider(height: 1, color: AppColors.border),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('الإجمالي لـ ${selected.length} منتج',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text('${total.toStringAsFixed(0)} د.ل',
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
                  label: Text('أضف ${selected.length} للسلة',
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
  const _ReviewsSnippet({required this.productId, required this.count, required this.rating});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(_productReviewsProvider(productId));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('التقييمات ($count)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const Spacer(),
            GestureDetector(
              onTap: () => safePush(context, '/product/$productId/reviews'),
              child: const Text('الكل ←',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
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
                Text('بناءً على $count تقييم موثّق',
                  style: const TextStyle(fontSize: 12, color: AppColors.ink3)),
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
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: Text(review.reviewerName.isNotEmpty ? review.reviewerName[0] : '?',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.teal600)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(review.reviewerName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(review.createdAt ?? '',
                  style: const TextStyle(fontSize: 11, color: AppColors.ink3)),
              ],
            )),
            Row(children: List.generate(5, (i) => Icon(
              i < review.rating ? Icons.star_rounded : Icons.star_border_rounded,
              size: 13, color: AppColors.gold))),
          ]),
          const SizedBox(height: 8),
          Text(review.body, style: const TextStyle(fontSize: 13, color: AppColors.ink1, height: 1.5)),
        ],
      ),
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
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(typeName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                if (selections[typeName] != null)
                  Text(selections[typeName]!,
                    style: const TextStyle(fontSize: 13, color: AppColors.ink2)),
              ]),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: options.map((opt) {
                  final isSelected = selections[typeName] == opt.value;
                  final isOutOfStock = !product.variations.any((v) =>
                      v.attributes.any((a) => a.typeName == typeName && a.value == opt.value) &&
                      v.stockQuantity > 0);
                  return GestureDetector(
                    onTap: isOutOfStock ? null : () => onChanged(typeName, opt.value),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.ink0
                                : isOutOfStock ? const Color(0xFFF2F2F2)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? AppColors.ink0
                                  : isOutOfStock ? const Color(0xFFDDDDDD)
                                  : AppColors.border,
                              width: 1.5),
                          ),
                          child: Text(opt.value,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: isSelected ? Colors.white
                                  : isOutOfStock ? const Color(0xFFBBBBBB)
                                  : AppColors.ink0)),
                        ),
                        if (isOutOfStock)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(9),
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

// ── Qty selector ──────────────────────────────────────────────────────────────

class _QtySelector extends StatelessWidget {
  final int qty;
  final ValueChanged<int> onChanged;
  final bool enabled;
  const _QtySelector({required this.qty, required this.onChanged, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Text('الكمية', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      const Spacer(),
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
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
          _QtyBtn(Icons.add, enabled ? () => onChanged(qty + 1) : null),
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
        color: onTap != null ? AppColors.ink0 : AppColors.border),
    ),
  );
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
              color: AppColors.border,
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
                const Text('تمت الإضافة للسلة',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('$qty× $name',
                  style: const TextStyle(fontSize: 12, color: AppColors.ink2),
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
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('مواصلة التسوّق',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, color: AppColors.ink0)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('عرض السلة',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.ink0)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
