import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../models/cart.dart';
import '../models/product.dart';
import '../models/app_config.dart';
import '../models/shipping_rate.dart';
import 'app_config_provider.dart';
import 'shipping_provider.dart';
import 'auth_provider.dart';

const _kCartKey = 'baahy_cart';

class CartState {
  final List<CartItem> items;
  final String? couponCode;
  final double discountAmount;
  // City-specific rate (null = city unknown, fall back to fallbackShippingFee)
  final ShippingRate? cityRate;
  // Fallback estimate shown before city is selected
  final double fallbackShippingFee;
  final double collectionFee;
  // True while background vendor fee refresh is in progress
  final bool feesRefreshing;

  const CartState({
    this.items = const [],
    this.couponCode,
    this.discountAmount = 0,
    this.cityRate,
    this.fallbackShippingFee = 10.0,
    this.collectionFee = 0,
    this.feesRefreshing = false,
  });

  double get subtotal => items.fold(0, (s, i) => s + i.total);

  bool get hasVendorFulfilledItems => items.any((i) => !i.product.fulfilledByBaahy);

  // Sum collection fees across unique vendors. Zero if vendor has no fee set.
  double get totalCollectionFee {
    final seenIds = <int>{};
    double total = 0;
    for (final item in items) {
      if (item.product.fulfilledByBaahy) continue;
      final vendor = item.product.vendor;
      if (vendor == null) continue;
      if (seenIds.contains(vendor.id)) continue;
      seenIds.add(vendor.id);
      total += vendor.collectionFee ?? 0;
    }
    return total;
  }

  double get deliveryFee {
    final base = cityRate != null
        ? cityRate!.effectiveRate(subtotal)
        : (subtotal >= 150 ? 0 : fallbackShippingFee);
    if (base == 0) return 0; // free shipping — waive collection fee too
    return base + totalCollectionFee;
  }

  double? get freeShippingThreshold => cityRate?.freeShippingThreshold;

  // For UI: how much more until free shipping kicks in (0 if city has no threshold)
  double get freeShippingRemaining {
    if (freeShippingThreshold == null) return 0;
    return subtotal >= freeShippingThreshold! ? 0 : freeShippingThreshold! - subtotal;
  }

  double get total => subtotal - discountAmount + deliveryFee;
  int get count => items.fold(0, (s, i) => s + i.quantity);

  CartState copyWith({
    List<CartItem>? items,
    String? couponCode,
    double? discountAmount,
    ShippingRate? cityRate,
    bool clearCityRate = false,
    double? fallbackShippingFee,
    double? collectionFee,
    bool clearCoupon = false,
    bool? feesRefreshing,
  }) => CartState(
    items: items ?? this.items,
    couponCode: clearCoupon ? null : (couponCode ?? this.couponCode),
    discountAmount: clearCoupon ? 0 : (discountAmount ?? this.discountAmount),
    cityRate: clearCityRate ? null : (cityRate ?? this.cityRate),
    fallbackShippingFee: fallbackShippingFee ?? this.fallbackShippingFee,
    collectionFee: collectionFee ?? this.collectionFee,
    feesRefreshing: feesRefreshing ?? this.feesRefreshing,
  );
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier({
    double fallbackShippingFee = 10.0,
    double collectionFee = 0,
  }) : super(CartState(fallbackShippingFee: fallbackShippingFee, collectionFee: collectionFee)) {
    _load();
  }

  void updateCollectionFee(double fee) {
    state = state.copyWith(collectionFee: fee);
  }

  void updateCityRate(ShippingRate? rate) {
    state = state.copyWith(cityRate: rate, clearCityRate: rate == null);
    // Always sync collection fee from city rate so switching cities resets it
    if (rate != null) {
      state = state.copyWith(collectionFee: rate.collectionFee);
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCartKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((j) => CartItem.fromJson(j as Map<String, dynamic>))
          .toList();
      state = state.copyWith(items: list);
      // Refresh vendor data in background so stale cached collection_fee gets updated
      await _refreshVendorFees(list);
    } catch (_) {}
  }

  Future<void> _refreshVendorFees(List<CartItem> items) async {
    // Refresh all vendor-fulfilled items so stale cached collection_fee values are corrected
    final staleItems = items.where((i) =>
        !i.product.fulfilledByBaahy &&
        i.product.vendor != null).toList();
    if (staleItems.isEmpty) return;
    state = state.copyWith(feesRefreshing: true);
    final uniqueProductIds = staleItems.map((i) => i.productId).toSet();
    for (final pid in uniqueProductIds) {
      try {
        final res = await ApiClient.instance.dio.get('/products/$pid');
        final fresh = Product.fromJson(res.data['data'] as Map<String, dynamic>);
        if (fresh.vendor == null) continue;
        state = state.copyWith(
          items: state.items.map((i) {
            if (i.productId == pid) {
              return CartItem(
                productId: i.productId,
                variationId: i.variationId,
                quantity: i.quantity,
                product: fresh,
                variation: i.variation,
              );
            }
            return i;
          }).toList(),
        );
      } catch (_) {}
    }
    state = state.copyWith(feesRefreshing: false);
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
    state = state.copyWith(items: items);
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
    state = state.copyWith(items: items);
    await _save();
  }

  Future<void> remove(String key) async {
    final items = state.items.where((i) => i.key != key).toList();
    state = state.copyWith(items: items);
    await _save();
  }

  Future<void> clear() async {
    state = CartState(fallbackShippingFee: state.fallbackShippingFee, collectionFee: state.collectionFee);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCartKey);
  }

  Future<String?> applyCoupon(String code) async {
    if (code.trim().isEmpty) return 'أدخل رمز الكوبون';
    try {
      final res = await ApiClient.instance.dio.post('/coupons/apply', data: {
        'code': code.trim(),
        'order_total': state.subtotal,
      });
      final raw = res.data['data']?['discount'] ?? res.data['data']?['discount_amount'];
      final discount = raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '') ?? 0.0;
      state = state.copyWith(couponCode: code.trim(), discountAmount: discount);
      return null;
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      return 'الكوبون غير صالح أو منتهي الصلاحية';
    }
  }

  void removeCoupon() {
    state = state.copyWith(clearCoupon: true);
  }

  Future<String?> validate() async {
    if (state.items.isEmpty) return 'السلة فارغة';
    try {
      final res = await ApiClient.instance.dio.post('/cart/validate', data: {
        'items': state.items
            .map((i) => {
                  'product_id': i.productId,
                  if (i.variationId != null) 'variation_id': i.variationId,
                  'quantity': i.quantity,
                  'price': i.unitPrice,
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
    } catch (e) {
      try {
        final resp = (e as dynamic).response;
        final status = resp?.statusCode as int?;
        // Skip validation for server errors or unimplemented endpoint
        if (status == null || status >= 500 || status == 404 || status == 405) return null;
        // Surface meaningful 4xx messages (e.g. out of stock from backend)
        final data = resp?.data;
        if (data is Map && data['message'] != null) return data['message'].toString();
      } catch (_) {}
      return null;
    }
  }

  // Returns all cart issues (unavailable OR price-changed) so the cart screen
  // can prompt the user before entering checkout.
  // type: 'unavailable' | 'price_changed'
  Future<List<({CartItem item, String message, String type, double? newPrice, double? oldPrice})>>
      validateAndGetIssues() async {
    if (state.items.isEmpty) return [];
    try {
      final res = await ApiClient.instance.dio.post('/cart/validate', data: {
        'items': state.items
            .map((i) => {
                  'product_id': i.productId,
                  if (i.variationId != null) 'variation_id': i.variationId,
                  'quantity': i.quantity,
                  'price': i.unitPrice,
                })
            .toList(),
      });
      if (res.data['valid'] == true) return [];
      final issues = <({CartItem item, String message, String type, double? newPrice, double? oldPrice})>[];
      for (final apiItem in (res.data['items'] as List? ?? [])) {
        if (apiItem['ok'] != false) continue;
        final pid = apiItem['product_id'] as int?;
        final vid = apiItem['variation_id'] as int?;
        final msg = (apiItem['message'] as String?) ?? 'مشكلة في المنتج';
        final issueType = (apiItem['type'] as String?) ?? 'unavailable';
        final newPrice = (apiItem['current_price'] as num?)?.toDouble();
        final oldPrice = (apiItem['old_price'] as num?)?.toDouble();
        final cartItem = state.items.where((i) =>
          i.productId == pid &&
          (vid == null ? i.variationId == null : i.variationId == vid)
        ).firstOrNull;
        if (cartItem != null) {
          issues.add((item: cartItem, message: msg, type: issueType,
            newPrice: newPrice, oldPrice: oldPrice));
        }
      }
      if (issues.isEmpty) {
        return state.items
            .map((i) => (item: i, message: 'بعض المنتجات غير متاحة',
                type: 'unavailable', newPrice: null, oldPrice: null))
            .take(1)
            .toList();
      }
      return issues;
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      return [];
    }
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  final config = ref.read(appConfigProvider);
  final notifier = CartNotifier(
    fallbackShippingFee: config.shippingFee,
    collectionFee: config.collectionFee,
  );
  ref.listen<AppConfig>(appConfigProvider, (_, next) {
    notifier.updateCollectionFee(next.collectionFee);
  });
  ref.listen<ShippingRate?>(cityShippingRateProvider, (_, next) {
    notifier.updateCityRate(next);
  });
  // Clear the local cart on logout so the next user on a shared device doesn't
  // inherit it (the server retains each user's authed cart).
  ref.listen<AuthState>(authProvider, (prev, next) {
    if (prev?.isLoggedIn == true && !next.isLoggedIn) notifier.clear();
  });
  // Apply immediately if city rate is already available
  final initialRate = ref.read(cityShippingRateProvider);
  if (initialRate != null) notifier.updateCityRate(initialRate);
  return notifier;
});

final cartCountProvider =
    Provider<int>((ref) => ref.watch(cartProvider).count);
