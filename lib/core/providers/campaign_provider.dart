import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../api/api_client.dart';
import '../debug/fake_campaign.dart';
import '../models/campaign.dart';
import '../models/product.dart';
import '../services/cache_service.dart';

/// The campaign running right now (`GET /campaigns/current`), or null when none is.
///
/// Loaded with the home data (stale cache first, like home), refreshed on home's pull-to-refresh.
/// A failed request just means "no campaign": it never throws and never blocks home. Every
/// campaign entry point (home strip, browse tile, search chip, store strip) reads `valueOrNull`.
class CampaignNotifier extends StateNotifier<AsyncValue<Campaign?>> {
  CampaignNotifier() : super(const AsyncLoading()) {
    _load();
  }

  static const _cacheKey = 'campaign_current_v1';
  static const _cacheTtl = Duration(minutes: 5);

  Future<void> _load() async {
    if (kFakeCampaign) {
      state = AsyncData(Campaign.tryParse(kFakeCampaignJson));
      return;
    }
    final cached = await CacheService.instance.getStaleWithAge(_cacheKey);
    if (cached != null) {
      final c = Campaign.tryParse(cached.$1['campaign']);
      if (mounted) state = AsyncData(c == null || c.hasEnded ? null : c);
      if (cached.$2 <= _cacheTtl) return;
    }
    await refresh();
  }

  Future<void> refresh() async {
    if (kFakeCampaign) {
      state = AsyncData(Campaign.tryParse(kFakeCampaignJson));
      return;
    }
    try {
      final res = await ApiClient.instance.dio.get('/campaigns/current');
      final raw = res.data is Map ? res.data['campaign'] : null;
      final c = Campaign.tryParse(raw);
      if (mounted) state = AsyncData(c == null || c.hasEnded ? null : c);
      await CacheService.instance.set(_cacheKey, {'campaign': c?.json});
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      // Keep what we had (a cached campaign); otherwise there is no campaign.
      if (mounted && state is! AsyncData) state = const AsyncData(null);
    }
  }
}

final campaignProvider =
    StateNotifierProvider<CampaignNotifier, AsyncValue<Campaign?>>((ref) => CampaignNotifier());

/// The running campaign, or null. What the entry points watch.
final currentCampaignProvider =
    Provider<Campaign?>((ref) => ref.watch(campaignProvider).valueOrNull);

/// Stores with offers in the campaign right now, most offers first. Empty on failure.
final campaignStoresProvider =
    FutureProvider.autoDispose.family<List<CampaignStore>, String>((ref, slug) async {
  if (kFakeCampaign) return _fakeStores();
  try {
    final res = await ApiClient.instance.dio.get('/campaigns/${Uri.encodeComponent(slug)}/stores');
    final list = res.data is Map ? res.data['data'] as List? : null;
    return (list ?? const []).map(CampaignStore.tryParse).whereType<CampaignStore>().toList();
  } catch (e, st) {
    Sentry.captureException(e, stackTrace: st);
    return const [];
  }
});

/// Whether a store has products in the campaign (for the «مشارك في …» strip on its page).
final vendorInCampaignProvider =
    FutureProvider.autoDispose.family<bool, (String, int)>((ref, key) async {
  final (slug, vendorId) = key;
  try {
    final res = await ApiClient.instance.dio.get('/products', queryParameters: {
      ...campaignProductsParams(slug),
      'vendor_ids[]': [vendorId],
      'per_page': 1,
    });
    final total = (res.data?['data']?['total'] as num?)?.toInt() ?? 0;
    return total > 0;
  } catch (_) {
    return false;
  }
});

/// The `/products` params that scope a listing to a campaign. When faking (debug only) the live
/// discounted products stand in, since the server does not know the fake campaign.
Map<String, dynamic> campaignProductsParams(String slug) =>
    kFakeCampaign ? {'on_sale': '1'} : {'campaign': slug};

/// Debug only: the stores behind the first 100 discounted products, plus one store without a logo
/// (and usually without offers) so the initial fallback and the empty state can be checked.
Future<List<CampaignStore>> _fakeStores() async {
  final out = <int, CampaignStore>{};
  try {
    final res = await ApiClient.instance.dio.get('/products',
        queryParameters: {'on_sale': '1', 'sort': 'discount', 'per_page': 100});
    for (final p in (res.data['data']['data'] as List)) {
      final v = Product.fromJson(p as Map<String, dynamic>).vendor;
      if (v == null) continue;
      final prev = out[v.id];
      out[v.id] = CampaignStore(
        id: v.id,
        name: v.storeName,
        nameAr: v.storeNameAr,
        logo: v.logo,
        count: (prev?.count ?? 0) + 1,
      );
    }
    final vres = await ApiClient.instance.dio
        .get('/vendors', queryParameters: {'per_page': 30, 'has_products': 1});
    final raw = vres.data?['data'];
    final list = (raw is Map ? raw['data'] : raw) as List? ?? const [];
    for (final j in list) {
      if (j is! Map) continue;
      final id = (j['id'] as num?)?.toInt();
      if (id == null || out.containsKey(id) || (j['logo'] ?? '').toString().isNotEmpty) continue;
      out[id] = CampaignStore(
        id: id,
        name: '${j['store_name'] ?? ''}',
        nameAr: '${j['store_name_ar'] ?? ''}',
      );
      break;
    }
  } catch (_) {}
  return out.values.toList()..sort((a, b) => b.count.compareTo(a.count));
}
