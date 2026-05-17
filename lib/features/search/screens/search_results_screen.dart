import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/product.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/product_card.dart';

final _sortOptions = [
  ('latest', 'الأحدث'),
  ('popular', 'الأكثر مبيعاً'),
  ('price_asc', 'الأرخص'),
  ('price_desc', 'الأغلى'),
];

class SearchResultsScreen extends ConsumerStatefulWidget {
  final String query;
  const SearchResultsScreen({required this.query, super.key});

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

  @override
  void initState() {
    super.initState();
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
        'sort': _sort,
        'page': _page,
        'per_page': 20,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.query.isNotEmpty ? widget.query : 'المنتجات',
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
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
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: AppColors.ink4),
                      SizedBox(height: 12),
                      Text('لا توجد نتائج',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: AppColors.ink2)),
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
                    childAspectRatio: 0.68,
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
