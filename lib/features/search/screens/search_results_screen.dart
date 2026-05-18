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

class _FilterState {
  final double? minPrice;
  final double? maxPrice;
  final int? minRating;   // 1-5, null = any
  final bool inStockOnly;

  const _FilterState({
    this.minPrice,
    this.maxPrice,
    this.minRating,
    this.inStockOnly = false,
  });

  bool get isActive =>
      minPrice != null || maxPrice != null || minRating != null || inStockOnly;

  _FilterState copyWith({
    Object? minPrice = _unset,
    Object? maxPrice = _unset,
    Object? minRating = _unset,
    bool? inStockOnly,
  }) => _FilterState(
    minPrice: identical(minPrice, _unset) ? this.minPrice : minPrice as double?,
    maxPrice: identical(maxPrice, _unset) ? this.maxPrice : maxPrice as double?,
    minRating: identical(minRating, _unset) ? this.minRating : minRating as int?,
    inStockOnly: inStockOnly ?? this.inStockOnly,
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
  _FilterState _filters = const _FilterState();

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
        if (widget.categoryId != null) 'category_id': widget.categoryId,
        'sort': _sort,
        'page': _page,
        'per_page': 20,
        if (_filters.minPrice != null) 'min_price': _filters.minPrice,
        if (_filters.maxPrice != null) 'max_price': _filters.maxPrice,
        if (_filters.minRating != null) 'min_rating': _filters.minRating,
        if (_filters.inStockOnly) 'in_stock': 1,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _FilterSheet(initial: _filters),
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
                    mainAxisExtent: 300,
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

class _FilterSheet extends StatefulWidget {
  final _FilterState initial;
  const _FilterSheet({required this.initial});
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  int? _rating;
  late bool _inStock;

  @override
  void initState() {
    super.initState();
    _minCtrl = TextEditingController(
      text: widget.initial.minPrice?.toStringAsFixed(0) ?? '');
    _maxCtrl = TextEditingController(
      text: widget.initial.maxPrice?.toStringAsFixed(0) ?? '');
    _rating = widget.initial.minRating;
    _inStock = widget.initial.inStockOnly;
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
    ));
  }

  void _reset() {
    setState(() {
      _minCtrl.clear();
      _maxCtrl.clear();
      _rating = null;
      _inStock = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [

        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: AppColors.border,
            borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),

        Row(children: [
          const Text('الفلاتر',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const Spacer(),
          TextButton(onPressed: _reset,
            child: const Text('إعادة تعيين',
              style: TextStyle(color: AppColors.ink2))),
        ]),
        const SizedBox(height: 16),

        // Price range
        const Text('نطاق السعر (د.ل)',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700,
            color: AppColors.ink1)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _PriceField(controller: _minCtrl, hint: 'الحد الأدنى'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text('—', style: TextStyle(color: AppColors.ink3))),
          Expanded(
            child: _PriceField(controller: _maxCtrl, hint: 'الحد الأقصى'),
          ),
        ]),
        const SizedBox(height: 20),

        // Rating
        const Text('الحد الأدنى للتقييم',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700,
            color: AppColors.ink1)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: List.generate(5, (i) {
            final star = i + 1;
            final selected = _rating == star;
            return GestureDetector(
              onTap: () => setState(() => _rating = selected ? null : star),
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    const SizedBox(width: 3),
                    Text('$star+',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: selected ? AppColors.ink0 : AppColors.ink1)),
                  ]),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),

        // In-stock toggle
        GestureDetector(
          onTap: () => setState(() => _inStock = !_inStock),
          child: Row(children: [
            const Expanded(child: Text('متوفّر فقط',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700,
                color: AppColors.ink1))),
            Switch(
              value: _inStock,
              onChanged: (v) => setState(() => _inStock = v),
              activeColor: AppColors.primary,
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // Apply
        SizedBox(
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
      ]),
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
