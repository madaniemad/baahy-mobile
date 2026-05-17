import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/cart.dart';

class CartState {
  final List<CartItem> items;
  final bool loading;
  final double? shippingCost;
  final double? discount;
  const CartState({
    this.items = const [],
    this.loading = false,
    this.shippingCost,
    this.discount,
  });

  double get subtotal => items.fold(0, (s, i) => s + i.total);
  double get total => subtotal + (shippingCost ?? 0) - (discount ?? 0);
  int get count => items.fold(0, (s, i) => s + i.quantity);

  CartState copyWith({List<CartItem>? items, bool? loading, double? shippingCost, double? discount}) =>
      CartState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        shippingCost: shippingCost ?? this.shippingCost,
        discount: discount ?? this.discount,
      );
}

class CartNotifier extends StateNotifier<CartState> {
  final ApiClient _api;
  CartNotifier(this._api) : super(const CartState()) {
    fetch();
  }

  Future<void> fetch() async {
    if (!await _api.isLoggedIn) return;
    state = state.copyWith(loading: true);
    try {
      final res = await _api.dio.get('/cart');
      final data = res.data['data'];
      final items = (data['items'] as List?)
          ?.map((i) => CartItem.fromJson(i)).toList() ?? [];
      state = CartState(
        items: items,
        shippingCost: (data['shipping_cost'] as num?)?.toDouble(),
        discount: (data['discount'] as num?)?.toDouble(),
      );
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> add(int productId, {int? variationId, int qty = 1}) async {
    await _api.dio.post('/cart', data: {
      'product_id': productId,
      if (variationId != null) 'variation_id': variationId,
      'quantity': qty,
    });
    await fetch();
  }

  Future<void> updateQty(int itemId, int qty) async {
    if (qty < 1) {
      await remove(itemId);
      return;
    }
    await _api.dio.put('/cart/$itemId', data: {'quantity': qty});
    await fetch();
  }

  Future<void> remove(int itemId) async {
    await _api.dio.delete('/cart/$itemId');
    await fetch();
  }

  Future<void> clear() async {
    await _api.dio.delete('/cart');
    state = const CartState();
  }

  Future<Map<String, dynamic>?> applyCoupon(String code) async {
    try {
      final res = await _api.dio.post('/cart/coupon', data: {'code': code});
      state = state.copyWith(discount: (res.data['data']['discount'] as num?)?.toDouble());
      return res.data['data'];
    } catch (e) {
      return null;
    }
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier(ApiClient.instance);
});

final cartCountProvider = Provider<int>((ref) => ref.watch(cartProvider).count);
