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
