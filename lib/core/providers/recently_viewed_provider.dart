import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const _kViewedIds      = 'viewed_product_ids';
const _kViewedProducts = 'viewed_products_json';
const _kMaxStored      = 20;

final recentlyViewedProvider =
    StateNotifierProvider<RecentlyViewedNotifier, List<Product>>((ref) {
  return RecentlyViewedNotifier();
});

class RecentlyViewedNotifier extends StateNotifier<List<Product>> {
  RecentlyViewedNotifier() : super([]) {
    _restore();
  }

  // Load persisted products from disk on cold start.
  Future<void> _restore() async {
    try {
      final prefs   = await SharedPreferences.getInstance();
      final encoded = prefs.getStringList(_kViewedProducts) ?? [];
      final products = encoded
          .map((s) {
            try { return Product.fromJson(jsonDecode(s) as Map<String, dynamic>); }
            catch (e, st) { Sentry.captureException(e, stackTrace: st); return null; }
          })
          .whereType<Product>()
          .toList();
      if (products.isNotEmpty && mounted) state = products;
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
    }
  }

  void add(Product product) {
    final updated = [
      product,
      ...state.where((p) => p.id != product.id),
    ].take(_kMaxStored).toList();
    state = updated;
    _persist(updated);
  }

  static Future<void> _persist(List<Product> products) async {
    final prefs = await SharedPreferences.getInstance();
    // IDs used by the recommendations endpoint.
    await prefs.setStringList(_kViewedIds,
      products.map((p) => p.id.toString()).toList());
    // Full product JSON for cold-start restoration.
    await prefs.setStringList(_kViewedProducts,
      products.map((p) => jsonEncode(p.toJson())).toList());
  }

  static Future<List<int>> loadStoredIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kViewedIds) ?? [])
        .map(int.tryParse)
        .whereType<int>()
        .toList();
  }
}
