import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../api/api_client.dart';
import '../models/product.dart';
import 'auth_provider.dart';

class WishlistNotifier extends StateNotifier<Set<int>> {
  final ApiClient _api;
  final Ref _ref;
  WishlistNotifier(this._api, Ref ref) : _ref = ref, super({}) {
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
    final nowSaved = !state.contains(productId);
    state = Set.from(state)..toggle(productId);
    try {
      await _api.dio.post('/wishlist/toggle', data: {'product_id': productId});
      // Membership lives here, but the wishlist SCREEN and the tab badge read the product
      // list, which had no way to learn about an addition — it has fetch() and remove() and
      // nothing else. So tapping a heart coloured it and left the badge stale until the list
      // happened to be refetched. Keep the two in step: a removal is local and instant, an
      // addition needs the product object and so costs one refetch.
      final products = _ref.read(wishlistProductsProvider.notifier);
      if (nowSaved) {
        products.fetch();
      } else {
        products.remove(productId);
      }
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
