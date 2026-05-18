import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Disk-backed JSON cache with TTL.
/// Used for AppConfig and Banners so they load instantly on cold start.
class CacheService {
  static CacheService? _instance;
  static CacheService get instance => _instance ??= CacheService._();
  CacheService._();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Returns cached value if fresher than [maxAge], null otherwise.
  Future<Map<String, dynamic>?> get(String key, {Duration maxAge = const Duration(minutes: 30)}) async {
    final prefs = await _p;
    final raw = prefs.getString('cache_$key');
    if (raw == null) return null;
    try {
      final wrapper = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.fromMillisecondsSinceEpoch(wrapper['_t'] as int);
      if (DateTime.now().difference(savedAt) > maxAge) return null;
      return wrapper['d'] as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Returns cached value regardless of age (used for stale-while-revalidate).
  Future<Map<String, dynamic>?> getStale(String key) async {
    final prefs = await _p;
    final raw = prefs.getString('cache_$key');
    if (raw == null) return null;
    try {
      final wrapper = jsonDecode(raw) as Map<String, dynamic>;
      return wrapper['d'] as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> set(String key, Map<String, dynamic> data) async {
    final prefs = await _p;
    await prefs.setString('cache_$key', jsonEncode({
      '_t': DateTime.now().millisecondsSinceEpoch,
      'd': data,
    }));
  }

  Future<void> invalidate(String key) async {
    final prefs = await _p;
    await prefs.remove('cache_$key');
  }
}
