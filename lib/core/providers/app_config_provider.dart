import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../models/app_config.dart';
import '../services/cache_service.dart';

// Fetches from /api/app-config (backed by site_settings table in Laravel).
// Strategy: return disk-cached value immediately (instant UI), then refresh
// from network in background and update state. Falls back to built-in
// defaults if both disk and network fail.
final appConfigProvider = StateNotifierProvider<AppConfigNotifier, AppConfig>((ref) {
  return AppConfigNotifier();
});

class AppConfigNotifier extends StateNotifier<AppConfig> {
  static const _cacheKey = 'app_config';
  static const _cacheTtl = Duration(minutes: 30);

  AppConfigNotifier() : super(AppConfig.defaults) {
    _load();
  }

  Future<void> _load() async {
    // 1. Return stale cache immediately so UI is instant on cold start.
    final stale = await CacheService.instance.getStale(_cacheKey);
    if (stale != null) {
      try { state = AppConfig.fromJson(stale); } catch (_) {}
    }

    // 2. Always fetch fresh from network so admin changes (e.g. AI toggle)
    //    reflect on the next app open without waiting for cache to expire.
    await refresh();
  }

  Future<void> refresh() async {
    try {
      final res = await ApiClient.instance.dio.get('/app-config');
      final data = res.data['data'];
      if (data != null && data is Map<String, dynamic>) {
        await CacheService.instance.set(_cacheKey, data);
        state = AppConfig.fromJson(data);
      }
    } catch (_) {
      // Keep current state (stale cache or defaults).
    }
  }
}

// Sync accessor — always returns current state (never null, never blocks).
extension AppConfigX on AsyncValue<AppConfig> {
  AppConfig get config => value ?? AppConfig.defaults;
}
