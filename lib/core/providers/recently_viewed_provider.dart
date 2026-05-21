import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';

const _kViewedIds = 'viewed_product_ids';
const _kMaxStored = 40;

final recentlyViewedProvider =
    StateNotifierProvider<RecentlyViewedNotifier, List<Product>>((ref) {
  return RecentlyViewedNotifier();
});

class RecentlyViewedNotifier extends StateNotifier<List<Product>> {
  RecentlyViewedNotifier() : super([]);

  void add(Product product) {
    final updated = [
      product,
      ...state.where((p) => p.id != product.id),
    ].take(12).toList();
    state = updated;
    _persistId(product.id);
  }

  static Future<void> _persistId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_kViewedIds) ?? [];
    final updated = [id.toString(), ...stored.where((s) => s != id.toString())]
        .take(_kMaxStored)
        .toList();
    await prefs.setStringList(_kViewedIds, updated);
  }

  static Future<List<int>> loadStoredIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kViewedIds) ?? [])
        .map(int.tryParse)
        .whereType<int>()
        .toList();
  }
}
