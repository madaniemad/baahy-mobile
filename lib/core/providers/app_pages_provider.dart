import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../api/api_client.dart';
import '../services/cache_service.dart';

class CityEntry {
  final String ar;
  final String en;
  const CityEntry({required this.ar, required this.en});
  factory CityEntry.fromJson(Map<String, dynamic> j) =>
      CityEntry(ar: j['ar']?.toString() ?? '', en: j['en']?.toString() ?? '');
}

class AppPages {
  final String privacyAr;
  final String privacyEn;
  final String termsAr;
  final String termsEn;
  final List<Map<String, String>> returnSections;
  final List<Map<String, String>> faqItems;
  final String contactWhatsapp;
  final String contactEmail;
  final String contactPhone;
  final List<CityEntry> cities;

  const AppPages({
    this.privacyAr = '',
    this.privacyEn = '',
    this.termsAr = '',
    this.termsEn = '',
    this.returnSections = const [],
    this.faqItems = const [],
    this.contactWhatsapp = '',
    this.contactEmail = '',
    this.contactPhone = '',
    this.cities = const [],
  });

  factory AppPages.fromJson(Map<String, dynamic> j) {
    List<Map<String, String>> parseSections(dynamic raw) {
      if (raw is! List) return [];
      return raw.map<Map<String, String>>((s) => {
        'title_ar': s['title_ar']?.toString() ?? s['title']?.toString() ?? '',
        'title_en': s['title_en']?.toString() ?? '',
        'body_ar':  s['body_ar']?.toString()  ?? s['body']?.toString()  ?? '',
        'body_en':  s['body_en']?.toString()  ?? '',
      }).toList();
    }

    List<Map<String, String>> parseFaq(dynamic raw) {
      if (raw is! List) return [];
      return raw.map<Map<String, String>>((s) => {
        'q_ar': s['q_ar']?.toString() ?? s['q']?.toString() ?? '',
        'q_en': s['q_en']?.toString() ?? '',
        'a_ar': s['a_ar']?.toString() ?? s['a']?.toString() ?? '',
        'a_en': s['a_en']?.toString() ?? '',
      }).toList();
    }

    final contact = j['contact'] as Map<String, dynamic>? ?? {};
    final rawCities = j['cities'] as List? ?? [];
    return AppPages(
      privacyAr: (j['privacy'] as Map?)?['content_ar']?.toString() ?? '',
      privacyEn: (j['privacy'] as Map?)?['content_en']?.toString() ?? '',
      termsAr:   (j['terms']   as Map?)?['content_ar']?.toString() ?? '',
      termsEn:   (j['terms']   as Map?)?['content_en']?.toString() ?? '',
      returnSections: parseSections((j['return_policy'] as Map?)?['sections']),
      faqItems:  parseFaq(j['faq']),
      contactWhatsapp: contact['whatsapp']?.toString() ?? '',
      contactEmail:    contact['email']?.toString() ?? '',
      contactPhone:    contact['phone']?.toString() ?? '',
      cities: rawCities.map((c) => CityEntry.fromJson(c as Map<String, dynamic>)).toList(),
    );
  }
}

final appPagesProvider = StateNotifierProvider<AppPagesNotifier, AppPages>((ref) {
  return AppPagesNotifier();
});

class AppPagesNotifier extends StateNotifier<AppPages> {
  static const _cacheKey = 'app_pages_v1';
  static const _cacheTtl = Duration(minutes: 30);

  AppPagesNotifier() : super(const AppPages()) {
    _load();
  }

  Future<void> _load() async {
    final stale = await CacheService.instance.getStale(_cacheKey);
    if (stale != null) {
      try { state = AppPages.fromJson(stale); } catch (_) {}
    }
    final fresh = await CacheService.instance.get(_cacheKey, maxAge: _cacheTtl);
    if (fresh != null) return;
    // Cache expired — defer the network call so it doesn't compete with
    // startup-critical requests (home feed, config, etc.).
    Future.delayed(const Duration(seconds: 4), refresh);
  }

  Future<void> refresh() async {
    try {
      final res = await ApiClient.instance.dio.get('/app-pages');
      final data = res.data['data'];
      if (data != null && data is Map<String, dynamic>) {
        await CacheService.instance.set(_cacheKey, data);
        state = AppPages.fromJson(data);
      }
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st);
    }
  }
}
