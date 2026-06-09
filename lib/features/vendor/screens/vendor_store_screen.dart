import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/product.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/product_card.dart';

class VendorStoreScreen extends ConsumerStatefulWidget {
  final int vendorId;
  const VendorStoreScreen({required this.vendorId, super.key});

  @override
  ConsumerState<VendorStoreScreen> createState() => _VendorStoreScreenState();
}

class _VendorStoreScreenState extends ConsumerState<VendorStoreScreen> {
  Vendor? _vendor;
  List<Product> _products = [];
  bool _loadingVendor = true;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  static const _perPage = 20;

  @override
  void initState() {
    super.initState();
    _loadVendor();
    _loadProducts(1);
  }

  Future<void> _loadVendor() async {
    try {
      final res = await ApiClient.instance.dio.get('/vendors/${widget.vendorId}');
      if (mounted) setState(() { _vendor = Vendor.fromJson(res.data['data']); _loadingVendor = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingVendor = false);
    }
  }

  Future<void> _loadProducts(int page) async {
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
    } catch (_) {
      if (mounted) setState(() { _loading = false; _loadingMore = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    final vendorName = _vendor != null
        ? (isAr && _vendor!.storeNameAr.isNotEmpty ? _vendor!.storeNameAr : _vendor!.storeName)
        : '';

    return Scaffold(
      backgroundColor: context.col.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            title: _loadingVendor
                ? const SizedBox.shrink()
                : Text(
                    vendorName.isNotEmpty ? vendorName : context.s.storeLabel,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Cairo',
                      fontSize: 17, fontWeight: FontWeight.w700),
                  ),
          ),

          // Vendor header
          if (_vendor != null)
            SliverToBoxAdapter(
              child: Container(
                color: context.col.surface,
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: context.col.surfaceSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.col.border),
                    ),
                    child: _vendor!.logo != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(imageUrl: _vendor!.logo!, fit: BoxFit.cover))
                        : Icon(Icons.store_outlined, size: 30, color: context.col.ink2),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _vendor!.storeNameAr.isNotEmpty ? _vendor!.storeNameAr : _vendor!.storeName,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      if (_vendor!.city != null && _vendor!.city!.isNotEmpty)
                        Text(_vendor!.city!,
                          style: TextStyle(fontSize: 13, color: context.col.ink3)),
                    ],
                  )),
                ]),
              ),
            ),

          // Section header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(context.s.storeProducts,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),

          // Products grid
          if (_loading)
            const SliverToBoxAdapter(
              child: SizedBox(height: 200,
                child: Center(child: CircularProgressIndicator(color: AppColors.primary))))
          else if (_products.isEmpty)
            SliverToBoxAdapter(
              child: Center(child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(context.s.noProductsNow, style: TextStyle(color: context.col.ink3)))))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => ProductCard(product: _products[i]),
                  childCount: _products.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 344,
                ),
              ),
            ),

          // Load more button
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: Text(context.s.viewMore,
                          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700,
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
