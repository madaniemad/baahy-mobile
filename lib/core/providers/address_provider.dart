import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';

class CityNotifier extends StateNotifier<String> {
  CityNotifier() : super('ليبيا') {
    _init();
  }

  Future<void> _init() async {
    // Read SharedPrefs immediately (synchronous-ish)
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('city')?.trim();
    if (saved != null && saved.isNotEmpty && saved != 'كل ليبيا') {
      state = saved;
    }
    // Then try to get the default address city from API
    await _refreshFromAddress();
  }

  Future<void> _refreshFromAddress() async {
    try {
      final res = await ApiClient.instance.dio.get('/addresses');
      final list = res.data['data'] as List? ?? [];
      if (list.isEmpty) return;
      final def = list.firstWhere(
        (a) => a['is_default'] == true,
        orElse: () => list.first,
      );
      final city = (def['city'] as String?)?.trim();
      if (city != null && city.isNotEmpty) {
        state = city;
      }
    } catch (_) {}
  }

  Future<void> setCity(String city) async {
    state = city;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('city', city);
  }

  /// Call this after the user changes their default address
  Future<void> refresh() => _refreshFromAddress();
}

final cityProvider = StateNotifierProvider<CityNotifier, String>(
  (ref) => CityNotifier(),
);
