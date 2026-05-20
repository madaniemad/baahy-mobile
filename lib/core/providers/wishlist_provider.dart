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
          ?.map((item) => item['product']['id'] as int).toSet() ?? {};
      state = ids;
    } catch (_) {}
  }

  Future<bool> toggle(int productId) async {
    if (!await _api.isLoggedIn) return false;
    state = Set.from(state)..toggle(productId);
    try {
      await _api.dio.post('/wishlist/toggle', data: {'product_id': productId});
      return true;
    } catch (_) {
      state = Set.from(state)..toggle(productId);
      return false;
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

class WishlistProductsNotifier extends StateNotifier<AsyncValue<List<Product>>> {
  final ApiClient _api;
  WishlistProductsNotifier(this._api) : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    if (!await _api.isLoggedIn) {
      state = const AsyncValue.data([]);
      return;
    }
    try {
      final res = await _api.dio.get('/wishlist');
      state = AsyncValue.data((res.data['data'] as List?)
          ?.map((item) => Product.fromJson(item['product'])).toList() ?? []);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void remove(int productId) {
    state.whenData((products) {
      state = AsyncValue.data(products.where((p) => p.id != productId).toList());
    });
  }
}

final wishlistProductsProvider =
    StateNotifierProvider<WishlistProductsNotifier, AsyncValue<List<Product>>>((ref) {
  return WishlistProductsNotifier(ApiClient.instance);
});
