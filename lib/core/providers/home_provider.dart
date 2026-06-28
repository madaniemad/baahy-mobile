import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../models/product.dart';
import '../services/cache_service.dart';
import 'recently_viewed_provider.dart';

class CategorySection {
  final Category category;
  final List<Product> products;
  final String? viewAllUrl;
  const CategorySection({required this.category, required this.products, this.viewAllUrl});
}

// ── Ordered dynamic section items (reflect admin position exactly) ────────────
abstract class HomeDynamicItem {}

class DynGrid extends HomeDynamicItem {
  final String titleAr;
  final String titleEn;
  final String? viewAllUrl;
  final List<Product> products;
  DynGrid({required this.titleAr, required this.titleEn, this.viewAllUrl, required this.products});
}

class DynCarousel extends HomeDynamicItem {
  final CategorySection section;
  DynCarousel(this.section);
}

class DynBannerDuo extends HomeDynamicItem {
  final BannerDuoSection section;
  DynBannerDuo(this.section);
}

class DynBanner extends HomeDynamicItem {
  final String? imageUrl;
  final String? linkUrl;
  final String? badgeAr;
  final String? badgeEn;
  final bool showOverlay;
  DynBanner({this.imageUrl, this.linkUrl, this.badgeAr, this.badgeEn, this.showOverlay = false});
}

class DynCategoryCarousel extends HomeDynamicItem {
  final String titleAr;
  final String titleEn;
  final List<Category> categories;
  DynCategoryCarousel({required this.titleAr, required this.titleEn, required this.categories});
}

class FashionCard {
  final String imageUrl;
  final String? imageUrlEn;
  final String? linkUrl;
  final String? badgeAr;
  final String? badgeEn;
  const FashionCard({required this.imageUrl, this.imageUrlEn, this.linkUrl, this.badgeAr, this.badgeEn});
  Map<String, dynamic> toJson() => {
    'imageUrl': imageUrl, 'imageUrlEn': imageUrlEn, 'linkUrl': linkUrl, 'badgeAr': badgeAr, 'badgeEn': badgeEn,
  };
  factory FashionCard.fromJson(Map<String, dynamic> j) => FashionCard(
    imageUrl: j['imageUrl'] as String,
    imageUrlEn: j['imageUrlEn'] as String?,
    linkUrl: j['linkUrl'] as String?,
    badgeAr: j['badgeAr'] as String?,
    badgeEn: j['badgeEn'] as String?,
  );
}

class DynFashionCards extends HomeDynamicItem {
  final String titleAr;
  final String titleEn;
  final List<FashionCard> cards;
  DynFashionCards({required this.titleAr, required this.titleEn, required this.cards});
}

class DynStripBanner extends HomeDynamicItem {
  final String imageUrl;
  final String? linkUrl;
  DynStripBanner({required this.imageUrl, this.linkUrl});
}

class BannerDuoSection {
  final String? imageUrl;
  final String? imageUrl2;
  final String? linkUrl;
  final String? linkUrl2;
  final String? badgeAr;
  final String? badgeEn;
  final String? badgeAr2;
  final String? badgeEn2;
  final bool showOverlay;
  // Left panel overlay
  final String? titleAr;
  final String? titleEn;
  final String? subtitleAr;
  final String? subtitleEn;
  final String? buttonAr;
  final String? buttonEn;
  final String textSide;
  // Right panel overlay
  final String? titleAr2;
  final String? titleEn2;
  final String? subtitleAr2;
  final String? subtitleEn2;
  final String? buttonAr2;
  final String? buttonEn2;
  final String textSide2;

  const BannerDuoSection({
    this.imageUrl, this.imageUrl2,
    this.linkUrl, this.linkUrl2,
    this.badgeAr, this.badgeEn,
    this.badgeAr2, this.badgeEn2,
    this.showOverlay = false,
    this.titleAr, this.titleEn,
    this.subtitleAr, this.subtitleEn,
    this.buttonAr, this.buttonEn,
    this.textSide = 'right',
    this.titleAr2, this.titleEn2,
    this.subtitleAr2, this.subtitleEn2,
    this.buttonAr2, this.buttonEn2,
    this.textSide2 = 'right',
  });
  Map<String, dynamic> toJson() => {
    'imageUrl': imageUrl, 'imageUrl2': imageUrl2,
    'linkUrl': linkUrl, 'linkUrl2': linkUrl2,
    'badgeAr': badgeAr, 'badgeEn': badgeEn,
    'badgeAr2': badgeAr2, 'badgeEn2': badgeEn2,
    'showOverlay': showOverlay,
    'titleAr': titleAr, 'titleEn': titleEn,
    'subtitleAr': subtitleAr, 'subtitleEn': subtitleEn,
    'buttonAr': buttonAr, 'buttonEn': buttonEn,
    'textSide': textSide,
    'titleAr2': titleAr2, 'titleEn2': titleEn2,
    'subtitleAr2': subtitleAr2, 'subtitleEn2': subtitleEn2,
    'buttonAr2': buttonAr2, 'buttonEn2': buttonEn2,
    'textSide2': textSide2,
  };
  factory BannerDuoSection.fromJson(Map<String, dynamic> j) => BannerDuoSection(
    imageUrl: j['imageUrl'] as String?,
    imageUrl2: j['imageUrl2'] as String?,
    linkUrl: j['linkUrl'] as String?,
    linkUrl2: j['linkUrl2'] as String?,
    badgeAr: j['badgeAr'] as String?,
    badgeEn: j['badgeEn'] as String?,
    badgeAr2: j['badgeAr2'] as String?,
    badgeEn2: j['badgeEn2'] as String?,
    showOverlay: (j['showOverlay'] as bool?) ?? false,
    titleAr: j['titleAr'] as String?,
    titleEn: j['titleEn'] as String?,
    subtitleAr: j['subtitleAr'] as String?,
    subtitleEn: j['subtitleEn'] as String?,
    buttonAr: j['buttonAr'] as String?,
    buttonEn: j['buttonEn'] as String?,
    textSide: (j['textSide'] as String?) ?? 'right',
    titleAr2: j['titleAr2'] as String?,
    titleEn2: j['titleEn2'] as String?,
    subtitleAr2: j['subtitleAr2'] as String?,
    subtitleEn2: j['subtitleEn2'] as String?,
    buttonAr2: j['buttonAr2'] as String?,
    buttonEn2: j['buttonEn2'] as String?,
    textSide2: (j['textSide2'] as String?) ?? 'right',
  );
}

class HomeData {
  final List<Product> featured;
  final List<Product> newArrivals;
  final List<Product> popular;
  final List<Product> deals;
  final List<Category> categories;
  final List<HomeDynamicItem> orderedDynamicSections;
  final bool loading;
  final String? error;

  const HomeData({
    this.featured = const [],
    this.newArrivals = const [],
    this.popular = const [],
    this.deals = const [],
    this.categories = const [],
    this.orderedDynamicSections = const [],
    this.loading = false,
    this.error,
  });

  HomeData copyWith({
    List<Product>? featured,
    List<Product>? newArrivals,
    List<Product>? popular,
    List<Product>? deals,
    List<Category>? categories,
    List<HomeDynamicItem>? orderedDynamicSections,
    bool? loading,
    String? error,
  }) => HomeData(
    featured: featured ?? this.featured,
    newArrivals: newArrivals ?? this.newArrivals,
    popular: popular ?? this.popular,
    deals: deals ?? this.deals,
    categories: categories ?? this.categories,
    orderedDynamicSections: orderedDynamicSections ?? this.orderedDynamicSections,
    loading: loading ?? this.loading,
    error: error,
  );
}

class HomeNotifier extends StateNotifier<HomeData> {
  final ApiClient _api;

  static const _cacheKey = 'home_data_v11';
  static const _cacheTtl = Duration(minutes: 5);

  HomeNotifier(this._api) : super(const HomeData(loading: true)) {
    _loadAndFetch();
  }

  Future<void> _loadAndFetch() async {
    // Serve stale cache immediately so user sees content on cold start.
    final stale = await CacheService.instance.getStale(_cacheKey);
    if (stale != null) {
      try {
        state = _fromCache(stale);
      } catch (e, st) {
        Sentry.captureException(e, stackTrace: st);
      }
    }

    // Skip network if cache is fresh.
    final fresh = await CacheService.instance.get(_cacheKey, maxAge: _cacheTtl);
    if (fresh != null) return;

    await fetch();
  }

  Future<dynamic> _fetchRecommended() async {
    try {
      final signals = await Future.wait([
        RecentlyViewedNotifier.loadStoredIds(),
        _loadCartProductIds(),
        _fetchOrderProductIds(),
      ]);
      final viewedIds = signals[0];
      final cartIds   = signals[1];
      final orderIds  = signals[2];

      final params = <String, dynamic>{'limit': '16'};
      if (viewedIds.isNotEmpty) {
        params['viewed_ids[]'] = viewedIds.take(20).map((id) => id.toString()).toList();
      }
      if (cartIds.isNotEmpty) {
        params['cart_ids[]'] = cartIds.take(10).map((id) => id.toString()).toList();
      }
      if (orderIds.isNotEmpty) {
        params['order_ids[]'] = orderIds.take(20).map((id) => id.toString()).toList();
      }
      final res = await _api.dio.get('/products/recommended', queryParameters: params);
      return res.data;
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      return null;
    }
  }

  static Future<List<int>> _loadCartProductIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('baahy_cart');
      if (raw == null) return [];
      return (jsonDecode(raw) as List)
          .map((j) => (j as Map<String, dynamic>)['product_id'] as int?)
          .whereType<int>()
          .toList();
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      return [];
    }
  }

  Future<List<int>> _fetchOrderProductIds() async {
    try {
      final res = await _api.dio.get('/orders',
          queryParameters: {'per_page': '5'},
          options: Options(receiveTimeout: const Duration(seconds: 2)));
      final body = res.data;
      List? raw;
      final d = body['data'];
      if (d is Map) raw = d['data'] as List?;
      else if (d is List) raw = d;
      if (raw == null) return [];
      return (raw).expand((o) {
        final groups = (o['vendor_groups'] as List?) ?? [];
        return groups.expand((g) {
          final items = (g['items'] as List?) ?? [];
          return items
              .map((i) => (i as Map<String, dynamic>)['product_id'] as int?)
              .whereType<int>();
        });
      }).toList();
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      return [];
    }
  }

  // Derives preferred category IDs using EXACT category (no sibling bleed across gender/type).
  // Cart items weighted 3x, recently viewed 1x.
  // minWeight: only return categories with total weight >= minWeight (default 1 = all).
  // For deal fetching pass minWeight:2 to filter out single-view accidental signals.
  static Future<List<int>> _loadPreferredCategoryIds({int minWeight = 1}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final counts = <int, int>{};

      final encoded = prefs.getStringList('viewed_products_json') ?? [];
      for (final s in encoded.take(20)) {
        try {
          final p = Product.fromJson(jsonDecode(s) as Map<String, dynamic>);
          final id = p.category?.id;
          if (id != null) counts[id] = (counts[id] ?? 0) + 1;
        } catch (e, st) {
          Sentry.captureException(e, stackTrace: st);
        }
      }

      final raw = prefs.getString('baahy_cart');
      if (raw != null) {
        for (final j in (jsonDecode(raw) as List)) {
          try {
            final p = Product.fromJson((j as Map<String, dynamic>)['product'] as Map<String, dynamic>);
            final id = p.category?.id;
            if (id != null) counts[id] = (counts[id] ?? 0) + 3;
          } catch (e, st) {
            Sentry.captureException(e, stackTrace: st);
          }
        }
      }

      if (counts.isEmpty) {
        debugPrint('[Prefs] no viewed/cart data → prefCats empty');
        return [];
      }
      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Apply minimum weight threshold — filter out low-signal categories.
      // If nothing passes the threshold, fall back to top 3 regardless of weight.
      var filtered = sorted.where((e) => e.value >= minWeight).take(6).toList();
      if (filtered.isEmpty) filtered = sorted.take(3).toList();

      final result = filtered.map((e) => e.key).toList();
      debugPrint('[Prefs] prefCats=$result weights=${sorted.take(6).map((e) => '${e.key}:${e.value}').join(',')} (minWeight=$minWeight)');
      return result;
    } catch (e) {
      debugPrint('[Prefs] error loading prefCats: $e');
      return [];
    }
  }

  // Each API call is wrapped independently — one failure never kills the others.
  Future<dynamic> _safeGet(String path, {Map<String, dynamic>? params}) async {
    try {
      final res = await _api.dio.get(path, queryParameters: params);
      return res.data;
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      return null;
    }
  }

  List<Product> _products(dynamic data, String path) {
    try {
      dynamic node = data;
      for (final key in path.split('.')) {
        if (node == null) return [];
        node = node[key];
      }
      return (node as List?)?.map((p) => Product.fromJson(p)).toList() ?? [];
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      return [];
    }
  }

  List<Category> _categories(dynamic data) {
    try {
      return (data?['data'] as List?)?.map((c) => Category.fromJson(c)).toList() ?? [];
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
      return [];
    }
  }

  Future<void> fetch() async {
    state = state.copyWith(loading: true, error: null);

    // Load preferences first — pure local read (~1 ms), negligible overhead.
    // Deals use minWeight:2 to exclude single-accidental-view categories (weight=1).
    // A weight of ≥2 means either 2+ views or at least one cart addition (weight=3).
    final prefDealCats = await _loadPreferredCategoryIds(minWeight: 2);

    // Fire personalized recommendations independently — it's the slowest call
    // (fetches order/viewed signals first, then products). The rest of the screen
    // can render while we wait for it.
    final recommendedFuture = _fetchRecommended();

    // Build deal futures: per-preferred-category (high-relevance) + generic fallback.
    // Both start before any await, so they run in parallel with main requests below.
    // Up to 6 preferred categories × 10 products each, then generic fills the rest.
    final dealFuture = Future.wait([
      ...prefDealCats.map((catId) => _safeGet('/products',
          params: {'category_id': catId, 'on_sale': '1', 'sort': 'popular', 'per_page': 10, 'has_image': '1'})),
      // Generic deals for variety / new-user fallback (always included)
      _safeGet('/products', params: {'on_sale': '1', 'sort': 'popular', 'per_page': 16, 'has_image': '1'}),
    ]);

    final results = await Future.wait([
      _safeGet('/products', params: {'sort': 'popular', 'per_page': 20, 'has_image': '1', 'featured': '1'}),     // 0 featured (منتجات مميزة)
      _safeGet('/products', params: {'sort': 'latest',  'per_page': 16, 'has_image': '1'}),                      // 1 (reserved — was newArrivals)
      _safeGet('/products', params: {'category_id': 25,  'sort': 'popular', 'per_page': 20, 'has_image': '1'}), // 2 bestsellers men
      _safeGet('/products', params: {'category_id': 1,   'sort': 'popular', 'per_page': 20, 'has_image': '1'}), // 3 bestsellers women
      _safeGet('/products', params: {'category_id': 90,  'sort': 'popular', 'per_page': 20, 'has_image': '1'}), // 4 bestsellers electronics
      _safeGet('/products', params: {'category_id': 64,  'sort': 'popular', 'per_page': 20, 'has_image': '1'}), // 5 bestsellers beauty
      _safeGet('/products', params: {'category_id': 61,  'sort': 'popular', 'per_page': 20, 'has_image': '1'}), // 6 bestsellers perfumes
      _safeGet('/products', params: {'category_id': 119, 'sort': 'popular', 'per_page': 20, 'has_image': '1'}), // 7 bestsellers home
      _safeGet('/categories'),                                                                                   // 8
      _safeGet('/home/sections', params: {'platform': 'mobile'}),                                              // 9 dynamic sections
    ]);

    final newArrivals = _products(results[0], 'data.data');

    // One bestseller per main category — pick randomly from top pool so each open varies
    Product? _pick(int i) {
      final list = _products(results[i], 'data.data');
      if (list.isEmpty) return null;
      list.shuffle(Random());
      return list.first;
    }
    final popular = [
      _pick(2),  // men
      _pick(3),  // women
      _pick(4),  // electronics
      _pick(5),  // beauty
      _pick(6),  // perfumes
      _pick(7),  // home
    ].whereType<Product>().toList();

    final categories = _categories(results[8]);

    // Parse dynamic home sections from admin API — preserve exact position order.
    final sectionList = (results[9]?['data'] as List? ?? []);
    final orderedSections = <HomeDynamicItem>[];
    final seenAboveIds = <int>{
      ...popular.map((p) => p.id),
      ...newArrivals.map((p) => p.id),
    };

    const String apiBase = 'https://api.baahy.com';
    String? fullUrl(String? path) {
      if (path == null || path.isEmpty) return null;
      if (path.startsWith('http')) return path;
      return '$apiBase$path';
    }

    for (final s in sectionList) { try {
      final type = s['type'] as String? ?? 'carousel';
      final titleAr = s['title_ar'] as String? ?? '';
      final titleEn = s['title_en'] as String? ?? titleAr;
      final viewAll = s['view_all_url'] as String?;
      final prods = (s['products'] as List? ?? [])
          .map((p) => Product.fromJson(p as Map<String, dynamic>))
          .where((p) => !seenAboveIds.contains(p.id))
          .toList();

      if (type == 'grid') {
        if (prods.isNotEmpty) {
          orderedSections.add(DynGrid(
            titleAr: titleAr, titleEn: titleEn,
            viewAllUrl: viewAll,
            products: prods.take(24).toList(),
          ));
          seenAboveIds.addAll(prods.map((p) => p.id));
        }
      } else if (type == 'carousel') {
        if (prods.isNotEmpty) {
          int catId = s['id'] as int? ?? 0;
          if (viewAll != null) {
            final m = RegExp(r'category_id=(\d+)').firstMatch(viewAll);
            if (m != null) catId = int.tryParse(m.group(1) ?? '') ?? catId;
          }
          final cat = Category(id: catId, name: titleEn, nameAr: titleAr);
          orderedSections.add(DynCarousel(CategorySection(
            category: cat, products: prods, viewAllUrl: viewAll,
          )));
          seenAboveIds.addAll(prods.map((p) => p.id));
        }
      } else if (type == 'fashion_cards') {
        final rawCards = s['cards'] as List? ?? [];
        final fashionCards = rawCards
            .whereType<Map<String, dynamic>>()
            .where((c) => (c['image'] as String?)?.isNotEmpty == true)
            .map((c) => FashionCard(
              imageUrl: c['image'] as String,
              imageUrlEn: c['image_en'] as String?,
              linkUrl: c['link'] as String?,
              badgeAr: c['badge_ar'] as String?,
              badgeEn: c['badge_en'] as String?,
            ))
            .toList();
        if (fashionCards.isNotEmpty) {
          orderedSections.add(DynFashionCards(
            titleAr: titleAr, titleEn: titleEn, cards: fashionCards,
          ));
        }
      } else if (type == 'banner_duo') {
        final duo = BannerDuoSection(
          imageUrl:  fullUrl(s['image_url'] as String?),
          imageUrl2: fullUrl(s['image_url_2'] as String?),
          linkUrl:   s['link_url'] as String?,
          linkUrl2:  s['link_url_2'] as String?,
          badgeAr:   s['badge_text_ar'] as String?,
          badgeEn:   s['badge_text_en'] as String?,
          badgeAr2:  s['badge_text_ar_2'] as String?,
          badgeEn2:  s['badge_text_en_2'] as String?,
          showOverlay: (s['show_overlay'] as bool?) ?? false,
          titleAr:    s['overlay_title_ar'] as String?,
          titleEn:    s['overlay_title_en'] as String?,
          subtitleAr: s['overlay_subtitle_ar'] as String?,
          subtitleEn: s['overlay_subtitle_en'] as String?,
          buttonAr:   s['btn_label_ar'] as String?,
          buttonEn:   s['btn_label_en'] as String?,
          textSide:   (s['overlay_position'] as String?) ?? 'right',
          titleAr2:    s['overlay_title_ar_2'] as String?,
          titleEn2:    s['overlay_title_en_2'] as String?,
          subtitleAr2: s['overlay_subtitle_ar_2'] as String?,
          subtitleEn2: s['overlay_subtitle_en_2'] as String?,
          buttonAr2:   s['btn_label_ar_2'] as String?,
          buttonEn2:   s['btn_label_en_2'] as String?,
          textSide2:   (s['overlay_position_2'] as String?) ?? 'right',
        );
        if (duo.imageUrl != null || duo.imageUrl2 != null) {
          orderedSections.add(DynBannerDuo(duo));
        }
      } else if (type == 'category_carousel') {
        final cats = (s['categories'] as List?)
            ?.map((c) => Category.fromJson(c as Map<String, dynamic>))
            .where((c) => c.image != null && c.image!.isNotEmpty)
            .toList();
        final items = (cats != null && cats.isNotEmpty) ? cats : categories
            .where((c) => c.image != null && c.image!.isNotEmpty)
            .take(12).toList();
        if (items.isNotEmpty) {
          orderedSections.add(DynCategoryCarousel(
            titleAr: titleAr, titleEn: titleEn, categories: items,
          ));
        }
      } else if (type == 'strip_banner') {
        final imageUrl = fullUrl(s['image_url'] as String?);
        if (imageUrl != null) {
          orderedSections.add(DynStripBanner(
            imageUrl: imageUrl,
            linkUrl: s['link_url'] as String?,
          ));
        }
      } else if (type == 'banner') {
        final imageUrl = fullUrl(s['image_url'] as String?);
        if (imageUrl != null) {
          orderedSections.add(DynBanner(
            imageUrl: imageUrl,
            linkUrl:  s['link_url'] as String?,
            badgeAr:  s['badge_text_ar'] as String?,
            badgeEn:  s['badge_text_en'] as String?,
            showOverlay: (s['show_overlay'] as bool?) ?? false,
          ));
        }
      }
    } catch (e, st) { Sentry.captureException(e, stackTrace: st); } }

    // Partial emit — skeleton clears as soon as the fast calls finish.
    // featured (personalized) arrives in a second state update below.
    state = state.copyWith(
      newArrivals: newArrivals,
      popular: popular,
      categories: categories,
      orderedDynamicSections: orderedSections,
    );

    // Wait for the slow personalized call + deals (deals likely already resolved).
    final recommended = await recommendedFuture;
    final dealResults = await dealFuture;

    // recommended returns flat array at 'data', not paginated 'data.data'
    final featured = _products(recommended, 'data')..shuffle(Random());

    // Build per-category preferred deal buckets (dealResults indices 0..prefDealCats.length-1).
    // Each bucket is sorted by discount % DESC — highest deal per category surfaces first.
    final popularIds = popular.map((p) => p.id).toSet();
    final seenDealIds = <int>{...popularIds};
    final prefBuckets = <List<Product>>[];
    for (int i = 0; i < prefDealCats.length; i++) {
      final list = _products(dealResults[i], 'data.data');
      list.sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
      prefBuckets.add(list);
    }

    // Interleave preferred buckets: take 1 item from cat[0], then cat[1], ..., then repeat.
    // Buckets are ordered by weight (index 0 = highest weight category).
    // This ensures: men's perfume deal appears before a 2nd women's item, even if women's
    // items have higher discount %. One cycle = one item per preferred category.
    final prefDeals = <Product>[];
    final maxLen = prefBuckets.fold(0, (m, b) => b.length > m ? b.length : m);
    for (int i = 0; i < maxLen; i++) {
      for (final bucket in prefBuckets) {
        if (i < bucket.length) {
          final p = bucket[i];
          if (seenDealIds.add(p.id)) prefDeals.add(p);
        }
      }
    }

    // Generic fallback: diversity cap of 3 per parent category prevents any one category
    // (e.g. women's clothing) from dominating the tail of the carousel.
    final allGeneric = <Product>[];
    for (final p in _products(dealResults.last, 'data.data')) {
      if (seenDealIds.add(p.id)) allGeneric.add(p);
    }
    allGeneric.sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
    final genericDeals = <Product>[];
    final genericCatCounts = <int, int>{};
    for (final p in allGeneric) {
      final key = p.category?.parentId ?? p.category?.id ?? -1;
      if ((genericCatCounts[key] ?? 0) < 3) {
        genericCatCounts[key] = (genericCatCounts[key] ?? 0) + 1;
        genericDeals.add(p);
      }
    }

    debugPrint('[Deals] prefBuckets=${prefBuckets.map((b) => b.length).toList()} → prefDeals=${prefDeals.length}, genericDeals=${genericDeals.length}');

    final deals = [...prefDeals, ...genericDeals];

    state = HomeData(
      featured: featured,
      newArrivals: newArrivals,
      popular: popular,
      deals: deals,
      categories: categories,
      orderedDynamicSections: orderedSections,
      loading: false,
    );

    // Persist to disk for next cold start.
    if (state.featured.isNotEmpty || state.categories.isNotEmpty) {
      try {
        await CacheService.instance.set(_cacheKey, _toCache(state));
      } catch (e, st) {
        Sentry.captureException(e, stackTrace: st);
      }
    }
  }

  Map<String, dynamic> _toCache(HomeData d) => {
    'featured':    d.featured.map((p) => p.toJson()).toList(),
    'newArrivals': d.newArrivals.map((p) => p.toJson()).toList(),
    'popular':     d.popular.map((p) => p.toJson()).toList(),
    'deals':       d.deals.map((p) => p.toJson()).toList(),
    'categories':  d.categories.map((c) => c.toJson()).toList(),
    'dynSections': d.orderedDynamicSections.map((item) {
      if (item is DynGrid) return {
        'type': 'grid', 'titleAr': item.titleAr, 'titleEn': item.titleEn,
        'viewAllUrl': item.viewAllUrl,
        'products': item.products.map((p) => p.toJson()).toList(),
      };
      if (item is DynCarousel) return {
        'type': 'carousel',
        'category': item.section.category.toJson(),
        'viewAllUrl': item.section.viewAllUrl,
        'products': item.section.products.map((p) => p.toJson()).toList(),
      };
      if (item is DynBannerDuo) return {'type': 'banner_duo', ...item.section.toJson()};
      if (item is DynStripBanner) return {
        'type': 'strip_banner', 'imageUrl': item.imageUrl, 'linkUrl': item.linkUrl,
      };
      if (item is DynCategoryCarousel) return {
        'type': 'category_carousel', 'titleAr': item.titleAr, 'titleEn': item.titleEn,
        'categories': item.categories.map((c) => c.toJson()).toList(),
      };
      if (item is DynBanner) return {
        'type': 'banner', 'imageUrl': item.imageUrl, 'linkUrl': item.linkUrl,
        'badgeAr': item.badgeAr, 'badgeEn': item.badgeEn, 'showOverlay': item.showOverlay,
      };
      if (item is DynFashionCards) return {
        'type': 'fashion_cards', 'titleAr': item.titleAr, 'titleEn': item.titleEn,
        'cards': item.cards.map((c) => c.toJson()).toList(),
      };
      return {'type': 'unknown'};
    }).toList(),
  };

  HomeData _fromCache(Map<String, dynamic> j) {
    List<Product> prods(String key) =>
        (j[key] as List? ?? [])
            .map((p) => Product.fromJson(p as Map<String, dynamic>))
            .toList();

    final categories = (j['categories'] as List? ?? [])
        .map((c) => Category.fromJson(c as Map<String, dynamic>))
        .toList();

    final dynSections = <HomeDynamicItem>[];
    for (final raw in (j['dynSections'] as List? ?? [])) {
      final m = raw as Map<String, dynamic>;
      final type = m['type'] as String? ?? '';
      if (type == 'grid') {
        dynSections.add(DynGrid(
          titleAr: m['titleAr'] as String? ?? '',
          titleEn: m['titleEn'] as String? ?? '',
          viewAllUrl: m['viewAllUrl'] as String?,
          products: (m['products'] as List? ?? [])
              .map((p) => Product.fromJson(p as Map<String, dynamic>)).toList(),
        ));
      } else if (type == 'carousel') {
        dynSections.add(DynCarousel(CategorySection(
          category: Category.fromJson(m['category'] as Map<String, dynamic>),
          viewAllUrl: m['viewAllUrl'] as String?,
          products: (m['products'] as List? ?? [])
              .map((p) => Product.fromJson(p as Map<String, dynamic>)).toList(),
        )));
      } else if (type == 'banner_duo') {
        dynSections.add(DynBannerDuo(BannerDuoSection.fromJson(m)));
      } else if (type == 'strip_banner') {
        final url = m['imageUrl'] as String?;
        if (url != null) dynSections.add(DynStripBanner(imageUrl: url, linkUrl: m['linkUrl'] as String?));
      } else if (type == 'category_carousel') {
        final cats = (m['categories'] as List? ?? [])
            .map((c) => Category.fromJson(c as Map<String, dynamic>)).toList();
        if (cats.isNotEmpty) {
          dynSections.add(DynCategoryCarousel(
            titleAr: m['titleAr'] as String? ?? '',
            titleEn: m['titleEn'] as String? ?? '',
            categories: cats,
          ));
        }
      } else if (type == 'banner') {
        dynSections.add(DynBanner(
          imageUrl: m['imageUrl'] as String?,
          linkUrl:  m['linkUrl'] as String?,
          badgeAr:  m['badgeAr'] as String?,
          badgeEn:  m['badgeEn'] as String?,
          showOverlay: (m['showOverlay'] as bool?) ?? false,
        ));
      } else if (type == 'fashion_cards') {
        final cards = (m['cards'] as List? ?? [])
            .map((c) => FashionCard.fromJson(c as Map<String, dynamic>)).toList();
        if (cards.isNotEmpty) {
          dynSections.add(DynFashionCards(
            titleAr: m['titleAr'] as String? ?? '',
            titleEn: m['titleEn'] as String? ?? '',
            cards: cards,
          ));
        }
      }
    }

    return HomeData(
      featured:    prods('featured'),
      newArrivals: prods('newArrivals'),
      popular:     prods('popular'),
      deals:       prods('deals'),
      categories:  categories,
      orderedDynamicSections: dynSections,
    );
  }
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeData>((ref) {
  return HomeNotifier(ApiClient.instance);
});
