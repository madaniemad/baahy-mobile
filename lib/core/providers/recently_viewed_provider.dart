import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';

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
  }
}
