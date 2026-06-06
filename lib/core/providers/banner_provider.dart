import 'dart:async';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
    // 1. Load stale cache so banner data is ready.
    final stale = await CacheService.instance.getStale(_cacheKey);
    if (stale != null) {
      try { state = BannersData.fromJson(stale); } catch (_) {}
    }

    // 2. Pre-warm the first hero image into Flutter's image cache before
    //    marking initialized. This ensures CachedNetworkImage shows it
    //    instantly (no placeholder flash) when the home skeleton clears.
    await _prewarmFirstHero();

    // 3. Mark initialized — home screen can now render without a blank slot.
    if (!state.initialized) state = state.copyWith(initialized: true);

    // 4. Always fetch fresh in background.
    await refresh();
  }

  Future<void> _prewarmFirstHero() async {
    final url = state.hero
        .where((b) => b.imageUrl != null)
        .map((b) => b.imageUrl!)
        .firstOrNull;
    if (url == null) return;

    try {
      final provider = CachedNetworkImageProvider(url);
      final completer = Completer<void>();
      final stream = provider.resolve(ImageConfiguration.empty);
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (_, __) {
          if (!completer.isCompleted) completer.complete();
          stream.removeListener(listener);
        },
        onError: (_, __) {
          if (!completer.isCompleted) completer.complete();
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
      await completer.future
          .timeout(const Duration(seconds: 2), onTimeout: () {
        stream.removeListener(listener);
      });
    } catch (_) {}
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
