import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../api/api_client.dart';
import '../models/product.dart';
import 'auth_provider.dart';

class WishlistNotifier extends StateNotifier<Set<int>> {
  final ApiClient _api;
  WishlistNotifier(this._api, Ref ref) : super({}) {
    fetch();
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (!next.isLoggedIn) {
        state = {}; // clear local cache only — server still holds the wishlist
      } else if (prev?.isLoggedIn != true) {
        fetch(); // just logged in — reload from server
      }
    });
  }

  Future<void> fetch() async {
    if (!await _api.isLoggedIn) return;
    try {
      final res = await _api.dio.get('/wishlist');
      final ids = <int>{};
      for (final item in (res.data['data'] as List? ?? [])) {
        final product = item['product'];
        if (product == null) continue;
        final id = product['id'];
        if (id is int) ids.add(id);
        else if (id is num) ids.add(id.toInt());
        else if (id is String) { final n = int.tryParse(id); if (n != null) ids.add(n); }
      }
      state = ids;
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
    }
  }

  Future<bool> toggle(int productId) async {
    if (!await _api.isLoggedIn) return false;
    state = Set.from(state)..toggle(productId);
    try {
      await _api.dio.post('/wishlist/toggle', data: {'product_id': productId});
      return true;
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
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
  return WishlistNotifier(ApiClient.instance, ref);
});

class WishlistProductsNotifier extends StateNotifier<AsyncValue<List<Product>>> {
  final ApiClient _api;
  WishlistProductsNotifier(this._api, Ref ref) : super(const AsyncValue.loading()) {
    fetch();
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (!next.isLoggedIn) {
        state = const AsyncValue.data([]); // clear local only — server retains it
      } else if (prev?.isLoggedIn != true) {
        fetch(); // just logged in — reload from server
      }
    });
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
  return WishlistProductsNotifier(ApiClient.instance, ref);
});
