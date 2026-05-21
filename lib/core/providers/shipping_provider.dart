import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/shipping_rate.dart';
import 'address_provider.dart';

// Cached list of all active city rates — loaded once on app start, rarely changes.
final shippingRatesProvider = FutureProvider<List<ShippingRate>>((ref) async {
  try {
    final res = await ApiClient.instance.dio.get('/shipping/cities');
    final list = (res.data['data'] as List? ?? []);
    return list.map((j) => ShippingRate.fromJson(j as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
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
