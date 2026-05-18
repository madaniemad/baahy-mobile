import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/banner.dart';
import '../services/cache_service.dart';

// Same stale-while-revalidate strategy as AppConfigNotifier.
// Banners load from disk instantly on cold start, then refresh in background.
final bannersProvider = StateNotifierProvider<BannersNotifier, BannersData>((ref) {
  return BannersNotifier();
});

class BannersNotifier extends StateNotifier<BannersData> {
  static const _cacheKey = 'banners';
  static const _cacheTtl = Duration(minutes: 30);

  BannersNotifier() : super(const BannersData()) {
    _load();
  }

  Future<void> _load() async {
    // 1. Return stale cache immediately.
    final stale = await CacheService.instance.getStale(_cacheKey);
    if (stale != null) {
      try { state = BannersData.fromJson(stale); } catch (_) {}
    }

    // 2. Skip network if cache is fresh.
    final fresh = await CacheService.instance.get(_cacheKey, maxAge: _cacheTtl);
    if (fresh != null) return;

    // 3. Fetch and update.
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
