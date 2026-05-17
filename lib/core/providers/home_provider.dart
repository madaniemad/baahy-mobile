import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/product.dart';

class HomeData {
  final List<Product> featured;
  final List<Product> newArrivals;
  final List<Product> popular;
  final List<Category> categories;
  final bool loading;
  final String? error;

  const HomeData({
    this.featured = const [],
    this.newArrivals = const [],
    this.popular = const [],
    this.categories = const [],
    this.loading = false,
    this.error,
  });

  HomeData copyWith({
    List<Product>? featured,
    List<Product>? newArrivals,
    List<Product>? popular,
    List<Category>? categories,
    bool? loading,
    String? error,
  }) => HomeData(
    featured: featured ?? this.featured,
    newArrivals: newArrivals ?? this.newArrivals,
    popular: popular ?? this.popular,
    categories: categories ?? this.categories,
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
        _api.dio.get('/products', queryParameters: {'sort': 'latest', 'per_page': 10}),
        _api.dio.get('/products', queryParameters: {'sort': 'popular', 'per_page': 10}),
        _api.dio.get('/categories'),
      ]);

      final featured = (results[0].data['data'] as List?)
          ?.map((p) => Product.fromJson(p)).toList() ?? [];
      final newArrivals = (results[1].data['data']['data'] as List?)
          ?.map((p) => Product.fromJson(p)).toList() ?? [];
      final popular = (results[2].data['data']['data'] as List?)
          ?.map((p) => Product.fromJson(p)).toList() ?? [];
      final categories = (results[3].data['data'] as List?)
          ?.map((c) => Category.fromJson(c)).toList() ?? [];

      state = HomeData(
        featured: featured,
        newArrivals: newArrivals,
        popular: popular,
        categories: categories,
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
