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

  Future<void> fetch() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final results = await Future.wait([
        _api.dio.get('/products/featured'),
        _api.dio.get('/products', queryParameters: {'sort': 'latest', 'per_page': 12}),
        _api.dio.get('/products', queryParameters: {'sort': 'popular', 'per_page': 8}),
        _api.dio.get('/categories'),
        _api.dio.get('/products', queryParameters: {'max_price': 50, 'per_page': 6, 'sort': 'latest'}),
      ]);

      final featured = (results[0].data['data'] as List?)
          ?.map((p) => Product.fromJson(p)).toList() ?? [];
      final newArrivals = (results[1].data['data']['data'] as List?)
          ?.map((p) => Product.fromJson(p)).toList() ?? [];
      final popular = (results[2].data['data']['data'] as List?)
          ?.map((p) => Product.fromJson(p)).toList() ?? [];
      final categories = (results[3].data['data'] as List?)
          ?.map((c) => Category.fromJson(c)).toList() ?? [];
      final budget = (results[4].data['data']['data'] as List?)
          ?.map((p) => Product.fromJson(p)).toList() ?? [];

      // Deals = featured products with discounts, or just all discounted
      final deals = featured.where((p) => p.hasDiscount).toList();

      // Category sections — take top 5 root categories and fetch products for each
      final rootCats = categories.take(5).toList();
      List<CategorySection> sections = [];
      if (rootCats.isNotEmpty) {
        final catResults = await Future.wait(
          rootCats.map((cat) => _api.dio.get('/products',
            queryParameters: {'category_id': cat.id, 'per_page': 8, 'sort': 'latest'})),
        );
        for (var i = 0; i < rootCats.length; i++) {
          final prods = (catResults[i].data['data']['data'] as List?)
              ?.map((p) => Product.fromJson(p)).toList() ?? [];
          if (prods.isNotEmpty) {
            sections.add(CategorySection(category: rootCats[i], products: prods));
          }
        }
      }

      state = HomeData(
        featured: featured,
        newArrivals: newArrivals,
        popular: popular,
        deals: deals.isNotEmpty ? deals : featured.take(6).toList(),
        budget: budget,
        categories: categories,
        categorySections: sections,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeData>((ref) {
  return HomeNotifier(ApiClient.instance);
});
