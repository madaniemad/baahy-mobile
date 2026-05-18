import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/product.dart';

class CategorySection {
  final Category category;
  final List<Product> products;
  const CategorySection({required this.category, required this.products});
}

class HomeData {
  final List<Product> featured;
  final List<Product> newArrivals;
  final List<Product> popular;
  final List<Product> deals;
  final List<Product> budget;
  final List<Category> categories;
  final List<CategorySection> categorySections;
  final bool loading;
  final String? error;

  const HomeData({
    this.featured = const [],
    this.newArrivals = const [],
    this.popular = const [],
    this.deals = const [],
    this.budget = const [],
    this.categories = const [],
    this.categorySections = const [],
    this.loading = false,
    this.error,
  });

  HomeData copyWith({
    List<Product>? featured,
    List<Product>? newArrivals,
    List<Product>? popular,
    List<Product>? deals,
    List<Product>? budget,
    List<Category>? categories,
    List<CategorySection>? categorySections,
    bool? loading,
    String? error,
  }) => HomeData(
    featured: featured ?? this.featured,
    newArrivals: newArrivals ?? this.newArrivals,
    popular: popular ?? this.popular,
    deals: deals ?? this.deals,
    budget: budget ?? this.budget,
    categories: categories ?? this.categories,
    categorySections: categorySections ?? this.categorySections,
    loading: loading ?? this.loading,
    error: error,
  );
}

class HomeNotifier extends StateNotifier<HomeData> {
  final ApiClient _api;
  HomeNotifier(this._api) : super(const HomeData(loading: true)) {
    fetch();
  }

  // Each API call is wrapped independently — one failure never kills the others.
  Future<dynamic> _safeGet(String path, {Map<String, dynamic>? params}) async {
    try {
      final res = await _api.dio.get(path, queryParameters: params);
      return res.data;
    } catch (_) {
      return null;
    }
  }

  List<Product> _products(dynamic data, String path) {
    try {
      dynamic node = data;
      for (final key in path.split('.')) {
        if (node == null) return [];
        node = node[key];
      }
      return (node as List?)?.map((p) => Product.fromJson(p)).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  List<Category> _categories(dynamic data) {
    try {
      return (data?['data'] as List?)?.map((c) => Category.fromJson(c)).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<void> fetch() async {
    state = state.copyWith(loading: true, error: null);

    final results = await Future.wait([
      _safeGet('/products/featured'),
      _safeGet('/products', params: {'sort': 'latest', 'per_page': 12}),
      _safeGet('/products', params: {'sort': 'popular', 'per_page': 8}),
      _safeGet('/categories'),
      _safeGet('/products', params: {'max_price': 50, 'per_page': 6, 'sort': 'latest'}),
    ]);

    final featured  = _products(results[0], 'data');
    final newArrivals = _products(results[1], 'data.data');
    final popular   = _products(results[2], 'data.data');
    final categories = _categories(results[3]);
    final budget    = _products(results[4], 'data.data');
    final deals     = featured.where((p) => p.hasDiscount).toList();

    // Emit partial data immediately so user sees content while category sections load.
    state = HomeData(
      featured: featured,
      newArrivals: newArrivals,
      popular: popular,
      deals: deals.isNotEmpty ? deals : featured.take(6).toList(),
      budget: budget,
      categories: categories,
      categorySections: state.categorySections,
      loading: categories.isNotEmpty, // still loading if we'll fetch category sections
    );

    // Fetch category sections (top 5 root categories) independently.
    if (categories.isNotEmpty) {
      final rootCats = categories.take(5).toList();
      final catResults = await Future.wait(
        rootCats.map((cat) => _safeGet('/products',
          params: {'category_id': cat.id, 'per_page': 8, 'sort': 'popular'})),
      );

      final sections = <CategorySection>[];
      for (var i = 0; i < rootCats.length; i++) {
        final prods = _products(catResults[i], 'data.data');
        if (prods.isNotEmpty) {
          sections.add(CategorySection(category: rootCats[i], products: prods));
        }
      }

      state = state.copyWith(categorySections: sections, loading: false);
    } else {
      state = state.copyWith(loading: false);
    }
  }
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeData>((ref) {
  return HomeNotifier(ApiClient.instance);
});
