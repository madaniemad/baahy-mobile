import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/product.dart';

class WishlistNotifier extends StateNotifier<Set<int>> {
  final ApiClient _api;
  WishlistNotifier(this._api) : super({}) {
    fetch();
  }

  Future<void> fetch() async {
    if (!await _api.isLoggedIn) return;
    try {
      final res = await _api.dio.get('/wishlist');
      final ids = (res.data['data'] as List?)
          ?.map((p) => p['id'] as int).toSet() ?? {};
      state = ids;
    } catch (_) {}
  }

  Future<void> toggle(int productId) async {
    final wasIn = state.contains(productId);
    state = Set.from(state)..toggle(productId);
    try {
      if (wasIn) {
        await _api.dio.delete('/wishlist/$productId');
      } else {
        await _api.dio.post('/wishlist', data: {'product_id': productId});
      }
    } catch (_) {
      state = Set.from(state)..toggle(productId);
    }
  }

  bool contains(int id) => state.contains(id);
}

extension _SetToggle<T> on Set<T> {
  void toggle(T value) => contains(value) ? remove(value) : add(value);
}

final wishlistProvider = StateNotifierProvider<WishlistNotifier, Set<int>>((ref) {
  return WishlistNotifier(ApiClient.instance);
});

class WishlistProductsNotifier extends StateNotifier<List<Product>> {
  final ApiClient _api;
  WishlistProductsNotifier(this._api) : super([]) {
    fetch();
  }

  Future<void> fetch() async {
    if (!await _api.isLoggedIn) return;
    try {
      final res = await _api.dio.get('/wishlist?include=products');
      state = (res.data['data'] as List?)
          ?.map((p) => Product.fromJson(p)).toList() ?? [];
    } catch (_) {}
  }
}

final wishlistProductsProvider =
    StateNotifierProvider<WishlistProductsNotifier, List<Product>>((ref) {
  return WishlistProductsNotifier(ApiClient.instance);
});
