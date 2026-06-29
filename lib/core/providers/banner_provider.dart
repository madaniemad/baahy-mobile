import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../api/api_client.dart';
import '../models/banner.dart';
import '../services/cache_service.dart';

// Banners: show stale cache instantly on cold start, always fetch fresh in background.
// No TTL gate — admin changes must reflect on every app launch.
final bannersProvider = StateNotifierProvider<BannersNotifier, BannersData>((ref) {
  return BannersNotifier();
});

class BannersNotifier extends StateNotifier<BannersData> {
  static const _cacheKey = 'banners_v2';

  BannersNotifier() : super(const BannersData()) {
    _load();
  }

  Future<void> _load() async {
    // 1. Load stale cache so banner data is ready.
    final stale = await CacheService.instance.getStale(_cacheKey);
    if (stale != null) {
      try { state = BannersData.fromJson(stale); } catch (_) {}
    }

    // 2. Mark initialized immediately — home screen does not wait for the prewarm.
    if (!state.initialized) state = state.copyWith(initialized: true);

    // 3. Pre-warm hero image concurrently so it's in Flutter's cache when it first renders.
    unawaited(_prewarmFirstHero());

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
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
    }
  }

  Future<void> refresh() async {
    try {
      final res = await ApiClient.instance.dio.get('/content/banners',
          options: Options(headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'}));
      final data = res.data['data'] as Map<String, dynamic>?;
      if (data != null) {
        await CacheService.instance.set(_cacheKey, data);
        state = BannersData.fromJson(data);
      }
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
    }
  }
}
