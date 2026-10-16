import 'package:dio/dio.dart';
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
  /// The applied coupon also waives delivery (coupons.free_shipping). Independent of
  /// [discountAmount] — a delivery-only offer discounts nothing and sets only this.
  final bool couponFreeShipping;
  /// The applied coupon cannot be combined with reward credit (coupons.blocks_wallet, from the
  /// /coupons/apply answer). The wallet cap must follow the coupon actually on the order, not only
  /// the auto-offer: a typed code can block the wallet too, and a typed code replaces the offer.
  final bool couponBlocksWallet;
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
    this.couponFreeShipping = false,
    this.couponBlocksWallet = false,
    this.cityRate,
    this.fallbackShippingFee = 10.0,
    this.collectionFee = 0,
    this.feesRefreshing = false,
  });

  double get subtotal => items.fold(0, (s, i) => s + i.total);

  bool get hasVendorFulfilledItems => items.any((i) => !i.product.fulfilledByBaahy);

  /// Collection fee across distinct non-FBB vendors, with the FIRST (largest) one waived.
  ///
  /// The backend has always waived it — OrderController::collectionFeeWithFirstFree returns 0 for
  /// a single vendor — and the web mirrors that. This summed every vendor instead, so a one-vendor
  /// basket (which is most of them) was quoted 5 LYD more than the order was actually created with:
  /// checkout said 585, the server charged 580, and the driver collected the smaller figure.
  ///
  /// Only Tripoli-hub deliveries carry it: the server adds it only when the zone is a `hub_city`
  /// (OrderController), and the website does the same (collectionFeeForCart). Adding it for every
  /// city quoted Benghazi more than the order was created with.
  double get totalCollectionFee => collectionFeeFor(cityRate);

  /// The collection fee for delivery under [rate] — checkout prices the chosen ADDRESS's city,
  /// which need not be the header city this cart's [cityRate] follows.
  double collectionFeeFor(ShippingRate? rate) {
    if (rate?.zoneType != 'hub_city') return 0;
    final perVendor = <int, double>{};
    for (final item in items) {
      if (item.product.fulfilledByBaahy) continue;
      final vendor = item.product.vendor;
      if (vendor == null) continue;
      perVendor[vendor.id] = (vendor.collectionFee ?? 0).toDouble();
    }
    if (perVendor.length <= 1) return 0;
    final fees = perVendor.values.toList()..sort();
    fees.removeLast();                     // the largest single fee is on us
    return fees.fold<double>(0, (sum, f) => sum + f);
  }

  double get deliveryFee {
    // A free-delivery coupon zeroes the whole line, collection fee included — the backend
    // applies it after folding the fee in, so anything less would quote more than we charge.
    if (couponFreeShipping) return 0;
    final base = cityRate != null
        ? cityRate!.effectiveRate(subtotal)
        : 0;
    if (base == 0) return 0; // free shipping — waive collection fee too
    return base + totalCollectionFee;
  }

  /// False until the city's shipping_rates row has actually loaded. The delivery line and
  /// the total must render as unknown, not as a number: quoting zero reads as free delivery,
  /// and quoting the flat fallback invents a price for a city we have not looked up. Both
  /// were wrong the moment free-shipping thresholds were removed from every city
  /// (2026-09-01) — a 150+ cart showed 0 and checkout then charged the real rate.
  ///
  /// A free-delivery coupon settles the line on its own, so that counts as known.
  bool get deliveryFeeKnown => couponFreeShipping || cityRate != null;

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
    bool? couponFreeShipping,
    bool? couponBlocksWallet,
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
    couponFreeShipping: clearCoupon ? false : (couponFreeShipping ?? this.couponFreeShipping),
    couponBlocksWallet: clearCoupon ? false : (couponBlocksWallet ?? this.couponBlocksWallet),
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

  /// Re-fetch every cart item's product so the cached copy (price, sale price,
  /// stock, vendor collection fee) matches reality.
  ///
  /// This used to only refresh VENDOR-fulfilled items, purely to correct stale
  /// collection fees — so a price change was invisible in the cart and only
  /// surfaced at checkout as a red "price changed" toast, while the cart went on
  /// displaying the old price. Refreshing everything means the cart shows the
  /// true price, and the checkout validation stops firing for items that are
  /// simply stale in local storage.
  Future<void> _refreshVendorFees(List<CartItem> items) async {
    if (items.isEmpty) return;
    state = state.copyWith(feesRefreshing: true);
    final uniqueProductIds = items.map((i) => i.productId).toSet();
    // Fetch every product concurrently (a 6-product cart on a slow link used to take 6 serial round
    // trips, with checkout waiting on feesRefreshing), then apply all results in ONE state update.
    final fetched = await Future.wait(uniqueProductIds.map((pid) async {
      try {
        final res = await ApiClient.instance.dio.get('/products/$pid');
        return MapEntry(pid, Product.fromJson(res.data['data'] as Map<String, dynamic>));
      } catch (_) {
        return MapEntry<int, Product?>(pid, null);
      }
    }));
    final freshById = {
      for (final e in fetched)
        if (e.value != null) e.key: e.value!,
    };
    if (freshById.isNotEmpty) {
      state = state.copyWith(
        items: state.items.map((i) {
          final fresh = freshById[i.productId];
          if (fresh == null) return i;
          // Re-resolve the variation from the FRESH product too — its price
          // can move independently of the parent, and keeping the stale one
          // would leave the cart showing an old variation price.
          final freshVariation = i.variationId == null
              ? null
              : fresh.variations
                  .where((v) => v.id == i.variationId)
                  .firstOrNull ?? i.variation;
          final refreshed = CartItem(
            productId: i.productId,
            variationId: i.variationId,
            quantity: i.quantity,
            product: fresh,
            variation: freshVariation,
          );
          // Keep a server-quoted price only while the catalogue still disagrees with it; once the
          // product shows the same figure the correction has nothing left to do.
          final keep = i.priceOverride != null &&
              (refreshed.catalogUnitPrice - i.priceOverride!).abs() > 0.5;
          return keep ? refreshed.copyWith(priceOverride: i.priceOverride) : refreshed;
        }).toList(),
      );
    }
    state = state.copyWith(feesRefreshing: false);
    // Persist the refreshed prices, and re-price the coupon against the new subtotal.
    await _save();
    await _refreshCouponDiscount();
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
    await _refreshCouponDiscount();
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
    await _refreshCouponDiscount();
  }

  Future<void> remove(String key) async {
    final items = state.items.where((i) => i.key != key).toList();
    state = state.copyWith(items: items);
    await _save();
    await _refreshCouponDiscount();
  }

  Future<void> clear() async {
    state = CartState(fallbackShippingFee: state.fallbackShippingFee, collectionFee: state.collectionFee);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCartKey);
  }

  /// Re-ask the server what the coupon is worth against the CURRENT subtotal.
  ///
  /// applyCoupon() stores a fixed discount computed at the moment it was
  /// applied. Without this, changing the cart left the discount pinned to the
  /// old subtotal (apply on a 38 cart -> 4; swap to a 53 cart -> still 4,
  /// instead of ~5). The server recomputes at checkout anyway, so the app was
  /// showing a total that wouldn't match what was actually charged.
  /// Cart lines for /coupons/apply. An at-cost (profit-based) coupon is priced off our margin
  /// on each line, so a total alone gets it refused or mispriced. Ids and quantities only —
  /// the server reads every price and cost itself (same as baahy.com, commit 6f7ee92).
  List<Map<String, dynamic>> _couponLines() => state.items
      .map((i) => {
            'product_id': i.productId,
            if (i.variationId != null) 'variation_id': i.variationId,
            'quantity': i.quantity,
          })
      .toList();

  Future<void> _refreshCouponDiscount() async {
    final code = state.couponCode;
    if (code == null || code.trim().isEmpty) return;

    // Empty cart -> nothing to discount.
    if (state.items.isEmpty) {
      state = state.copyWith(clearCoupon: true);
      return;
    }

    try {
      final res = await ApiClient.instance.dio.post('/coupons/apply', data: {
        'code': code,
        'order_total': state.subtotal,
        'items': _couponLines(),
      });
      final raw = res.data['data']?['discount'] ?? res.data['data']?['discount_amount'];
      final discount =
          raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '') ?? 0.0;
      state = state.copyWith(
        discountAmount: discount,
        couponFreeShipping: res.data['data']?['free_shipping'] == true,
        couponBlocksWallet: res.data['data']?['blocks_wallet'] == true,
      );
    } catch (e, st) {
      // The coupon no longer applies to this cart (min order no longer met,
      // vendor's items removed, ...). Drop it rather than keep showing a stale
      // discount the server will refuse.
      Sentry.captureException(e, stackTrace: st);
      // Only a server refusal (4xx) means the coupon no longer applies; a timeout or dropped
      // connection must not silently strip a valid coupon from the cart.
      final code = e is DioException ? e.response?.statusCode : null;
      if (code == 400 || code == 404 || code == 422) {  // the server refused the coupon
        state = state.copyWith(clearCoupon: true);
      }
    }
  }

  Future<String?> applyCoupon(String code, {bool isAr = true}) async {
    if (code.trim().isEmpty) return isAr ? 'أدخل رمز الكوبون' : 'Enter a coupon code';
    try {
      final res = await ApiClient.instance.dio.post('/coupons/apply', data: {
        'code': code.trim(),
        'order_total': state.subtotal,
        'items': _couponLines(),
      });
      final raw = res.data['data']?['discount'] ?? res.data['data']?['discount_amount'];
      final discount = raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '') ?? 0.0;
      state = state.copyWith(
        couponCode: code.trim(),
        discountAmount: discount,
        couponFreeShipping: res.data['data']?['free_shipping'] == true,
        couponBlocksWallet: res.data['data']?['blocks_wallet'] == true,
      );
      return null;
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      return isAr ? 'الكوبون غير صالح أو منتهي الصلاحية' : 'Invalid or expired coupon';
    }
  }

  void removeCoupon() {
    state = state.copyWith(clearCoupon: true);
  }

  /// Adopt the server's unit price for these cart lines (key → price from /cart/validate
  /// `current_price`). The order is priced by the server anyway; this makes the cart show — and
  /// send back — the same figure, so the next validation passes instead of looping on
  /// "تغير سعر X".
  Future<void> applyServerPrices(Map<String, double> pricesByKey) async {
    if (pricesByKey.isEmpty) return;
    state = state.copyWith(
      items: state.items
          .map((i) => pricesByKey.containsKey(i.key)
              ? i.copyWith(priceOverride: pricesByKey[i.key])
              : i)
          .toList(),
    );
    await _save();
    await _refreshCouponDiscount();
  }

  static double? _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static String _lineKey(dynamic pid, dynamic vid) {
    final p = pid is int ? pid : int.tryParse('$pid');
    final v = vid == null ? null : (vid is int ? vid : int.tryParse('$vid'));
    return v != null ? '${p}_$v' : '$p';
  }

  /// Checkout's last look at the cart. [error] blocks the order. [pricesUpdated] means some
  /// prices moved: they are already applied to the cart, the customer is told once and the next
  /// tap goes through.
  Future<({String? error, bool pricesUpdated})> validate({bool isAr = true}) async {
    if (state.items.isEmpty) {
      return (error: isAr ? 'السلة فارغة' : 'Your cart is empty', pricesUpdated: false);
    }
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
      if (res.data['valid'] == true) return (error: null, pricesUpdated: false);
      final newPrices = <String, double>{};
      String? firstError;
      for (final item in (res.data['items'] as List? ?? [])) {
        if (item['ok'] != false) continue;
        final price = _num(item['current_price']);
        if (item['type'] == 'price_changed' && price != null) {
          newPrices[_lineKey(item['product_id'], item['variation_id'])] = price;
          continue;
        }
        firstError ??= item['message'] as String? ??
            (isAr ? 'بعض المنتجات غير متاحة' : 'Some items are unavailable');
      }
      if (newPrices.isNotEmpty) await applyServerPrices(newPrices);
      if (firstError != null) return (error: firstError, pricesUpdated: newPrices.isNotEmpty);
      if (newPrices.isNotEmpty) return (error: null, pricesUpdated: true);
      return (error: isAr ? 'بعض المنتجات غير متاحة' : 'Some items are unavailable', pricesUpdated: false);
    } catch (e) {
      try {
        final resp = (e as dynamic).response;
        final status = resp?.statusCode as int?;
        // Skip validation for server errors or unimplemented endpoint
        if (status == null || status >= 500 || status == 404 || status == 405) {
          return (error: null, pricesUpdated: false);
        }
        // Surface meaningful 4xx messages (e.g. out of stock from backend)
        final data = resp?.data;
        if (data is Map && data['message'] != null) {
          return (error: data['message'].toString(), pricesUpdated: false);
        }
      } catch (_) {}
      return (error: null, pricesUpdated: false);
    }
  }

  // Returns all cart issues (unavailable OR price-changed) so the cart screen
  // can prompt the user before entering checkout.
  // type: 'unavailable' | 'price_changed'
  Future<List<({CartItem item, String message, String type, double? newPrice, double? oldPrice})>>
      validateAndGetIssues({bool isAr = true}) async {
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
        final pid = apiItem['product_id'] is int
            ? apiItem['product_id'] as int
            : int.tryParse('${apiItem['product_id']}');
        final vid = apiItem['variation_id'] == null
            ? null
            : (apiItem['variation_id'] is int
                ? apiItem['variation_id'] as int
                : int.tryParse('${apiItem['variation_id']}'));
        final msg = (apiItem['message'] as String?) ?? (isAr ? 'مشكلة في المنتج' : 'There is a problem with this item');
        final issueType = (apiItem['type'] as String?) ?? 'unavailable';
        // Laravel sends decimals as strings ("45.00"); a bare `as num?` threw here.
        final newPrice = _num(apiItem['current_price']);
        final oldPrice = _num(apiItem['old_price']);
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
            .map((i) => (item: i, message: isAr ? 'بعض المنتجات غير متاحة' : 'Some items are unavailable',
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
