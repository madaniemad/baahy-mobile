import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../models/cart.dart';
import '../models/product.dart';

const _kCartKey = 'baahy_cart';

const double kFreeShippingThreshold = 150;
const double kDeliveryFee = 10;

class CartState {
  final List<CartItem> items;
  final String? couponCode;
  final double discountAmount;

  const CartState({
    this.items = const [],
    this.couponCode,
    this.discountAmount = 0,
  });

  double get subtotal => items.fold(0, (s, i) => s + i.total);
  double get deliveryFee => subtotal >= kFreeShippingThreshold ? 0 : kDeliveryFee;
  double get freeShippingRemaining =>
      subtotal >= kFreeShippingThreshold ? 0 : kFreeShippingThreshold - subtotal;
  double get total => subtotal - discountAmount + deliveryFee;
  int get count => items.fold(0, (s, i) => s + i.quantity);

  CartState copyWith({
    List<CartItem>? items,
    String? couponCode,
    double? discountAmount,
    bool clearCoupon = false,
  }) => CartState(
    items: items ?? this.items,
    couponCode: clearCoupon ? null : (couponCode ?? this.couponCode),
    discountAmount: clearCoupon ? 0 : (discountAmount ?? this.discountAmount),
  );
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCartKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((j) => CartItem.fromJson(j as Map<String, dynamic>))
          .toList();
      state = CartState(items: list);
    } catch (_) {}
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kCartKey, jsonEncode(state.items.map((i) => i.toJson()).toList()));
  }

  Future<void> add(Product product,
      {ProductVariation? variation, int qty = 1}) async {
    final key =
        variation != null ? '${product.id}_${variation.id}' : '${product.id}';
    final items = List<CartItem>.from(state.items);
    final idx = items.indexWhere((i) => i.key == key);
    if (idx >= 0) {
      items[idx] = items[idx].copyWith(quantity: items[idx].quantity + qty);
    } else {
      items.add(CartItem(
        productId: product.id,
        variationId: variation?.id,
        product: product,
        variation: variation,
        quantity: qty,
      ));
    }
    state = CartState(items: items);
    await _save();
  }

  Future<void> updateQty(String key, int qty) async {
    if (qty < 1) {
      await remove(key);
      return;
    }
    final items = state.items
        .map((i) => i.key == key ? i.copyWith(quantity: qty) : i)
        .toList();
    state = CartState(items: items);
    await _save();
  }

  Future<void> remove(String key) async {
    final items = state.items.where((i) => i.key != key).toList();
    state = CartState(items: items);
    await _save();
  }

  Future<void> clear() async {
    state = const CartState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCartKey);
  }

  /// Returns null on success (coupon applied), or an Arabic error message.
  Future<String?> applyCoupon(String code) async {
    if (code.trim().isEmpty) return 'أدخل رمز الكوبون';
    try {
      final res = await ApiClient.instance.dio.post('/coupons/validate', data: {
        'code': code.trim(),
        'subtotal': state.subtotal,
      });
      final raw = res.data['data']?['discount_amount'];
      final discount = raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '') ?? 0.0;
      state = state.copyWith(couponCode: code.trim(), discountAmount: discount);
      return null;
    } catch (_) {
      return 'الكوبون غير صالح أو منتهي الصلاحية';
    }
  }

  void removeCoupon() {
    state = state.copyWith(clearCoupon: true);
  }

  /// Validates cart with the server. Returns null if all items are valid,
  /// or an Arabic error message if something is wrong.
  Future<String?> validate() async {
    if (state.items.isEmpty) return 'السلة فارغة';
    try {
      final res = await ApiClient.instance.dio.post('/cart/validate', data: {
        'items': state.items
            .map((i) => {
                  'product_id': i.productId,
                  if (i.variationId != null) 'variation_id': i.variationId,
                  'quantity': i.quantity,
                })
            .toList(),
      });
      if (res.data['valid'] == true) return null;
      for (final item in (res.data['items'] as List? ?? [])) {
        if (item['ok'] == false) {
          return item['message'] as String? ?? 'بعض المنتجات غير متاحة';
        }
      }
      return 'بعض المنتجات غير متاحة';
    } catch (_) {
      return 'تعذر التحقق من السلة';
    }
  }
}

final cartProvider =
    StateNotifierProvider<CartNotifier, CartState>((ref) => CartNotifier());

final cartCountProvider =
    Provider<int>((ref) => ref.watch(cartProvider).count);
