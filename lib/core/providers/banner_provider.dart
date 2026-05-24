import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/banner.dart';
import '../services/cache_service.dart';

// Banners: show stale cache instantly on cold start, always fetch fresh in background.
// No TTL gate — admin changes must reflect on every app launch.
final bannersProvider = StateNotifierProvider<BannersNotifier, BannersData>((ref) {
  return BannersNotifier();
});

class BannersNotifier extends StateNotifier<BannersData> {
  static const _cacheKey = 'banners';

  BannersNotifier() : super(const BannersData()) {
    _load();
  }

  Future<void> _load() async {
    // 1. Show stale cache immediately so the screen isn't blank on launch.
    final stale = await CacheService.instance.getStale(_cacheKey);
    if (stale != null) {
      try { state = BannersData.fromJson(stale); } catch (_) {}
    }

    // 2. Always fetch fresh — no TTL gate so admin changes reflect immediately.
    await refresh();
  }

  Future<void> refresh() async {
    try {
      final res = await ApiClient.instance.dio.get('/content/banners');
      final data = res.data['data'] as Map<String, dynamic>?;
      if (data != null) {
        await CacheService.instance.set(_cacheKey, data);
        state = BannersData.fromJson(data);
      }
    } catch (_) {}
  }
}
