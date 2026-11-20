import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../api/api_client.dart';
import '../models/shipping_rate.dart';
import '../services/cache_service.dart';
import 'address_provider.dart';

const _shippingCacheKey = 'shipping_cities_v1';
const _shippingCacheTtl = Duration(minutes: 5);

// Shipping rates with 5-minute disk cache — refreshes automatically without app restart.
// A failed load is an ERROR, not an empty list: `catch → []` was cached for the whole
// session and read as "no cities". Readers using `valueOrNull ?? []` are unaffected;
// screens that list cities show an error and `ref.invalidate(shippingRatesProvider)`.
final shippingRatesProvider = FutureProvider<List<ShippingRate>>((ref) async {
  try {
    final cached = await CacheService.instance.get(_shippingCacheKey, maxAge: _shippingCacheTtl);
    List rawList;
    if (cached != null && cached['data'] is List) {
      rawList = cached['data'] as List;
    } else {
      final res = await ApiClient.instance.dio.get('/shipping/cities');
      rawList = (res.data['data'] as List? ?? []);
      await CacheService.instance.set(_shippingCacheKey, {'data': rawList});
    }
    return rawList.map((j) => ShippingRate.fromJson(j as Map<String, dynamic>)).toList();
  } catch (e, st) {
    Sentry.captureException(e, stackTrace: st);
    rethrow;
  }
});

// The rate for the currently selected city. Null = city not set / rates not loaded.
final cityShippingRateProvider = Provider<ShippingRate?>((ref) {
  final city = ref.watch(cityProvider);
  if (city.isEmpty) return null;
  final rates = ref.watch(shippingRatesProvider).valueOrNull ?? [];
  if (rates.isEmpty) return null;
  try {
    return rates.firstWhere(
      (r) => r.cityAr == city || r.city.toLowerCase() == city.toLowerCase(),
    );
  } catch (_) {
    return null;
  }
});

/// What each area of a city adds to delivery (Emad 2026-11-18): far Tripoli areas pay a little more.
/// The server sends 0 while its switch is off, so the checkout total always equals what the order is
/// charged (FarAreaFee). Keyed by area id.
final areaExtraFeesProvider = FutureProvider.family<Map<int, double>, String>((ref, city) async {
  try {
    final res = await ApiClient.instance.dio.get('/areas', queryParameters: {'city': city});
    final data = res.data is Map ? res.data['data'] : null;
    final areas = (data is Map ? data['areas'] as List? : null) ?? const [];
    return {
      for (final a in areas)
        if (a is Map && a['id'] is num) (a['id'] as num).toInt(): ((a['extra_delivery_fee'] ?? 0) as num).toDouble(),
    };
  } catch (_) {
    return const {};
  }
});

/// What a checkout asks the server for the distance fee: the city, the delivery pin, the cart's products
/// (sorted ids, comma-joined) and its subtotal. A record, so equal queries share one request.
typedef DistanceFeeQuery = ({String city, double lat, double lng, String productIds, double total});

/// Delivery by distance (Emad 2026-11-20): inside Tripoli the customer pays what the driver is paid for the
/// trip (15 / 20 by the route from the nearest seller to the pin), never more than 20. The server works it out
/// (CustomerDeliveryFee) and /shipping/calculate quotes it as `distance_fee`. null = not switched on, no route,
/// or no answer: keep the flat fee. The order is charged it only when it sends `distance_fee: 1`, which the
/// checkout does only when this gave a number — so the total shown is the total charged.
final distanceFeeProvider = FutureProvider.family<double?, DistanceFeeQuery>((ref, q) async {
  try {
    final res = await ApiClient.instance.dio.post('/shipping/calculate', data: {
      'city': q.city,
      'total': q.total,
      'lat': q.lat,
      'lng': q.lng,
      'product_ids': q.productIds.split(',').map(int.parse).toList(),
    });
    final d = res.data is Map ? res.data['data'] : null;
    final fee = d is Map ? d['distance_fee'] : null;
    return fee is num ? fee.toDouble() : (fee == null ? null : double.tryParse(fee.toString()));
  } catch (_) {
    return null;
  }
});
