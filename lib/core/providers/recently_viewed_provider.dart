import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
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
    await refreshFromServer();
  }

  /// The row shows copies saved on the phone, so a product that went draft, sold out or whose shop
  /// closed stayed in it, at its old price (Emad, 2026-11-08). Ask the server for the saved ids: it
  /// returns only products a customer can buy now. Missing ones leave the row, the rest take the
  /// current price. On any network error the row is left as it is.
  Future<void> refreshFromServer() async {
    final asked = state.map((p) => p.id).toSet();
    if (asked.isEmpty) return;
    try {
      final res = await ApiClient.instance.dio.get('/products',
          queryParameters: {'ids[]': asked.map((id) => id.toString()).toList()});
      // { data: { data: [...] } }, like Reorder reads it.
      final node = res.data is Map ? res.data['data'] : null;
      final raw = node is List ? node : (node is Map ? node['data'] : null);
      if (raw is! List) return;
      final fresh = <int, Product>{};
      for (final j in raw) {
        try {
          final p = Product.fromJson(j as Map<String, dynamic>);
          fresh[p.id] = p;
        } catch (e, st) {
          Sentry.captureException(e, stackTrace: st);
        }
      }
      if (!mounted) return;
      // A product viewed while the request was out was not asked about: keep it as it is.
      final updated = [
        for (final p in state)
          if (!asked.contains(p.id)) p else if (fresh[p.id] != null) fresh[p.id]!,
      ];
      state = updated;
      await _persist(updated);
    } catch (e, st) {
      // Offline or a server error: keep what is saved rather than emptying the row.
      if (e is! DioException) Sentry.captureException(e, stackTrace: st);
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

  /// Drop a product that is no longer for sale (its page answered 404), so the row stops
  /// offering it.
  void remove(int productId) {
    if (!state.any((p) => p.id == productId)) return;
    final updated = state.where((p) => p.id != productId).toList();
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
