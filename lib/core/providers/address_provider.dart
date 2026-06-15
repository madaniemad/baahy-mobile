import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';

// Holds the user's primary/default delivery address (null = no address saved yet)
final primaryAddressProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

// True when the active city is derived from a saved delivery address
final cityFromAddressProvider = StateProvider<bool>((ref) => false);

class CityNotifier extends StateNotifier<String> {
  final Ref _ref;
  CityNotifier(this._ref) : super('ليبيا') {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('city')?.trim();
    if (saved != null && saved.isNotEmpty && saved != 'كل ليبيا') {
      state = saved;
    }
    // On startup, try to pull city from saved delivery address.
    // This is a best-effort call — fails silently if not logged in.
    await _refreshFromAddress();
  }

  Future<void> _refreshFromAddress() async {
    try {
      final res = await ApiClient.instance.dio.get('/addresses');
      final list = res.data['data'] as List? ?? [];
      if (list.isEmpty) {
        _ref.read(primaryAddressProvider.notifier).state = null;
        _ref.read(cityFromAddressProvider.notifier).state = false;
        return;
      }
      final def = list.firstWhere(
        (a) => a['is_default'] == true,
        orElse: () => list.first,
      ) as Map<String, dynamic>;
      final city = (def['city'] as String?)?.trim();
      if (city != null && city.isNotEmpty) {
        state = city;
        _ref.read(primaryAddressProvider.notifier).state = def;
        _ref.read(cityFromAddressProvider.notifier).state = true;
      }
    } catch (e, st) {
      // Not logged in (401) or unexpected network error — keep current city
      Sentry.captureException(e, stackTrace: st);
    }
  }

  Future<void> setCity(String city) async {
    state = city;
    _ref.read(primaryAddressProvider.notifier).state = null;
    _ref.read(cityFromAddressProvider.notifier).state = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('city', city);
  }

  /// Call this after the user adds, updates, or changes their default address
  Future<void> refresh() => _refreshFromAddress();
}

final cityProvider = StateNotifierProvider<CityNotifier, String>(
  (ref) => CityNotifier(ref),
);
